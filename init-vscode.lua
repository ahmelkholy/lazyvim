-- Lightweight Neovim backend for the VSCode Neovim extension.
-- Standalone Neovim continues to use init.lua and the full LazyVim setup.

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- VS Code owns files, rendering, completion, diagnostics, and undo history.
vim.opt.shadafile = "NONE"
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.spell = false
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.clipboard = "unnamedplus"
vim.opt.report = 999999
vim.opt.shortmess:append({ W = true, c = true, C = true, F = true, S = true })

local map = vim.keymap.set

if not vim.g.vscode then
  return
end

-- `vscode` is the current API module name. `vscode-neovim` is deprecated.
local vscode = require("vscode")

local function action(name, opts)
  return function()
    vscode.action(name, opts)
  end
end

-- Match LazyVim's prefix discovery without loading UI plugins inside VS Code.
-- Fast sequences keep using Neovim directly; pausing on a prefix opens Which Key.
vim.opt.timeout = true
vim.opt.timeoutlen = 300

local function command_item(key, name, command, args)
  return {
    key = key,
    name = name,
    type = "command",
    command = command,
    args = args,
  }
end

local function neovim_item(prefix, key, name, sequence)
  return command_item(key, name, "vscode-neovim.send", sequence or (prefix .. key))
end

local function show_which_key(items)
  vscode.action("whichkey.show", { args = { items } })
end

local function feed_native(keys)
  local count = vim.v.count
  local sequence = (count > 0 and tostring(count) or "") .. keys
  local termcodes = vim.api.nvim_replace_termcodes(sequence, true, false, true)
  vim.api.nvim_feedkeys(termcodes, "n", false)
end

local function run_menu_item(item)
  if item.command == "vscode-neovim.send" then
    feed_native(item.args)
    return
  end
  vscode.action(item.command)
end

local passthrough_suffixes = {}
for codepoint = 32, 126 do
  table.insert(passthrough_suffixes, string.char(codepoint))
end
for _, key in ipairs({
  "<CR>",
  "<Tab>",
  "<Up>",
  "<Down>",
  "<Left>",
  "<Right>",
  "<Home>",
  "<End>",
  "<C-b>",
  "<C-c>",
  "<C-d>",
  "<C-f>",
  "<C-g>",
  "<C-h>",
  "<C-i>",
  "<C-j>",
  "<C-k>",
  "<C-l>",
  "<C-n>",
  "<C-o>",
  "<C-p>",
  "<C-q>",
  "<C-r>",
  "<C-s>",
  "<C-t>",
  "<C-v>",
  "<C-w>",
  "<C-x>",
  "<C-z>",
  "<C-]>",
  "<C-^>",
  "<C-_>",
}) do
  table.insert(passthrough_suffixes, key)
end

local function map_prefix_menu(prefix, name, items, on_timeout, preserve_unlisted)
  -- Longer mappings preserve normal fast sequences such as `gg` and `za`.
  -- The exact prefix mapping runs only after timeoutlen, opening discovery.
  local mapped_keys = {}
  for _, item in ipairs(items) do
    local mapped_item = item
    mapped_keys[mapped_item.key] = true
    map("n", prefix .. mapped_item.key, function()
      run_menu_item(mapped_item)
    end, { silent = true, desc = mapped_item.name })
  end

  if preserve_unlisted then
    for _, suffix in ipairs(passthrough_suffixes) do
      if not mapped_keys[suffix] then
        local native_sequence = prefix .. suffix
        map("n", native_sequence, function()
          feed_native(native_sequence)
        end, { silent = true, desc = "Native " .. native_sequence })
      end
    end
  end

  map("n", prefix, on_timeout or function()
    show_which_key(items)
  end, { silent = true, desc = name .. " (Which Key)" })
end

local function map_neovim_prefix(prefix, name, definitions)
  local items = {}
  for _, definition in ipairs(definitions) do
    table.insert(items, neovim_item(prefix, definition[1], definition[2], definition[3]))
  end
  map_prefix_menu(prefix, name, items, nil, true)
end

map_neovim_prefix("g", "Goto", {
  { "g", "First line" },
  { "e", "Previous end of word" },
  { "E", "Previous end of WORD" },
  { "j", "Next display line" },
  { "k", "Previous display line" },
  { "0", "First display-column character" },
  { "^", "First non-blank display character" },
  { "$", "Last display-column character" },
  { "m", "Middle of display line" },
  { "M", "Middle of text line" },
  { "_", "Last non-blank character" },
  { "d", "Go to definition" },
  { "D", "Peek definition" },
  { "f", "Go to declaration/file" },
  { "H", "Show references" },
  { "O", "Document symbols" },
  { "x", "Open link or file" },
  { "~", "Swap case operator" },
  { "u", "Lowercase operator" },
  { "U", "Uppercase operator" },
  { "q", "Format operator" },
  { "?", "ROT13 operator" },
  { "&", "Repeat substitute globally" },
})

