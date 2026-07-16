-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

vim.api.nvim_create_user_command("NvimTransition", function()
  local guide = vim.fn.stdpath("config") .. "/NVIM_TRANSITION_GUIDE.md"
  vim.cmd.tabnew(vim.fn.fnameescape(guide))
end, { desc = "Open the personalized VS Code to Neovim transition guide" })
