-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

vim.api.nvim_create_user_command("NvimTransition", function()
  local guide = vim.fn.stdpath("config") .. "/NVIM_TRANSITION_GUIDE.md"
  vim.cmd.tabnew(vim.fn.fnameescape(guide))
end, { desc = "Open the personalized VS Code to Neovim transition guide" })

require("config.workspace").setup()
require("config.workspaces").setup()

-- Match Ctrl+C in graphical editors: every yank is also copied to the system
-- clipboard without changing the normal behavior of delete/change registers.
vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("system_clipboard_yanks", { clear = true }),
  callback = function()
    if vim.v.event.operator == "y" then
      pcall(vim.fn.setreg, "+", vim.v.event.regcontents, vim.v.event.regtype)
    end
  end,
  desc = "Mirror yanks to the system clipboard",
})
