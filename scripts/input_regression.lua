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
require("config.display_motions").setup()
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
check("delete operators and x/X cut Unicode text to the system clipboard", function()
  buffer({ "one", "two", "three" })
  feed("2dd")
  assert(vim.deep_equal(copied, { { "one", "two", "" }, "V" }), vim.inspect(copied))
  buffer({ "one two" })
  feed("dw")
  assert(vim.deep_equal(copied, { { "one " }, "v" }))
  buffer({ "العربية text" })
  feed("viwd")
  assert(vim.deep_equal(copied, { { "العربية" }, "v" }))
  buffer({ "عربي" })
  feed("2x")
  assert(vim.deep_equal(copied, { { "عر" }, "v" }))
  buffer({ "abc" }, 1, 2)
  feed("X")
  assert(vim.deep_equal(copied, { { "b" }, "v" }))
  buffer({ "tail" }, 1, 1)
  feed("D")
  assert(vim.deep_equal(copied, { { "ail" }, "v" }))
  buffer({ "cut word" })
  feed("viwx")
  assert(vim.deep_equal(copied, { { "cut" }, "v" }))
end)
check("yanks and changes copy; explicit black-hole operations stay local", function()
  buffer({ "keep", "delete", "change" })
  feed('yyj"_dd')
  assert(copied[1][1] == "keep")
  feed('"_x')
  assert(copied[1][1] == "keep")
  feed("ccchanged<Esc>")
  assert(copied[1][1] == "hange")
  feed('"_yy')
  assert(copied[1][1] == "hange")
  assert(vim.fn.maparg("<C-c>", "t") == "" and vim.fn.maparg("<C-c>", "c") == "")
  assert(vim.fn.maparg("<C-v>", "n") == "", "Visual-block mode was replaced")
end)
check("p/P read fresh external clipboard text, counts, Unicode and linewise contents", function()
  buffer({ "ab" })
  vim.fn.setreg('"', "stale internal text")
  copied = { { "العربية" }, "v" } -- Copy in another application, without a focus event.
  feed("p")
  assert(vim.api.nvim_get_current_line() == "aالعربيةb")
  buffer({ "ab" })
  copied = { { "NEW" }, "v" }
  feed("P")
  assert(vim.api.nvim_get_current_line() == "NEWab", "P reused a cached clipboard")
  buffer({ "ab" })
  copied = { { "X" }, "v" }
  feed("2p")
  assert(vim.api.nvim_get_current_line() == "aXXb")
  buffer({ "anchor" })
  copied = { { "one", "two", "" }, "V" }
  feed("p")
  assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "anchor", "one", "two" }))
  buffer({ "replace me" })
  copied = { { "external" }, "v" }
  feed("viwP")
  assert(vim.api.nvim_get_current_line() == "external me")
  assert(copied[1][1] == "external", "Visual P replaced the clipboard")
end)
check("explicit named-register puts still work without changing the system clipboard", function()
  buffer({ "ab" })
  vim.fn.setreg("a", "named", "v")
  copied = { { "external" }, "v" }
  feed('"ap')
  assert(vim.api.nvim_get_current_line() == "anamedb")
  assert(copied[1][1] == "external")
end)
check("embedded clipboard uses the VS Code client", function()
  vim.g.vscode = true
  vim.g.vscode_clipboard = vim.g.clipboard
  require("config.clipboard").setup()
  assert(vim.g.clipboard.name == "isolated test clipboard")
  vim.g.vscode = false
end)

check("plain j/k follow wrapped screen rows in Normal and Visual mode", function()
  local columns = vim.o.columns
  vim.o.columns = 40
  vim.wo.wrap, vim.wo.linebreak, vim.wo.number, vim.wo.relativenumber = true, false, false, false
  vim.wo.signcolumn, vim.wo.foldcolumn = "no", "0"
  local width = vim.api.nvim_win_get_width(0)
  buffer({ string.rep("x", width * 4), "next file line" })
  feed("jjj")
  assert(vim.deep_equal(vim.api.nvim_win_get_cursor(0), { 1, width * 3 }), "j skipped wrapped rows")
  feed("kkk")
  assert(vim.deep_equal(vim.api.nvim_win_get_cursor(0), { 1, 0 }), "k skipped wrapped rows")
  feed("vj")
  assert(vim.fn.mode() == "v" and vim.api.nvim_win_get_cursor(0)[2] == width)
  feed("k")
  assert(vim.fn.mode() == "v" and vim.api.nvim_win_get_cursor(0)[2] == 0)
  feed("<Esc>")
  vim.o.columns = columns
end)
check("counted j/k, editing operators and literal typing keep native behavior", function()
  local lines = { string.rep("x", 400), "two", "three", "four", "five" }
  buffer(lines)
  feed("3j")
  assert(vim.api.nvim_win_get_cursor(0)[1] == 4, "counted j must use file lines")
  feed("2k")
  assert(vim.api.nvim_win_get_cursor(0)[1] == 2, "counted k must use file lines")
  buffer(lines)
  feed("dj")
  assert(vim.api.nvim_get_current_line() == "three" and vim.api.nvim_buf_line_count(0) == 3)
  buffer(lines, 3, 0)
  feed("dk")
  assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { lines[1], "four", "five" }))
  buffer({ "" })
  feed("ijk<Esc>")
  assert(vim.api.nvim_get_current_line() == "jk", "Insert mode was remapped")
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
    assert(vim.deep_equal(copied, { { "two " }, "v" }), "Arabic delete did not reach the clipboard")
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
    vim.keymap.set("n", "gk", function()
      called.up = true
      return "k"
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
    for _, pair in ipairs({ { "ت", "ن" }, variant == "phonetic" and { "й", "к" } or { "о", "л" } }) do
      called.wrapped, called.up = false, false
      feed(pair[1])
      assert(called.wrapped and vim.api.nvim_win_get_cursor(0)[1] == 3, "layout j bypassed gj")
      feed(pair[2])
      assert(called.up and vim.api.nvim_win_get_cursor(0)[1] == 2, "layout k bypassed gk")
    end
    feed(variant == "phonetic" and "л" or "д")
    assert(vim.api.nvim_win_get_cursor(0)[2] == 1, "Russian physical l failed")
    buffer({ "xعy" })
    feed("بع")
    assert(vim.api.nvim_win_get_cursor(0)[2] == 1, "f must search literal Arabic text")
    buffer({ "" })
    feed("iالعربية لا<Esc>")
    assert(vim.api.nvim_get_current_line() == "العربية لا", "Arabic typing changed")
    buffer({ "ab" })
    copied = { { "خارجي" }, "v" }
    feed("ح") -- Arabic physical p
    assert(vim.api.nvim_get_current_line() == "aخارجيb", "Arabic p did not use the system clipboard")
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
