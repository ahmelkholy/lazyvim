return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    init = function()
      require("config.markdown_tables").setup()
    end,
    opts = {
      -- Neovim cannot preserve a pipe table grid after its source rows wrap.
      -- A local renderer replaces tables with width-aware virtual rows instead.
      pipe_table = {
        enabled = false,
      },
      win_options = {
        conceallevel = {
          default = vim.o.conceallevel,
          rendered = 3,
        },
        concealcursor = {
          default = vim.o.concealcursor,
          rendered = "nvc",
        },
        wrap = {
          default = true,
          rendered = true,
        },
        linebreak = {
          default = true,
          rendered = true,
        },
        breakindent = {
          default = false,
          rendered = false,
        },
        showbreak = {
          default = "",
          rendered = "",
        },
      },
    },
  },
}
