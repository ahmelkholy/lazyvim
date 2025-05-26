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
    opts = {
      -- Normal gitsigns configuration for regular Neovim
      signs = {
        add = { text = "+" },
        change = { text = "~" },
        delete = { text = "_" },
        topdelete = { text = "‾" },
        changedelete = { text = "~" },
      },
    },
  },
}
