if vim.g.vscode then
  return {}
end

return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = {
      filesystem = {
        commands = {
          open = function(state)
            require("config.workspace").open_from_tree(state)
          end,
        },
        follow_current_file = {
          enabled = true,
          leave_dirs_open = true,
        },
        use_libuv_file_watcher = true,
        filtered_items = {
          visible = true,
          hide_dotfiles = false,
          hide_gitignored = false,
          hide_ignored = false,
          hide_hidden = false,
          hide_by_name = {},
          hide_by_pattern = {},
          never_show = {},
          never_show_by_pattern = {},
        },
      },
      window = {
        width = 34,
        mappings = {
          -- Match the user's VS Code Explorer bindings.
          ["y"] = "copy_to_clipboard",
          ["p"] = "paste_from_clipboard",
          ["d"] = "cut_to_clipboard",
          ["x"] = "delete",
          ["r"] = "rename",
          ["n"] = "add",
          ["N"] = "add_directory",
          ["<C-A-s>"] = function(state)
            local node = state.tree:get_node()
            if node and node.path then
              vim.fn.setreg("+", node.path)
              vim.fn.setreg('"', node.path)
              vim.notify("Copied: " .. node.path)
            end
          end,
        },
      },
    },
  },
  {
    "ibhagwan/fzf-lua",
    opts = {
      files = {
        hidden = true,
        no_ignore = true,
        follow = true,
      },
      grep = {
        hidden = true,
        no_ignore = true,
        follow = true,
      },
    },
  },
  {
    "lervag/vimtex",
    keys = {
      { "<C-A-z>", "<cmd>VimtexTocToggle<cr>", ft = "tex", desc = "LaTeX: outline" },
    },
  },
  {
    "zbirenbaum/copilot.lua",
    opts = {
      suggestion = {
        keymap = {
          accept_word = "<M-'>",
          next = "<M-i>",
        },
      },
    },
  },
}
