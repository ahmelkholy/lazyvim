-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set

map("n", ";", ":", { remap = true, desc = "Command mode" })

if vim.g.vscode then
  return
end

-- VS Code muscle-memory bridge for standalone Neovim. These mappings avoid
-- replacing core Neovim controls such as C-w, C-r, C-i, C-h/j/k/l, C-f, and C-/.
local function toggle_explorer()
  vim.cmd("Neotree toggle reveal_force_cwd dir=" .. vim.fn.fnameescape(LazyVim.root()))
end

local function reveal_explorer()
  vim.cmd("Neotree reveal reveal_force_cwd dir=" .. vim.fn.fnameescape(LazyVim.root()))
end

local function terminal()
  Snacks.terminal.focus(nil, { cwd = LazyVim.root() })
end

local function cli_terminal(command)
  if vim.fn.executable(command) == 0 then
    vim.notify(command .. " is not installed or is not on PATH", vim.log.levels.WARN)
    return
  end
  Snacks.terminal({ command }, { cwd = LazyVim.root() })
end

local function copy_current_path()
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" then
    vim.notify("The current buffer has no file path", vim.log.levels.WARN)
    return
  end
  vim.fn.setreg("+", path)
  vim.fn.setreg('"', path)
  vim.notify("Copied: " .. path)
end

map("n", "<C-A-d>", toggle_explorer, { desc = "Explorer: toggle and reveal file" })
map("n", "<C-S-e>", toggle_explorer, { desc = "Explorer: toggle and reveal file" })
map("n", "<A-f>", toggle_explorer, { desc = "Explorer: toggle and reveal file" })
map("n", "<F2>", reveal_explorer, { desc = "Explorer: reveal active file" })

map("n", "<C-p>", LazyVim.pick("files"), { desc = "Quick Open: files" })
map("n", "<C-S-p>", "<cmd>FzfLua commands<cr>", { desc = "Command Palette" })
map("n", "<C-A-q>", LazyVim.pick("live_grep"), { desc = "Search: find in files" })

map("n", "<C-q>", function()
  Snacks.bufdelete()
end, { desc = "Close active editor" })
map("n", "<C-Tab>", "<cmd>bnext<cr>", { desc = "Next editor" })
map("n", "<C-S-Tab>", "<cmd>bprevious<cr>", { desc = "Previous editor" })
map("n", "<C-S-n>", "<cmd>tab split<cr>", { desc = "Move editor to new tab" })
map("n", "<S-A-q>", "<cmd>confirm qall<cr>", { desc = "Close Neovim" })

map({ "n", "t" }, "<A-t>", terminal, { desc = "Toggle terminal" })
map({ "n", "t" }, "<C-A-b>", terminal, { desc = "Toggle terminal panel" })
map("n", "<A-b>", "<cmd>botright split | terminal<cr>", { desc = "New terminal" })

local function send_terminal_continuation()
  local channel = vim.b.terminal_job_id
  if channel then
    vim.api.nvim_chan_send(channel, "\\\n")
  end
end

map("t", "<S-CR>", send_terminal_continuation, { desc = "Terminal: continue command" })
map("t", "<C-CR>", send_terminal_continuation, { desc = "Terminal: continue command" })
map("t", "<C-S-b>", [[<C-\><C-n><cmd>botright split | terminal<cr>]], { desc = "Split terminal" })

map({ "n", "x" }, "<S-A-f>", function()
  LazyVim.format({ force = true })
end, { desc = "Format document" })

map("n", "<S-A-2>", "<C-w>v", { remap = true, desc = "Split editor right" })
map("n", "<C-A-w>", "<C-w>H", { remap = true, desc = "Move editor group left" })
map("n", "<C-A-e>", "<C-w>L", { remap = true, desc = "Move editor group right" })

map("n", "<F12>", vim.lsp.buf.definition, { desc = "Go to definition" })
map("n", "<S-F12>", vim.lsp.buf.references, { desc = "Go to references" })
map({ "n", "x" }, "<C-.>", vim.lsp.buf.code_action, { desc = "Quick fix / code action" })

map("n", "<A-Left>", "<C-o>", { remap = true, desc = "Navigate back" })
map("n", "<A-Right>", "<C-i>", { remap = true, desc = "Navigate forward" })
map("n", "<C-A-g>", function()
  Snacks.lazygit({ cwd = LazyVim.root.git() })
end, { desc = "Source control" })
map("n", "<C-A-v>", "<cmd>FzfLua git_status<cr>", { desc = "Source control files" })
map("n", "<A-,>", function()
  require("gitsigns").nav_hunk("prev")
end, { desc = "Previous change" })
map("n", "<A-.>", function()
  require("gitsigns").nav_hunk("next")
end, { desc = "Next change" })
map("n", "<A-r>", function()
  require("gitsigns").preview_hunk()
end, { desc = "Preview change" })

map("n", "<A-d>", function()
  local path = vim.api.nvim_buf_get_name(0)
  vim.ui.open(path ~= "" and vim.fs.dirname(path) or LazyVim.root())
end, { desc = "Reveal file in system explorer" })
map("n", "<C-A-s>", copy_current_path, { desc = "Copy file path" })

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

map("n", "<leader>W", "<cmd>noautocmd write<cr>", { desc = "Save without formatting" })

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("vscode_bridge_filetypes", { clear = true }),
  pattern = "markdown",
  callback = function(event)
    map("n", "<A-b>", "<cmd>MarkdownPreviewToggle<cr>", {
      buffer = event.buf,
      desc = "Markdown preview",
    })
  end,
})

-- Preserve the user's existing multi-cursor workflow.
map("n", "<C-d>", "<Plug>(VM-Find-Under)")
map("x", "<C-d>", "<Plug>(VM-Find-Subword-Under)")
