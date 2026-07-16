if vim.g.vscode then
  return {}
end

return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = {
      filesystem = {
        follow_current_file = {
          enabled = true,
          leave_dirs_open = true,
        },
        use_libuv_file_watcher = true,
      },
      window = {
        width = 36,
        mappings = {
          -- Match the user's VS Code Explorer bindings.
          ["y"] = "copy_to_clipboard",
          ["p"] = "paste_from_clipboard",
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
    "lervag/vimtex",
    keys = {
      { "<C-S-b>", "<cmd>VimtexView<cr>", ft = "tex", desc = "LaTeX: view PDF" },
      { "<C-A-z>", "<cmd>VimtexTocToggle<cr>", ft = "tex", desc = "LaTeX: outline" },
    },
  },
  {
    "zbirenbaum/copilot.lua",
    opts = {
      suggestion = {
        keymap = {
          accept_word = "<M-'>",
        },
      },
    },
  },
}
