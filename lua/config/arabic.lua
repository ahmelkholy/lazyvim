local M = {}

-- Keep the remote UI's connected box-drawing separator. Arabic alignment is
-- pane-scoped, so it does not need to replace this visual boundary.
local bidi_separator = "│"
local original_separator
local alignment_namespaces = {}
local alignment_buffers = {}
local refresh_pending = {}
local refresh_scheduled = false
local window_scoped_namespaces = type(vim.api.nvim__ns_set) == "function"
local namespace_warning_shown = false

local function notify(message, level, quiet)
  if not quiet then
    vim.notify(message, level or vim.log.levels.INFO, { title = "Arabic display" })
  end
end

local function terminal_name()
  if vim.env.TERM_PROGRAM and vim.env.TERM_PROGRAM ~= "" then
    return vim.env.TERM_PROGRAM
  elseif vim.env.LC_TERMINAL and vim.env.LC_TERMINAL ~= "" then
    return vim.env.LC_TERMINAL
  elseif vim.env.KONSOLE_VERSION then
    return "Konsole"
  elseif vim.env.VTE_VERSION then
    return "VTE " .. vim.env.VTE_VERSION
  elseif vim.env.WT_SESSION then
    return "Windows Terminal"
  end
  return vim.env.TERM or "unknown"
end

local function enabled(value)
  if value == true or value == 1 then
    return true
  end
  if type(value) == "string" then
    value = value:lower()
    return value == "1" or value == "true" or value == "yes" or value == "on"
  end
  return false
end

local function disabled(value)
  if value == false or value == 0 then
    return true
  end
  if type(value) == "string" then
    value = value:lower()
    return value == "0" or value == "false" or value == "no" or value == "off"
  end
  return false
end

local function clear_rightleft_windows()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) then
      vim.wo[win].rightleft = false
    end
  end
end

local function set_current_buffer_mode(mode)
  vim.b.arabic_display_mode = mode
end

local function set_bidi_separator(enabled)
  local separator = enabled and bidi_separator or original_separator
  if separator and separator ~= "" then
    vim.opt.fillchars:append({ vert = separator })
  end
end

function M.is_arabic_codepoint(codepoint)
  return (codepoint >= 0x0600 and codepoint <= 0x06ff)
    or (codepoint >= 0x0750 and codepoint <= 0x077f)
    or (codepoint >= 0x0870 and codepoint <= 0x089f)
    or (codepoint >= 0x08a0 and codepoint <= 0x08ff)
    or (codepoint >= 0xfb50 and codepoint <= 0xfdff)
    or (codepoint >= 0xfe70 and codepoint <= 0xfeff)
    or (codepoint >= 0x10ec0 and codepoint <= 0x10eff)
    or (codepoint >= 0x1ee00 and codepoint <= 0x1eeff)
end

local function is_arabic_strong(codepoint)
  return (codepoint >= 0x0620 and codepoint <= 0x063f)
    or (codepoint >= 0x0641 and codepoint <= 0x064a)
    or (codepoint >= 0x066e and codepoint <= 0x066f)
    or (codepoint >= 0x0671 and codepoint <= 0x06d3)
    or codepoint == 0x06d5
    or (codepoint >= 0x06ee and codepoint <= 0x06ef)
    or (codepoint >= 0x06fa and codepoint <= 0x06fc)
    or codepoint == 0x06ff
    or (codepoint >= 0x0750 and codepoint <= 0x077f)
    or (codepoint >= 0x0870 and codepoint <= 0x088f)
    or (codepoint >= 0x08a0 and codepoint <= 0x08c9)
    or (codepoint >= 0xfb50 and codepoint <= 0xfdff)
    or (codepoint >= 0xfe70 and codepoint <= 0xfefc)
    or (codepoint >= 0x10ec0 and codepoint <= 0x10efb)
    or (codepoint >= 0x1ee00 and codepoint <= 0x1eeff)
end

local function is_ltr_strong(codepoint)
  return (codepoint >= 0x0041 and codepoint <= 0x005a)
    or (codepoint >= 0x0061 and codepoint <= 0x007a)
    or (codepoint >= 0x0400 and codepoint <= 0x0481)
    or (codepoint >= 0x048a and codepoint <= 0x052f)
    or (codepoint >= 0x1c80 and codepoint <= 0x1c8f)
    or (codepoint >= 0xa640 and codepoint <= 0xa69d)
