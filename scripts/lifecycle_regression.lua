-- Real Neovim buffers/windows/jobs; only the external Explorer UI is omitted.
local root = vim.fs.dirname(vim.fs.dirname(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p")))
vim.opt.rtp:prepend(root)
vim.opt.hidden = true
vim.opt.swapfile = false
local api = vim.api
local temporary = vim.fn.tempname()
vim.fn.mkdir(temporary, "p")
package.loaded["lazyvim.util"] = {
  root = function()
    return temporary
  end,
}
local workspace = require("config.workspace")
workspace.schedule_empty_pane_cleanup = function() end
workspace.schedule_explorer_width = function() end
workspace.setup()
local passed = 0
local function check(name, callback)
  local ok, err = xpcall(callback, debug.traceback)
  assert(ok, name .. "\n" .. tostring(err))
  passed = passed + 1
  print("PASS " .. name)
end
local function file(name)
  local path = temporary .. "/" .. name
  vim.fn.writefile({ name }, path)
  vim.cmd.edit(vim.fn.fnameescape(path))
  return api.nvim_get_current_buf()
end

check("closing a shared modified file affects only its current pane", function()
  local buf = file("shared.txt")
  local original = api.nvim_get_current_win()
  vim.cmd.vsplit()
  local closing = api.nvim_get_current_win()
  api.nvim_buf_set_lines(buf, 0, -1, false, { "unsaved text" })
  local confirm = vim.fn.confirm
  vim.fn.confirm = function()
    error("A shared file must not prompt to discard edits")
  end
  local ok = workspace.close_current_tab()
  vim.fn.confirm = confirm
  assert(ok)
  assert(api.nvim_buf_is_valid(buf) and vim.bo[buf].modified)
  assert(api.nvim_win_get_buf(original) == buf)
  assert(api.nvim_win_get_buf(closing) ~= buf)
  assert(not vim.tbl_contains(workspace.tabs(closing), buf))
  assert(api.nvim_buf_get_lines(buf, 0, -1, false)[1] == "unsaved text")
  api.nvim_win_close(closing, false)
  api.nvim_set_current_win(original)
  vim.bo[buf].modified = false
end)

check("a hidden tab in another pane retains ownership when one pane closes it", function()
  local buf = file("hidden-shared.txt")
  local owner = api.nvim_get_current_win()
  vim.cmd.vsplit()
  local closing = api.nvim_get_current_win()
  api.nvim_set_current_win(owner)
  local other = file("other.txt")
  api.nvim_set_current_win(closing)
  assert(workspace.close_current_tab())
  assert(api.nvim_buf_is_valid(buf))
  assert(api.nvim_win_get_buf(owner) == other)
  assert(vim.tbl_contains(workspace.tabs(owner), buf))
  assert(not vim.tbl_contains(workspace.tabs(closing), buf))
  api.nvim_win_close(closing, false)
  api.nvim_set_current_win(owner)
end)

check("last-owner close supports Cancel, failed Save, Save and Discard", function()
  local buf = file("save.txt")
  api.nvim_buf_set_lines(buf, 0, -1, false, { "changed" })
  local confirm, notify = vim.fn.confirm, vim.notify
  vim.fn.confirm = function()
    return 3
  end
  assert(not workspace.close_current_tab())
  assert(api.nvim_get_current_buf() == buf and vim.bo[buf].modified)
  vim.fn.confirm = function()
    return 1
  end
  vim.bo[buf].readonly = true
  vim.notify = function() end
  assert(not workspace.close_current_tab())
  assert(api.nvim_buf_is_valid(buf) and vim.bo[buf].modified)
  vim.bo[buf].readonly = false
  assert(workspace.close_current_tab())
  assert(vim.fn.readfile(temporary .. "/save.txt")[1] == "changed")
  buf = file("discard.txt")
  api.nvim_buf_set_lines(buf, 0, -1, false, { "discard this" })
  vim.fn.confirm = function()
    return 2
  end
  assert(workspace.close_current_tab())
  assert(vim.fn.readfile(temporary .. "/discard.txt")[1] == "discard.txt")
  vim.fn.confirm, vim.notify = confirm, notify
end)

check("terminal groups retain processes across hide/show and stay workspace-local", function()
  file("terminal-owner.txt")
  vim.o.shell = vim.fn.has("win32") == 1 and (vim.env.ComSpec or "cmd.exe") or "/bin/sh"
  local terminals = require("config.terminals")
  assert(terminals.show())
  local first = api.nvim_get_current_buf()
  local first_job = vim.b.terminal_job_id
  assert(terminals.split())
  local second = api.nvim_get_current_buf()
  local second_job = vim.b.terminal_job_id
  assert(first ~= second)
  assert(terminals.split())
  local visible, remembered = terminals.count()
  assert(visible == 2 and remembered == 2, "split created a third terminal")
  assert(terminals.hide())
  visible, remembered = terminals.count()
  assert(visible == 0 and remembered == 2)
  assert(vim.fn.jobwait({ first_job, second_job }, 0)[1] == -1, "hiding stopped the process")
  assert(terminals.show())
  assert(api.nvim_get_current_buf() == first)
  assert(vim.b.terminal_job_id == first_job)
  vim.cmd.tabnew()
  visible, remembered = terminals.count()
  assert(visible == 0 and remembered == 0, "another workspace inherited the terminal group")
  vim.cmd.tabclose()
  assert(terminals.hide())
  vim.fn.jobstop(first_job)
  vim.fn.jobstop(second_job)
end)

vim.fn.delete(temporary, "rf")
print(("PASS %d lifecycle checks"):format(passed))
vim.cmd("qa!")
