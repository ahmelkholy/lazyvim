return {
  -- Monokai theme.
  { "tanvirtin/monokai.nvim", priority = 1000 },

  -- Configure LazyVim to load Monokai.
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "monokai",
    },
  },
}
