local LazyVim = require("lazyvim.util")

local M = {
  max_tabs = 4,
  _arranging = false,
}

---@type table<number, number[]>
local histories = {}

local starter_filetypes = {
  alpha = true,
  dashboard = true,
  ministarter = true,
  snacks_dashboard = true,
}

local function is_regular_window(win)
  return vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative == ""
end

local function is_editor_window(win)
  if not is_regular_window(win) then
    return false
  end

  local buf = vim.api.nvim_win_get_buf(win)
  local filetype = vim.api.nvim_get_option_value("filetype", { buf = buf })
  local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })
  return filetype ~= "neo-tree" and buftype == ""
end

local function editor_windows()
  local windows = vim.tbl_filter(is_editor_window, vim.api.nvim_tabpage_list_wins(0))
  table.sort(windows, function(left, right)
    local left_position = vim.api.nvim_win_get_position(left)
    local right_position = vim.api.nvim_win_get_position(right)
    return left_position[2] == right_position[2] and left_position[1] < right_position[1]
      or left_position[2] < right_position[2]
  end)
  return windows
end

local function tree_window()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if is_regular_window(win) then
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.api.nvim_get_option_value("filetype", { buf = buf }) == "neo-tree" then
        return win
      end
    end
  end
end

local function valid_editor_buffer(buf)
  return vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_get_option_value("buftype", { buf = buf }) == ""
end

