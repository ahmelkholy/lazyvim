-- Full installed LazyVim boot, with only the VS Code RPC/clipboard boundary mocked.
local root = vim.fs.dirname(vim.fs.dirname(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p")))
vim.opt.rtp:prepend(root)
vim.g.vscode = true
local calls = {}
package.loaded.vscode = {
  action = function(command, opts)
    calls[#calls + 1] = { command, opts }
  end,
  call = function(command, opts)
    calls[#calls + 1] = { command, opts }
  end,
  notify = function(message)
    print(message)
  end,
  get_config = function() end,
  update_config = function() end,
}
vim.g.vscode_clipboard = {
  name = "isolated VS Code clipboard",
  copy = { ["+"] = function() end, ["*"] = function() end },
  paste = {
    ["+"] = function()
      return { {}, "v" }
    end,
    ["*"] = function()
      return { {}, "v" }
    end,
  },
}
local sync = require("config.key_sync")
require("config.custom_keys").path = root .. "/lua/config/shared_keymaps.lua"
local fixture = vim.fn.tempname()
vim.fn.mkdir(fixture, "p")
vim.fn.writefile(vim.fn.readfile(root .. "/shared-keybindings.json"), fixture .. "/shared-keybindings.json")
vim.fn.writefile(
  { "[", "// BEGIN NVIM SHARED KEY ROUTES", "// END NVIM SHARED KEY ROUTES", "]" },
  fixture .. "/keybindings.json"
)
sync.manifest_path = fixture .. "/shared-keybindings.json"
sync.keybindings_path = fixture .. "/keybindings.json"
assert(sync.push())
vim.opt.loadplugins = true
dofile(root .. "/init.lua")
vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
assert(
  vim.wait(3000, function()
    return require("config.vscode_parity")._setup
  end),
  "embedded setup did not finish"
)
local parity = require("config.vscode_parity")
local report = parity.health()
assert(report.ok, table.concat(report.errors, "\n"))
assert(vim.g.clipboard.name == "isolated VS Code clipboard")
require("config.multilingual_keys").refresh_aliases()
assert(vim.fn.maparg(" صم", "n") == " wl", "Arabic leader alias missing after full boot")
assert(vim.fn.maparg("لت", "n") ~= "", "Arabic g prefix/display movement missing")
parity.run_leader("<Space>wl")
assert(calls[#calls][1] == "workbench.action.focusRightGroup")
parity.show_leader()
assert(calls[#calls][1] == "whichkey.show")
local function clean(items)
  for _, item in ipairs(items) do
    assert(not (item.name or ""):find("^Layout alias: "), "layout aliases clutter the menu")
    if item.bindings then
      clean(item.bindings)
    end
  end
end
clean(calls[#calls][2].args[1])
for _, key in ipairs({ "j", "k", "ت", "ن" }) do
  local count = #calls
  vim.fn.feedkeys(key, "xt")
  local call = calls[#calls]
  assert(#calls == count + 1 and call[1] == "cursorMove", "full boot lost display motion: " .. key)
  assert(call[2].args.by == "wrappedLine" and call[2].args.value == 1)
  assert(call[2].args.to == ((key == "j" or key == "ت") and "down" or "up"))
end
local shared = sync.health()
assert(shared.ok, table.concat(shared.errors, "\n"))
vim.fn.delete(fixture, "rf")
print(
  ("PASS full embedded LazyVim: %d leader mappings, %d menu items, Arabic aliases and client clipboard"):format(
    report.leader_maps,
    report.menu_items
  )
)
vim.cmd("qa!")
