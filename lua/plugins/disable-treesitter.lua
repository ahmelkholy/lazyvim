if not vim.g.vscode then
  return {}
end

return {
  -- VS Code owns syntax highlighting there; keep Treesitter for standalone Neovim.
  {
    "nvim-treesitter/nvim-treesitter",
    enabled = false,
  },
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    enabled = false,
  },
  {
    "nvim-treesitter/playground",
    enabled = false,
  },
}
