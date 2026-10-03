-- Isolated fixtures only; never rewrites the actual VS Code/Neovim config.
-- nvim --headless -u NONE -l scripts/shared_keys_regression.lua
local root = vim.fs.dirname(vim.fs.dirname(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p")))
vim.opt.rtp:prepend(root)
vim.g.mapleader = " "
local sync = require("config.key_sync")
local custom = require("config.custom_keys")
local jsonc = require("config.jsonc")
local directory = vim.fn.tempname()
vim.fn.mkdir(directory, "p")
sync.manifest_path = directory .. "/shared-keybindings.json"
sync.keybindings_path = directory .. "/keybindings.json"
custom.path = directory .. "/shared_keymaps.lua"
local passed, invoked, notifications = 0, {}, {}
vim.notify = function(message)
  notifications[#notifications + 1] = message
end
package.loaded.vscode = {
  action = function(command)
    invoked[#invoked + 1] = command
  end,
}

local function read(path)
  local handle = assert(io.open(path, "rb"))
  local content = handle:read("*a")
  handle:close()
  return content
end
local function write(path, content)
  vim.fn.writefile(vim.split(content, "\n", { plain = true }), path, "b")
end
local function invoke(key, mode)
  local mapping = vim.fn.maparg(key, mode or "n", false, true)
  assert(mapping.callback, "expected callback for " .. key)
  mapping.callback()
  return invoked[#invoked]
end
local function map(key, label, modes)
  vim.keymap.set(modes or "n", key, function()
    invoked[#invoked + 1] = label
  end, { desc = label })
end
local function reset()
  sync.clear_aliases()
  custom.clear()
  custom.errors = {}
  vim.g.vscode = false
  map("<C-r>", "Recent")
  map("<F2>", "Rename", { "n", "x" })
  map("<C-.>", "Quick fix", { "n", "x" })
  map("<leader>fn", "New file")
  write(custom.path, "return {}\n")
  write(sync.manifest_path, vim.json.encode({
    version = 1,
    routes = {
      { key = "ctrl+r", command = "workbench.action.openRecent", nvim = "<C-r>", description = "Recent" },
    },
  }) .. "\n")
  write(
    sync.keybindings_path,
    "[\n // keep this user comment\n // BEGIN NVIM SHARED KEY ROUTES\n // END NVIM SHARED KEY ROUTES\n]\n"
  )
  local ok, err = sync.push()
  assert(ok, err)
end
local function check(name, callback)
  reset()
  local ok, err = xpcall(callback, debug.traceback)
  if not ok then
    error(name .. "\n" .. err)
  end
  passed = passed + 1
  print("PASS " .. name)
end
local function append(binding, inside_comma)
  local raw = read(sync.keybindings_path)
  if inside_comma then
    raw = raw:gsub("  }\n  // END", "  },\n  // END")
  end
  local close = assert(jsonc.strip(raw):find("]%s*$"))
  local prefix = raw:sub(1, close - 1)
  write(
    sync.keybindings_path,
    prefix .. (inside_comma and "" or "  ,\n") .. vim.json.encode(binding) .. "\n" .. raw:sub(close)
  )
end

check("new managed entries need no metadata and import native actions", function()
  local raw = read(sync.keybindings_path):gsub(
    "  // END",
    '  ,\n {"key":"ctrl+alt+k","command":"editor.action.rename"}\n  // END'
  )
  write(sync.keybindings_path, raw)
  assert(sync.pull())
  local manifest = vim.json.decode(read(sync.manifest_path))
  assert(manifest.routes[2].nvim == "<F2>")
  assert(invoke("<C-A-k>") == "Rename")
end)

check("changing a command also changes standalone meaning", function()
  local raw = read(sync.keybindings_path):gsub('"workbench.action.openRecent"', '"editor.action.rename"')
  write(sync.keybindings_path, raw)
  assert(sync.pull())
  local route = vim.json.decode(read(sync.manifest_path)).routes[1]
  assert(route.nvim == "<F2>", "native command retained stale Neovim meaning")
  assert(invoke("<C-r>") == "Rename")
end)

for _, inside in ipairs({ false, true }) do
  check("VS Code UI additions/edits/removals preserve JSONC, comma style " .. tostring(inside), function()
    append({ key = "ctrl+alt+k", command = "editor.action.rename", when = "editorTextFocus" }, inside)
    assert(sync.pull())
    assert(invoke("<C-A-k>") == "Rename")
    assert(sync.push())
    local raw = read(sync.keybindings_path)
    assert(jsonc.decode(raw))
    assert(raw:find("// keep this user comment", 1, true))
    assert(sync.health().ok)
    -- Remove only the raw UI addition, leaving the generated source-tagged copy.
    local last = raw:find("// END NVIM SHARED KEY ROUTES", 1, true)
    local prefix = raw:sub(1, last + #"// END NVIM SHARED KEY ROUTES" - 1)
    write(sync.keybindings_path, prefix .. "\n]\n")
    assert(sync.pull())
    assert(#vim.json.decode(read(sync.manifest_path)).routes == 1)
    assert(vim.tbl_isempty(vim.fn.maparg("<C-A-k>", "n", false, true)))
  end)
end

check("unknown commands and language/terminal contexts are reported, not guessed", function()
  append({ key = "ctrl+alt+k", command = "unknown.extension.command" })
  append({ key = "ctrl+alt+j", command = "editor.action.rename", when = "editorLangId == 'python'" })
  append({ key = "ctrl+alt+l", command = "editor.action.rename", when = "terminalFocus" })
  assert(sync.pull())
  local health = sync.health()
  assert(health.ok and #health.warnings == 3)
  assert(#vim.json.decode(read(sync.manifest_path)).routes == 1)
end)

check("removing a VS Code override restores the original shared action", function()
  append({ key = "ctrl+r", command = "editor.action.rename", when = "editorTextFocus" })
  assert(sync.pull())
  assert(invoke("<C-r>") == "Rename")
  assert(sync.push())
  local raw = read(sync.keybindings_path)
  local last = assert(raw:find("// END NVIM SHARED KEY ROUTES", 1, true))
  write(sync.keybindings_path, raw:sub(1, last + #"// END NVIM SHARED KEY ROUTES" - 1) .. "\n]\n")
  assert(sync.pull())
  assert(invoke("<C-r>") == "Recent")
  assert(#vim.json.decode(read(sync.manifest_path)).routes == 1)
end)

check("visual UI overrides do not erase normal shared actions", function()
  append({ key = "ctrl+r", command = "editor.action.quickFix", when = "editorTextFocus && neovim.mode == 'visual'" })
  assert(sync.pull())
  assert(invoke("<C-r>") == "Recent")
  assert(invoke("<C-r>", "x") == "Quick fix")
  assert(#vim.json.decode(read(sync.manifest_path)).routes == 2)
end)

check("key swaps capture original actions without remap loops in both hosts/modes", function()
  map("<F13>", "First", { "n", "x" })
  map("<F14>", "Second", { "n", "x" })
  local manifest = {
    version = 1,
    routes = {
      { key = "f13", command = "vscode-neovim.send", args = "<F14>", nvim = "<F14>", modes = { "n", "x" } },
      { key = "f14", command = "vscode-neovim.send", args = "<F13>", nvim = "<F13>", modes = { "n", "x" } },
    },
  }
  for _, embedded in ipairs({ false, true }) do
    vim.g.vscode = embedded
    sync.apply_aliases(manifest)
    for _, mode in ipairs({ "n", "x" }) do
      assert(invoke("<F13>", mode) == "Second")
      assert(invoke("<F14>", mode) == "First")
    end
    sync.clear_aliases()
    assert(invoke("<F13>") == "First")
    assert(invoke("<F14>") == "Second")
  end
end)

check("global aliases never capture buffer-local actions and restore Nop mappings", function()
  map("<F15>", "Global")
  vim.keymap.set("n", "<F15>", function()
    error("buffer-local mapping leaked globally")
  end, { buffer = 0 })
  vim.keymap.set("n", "<F16>", "", { desc = "No-op" })
  sync.apply_aliases({ routes = { { key = "f16", nvim = "<F15>" } } })
  assert(invoke("<F16>") == "Global")
  sync.clear_aliases()
  assert(vim.fn.maparg("<F16>", "n", false, true).desc == "No-op")
  vim.keymap.del("n", "<F15>", { buffer = 0 })
end)

check("shared Lua adds/removes leader and physical maps, with native host overrides", function()
  write(
    custom.path,
    [[return {
    { key = "<leader>kN", target = "<leader>fn", desc = "Twin new file" },
    { key = "<C-A-k>", target = "<F2>", desc = "Twin rename", modes = { "n", "x" } },
    { key = "<leader>kT", rhs = function() _G.twin_task = true end,
      vscode = "workbench.action.tasks.runTask", desc = "Twin task" },
  }]]
  )
  assert(custom.reload())
  assert(invoke("<leader>kN") == "New file")
  assert(invoke("<C-A-k>", "x") == "Rename")
  invoke("<leader>kT")
  assert(_G.twin_task)
  assert(#vim.json.decode(read(sync.manifest_path)).routes == 2)
  assert(read(sync.keybindings_path):find('"key": "ctrl+alt+k"', 1, true))
  assert(not read(sync.keybindings_path):find('"key": "space k n"', 1, true))
  vim.g.vscode = true
  assert(custom.reload())
  assert(invoke("<leader>kN") == "New file")
  assert(invoke("<leader>kT") == "workbench.action.tasks.runTask")
  write(custom.path, "return {}\n")
  assert(custom.reload())
  assert(vim.tbl_isempty(vim.fn.maparg("<leader>kN", "n", false, true)))
  assert(vim.tbl_isempty(vim.fn.maparg("<C-A-k>", "x", false, true)))
  assert(#vim.json.decode(read(sync.manifest_path)).routes == 1)
end)

check("VS Code physical key edits survive shared Lua reloads", function()
  write(custom.path, 'return { { key="<C-A-k>", target="<F2>", desc="Twin rename" } }\n')
  assert(custom.reload())
  local raw = read(sync.keybindings_path):gsub('"key": "ctrl%+alt%+k"', '"key": "ctrl+alt+j"')
  write(sync.keybindings_path, raw)
  assert(sync.pull())
  assert(custom.reload())
  assert(invoke("<C-A-j>") == "Rename")
  local route = vim.json.decode(read(sync.manifest_path)).routes[2]
  assert(route.key == "ctrl+alt+j")
end)

check("invalid Lua edits preserve the previous working shortcuts", function()
  write(custom.path, 'return { { key="<C-A-k>", target="<F2>", desc="Twin rename" } }\n')
  assert(custom.reload())
  write(custom.path, "return { invalid syntax !!!\n")
  assert(not custom.reload())
  assert(invoke("<C-A-k>") == "Rename")
  assert(#custom.errors == 1)
  write(custom.path, 'return { { key="<Space>", rhs="noop", desc="Break leader" } }\n')
  assert(not custom.reload(), "leader prefix was allowed to suppress the menu")
  assert(invoke("<C-A-k>") == "Rename")
end)

check("SharedKeysAdd writes a usable route without needing VS Code installed", function()
  assert(sync.add("<C-A-k>", "<F2>", { description = "Manual rename" }))
  assert(invoke("<C-A-k>") == "Rename")
  assert(sync.health().ok)
  assert(not sync.add("space k", "<F2>"), "Space chord suppressed the popup menu")
  assert(not sync.add("<Space>", "<F2>"), "leader prefix suppressed the popup menu")
  sync.keybindings_path = nil
  assert(sync.add("ctrl+alt+j", "<F2>"))
  assert(invoke("<C-A-j>") == "Rename")
  sync.keybindings_path = directory .. "/keybindings.json"
end)

check("live file watchers reload shared Lua and VS Code edits", function()
  sync.setup()
  assert(vim.wait(2000, function()
    return #sync._watchers == 3
  end))
  write(custom.path, 'return { { key="<C-A-k>", target="<F2>", desc="Live rename" } }\n')
  assert(vim.wait(2500, function()
    return vim.fn.maparg("<C-A-k>", "n", false, true).desc == "Live rename"
  end))
  assert(vim.wait(2500, function()
    return read(sync.keybindings_path):find('"key": "ctrl+alt+k"', 1, true) ~= nil
  end))
  write(sync.keybindings_path, read(sync.keybindings_path):gsub('"key": "ctrl%+alt%+k"', '"key": "ctrl+alt+l"'))
  assert(vim.wait(2500, function()
    return not vim.tbl_isempty(vim.fn.maparg("<C-A-l>", "n", false, true))
  end))
  assert(invoke("<C-A-l>") == "Rename")
  for _, watcher in ipairs(sync._watchers) do
    watcher:stop()
    watcher:close()
  end
  sync._watchers = {}
end)

sync.clear_aliases()
custom.clear()
vim.fn.delete(directory, "rf")
print(("All %d shared shortcut lifecycle checks passed"):format(passed))
