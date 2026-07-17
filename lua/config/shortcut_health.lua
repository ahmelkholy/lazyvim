local M = {}

local required_maps = {
  n = {
    "<C-A-d>",
    "<C-S-e>",
    "<C-S-f>",
    "<A-f>",
    "<F2>",
    "<C-S-p>",
    "<C-A-q>",
    "<leader>fw",
    "<leader>wa",
    "<leader>wc",
    "<leader>wL",
    "<C-Tab>",
    "<C-S-Tab>",
    "<leader><tab><tab>",
    "<leader><tab>[",
    "<leader><tab>]",
    "<leader><tab>1",
    "<leader><tab>2",
    "<leader><tab>3",
    "<leader><tab>4",
    "<leader><tab>f",
    "<leader><tab>l",
    "<leader><tab>d",
    "<leader><tab>o",
    "<leader><tab>w",
    "<leader>W",
    "<leader>bb",
    "<leader>`",
    "<leader>fn",
    "<leader>wd",
    "<leader>bD",
    "<leader>qq",
    "<C-S-n>",
    "<S-A-q>",
    "<A-t>",
    "<C-A-b>",
    "<A-b>",
    "<C-S-b>",
    "<S-A-f>",
    "<S-A-2>",
    "<C-A-w>",
    "<C-A-e>",
    "<C-A-t>",
    "<F11>",
    "<C-A-f>",
    "<F12>",
    "<S-F12>",
    "<C-.>",
    "<A-Left>",
    "<A-Right>",
    "<C-A-g>",
    "<C-A-v>",
    "<A-,>",
    "<A-.>",
    "<A-r>",
    "<A-d>",
    "<C-A-s>",
    "<C-A-p>",
    "<C-S-g>",
    "<C-S-Left><Delete>",
    "<C-S-A-r>",
    "<A-a>",
    "<C-A-a>",
    "<C-S-i>",
    "<S-A-a>",
    "<C-A-c>",
    "<A-g>",
    "<C-A-o>",
    "<C-A-x>",
    "<S-A-b>",
    "<C-A-n>",
    "<leader>Rj",
    "<leader>Rp",
    "<leader>Rm",
    "<leader>RM",
    "<leader>mc",
  },
  x = {
    "<S-A-f>",
    "<C-.>",
    "<A-a>",
    "<C-A-a>",
    "<C-S-i>",
    "<S-A-a>",
    "<C-A-c>",
    "<leader>mc",
  },
  t = {
    "<C-A-d>",
    "<C-S-e>",
    "<C-S-f>",
    "<A-f>",
    "<A-t>",
    "<C-A-b>",
    "<A-b>",
    "<C-S-b>",
    "<S-CR>",
    "<C-CR>",
    "<C-S-v>",
    "<A-Up>",
    "<A-Down>",
  },
}

local required_modules = {
  "aerial",
  "config.workspace",
  "config.workspaces",
  "config.terminals",
  "dap",
  "fzf-lua",
  "gitsigns",
  "neo-tree.command",
  "neotest",
  "overseer",
  "project_nvim",
  "snacks",
}

local required_commands = {
  "FzfLua",
  "Lazy",
  "Mason",
  "Neotree",
  "OverseerRun",
  "OverseerTaskAction",
  "OverseerToggle",
  "ShortcutHealth",
  "Trouble",
  "WorkspaceAdd",
  "WorkspaceClose",
  "WorkspaceLayout",
  "Workspaces",
}

local optional_executables = {
  "biber",
  "claude",
  "gemini",
  "g++",
  "gcc",
  "julia",
  "make",
  "matlab",
  "opencode",
  "R",
}

