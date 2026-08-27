local M = {}

local proxy_environment = {
  "HTTPS_PROXY",
  "https_proxy",
  "HTTP_PROXY",
  "http_proxy",
  "ALL_PROXY",
  "all_proxy",
}

local function proxy_url(scheme, host, port)
  if not host or host == "" or not port or port == "" then
    return nil
  end
  if host:find(":", 1, true) and not host:match("^%[.*%]$") then
    host = "[" .. host .. "]"
  end
  return ("%s://%s:%s"):format(scheme, host, port)
end

---@param output string
---@return string?
function M.parse_macos_proxy(output)
  for _, kind in ipairs({ "HTTPS", "HTTP", "SOCKS" }) do
    local enabled = output:match(kind .. "Enable%s*:%s*(%d+)")
    local host = output:match(kind .. "Proxy%s*:%s*([^\r\n]+)")
    local port = output:match(kind .. "Port%s*:%s*(%d+)")
    if enabled == "1" and host and port then
      host = vim.trim(host)
      return proxy_url(kind == "SOCKS" and "socks5h" or "http", host, port)
    end
  end
end

local function environment_proxy()
  if vim.env.NVIM_NETWORK_PROXY and vim.env.NVIM_NETWORK_PROXY ~= "" then
    return vim.env.NVIM_NETWORK_PROXY
  end
  for _, name in ipairs(proxy_environment) do
    local value = vim.env[name]
    if value and value ~= "" then
      return value
    end
  end
end

local function macos_proxy()
  if vim.fn.has("mac") ~= 1 or vim.fn.executable("/usr/sbin/scutil") ~= 1 then
    return nil
  end

  local result = vim.system({ "/usr/sbin/scutil", "--proxy" }, { text = true }):wait()
  if result.code ~= 0 then
    return nil
  end
  return M.parse_macos_proxy(result.stdout or "")
end

---@param proxy string
local function export_proxy(proxy)
  -- Git, curl, npm, and plugin installers do not all read the same casing.
  -- Export both forms only inside Neovim and its child processes.
  for _, name in ipairs({ "HTTPS_PROXY", "https_proxy", "HTTP_PROXY", "http_proxy" }) do
    if not vim.env[name] or vim.env[name] == "" then
      vim.env[name] = proxy
    end
  end
end

---@return string?
function M.setup()
  if vim.g.nvim_network_proxy_initialized then
    return vim.g.nvim_network_proxy or nil
  end

  local proxy = environment_proxy() or macos_proxy()
  if proxy then
    export_proxy(proxy)
    vim.g.nvim_network_proxy = proxy
  end
  vim.g.nvim_network_proxy_initialized = true
  return proxy
end

return M
