return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    opts = {
      -- Padded tables expand every column to its longest value.  Trimming
      -- avoids large runs of virtual padding and lets normal window wrapping
      -- handle tables that are still wider than the editor.
      pipe_table = {
        cell = "trimmed",
      },
      win_options = {
        conceallevel = {
          default = vim.o.conceallevel,
          rendered = 2,
        },
        concealcursor = {
          default = vim.o.concealcursor,
          rendered = "",
        },
      },
    },
  },
}