local function add(collection, message)
  collection[#collection + 1] = message
end

local function all_maps(mode)
  return vim.list_extend(vim.api.nvim_get_keymap(mode), vim.api.nvim_buf_get_keymap(0, mode))
end

local function command_from_rhs(rhs)
  return rhs and (rhs:match("^<Cmd>%s*:?(%a[%w]*)") or rhs:match("^<cmd>%s*:?(%a[%w]*)")) or nil
end

function M.check()
  local report = {
    errors = {},
    warnings = {},
    leader_maps = 0,
    command_maps = 0,
    required_maps = 0,
  }

  local ok, lazy = pcall(require, "lazy")
  if ok then
    lazy.load({ plugins = { "vim-visual-multi" } })
  end

  for _, mode in ipairs({ "n", "x", "o", "t", "i" }) do
    for _, mapping in ipairs(all_maps(mode)) do
      if mapping.lhs:sub(1, 1) == " " then
        report.leader_maps = report.leader_maps + 1
        if not mapping.desc or mapping.desc == "" then
          add(report.errors, ("%s %s has no description"):format(mode, vim.fn.keytrans(mapping.lhs)))
        end

        local command = command_from_rhs(mapping.rhs)
        if command then
          report.command_maps = report.command_maps + 1
          if vim.fn.exists(":" .. command) == 0 then
            add(report.errors, ("%s %s uses missing command :%s"):format(mode, vim.fn.keytrans(mapping.lhs), command))
          end
        end
      end
    end
  end

  for mode, mappings in pairs(required_maps) do
    for _, lhs in ipairs(mappings) do
      report.required_maps = report.required_maps + 1
      local mapping = vim.fn.maparg(lhs, mode, false, true)
      if not mapping or next(mapping) == nil then
        add(report.errors, ("required mapping is missing: %s %s"):format(mode, lhs))
      elseif not mapping.desc or mapping.desc == "" then
        add(report.errors, ("required mapping has no description: %s %s"):format(mode, lhs))
      end
    end
  end

  local tmux_config = vim.fn.stdpath("config") .. "/lua/plugins/tmux.lua"
  if vim.uv.fs_stat(tmux_config) then
    for _, lhs in ipairs({ "<C-h>", "<C-j>", "<C-k>", "<C-l>", "<C-\\>" }) do
      local mapping = vim.fn.maparg(lhs, "n", false, true)
      if not mapping or next(mapping) == nil then
        add(report.errors, "tmux/window navigation mapping is missing: n " .. lhs)
      end
    end
  end

  for _, module in ipairs(required_modules) do
    local loaded, err = pcall(require, module)
    if not loaded then
      add(report.errors, ("required module failed to load: %s (%s)"):format(module, err))
    end
  end

  for _, command in ipairs(required_commands) do
    if vim.fn.exists(":" .. command) == 0 then
      add(report.errors, "required command is missing: :" .. command)
    end
  end

  for _, executable in ipairs(optional_executables) do
    if vim.fn.executable(executable) == 0 then
      add(report.warnings, executable .. " is unavailable; its optional shortcut will show a warning")
    end
  end

  local python = vim.fn.has("win32") == 1 and "python" or "python3"
  for _, executable in ipairs({ "fd", "fzf", "git", "lazygit", python, "rg" }) do
    if vim.fn.executable(executable) == 0 then
      add(report.errors, "required executable is unavailable: " .. executable)
    end
  end

  local clipboard = vim.fn.has("clipboard") == 1
    or vim.g.clipboard ~= nil
    or vim.fn.executable("wl-copy") == 1
    or vim.fn.executable("xclip") == 1
    or vim.fn.executable("pbcopy") == 1
  if not clipboard then
    add(report.warnings, "no system clipboard provider was detected")
  end

  report.ok = #report.errors == 0
  return report
end

function M.show()
  local report = M.check()
  local lines = {
    ("Shortcut audit: %s"):format(report.ok and "PASS" or "FAIL"),
    ("Leader mappings: %d | required custom mappings: %d | command mappings: %d"):format(
      report.leader_maps,
      report.required_maps,
      report.command_maps
    ),
  }

  for _, message in ipairs(report.errors) do
    lines[#lines + 1] = "ERROR: " .. message
  end
  for _, message in ipairs(report.warnings) do
    lines[#lines + 1] = "WARN: " .. message
  end
  vim.notify(table.concat(lines, "\n"), report.ok and vim.log.levels.INFO or vim.log.levels.ERROR, {
    title = "Shortcut Health",
  })
  return report
end

return M
