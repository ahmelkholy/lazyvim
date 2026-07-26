-- Configure gitsigns for VSCode compatibility
-- Completely disable gitsigns in VSCode to prevent E5560 errors
-- The E5560 error occurs when gitsigns tries to call Vimscript functions in Lua loop callbacks
-- which is problematic in the VSCode Neovim extension environment

-- Check if running in VSCode and disable if true
if vim.g.vscode then
  return {}
end

return {
  {
    "lewis6991/gitsigns.nvim",
    priority = 1000, -- Load early to override LazyVim defaults
    opts = function(_, opts)
      -- Normal gitsigns configuration for regular Neovim
      opts.signs = {
        add = { text = "+" },
        change = { text = "~" },
        delete = { text = "_" },
        topdelete = { text = "‾" },
        changedelete = { text = "~" },
      }

      -- Keep every hunk action directly in the Git menu.  LazyVim normally
      -- nests these below <leader>gh, which makes the common diff action four
      -- keystrokes long.
      opts.on_attach = function(buffer)
        local gs = require("gitsigns")
        local function map(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = buffer, silent = true, desc = desc })
        end

        map("n", "]h", function()
          if vim.wo.diff then
            vim.cmd.normal({ "]c", bang = true })
          else
            gs.nav_hunk("next")
          end
        end, "Next Hunk")
        map("n", "[h", function()
          if vim.wo.diff then
            vim.cmd.normal({ "[c", bang = true })
          else
            gs.nav_hunk("prev")
          end
        end, "Previous Hunk")
        map("n", "]H", function()
          gs.nav_hunk("last")
        end, "Last Hunk")
        map("n", "[H", function()
          gs.nav_hunk("first")
        end, "First Hunk")

        map({ "n", "x" }, "<leader>ga", ":Gitsigns stage_hunk<CR>", "Stage Hunk")
        map({ "n", "x" }, "<leader>gr", ":Gitsigns reset_hunk<CR>", "Reset Hunk")
        map("n", "<leader>gA", gs.stage_buffer, "Stage Buffer")
        map("n", "<leader>gu", gs.undo_stage_hunk, "Undo Stage Hunk")
        map("n", "<leader>gR", gs.reset_buffer, "Reset Buffer")
        map("n", "<leader>gp", gs.preview_hunk_inline, "Preview Hunk")
        map("n", "<leader>gb", function()
          gs.blame_line({ full = true })
        end, "Blame Line")
        map("n", "<leader>gB", gs.blame, "Blame Buffer")
        map("n", "<leader>gd", gs.diffthis, "Diff This")
        map("n", "<leader>gD", function()
          gs.diffthis("~")
        end, "Diff This (previous commit)")
        map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", "GitSigns Select Hunk")
      end
    end,
  },
}
