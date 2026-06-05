return {
  {
    "christoomey/vim-tmux-navigator",
    cond = function()
      return not vim.g.vscode
    end,
    init = function()
      vim.g.tmux_navigator_no_mappings = 1
    end,
    keys = {
      { "<C-h>", "<cmd>TmuxNavigateLeft<cr>", desc = "Tmux/Vim Left" },
      { "<C-j>", "<cmd>TmuxNavigateDown<cr>", desc = "Tmux/Vim Down" },
      { "<C-k>", "<cmd>TmuxNavigateUp<cr>", desc = "Tmux/Vim Up" },
      { "<C-l>", "<cmd>TmuxNavigateRight<cr>", desc = "Tmux/Vim Right" },
      { "<C-\\>", "<cmd>TmuxNavigatePrevious<cr>", desc = "Tmux/Vim Previous" },
    },
  },
}