map_neovim_prefix("z", "Fold/Viewport", {
  { "a", "Toggle fold" },
  { "A", "Toggle fold recursively" },
  { "c", "Close fold" },
  { "C", "Close fold recursively" },
  { "o", "Open fold" },
  { "O", "Open fold recursively" },
  { "M", "Close all folds" },
  { "R", "Open all folds" },
  { "d", "Delete fold" },
  { "D", "Delete folds recursively" },
  { "E", "Delete all folds" },
  { "f", "Create fold operator" },
  { "i", "Toggle folding" },
  { "j", "Next fold" },
  { "k", "Previous fold" },
  { "v", "Open folds around cursor" },
  { "x", "Update folds" },
  { "X", "Undo manually opened/closed folds" },
  { "z", "Center cursor line" },
  { "t", "Cursor line at top" },
  { "b", "Cursor line at bottom" },
  { "h", "Scroll left" },
  { "l", "Scroll right" },
  { "H", "Scroll half-screen left" },
  { "L", "Scroll half-screen right" },
})

local previous_items = {
  command_item("b", "Previous editor", "workbench.action.previousEditor"),
  command_item("d", "Previous diagnostic", "editor.action.marker.prev"),
  command_item("q", "Previous problem", "editor.action.marker.prevInFiles"),
  command_item("h", "Previous change", "workbench.action.compareEditor.previousChange"),
  neovim_item("[", "[", "Previous section"),
  neovim_item("[", "]", "Previous section end"),
  neovim_item("[", "c", "Previous diff change"),
  neovim_item("[", "m", "Previous method"),
  neovim_item("[", "M", "Previous method end"),
  neovim_item("[", "s", "Previous misspelling"),
  neovim_item("[", "z", "Start of open fold"),
  neovim_item("[", "{", "Previous unmatched brace"),
  neovim_item("[", "(", "Previous unmatched parenthesis"),
}

local next_items = {
  command_item("b", "Next editor", "workbench.action.nextEditor"),
  command_item("d", "Next diagnostic", "editor.action.marker.next"),
  command_item("q", "Next problem", "editor.action.marker.nextInFiles"),
  command_item("h", "Next change", "workbench.action.compareEditor.nextChange"),
  neovim_item("]", "]", "Next section"),
  neovim_item("]", "[", "Next section end"),
  neovim_item("]", "c", "Next diff change"),
  neovim_item("]", "m", "Next method"),
  neovim_item("]", "M", "Next method end"),
  neovim_item("]", "s", "Next misspelling"),
  neovim_item("]", "z", "End of open fold"),
  neovim_item("]", "}", "Next unmatched brace"),
  neovim_item("]", ")", "Next unmatched parenthesis"),
}

map_prefix_menu("[", "Previous", previous_items, nil, true)
map_prefix_menu("]", "Next", next_items, nil, true)

local register_names = {
  ['"'] = "Unnamed register",
  ["0"] = "Last yank",
  ["-"] = "Small delete",
  ["."] = "Last inserted text",
  [":"] = "Last Ex command",
  ["%"] = "Current file name",
  ["#"] = "Alternate file name",
  ["="] = "Expression register",
  ["*"] = "Selection clipboard",
  ["+"] = "System clipboard",
  ["_"] = "Black-hole register",
}

local function register_menu(prefix, title, include_uppercase)
  local items = {}
  for character in ("abcdefghijklmnopqrstuvwxyz"):gmatch(".") do
    table.insert(items, neovim_item(prefix, character, title .. " register " .. character))
  end
  if include_uppercase then
    for character in ("ABCDEFGHIJKLMNOPQRSTUVWXYZ"):gmatch(".") do
      table.insert(items, neovim_item(prefix, character, title .. " append register " .. character))
    end
  end
  for character in ("0123456789"):gmatch(".") do
    table.insert(items, neovim_item(prefix, character, register_names[character] or (title .. " register " .. character)))
  end
  for _, character in ipairs({ '"', "-", ".", ":", "%", "#", "=", "*", "+", "_" }) do
    table.insert(items, neovim_item(prefix, character, register_names[character]))
  end
  return items
end

local named_registers = register_menu('"', "Use", true)
local record_registers = register_menu("q", "Record macro in", true)
local execute_registers = register_menu("@", "Execute macro from", false)
table.insert(execute_registers, 1, neovim_item("@", "@", "Repeat last macro"))

map_prefix_menu('"', "Registers", named_registers)

