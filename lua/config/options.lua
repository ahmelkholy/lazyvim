-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.g.lazyvim_python_lsp = "pyright"
vim.g.lazyvim_python_ruff = "ruff"

-- Graphical Neovim clients can apply this directly. Terminal Neovim inherits
-- its font from the terminal (the VS Code workspace uses the same Nerd Font).
vim.opt.guifont = "JetBrainsMono Nerd Font Mono:h14"

if not vim.g.vscode then
  -- One global statusline plus one title bar per window is clearer than a
  -- shared buffer strip when several editor panes are visible.
  vim.opt.laststatus = 3
  vim.opt.showtabline = 1

  if vim.fn.exists("+winborder") == 1 then
    vim.opt.winborder = "rounded"
  end

  vim.opt.fillchars:append({
    horiz = "─",
    horizdown = "┬",
    horizup = "┴",
    vert = "│",
    vertleft = "┤",
    vertright = "├",
    verthoriz = "┼",
  })
end

-- Mason-installed tools must also be available to health checks and plugins
-- that execute before Mason itself is loaded.
local mason_bin = vim.fn.stdpath("data") .. "/mason/bin"
if (vim.uv or vim.loop).fs_stat(mason_bin) then
  local separator = vim.fn.has("win32") == 1 and ";" or ":"
  if not vim.env.PATH:find(mason_bin, 1, true) then
    vim.env.PATH = mason_bin .. separator .. vim.env.PATH
  end
end

local provider_python = vim.fn.stdpath("data")
  .. (vim.fn.has("win32") == 1 and "/provider-python/Scripts/python.exe" or "/provider-python/bin/python")
if vim.fn.executable(provider_python) == 1 then
  vim.g.python3_host_prog = provider_python
end

-- These optional remote providers are not used by this configuration.
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0

-- SSH/tmux sessions have no DISPLAY even though the terminal supports OSC52.
if vim.env.SSH_TTY and not vim.env.DISPLAY and not vim.env.WAYLAND_DISPLAY then
  vim.g.clipboard = "osc52"
end

-- Linux/macOS: use the account's login shell for external commands.
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
  vim.opt.swapfile = false
  vim.opt.backup = false
  vim.opt.writebackup = false
  vim.opt.report = 999999
  vim.opt.shortmess:append({ W = true, c = true, C = true, F = true, S = true })
end

-- lua/config/options.lua