end

local function is_cyrillic(codepoint)
  return (codepoint >= 0x0400 and codepoint <= 0x052f)
    or (codepoint >= 0x1c80 and codepoint <= 0x1c8f)
    or (codepoint >= 0x2de0 and codepoint <= 0x2dff)
    or (codepoint >= 0xa640 and codepoint <= 0xa69f)
end

function M.detect_terminal_bidi(environment)
  environment = environment or {}
  -- A portable override is useful for configurable terminals such as WezTerm,
  -- whose environment does not reveal whether BiDi is enabled in its profile.
  if environment.NVIM_TUI_BIDI and environment.NVIM_TUI_BIDI ~= "" then
    if enabled(environment.NVIM_TUI_BIDI) then
      return true, "NVIM_TUI_BIDI override"
    elseif disabled(environment.NVIM_TUI_BIDI) then
      return false, "NVIM_TUI_BIDI override"
    end
  end

  local term_program = (environment.TERM_PROGRAM or ""):lower()
  local lc_terminal = (environment.LC_TERMINAL or ""):lower()
  local term = (environment.TERM or ""):lower()
  if term_program == "apple_terminal" or lc_terminal == "apple_terminal" then
    return true, "Terminal.app BiDi"
  end
  if term_program == "mlterm" or lc_terminal == "mlterm" or term:find("mlterm", 1, true) then
    return true, "mlterm BiDi"
  end

  -- VTE has provided Arabic shaping and BiDi since 0.58. This covers current
  -- GNOME Terminal and other VTE frontends on Linux.
  local vte_version = tonumber(environment.VTE_VERSION)
  if vte_version and vte_version >= 5800 then
    return true, "VTE 0.58+ BiDi"
  end
  if environment.KONSOLE_VERSION then
    return true, "Konsole complex-text rendering"
  end

  if term_program == "wezterm" then
    return false, "WezTerm does not advertise enabled BiDi; override only after verifying it"
  elseif environment.KITTY_WINDOW_ID or term == "xterm-kitty" then
    return false, "kitty shapes RTL words but does not implement full mixed BiDi"
  elseif environment.WT_SESSION then
    return false, "Windows Terminal does not yet provide complete mixed BiDi"
  end
  return false, "no terminal BiDi capability was advertised"
end

function M.terminal_bidi_capability()
  if vim.g.arabic_terminal_bidi ~= nil then
    return enabled(vim.g.arabic_terminal_bidi), "vim.g.arabic_terminal_bidi override"
  end
  if vim.g.vscode or vim.g.neovide then
    return false, "the graphical client does not expose terminal BiDi"
  end
  return M.detect_terminal_bidi(vim.env)
end

function M.terminal_supports_bidi()
  return M.terminal_bidi_capability()
end

function M.contains_arabic(text)
  for _, codepoint in ipairs(vim.fn.str2list(text, true)) do
    if M.is_arabic_codepoint(codepoint) then
      return true
    end
  end
  return false
end

-- Natural line direction: indentation, Markdown markers, punctuation, and
-- numbers are weak; the first Arabic, Latin, or Cyrillic letter chooses it.
function M.line_direction(text)
  local saw_arabic = false
  for _, codepoint in ipairs(vim.fn.str2list(text, true)) do
    if M.is_arabic_codepoint(codepoint) then
      saw_arabic = true
      if is_arabic_strong(codepoint) then
        return "rtl"
      end
    elseif is_ltr_strong(codepoint) then
      return "ltr"
    end
  end
  return saw_arabic and "rtl" or "neutral"
end

-- The operating system owns text input. Detect the script after a real
-- character arrives so the status line can follow it without an input-mode
-- command, while punctuation and digits preserve the last detected script.
function M.detect_input_script(text)
  for _, codepoint in ipairs(vim.fn.str2list(text or "", true)) do
    if M.is_arabic_codepoint(codepoint) then
      return "arabic"
    elseif is_cyrillic(codepoint) then
      return "russian"
    elseif (codepoint >= 0x0041 and codepoint <= 0x005a) or (codepoint >= 0x0061 and codepoint <= 0x007a) then
      return "english"
    end
  end
