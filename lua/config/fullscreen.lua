local M = {}

local terminal_fullscreen = false

local function zero_neovide_padding()
  vim.g.neovide_padding_top = 0
  vim.g.neovide_padding_bottom = 0
  vim.g.neovide_padding_left = 0
  vim.g.neovide_padding_right = 0
end

local function is_tui(channel)
  if not channel or vim.env.TERM == "dumb" or vim.env.NVIM or vim.env.TMUX or vim.env.STY then
    return false
  end

  local ok, info = pcall(vim.api.nvim_get_chan_info, channel)
  return ok and info.client and info.client.name == "nvim-tui"
end

local function send_terminal_window_request(sequence, channel)
  if not is_tui(channel) then
    return false
  end

  -- These are standard xterm window operations. Unsupported terminals safely
  -- ignore them; SSH forwards them to the terminal on the local machine.
  return pcall(vim.api.nvim_ui_send, sequence)
end

local function set_qt_fullscreen(enabled)
  if vim.fn.exists(":GuiWindowFullScreen") ~= 2 then
    return false
  end

  return pcall(vim.cmd, "GuiWindowFullScreen " .. (enabled and "1" or "0"))
end

function M.enable(channel)
  terminal_fullscreen = true

  if vim.g.neovide then
    zero_neovide_padding()
    vim.g.neovide_fullscreen = true
    return true
  end

  if set_qt_fullscreen(true) then
    return true
  end

  -- Maximize first as a fallback for terminals that implement the xterm
  -- maximize operation but not its true-fullscreen operation.
  return send_terminal_window_request("\027[9;1t\027[10;1t", channel)
end

function M.disable(channel)
  terminal_fullscreen = false

  if vim.g.neovide then
    vim.g.neovide_fullscreen = false
    return true
  end

  if set_qt_fullscreen(false) then
    return true
  end

  return send_terminal_window_request("\027[10;0t\027[9;0t", channel)
end

function M.toggle()
  if vim.g.neovide then
    if vim.g.neovide_fullscreen then
      return M.disable()
    end
    return M.enable()
  end

  local ui = vim.api.nvim_list_uis()[1]
  if terminal_fullscreen then
    return M.disable(ui and ui.chan)
  end
  return M.enable(ui and ui.chan)
end

function M.setup()
  if vim.g.vscode then
    return
  end

  -- Neovide reads these globals during startup, before UIEnter fires.
  zero_neovide_padding()
  vim.g.neovide_fullscreen = true

  local function enable_later(channel)
    vim.schedule(function()
      M.enable(channel)
    end)
  end

  vim.api.nvim_create_autocmd("UIEnter", {
    group = vim.api.nvim_create_augroup("fullscreen_on_startup", { clear = true }),
    callback = function()
      enable_later(vim.v.event.chan)
    end,
    desc = "Use the full terminal or GUI screen on startup",
  })

  -- LazyVim may load user options after the builtin TUI's UIEnter event.
  -- Cover that path as well as graphical UIs attached later.
  for _, ui in ipairs(vim.api.nvim_list_uis()) do
    enable_later(ui.chan)
  end
end

return M
