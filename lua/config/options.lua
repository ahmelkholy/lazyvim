-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Disable spell checking when in VSCode
if vim.g.vscode then
  vim.opt.spell = false
  vim.opt.spelllang = {}
  vim.opt.shadafile = "NONE"
  vim.opt.report = 999999
  vim.opt.shortmess:append({ W = true, c = true, C = true, F = true, S = true })
end

-- lua/config/options.lua
