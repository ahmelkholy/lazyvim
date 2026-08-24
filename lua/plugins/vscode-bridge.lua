if vim.g.vscode then
  return {}
end

local file_excludes = {
  ".git",
  ".jj",
  "node_modules",
  ".venv",
  "venv",
  "__pycache__",
  ".mypy_cache",
  ".pytest_cache",
  ".ruff_cache",
  ".cache",
  "target",
  "dist",
  "build",
  "coverage",
  ".next",
}

local file_args = { "--threads", "2", "--max-results", "20000" }

local function project_files()
  local root = require("config.workspace").root() or vim.fn.getcwd()
  Snacks.picker.files({ cwd = root })
end

local function open_files()
  Snacks.picker.buffers({
    current = true,
    layout = { preset = "select" },
    sort_lastused = true,
    unloaded = true,
  })
end

return {
  {
    "folke/snacks.nvim",
    init = function()
      require("config.svg_preview").setup()
    end,
    opts = function(_, opts)
      opts.picker = vim.tbl_deep_extend("force", opts.picker or {}, {
        -- Snacks performs matching inside Neovim, so no fzf process can grow
        -- independently. Both the producer and Lua finder stop at hard limits.
        limit = 20000,
        limit_live = 2000,
        previewers = {
          file = {
            max_line_length = 500,
            max_size = 2 * 1024 * 1024,
          },
        },
        sources = {
          buffers = {
            sort_lastused = true,
            unloaded = true,
          },
          files = {
            args = file_args,
            cmd = "fd",
            exclude = file_excludes,
            follow = false,
            hidden = true,
            ignored = false,
            limit = 20000,
          },
          git_files = {
            limit = 20000,
            untracked = true,
          },
          grep = {
            args = { "--max-filesize", "2M", "--max-count", "20" },
            exclude = file_excludes,
            follow = false,
            hidden = true,
            ignored = false,
            limit_live = 2000,
          },
        },
      })
    end,
    keys = {
      { "<leader><space>", project_files, desc = "Find Project Files (safe Lua picker)" },
      { "<leader>,", open_files, desc = "Switch Open File" },
      { "<leader>fb", open_files, desc = "Switch Open File" },
    },
  },
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
          -- Virtual buffers such as gitsigns:// are not filesystem paths.
          -- Explicit reveal from Ctrl+Alt+D still follows real files safely.
          enabled = false,
          leave_dirs_open = true,
        },
        -- Neo-tree already refreshes after writes and its own file actions.
        -- Avoid one persistent OS watcher per expanded directory in large
        -- repositories; R remains available for an explicit external refresh.
        use_libuv_file_watcher = false,
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
        width = require("config.workspace").explorer_width,
        mappings = {
          -- Match the user's VS Code Explorer bindings.
          ["y"] = "copy_to_clipboard",
          ["p"] = "paste_from_clipboard",
          ["d"] = "cut_to_clipboard",
          ["x"] = "delete",
          ["r"] = "rename",
          ["n"] = "add",
          ["N"] = "add_directory",
          ["<C-b>"] = function(state)
            local node = state.tree:get_node()
            local path = node and (node.path or node:get_id())
            if path and path:lower():match("%.svg$") then
              require("config.svg_preview").open(path)
            else
              vim.notify("Select an SVG file to preview", vim.log.levels.INFO, { title = "SVG Preview" })
            end
          end,
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
      { "<C-A-z>", "<cmd>VimtexTocToggle<cr>", ft = "tex", desc = "LaTeX: outline" },
    },
  },
}
