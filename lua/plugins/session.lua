return {
  {
    "folke/persistence.nvim",
    lazy = false,
    opts = {
      -- A workspace is identified by its directory, not its current Git
      -- branch. This makes the same path reopen exactly where it was left.
      branch = false,
      need = 1,
    },
    config = function(_, opts)
      local persistence = require("persistence")
      persistence.setup(opts)

      local function has_explicit_file_argument()
        for index = 0, vim.fn.argc(-1) - 1 do
          local argument = vim.fn.argv(index, -1)
          local stat = argument ~= "" and vim.uv.fs_stat(vim.fn.fnamemodify(argument, ":p")) or nil
          if not stat or stat.type ~= "directory" then
            return true
          end
        end
        return false
      end

      local function restore_workspace()
        if
          vim.g.vscode
          or #vim.api.nvim_list_uis() == 0
          or vim.v.this_session ~= ""
          or vim.g.started_with_stdin
          or has_explicit_file_argument()
        then
          return
        end
        persistence.load()
      end

      vim.api.nvim_create_autocmd("VimEnter", {
        group = vim.api.nvim_create_augroup("automatic_workspace_session", { clear = true }),
        once = true,
        nested = true,
        callback = restore_workspace,
        desc = "Restore the last session for the current directory",
      })
    end,
  },
}
