-- ~/.config/nvim/lua/plugins/vim-visual-multi.lua
return {
  {
    "mg979/vim-visual-multi",
    branch = "master",
    event = "BufReadPost",
    -- You can lazy-load on certain events if you'd like:
    config = function()
      -- Disable plugin’s default mappings if you want your own
      vim.g.VM_default_mappings = 0

      -- Now set up your own keymaps for vim-visual-multi
      vim.keymap.set("n", "<C-d>", "<Plug>(VM-Find-Under)", {})
      vim.keymap.set("x", "<C-d>", "<Plug>(VM-Find-Subword-Under)", {})
      -- or both "n"/"v" if you prefer
    end,
  },
}
