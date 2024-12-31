-- Keymaps are automatically loaded on the VeryLazy event
-- filepath: /C:/Users/ahm_e/AppData/Local/nvim/lua/config/keymaps.lua
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set

map({ "n" }, ";", ":", { remap = true })
vim.keymap.set("n", "<C-d>", "<Plug>(VM-Find-Under)", {})
vim.keymap.set("x", "<C-d>", "<Plug>(VM-Find-Subword-Under)", {})