end

-- Return display-only padding. The buffer and saved file remain untouched.
function M.padding_for_line(text, width)
  -- Keep one stable blank cell between prose and the pane boundary. Besides
  -- looking calmer, this avoids terminal edge wrapping at the final column.
  local content_width = width - 1
  if content_width <= 1 or M.line_direction(text) ~= "rtl" then
    return 0
  end

  local display_width = vim.fn.strdisplaywidth(text)
  if display_width <= 0 or display_width >= content_width then
    return 0
  end
  if not text:find("\t", 1, true) then
    return content_width - display_width
  end

  -- Tabs depend on their starting screen column. Find the largest safe pad.
  for padding = content_width - 1, 0, -1 do
    if padding + vim.fn.strdisplaywidth(text, padding) <= content_width then
      return padding
    end
  end
  return 0
end

local function window_text_width(win)
  local info = vim.fn.getwininfo(win)[1]
  if not info then
    return 0
  end
  return math.max(0, info.width - info.textoff)
end

local function alignable_window(win, buf)
  if vim.g.arabic_display_strategy ~= "mixed" or not vim.o.termbidi then
    return false
  end
  if vim.g.arabic_align_rtl_lines == false or vim.g.arabic_align_rtl_lines == 0 then
    return false
  end
  if not window_scoped_namespaces then
    return false
  end
  if not vim.api.nvim_win_is_valid(win) or not vim.api.nvim_buf_is_valid(buf) then
    return false
  end
  if vim.api.nvim_get_option_value("buftype", { buf = buf }) ~= "" then
    return false
  end
  return not vim.wo[win].rightleft and vim.wo[win].wrap
end

local function alignment_namespace(win)
  local namespace = alignment_namespaces[win]
  if namespace then
    return namespace
  end
  namespace = vim.api.nvim_create_namespace("arabic_line_alignment_" .. win)
  alignment_namespaces[win] = namespace
  -- Inline virtual text affects layout and cannot be ephemeral. Scope each
  -- namespace to one window so the same buffer can still appear at different
  -- pane widths without one pane's padding affecting another.
  local ok = pcall(vim.api.nvim__ns_set, namespace, { wins = { win } })
  if not ok then
    window_scoped_namespaces = false
    alignment_namespaces[win] = nil
    if not namespace_warning_shown then
      namespace_warning_shown = true
      notify("This Neovim build cannot scope alignment per window; line alignment was disabled", vim.log.levels.WARN)
    end
    return nil
  end
  return namespace
end

local function clear_alignment(win, buf)
  local namespace = alignment_namespaces[win]
  local target = buf or alignment_buffers[win]
  if namespace and target and vim.api.nvim_buf_is_valid(target) then
    vim.api.nvim_buf_clear_namespace(target, namespace, 0, -1)
  end
  if not buf then
    alignment_buffers[win] = nil
  end
end

function M.refresh_alignment(win)
  win = win or vim.api.nvim_get_current_win()
  if not vim.api.nvim_win_is_valid(win) then
    return
  end

  local buf = vim.api.nvim_win_get_buf(win)
  local previous = alignment_buffers[win]
  if previous and previous ~= buf then
    clear_alignment(win, previous)
  end

  if not alignable_window(win, buf) then
    clear_alignment(win, buf)
    alignment_buffers[win] = buf
    return
  end

  local namespace = alignment_namespace(win)
  if not namespace then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
  alignment_buffers[win] = buf

  local info = vim.fn.getwininfo(win)[1]
  local width = window_text_width(win)
  if not info or width <= 1 then
    return
  end

  local first = math.max(0, info.topline - 1)
  local last = math.min(vim.api.nvim_buf_line_count(buf), info.botline)
  local lines = vim.api.nvim_buf_get_lines(buf, first, last, false)
  for offset, line in ipairs(lines) do
    local row = first + offset
    local table_row = false
    if vim.bo[buf].filetype:match("^markdown") then
      local ok, markdown_tables = pcall(require, "config.markdown_tables")
      table_row = ok and markdown_tables.contains_line(buf, row)
    end
    -- Responsive Markdown tables own their complete display row. Adding a
    -- second inline alignment mark would shift the overlay past its border.
    local padding = table_row and 0 or M.padding_for_line(line, width)
    if padding > 0 then
      vim.api.nvim_buf_set_extmark(buf, namespace, row - 1, 0, {
        priority = 1,
        right_gravity = false,
        virt_text = { { string.rep(" ", padding), "Normal" } },
        virt_text_pos = "inline",
      })
    end
  end
