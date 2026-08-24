local M = {}

local proxy_variables = {
  "NVIM_COPILOT_PROXY",
  "HTTPS_PROXY",
  "https_proxy",
  "HTTP_PROXY",
  "http_proxy",
  "ALL_PROXY",
  "all_proxy",
}

local last_problem

local function running_headless()
  return vim.tbl_contains(vim.v.argv, "--headless")
end

local function trim(value)
  return value and value:match("^%s*(.-)%s*$") or nil
end

local function valid_proxy(value)
  return value and value:match("^https?://[^%s]+$") ~= nil
end

local function redact_proxy(value)
  if not value then
    return nil
  end
  return value:gsub("^(%a[%w+.-]*://)[^/@]+@", "%1<redacted>@")
end

function M.proxy()
  for _, variable in ipairs(proxy_variables) do
    local value = trim(vim.env[variable])
    if value and value ~= "" then
      return value, variable
    end
  end
end

local function strict_ssl()
  local value = trim(vim.env.NVIM_COPILOT_PROXY_STRICT_SSL)
  return not value or not vim.tbl_contains({ "0", "false", "no" }, value:lower())
end

local function bounded_node_options()
  local options = trim(vim.env.NODE_OPTIONS) or ""
  options = options:gsub("%-%-max%-old%-space%-size%s*=%s*%d+", "")
  options = options:gsub("%-%-max%-old%-space%-size%s+%d+", "")
  return trim(options .. " --max-old-space-size=512")
end

local function non_blocking_message(_, params)
  local message = trim(params and params.message) or "Copilot needs attention"
  last_problem = message
  vim.schedule(function()
    vim.notify_once(message .. "\nRun :CopilotHealth for connection details.", vim.log.levels.WARN, {
      title = "GitHub Copilot",
    })
  end)
  -- Copilot uses a server request here. Returning JSON null dismisses it
  -- immediately, so an unavailable network or account can never block nvim .
  return vim.NIL
end

function M.server_options()
  local options = {
    -- Maintenance commands and regression checks must never launch a network
    -- language server or leave one behind after their short-lived process.
    enabled = not running_headless(),
    handlers = {
      ["window/showMessageRequest"] = non_blocking_message,
    },
    -- Node understands these limits identically on Windows, macOS, and Linux.
    -- The heap ceiling prevents a failed proxy/session loop from growing until
    -- the operating system runs out of memory.
    cmd_env = {
      NODE_OPTIONS = bounded_node_options(),
      UV_THREADPOOL_SIZE = "2",
    },
  }

  local proxy = M.proxy()
  if not valid_proxy(proxy) then
    return options
  end

  options.settings = {
    http = {
      proxy = proxy,
      proxyStrictSSL = strict_ssl(),
    },
  }
  -- The language server documents the LSP setting above. Mirroring it into
  -- its process environment also covers networking performed during startup.
  options.cmd_env.HTTP_PROXY = proxy
  options.cmd_env.HTTPS_PROXY = proxy
  options.cmd_env.http_proxy = proxy
  options.cmd_env.https_proxy = proxy
  return options
end

function M.check()
  local proxy, source = M.proxy()
  local clients = vim.lsp.get_clients({ name = "copilot" })
  return {
    binary = vim.fn.executable("copilot-language-server") == 1,
    clients = #clients,
    last_problem = last_problem,
    proxy = proxy and redact_proxy(proxy) or nil,
    proxy_source = source,
    proxy_valid = not proxy or valid_proxy(proxy),
  }
end

function M.show()
  local status = M.check()
  local lines = {
    "Copilot health",
    "Language server: " .. (status.binary and "installed" or "missing"),
    "Active clients: " .. status.clients,
  }
  if status.proxy then
    lines[#lines + 1] = ("Proxy: %s (from %s)"):format(status.proxy, status.proxy_source)
    if not status.proxy_valid then
      lines[#lines + 1] = "Proxy error: only http:// and https:// URLs are supported"
    end
  else
    lines[#lines + 1] = "Proxy: direct connection"
    lines[#lines + 1] = "To use a proxy, export NVIM_COPILOT_PROXY before starting Neovim"
  end
  if status.last_problem then
    lines[#lines + 1] = "Last server message: " .. status.last_problem
  end
  vim.notify(table.concat(lines, "\n"), status.binary and vim.log.levels.INFO or vim.log.levels.ERROR, {
    title = "GitHub Copilot",
  })
  return status
end

function M.setup()
  vim.api.nvim_create_user_command("CopilotHealth", M.show, {
    desc = "Show proxy-safe GitHub Copilot diagnostics",
    force = true,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("copilot_lifecycle", { clear = true }),
    callback = function()
      for _, client in ipairs(vim.lsp.get_clients({ name = "copilot" })) do
        client:stop(true)
      end
    end,
    desc = "Force-stop Copilot with its Neovim session",
  })
end

return M
