local vscode_parsers = {
  "bash",
  "html",
  "javascript",
  "json",
  "lua",
  "markdown",
  "markdown_inline",
  "query",
  "tsx",
  "typescript",
  "vim",
  "vimdoc",
  "yaml",
}

local is_windows = vim.fn.has("win32") == 1
local rnoweb_parser_dir = vim.fn.stdpath("data") .. "/lazy/tree-sitter-rnoweb"

return {
  {
    "nvim-treesitter/nvim-treesitter",
    enabled = true,
    dependencies = is_windows and {
      {
        "bamonroe/tree-sitter-rnoweb",
        name = "tree-sitter-rnoweb",
        lazy = true,
        build = false,
      },
    } or nil,
    init = function()
      if not is_windows then
        return
      end

      -- The upstream rnoweb tarball contains a node_modules/.bin symlink that
      -- Windows' tar cannot extract. Lazy's Git checkout handles it correctly,
      -- so compile this parser from that checkout instead of the tarball.
      vim.api.nvim_create_autocmd("User", {
        pattern = "TSUpdate",
        callback = function()
          if vim.uv.fs_stat(rnoweb_parser_dir) then
            require("nvim-treesitter.parsers").rnoweb.install_info = {
              path = rnoweb_parser_dir,
            }
          end
        end,
      })
    end,
    opts = function(_, opts)
      if not vim.g.vscode then
        return
      end

      opts.ensure_installed = vscode_parsers
      opts.highlight = { enable = false }
      opts.indent = { enable = false }
      opts.folds = { enable = false }
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    enabled = true,
  },
  {
    "nvim-treesitter/playground",
    enabled = false,
  },
}
