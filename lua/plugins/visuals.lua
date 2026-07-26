return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      diagnostics = {
        severity_sort = true,
        float = {
          border = "rounded",
          source = "if_many",
        },
        virtual_text = {
          prefix = "icons",
          source = "if_many",
          spacing = 2,
        },
      },
    },
  },
}
