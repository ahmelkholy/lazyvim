return {
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "bash-language-server",
        "black",
        "clang-format",
        "clangd",
        "codelldb",
        "cmakelang",
        "cmakelint",
        "debugpy",
        "isort",
        "json-lsp",
        "lua-language-server",
        "markdownlint",
        "marksman",
        "neocmakelsp",
        "prettier",
        "pyright",
        "ruff",
        "selene",
        "shellcheck",
        "shfmt",
        "stylua",
        "taplo",
        "typescript-language-server",
        "yaml-language-server",
      },
    },
  },

  {
    "neovim/nvim-lspconfig",
    opts = {
      codelens = { enabled = true },
      diagnostics = {
        virtual_text = {
          prefix = "icons",
          source = "if_many",
        },
      },
      servers = {
        julials = {
          mason = false,
          cmd_env = {
            JULIA_NUM_THREADS = "auto",
          },
          settings = {
            julia = {
              completionmode = "qualify",
              lint = {
                missingrefs = "none",
                run = true,
              },
              inlayHints = {
                static = {
                  enabled = true,
                },
              },
            },
          },
        },
        pyright = {
          settings = {
            python = {
              analysis = {
                autoImportCompletions = true,
                diagnosticMode = "workspace",
                inlayHints = {
                  callArgumentNames = true,
                  functionReturnTypes = true,
                  variableTypes = true,
                },
                typeCheckingMode = "basic",
                useLibraryCodeForTypes = true,
              },
            },
          },
        },
        ruff = {
          init_options = {
            settings = {
              lineLength = 100,
              logLevel = "error",
            },
          },
        },
        yamlls = {
          settings = {
            yaml = {
              keyOrdering = false,
            },
          },
        },
      },
    },
  },

  {
    "stevearc/conform.nvim",
    opts = {
      default_format_opts = {
        timeout_ms = 5000,
        lsp_format = "fallback",
      },
      formatters_by_ft = {
        bash = { "shfmt" },
        c = { "clang_format" },
        cpp = { "clang_format" },
        css = { "prettier" },
        html = { "prettier" },
        javascript = { "prettier" },
        javascriptreact = { "prettier" },
        json = { "prettier" },
        jsonc = { "prettier" },
        markdown = { "prettier" },
        python = { "ruff_fix", "ruff_organize_imports", "ruff_format" },
        sh = { "shfmt" },
        typescript = { "prettier" },
        typescriptreact = { "prettier" },
        yaml = { "prettier" },
        zsh = { "shfmt" },
      },
    },
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "bash",
        "c",
        "cmake",
        "cpp",
        "dockerfile",
        "julia",
        "make",
        "python",
        "sql",
      },
    },
  },
}
