return {
  -- Gruvbox theme.
  { "ellisonleao/gruvbox.nvim", priority = 1000 },

  -- Configure LazyVim to load Gruvbox.
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "gruvbox",
    },
  },
}
