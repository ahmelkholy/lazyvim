local LazyVim = require("lazyvim.util")
local Workspace = require("config.workspace")

local function statusline_window()
  local win = tonumber(vim.g.statusline_winid)
  if win and vim.api.nvim_win_is_valid(win) then
    return win
  end
  return vim.api.nvim_get_current_win()
end

local function pane_number()
  local win = statusline_window()
  return string.format("󰓩 %s", Workspace.pane_role(win) or vim.fn.win_id2win(win))
end

local special_titles = {
  aerial = "󰘦 Outline",
  alpha = "󰋜 Home",
  dashboard = "󰋜 Home",
  help = "󰋖 Help",
  lazy = "󰒲 Plugins",
  mason = "󰏖 Tool Manager",
  neo_tree = "󰙅 Explorer",
  noice = "󰍡 Messages",
  qf = "󰁨 Quickfix",
  snacks_dashboard = "󰋜 Home",
  snacks_picker_list = "󰱼 Picker",
  trouble = "󱖫 Problems",
}

local function file_icon(name, filetype)
  local configured = LazyVim.config.icons.ft[filetype]
  if configured then
    return configured
  end

  local ok, mini_icons = pcall(require, "mini.icons")
  if ok then
    return mini_icons.get("file", name)
  end
  return "󰈙"
end

local function pane_title()
  local win = statusline_window()
  local buf = vim.api.nvim_win_get_buf(win)
  local filetype = vim.api.nvim_get_option_value("filetype", { buf = buf })
  local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })

  local title = special_titles[filetype:gsub("-", "_")]
  if buftype == "terminal" then
    title = " Terminal"
  elseif not title then
    local name = vim.api.nvim_buf_get_name(buf)
    if name == "" then
      title = "󰈙 Untitled"
    else
      local path = vim.fn.fnamemodify(name, ":.")
      title = string.format("%s %s", file_icon(name, filetype), path)
    end
  end

  if vim.api.nvim_get_option_value("readonly", { buf = buf }) then
    title = title .. " 󰌾"
  end
  if vim.api.nvim_get_option_value("modified", { buf = buf }) then
    title = title .. " ●"
  end
  return title
end

local function compact_name(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" then
    return "Untitled"
  end

  local basename = vim.fn.fnamemodify(name, ":t")
  if vim.fn.strdisplaywidth(basename) > 16 then
    basename = vim.fn.strcharpart(basename, 0, 13) .. "…"
  end
  return basename
end

local function pane_tabs()
  local win = statusline_window()
  local current = vim.api.nvim_win_get_buf(win)
  local tabs = Workspace.tabs(win)
  if #tabs < 2 then
    return pane_title()
  end

  local labels = {}
  for index, buf in ipairs(tabs) do
    local filetype = vim.api.nvim_get_option_value("filetype", { buf = buf })
    local name = vim.api.nvim_buf_get_name(buf)
    local marker = buf == current and "▸" or "·"
    local modified = vim.api.nvim_get_option_value("modified", { buf = buf }) and "+" or ""
    labels[#labels + 1] =
      string.format("%s%d %s %s%s", marker, index, file_icon(name, filetype), compact_name(buf), modified)
  end
  return table.concat(labels, "  ")
end

local function winbar(active)
  return {
    lualine_a = { { pane_number, separator = { right = "" } } },
    lualine_b = {},
    lualine_c = { { pane_tabs, color = active and { gui = "bold" } or nil } },
    lualine_x = {},
    lualine_y = {},
    lualine_z = {},
  }
end

return {
  -- Bufferline is one shared list, which is visually ambiguous with multiple
  -- splits. Per-window winbars below make ownership explicit instead.
  { "akinsho/bufferline.nvim", enabled = false },
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      opts.options.globalstatus = true
      opts.options.disabled_filetypes = opts.options.disabled_filetypes or {}
      opts.options.disabled_filetypes.winbar = {}
      opts.winbar = winbar(true)
      opts.inactive_winbar = winbar(false)
    end,
  },
}