end

local function request_refresh(win)
  if win then
    refresh_pending[win] = true
  else
    refresh_pending.all = true
  end
  if refresh_scheduled then
    return
  end
  refresh_scheduled = true
  vim.schedule(function()
    refresh_scheduled = false
    local all = refresh_pending.all
    local requested = refresh_pending
    refresh_pending = {}
    local windows = all and vim.api.nvim_list_wins() or vim.tbl_keys(requested)
    for _, requested_win in ipairs(windows) do
      if requested_win ~= "all" then
        M.refresh_alignment(tonumber(requested_win))
      end
    end
    pcall(vim.cmd, "redraw")
  end)
end

-- Keep Neovim's grid LTR and let a bidi-aware terminal process each Arabic
-- run. This is the correct mode for source code, comments, strings, Markdown,
-- numbers, and English identifiers mixed on the same line.
function M.mixed(force, quiet)
  if not force and not M.terminal_supports_bidi() then
    local _, reason = M.terminal_bidi_capability()
    notify(
      ("%s: %s. Use a BiDi terminal or set NVIM_TUI_BIDI=1 after enabling it; :ArabicMixed! forces the mode."):format(
        terminal_name(),
        reason
      ),
      vim.log.levels.WARN,
      quiet
    )
    return false
  end

  vim.g.arabic_display_strategy = "mixed"
  vim.opt.termbidi = true
  clear_rightleft_windows()
  set_bidi_separator(true)
  set_current_buffer_mode("mixed")
  request_refresh()
  notify("Mixed Arabic/English bidi enabled; Arabic-first lines align right", nil, quiet)
  return true
end

-- Neovim's internal Arabic renderer shapes connected letters, but rightleft
-- reverses the complete screen line. Reserve it for an Arabic-only document;
-- it is deliberately never enabled from buffer content or file type.
function M.rtl(quiet)
  vim.g.arabic_display_strategy = "native-rtl"
  vim.opt.termbidi = false
  clear_rightleft_windows()
  vim.wo.rightleft = true
  vim.wo.rightleftcmd = "search"
  set_bidi_separator(false)
  set_current_buffer_mode("native-rtl")
  request_refresh()
  notify("Native RTL enabled for this Arabic-only window", nil, quiet)
  return true
end

function M.auto(quiet)
  if M.terminal_supports_bidi() then
    return M.mixed(false, quiet)
  end

  vim.g.arabic_display_strategy = "native-shaping"
  vim.opt.termbidi = false
  clear_rightleft_windows()
  set_bidi_separator(false)
  set_current_buffer_mode("native-shaping")
  request_refresh()
  notify("Arabic shaping enabled; this terminal cannot provide mixed bidi", vim.log.levels.WARN, quiet)
  return false
end

function M.off(quiet)
  vim.g.arabic_display_strategy = "off"
  vim.opt.termbidi = false
  clear_rightleft_windows()
  set_bidi_separator(false)
  set_current_buffer_mode("off")
  request_refresh()
  notify("Arabic bidi disabled", nil, quiet)
end

function M.enable(quiet)
  return M.auto(quiet)
end

function M.toggle()
  if vim.o.termbidi and not vim.wo.rightleft then
    M.off()
  else
    M.auto()
  end
end

function M.input_language()
  return vim.b.multilingual_input_script or "automatic"
end

function M.input_status()
  local language = M.input_language()
  return language == "arabic" and "AR" or language == "russian" and "RU" or ""
end

