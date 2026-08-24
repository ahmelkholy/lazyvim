-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.g.lazyvim_python_lsp = "pyright"
vim.g.lazyvim_python_ruff = "ruff"
vim.opt.clipboard = "unnamedplus"

-- Keep source code readable at every window width. These are display settings:
-- they never insert line breaks or otherwise modify the file.
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.breakindent = true
vim.opt.breakindentopt = "shift:2,min:20"
-- Wrapped lines never display a synthetic continuation marker.
vim.opt.showbreak = ""
vim.opt.smoothscroll = true
vim.opt.scrolloff = 6
vim.opt.sidescrolloff = 8
vim.opt.cursorline = true
vim.opt.cursorlineopt = "number,line"
vim.opt.signcolumn = "yes"
vim.opt.foldcolumn = "1"
vim.opt.list = true
vim.opt.listchars = {
  tab = "→ ",
  trail = "·",
  extends = "›",
  precedes = "‹",
  nbsp = "␣",
}

-- Native histogram diffing produces stable, readable hunks for moved and
-- heavily edited blocks without loading an additional diff plugin.
vim.opt.diffopt:append("algorithm:histogram")

-- Graphical Neovim clients can apply this directly. Terminal Neovim inherits
-- its font from the terminal (the VS Code workspace uses the same Nerd Font).
vim.opt.guifont = "JetBrainsMono Nerd Font Mono:h14"

if not vim.g.vscode then
  -- One global statusline plus a top title bar inside each window is clearer
  -- than a shared full-width buffer/workspace strip.
  vim.opt.laststatus = 3
  vim.opt.showtabline = 0

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

-- SSH terminals reliably support OSC52 writes, but many do not answer OSC52
-- reads. Neovim's stock paste provider waits up to ten seconds for that reply,
-- which can make `nvim .` look frozen. Keep system clipboard copies and cache
-- our own yanks locally; use the terminal's normal paste shortcut for external
-- clipboard text.
if vim.env.SSH_TTY and not vim.env.DISPLAY and not vim.env.WAYLAND_DISPLAY then
  local cache = {}
  local function copy(reg)
    local send = require("vim.ui.clipboard.osc52").copy(reg)
    return function(lines, regtype)
      cache[reg] = { vim.deepcopy(lines), regtype }
      send(lines)
    end
  end
  local function paste(reg)
    return function()
      return cache[reg] or { {}, "v" }
    end
  end
  vim.g.clipboard = {
    name = "OSC52 copy (non-blocking)",
    copy = {
      ["+"] = copy("+"),
      ["*"] = copy("*"),
    },
    paste = {
      ["+"] = paste("+"),
      ["*"] = paste("*"),
    },
    cache_enabled = 0,
  }
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
