-- Lightweight Neovim configuration for the VSCode Neovim extension.
-- The full LazyVim configuration remains available in init.lua for terminal Neovim.

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- VS Code owns rendering, completion, diagnostics, undo history, and syntax.
vim.opt.shadafile = "NONE"
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.spell = false
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.report = 999999
vim.opt.shortmess:append({ W = true, c = true, C = true, F = true, S = true })

vim.keymap.set("n", ";", ":", { desc = "Command mode" })

if vim.g.vscode then
  local vscode = require("vscode-neovim")

  vim.keymap.set("n", "u", function()
    vscode.action("undo")
  end, { silent = true, desc = "VS Code undo" })

  vim.keymap.set("n", "<C-r>", function()
    vscode.action("redo")
  end, { silent = true, desc = "VS Code redo" })

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

  vim.keymap.set("v", "gj", move_wrapped("j"), { expr = true, silent = true })
  vim.keymap.set("v", "gk", move_wrapped("k"), { expr = true, silent = true })
end
