-- Run without plugins/UI: nvim --headless -u NONE -l scripts/integration_regression.lua
local config = vim.fs.dirname(vim.fs.dirname(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p")))
vim.opt.rtp:prepend(config)
vim.g.mapleader = " "
local passed = 0
local function write_raw(path, content)
  vim.fn.writefile(vim.split(content, "\n", { plain = true }), path, "b")
end
local function check(name, callback)
  local ok, err = xpcall(callback, debug.traceback)
  if not ok then
    error(name .. "\n" .. err)
  end
  passed = passed + 1
  print("PASS " .. name)
end

local jsonc = require("config.jsonc")
check("repository workspaces inherit shared Neovim settings", function()
  for _, file in ipairs({ ".vscode/settings.json", ".vscode/nvim.code-workspace" }) do
    local decoded = jsonc.decode(table.concat(vim.fn.readfile(config .. "/" .. file), "\n"))
    for key in pairs(decoded.settings or decoded) do
      assert(not key:find("^vscode%-neovim%."), "stale workspace override: " .. key)
    end
  end
end)

check("JSONC keeps URLs/Windows paths and accepts comments/trailing commas", function()
  local source = '\239\187\191[ /* header */ {"url":"https://test/a,//]", "path":"C:\\\\Users\\\\Name",}, // item\r\n]'
  local decoded = jsonc.decode(source)
  assert(decoded[1].url == "https://test/a,//]")
  assert(decoded[1].path == [[C:\Users\Name]])
  assert(#jsonc.strip(source) == #source, "stripping changed byte offsets")
  assert(not pcall(jsonc.decode, "[ /* unclosed ]"))
end)

check("portable sync initializes an existing JSONC array without removing user keys", function()
  local sync = require("config.key_sync")
  local original = sync.keybindings_path
  local original_manifest = sync.manifest_path
  local directory = vim.fn.tempname()
  vim.fn.mkdir(directory, "p")
  sync.keybindings_path = directory .. "/keybindings.json"
  sync.manifest_path = directory .. "/shared-keybindings.json"
  vim.fn.writefile(vim.fn.readfile(original_manifest, "b"), sync.manifest_path, "b")
  local source = '[\r\n {"key":"ctrl+9", "command":"user.command",}, // user key\r\n]\r\n'
  write_raw(sync.keybindings_path, source)
  local ok, err = sync.push()
  assert(ok, err)
  local raw = table.concat(vim.fn.readfile(sync.keybindings_path, "b"), "\n")
  assert(raw:find('"command":"user.command"', 1, true))
  assert(#jsonc.decode(raw) == 53)
  assert(not raw:gsub("\r\n", ""):find("\n"), "CRLF was not preserved")
  local once = raw
  assert(sync.push())
  assert(table.concat(vim.fn.readfile(sync.keybindings_path, "b"), "\n") == once, "push was not idempotent")
  -- VS Code permits trailing commas in the managed block, too.
  raw = raw:gsub("(  }\r\n  // END NVIM)", "  },\r\n  // END NVIM")
  write_raw(sync.keybindings_path, raw)
  assert(sync.pull())
  -- Corrupt source must be reported, never silently replaced at startup.
  write_raw(sync.keybindings_path, once:gsub('"key": "ctrl%+b"', '"key": INVALID'))
  local before = table.concat(vim.fn.readfile(sync.keybindings_path, "b"), "\n")
  assert(not sync.sync())
  assert(table.concat(vim.fn.readfile(sync.keybindings_path, "b"), "\n") == before)
  vim.fn.writefile({ "[", "// BEGIN NVIM SHARED KEY ROUTES", "]" }, sync.keybindings_path)
  assert(not sync.push(), "incomplete markers were duplicated")
  vim.uv.fs_unlink(sync.keybindings_path)
  assert(sync.sync(), "missing VS Code caused a startup error")
  sync.keybindings_path = nil
  assert(sync.sync(), "missing APPDATA caused a startup error")
  sync.keybindings_path = original
  sync.manifest_path = original_manifest
  vim.uv.fs_unlink(directory .. "/shared-keybindings.json")
  vim.fn.delete(directory, "d")
end)

local calls = {}
package.loaded.vscode = {
  action = function(command, opts)
    calls[#calls + 1] = { command = command, opts = opts }
  end,
  notify = function(message)
    error(message)
  end,
  get_config = function() end,
  update_config = function() end,
  call = function()
    error("Menu opening must not block on an RPC timeout")
  end,
}
vim.g.vscode = true
local parity = require("config.vscode_parity")
parity.setup()

check("embedded F11 uses native fullscreen, with Zen kept separate", function()
  vim.fn.maparg("<F11>", "n", false, true).callback()
  assert(calls[#calls].command == "workbench.action.toggleFullScreen")
  parity.run_leader("<Space>uz")
  assert(calls[#calls].command == "workbench.action.toggleZenMode")
end)

check("embedded leader menu covers effective maps and executes q q directly", function()
  local health = parity.health()
  assert(health.ok, table.concat(health.errors, "\n"))
  parity.show_leader()
  local opened = calls[#calls]
  assert(opened.command == "whichkey.show")
  local items = opened.opts.args[1]
  local function find(path)
    local current = items
    local found
    for char in path:gmatch(".") do
      found = nil
      for _, item in ipairs(current) do
        if item.key == char then
          found = item
          break
        end
      end
      assert(found, "missing menu path " .. path)
      current = found.bindings
    end
    return found
  end
  for path, command in pairs({
    qq = "workbench.action.closeWindow",
    wh = "workbench.action.focusLeftGroup",
    wl = "workbench.action.focusRightGroup",
  }) do
    local item = find(path)
    assert(item.command == "vscode-neovim.lua")
    assert(#item.args == 1, "extension accepts code only, not positional Lua parameters")
    local previous = #calls
    assert(loadstring(item.args[1]))()
    assert(#calls == previous + 1 and calls[#calls].command == command, path .. " re-entered the menu")
  end
  local invoked = false
  vim.keymap.set("n", "<leader>qq", function()
    invoked = true
  end, { buffer = 0, desc = "Buffer-local quit override" })
  parity.run_leader("<Space>qq")
  assert(invoked, "dispatch ignored a changed buffer-local mapping")
  vim.keymap.del("n", "<leader>qq", { buffer = 0 })
end)

local build = require("config.build")
check("unsupported Ctrl+B stays native instead of rebuilding or recursively mapping", function()
  vim.api.nvim_buf_set_name(0, "C:/Users/Test Name/plain.txt")
  vim.bo.filetype = "text"
  local original = vim.api.nvim_feedkeys
  local received, mode
  vim.api.nvim_feedkeys = function(keys, flags)
    received, mode = keys, flags
  end
  local previous = #calls
  build.run({ scroll = true })
  vim.api.nvim_feedkeys = original
  assert(#calls == previous, "unsupported Ctrl+B launched a build")
  assert(received == vim.api.nvim_replace_termcodes("<C-b>", true, false, true) and mode == "n")
end)

check("Ctrl+B restores native language build/run/preview commands", function()
  local expected = {
    python = "python.execInTerminal",
    julia = "language-julia.executeActiveFile",
    r = "r.runSource",
    matlab = "matlab.runFile",
    tex = "latex-workshop.build",
    markdown = "office.markdown.switch",
    csv = "edit-csv.edit",
    html = "simpleBrowser.show",
    c = "workbench.action.tasks.build",
    cpp = "workbench.action.tasks.build",
  }
  for filetype, command in pairs(expected) do
    vim.bo.filetype = filetype
    vim.fn.maparg("<C-b>", "n", false, true).callback()
    assert(calls[#calls].command == command, filetype .. " selected the wrong action")
  end
  vim.api.nvim_buf_set_name(0, "C:/Users/Test Name/art.svg")
  vim.bo.filetype = "xml"
  build.run()
  assert(calls[#calls].command == "svgeditor.openSvgEditor")
end)

check("Windows standalone builds use argv, virtualenvs and .exe outputs", function()
  vim.g.vscode = false
  vim.api.nvim_buf_set_name(0, "C:/Project With Spaces/main.py")
  local original = { has = vim.fn.has, exepath = vim.fn.exepath, executable = vim.fn.executable, system = vim.system }
  local original_build = { root = build.root, current_file = build.current_file, terminal = build.terminal }
  local previous_venv = vim.env.VIRTUAL_ENV
  vim.env.VIRTUAL_ENV = "C:/Project With Spaces/.venv"
  vim.fn.has = function(feature)
    return feature == "win32" and 1 or original.has(feature)
  end
  vim.fn.exepath = function(name)
    return "C:/Program Files/Tools/" .. name .. ".exe"
  end
  vim.fn.executable = function(path)
    return path:find("/Scripts/python.exe", 1, true) and 1 or 0
  end
  build.root = function()
    return "C:/Project With Spaces"
  end
  build.current_file = function()
    return "C:/Project With Spaces/main.py"
  end
  local launched, compiled
  build.terminal = function(argv, cwd)
    launched = { argv = argv, cwd = cwd }
  end
  vim.bo.filetype = "python"
  build.run()
  assert(launched.argv[1] == "C:/Project With Spaces/.venv/Scripts/python.exe")
  assert(launched.argv[2] == "C:/Project With Spaces/main.py")
  build.current_file = function()
    return "C:/Project With Spaces/main.cpp"
  end
  vim.system = function(argv, opts, callback)
    compiled = { argv = argv, opts = opts }
    callback({ code = 0, stdout = "", stderr = "" })
  end
  vim.bo.filetype = "cpp"
  build.run()
  assert(compiled.argv[1] == "C:/Program Files/Tools/g++.exe")
  assert(compiled.argv[2] == "C:/Project With Spaces/main.cpp")
  assert(compiled.argv[#compiled.argv]:match("%.exe$"))
  assert(compiled.opts.cwd == "C:/Project With Spaces")
  vim.wait(1000, function()
    return launched.argv[1] == compiled.argv[#compiled.argv]
  end)
  assert(launched.argv[1] == compiled.argv[#compiled.argv])
  vim.fn.has, vim.fn.exepath, vim.fn.executable, vim.system =
    original.has, original.exepath, original.executable, original.system
  build.root, build.current_file, build.terminal =
    original_build.root, original_build.current_file, original_build.terminal
  vim.env.VIRTUAL_ENV = previous_venv
end)

print(("All %d editor integration checks passed"):format(passed))
