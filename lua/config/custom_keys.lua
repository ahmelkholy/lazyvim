local M = { active = {}, routes = {}, errors = {} }
M.path = vim.fn.stdpath("config") .. "/lua/config/shared_keymaps.lua"

local function expand(key)
  return key:gsub("<leader>", vim.g.mapleader or "\\")
end

local function identity(mode, key)
  return mode .. "\0" .. vim.api.nvim_replace_termcodes(expand(key), true, true, true)
end

local function fail(message)
  M.errors = { message }
  return false, message
end

function M.owns(key, mode)
  return M.active[identity(mode or "n", key)] ~= nil
end

function M.clear()
  local sync = require("config.key_sync")
  for _, entry in pairs(M.active) do
    sync.restore_mapping(entry.mode, entry.key, entry.original)
  end
  M.active = {}
end

function M.reload(opts)
  opts = opts or {}
  local sync = require("config.key_sync")
  local chunk, err = loadfile(M.path)
  if not chunk then
    M.errors = { tostring(err) }
    return false, err
  end
  local ok, specs = pcall(chunk)
  if not ok or type(specs) ~= "table" or not vim.islist(specs) then
    M.errors = { "shared_keymaps.lua must return an array of shortcut objects: " .. tostring(specs) }
    return false, M.errors[1]
  end
  local seen, prepared, routes = {}, {}, {}
  for index, spec in ipairs(specs) do
    local valid = type(spec) == "table"
      and type(spec.key) == "string"
      and spec.key ~= ""
      and type(spec.desc) == "string"
      and spec.desc ~= ""
      and (
        (type(spec.target) == "string" and spec.target ~= "")
        or type(spec.rhs) == "string"
        or type(spec.rhs) == "function"
      )
    local modes = valid and (spec.modes or { "n" }) or {}
    if
      not valid
      or not vim.islist(modes)
      or #modes == 0
      or identity("n", spec.key) == identity("n", vim.g.mapleader or "\\")
    then
      M.errors = {
        "Invalid shared shortcut " .. index .. ": key, desc and target/rhs are required; the leader prefix is reserved",
      }
      return false, M.errors[1]
    end
    if spec.vscode ~= nil and type(spec.vscode) ~= "string" then
      return fail("Shared shortcut " .. index .. " vscode must be a command string")
    end
    for _, mode in ipairs(modes) do
      if mode ~= "n" and mode ~= "x" and mode ~= "i" then
        return fail("Shared shortcut modes support n, x, i; terminal keys remain host-specific")
      end
      local id = identity(mode, spec.key)
      if seen[id] then
        return fail("Duplicate shared shortcut: " .. mode .. " " .. spec.key)
      end
      seen[id] = true
    end
    prepared[#prepared + 1] = { spec = spec, modes = modes }
    local key = expand(spec.key)
    -- Letters and leader paths already pass through Neovim and its live menu.
    -- Never register Space chords in VS Code: they would suppress that menu.
    if key:sub(1, 1) == "<" and not vim.startswith(key, "<Space>") then
      local physical, key_err = sync.to_vscode_key(key)
      if not physical then
        return fail(key_err)
      end
      local clauses = {}
      for _, mode in ipairs(modes) do
        clauses[#clauses + 1] = "neovim.mode == '" .. ({ n = "normal", x = "visual", i = "insert" })[mode] .. "'"
      end
      routes[#routes + 1] = {
        key = physical,
        command = "vscode-neovim.send",
        args = key,
        nvim = key,
        when = "editorTextFocus && neovim.init && (" .. table.concat(clauses, " || ") .. ") && !lazygitFocus",
        description = spec.desc,
        modes = modes,
        source = "shared_keymaps:" .. key,
      }
    end
  end

  -- Validate the whole file before removing any working shortcuts.
  sync.clear_aliases()
  M.clear()
  local baselines = {}
  for _, mode in ipairs({ "n", "x", "i" }) do
    baselines[mode] = sync.global_maps(mode)
  end
  for _, entry in ipairs(prepared) do
    local spec = entry.spec
    for _, mode in ipairs(entry.modes) do
      local key = expand(spec.key)
      local codes = vim.api.nvim_replace_termcodes(key, true, true, true)
      M.active[identity(mode, key)] = { mode = mode, key = key, original = baselines[mode][codes] }
      local rhs, map_opts
      if vim.g.vscode and spec.vscode then
        rhs = function()
          require("vscode").action(spec.vscode)
        end
      elseif spec.target then
        local target = expand(spec.target)
        local original = baselines[mode][vim.api.nvim_replace_termcodes(target, true, true, true)]
        if original then
          rhs = original.callback or original.rhs
          map_opts = sync.mapping_options(original, spec.desc)
        else
          rhs = target
        end
      else
        rhs = spec.rhs
      end
      vim.keymap.set(mode, key, rhs, map_opts or { desc = spec.desc, silent = true })
    end
  end
  M.routes, M.errors = routes, {}
  if opts.sync ~= false then
    -- Reconcile pending VS Code edits before rewriting the manifest. Otherwise
    -- a startup normalization/new custom key could win solely by its fresh mtime.
    local reconciled, reconcile_err = sync.sync()
    if not reconciled then
      return false, reconcile_err
    end
    local registered, registration_err = sync.set_custom_routes(routes)
    if not registered then
      return false, registration_err
    end
    return sync.sync()
  end
  return true
end

function M.setup()
  if M._setup then
    return
  end
  M._setup = true
  vim.api.nvim_create_user_command("SharedKeysEdit", function()
    vim.cmd.edit(vim.fn.fnameescape(M.path))
  end, { desc = "Edit shortcuts shared by standalone Neovim and VS Code" })
  vim.api.nvim_create_user_command("SharedKeysReload", function()
    local ok, err = M.reload()
    vim.notify(
      ok and "Shared shortcuts reloaded in this editor" or tostring(err),
      ok and vim.log.levels.INFO or vim.log.levels.ERROR
    )
  end, { desc = "Reload shared custom maps and regenerate physical VS Code routes" })
  vim.keymap.set("n", "<leader>kS", "<cmd>SharedKeysEdit<cr>", { desc = "Edit shared shortcuts" })
  vim.keymap.set("n", "<leader>kH", "<cmd>SharedKeysHealth<cr>", { desc = "Audit shared shortcuts" })
end

return M