function M.status()
  local terminal_bidi, terminal_bidi_reason = M.terminal_bidi_capability()
  return {
    alignment = window_scoped_namespaces
      and vim.g.arabic_display_strategy == "mixed"
      and vim.o.termbidi
      and vim.g.arabic_align_rtl_lines ~= false
      and vim.g.arabic_align_rtl_lines ~= 0,
    alignment_available = window_scoped_namespaces,
    arabicshape = vim.o.arabicshape,
    buffer_mode = vim.b.arabic_display_mode or "automatic",
    delcombine = vim.o.delcombine,
    encoding = vim.o.encoding,
    input = M.input_language(),
    keymap = vim.bo.keymap,
    rightleft = vim.wo.rightleft,
    separator = vim.opt.fillchars:get().vert,
    strategy = vim.g.arabic_display_strategy,
    terminal = terminal_name(),
    terminal_bidi = terminal_bidi,
    terminal_bidi_reason = terminal_bidi_reason,
    termbidi = vim.o.termbidi,
  }
end

function M.show_status()
  local status = M.status()
  local mode = status.termbidi and "mixed Arabic/English bidi"
    or status.rightleft and "native Arabic-only RTL"
    or status.strategy == "native-shaping" and "LTR with native shaping"
    or "off"
  notify(
    ("Mode: %s\nArabic-first lines: %s\nInput: OS layout, detected automatically (%s)\nTerminal: %s (%s)\nUTF-8: %s · Arabic shaping: %s"):format(
      mode,
      status.alignment and "right aligned" or "not aligned",
      status.input,
      status.terminal,
      status.terminal_bidi_reason,
      status.encoding == "utf-8" and "yes" or "no",
      status.arabicshape and "on" or "off"
    )
  )
  return status
end

function M.setup()
  if vim.g.arabic_display_setup_done then
    return
  end
  vim.g.arabic_display_setup_done = true

  vim.opt.encoding = "utf-8"
  vim.opt.arabicshape = true
  vim.opt.delcombine = true

  -- Insert mode receives Unicode directly from the operating-system layout.
  -- Keeping Neovim's internal keymap empty prevents double translation and is
  -- portable across macOS, Linux, and Windows.
  vim.opt.keymap = ""
  vim.opt.iminsert = 0
  vim.opt.imsearch = -1

  original_separator = vim.opt.fillchars:get().vert

  M.auto(true)

  local group = vim.api.nvim_create_augroup("mixed_arabic_english", { clear = true })
  vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter" }, {
    group = group,
    desc = "Keep code and Markdown windows LTR while terminal bidi is active",
    callback = function()
      if vim.g.arabic_display_strategy == "mixed" then
        vim.wo.rightleft = false
      end
      request_refresh(vim.api.nvim_get_current_win())
    end,
  })
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "WinResized", "WinScrolled" }, {
    group = group,
    desc = "Refresh natural alignment for Arabic-first lines",
    callback = function()
      request_refresh()
    end,
  })
  vim.api.nvim_create_autocmd("InsertCharPre", {
    group = group,
    desc = "Detect the active OS keyboard script automatically",
    callback = function()
      local language = M.detect_input_script(vim.v.char)
      if language then
        vim.b.multilingual_input_script = language
      end
    end,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    desc = "Release closed-window Arabic alignment state",
    callback = function(event)
      local win = tonumber(event.match)
      if win then
        clear_alignment(win)
        alignment_namespaces[win] = nil
        refresh_pending[win] = nil
      end
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    desc = "Release wiped-buffer Arabic alignment state",
    callback = function(event)
      for win, buf in pairs(alignment_buffers) do
        if buf == event.buf then
          alignment_buffers[win] = nil
        end
      end
    end,
  })

  vim.api.nvim_create_user_command("Arabic", function()
    M.auto()
  end, { force = true, desc = "Enable mixed Arabic and English bidi" })
  vim.api.nvim_create_user_command("ArabicAuto", function()
    M.auto()
  end, { force = true, desc = "Enable the best mixed Arabic and English mode" })
  vim.api.nvim_create_user_command("ArabicMixed", function(opts)
    M.mixed(opts.bang)
  end, {
    bang = true,
    force = true,
    desc = "Keep code LTR and render Arabic runs with terminal bidi",
  })
  vim.api.nvim_create_user_command("ArabicRTL", function()
    M.rtl()
  end, { force = true, desc = "Use native RTL for an Arabic-only document" })
  vim.api.nvim_create_user_command("ArabicOff", function()
    M.off()
  end, { force = true, desc = "Disable Arabic bidi" })
  vim.api.nvim_create_user_command("ArabicStatus", function()
    M.show_status()
  end, { force = true, desc = "Show Arabic display capabilities and mode" })
end

return M
