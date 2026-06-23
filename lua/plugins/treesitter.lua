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

return {
  {
    "nvim-treesitter/nvim-treesitter",
    enabled = true,
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
