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
  assert(require("lazy.core.config").options.ui.size.width == 0.8)
  assert(require("lazy.core.config").options.ui.size.height == 0.8)
  assert(require("lazy.core.config").options.ui.backdrop == 60)
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
  assert(lsp.servers.julials, "Julia language server is not configured")
  local treesitter = require("lazyvim.util").opts("nvim-treesitter")
  assert(vim.tbl_contains(treesitter.ensure_installed, "julia"), "Julia Treesitter parser is not configured")
  local completion = require("lazyvim.util").opts("blink.cmp")
  assert(completion.keymap.preset == "super-tab", "Tab is not configured to accept completion")
  assert(vim.deep_equal(completion.keymap["<CR>"], { "fallback" }), "Enter must remain a normal newline")
  local arabic = require("config.arabic").status()
  assert(arabic.encoding == "utf-8", "Arabic requires UTF-8")
  assert(arabic.arabicshape, "Arabic shaping is disabled")
  assert(arabic.delcombine, "Arabic combined-character deletion is disabled")
  assert(arabic.termbidi == arabic.terminal_bidi, "terminal bidi selection does not match terminal support")
  assert(not arabic.rightleft, "code and Markdown must stay in an LTR window")
  assert(
    arabic.alignment == (arabic.termbidi and arabic.alignment_available),
    "Arabic alignment does not match this Neovim/terminal capability"
  )
  assert(arabic.keymap == "" and arabic.input == "automatic", "OS-layout input is not in automatic mode")
  assert(arabic.separator == "│", "pane separator does not match the connected remote UI")
  assert(require("config.arabic").contains_arabic("# ويستخدم promote و Float64"))
  assert(not require("config.arabic").contains_arabic("English source code"))
  assert(require("config.arabic").line_direction("## هذه جملة with English 123") == "rtl")
  assert(require("config.arabic").line_direction("English ثم العربية") == "ltr")
  assert(require("config.arabic").line_direction("Русский ثم العربية") == "ltr")
  assert(require("config.arabic").line_direction("العربية ثم Русский") == "rtl")
  local sample = "هذه جملة عربية"
  local padding = require("config.arabic").padding_for_line(sample, 40)
  assert(padding + vim.fn.strdisplaywidth(sample) == 39, "Arabic line escaped its one-cell pane margin")
  assert(vim.fn.exists(":Arabic") == 2 and vim.fn.exists(":ArabicAuto") == 2)
  assert(vim.fn.exists(":ArabicStatus") == 2)
  assert(vim.fn.exists(":ArabicInput") == 0 and vim.fn.exists(":RussianInput") == 0)
  assert(vim.fn.exists(":EnglishInput") == 0)
  local input_mapping = vim.fn.maparg("<leader>ui", "n", false, true)
  assert(not (input_mapping.desc or ""):lower():find("input", 1, true), "<leader>ui still switches input modes")
  assert(vim.g.neovide_fullscreen == nil, "Neovim must not resize the terminal or GUI at startup")
  local zoom_mapping = vim.fn.maparg("<C-A-t>", "n", false, true)
  assert(zoom_mapping.desc == "Toggle maximized panel", "the remote panel zoom mapping was not restored")
  local zen_mapping = vim.fn.maparg("<F11>", "n", false, true)
  assert(zen_mapping.desc == "Toggle fullscreen / Zen mode", "the remote internal Zen mapping was not restored")
  local arabic_config = require("config.arabic")
  assert(arabic_config.detect_terminal_bidi({ TERM_PROGRAM = "Apple_Terminal" }))
  assert(arabic_config.detect_terminal_bidi({ TERM_PROGRAM = "mlterm" }))
  assert(arabic_config.detect_terminal_bidi({ VTE_VERSION = "5800" }))
  assert(arabic_config.detect_terminal_bidi({ KONSOLE_VERSION = "240800" }))
  assert(not arabic_config.detect_terminal_bidi({ WT_SESSION = "test" }))
  assert(not arabic_config.detect_terminal_bidi({ TERM_PROGRAM = "WezTerm" }))
  assert(not arabic_config.detect_terminal_bidi({ TERM = "xterm-kitty" }))
  assert(arabic_config.detect_terminal_bidi({ TERM_PROGRAM = "WezTerm", NVIM_TUI_BIDI = "1" }))
  assert(arabic_config.detect_input_script("العربية") == "arabic")
  assert(arabic_config.detect_input_script("Русский") == "russian")
  assert(arabic_config.detect_input_script("English") == "english")
  assert(arabic_config.detect_input_script("123 —") == nil)
  local multilingual = require("config.multilingual_keys")
  assert(not vim.o.langremap and vim.o.langmap ~= "", "multilingual Normal-mode translation is disabled")
  assert(multilingual.translate("م") == "l" and multilingual.translate("ا") == "h")
  assert(multilingual.translate("д") == "l" and multilingual.translate("о") == "j")
  assert(multilingual.translate("٥") == "5" and multilingual.translate("۵") == "5")
  local symbol = api.nvim_get_hl(0, { name = "SymbolLink", link = false })
  assert(symbol.fg, "SymbolLink has no foreground color")
