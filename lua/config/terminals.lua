local M = {
  max_terminals = 2,
}

---@type table<number, number[]>
local groups = {}

local function current_tab()
  return vim.api.nvim_get_current_tabpage()
end

local function is_terminal(buf)
  return vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_get_option_value("buftype", { buf = buf }) == "terminal"
end

local function group_buffers()
  local tab = current_tab()
  groups[tab] = vim.tbl_filter(is_terminal, groups[tab] or {})
  return groups[tab]
end

local function remember(buf)
  local buffers = group_buffers()
  if not vim.tbl_contains(buffers, buf) then
    buffers[#buffers + 1] = buf
  end
  vim.api.nvim_buf_set_var(buf, "workspace_terminal_group", true)
end

local function terminal_windows()
  local buffers = group_buffers()
  local windows = vim.tbl_filter(function(win)
    return vim.tbl_contains(buffers, vim.api.nvim_win_get_buf(win)) and vim.api.nvim_win_get_config(win).relative == ""
  end, vim.api.nvim_tabpage_list_wins(0))
  table.sort(windows, function(left, right)
    local left_position = vim.api.nvim_win_get_position(left)
    local right_position = vim.api.nvim_win_get_position(right)
    return left_position[1] == right_position[1] and left_position[2] < right_position[2]
      or left_position[1] < right_position[1]
  end)
  return windows
end

local function focus(win)
  if not win or not vim.api.nvim_win_is_valid(win) then
    return false
  end
  vim.api.nvim_set_current_win(win)
  if #vim.api.nvim_list_uis() > 0 then
    vim.cmd.startinsert()
  end
  return true
end

local function anchor_editor()
  local editor = require("config.workspace").active_editor_window()
  if editor then
    vim.api.nvim_set_current_win(editor)
  end
end

local function terminal_height()
  local previous_height = math.max(8, math.min(15, math.floor(vim.o.lines * 0.3)))
  return math.min(previous_height * 2, math.max(8, vim.o.lines - 6))
end

local function create_primary()
  anchor_editor()
  local root = require("config.workspace").root() or vim.fn.getcwd()
  local command = ("botright %dsplit | lcd %s | terminal"):format(terminal_height(), vim.fn.fnameescape(root))
  local ok, err = pcall(vim.cmd, command)
  if not ok then
    vim.notify(err, vim.log.levels.ERROR, { title = "Terminal group" })
    return nil
  end
  local win = vim.api.nvim_get_current_win()
  remember(vim.api.nvim_win_get_buf(win))
  require("config.workspace").schedule_explorer_width()
  return win
end

local function split_with_buffer(anchor, buf)
  vim.api.nvim_set_current_win(anchor)
  local ok, err = pcall(vim.cmd, "rightbelow vsplit")
  if not ok then
    vim.notify(err, vim.log.levels.ERROR, { title = "Terminal group" })
    return nil
  end
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  require("config.workspace").schedule_explorer_width()
  return win
end

local function create_secondary(anchor)
  vim.api.nvim_set_current_win(anchor)
  local ok, err = pcall(vim.cmd, "rightbelow vsplit | terminal")
  if not ok then
    vim.notify(err, vim.log.levels.ERROR, { title = "Terminal group" })
    return nil
  end
  local win = vim.api.nvim_get_current_win()
  remember(vim.api.nvim_win_get_buf(win))
  require("config.workspace").schedule_explorer_width()
  return win
end

function M.show()
  local visible = terminal_windows()
  if visible[1] then
    focus(visible[1])
    return true
  end

  local buffers = group_buffers()
  if #buffers == 0 then
    local primary = create_primary()
    focus(primary)
    return primary ~= nil
  end

  anchor_editor()
  local ok, err = pcall(vim.cmd, ("botright %dsplit"):format(terminal_height()))
  if not ok then
    vim.notify(err, vim.log.levels.ERROR, { title = "Terminal group" })
    return false
  end
  local primary = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(primary, buffers[1])
  if buffers[2] then
    split_with_buffer(primary, buffers[2])
  end
  require("config.workspace").schedule_explorer_width()
  focus(primary)
  return true
end

function M.hide()
  local visible = terminal_windows()
  if #visible == 0 then
    return true
  end

  local regular = vim.tbl_filter(function(win)
    return vim.api.nvim_win_get_config(win).relative == ""
  end, vim.api.nvim_tabpage_list_wins(0))
  if #regular <= #visible then
    require("config.workspace").open()
  end

  for index = #visible, 1, -1 do
    local win = visible[index]
    if vim.api.nvim_win_is_valid(win) then
      local buf = vim.api.nvim_win_get_buf(win)
      vim.api.nvim_set_option_value("bufhidden", "hide", { buf = buf })
      local ok, err = pcall(vim.api.nvim_win_close, win, false)
      if not ok then
        vim.notify(err, vim.log.levels.ERROR, { title = "Terminal group" })
        return false
      end
    end
  end
  require("config.workspace").schedule_explorer_width()
  return true
end

function M.toggle()
  if #terminal_windows() > 0 then
    return M.hide()
  end
  return M.show()
end

function M.split()
  if #terminal_windows() == 0 then
    return M.show()
  end

  local visible = terminal_windows()
  local buffers = group_buffers()
  if #visible >= M.max_terminals then
    local current = vim.api.nvim_get_current_win()
    focus(current == visible[1] and visible[2] or visible[1])
    return true
  end

  local secondary
  if buffers[2] then
    secondary = split_with_buffer(visible[1], buffers[2])
  else
    secondary = create_secondary(visible[1])
  end
  focus(secondary)
  return secondary ~= nil
end

function M.count()
  return #terminal_windows(), #group_buffers()
end

return M
