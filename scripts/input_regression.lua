-- Isolated input tests: no plugins, system clipboard, or live settings writes.
local root = vim.fs.dirname(vim.fs.dirname(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p")))
vim.opt.rtp:prepend(root)
vim.g.mapleader = " "
local passed = 0
local function check(name, fn)
  fn()
  passed = passed + 1
  print("PASS " .. name)
end
local function feed(keys)
  vim.fn.feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "xt")
end
local function buffer(lines, row, col)
  feed("<Esc>")
  vim.cmd("enew!")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, { row or 1, col or 0 })
end
local copied = {}
vim.g.clipboard = {
  name = "isolated test clipboard",
  copy = {
    ["+"] = function(lines, kind)
      copied = { vim.deepcopy(lines), kind }
    end,
    ["*"] = function() end,
  },
  paste = {
    ["+"] = function()
      return copied
    end,
    ["*"] = function()
      return { {}, "v" }
    end,
  },
  cache_enabled = 0,
}
require("config.clipboard").setup()
check("Ctrl+C copies lines, Unicode visual selections and Select mode", function()
  buffer({ "Arabic العربية", "second" })
  feed("<C-c>")
  assert(copied[1][1] == "Arabic العربية" and copied[2] == "V")
  buffer({ "العربية text" })
  feed("viw<C-c>")
  assert(copied[1][1] == "العربية" and copied[2] == "v")
  buffer({ "select this" })
  feed("viw<C-g><C-c>")
  assert(copied[1][1] == "select")
end)
check("yanks copy; delete/change/black-hole operations preserve the clipboard", function()
  buffer({ "keep", "delete", "change" })
  feed("yyjdd")
  assert(copied[1][1] == "keep")
  feed("ccchanged<Esc>")
  assert(copied[1][1] == "keep")
  feed('"_yy')
  assert(copied[1][1] == "keep")
  assert(vim.fn.maparg("<C-c>", "t") == "" and vim.fn.maparg("<C-c>", "c") == "")
  assert(vim.fn.maparg("<C-v>", "n") == "", "Visual-block mode was replaced")
end)
check("embedded clipboard uses the VS Code client", function()
  vim.g.vscode = true
  vim.g.vscode_clipboard = vim.g.clipboard
  require("config.clipboard").setup()
  assert(vim.g.clipboard.name == "isolated test clipboard")
  vim.g.vscode = false
end)

for _, variant in ipairs({ "standard", "mac", "phonetic" }) do
  check("Arabic commands and mapped actions with Russian " .. variant, function()
    vim.g.russian_keyboard_variant = variant
    package.loaded["config.multilingual_keys"] = nil
    local multilingual = require("config.multilingual_keys")
    multilingual.setup()
    buffer({ "one two three", "second line", "last line" }, 1, 12)
    feed("لا")
    assert(vim.api.nvim_win_get_cursor(0)[2] == 8, "LAM ALEF did not move backward")
    feed("يلا")
    assert(vim.api.nvim_get_current_line() == "one three", "Arabic db failed")
    buffer({ "one", "two", "three" })
    feed("يلأ")
    assert(vim.api.nvim_get_current_line() == "", "Arabic dG failed")
    local called = {}
    vim.keymap.set("n", "<leader>wl", function()
      called.pane = true
    end, { desc = "Pane right" })
    vim.keymap.set("n", "gj", function()
      called.wrapped = true
      return "j"
    end, { expr = true })
    vim.keymap.set("n", "K", function()
      called.local_map = true
    end, { buffer = true })
    multilingual.refresh_aliases()
    feed("،")
    assert(called.local_map, "Arabic buffer-local mapping failed")
    buffer({ "one", "two", "three" })
    feed(" صم")
    assert(called.pane, "Arabic leader mapping failed")
    feed("لت")
    assert(called.wrapped and vim.api.nvim_win_get_cursor(0)[1] == 2, "mapped Arabic gj failed")
    feed(variant == "phonetic" and "л" or "д")
    assert(vim.api.nvim_win_get_cursor(0)[2] == 1, "Russian physical l failed")
    buffer({ "xعy" })
    feed("بع")
    assert(vim.api.nvim_win_get_cursor(0)[2] == 1, "f must search literal Arabic text")
    buffer({ "" })
    feed("iالعربية لا<Esc>")
    assert(vim.api.nvim_get_current_line() == "العربية لا", "Arabic typing changed")
    vim.keymap.del("n", "<leader>wl")
    multilingual.refresh_aliases()
    assert(vim.fn.maparg(" صم", "n") == "", "removed mapping left a stale alias")
  end)
end
check("scan codes share the same logical Neovim key on every platform", function()
  local sync = require("config.key_sync")
  assert(sync.to_nvim_key("ctrl+[KeyC]") == "<C-c>")
  assert(sync.to_nvim_key("ctrl+shift+[KeyV]") == "<C-S-v>")
  assert(sync.to_nvim_key("ctrl+[Digit6]") == "<C-^>")
  assert(not sync.to_nvim_key("ctrl+[Unknown]"))
end)
print(("All %d input checks passed"):format(passed))
vim.cmd("qa!")