map_prefix_menu("q", "Record macro", record_registers, function()
  if vim.fn.reg_recording() ~= "" then
    feed_native("q")
    return
  end
  show_which_key(record_registers)
end)

map_prefix_menu("@", "Execute macro", execute_registers)

local function mark_menu(prefix, verb)
  local items = {}
  for character in ("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"):gmatch(".") do
    table.insert(items, neovim_item(prefix, character, verb .. " mark " .. character))
  end
  for _, character in ipairs({ "[", "]", "<", ">", ".", "^", "'", "`" }) do
    table.insert(items, neovim_item(prefix, character, verb .. " special mark " .. character))
  end
  return items
end

local set_marks = mark_menu("m", "Set")
local jump_marks_line = mark_menu("'", "Jump to line of")
local jump_marks_exact = mark_menu("`", "Jump exactly to")

map_prefix_menu("m", "Set mark", set_marks)
map_prefix_menu("'", "Jump to mark line", jump_marks_line)
map_prefix_menu("`", "Jump to mark position", jump_marks_exact)

local window_items = {
  command_item("h", "Focus left group", "workbench.action.focusLeftGroup"),
  command_item("j", "Focus group below", "workbench.action.focusBelowGroup"),
  command_item("k", "Focus group above", "workbench.action.focusAboveGroup"),
  command_item("l", "Focus right group", "workbench.action.focusRightGroup"),
  command_item("H", "Move group left", "workbench.action.moveActiveEditorGroupLeft"),
  command_item("J", "Move group down", "workbench.action.moveActiveEditorGroupDown"),
  command_item("K", "Move group up", "workbench.action.moveActiveEditorGroupUp"),
  command_item("L", "Move group right", "workbench.action.moveActiveEditorGroupRight"),
  command_item("s", "Split editor below", "workbench.action.splitEditorDown"),
  command_item("v", "Split editor right", "workbench.action.splitEditorRight"),
  command_item("w", "Focus previous group", "workbench.action.focusPreviousGroup"),
  command_item("q", "Close editor group", "workbench.action.closeEditorsInGroup"),
  command_item("o", "Join all editor groups", "workbench.action.joinAllGroups"),
  command_item("=", "Equal editor widths", "workbench.action.evenEditorWidths"),
}

map_prefix_menu("<C-w>", "Windows", window_items, nil, true)

-- Keep undo in VS Code so edits from both engines share one undo history.
map("n", "u", action("undo"), { silent = true, desc = "VS Code undo" })
map("n", "<C-r>", action("redo"), { silent = true, desc = "VS Code redo" })
map("v", "<C-c>", '"+y', { silent = true, desc = "Copy visual selection to system clipboard" })

-- LazyVim-shaped aliases backed by native VS Code surfaces.
map("n", "<leader><space>", action("workbench.action.quickOpen"), { desc = "Find files" })
map("n", "<leader>/", action("workbench.action.findInFiles"), { desc = "Search in files" })
map("n", "<leader>e", action("workbench.view.explorer"), { desc = "Explorer" })
map("n", "<leader>bd", action("workbench.action.closeActiveEditor"), { desc = "Close editor" })
map("n", "<leader>ca", action("editor.action.quickFix"), { desc = "Code action" })
map("n", "<leader>cr", action("editor.action.rename"), { desc = "Rename symbol" })
map("n", "<leader>cf", action("editor.action.formatDocument"), { desc = "Format document" })
map("n", "<leader>xx", action("workbench.actions.view.problems"), { desc = "Problems" })
map("n", "<leader>ft", action("workbench.action.terminal.toggleTerminal"), { desc = "Terminal" })
map("n", "<leader>fT", action("workbench.action.terminal.toggleTerminal"), { desc = "Terminal" })
map("n", "<leader>gg", action("lazygit-vscode.toggle"), { desc = "LazyGit" })
map("n", "<C-A-g>", action("lazygit-vscode.toggle"), { desc = "LazyGit" })
map("n", "<S-h>", action("workbench.action.previousEditor"), { desc = "Previous editor" })
map("n", "<S-l>", action("workbench.action.nextEditor"), { desc = "Next editor" })

-- Preserve selection while moving over wrapped display lines.
local function move_wrapped(direction)
  return function()
    if vim.api.nvim_get_mode().mode ~= "v" then
      return "g" .. direction
    end
    vscode.action("cursorMove", {
      args = {
        {
          to = direction == "j" and "down" or "up",
          by = "wrappedLine",
          value = vim.v.count1,
          select = true,
        },
      },
    })
    return "<Ignore>"
  end
end

map("v", "gj", move_wrapped("j"), { expr = true, silent = true })
map("v", "gk", move_wrapped("k"), { expr = true, silent = true })
