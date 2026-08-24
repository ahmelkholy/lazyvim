local api = vim.api
local config_root = vim.fn.stdpath("config")
local passed = 0
local failures = {}

local function check(name, callback)
  local ok, err = xpcall(callback, debug.traceback)
  if ok then
    passed = passed + 1
    print("PASS " .. name)
  else
    failures[#failures + 1] = name .. "\n" .. err
    print("FAIL " .. name)
  end
end

pcall(vim.cmd, "doautocmd User VeryLazy")
pcall(function()
  require("persistence").stop()
end)

check("all local Lua files parse", function()
  for _, path in ipairs(vim.fn.glob(config_root .. "/lua/**/*.lua", false, true)) do
    local chunk, err = loadfile(path)
    assert(chunk, err)
  end
end)

check("shortcut audit", function()
  local report = require("config.shortcut_health").check()
  assert(report.ok, table.concat(report.errors, "\n"))
end)

check("resource and native options", function()
  assert(vim.tbl_contains(vim.opt.diffopt:get(), "algorithm:histogram"))
  assert(vim.o.showtabline == 0)
  assert(vim.o.tabline == "")
  assert(require("lazy.core.config").options.checker.enabled == false)
  local snacks = require("lazyvim.util").opts("snacks.nvim")
  local lsp = require("lazyvim.util").opts("nvim-lspconfig")
  assert(require("lazyvim.util.pick").picker.name == "snacks")
  assert(snacks.picker.limit == 20000)
  assert(snacks.picker.limit_live == 2000)
  assert(snacks.picker.sources.files.cmd == "fd")
  assert(vim.tbl_contains(snacks.picker.sources.files.args, "--max-results"))
  assert(snacks.picker.sources.files.limit == 20000)
  assert(snacks.picker.sources.git_files.limit == 20000)
  assert(snacks.picker.sources.grep.limit_live == 2000)
  assert(snacks.picker.previewers.file.max_size == 2 * 1024 * 1024)
  assert(not require("lazy.core.config").plugins["fzf-lua"], "external fzf picker must stay disabled")
  assert(lsp.servers.copilot.enabled == false, "Copilot must stay off during headless maintenance")
  assert(lsp.servers.copilot.cmd_env.NODE_OPTIONS:find("--max-old-space-size=512", 1, true))
  assert(lsp.servers.copilot.cmd_env.UV_THREADPOOL_SIZE == "2")
  local symbol = api.nvim_get_hl(0, { name = "SymbolLink", link = false })
  assert(symbol.fg, "SymbolLink has no foreground color")
end)

check("custom helpers are portable Lua", function()
  assert(#vim.fn.glob(config_root .. "/scripts/*.sh", false, true) == 0)
  assert(#vim.fn.glob(config_root .. "/scripts/*.py", false, true) == 0)

  local raster = require("config.png")
  local svg = require("config.svg_preview")
  local pixels =
    string.char(255, 0, 0, 0, 255, 0, 0, 0, 255, 255, 255, 255, 255, 255, 0, 0, 255, 255, 255, 0, 255, 128, 128, 128)
  local image = raster.decode_ppm("P6\n2 4\n255\n" .. pixels)
  local ansi = svg.render_ansi(image.pixels, 1)
  local visible = (ansi:gsub("\27%[[%d;?]*[A-Za-z]", ""))
  assert(image.width == 2 and image.height == 4)
  assert(ansi:find("\27[", 1, true), "high-resolution terminal output is missing ANSI color")
  assert(vim.fn.strchars(visible) >= 1, "Braille SVG cell is missing")

  local source = vim.fn.tempname() .. ".svg"
  vim.fn.writefile({
    [[<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><circle cx="16" cy="16" r="14" fill="#33aaff"/></svg>]],
  }, source)
  local command, format = svg.renderer_command(source, 64, 64)
  if command then
    local result = vim.system(command, { text = false, timeout = 12000 }):wait()
    vim.uv.fs_unlink(source)
    assert(result.code == 0, result.stderr)
    local rendered = format == "ppm" and raster.decode_ppm(result.stdout) or raster.decode(result.stdout)
    assert(rendered.width > 0 and rendered.height > 0, "Lua did not decode the rendered SVG")
  else
    vim.uv.fs_unlink(source)
  end
end)

check("top row stays pane-local", function()
  local buf = api.nvim_get_current_buf()
  local old_buftype = vim.bo[buf].buftype
  local old_filetype = vim.bo[buf].filetype
  local old_workspace = vim.t.workspace_name
  local old_statusline_winid = vim.g.statusline_winid
  local lualine = require("lazyvim.util").opts("lualine.nvim")

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].filetype = "neo-tree"
  vim.t.workspace_name = "workspace-title-check"
  vim.g.statusline_winid = api.nvim_get_current_win()
  local explorer_icon = lualine.winbar.lualine_a[1][1]()
  local explorer_title = lualine.winbar.lualine_c[1][1]()

  vim.bo[buf].filetype = old_filetype
  vim.bo[buf].buftype = old_buftype
  vim.t.workspace_name = old_workspace
  vim.g.statusline_winid = old_statusline_winid

  assert(explorer_icon == "󰙅")
  assert(explorer_title:find("workspace-title-check", 1, true))
end)

check("file transfer never targets Explorer", function()
  local workspace = require("config.workspace")
  vim.cmd("silent! only!")
  vim.cmd.edit(vim.fs.joinpath(config_root, "init.lua"))
  local left = api.nvim_get_current_win()
  local left_buf = api.nvim_get_current_buf()
  vim.cmd.vsplit(vim.fs.joinpath(config_root, "README.md"))
  local right = api.nvim_get_current_win()
  local moved = api.nvim_get_current_buf()

  vim.cmd("topleft vnew")
  local explorer = api.nvim_get_current_win()
  local explorer_buf = api.nvim_get_current_buf()
  vim.bo[explorer_buf].buftype = "nofile"
  vim.bo[explorer_buf].filetype = "neo-tree"
  api.nvim_set_current_win(right)

  local count = #api.nvim_tabpage_list_wins(0)
  assert(workspace.move_current_file(-1))
  assert(api.nvim_get_current_win() == left)
  assert(api.nvim_win_get_buf(left) == moved)
  assert(api.nvim_win_get_buf(right) == left_buf)
  assert(api.nvim_win_get_buf(explorer) == explorer_buf)
  assert(#api.nvim_tabpage_list_wins(0) == count)
  assert(not workspace.move_current_file(-1), "left boundary should be a no-op")
  assert(workspace.move_current_file(1))
  assert(not workspace.move_current_file(1), "right boundary should be a no-op")
  assert(api.nvim_win_get_buf(explorer) == explorer_buf)
end)

check("pane histories restore without eager loading", function()
  local workspace = require("config.workspace")
  vim.cmd("silent! only!")
  vim.cmd.edit(vim.fs.joinpath(config_root, "init.lua"))
  vim.cmd.vsplit(vim.fs.joinpath(config_root, "README.md"))
  vim.cmd.edit(vim.fs.joinpath(config_root, "lazyvim.json"))
  local readme = vim.fn.bufnr(vim.fs.joinpath(config_root, "README.md"))
  assert(workspace.save_session_histories())
  local encoded = vim.g.NvimWorkspacePaneHistoriesJson

  vim.cmd.close()
  if readme > 0 and api.nvim_buf_is_valid(readme) then
    api.nvim_buf_delete(readme, { force = true })
  end
  vim.cmd.vsplit(vim.fs.joinpath(config_root, "lazyvim.json"))
  local right = api.nvim_get_current_win()
  vim.g.NvimWorkspacePaneHistoriesJson = encoded
  assert(workspace.restore_session_histories())

  local restored
  for _, buf in ipairs(workspace.tabs(right)) do
    if vim.fs.basename(api.nvim_buf_get_name(buf)) == "README.md" then
      restored = buf
    end
  end
  assert(restored, "README.md was not restored to its pane")
  assert(not api.nvim_buf_is_loaded(restored), "hidden history file was loaded eagerly")
end)

check("long Markdown rendering stays viewport bounded", function()
  vim.cmd("silent! only!")
  vim.cmd.enew()
  local buf = api.nvim_get_current_buf()
  local lines = { "| Name | Value |", "| --- | --- |" }
  for index = 1, 2000 do
    lines[#lines + 1] = ("| row-%d | value-%d |"):format(index, index)
  end
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "markdown"
  require("config.markdown_tables").render(buf)

  local namespace = api.nvim_get_namespaces().responsive_markdown_tables
  assert(namespace, "Markdown table namespace is missing")
  local marks = api.nvim_buf_get_extmarks(buf, namespace, 0, -1, {})
  assert(#marks > 0, "Markdown table was not rendered")
  assert(#marks < 500, "Markdown renderer created unbounded viewport marks")
  assert(api.nvim_buf_line_count(buf) == #lines, "Markdown source rows changed")
  assert(vim.wo.wrap == false, "native wrapping was not suspended over the rendered table")
  assert(vim.wo.spell == true, "Markdown spelling aid was not enabled")
end)

if #failures > 0 then
  print(("\n%d checks passed; %d failed\n%s"):format(passed, #failures, table.concat(failures, "\n\n")))
  vim.cmd("cquit 1")
else
  print(("\nAll %d Neovim regression checks passed"):format(passed))
  vim.cmd("qa!")
end
