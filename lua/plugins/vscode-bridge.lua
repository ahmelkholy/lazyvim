if vim.g.vscode then
  return {}
end

local file_excludes = table.concat({
  "--exclude .git",
  "--exclude .jj",
  "--exclude node_modules",
  "--exclude .venv",
  "--exclude venv",
  "--exclude __pycache__",
  "--exclude .mypy_cache",
  "--exclude .pytest_cache",
  "--exclude .ruff_cache",
  "--exclude .cache",
  "--exclude target",
  "--exclude dist",
  "--exclude build",
  "--exclude coverage",
  "--exclude .next",
}, " ")

local rg_excludes = table.concat({
  [[--glob '!.git/**']],
  [[--glob '!.jj/**']],
  [[--glob '!node_modules/**']],
  [[--glob '!.venv/**']],
  [[--glob '!venv/**']],
  [[--glob '!__pycache__/**']],
  [[--glob '!.cache/**']],
  [[--glob '!target/**']],
  [[--glob '!dist/**']],
  [[--glob '!build/**']],
  [[--glob '!coverage/**']],
  [[--glob '!.next/**']],
}, " ")

local function project_files()
  local root = require("config.workspace").root() or vim.fn.getcwd()
  require("fzf-lua").vcs_files({ cwd = root })
end

local function open_files()
  require("fzf-lua").buffers({
    previewer = false,
    sort_lastused = true,
    sort_mru = true,
  })
end

return {
  {
    "folke/snacks.nvim",
    init = function()
      require("config.svg_preview").setup()
    end,
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
    "ibhagwan/fzf-lua",
    opts = {
      winopts = {
        preview = {
          -- Avoid reading and highlighting every candidate while the cursor
          -- is moving quickly through a large result set.
          delay = 150,
        },
      },
      previewers = {
        builtin = {
          -- Previewing huge or generated files can consume more memory than
          -- the search itself. Keep useful previews, with strict limits.
          limit_b = 2 * 1024 * 1024,
          syntax_limit_b = 256 * 1024,
          syntax_limit_l = 2000,
        },
      },
      files = {
        hidden = true,
        no_ignore = false,
        follow = false,
        fd_opts = "--color=never --type f --type l --threads 2 --max-results 50000 " .. file_excludes,
        rg_opts = "--color=never --files --hidden --threads 2 " .. rg_excludes,
      },
      grep = {
        hidden = true,
        no_ignore = false,
        follow = false,
        rg_opts = "--column --line-number --no-heading --color=always --smart-case "
          .. "--max-columns=4096 --max-filesize=2M --max-count=200 --hidden --threads=2 "
          .. rg_excludes
          .. " -e",
      },
      buffers = {
        previewer = false,
        sort_lastused = true,
        show_unloaded = true,
      },
      git = {
        files = {
          -- Includes tracked and useful untracked files, respects Git ignore
          -- rules, and puts a hard ceiling on pathological repositories.
          cmd = "git ls-files --cached --others --exclude-standard | head -n 50000",
        },
      },
    },
    keys = {
      { "<leader><space>", project_files, desc = "Find Project Files (safe)" },
      { "<leader>,", open_files, desc = "Switch Open File" },
      { "<leader>fb", open_files, desc = "Switch Open File" },
    },
  },
  {
    "lervag/vimtex",
    keys = {
      { "<C-A-z>", "<cmd>VimtexTocToggle<cr>", ft = "tex", desc = "LaTeX: outline" },
    },
  },
}
