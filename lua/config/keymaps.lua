-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set

if vim.g.vscode then
  return
end

-- A conservative VS Code bridge for standalone Neovim. Only keys that do not
-- replace core Neovim motions, undo, window, scrolling, or terminal controls
-- belong here.
local function workspace_root()
  return require("config.workspace").root() or vim.fn.getcwd()
end

local function current_file_path()
  if vim.bo.buftype ~= "" then
    return nil
  end

  local path = vim.api.nvim_buf_get_name(0)
  if path == "" or path:match("^%a[%w+.-]*://") then
    return nil
  end
  return vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
end

local function toggle_explorer()
  require("config.workspace").toggle_explorer()
end

local function focus_explorer()
  require("config.workspace").open_or_focus_explorer()
end

local function reveal_explorer()
  require("config.workspace").reveal_current_file()
end

local function terminal()
  Snacks.terminal.focus(nil, { cwd = workspace_root() })
end

local function new_terminal()
  local ok, err = pcall(vim.cmd, "botright split | terminal")
  if not ok then
    vim.notify(err, vim.log.levels.ERROR, { title = "Terminal" })
  end
end

local function cli_terminal(command)
  if vim.fn.executable(command) == 0 then
    vim.notify(command .. " is not installed or is not on PATH", vim.log.levels.WARN)
    return
  end
  Snacks.terminal({ command }, { cwd = workspace_root() })
end

local function copy_current_path()
  local path = current_file_path()
  if not path then
    vim.notify("The current buffer is not a filesystem file", vim.log.levels.WARN)
    return
  end
  vim.fn.setreg("+", path)
  vim.fn.setreg('"', path)
  vim.notify("Copied: " .. path)
end

local function paste_terminal_clipboard()
  local channel = vim.b.terminal_job_id
  if channel then
    vim.api.nvim_chan_send(channel, vim.fn.getreg("+"))
  end
end

local function markdown_links()
  require("fzf-lua").live_grep({ search = [[\[\[]], prompt = "Markdown links> " })
end

local function daily_note()
  local directory = workspace_root() .. "/notes/daily"
  vim.fn.mkdir(directory, "p")
  vim.cmd.edit(vim.fn.fnameescape(directory .. "/" .. os.date("%Y-%m-%d") .. ".md"))
end

local function lsp_action(method, callback, label)
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
    local ok, supported = pcall(client.supports_method, client, method)
    if ok and supported then
      callback()
      return
    end
  end
  vim.notify("No attached language server supports " .. label, vim.log.levels.WARN, { title = "LSP" })
end

local function gitsigns_action(action, ...)
  if type(vim.b.gitsigns_status_dict) ~= "table" then
    vim.notify("Git signs are not attached to this buffer", vim.log.levels.WARN, { title = "Git" })
    return
  end
  local ok, gitsigns = pcall(require, "gitsigns")
  if not ok or type(gitsigns[action]) ~= "function" then
    vim.notify("Git signs action is unavailable: " .. action, vim.log.levels.WARN, { title = "Git" })
    return
  end
  gitsigns[action](...)
end

local function git_root()
  return vim.fs.root(workspace_root(), ".git")
end

local function new_named_file()
  vim.ui.input({ prompt = "New file: ", default = workspace_root() .. "/" }, function(path)
    if path and path ~= "" then
      vim.cmd.edit(vim.fn.fnameescape(vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))))
    end
  end)
end

local function safe_alternate_buffer()
  local alternate = vim.fn.bufnr("#")
  if alternate < 0 or not vim.api.nvim_buf_is_valid(alternate) or not vim.bo[alternate].buflisted then
    vim.notify("There is no alternate file in this pane", vim.log.levels.WARN)
    return
  end
  vim.api.nvim_win_set_buf(0, alternate)
end

local function safe_close_window()
  local windows = vim.tbl_filter(function(win)
    return vim.api.nvim_win_get_config(win).relative == ""
  end, vim.api.nvim_tabpage_list_wins(0))
  if #windows <= 1 then
    vim.notify("This is the only window; use a buffer or workspace close action instead", vim.log.levels.WARN)
    return
  end
  local ok, err = pcall(vim.cmd, "confirm close")
  if not ok then
    vim.notify(err, vim.log.levels.ERROR, { title = "Close window" })
  end
end

local function safe_write()
  if not current_file_path() then
    vim.notify("Name the file before saving it", vim.log.levels.WARN)
    return
  end
  local ok, err = pcall(vim.cmd, "noautocmd write")
  if not ok then
    vim.notify(err, vim.log.levels.ERROR, { title = "Save" })
  end
end

