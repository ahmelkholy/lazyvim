-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Linux: use the account's login shell for external commands.
if vim.fn.has("unix") == 1 then
  local shell = vim.env.SHELL
  if shell and shell ~= "" and vim.fn.executable(shell) == 1 then
    vim.opt.shell = shell
  end
end

-- Disable spell checking when in VSCode
if vim.g.vscode then
  vim.opt.spell = false
  vim.opt.spelllang = {}
  vim.opt.shadafile = "NONE"
end

-- lua/config/options.lua