local function clean_history(win)
  local cleaned = {}
  local seen = {}
  for _, buf in ipairs(histories[win] or {}) do
    if valid_editor_buffer(buf) and not seen[buf] then
      seen[buf] = true
      cleaned[#cleaned + 1] = buf
    end
  end
  histories[win] = cleaned
  return cleaned
end

local function buffer_is_visible(buf)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
      return true
    end
  end
  return false
end

local function buffer_belongs_to_another_pane(buf, excluded_win)
  for win, history in pairs(histories) do
    if win ~= excluded_win then
      for _, candidate in ipairs(history) do
        if candidate == buf then
          return true
        end
      end
    end
  end
  return false
end

local function close_buffer_if_safe(buf, excluded_win)
  if not valid_editor_buffer(buf) then
    return
  end
  if vim.api.nvim_get_option_value("modified", { buf = buf }) then
    return
  end
  if buffer_is_visible(buf) or buffer_belongs_to_another_pane(buf, excluded_win) then
    return
  end
  pcall(vim.api.nvim_buf_delete, buf, { force = false })
end

local function record_buffer(win, buf)
  if M._arranging or not is_editor_window(win) or not valid_editor_buffer(buf) then
    return
  end

  local history = clean_history(win)
  if vim.tbl_contains(history, buf) then
    return
  end

  history[#history + 1] = buf
  while #history > M.max_tabs do
    local evicted = table.remove(history, 1)
    close_buffer_if_safe(evicted, win)
  end
  histories[win] = history
end

local function remove_buffer_from_histories(buf)
  for win, history in pairs(histories) do
    histories[win] = vim.tbl_filter(function(candidate)
      return candidate ~= buf
    end, history)
  end
end

local function arrange(callback)
  local previous = M._arranging
  M._arranging = true
  local ok, result = xpcall(callback, debug.traceback)
  M._arranging = previous
  if not ok then
    vim.notify(result, vim.log.levels.ERROR, { title = "Workspace layout" })
    return nil
  end
  return result
end

local function fresh_buffer(buf)
  local filetype = vim.api.nvim_get_option_value("filetype", { buf = buf })
  if starter_filetypes[filetype] then
    return true
  end

  return vim.api.nvim_buf_get_name(buf) == ""
    and not vim.api.nvim_get_option_value("modified", { buf = buf })
    and vim.api.nvim_get_option_value("buftype", { buf = buf }) == ""
    and vim.api.nvim_buf_line_count(buf) == 1
    and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
end

function M.should_open_automatically()
  if vim.g.vscode or #vim.api.nvim_list_uis() == 0 then
    return false
  end
  if vim.fn.argc(-1) ~= 0 or vim.v.this_session ~= "" then
    return false
  end
  if #vim.api.nvim_list_tabpages() ~= 1 or #vim.api.nvim_tabpage_list_wins(0) ~= 1 then
    return false
  end
  return fresh_buffer(vim.api.nvim_get_current_buf())
end

function M.tabs(win)
  win = win or vim.api.nvim_get_current_win()
  local history = clean_history(win)
  if #history == 0 and is_editor_window(win) then
    local current = vim.api.nvim_win_get_buf(win)
    if valid_editor_buffer(current) then
      return { current }
    end
  end
  return vim.list_slice(history)
end

function M.pane_role(win)
  for index, editor in ipairs(editor_windows()) do
    if editor == win then
      if index == 1 then
        return "L"
      elseif index == 2 then
        return "R"
      end
      return tostring(index)
    end
  end
end

function M.ensure_editor_panes()
  if vim.g.vscode then
    return {}
  end

  local windows = arrange(function()
    local editors = editor_windows()
    if #editors == 0 then
      vim.cmd("rightbelow vnew")
      editors = editor_windows()
    end
    if #editors == 1 then
      vim.api.nvim_set_current_win(editors[1])
      -- Preserve the existing editor on the right and create the Explorer's
      -- deterministic file target on its left.
      vim.cmd("leftabove vnew")
    end
    return editor_windows()
  end) or editor_windows()

  for _, win in ipairs(windows) do
    record_buffer(win, vim.api.nvim_win_get_buf(win))
  end
  return windows
end

function M.open_or_focus_explorer()
  if vim.g.vscode then
    return
  end

  local source_win = is_editor_window(vim.api.nvim_get_current_win()) and vim.api.nvim_get_current_win() or nil
  local path = vim.api.nvim_buf_get_name(0)
  local root = LazyVim.root()
  M.ensure_editor_panes()
  local source_role = source_win and M.pane_role(source_win) or nil
  if source_role then
    vim.t.workspace_last_editor_role = source_role
  end

  local existing = tree_window()
  if existing then
    vim.api.nvim_set_current_win(existing)
    return
  end

  require("neo-tree.command").execute({
    action = "focus",
    source = "filesystem",
    position = "left",
    dir = root,
    reveal_file = path ~= "" and path or nil,
    reveal_force_cwd = true,
  })
end

function M.open_file_in_next_pane(path, state)
  if vim.g.vscode or not path or path == "" then
    return false
  end

  local editors = M.ensure_editor_panes()
  local source_role = vim.t.workspace_last_editor_role
  local target_role = source_role == "L" and "R" or "L"
  local target = target_role == "R" and editors[2] or editors[1]
  if not target or not vim.api.nvim_win_is_valid(target) then
    vim.notify("No target editor pane is available", vim.log.levels.ERROR)
    return false
  end

  vim.api.nvim_set_current_win(target)
  local ok, err = pcall(vim.cmd.edit, vim.fn.fnameescape(path))
  if not ok then
    vim.notify(err, vim.log.levels.ERROR, { title = "Open file" })
    return false
  end

  record_buffer(target, vim.api.nvim_win_get_buf(target))
  vim.t.workspace_last_editor_role = target_role
  if state then
    local events = require("neo-tree.events")
    events.fire_event(events.FILE_OPENED, path)
  end
  return true
end

function M.open_from_tree(state)
  local node = state.tree:get_node()
  if not node then
    return
  end

  if node.type ~= "file" then
    require("neo-tree.sources.filesystem.commands").open(state)
    return
  end

  local utils = require("neo-tree.utils")
  local config = state.config or {}
  local should_expand_file = config.expand_nested_files and not node:is_expanded()
  if utils.is_expandable(node) and should_expand_file then
    require("neo-tree.sources.filesystem.commands").open(state)
    return
  end

  M.open_file_in_next_pane(node.path or node:get_id(), state)
end

function M.cycle_tabs(direction)
  local win = vim.api.nvim_get_current_win()
  if not is_editor_window(win) then
    return
  end

  local current = vim.api.nvim_win_get_buf(win)
  record_buffer(win, current)
  local tabs = M.tabs(win)
  if #tabs < 2 then
    return
  end

  local index = 1
  for position, buf in ipairs(tabs) do
    if buf == current then
      index = position
      break
    end
  end
  local target = ((index - 1 + direction) % #tabs) + 1
  local ok, err = pcall(vim.api.nvim_win_set_buf, win, tabs[target])
  if not ok then
    vim.notify(err, vim.log.levels.ERROR, { title = "Pane tabs" })
  end
end

function M.open()
  if vim.g.vscode then
    return
  end

  local root = LazyVim.root()
  arrange(function()
    local current_buf = vim.api.nvim_get_current_buf()
    local current_ft = vim.api.nvim_get_option_value("filetype", { buf = current_buf })
    if starter_filetypes[current_ft] and not vim.api.nvim_get_option_value("modified", { buf = current_buf }) then
      vim.cmd.enew()
    end

    local editors = M.ensure_editor_panes()
    require("neo-tree.command").execute({
      action = "show",
      source = "filesystem",
      position = "left",
      dir = root,
    })

    if editors[1] and vim.api.nvim_win_is_valid(editors[1]) then
      vim.api.nvim_set_current_win(editors[1])
      vim.t.workspace_last_editor_role = "L"
    end
    vim.cmd.wincmd("=")
  end)

  for _, win in ipairs(editor_windows()) do
    record_buffer(win, vim.api.nvim_win_get_buf(win))
  end
end

function M.setup()
  vim.api.nvim_create_user_command("WorkspaceLayout", M.open, {
    desc = "Open Explorer with two independent editor panes",
  })
  vim.keymap.set("n", "<leader>wL", M.open, { desc = "Workspace Layout" })

  local history_group = vim.api.nvim_create_augroup("workspace_tabs", { clear = true })
  vim.api.nvim_create_autocmd("BufEnter", {
    group = history_group,
    callback = function()
      record_buffer(vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf())
    end,
  })
  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = history_group,
    callback = function(event)
      remove_buffer_from_histories(event.buf)
    end,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = history_group,
    callback = function(event)
      histories[tonumber(event.match)] = nil
    end,
  })
  vim.api.nvim_create_autocmd("WinEnter", {
    group = history_group,
    callback = function()
      if M._arranging then
        return
      end
      local role = M.pane_role(vim.api.nvim_get_current_win())
      if role then
        vim.t.workspace_last_editor_role = role
      end
    end,
  })

  local function open_fresh_workspace()
    vim.schedule(function()
      if M.should_open_automatically() then
        M.open()
      end
    end)
  end

  if vim.v.vim_did_enter == 1 then
    open_fresh_workspace()
  else
    vim.api.nvim_create_autocmd("UIEnter", {
      group = vim.api.nvim_create_augroup("workspace_layout", { clear = true }),
      once = true,
      callback = open_fresh_workspace,
    })
  end

  vim.schedule(function()
    record_buffer(vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf())
  end)
end

return M
