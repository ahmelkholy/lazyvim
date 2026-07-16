return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters = {
        ["markdownlint-cli2"] = {
          args = {
            "--config",
            vim.fn.stdpath("config") .. "/.markdownlint-cli2.jsonc",
            "--fix",
            "$FILENAME",
          },
        },
      },
    },
  },
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters = {
        ["markdownlint-cli2"] = {
          args = {
            "--config",
            vim.fn.stdpath("config") .. "/.markdownlint-cli2.jsonc",
            "-",
          },
        },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "csv", "typst" } },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        r_language_server = {
          enabled = vim.fn.executable("R") == 1,
        },
      },
    },
  },
  {
    "R-nvim/R.nvim",
    enabled = function()
      return vim.fn.executable("R") == 1
    end,
  },
}
