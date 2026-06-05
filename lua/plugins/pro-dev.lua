local function root()
  return LazyVim and LazyVim.root and LazyVim.root.get() or vim.uv.cwd()
end

local function exe(name)
  local path = vim.fn.exepath(name)
  return path ~= "" and path or name
end

local function current_file()
  return vim.api.nvim_buf_get_name(0)
end

local function python_cmd()
  local venv = vim.env.VIRTUAL_ENV
  if venv and venv ~= "" then
    local candidate = venv .. "/bin/python"
    if vim.fn.executable(candidate) == 1 then
      return candidate
    end
  end
  return exe("python3")
end

local function terminal(cmd)
  Snacks.terminal(cmd, { cwd = root() })
end

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

  {
    "folke/snacks.nvim",
    keys = {
      {
        "<leader>rj",
        function()
          terminal({ exe("julia"), "--project=@." })
        end,
        desc = "Julia REPL",
      },
      {
        "<leader>rJ",
        function()
          terminal({ exe("julia"), "--project=@.", current_file() })
        end,
        desc = "Run Julia File",
        ft = "julia",
      },
      {
        "<leader>rp",
        function()
          terminal({ python_cmd() })
        end,
        desc = "Python REPL",
      },
      {
        "<leader>rP",
        function()
          terminal({ python_cmd(), current_file() })
        end,
        desc = "Run Python File",
        ft = "python",
      },
      {
        "<leader>rm",
        function()
          terminal({ "make" })
        end,
        desc = "Run Make",
      },
      {
        "<leader>rM",
        function()
          local target = vim.fn.input("make target: ")
          terminal(target ~= "" and { "make", target } or { "make" })
        end,
        desc = "Run Make Target",
      },
      {
        "<leader>rc",
        function()
          local file = current_file()
          local out = vim.fn.fnamemodify(file, ":r")
          terminal({ "sh", "-lc", ("gcc %q -O0 -g -Wall -Wextra -o %q && %q"):format(file, out, out) })
        end,
        desc = "Build and Run C File",
        ft = "c",
      },
      {
        "<leader>rC",
        function()
          local file = current_file()
          local out = vim.fn.fnamemodify(file, ":r")
          terminal({ "sh", "-lc", ("g++ %q -O0 -g -Wall -Wextra -o %q && %q"):format(file, out, out) })
        end,
        desc = "Build and Run C++ File",
        ft = "cpp",
      },
    },
  },
}
