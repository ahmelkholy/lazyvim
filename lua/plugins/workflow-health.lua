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
  {
    url = "https://github.com/ggandor/leap.nvim.git",
    name = "leap.nvim",
    config = function(_, opts)
      local leap = require("leap")
      for key, value in pairs(opts) do
        leap.opts[key] = value
      end

      vim.keymap.set({ "n", "x", "o" }, "s", "<Plug>(leap-forward)", {
        silent = true,
        desc = "Leap forward",
      })
      vim.keymap.set({ "n", "x", "o" }, "S", "<Plug>(leap-backward)", {
        silent = true,
        desc = "Leap backward",
      })
      vim.keymap.set({ "n", "x", "o" }, "gs", "<Plug>(leap-from-window)", {
        silent = true,
        desc = "Leap from window",
      })
    end,
  },
}
