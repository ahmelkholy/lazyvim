local M = {}
local LazyVim = require("lazyvim.util")

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
  return vim.tbl_filter(is_editor_window, vim.api.nvim_tabpage_list_wins(0))
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

function M.open()
  if vim.g.vscode then
    return
  end

  local current_buf = vim.api.nvim_get_current_buf()
  local current_ft = vim.api.nvim_get_option_value("filetype", { buf = current_buf })
  if starter_filetypes[current_ft] and not vim.api.nvim_get_option_value("modified", { buf = current_buf }) then
    vim.cmd.enew()
  end

  local editors = editor_windows()
  if #editors == 0 then
    vim.cmd.enew()
    editors = editor_windows()
  end

  local current_win = vim.api.nvim_get_current_win()
  local primary = is_editor_window(current_win) and current_win or editors[1]
  vim.api.nvim_set_current_win(primary)

  if #editors < 2 then
    vim.cmd.vsplit()
    vim.cmd.enew()
  end

  require("neo-tree.command").execute({
    action = "show",
    source = "filesystem",
    position = "left",
    dir = LazyVim.root(),
  })

  editors = editor_windows()
  table.sort(editors, function(left, right)
    return vim.api.nvim_win_get_position(left)[2] < vim.api.nvim_win_get_position(right)[2]
  end)
  if editors[1] and vim.api.nvim_win_is_valid(editors[1]) then
    vim.api.nvim_set_current_win(editors[1])
  end
  vim.cmd.wincmd("=")
end

function M.setup()
  vim.api.nvim_create_user_command("WorkspaceLayout", M.open, {
    desc = "Open Explorer with two independent editor panes",
  })
  vim.keymap.set("n", "<leader>wL", M.open, { desc = "Workspace Layout" })

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
end

return M
