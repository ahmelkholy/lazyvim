return {
  -- DISABLE the main nvim-treesitter plugin
  {
    "nvim-treesitter/nvim-treesitter",
    enabled = false,
  },

  -- DISABLE any additional nvim-treesitter addons from LazyVim or others
  -- (you might not have all of these, but listing them just in case)
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    enabled = false,
  },
  {
    "nvim-treesitter/playground",
    enabled = false,
  },
}
