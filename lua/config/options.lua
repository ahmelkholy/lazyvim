-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.g.lazyvim_python_lsp = "pyright"
vim.g.lazyvim_python_ruff = "ruff"

-- Linux: use the account's login shell for external commands.
if vim.fn.has("unix") == 1 then
  local shell = vim.env.SHELL
  if shell and shell ~= "" and vim.fn.executable(shell) == 1 then
    vim.opt.shell = shell
  end

  local npm_cache = vim.fn.stdpath("cache") .. "/npm"
  vim.fn.mkdir(npm_cache, "p")
  vim.env.npm_config_cache = npm_cache
  vim.env.NPM_CONFIG_CACHE = npm_cache
end

-- Disable spell checking when in VSCode
if vim.g.vscode then
  vim.opt.spell = false
  vim.opt.spelllang = {}
  vim.opt.shadafile = "NONE"
end

-- lua/config/options.lua
