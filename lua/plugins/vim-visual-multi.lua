-- ~/.config/nvim/lua/plugins/vim-visual-multi.lua
-- Only load this when NOT in VSCode (regular Neovim)
if vim.g.vscode then
  return {}
end

return {
  {
    "mg979/vim-visual-multi",
    branch = "master",
    event = "BufReadPost",
    init = function()
      -- Keep Neovim's native Ctrl+D/Ctrl+N scrolling. Multi-cursor remains
      -- available behind an explicit leader mapping.
      vim.g.VM_default_mappings = 0
      vim.g.VM_maps = {
        ["Find Under"] = "<leader>mc",
        ["Find Subword Under"] = "<leader>mc",
      }
    end,
    config = function()
      vim.keymap.set("n", "<leader>mc", "<Plug>(VM-Find-Under)", {
        remap = true,
        desc = "Multi-cursor: select word",
      })
      vim.keymap.set("x", "<leader>mc", "<Plug>(VM-Find-Subword-Under)", {
        remap = true,
        desc = "Multi-cursor: select selection",
      })
    end,
  },
}