end)

check("network proxy discovery stays secure and portable", function()
  local network = require("config.network")
  local macos = [[
<dictionary> {
  HTTPEnable : 1
  HTTPPort : 10808
  HTTPProxy : 127.0.0.1
  HTTPSEnable : 1
  HTTPSPort : 10808
  HTTPSProxy : 127.0.0.1
}
]]
  assert(network.parse_macos_proxy(macos) == "http://127.0.0.1:10808")
  assert(network.parse_macos_proxy("<dictionary> { HTTPSEnable : 0 }") == nil)
  assert(vim.g.nvim_network_proxy_initialized)
  assert(vim.env.GIT_SSL_NO_VERIFY == nil, "TLS verification must never be disabled")
end)

check("normal editor consumes the complete Neovim grid", function()
  vim.cmd("silent! only!")
  vim.cmd("silent! enew!")
  local win = api.nvim_get_current_win()
  assert(api.nvim_win_get_config(win).relative == "", "the main editor is an inset floating window")
  assert(api.nvim_win_get_width(win) == vim.o.columns, "the main editor leaves unused grid columns")

  local reserved_rows = vim.o.cmdheight
  if vim.o.laststatus == 3 or (vim.o.laststatus == 2 and #api.nvim_tabpage_list_wins(0) > 1) then
    reserved_rows = reserved_rows + 1
  end
  if vim.o.showtabline == 2 or (vim.o.showtabline == 1 and #api.nvim_list_tabpages() > 1) then
    reserved_rows = reserved_rows + 1
  end
  assert(api.nvim_win_get_height(win) + reserved_rows == vim.o.lines, "the main editor leaves unused grid rows")
end)

check("Arabic and Russian layouts execute physical Vim keys", function()
  vim.cmd("silent! enew!")
  local buf = api.nvim_get_current_buf()
  vim.bo[buf].buftype = "nofile"
  api.nvim_buf_set_lines(buf, 0, -1, false, { "abcdef" })

  local function expect_column(input, start, expected)
    api.nvim_win_set_cursor(0, { 1, start })
    vim.fn.feedkeys(input, "xt")
    assert(api.nvim_win_get_cursor(0)[2] == expected, ("%s did not act on its physical Vim key"):format(input))
  end

  expect_column("م", 0, 1) -- Arabic physical l
  expect_column("ا", 3, 2) -- Arabic physical h
  expect_column("д", 0, 1) -- Russian physical l
  expect_column("р", 3, 2) -- Russian physical h

  api.nvim_buf_set_lines(buf, 0, -1, false, { "one two three" })
  expect_column("لا", 12, 8) -- Arabic physical b emits LAM + ALEF

  local input = require("config.arabic")
  api.nvim_buf_set_lines(buf, 0, -1, false, { "" })
  vim.fn.feedkeys("iش\027", "xt")
  assert(api.nvim_buf_get_lines(buf, 0, 1, false)[1] == "ش", "OS Arabic text was translated in Insert mode")
  assert(input.input_language() == "arabic" and input.input_status() == "AR")
  vim.fn.feedkeys("aЯ\027", "xt")
  assert(input.input_language() == "russian" and input.input_status() == "RU")
  vim.fn.feedkeys("aE\027", "xt")
  assert(input.input_language() == "english" and input.input_status() == "")
  vim.b.multilingual_input_script = nil
  vim.bo[buf].modified = false
end)

check("Arabic alignment stays inside stable unequal splits", function()
  vim.cmd("silent! only!")
  vim.cmd("silent! enew!")
  local arabic = require("config.arabic")
  local buf = api.nvim_get_current_buf()
  local sample = "مرحبا with x"
  api.nvim_buf_set_lines(buf, 0, -1, false, { sample, "English ثم العربية" })
  vim.bo[buf].filetype = "text"
  arabic.mixed(true, true)

  local left = api.nvim_get_current_win()
  vim.cmd("vsplit")
  local right = api.nvim_get_current_win()
  vim.cmd("vertical resize 24")
  vim.wo[left].wrap = true
  vim.wo[right].wrap = true
  local widths_before = { api.nvim_win_get_width(left), api.nvim_win_get_width(right) }

  arabic.refresh_alignment(left)
  arabic.refresh_alignment(right)
  assert(vim.deep_equal(widths_before, { api.nvim_win_get_width(left), api.nvim_win_get_width(right) }))
  assert(api.nvim_buf_get_lines(buf, 0, -1, false)[1] == sample, "display alignment changed the source")

  local paddings = {}
  for _, win in ipairs({ left, right }) do
    local namespace = api.nvim_get_namespaces()["arabic_line_alignment_" .. win]
    assert(namespace, "split has no window-scoped Arabic alignment namespace")
    local marks = api.nvim_buf_get_extmarks(buf, namespace, 0, -1, { details = true })
    assert(#marks == 1 and marks[1][2] == 0, "only the Arabic-first line should align right")
    local padding = marks[1][4].virt_text[1][1]
    local info = vim.fn.getwininfo(win)[1]
    local text_width = info.width - info.textoff
    assert(#padding == arabic.padding_for_line(sample, text_width))
    assert(#padding + vim.fn.strdisplaywidth(sample) == text_width - 1, "Arabic crossed the pane margin")
    paddings[#paddings + 1] = #padding
  end
  assert(paddings[1] ~= paddings[2], "unequal panes incorrectly share one alignment width")

  vim.bo[buf].modified = false
  vim.cmd("silent! only!")
  arabic.auto(true)
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

check("remote Markdown tables stay connected and viewport bounded", function()
  vim.cmd("silent! only!")
  vim.cmd.enew()
  local buf = api.nvim_get_current_buf()
  local lines = { "| Name | Value |", "| --- | --- |" }
  for index = 1, 2000 do
    lines[#lines + 1] = ("| row-%d | value-%d |"):format(index, index)
  end
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "markdown"
  local markdown_tables = require("config.markdown_tables")
  markdown_tables.render(buf)

  local namespace = api.nvim_get_namespaces().responsive_markdown_tables
  assert(namespace, "Markdown table namespace is missing")
  local marks = api.nvim_buf_get_extmarks(buf, namespace, 0, -1, { details = true })
  assert(#marks > 0, "Markdown table was not rendered")
  assert(#marks < 500, "Markdown renderer created unbounded viewport marks")
  local rendered = vim.inspect(marks)
  assert(rendered:find("│", 1, true), "Markdown tables do not use connected vertical borders")
  assert(not rendered:find("ǀ", 1, true), "Markdown tables still use the disconnected local separator")
  assert(api.nvim_buf_line_count(buf) == #lines, "Markdown source rows changed")
  assert(markdown_tables.contains_line(buf, 1), "local multilingual table detection was not preserved")
  assert(vim.wo.wrap == false, "the remote table renderer did not suspend native wrapping")
  assert(vim.wo.spell == true, "the remote Markdown spelling presentation was not restored")
end)

if #failures > 0 then
  print(("\n%d checks passed; %d failed\n%s"):format(passed, #failures, table.concat(failures, "\n\n")))
  vim.cmd("cquit 1")
else
  print(("\nAll %d Neovim regression checks passed"):format(passed))
  vim.cmd("qa!")
end
