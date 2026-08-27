local M = {}

local api = vim.api
local namespace = api.nvim_create_namespace("responsive_markdown_tables")
local pending = {}
local table_cache = {}
local layout_cache = {}
local segment_cache = {}
local editing = {}
local render_state = {}
local mark_ids = {}
local saved_wrap = {}

local function is_markdown(buf)
  return api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype:match("^markdown") ~= nil
end

local function trim(value)
  return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Split a pipe row without treating escaped pipes or pipes inside inline code
-- as column separators.
local function split_row(line)
  if not line:find("|", 1, true) then
    return nil
  end

  local cells, current = {}, {}
  local code_fence
  local index = 1
  while index <= #line do
    local char = line:sub(index, index)
    if char == "\\" and index < #line then
      current[#current + 1] = line:sub(index + 1, index + 1)
      index = index + 2
    elseif char == "`" then
      local finish = index
      while line:sub(finish + 1, finish + 1) == "`" do
        finish = finish + 1
      end
      local fence = finish - index + 1
      if not code_fence then
        code_fence = fence
      elseif code_fence == fence then
        code_fence = nil
      end
      current[#current + 1] = line:sub(index, finish)
      index = finish + 1
    elseif char == "|" and not code_fence then
      cells[#cells + 1] = table.concat(current)
      current = {}
      index = index + 1
    else
      current[#current + 1] = char
      index = index + 1
    end
  end
  cells[#cells + 1] = table.concat(current)

  if trim(cells[1]) == "" then
    table.remove(cells, 1)
  end
  if #cells > 0 and trim(cells[#cells]) == "" then
    table.remove(cells)
  end
  if #cells < 2 then
    return nil
  end
  return vim.tbl_map(trim, cells)
end

local function is_delimiter(cells)
  if not cells then
    return false
  end
  for _, cell in ipairs(cells) do
    if not trim(cell):match("^:?-+:?$") then
      return false
    end
  end
  return true
end

local function display_text(value)
  value = value:gsub("<[bB][rR]%s*/?>", " ")
  value = value:gsub("!%[([^%]]-)%]%([^%)]-%)", "%1")
  value = value:gsub("%[([^%]]-)%]%([^%)]-%)", "%1")
  value = value:gsub("%[([^%]]-)%]%[[^%]]-%]", "%1")
  value = value:gsub("`+([^`]-)`+", "%1")
  value = value:gsub("%*%*", ""):gsub("__", "")
  value = value:gsub("~~", ""):gsub("&nbsp;", " ")
  return trim(value:gsub("%s+", " "))
end

local function normalize_row(row, columns)
  local result = {}
  for index = 1, columns do
    result[index] = display_text(row[index] or "")
  end
  return result
end

local function parse_tables(buf)
  local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
  local result = {}
  local line = 1
  local fence_char, fence_width
  while line < #lines do
    local stripped = trim(lines[line])
    local fence = stripped:match("^(```+)") or stripped:match("^(~~~+)")
    if fence then
      local char = fence:sub(1, 1)
      if not fence_char then
        fence_char, fence_width = char, #fence
      elseif char == fence_char and #fence >= fence_width then
        fence_char, fence_width = nil, nil
      end
      line = line + 1
    elseif fence_char or lines[line]:match("^    ") or lines[line]:match("^\t") then
      line = line + 1
    else
      local header = split_row(lines[line])
      local delimiter = split_row(lines[line + 1])
      if header and delimiter and #header == #delimiter and is_delimiter(delimiter) then
        local rows = {}
        local finish = line + 1
        while finish + 1 <= #lines do
          local row = split_row(lines[finish + 1])
          if not row then
            break
          end
          rows[#rows + 1] = normalize_row(row, #header)
          finish = finish + 1
        end
        result[#result + 1] = {
          first = line,
          last = finish,
          indent = lines[line]:match("^(%s*)") or "",
          header = normalize_row(header, #header),
          rows = rows,
        }
        line = finish + 1
      else
        line = line + 1
      end
    end
  end
  return result
end

local function tables(buf)
  if not table_cache[buf] then
    table_cache[buf] = parse_tables(buf)
  end
  return table_cache[buf]
end

-- Tables are parsed in source order and cannot overlap. Binary searches keep
-- cursor movement independent of the number of tables in a large document.
local function first_table_ending_at_or_after(markdown_tables, row)
  local low, high = 1, #markdown_tables + 1
  while low < high do
    local middle = math.floor((low + high) / 2)
    if markdown_tables[middle].last < row then
      low = middle + 1
    else
      high = middle
    end
  end
  return low
end

local function table_at_line(buf, row)
  local markdown_tables = tables(buf)
  local markdown_table = markdown_tables[first_table_ending_at_or_after(markdown_tables, row)]
  if markdown_table and markdown_table.first <= row then
    return markdown_table
  end
end

-- Arabic alignment uses this query to avoid shifting a rendered table row.
-- Keep the remote renderer unchanged apart from this non-visual compatibility
-- hook for the local multilingual functionality.
function M.contains_line(buf, row)
  return table_at_line(buf, row) ~= nil
end

local function nearest_table(buf, row)
  local markdown_tables = tables(buf)
  local index = first_table_ending_at_or_after(markdown_tables, row)
  local after = markdown_tables[index]
  if after and after.first <= row then
    return after
  end
  local before = markdown_tables[index - 1]
  if not before then
    return after
  elseif not after then
    return before
  end
  return row - before.last <= after.first - row and before or after
end

local function table_intersects(buf, first, last)
  local markdown_tables = tables(buf)
  local index = first_table_ending_at_or_after(markdown_tables, first)
  local markdown_table = markdown_tables[index]
  return markdown_table ~= nil and markdown_table.first <= last
end

local function restore_window_wrap(win)
  local state = saved_wrap[win]
  if not state then
    return
  end
  if api.nvim_win_is_valid(win) then
    vim.wo[win].wrap = state.value
  end
  saved_wrap[win] = nil
end

local function restore_buffer_wrap(buf)
  for win, state in pairs(saved_wrap) do
    if state.buf == buf then
      restore_window_wrap(win)
    end
  end
end

-- Concealed source text still contributes to Neovim's native line wrapping,
-- which creates blank display rows underneath long formatted table rows. The
-- responsive renderer already wraps every cell itself, so use nowrap only
-- while a table intersects this window and restore the user's setting as soon
-- as the table leaves the viewport.
local function update_table_wrap(buf)
  local current_win = api.nvim_get_current_win()
  local insert_mode = buf == api.nvim_get_current_buf() and api.nvim_get_mode().mode:match("^[iR]") ~= nil
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    if api.nvim_win_is_valid(win) then
      local info = vim.fn.getwininfo(win)[1]
      local has_visible_table = info
        and not (insert_mode and win == current_win)
        and table_intersects(buf, info.topline, info.botline)
      if has_visible_table then
        if saved_wrap[win] and saved_wrap[win].buf ~= buf then
          restore_window_wrap(win)
        end
        if not saved_wrap[win] then
          saved_wrap[win] = { buf = buf, value = vim.wo[win].wrap }
        end
        if vim.wo[win].wrap then
          vim.wo[win].wrap = false
        end
      elseif saved_wrap[win] and saved_wrap[win].buf == buf then
        restore_window_wrap(win)
      end
    end
  end
end

-- Let general window-option autocmds ask whether this renderer currently owns
-- 'wrap'. This prevents a later WinEnter/BufWinEnter callback from restoring
-- native wrapping underneath virtual table rows and creating display gaps.
function M.update_wrap(buf, win)
  buf = buf or api.nvim_get_current_buf()
  win = win or api.nvim_get_current_win()
  if not is_markdown(buf) or vim.b[buf].responsive_markdown_tables_disabled then
    restore_buffer_wrap(buf)
    return false
  end
  update_table_wrap(buf)
  local state = saved_wrap[win]
  return state ~= nil and state.buf == buf
end

local function text_width(value)
  return vim.fn.strdisplaywidth(value)
end

local function take_width(value, width)
  local count = vim.fn.strchars(value)
  local used = 0
  local index = 0
  while index < count do
    local char = vim.fn.strcharpart(value, index, 1)
    local char_width = text_width(char)
    if used + char_width > width then
      break
    end
    used = used + char_width
    index = index + 1
  end
  return vim.fn.strcharpart(value, 0, index), vim.fn.strcharpart(value, index), used
end

local function wrap_text(value, width)
  if value == "" then
    return { "" }
  end

  local result, current = {}, ""
  for word in value:gmatch("%S+") do
    while text_width(word) > width do
      if current ~= "" then
        result[#result + 1] = current
        current = ""
      end
      local chunk
      chunk, word = take_width(word, width)
      result[#result + 1] = chunk
    end
    if word ~= "" then
      local candidate = current == "" and word or (current .. " " .. word)
      if text_width(candidate) <= width then
        current = candidate
      else
        result[#result + 1] = current
        current = word
      end
    end
  end
  if current ~= "" then
    result[#result + 1] = current
  end
  return #result > 0 and result or { "" }
end

local function pad(value, width)
  return value .. string.rep(" ", math.max(0, width - text_width(value)))
end

local function available_width(buf)
  local available
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    if api.nvim_win_is_valid(win) then
      local info = vim.fn.getwininfo(win)[1] or {}
      local width = api.nvim_win_get_width(win) - (info.textoff or 0) - 1
      available = math.min(available or width, width)
    end
  end
  return math.max(20, available or 80)
end

local function column_widths(markdown_table, available)
  local columns = #markdown_table.header
  local overhead = (3 * columns) + 1
  local usable = available - text_width(markdown_table.indent) - overhead
  -- Columns narrower than ten cells turn commands and labels into vertical
  -- letter stacks. A labeled card layout is clearer below this threshold.
  if usable < columns * 10 then
    return nil
  end

  local natural = {}
  for column = 1, columns do
    natural[column] = math.max(4, text_width(markdown_table.header[column]))
    for _, row in ipairs(markdown_table.rows) do
      natural[column] = math.max(natural[column], text_width(row[column]))
    end
  end

  local widths, used = {}, 0
  local base_width = math.min(10, math.floor(usable / columns))
  for column = 1, columns do
    widths[column] = math.min(base_width, natural[column])
    used = used + widths[column]
  end
  local remaining = usable - used
  while remaining > 0 do
    local best, score = nil, 0
    for column = 1, columns do
      if widths[column] < natural[column] then
        -- Diminishing returns keep narrow columns usable while still giving
        -- more of the live window width to columns with longer content.
        local current_score = math.sqrt(natural[column]) / widths[column]
        if current_score > score then
          best, score = column, current_score
        end
      end
    end
    if not best then
      break
    end
    widths[best] = widths[best] + 1
    remaining = remaining - 1
  end
  return widths
end

local function cached_column_widths(buf, markdown_table, available)
  layout_cache[buf] = layout_cache[buf] or {}
  local key = string.format("%d:%d:%d", markdown_table.first, markdown_table.last, available)
  local cached = layout_cache[buf][key]
  if cached ~= nil then
    return cached ~= false and cached or nil
  end
  local widths = column_widths(markdown_table, available)
  layout_cache[buf][key] = widths or false
  return widths
end

local function border_line(indent, widths, left, middle, right)
  local parts = {}
  for _, width in ipairs(widths) do
    parts[#parts + 1] = string.rep("─", width + 2)
  end
  return { { indent .. left .. table.concat(parts, middle) .. right, "RenderMarkdownTableHead" } }
end

local function grid_row(indent, cells, widths, highlight)
  local wrapped, height = {}, 1
  for column, width in ipairs(widths) do
    wrapped[column] = wrap_text(cells[column], width)
    height = math.max(height, #wrapped[column])
  end

  local result = {}
  for row = 1, height do
    local chunks = { { indent .. "│", "RenderMarkdownTableHead" } }
    for column, width in ipairs(widths) do
      chunks[#chunks + 1] = { " " .. pad(wrapped[column][row] or "", width) .. " ", highlight }
      chunks[#chunks + 1] = { "│", "RenderMarkdownTableHead" }
    end
    result[#result + 1] = chunks
  end
  return result
end

local function stacked_row(markdown_table, row, width)
  local indent = markdown_table.indent
  local result = {}
  for column, header in ipairs(markdown_table.header) do
    local label = header ~= "" and header or ("Column " .. column)
    for _, part in ipairs(wrap_text(label .. ":", width - 2)) do
      result[#result + 1] = {
        { indent .. "│ ", "RenderMarkdownTableHead" },
        { pad(part, width - 2), "RenderMarkdownTableHead" },
        { " │", "RenderMarkdownTableHead" },
      }
    end
    for _, part in ipairs(wrap_text(row[column], width - 2)) do
      result[#result + 1] = {
        { indent .. "│ ", "RenderMarkdownTableRow" },
        { pad(part, width - 2), "RenderMarkdownTableRow" },
        { " │", "RenderMarkdownTableHead" },
      }
    end
  end
  return result
end

local function render_segment(markdown_table, available, source_row, widths)
  if source_row < markdown_table.first or source_row > markdown_table.last then
    return {}
  end

  local indent = markdown_table.indent
  if not widths then
    local width = math.max(8, available - text_width(indent) - 2)
    if source_row == markdown_table.first then
      local result = {
        { { indent .. "╭" .. string.rep("─", width) .. "╮", "RenderMarkdownTableHead" } },
      }
      if #markdown_table.rows == 0 then
        vim.list_extend(result, stacked_row(markdown_table, markdown_table.header, width))
      end
      return result
    elseif source_row == markdown_table.first + 1 then
      if #markdown_table.rows == 0 then
        return { { { indent .. "╰" .. string.rep("─", width) .. "╯", "RenderMarkdownTableRow" } } }
      end
      return { { { indent .. "├" .. string.rep("─", width) .. "┤", "RenderMarkdownTableHead" } } }
    end

    local index = source_row - markdown_table.first - 1
    local row = markdown_table.rows[index]
    if not row then
      return {}
    end
    local result = stacked_row(markdown_table, row, width)
    result[#result + 1] = {
      {
        indent
          .. (index < #markdown_table.rows and "├" or "╰")
          .. string.rep("─", width)
          .. (index < #markdown_table.rows and "┤" or "╯"),
        "RenderMarkdownTableRow",
      },
    }
    return result
  end

  if source_row == markdown_table.first then
    local result = { border_line(indent, widths, "┌", "┬", "┐") }
    vim.list_extend(result, grid_row(indent, markdown_table.header, widths, "RenderMarkdownTableHead"))
    return result
  elseif source_row == markdown_table.first + 1 then
    local result = { border_line(indent, widths, "├", "┼", "┤") }
    if #markdown_table.rows == 0 then
      result[#result + 1] = border_line(indent, widths, "└", "┴", "┘")
    end
    return result
  end

  local index = source_row - markdown_table.first - 1
  local row = markdown_table.rows[index]
  if not row then
    return {}
  end
  local result = grid_row(indent, row, widths, "RenderMarkdownTableRow")
  result[#result + 1] = index < #markdown_table.rows and border_line(indent, widths, "├", "┼", "┤")
    or border_line(indent, widths, "└", "┴", "┘")
  return result
end

local function cached_rendered_row(buf, markdown_table, width, widths, source_row)
  local changedtick = api.nvim_buf_get_changedtick(buf)
  local cache = segment_cache[buf]
  if not cache or cache.changedtick ~= changedtick or cache.width ~= width then
    cache = { changedtick = changedtick, width = width, tables = {} }
    segment_cache[buf] = cache
  end

  local key = string.format("%d:%d", markdown_table.first, markdown_table.last)
  local rendered_rows = cache.tables[key]
  if not rendered_rows then
    rendered_rows = {}
    cache.tables[key] = rendered_rows
  end
  if rendered_rows[source_row] then
    return rendered_rows[source_row]
  end

  local source_line = api.nvim_buf_get_lines(buf, source_row - 1, source_row, false)[1] or ""
  local signature = string.format("%d:%d:%d:%d", changedtick, width, markdown_table.first, markdown_table.last)
  local segment = render_segment(markdown_table, width, source_row, widths)
  local extra_lines = {}
  for index = 2, #segment do
    extra_lines[#extra_lines + 1] = segment[index]
  end
  local opts = {
    end_row = source_row - 1,
    end_col = #source_line,
    conceal = "",
    virt_text = segment[1],
    virt_text_pos = "overlay",
    virt_text_hide = false,
    priority = 300,
  }
  if #extra_lines > 0 then
    opts.virt_lines = extra_lines
  end
  rendered_rows[source_row] = {
    key = string.format("table-row:%d", source_row),
    signature = signature,
    row = source_row - 1,
    segment = segment,
    opts = opts,
  }
  return rendered_rows[source_row]
end

local function render_table(buf, marks, markdown_table, width, active_row, first, last)
  local widths = cached_column_widths(buf, markdown_table, width)
  local active = active_row and active_row >= markdown_table.first and active_row <= markdown_table.last and active_row
  local render_first = math.max(markdown_table.first, first)
  local render_last = math.min(markdown_table.last, last)
  for source_row = render_first, render_last do
    if source_row ~= active then
      marks[#marks + 1] = cached_rendered_row(buf, markdown_table, width, widths, source_row)
    end
  end
  if active and active >= render_first and active <= render_last then
    local rendered = cached_rendered_row(buf, markdown_table, width, widths, active)
    local frame
    local above = false
    if active == markdown_table.first then
      frame = { rendered.segment[1] }
      above = true
    elseif active == markdown_table.first + 1 then
      frame = rendered.segment
    else
      frame = { rendered.segment[#rendered.segment] }
    end
    marks[#marks + 1] = {
      key = string.format("table-edit-frame:%d", active),
      signature = rendered.signature .. ":edit-frame",
      row = active - 1,
      opts = {
        virt_lines = frame,
        virt_lines_above = above,
        priority = 300,
      },
    }
  end
end

local function clear_marks(buf)
  api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
  mark_ids[buf] = nil
end

-- Rows use stable keyed extmarks. On cursor movement only the row being left
-- and the row being entered change; every other formatted row remains intact.
-- This keeps very long tables responsive without hiding or paging any rows.
local function apply_marks(buf, marks)
  local states = mark_ids[buf] or {}
  local used = {}
  for _, mark in ipairs(marks) do
    used[mark.key] = true
    local state = states[mark.key]
    if not state or state.signature ~= mark.signature then
      local opts = vim.tbl_extend("force", {}, mark.opts)
      if state then
        opts.id = state.id
      end
      states[mark.key] = {
        id = api.nvim_buf_set_extmark(buf, namespace, mark.row, 0, opts),
        signature = mark.signature,
      }
    end
  end
  for key, state in pairs(states) do
    if not used[key] then
      pcall(api.nvim_buf_del_extmark, buf, namespace, state.id)
      states[key] = nil
    end
  end
  mark_ids[buf] = states
end

local function visible_range(buf)
  local first, last, height
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    if api.nvim_win_is_valid(win) then
      local info = vim.fn.getwininfo(win)[1]
      if info then
        first = math.min(first or info.topline, info.topline)
        last = math.max(last or info.botline, info.botline)
      end
      height = math.max(height or 0, api.nvim_win_get_height(win))
    end
  end

  if not first then
    local row = editing[buf] or 1
    first, last, height = row, row, 24
  elseif buf == api.nvim_get_current_buf() then
    local row = api.nvim_win_get_cursor(0)[1]
    first, last = math.min(first, row), math.max(last, row)
  end
  return first, last, math.max(8, height or 24)
end

local function nearby_range(buf)
  local first, last, height = visible_range(buf)
  local line_count = api.nvim_buf_line_count(buf)
  -- Render several windows ahead so a table is ready before it scrolls into
  -- view, but keep work bounded no matter how many tables the file contains.
  local margin = height * 3
  return math.max(1, first - margin), math.min(line_count, last + margin), first, last, height
end

local function needs_cursor_refresh(buf)
  local state = render_state[buf]
  if not state then
    return true
  end
  local row = api.nvim_win_get_cursor(0)[1]
  return row < state.safe_first or row > state.safe_last
end

local function needs_scroll_refresh(buf)
  local state = render_state[buf]
  if not state then
    return true
  end
  local first, last = visible_range(buf)
  return first < state.safe_first or last > state.safe_last
end

local function place_cursor(buf, row, column)
  if buf ~= api.nvim_get_current_buf() then
    return
  end
  local line = api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
  local target = { row, math.min(column, #line) }
  local current = api.nvim_win_get_cursor(0)
  if current[1] ~= target[1] or current[2] ~= target[2] then
    api.nvim_win_set_cursor(0, target)
  end
end

function M.render(buf)
  if not buf or buf == 0 then
    buf = api.nvim_get_current_buf()
  end
  if not is_markdown(buf) then
    return
  end
  if vim.b[buf].responsive_markdown_tables_disabled then
    restore_buffer_wrap(buf)
    clear_marks(buf)
    render_state[buf] = nil
    return
  end
  update_table_wrap(buf)
  local mode = buf == api.nvim_get_current_buf() and api.nvim_get_mode().mode or ""
  local active_row = editing[buf] and mode:match("^[iR]") and editing[buf] or nil
  local active_cursor
  if active_row then
    active_cursor = api.nvim_win_get_cursor(0)
  end
  local width = available_width(buf)
  local first, last, visible_first, visible_last, viewport_height = nearby_range(buf)
  local markdown_tables = tables(buf)
  local index = first_table_ending_at_or_after(markdown_tables, first)
  local marks = {}
  while markdown_tables[index] and markdown_tables[index].first <= last do
    render_table(buf, marks, markdown_tables[index], width, active_row, first, last)
    index = index + 1
  end
  apply_marks(buf, marks)
  render_state[buf] = {
    first = first,
    last = last,
    safe_first = math.max(1, visible_first - viewport_height),
    safe_last = math.min(api.nvim_buf_line_count(buf), visible_last + viewport_height),
  }
  -- Keep the cursor fixed while its row switches between the formatted
  -- overlay and editable Markdown.
  if active_cursor and active_row == active_cursor[1] then
    place_cursor(buf, active_cursor[1], active_cursor[2])
  end
end

local function schedule(buf)
  if pending[buf] then
    return
  end
  pending[buf] = true
  vim.schedule(function()
    pending[buf] = nil
    M.render(buf)
  end)
end

local function sync_edit_state(buf)
  if not is_markdown(buf) or vim.b[buf].responsive_markdown_tables_disabled then
    return
  end
  if not api.nvim_get_mode().mode:match("^[iR]") then
    if editing[buf] then
      editing[buf] = nil
      schedule(buf)
    end
    return
  end
  local row = api.nvim_win_get_cursor(0)[1]
  if table_at_line(buf, row) then
    if editing[buf] ~= row then
      editing[buf] = row
      schedule(buf)
    end
  elseif editing[buf] then
    editing[buf] = nil
    schedule(buf)
  end
end

function M.edit(buf)
  buf = buf or api.nvim_get_current_buf()
  if not is_markdown(buf) then
    return
  end
  local cursor = api.nvim_win_get_cursor(0)
  local markdown_table = nearest_table(buf, cursor[1])
  if not markdown_table then
    vim.notify("No Markdown table found in this buffer", vim.log.levels.WARN)
    return
  end

  local target_row = cursor[1]
  if cursor[1] < markdown_table.first or cursor[1] > markdown_table.last then
    target_row = markdown_table.first
    local line = api.nvim_buf_get_lines(buf, markdown_table.first - 1, markdown_table.first, false)[1] or ""
    local pipe = line:find("|", 1, true)
    local column = pipe and pipe or math.max(0, (line:find("%S") or 1) - 1)
    while line:sub(column + 1, column + 1) == " " do
      column = column + 1
    end
    api.nvim_win_set_cursor(0, { markdown_table.first, column })
  end
  editing[buf] = target_row
  M.render(buf)
  vim.schedule(vim.cmd.startinsert)
end

local function motion_crosses_table(delta)
  local buf = api.nvim_get_current_buf()
  if not is_markdown(buf) then
    return false
  end
  local row = api.nvim_win_get_cursor(0)[1]
  local target = math.max(1, math.min(api.nvim_buf_line_count(buf), row + (delta * vim.v.count1)))
  return table_intersects(buf, math.min(row, target), math.max(row, target))
end

function M.move_row(delta)
  local buf = api.nvim_get_current_buf()
  if not is_markdown(buf) then
    return false
  end

  local cursor = api.nvim_win_get_cursor(0)
  local count = vim.v.count1
  local target = math.max(1, math.min(api.nvim_buf_line_count(buf), cursor[1] + (delta * count)))
  local crosses_table = table_intersects(buf, math.min(cursor[1], target), math.max(cursor[1], target))
  if not crosses_table then
    return false
  end

  local line = api.nvim_buf_get_lines(buf, target - 1, target, false)[1] or ""
  local target_column = math.min(cursor[2], #line)
  api.nvim_win_set_cursor(0, { target, target_column })
  editing[buf] = api.nvim_get_mode().mode:match("^[iR]") and table_at_line(buf, target) and target or nil
  M.render(buf)
  -- The destination is always a real buffer row. Reassert it after swapping
  -- that row from its formatted overlay to editable Markdown.
  place_cursor(buf, target, target_column)
  return true
end

local function movement_mapping(buf, mode, key, delta, fallback)
  local description = delta > 0 and "Next Markdown table row" or "Previous Markdown table row"
  if mode == "n" then
    local plug = delta > 0 and "<Plug>(ResponsiveMarkdownTableDown)" or "<Plug>(ResponsiveMarkdownTableUp)"
    vim.keymap.set("n", plug, function()
      M.move_row(delta)
    end, { buffer = buf, desc = description })
    vim.keymap.set("n", key, function()
      -- Returning the native key from an expression mapping avoids adding a
      -- second key to Neovim's input queue for every j/k outside a table.
      return motion_crosses_table(delta) and plug or fallback
    end, {
      buffer = buf,
      desc = description,
      expr = true,
      replace_keycodes = true,
    })
    return
  end

  vim.keymap.set(mode, key, function()
    if M.move_row(delta) then
      return
    end
    api.nvim_feedkeys(api.nvim_replace_termcodes(fallback, true, false, true), "n", false)
  end, {
    buffer = buf,
    desc = description,
  })
end

function M.setup()
  local group = api.nvim_create_augroup("responsive_markdown_tables", { clear = true })

  api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = { "markdown", "markdown.mdx" },
    callback = function(args)
      table_cache[args.buf] = nil
      layout_cache[args.buf] = nil
      segment_cache[args.buf] = nil
      render_state[args.buf] = nil
      schedule(args.buf)
      vim.keymap.set("n", "<leader>mt", function()
        M.edit(args.buf)
      end, { buffer = args.buf, desc = "Edit nearest Markdown table" })
      movement_mapping(args.buf, "n", "j", 1, "j")
      movement_mapping(args.buf, "n", "k", -1, "k")
      movement_mapping(args.buf, "n", "<Down>", 1, "<Down>")
      movement_mapping(args.buf, "n", "<Up>", -1, "<Up>")
      movement_mapping(args.buf, "i", "<Down>", 1, "<Down>")
      movement_mapping(args.buf, "i", "<Up>", -1, "<Up>")
    end,
    desc = "Render Markdown tables within the available window width",
  })

  api.nvim_create_autocmd({ "BufWinEnter", "WinEnter", "WinResized", "VimResized" }, {
    group = group,
    callback = function()
      local buf = api.nvim_get_current_buf()
      if is_markdown(buf) then
        schedule(buf)
      end
    end,
    desc = "Resize responsive Markdown tables",
  })

  api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "InsertLeave" }, {
    group = group,
    callback = function(args)
      if is_markdown(args.buf) then
        table_cache[args.buf] = nil
        layout_cache[args.buf] = nil
        segment_cache[args.buf] = nil
        render_state[args.buf] = nil
        if args.event == "InsertLeave" then
          sync_edit_state(args.buf)
          schedule(args.buf)
        elseif args.event == "TextChanged" then
          schedule(args.buf)
        end
        -- TextChangedI only invalidates the inexpensive caches. Reparse once
        -- on InsertLeave instead of scanning a very long document after every
        -- inserted character. Table arrow motions still call render directly.
      end
    end,
    desc = "Refresh responsive Markdown tables",
  })

  api.nvim_create_autocmd("InsertEnter", {
    group = group,
    callback = function(args)
      if is_markdown(args.buf) then
        local row = api.nvim_win_get_cursor(0)[1]
        if table_at_line(args.buf, row) then
          editing[args.buf] = row
          -- InsertEnter fires just before Neovim reports insert mode. Render
          -- on the next event-loop tick so the editable source row is
          -- revealed while its border frame stays attached.
          schedule(args.buf)
        end
      end
    end,
    desc = "Reveal Markdown table source while editing",
  })

  api.nvim_create_autocmd("CursorMoved", {
    group = group,
    callback = function(args)
      if args.buf == api.nvim_get_current_buf() then
        sync_edit_state(args.buf)
        update_table_wrap(args.buf)
        if needs_cursor_refresh(args.buf) then
          schedule(args.buf)
        end
      end
    end,
    desc = "Reveal the Markdown table under the cursor for editing",
  })

  api.nvim_create_autocmd("WinScrolled", {
    group = group,
    callback = function()
      local buf = api.nvim_get_current_buf()
      if is_markdown(buf) then
        update_table_wrap(buf)
        if needs_scroll_refresh(buf) then
          schedule(buf)
        end
      end
    end,
    desc = "Prepare responsive Markdown tables near the visible window",
  })

  api.nvim_create_autocmd("BufWipeout", {
    group = group,
    callback = function(args)
      restore_buffer_wrap(args.buf)
      pending[args.buf] = nil
      table_cache[args.buf] = nil
      layout_cache[args.buf] = nil
      segment_cache[args.buf] = nil
      render_state[args.buf] = nil
      mark_ids[args.buf] = nil
      editing[args.buf] = nil
    end,
    desc = "Forget responsive Markdown table state",
  })

  api.nvim_create_autocmd("BufLeave", {
    group = group,
    callback = function(args)
      restore_buffer_wrap(args.buf)
    end,
    desc = "Restore Markdown wrapping after leaving the buffer",
  })

  api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(args)
      saved_wrap[tonumber(args.match)] = nil
    end,
    desc = "Forget closed Markdown table windows",
  })

  api.nvim_create_user_command("MarkdownTableEdit", function()
    M.edit()
  end, { desc = "Edit the nearest responsive Markdown table", force = true })

  api.nvim_create_user_command("MarkdownTableViewToggle", function()
    local buf = api.nvim_get_current_buf()
    vim.b[buf].responsive_markdown_tables_disabled = not vim.b[buf].responsive_markdown_tables_disabled
    editing[buf] = nil
    M.render(buf)
  end, { desc = "Toggle responsive Markdown table rendering", force = true })
end

return M
