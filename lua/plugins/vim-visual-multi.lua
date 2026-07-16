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
  },
}