map("n", "<C-A-d>", focus_explorer, { desc = "Explorer: open or focus" })
map("n", "<C-S-e>", toggle_explorer, { desc = "Explorer: toggle and reveal file" })
map("n", "<C-S-f>", toggle_explorer, { desc = "Toggle activity/sidebar" })
map("n", "<A-f>", toggle_explorer, { desc = "Explorer: toggle and reveal file" })
map("n", "<F2>", reveal_explorer, { desc = "Explorer: reveal active file" })

map("n", "<C-S-p>", "<cmd>FzfLua commands<cr>", { desc = "Command Palette" })
map("n", "<C-A-q>", LazyVim.pick("live_grep"), { desc = "Search: find in files" })
map("n", "<leader>fw", function()
  require("config.workspaces").show()
end, { desc = "Workspaces" })
map("n", "<leader>wa", function()
  require("config.workspaces").add(vim.fn.getcwd())
end, { desc = "Workspace: save current" })
map("n", "<leader>wc", function()
  require("config.workspaces").close()
end, { desc = "Workspace: close tab" })

map("n", "<C-Tab>", function()
  require("config.workspace").cycle_tabs(1)
end, { desc = "Next tab in pane" })
map("n", "<C-S-Tab>", function()
  require("config.workspace").cycle_tabs(-1)
end, { desc = "Previous tab in pane" })

-- The labels above each editor window are pane-local buffers, not Neovim tab
-- pages. Override LazyVim's real-tab menu so Space+Tab operates on those labels.
map("n", "<leader><tab><tab>", function()
  require("config.workspace").cycle_tabs(1)
end, { desc = "Pane tab: next" })
map("n", "<leader><tab>]", function()
  require("config.workspace").cycle_tabs(1)
end, { desc = "Pane tab: next" })
map("n", "<leader><tab>[", function()
  require("config.workspace").cycle_tabs(-1)
end, { desc = "Pane tab: previous" })
map("n", "<leader><tab>f", function()
  require("config.workspace").select_tab(1)
end, { desc = "Pane tab: first" })
map("n", "<leader><tab>l", function()
  require("config.workspace").select_tab(-1)
end, { desc = "Pane tab: last" })
map("n", "<leader><tab>d", function()
  require("config.workspace").close_current_tab()
end, { desc = "Pane tab: close file" })
map("n", "<leader><tab>o", function()
  require("config.workspace").close_other_tabs()
end, { desc = "Pane tab: close others" })
for index = 1, 4 do
  local tab_index = index
  map("n", "<leader><tab>" .. tab_index, function()
    require("config.workspace").select_tab(tab_index)
  end, { desc = "Pane tab: select " .. tab_index })
end
map("n", "<leader><tab>w", function()
  require("config.workspaces").show()
end, { desc = "Workspaces" })
map("n", "<C-S-n>", "<cmd>tab split<cr>", { desc = "Move editor to new tab" })
map("n", "<S-A-q>", "<cmd>confirm qall<cr>", { desc = "Close Neovim" })
map({ "n", "t" }, "<A-t>", terminal, { desc = "Toggle terminal" })
map({ "n", "t" }, "<C-A-b>", terminal, { desc = "Toggle terminal panel" })
map("n", "<A-b>", new_terminal, { desc = "New terminal" })
map({ "n", "t" }, "<C-S-b>", new_terminal, { desc = "New terminal" })

local function send_terminal_continuation()
  local channel = vim.b.terminal_job_id
  if channel then
    vim.api.nvim_chan_send(channel, "\\\n")
  end
end

map("t", "<S-CR>", send_terminal_continuation, { desc = "Terminal: continue command" })
map("t", "<C-CR>", send_terminal_continuation, { desc = "Terminal: continue command" })
map("t", "<C-S-v>", paste_terminal_clipboard, { desc = "Terminal: paste" })
map("t", "<A-Up>", [[<C-\><C-n><C-w>w]], { desc = "Terminal: focus next" })
map("t", "<A-Down>", [[<C-\><C-n><C-w>W]], { desc = "Terminal: focus previous" })

map({ "n", "x" }, "<S-A-f>", function()
  local ok, err = pcall(LazyVim.format, { force = true })
  if not ok then
    vim.notify(err, vim.log.levels.ERROR, { title = "Format" })
  end
end, { desc = "Format document" })

map("n", "<S-A-2>", "<C-w>v", { remap = true, desc = "Split editor right" })
map("n", "<C-A-w>", "<C-w>H", { remap = true, desc = "Move editor group left" })
map("n", "<C-A-e>", "<C-w>L", { remap = true, desc = "Move editor group right" })
map("n", "<C-A-t>", function()
  Snacks.zen.zoom()
end, { desc = "Toggle maximized panel" })
map("n", "<F11>", function()
  Snacks.zen()
end, { desc = "Toggle fullscreen / Zen mode" })
map("n", "<C-A-f>", function()
  local ok, aerial = pcall(require, "aerial")
  if ok then
    aerial.toggle({ focus = false, direction = "right" })
  else
    vim.notify("Aerial is unavailable", vim.log.levels.WARN)
  end
end, { desc = "Toggle auxiliary sidebar" })

