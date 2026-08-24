local LazyVim = require("lazyvim.util")

local M = {
  explorer_width = 34,
  max_tabs = 4,
  _arranging = false,
  _cleanup_scheduled = false,
  _opening_explorer = false,
  _resize_scheduled = false,
}

---@type table<number, number[]>
local histories = {}
local cycle_namespace = vim.api.nvim_create_namespace("workspace_file_cycle")
local cycle_key_namespace = vim.api.nvim_create_namespace("workspace_file_cycle_keys")
local cycle_menu = { generation = 0 }

local starter_filetypes = {
  alpha = true,
  dashboard = true,
  ministarter = true,
  snacks_dashboard = true,
}

local function is_regular_window(win)
  return vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative == ""
end

local function is_exiting()
  return vim.v.exiting ~= vim.NIL
end

local function normalize_existing_directory(path)
  if not path or path == "" then
    return nil
  end

  path = vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(path), ":p"))
  local stat = vim.uv.fs_stat(path)
  return stat and stat.type == "directory" and path or nil
end

local function real_file_path(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if vim.api.nvim_get_option_value("buftype", { buf = buf }) ~= "" then
    return nil
  end

  local path = vim.api.nvim_buf_get_name(buf)
  if path == "" or path:match("^%a[%w+.-]*://") then
    return nil
  end

  path = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
  local stat = vim.uv.fs_stat(path)
  return stat and stat.type == "file" and path or nil
end

local function explorer_root()
  return normalize_existing_directory(vim.t.workspace_root)
    or normalize_existing_directory(LazyVim.root())
    or normalize_existing_directory(vim.fn.getcwd())
end

function M.root()
  return explorer_root()
end

local function is_empty_editor_buffer(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return false
  end

  local filetype = vim.api.nvim_get_option_value("filetype", { buf = buf })
  local modified = vim.api.nvim_get_option_value("modified", { buf = buf })
  if starter_filetypes[filetype] and not modified then
    return true
  end

  return vim.api.nvim_get_option_value("buftype", { buf = buf }) == ""
    and vim.api.nvim_buf_get_name(buf) == ""
    and not modified
    and vim.api.nvim_buf_line_count(buf) == 1
    and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
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

local function is_empty_pane_window(win)
  if not is_regular_window(win) then
    return false
  end
  local buf = vim.api.nvim_win_get_buf(win)
  return vim.api.nvim_get_option_value("filetype", { buf = buf }) ~= "neo-tree" and is_empty_editor_buffer(buf)
end

local function is_file_window(win)
  return is_editor_window(win) and not is_empty_editor_buffer(vim.api.nvim_win_get_buf(win))
end

local function editor_windows(tabpage)
  local windows = vim.tbl_filter(is_file_window, vim.api.nvim_tabpage_list_wins(tabpage or 0))
  table.sort(windows, function(left, right)
    local left_position = vim.api.nvim_win_get_position(left)
    local right_position = vim.api.nvim_win_get_position(right)
    return left_position[2] == right_position[2] and left_position[1] < right_position[1]
      or left_position[2] < right_position[2]
  end)
  return windows
end

local function active_editor_window()
  local current = vim.api.nvim_get_current_win()
  if is_file_window(current) then
    return current
  end

  local editors = editor_windows()
  if vim.t.workspace_last_editor_role == "R" and editors[2] then
    return editors[2]
  end
  return editors[1]
end

function M.active_editor_window()
  return active_editor_window()
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

function M.restore_explorer_width()
  local tree = tree_window()
  if not tree then
    return false
  end

  local has_other_window = false
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if win ~= tree and is_regular_window(win) then
      has_other_window = true
      break
    end
  end
  if not has_other_window then
    return false
  end

  vim.api.nvim_set_option_value("winfixwidth", true, { win = tree })
  local available = math.max(1, vim.o.columns - 20)
  local ok = pcall(vim.api.nvim_win_set_width, tree, math.min(M.explorer_width, available))

  local editors = editor_windows()
  if #editors == 2 then
    local left_position = vim.api.nvim_win_get_position(editors[1])
    local right_position = vim.api.nvim_win_get_position(editors[2])
    if left_position[2] ~= right_position[2] then
      local total_width = vim.api.nvim_win_get_width(editors[1]) + vim.api.nvim_win_get_width(editors[2])
      pcall(vim.api.nvim_win_set_width, editors[1], math.floor(total_width / 2))
    end
  end
  return ok
end

function M.schedule_explorer_width()
  if M._resize_scheduled or is_exiting() then
    return
  end
  M._resize_scheduled = true
  vim.schedule(function()
    M._resize_scheduled = false
    if not is_exiting() then
      M.restore_explorer_width()
    end
  end)
end

local function valid_editor_buffer(buf)
  return vim.api.nvim_buf_is_valid(buf)
    and vim.api.nvim_get_option_value("buftype", { buf = buf }) == ""
    and not is_empty_editor_buffer(buf)
end

-- Pane tabs and the Alt+l carousel contain only named, loaded file buffers.
-- Excluding anonymous scratch buffers and detached listed buffers keeps the
-- cycle deterministic and prevents unrelated files from appearing at random.
local function valid_cycle_buffer(buf)
  if not valid_editor_buffer(buf) or not vim.api.nvim_buf_is_loaded(buf) or not vim.bo[buf].buflisted then
    return false
  end
  local name = vim.api.nvim_buf_get_name(buf)
  return name ~= "" and not name:match("^%a[%w+.-]*://")
end

local function clean_history(win)
  local cleaned = {}
  local seen = {}
  for _, buf in ipairs(histories[win] or {}) do
    if valid_cycle_buffer(buf) and not seen[buf] then
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
  if M._arranging or not is_editor_window(win) or not valid_cycle_buffer(buf) then
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

local function close_cycle_menu()
  cycle_menu.generation = cycle_menu.generation + 1
  vim.on_key(nil, cycle_key_namespace)
  if cycle_menu.win and vim.api.nvim_win_is_valid(cycle_menu.win) then
    vim.api.nvim_win_close(cycle_menu.win, true)
  end
  if cycle_menu.buf and vim.api.nvim_buf_is_valid(cycle_menu.buf) then
    vim.api.nvim_buf_delete(cycle_menu.buf, { force = true })
  end
  cycle_menu.win = nil
  cycle_menu.buf = nil
  cycle_menu.mode = nil
  cycle_menu.entries = nil
  cycle_menu.selected = nil
end

local function cycle_label(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" then
    return "Untitled"
  end
  local parent = vim.fn.fnamemodify(name, ":h:t")
  local basename = vim.fn.fnamemodify(name, ":t")
  local modified = vim.api.nvim_get_option_value("modified", { buf = buf }) and "  ●" or ""
  return (parent ~= "" and parent ~= "." and (parent .. "/") or "") .. basename .. modified
end

local function fit_cycle_label(value, width)
  if vim.fn.strdisplaywidth(value) <= width then
    return value
  end
  local room = math.max(1, width - 1)
  local result = ""
  for index = 0, vim.fn.strchars(value) - 1 do
    local character = vim.fn.strcharpart(value, index, 1)
    if vim.fn.strdisplaywidth(result .. character) > room then
      break
    end
    result = result .. character
  end
  return result .. "…"
end

local function cycle_item_buffer(item)
  return type(item) == "table" and item.buf or item
end

local function show_cycle_menu(owner, tabs, selected, opts)
  opts = opts or {}
  if not vim.api.nvim_win_is_valid(owner) then
    return
  end

  local owner_width = opts.global and vim.o.columns or vim.api.nvim_win_get_width(owner)
  local owner_height = opts.global and (vim.o.lines - vim.o.cmdheight) or vim.api.nvim_win_get_height(owner)
  local width = math.min(opts.global and 88 or 60, math.max(1, owner_width - (opts.global and 4 or 2)))
  local lines = {}
  for index, item in ipairs(tabs) do
    local marker = index == selected and "▸" or " "
    local context = type(item) == "table" and item.context or nil
    local prefix = string.format("%s %d", marker, index)
    if context then
      prefix = prefix .. "  [" .. context .. "]"
    end
    prefix = prefix .. "  "
    local label =
      fit_cycle_label(cycle_label(cycle_item_buffer(item)), math.max(1, width - vim.fn.strdisplaywidth(prefix)))
    lines[index] = prefix .. label
  end

  local buf = cycle_menu.buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    buf = vim.api.nvim_create_buf(false, true)
    cycle_menu.buf = buf
    vim.bo[buf].bufhidden = "hide"
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].filetype = "file_cycle_menu"
    vim.bo[buf].swapfile = false
  end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(buf, cycle_namespace, 0, -1)
  for index = 1, #lines do
    vim.api.nvim_buf_set_extmark(buf, cycle_namespace, index - 1, 0, {
      end_col = 0,
      hl_eol = true,
      line_hl_group = index == selected and "PmenuSel" or "Pmenu",
      priority = 500,
    })
  end
  vim.bo[buf].modifiable = false

  local max_height = math.max(1, owner_height - (opts.global and 4 or 2))
  if opts.global then
    max_height = math.min(max_height, 16)
  end
  local height = math.min(#lines, max_height)
  local config
  if opts.global then
    config = {
      relative = "editor",
      width = width,
      height = height,
      row = 1,
      col = math.max(0, math.floor((vim.o.columns - width) / 2)),
      style = "minimal",
      border = "rounded",
      focusable = false,
      title = " All Open Files · Pane/Window ",
      title_pos = "center",
      zindex = 250,
    }
  else
    config = {
      relative = "win",
      win = owner,
      width = width,
      height = height,
      row = math.min(1, math.max(0, owner_height - height)),
      col = math.max(0, math.floor((owner_width - width) / 2)),
      style = "minimal",
      border = "rounded",
      focusable = false,
      title = " Open Files ",
      title_pos = "center",
      zindex = 250,
    }
  end

  if
    cycle_menu.win
    and vim.api.nvim_win_is_valid(cycle_menu.win)
    and vim.api.nvim_win_get_tabpage(cycle_menu.win) ~= vim.api.nvim_get_current_tabpage()
  then
    vim.api.nvim_win_close(cycle_menu.win, true)
    cycle_menu.win = nil
  end
  if cycle_menu.win and vim.api.nvim_win_is_valid(cycle_menu.win) then
    vim.api.nvim_win_set_config(cycle_menu.win, config)
  else
    cycle_menu.win = vim.api.nvim_open_win(buf, false, config)
    vim.wo[cycle_menu.win].winblend = 5
    vim.wo[cycle_menu.win].winhighlight = "NormalFloat:Pmenu,FloatBorder:FloatBorder"
  end
  vim.wo[cycle_menu.win].wrap = false

  pcall(vim.api.nvim_win_set_cursor, cycle_menu.win, { selected, 0 })
  local topline = math.max(1, math.min(selected - math.floor(height / 2), #lines - height + 1))
  pcall(vim.api.nvim_win_call, cycle_menu.win, function()
    vim.fn.winrestview({ topline = topline, leftcol = 0 })
  end)

  cycle_menu.generation = cycle_menu.generation + 1
  local generation = cycle_menu.generation
  if opts.global then
    vim.on_key(function(_, typed)
      if typed == "" then
        return
      end
      local key = vim.fn.keytrans(typed)
      if key == "<M-l>" then
        return
      end
      vim.schedule(function()
        if cycle_menu.generation == generation then
          close_cycle_menu()
        end
      end)
    end, cycle_key_namespace)
    return
  end
  vim.defer_fn(function()
    if cycle_menu.generation == generation then
      close_cycle_menu()
    end
  end, 650)
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

local function open_tree(options)
  if M._opening_explorer then
    return true
  end

  options.dir = normalize_existing_directory(options.dir) or explorer_root()
  options.reveal_file = options.reveal_file and real_file_path() or nil
  if not options.reveal_file then
    options.reveal_force_cwd = nil
  end
  if not options.dir then
    vim.notify("No existing directory is available for Explorer", vim.log.levels.ERROR, { title = "Explorer" })
    return false
  end

  M._opening_explorer = true
  local ok, err = pcall(require("neo-tree.command").execute, options)
  if not ok then
    M._opening_explorer = false
    vim.notify(err, vim.log.levels.ERROR, { title = "Explorer" })
    return false
  end

  vim.defer_fn(function()
    M._opening_explorer = false
    M.schedule_empty_pane_cleanup()
    M.schedule_explorer_width()
  end, 50)
  return true
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
  return is_empty_editor_buffer(vim.api.nvim_get_current_buf())
end

function M.tabs(win)
  win = win or vim.api.nvim_get_current_win()
  local history = clean_history(win)
  if #history == 0 and is_editor_window(win) then
    local current = vim.api.nvim_win_get_buf(win)
    if valid_cycle_buffer(current) then
      return { current }
    end
  end
  return vim.list_slice(history)
end

function M.pane_role(win)
  if not win or not vim.api.nvim_win_is_valid(win) then
    return nil
  end

  local tabpage = vim.api.nvim_win_get_tabpage(win)
  for index, editor in ipairs(editor_windows(tabpage)) do
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

local function pane_cycle_label(index)
  if index == 1 then
    return "L"
  elseif index == 2 then
    return "R"
  end
  return "W" .. index
end

local function window_cycle_context(win)
  if not win or not vim.api.nvim_win_is_valid(win) then
    return "Open"
  end

  local tabpages = vim.api.nvim_list_tabpages()
  local owner_tab = vim.api.nvim_win_get_tabpage(win)
  for tab_index, tabpage in ipairs(tabpages) do
    if tabpage == owner_tab then
      for pane_index, editor in ipairs(editor_windows(tabpage)) do
        if editor == win then
          local pane = pane_cycle_label(pane_index)
          return #tabpages > 1 and ("T%d:%s"):format(tab_index, pane) or pane
        end
      end
    end
  end
  return "Open"
end

local function all_open_file_entries()
  local entries = {}
  local seen = {}
  local tabpages = vim.api.nvim_list_tabpages()

  for tab_index, tabpage in ipairs(tabpages) do
    for pane_index, win in ipairs(editor_windows(tabpage)) do
      local buffers = M.tabs(win)
      local visible = vim.api.nvim_win_get_buf(win)
      if valid_cycle_buffer(visible) and not vim.tbl_contains(buffers, visible) then
        buffers[#buffers + 1] = visible
      end

      local pane = pane_cycle_label(pane_index)
      local context = #tabpages > 1 and ("T%d:%s"):format(tab_index, pane) or pane
      for _, buf in ipairs(buffers) do
        if valid_cycle_buffer(buf) and not seen[buf] then
          seen[buf] = true
          entries[#entries + 1] = {
            buf = buf,
            win = win,
            tabpage = tabpage,
            context = context,
          }
        end
      end
    end
  end

  return entries
end

local function find_current_cycle_entry(entries)
  local current_win = vim.api.nvim_get_current_win()
  local current_buf = vim.api.nvim_get_current_buf()
  local buffer_match
  for index, entry in ipairs(entries) do
    if entry.buf == current_buf then
      if entry.win == current_win then
        return index
      end
      buffer_match = buffer_match or index
    end
  end
  return buffer_match
end

local function cycle_snapshot_is_current(entries, selected)
  local entry = entries and entries[selected]
  if not entry or entry.buf ~= vim.api.nvim_get_current_buf() then
    return false
  end
  return not entry.win or entry.win == vim.api.nvim_get_current_win()
end

local function clean_cycle_snapshot(entries, selected)
  local cleaned = {}
  local cleaned_selected
  for index, entry in ipairs(entries or {}) do
    if valid_cycle_buffer(entry.buf) then
      cleaned[#cleaned + 1] = entry
      if index == selected then
        cleaned_selected = #cleaned
      end
    end
  end
  return cleaned, cleaned_selected
end

local function focus_cycle_entry(entry)
  local win = entry.win
  if not win or not vim.api.nvim_win_is_valid(win) or not is_editor_window(win) then
    win = active_editor_window()
    if not win then
      for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
        win = editor_windows(tabpage)[1]
        if win then
          break
        end
      end
    end
  end
  if not win then
    return nil, "No editor pane is available"
  end

  local ok, err = pcall(function()
    local tabpage = vim.api.nvim_win_get_tabpage(win)
    if tabpage ~= vim.api.nvim_get_current_tabpage() then
      vim.api.nvim_set_current_tabpage(tabpage)
    end
    vim.api.nvim_set_current_win(win)
    vim.api.nvim_win_set_buf(win, entry.buf)
  end)
  if not ok then
    return nil, err
  end

  entry.win = win
  entry.tabpage = vim.api.nvim_win_get_tabpage(win)
  entry.context = window_cycle_context(win)
  local role = M.pane_role(win)
  if role then
    vim.t.workspace_last_editor_role = role
  end
  return win
end

function M.close_empty_panes()
  if vim.g.vscode or M._arranging or is_exiting() then
    return
  end

  local needs_explorer = false
  arrange(function()
    local candidates = vim.tbl_filter(function(win)
      return is_empty_pane_window(win)
    end, vim.api.nvim_tabpage_list_wins(0))

    for _, win in ipairs(candidates) do
      if vim.api.nvim_win_is_valid(win) then
        local has_other_window = false
        for _, other in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          if other ~= win and is_regular_window(other) then
            has_other_window = true
            break
          end
        end

        if has_other_window then
          local buf = vim.api.nvim_win_get_buf(win)
          pcall(vim.api.nvim_win_close, win, false)
          if vim.api.nvim_buf_is_valid(buf) and is_empty_editor_buffer(buf) and not buffer_is_visible(buf) then
            pcall(vim.api.nvim_buf_delete, buf, { force = false })
          end
        else
          -- Neovim cannot close its final window. Replace a last empty editor
          -- with Explorer, then let the scheduled cleanup remove the editor.
          needs_explorer = true
        end
      end
    end
  end)

  if needs_explorer then
    open_tree({
      action = "focus",
      source = "filesystem",
      position = "left",
      dir = explorer_root(),
    })
  end
end

function M.schedule_empty_pane_cleanup()
  if vim.g.vscode or M._cleanup_scheduled or is_exiting() then
    return
  end
  M._cleanup_scheduled = true
  vim.schedule(function()
    M._cleanup_scheduled = false
    if is_exiting() then
      return
    end
    M.close_empty_panes()
  end)
end

function M.open_or_focus_explorer()
  if vim.g.vscode then
    return
  end

  local source_win = is_editor_window(vim.api.nvim_get_current_win()) and vim.api.nvim_get_current_win() or nil
  local path = real_file_path()
  local root = explorer_root()
  local source_role = source_win and M.pane_role(source_win) or nil
  if source_role then
    vim.t.workspace_last_editor_role = source_role
    -- Neo-tree may briefly enter another editor while creating/focusing its
    -- split. Keep the pane that the user actually came from separately so
    -- that those internal window events cannot change the routing target.
    vim.t.workspace_explorer_source_role = source_role
  end

  local existing = tree_window()
  if existing then
    vim.api.nvim_set_current_win(existing)
    M.schedule_empty_pane_cleanup()
    M.schedule_explorer_width()
    return
  end

  open_tree({
    action = "focus",
    source = "filesystem",
    position = "left",
    dir = root,
    reveal_file = path ~= "" and path or nil,
    reveal_force_cwd = true,
  })
end

function M.toggle_explorer()
  if vim.g.vscode then
    return
  end

  local existing = tree_window()
  if existing then
    local regular_windows = vim.tbl_filter(is_regular_window, vim.api.nvim_tabpage_list_wins(0))
    if #regular_windows == 1 then
      vim.notify("Explorer is the only window; open a file before hiding it", vim.log.levels.WARN, {
        title = "Explorer",
      })
      return false
    end

    local ok, err = pcall(require("neo-tree.command").execute, {
      action = "close",
      source = "filesystem",
      position = "left",
    })
    if not ok then
      vim.notify(err, vim.log.levels.ERROR, { title = "Explorer" })
      return false
    end
    return true
  end

  return open_tree({
    action = "focus",
    source = "filesystem",
    position = "left",
    dir = explorer_root(),
  })
end

function M.reveal_current_file()
  if vim.g.vscode then
    return
  end

  local path = real_file_path()
  open_tree({
    action = "focus",
    source = "filesystem",
    position = "left",
    dir = explorer_root(),
    reveal_file = path,
    reveal_force_cwd = path ~= nil,
  })
end

function M.open_file_in_next_pane(path, state)
  if vim.g.vscode or not path or path == "" then
    return false
  end

  M.close_empty_panes()
  local editors = editor_windows()
  local source_role = vim.t.workspace_explorer_source_role or vim.t.workspace_last_editor_role
  vim.t.workspace_explorer_source_role = nil

  local absolute_path = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
  for _, win in ipairs(editors) do
    local buf = vim.api.nvim_win_get_buf(win)
    local name = vim.api.nvim_buf_get_name(buf)
    if name ~= "" and vim.fs.normalize(vim.fn.fnamemodify(name, ":p")) == absolute_path then
      vim.api.nvim_set_current_win(win)
      vim.t.workspace_last_editor_role = M.pane_role(win)
      if state then
        local events = require("neo-tree.events")
        events.fire_event(events.FILE_OPENED, path)
      end
      M.schedule_explorer_width()
      return true
    end
  end

  local target
  local ok
  local err
  if #editors < 2 then
    local anchor = editors[1] or tree_window() or vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(anchor)
    ok, err = pcall(vim.cmd, "rightbelow vsplit " .. vim.fn.fnameescape(path))
    target = ok and vim.api.nvim_get_current_win() or nil
  else
    local target_role = source_role == "L" and "R" or "L"
    target = target_role == "R" and editors[2] or editors[1]
    if target and vim.api.nvim_win_is_valid(target) then
      vim.api.nvim_set_current_win(target)
      ok, err = pcall(vim.cmd.edit, vim.fn.fnameescape(path))
    end
  end

  if not ok or not target or not vim.api.nvim_win_is_valid(target) then
    vim.notify(tostring(err or "No target editor pane is available"), vim.log.levels.ERROR, { title = "Open file" })
    return false
  end

  record_buffer(target, vim.api.nvim_win_get_buf(target))
  vim.t.workspace_last_editor_role = M.pane_role(target)
  M.schedule_empty_pane_cleanup()
  M.schedule_explorer_width()
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

function M.cycle_tabs(direction, opts)
  opts = opts or {}
  local win = active_editor_window()
  if not win then
    return
  end

  vim.api.nvim_set_current_win(win)
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
  elseif opts.menu then
    show_cycle_menu(win, tabs, target)
  end
end

---Move the active file into the adjacent editor pane without moving windows.
---Explorer and auxiliary windows are never considered destinations.
---@param direction integer Negative moves left; positive moves right.
---@return boolean
function M.move_current_file(direction)
  local source = vim.api.nvim_get_current_win()
  if not is_file_window(source) then
    vim.notify("Focus a file before moving it between editor panes", vim.log.levels.WARN, { title = "Move file" })
    return false
  end

  local current = vim.api.nvim_win_get_buf(source)
  if not valid_cycle_buffer(current) then
    vim.notify("Only a named file can be moved between editor panes", vim.log.levels.WARN, { title = "Move file" })
    return false
  end

  local editors = editor_windows()
  local source_index = vim.fn.index(editors, source) + 1
  local target = editors[source_index + (direction < 0 and -1 or 1)]
  if not target then
    return false
  end

  local target_visible = vim.api.nvim_win_get_buf(target)
  if target_visible == current then
    vim.api.nvim_set_current_win(target)
    vim.t.workspace_last_editor_role = M.pane_role(target)
    return true
  end

  local source_tabs = M.tabs(source)
  if not vim.tbl_contains(source_tabs, current) then
    source_tabs[#source_tabs + 1] = current
  end
  local target_tabs = M.tabs(target)
  if valid_cycle_buffer(target_visible) and not vim.tbl_contains(target_tabs, target_visible) then
    target_tabs[#target_tabs + 1] = target_visible
  end

  local current_index = vim.fn.index(source_tabs, current) + 1
  local replacement = source_tabs[current_index + 1] or source_tabs[current_index - 1]
  local swapping_visible_files = not replacement
  replacement = replacement or target_visible

  local source_history = vim.tbl_filter(function(buf)
    return buf ~= current
  end, source_tabs)
  local target_history = vim.tbl_filter(function(buf)
    return buf ~= current and (not swapping_visible_files or buf ~= target_visible)
  end, target_tabs)

  if valid_cycle_buffer(replacement) and not vim.tbl_contains(source_history, replacement) then
    source_history[#source_history + 1] = replacement
  end
  target_history[#target_history + 1] = current

  local evicted = {}
  while #target_history > M.max_tabs do
    evicted[#evicted + 1] = table.remove(target_history, 1)
  end

  local source_view = vim.api.nvim_win_call(source, vim.fn.winsaveview)
  local moved = arrange(function()
    vim.api.nvim_win_set_buf(source, replacement)
    vim.api.nvim_set_current_win(target)
    vim.api.nvim_win_set_buf(target, current)
    vim.api.nvim_win_call(target, function()
      vim.fn.winrestview(source_view)
    end)
    return true
  end)
  if not moved then
    return false
  end

  histories[source] = source_history
  histories[target] = target_history
  for _, buf in ipairs(evicted) do
    close_buffer_if_safe(buf, target)
  end

  vim.t.workspace_last_editor_role = M.pane_role(target)
  M.schedule_explorer_width()
  return true
end

function M.cycle_all_files(direction)
  direction = direction < 0 and -1 or 1

  local entries, current
  local reuse_snapshot = false
  if cycle_menu.mode == "global" then
    entries, current = clean_cycle_snapshot(cycle_menu.entries, cycle_menu.selected)
    reuse_snapshot = cycle_snapshot_is_current(entries, current)
  end
  if not reuse_snapshot then
    entries = all_open_file_entries()
    current = find_current_cycle_entry(entries)
  end
  if #entries == 0 then
    return false
  end

  if not current then
    current = direction > 0 and 0 or 1
  end
  local target = #entries == 1 and 1 or ((current - 1 + direction) % #entries) + 1
  local owner, err = focus_cycle_entry(entries[target])
  if not owner then
    vim.notify(err, vim.log.levels.ERROR, { title = "Open files" })
    close_cycle_menu()
    return false
  end

  -- Entering the target can evict and delete an old unmodified pane tab.
  -- Remove it before rendering so a long carousel never references a stale
  -- buffer or rebuilds itself in the middle of a key-repeat sequence.
  entries, target = clean_cycle_snapshot(entries, target)
  cycle_menu.mode = "global"
  cycle_menu.entries = entries
  cycle_menu.selected = target
  show_cycle_menu(owner, entries, target, { global = true })
  return true
end

function M.select_tab(index)
  local win = active_editor_window()
  if not win then
    return false
  end

  local tabs = M.tabs(win)
  index = index < 0 and #tabs + index + 1 or index
  local target = tabs[index]
  if not target then
    return false
  end

  vim.api.nvim_set_current_win(win)
  local ok, err = pcall(vim.api.nvim_win_set_buf, win, target)
  if not ok then
    vim.notify(err, vim.log.levels.ERROR, { title = "Pane tabs" })
    return false
  end
  vim.t.workspace_last_editor_role = M.pane_role(win)
  return true
end

function M.close_current_tab()
  local win = active_editor_window()
  if not win then
    return false
  end

  vim.api.nvim_set_current_win(win)
  local current = vim.api.nvim_win_get_buf(win)
  record_buffer(win, current)
  local tabs = M.tabs(win)

  if vim.api.nvim_get_option_value("modified", { buf = current }) then
    local name = vim.api.nvim_buf_get_name(current)
    name = name ~= "" and vim.fn.fnamemodify(name, ":t") or "Untitled"
    local ok, choice = pcall(vim.fn.confirm, ('Save changes to "%s"?'):format(name), "&Yes\n&No\n&Cancel")
    if not ok or choice == 0 or choice == 3 then
      return false
    end
    if choice == 1 then
      local wrote, write_err = pcall(vim.api.nvim_buf_call, current, vim.cmd.write)
      if not wrote then
        vim.notify(write_err, vim.log.levels.ERROR, { title = "Close pane tab" })
        return false
      end
    end
  end

  if #tabs > 1 then
    local current_index = vim.fn.index(tabs, current) + 1
    local target_index = current_index < #tabs and current_index + 1 or current_index - 1
    vim.api.nvim_win_set_buf(win, tabs[target_index])
  end

  local ok, err = pcall(vim.api.nvim_buf_delete, current, { force = true })
  if not ok then
    vim.notify(err, vim.log.levels.ERROR, { title = "Close pane tab" })
    return false
  end
  M.schedule_empty_pane_cleanup()
  return true
end

function M.close_other_tabs()
  local win = active_editor_window()
  if not win then
    return false
  end

  vim.api.nvim_set_current_win(win)
  local current = vim.api.nvim_win_get_buf(win)
  record_buffer(win, current)
  local kept = { current }
  local skipped = 0

  for _, buf in ipairs(M.tabs(win)) do
    if buf ~= current then
      local modified = vim.api.nvim_get_option_value("modified", { buf = buf })
      local shared = buffer_is_visible(buf) or buffer_belongs_to_another_pane(buf, win)
      if modified or shared or not pcall(vim.api.nvim_buf_delete, buf, { force = false }) then
        kept[#kept + 1] = buf
        skipped = skipped + 1
      end
    end
  end
  histories[win] = kept

  if skipped > 0 then
    vim.notify(("Kept %d modified or shared pane tab(s)"):format(skipped), vim.log.levels.WARN)
  end
  return true
end

function M.open()
  if vim.g.vscode then
    return
  end

  local root = explorer_root()
  open_tree({
    action = "focus",
    source = "filesystem",
    position = "left",
    dir = root,
  })
end

function M.setup()
  vim.api.nvim_create_user_command("WorkspaceLayout", M.open, {
    desc = "Open Explorer with up to two file-backed editor panes",
  })
  vim.keymap.set("n", "<leader>wL", M.open, { desc = "Workspace Layout" })

  local history_group = vim.api.nvim_create_augroup("workspace_tabs", { clear = true })
  vim.api.nvim_create_autocmd("BufEnter", {
    group = history_group,
    callback = function()
      record_buffer(vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf())
      M.schedule_empty_pane_cleanup()
    end,
  })
  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = history_group,
    callback = function(event)
      remove_buffer_from_histories(event.buf)
      M.schedule_empty_pane_cleanup()
    end,
  })
  vim.api.nvim_create_autocmd("WinNew", {
    group = history_group,
    callback = function()
      M.schedule_empty_pane_cleanup()
      M.schedule_explorer_width()
    end,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = history_group,
    callback = function(event)
      histories[tonumber(event.match)] = nil
      M.schedule_explorer_width()
    end,
  })
  vim.api.nvim_create_autocmd("VimResized", {
    group = history_group,
    callback = M.schedule_explorer_width,
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
