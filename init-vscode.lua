-- Lightweight Neovim backend for the VSCode Neovim extension.
-- Standalone Neovim continues to use init.lua and the full LazyVim setup.

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- VS Code owns files, rendering, completion, diagnostics, and undo history.
vim.opt.shadafile = "NONE"
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.spell = false
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.report = 999999
vim.opt.shortmess:append({ W = true, c = true, C = true, F = true, S = true })

local map = vim.keymap.set

map("n", ";", ":", { desc = "Command mode" })

if not vim.g.vscode then
  return
end

-- `vscode` is the current API module name. `vscode-neovim` is deprecated.
local vscode = require("vscode")

local function action(name, opts)
  return function()
    vscode.action(name, opts)
  end
end

-- Keep undo in VS Code so edits from both engines share one undo history.
map("n", "u", action("undo"), { silent = true, desc = "VS Code undo" })
map("n", "<C-r>", action("redo"), { silent = true, desc = "VS Code redo" })

-- LazyVim-shaped aliases backed by native VS Code surfaces.
map("n", "<leader><space>", action("workbench.action.quickOpen"), { desc = "Find files" })
map("n", "<leader>/", action("workbench.action.findInFiles"), { desc = "Search in files" })
map("n", "<leader>e", action("workbench.view.explorer"), { desc = "Explorer" })
map("n", "<leader>bd", action("workbench.action.closeActiveEditor"), { desc = "Close editor" })
map("n", "<leader>ca", action("editor.action.quickFix"), { desc = "Code action" })
map("n", "<leader>cr", action("editor.action.rename"), { desc = "Rename symbol" })
map("n", "<leader>cf", action("editor.action.formatDocument"), { desc = "Format document" })
map("n", "<leader>xx", action("workbench.actions.view.problems"), { desc = "Problems" })
map("n", "<leader>ft", action("workbench.action.terminal.toggleTerminal"), { desc = "Terminal" })
map("n", "<leader>fT", action("workbench.action.terminal.toggleTerminal"), { desc = "Terminal" })
map("n", "<S-h>", action("workbench.action.previousEditor"), { desc = "Previous editor" })
map("n", "<S-l>", action("workbench.action.nextEditor"), { desc = "Next editor" })

-- Preserve selection while moving over wrapped display lines.
local function move_wrapped(direction)
  return function()
    if vim.api.nvim_get_mode().mode ~= "v" then
      return "g" .. direction
    end
    vscode.action("cursorMove", {
      args = {
        {
          to = direction == "j" and "down" or "up",
          by = "wrappedLine",
          value = vim.v.count1,
          select = true,
        },
      },
    })
    return "<Ignore>"
  end
end

map("v", "gj", move_wrapped("j"), { expr = true, silent = true })
map("v", "gk", move_wrapped("k"), { expr = true, silent = true })