map("n", "<F12>", function()
  lsp_action("textDocument/definition", vim.lsp.buf.definition, "go to definition")
end, { desc = "Go to definition" })
map("n", "<S-F12>", function()
  lsp_action("textDocument/references", vim.lsp.buf.references, "references")
end, { desc = "Go to references" })
map({ "n", "x" }, "<C-.>", function()
  lsp_action("textDocument/codeAction", vim.lsp.buf.code_action, "code actions")
end, { desc = "Quick fix / code action" })

map("n", "<A-Left>", "<C-o>", { remap = true, desc = "Navigate back" })
map("n", "<A-Right>", "<C-i>", { remap = true, desc = "Navigate forward" })
map("n", "<C-A-g>", function()
  local root = git_root()
  if root then
    Snacks.lazygit({ cwd = root })
  else
    vim.notify("The current workspace is not a Git repository", vim.log.levels.WARN, { title = "Git" })
  end
end, { desc = "Source control" })
map("n", "<C-A-v>", function()
  local root = git_root()
  if root then
    require("fzf-lua").git_status({ cwd = root })
  else
    vim.notify("The current workspace is not a Git repository", vim.log.levels.WARN, { title = "Git" })
  end
end, { desc = "Source control files" })
map("n", "<A-,>", function()
  gitsigns_action("nav_hunk", "prev")
end, { desc = "Previous change" })
map("n", "<A-.>", function()
  gitsigns_action("nav_hunk", "next")
end, { desc = "Next change" })
map("n", "<A-r>", function()
  gitsigns_action("preview_hunk")
end, { desc = "Preview change" })

map("n", "<A-d>", function()
  local path = current_file_path()
  local ok, result, open_err = pcall(vim.ui.open, path and vim.fs.dirname(path) or workspace_root())
  if not ok then
    vim.notify(result, vim.log.levels.ERROR, { title = "System explorer" })
  elseif open_err then
    vim.notify(open_err, vim.log.levels.ERROR, { title = "System explorer" })
  end
end, { desc = "Reveal file in system explorer" })
map("n", "<C-A-s>", copy_current_path, { desc = "Copy file path" })
map("n", "<C-A-p>", "<cmd>Lazy<cr>", { desc = "Package explorer" })
map("n", "<C-S-g>", markdown_links, { desc = "Markdown link graph" })
map("n", "<C-S-Left><Delete>", daily_note, { desc = "Open daily note" })

map("n", "<C-S-A-r>", function()
  vim.opt_local.rightleft = not vim.opt_local.rightleft:get()
end, { desc = "Toggle right-to-left display" })

map({ "n", "x" }, "<A-a>", "<leader>aa", { remap = true, desc = "AI chat" })
map({ "n", "x" }, "<C-A-a>", "<leader>aa", { remap = true, desc = "AI chat" })
map({ "n", "x" }, "<C-S-i>", "<leader>aq", { remap = true, desc = "AI quick chat" })
map({ "n", "x" }, "<S-A-a>", "<leader>ap", { remap = true, desc = "AI prompt actions" })
map({ "n", "x" }, "<C-A-c>", "<leader>aa", { remap = true, desc = "AI chat" })
map("n", "<A-g>", function()
  cli_terminal("gemini")
end, { desc = "Gemini CLI" })
map("n", "<C-A-o>", function()
  cli_terminal("opencode")
end, { desc = "OpenCode CLI" })
map("n", "<C-A-x>", function()
  cli_terminal("claude")
end, { desc = "Claude CLI" })
map("n", "<S-A-b>", function()
  cli_terminal("matlab")
end, { desc = "MATLAB command window" })
map("n", "<C-A-n>", function()
  cli_terminal("matlab")
end, { desc = "MATLAB terminal" })

-- Harden fragile LazyVim defaults so missing context produces a useful message
-- instead of an editor error such as E23, E32, E444, or E784.
map("n", "<leader>W", safe_write, { desc = "Save without formatting" })
map("n", "<leader>bb", safe_alternate_buffer, { desc = "Switch to other buffer" })
map("n", "<leader>`", safe_alternate_buffer, { desc = "Switch to other buffer" })
map("n", "<leader>fn", new_named_file, { desc = "New named file" })
map("n", "<leader>wd", safe_close_window, { desc = "Close window safely" })
map("n", "<leader>bD", function()
  require("config.workspace").close_current_tab()
end, { desc = "Close pane file safely" })
map("n", "<leader>qq", "<cmd>confirm qall<cr>", { desc = "Quit all safely" })
