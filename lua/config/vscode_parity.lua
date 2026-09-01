local M = {}

local map = vim.keymap.set
local vscode = require("vscode")

local function action(command, args)
  return function()
    vscode.action(command, args and { args = args } or nil)
  end
end

local function actions(commands)
  return function()
    for _, command in ipairs(commands) do
      if type(command) == "string" then
        vscode.action(command)
      else
        vscode.action(command[1], command[2] and { args = command[2] } or nil)
      end
    end
  end
end

local function counted_action(command)
  return function()
    for _ = 1, vim.v.count1 do
      vscode.action(command)
    end
  end
end

local function standalone_only(name, alternative)
  return function()
    if alternative then
      vscode.action(alternative)
    end
    vscode.notify(
      name .. " uses a standalone Neovim UI; opened the closest VS Code surface instead",
      vim.log.levels.INFO
    )
  end
end

local function bind(modes, lhs, rhs, desc, opts)
  opts = vim.tbl_extend("force", { silent = true, desc = desc }, opts or {})
  map(modes, lhs, type(rhs) == "string" and action(rhs) or rhs, opts)
end

local function toggle_config(name, on, off)
  return function()
    local current = vscode.get_config(name)
    vscode.update_config(name, current == on and off or on, "global")
  end
end

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

local function group_item(key, name, bindings)
  return {
    key = key,
    name = name,
    type = "bindings",
    bindings = bindings,
  }
end

local function show_which_key(items)
  vscode.call("whichkey.show", { args = { items } }, 1000)
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
  vscode.action(item.command, item.args and { args = item.args } or nil)
end

-- VSCode-Neovim supplies these mappings itself. Preserve them when installing
-- discovery prefixes because they synchronize VS Code's viewport and LSP.
local vscode_native_overrides = {
  ["gj"] = true,
  ["gk"] = true,
  ["zt"] = true,
  ["zz"] = true,
  ["zb"] = true,
  ["z<CR>"] = true,
  ["z."] = true,
  ["z-"] = true,
  ["gf"] = true,
  ["gd"] = true,
  ["gO"] = true,
  ["gD"] = true,
  ["gH"] = true,
}

local passthrough_suffixes = {}
for codepoint = 32, 126 do
  passthrough_suffixes[#passthrough_suffixes + 1] = string.char(codepoint)
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
  passthrough_suffixes[#passthrough_suffixes + 1] = key
end

local function map_prefix_menu(prefix, name, items, on_timeout, preserve_unlisted)
  local mapped_keys = {}
  for _, item in ipairs(items) do
    mapped_keys[item.key] = true
    local sequence = prefix .. item.key
    if item.bindings then
      map("n", sequence, function()
        show_which_key(item.bindings)
      end, { silent = true, desc = item.name .. " (Which Key)" })
    else
      local existing = vim.fn.maparg(sequence, "n", false, true)
      local preserve_existing = item.command == "vscode-neovim.send" and not vim.tbl_isempty(existing)
      if not preserve_existing and not (vscode_native_overrides[sequence] and not vim.tbl_isempty(existing)) then
        local mapped_item = item
        map("n", sequence, function()
          run_menu_item(mapped_item)
        end, { silent = true, desc = mapped_item.name })
      end
    end
  end

  if preserve_unlisted then
    for _, suffix in ipairs(passthrough_suffixes) do
      local native_sequence = prefix .. suffix
      if not mapped_keys[suffix] and vim.tbl_isempty(vim.fn.maparg(native_sequence, "n", false, true)) then
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
    items[#items + 1] = neovim_item(prefix, definition[1], definition[2], definition[3])
  end
  map_prefix_menu(prefix, name, items, nil, true)
end

local function setup_native_prefixes()
  local lsp_items = {
    command_item("a", "Code action", "editor.action.quickFix"),
    command_item("i", "Go to implementation", "editor.action.goToImplementation"),
    command_item("n", "Rename symbol", "editor.action.rename"),
    command_item("r", "Show references", "editor.action.goToReferences"),
    command_item("t", "Go to type definition", "editor.action.goToTypeDefinition"),
    command_item("x", "Run code lens", "codelens.showLensesInCurrentLine"),
  }
  map_prefix_menu("gr", "LSP", lsp_items, nil, false)

  local surround_items = {
    neovim_item("gz", "a", "Add surrounding"),
    neovim_item("gz", "d", "Delete surrounding"),
    neovim_item("gz", "r", "Replace surrounding"),
    neovim_item("gz", "f", "Find surrounding to the right"),
    neovim_item("gz", "F", "Find surrounding to the left"),
    neovim_item("gz", "h", "Highlight surrounding"),
    neovim_item("gz", "n", "Set surrounding search lines"),
  }
  map_prefix_menu("gz", "Surround", surround_items, nil, false)

  local goto_items = {
    neovim_item("g", "g", "First line"),
    neovim_item("g", "e", "Previous end of word"),
    neovim_item("g", "E", "Previous end of WORD"),
    neovim_item("g", "j", "Next display line"),
    neovim_item("g", "k", "Previous display line"),
    neovim_item("g", "0", "First display-column character"),
    neovim_item("g", "^", "First non-blank display character"),
    neovim_item("g", "$", "Last display-column character"),
    neovim_item("g", "m", "Middle of display line"),
    neovim_item("g", "M", "Middle of text line"),
    neovim_item("g", "_", "Last non-blank character"),
    neovim_item("g", "d", "Go to definition"),
    neovim_item("g", "D", "Peek definition"),
    neovim_item("g", "f", "Go to declaration/file"),
    neovim_item("g", "H", "Show references"),
    neovim_item("g", "O", "Document symbols"),
    neovim_item("g", "x", "Open link or file"),
    neovim_item("g", "c", "Comment"),
    neovim_item("g", "s", "Leap from windows"),
    neovim_item("g", "~", "Swap case operator"),
    neovim_item("g", "u", "Lowercase operator"),
    neovim_item("g", "U", "Uppercase operator"),
    neovim_item("g", "q", "Format operator"),
    neovim_item("g", "?", "ROT13 operator"),
    neovim_item("g", "&", "Repeat substitute globally"),
    group_item("r", "+LSP", lsp_items),
    group_item("z", "+Surround", surround_items),
  }
  map_prefix_menu("g", "Goto", goto_items, nil, true)

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
    command_item("e", "Previous error", "editor.action.marker.prevInFiles"),
    command_item("q", "Previous problem", "editor.action.marker.prevInFiles"),
    command_item("h", "Previous change", "workbench.action.compareEditor.previousChange"),
    command_item("t", "Previous test", "testing.goToPreviousMessage"),
    neovim_item("[", "[", "Previous section"),
    neovim_item("[", "]", "Previous section end"),
    neovim_item("[", "c", "Previous diff change"),
    neovim_item("[", "m", "Previous method"),
    neovim_item("[", "M", "Previous method end"),
    neovim_item("[", "s", "Previous misspelling"),
    neovim_item("[", "y", "Previous yank history entry"),
    neovim_item("[", "z", "Start of open fold"),
    neovim_item("[", "{", "Previous unmatched brace"),
    neovim_item("[", "(", "Previous unmatched parenthesis"),
  }

  local next_items = {
    command_item("b", "Next editor", "workbench.action.nextEditor"),
    command_item("d", "Next diagnostic", "editor.action.marker.next"),
    command_item("e", "Next error", "editor.action.marker.nextInFiles"),
    command_item("q", "Next problem", "editor.action.marker.nextInFiles"),
    command_item("h", "Next change", "workbench.action.compareEditor.nextChange"),
    command_item("t", "Next test", "testing.goToNextMessage"),
    neovim_item("]", "]", "Next section"),
    neovim_item("]", "[", "Next section end"),
    neovim_item("]", "c", "Next diff change"),
    neovim_item("]", "m", "Next method"),
    neovim_item("]", "M", "Next method end"),
    neovim_item("]", "s", "Next misspelling"),
    neovim_item("]", "y", "Next yank history entry"),
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
      items[#items + 1] = neovim_item(prefix, character, title .. " register " .. character)
    end
    if include_uppercase then
      for character in ("ABCDEFGHIJKLMNOPQRSTUVWXYZ"):gmatch(".") do
        items[#items + 1] = neovim_item(prefix, character, title .. " append register " .. character)
      end
    end
    for character in ("0123456789"):gmatch(".") do
      items[#items + 1] =
        neovim_item(prefix, character, register_names[character] or (title .. " register " .. character))
    end
    for _, character in ipairs({ '"', "-", ".", ":", "%", "#", "=", "*", "+", "_" }) do
      items[#items + 1] = neovim_item(prefix, character, register_names[character])
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
      items[#items + 1] = neovim_item(prefix, character, verb .. " mark " .. character)
    end
    for _, character in ipairs({ "[", "]", "<", ">", ".", "^", "'", "`" }) do
      items[#items + 1] = neovim_item(prefix, character, verb .. " special mark " .. character)
    end
    return items
  end

  map_prefix_menu("m", "Set mark", mark_menu("m", "Set"))
  map_prefix_menu("'", "Jump to mark line", mark_menu("'", "Jump to line of"))
  map_prefix_menu("`", "Jump to mark position", mark_menu("`", "Jump exactly to"))

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
    command_item("w", "Focus next group", "workbench.action.focusNextGroup"),
    command_item("W", "Focus previous group", "workbench.action.focusPreviousGroup"),
    command_item("q", "Close editor group", "workbench.action.closeEditorsInGroup"),
    command_item("c", "Close editor group", "workbench.action.closeEditorsInGroup"),
    command_item("o", "Join all editor groups", "workbench.action.joinAllGroups"),
    command_item("=", "Equal editor widths", "workbench.action.evenEditorWidths"),
  }
  map_prefix_menu("<C-w>", "Windows", window_items, nil, true)
end

local leader_specs = {
  { " ", "Find Project Files", "workbench.action.quickOpen" },
  { ",", "Switch Open File", "workbench.action.showAllEditors" },
  { ".", "Toggle Scratch Buffer", "workbench.action.files.newUntitledFile" },
  { "/", "Grep (Root Dir)", "workbench.action.findInFiles" },
  { ":", "Command History", "workbench.action.showCommands" },
  { "?", "Buffer Keymaps", "workbench.action.openGlobalKeybindings" },
  { "D", "Toggle DBUI", "workbench.view.extension.github-cweijan-mysql" },
  { "E", "Explorer NeoTree (cwd)", "workbench.view.explorer" },
  { "K", "Keywordprg", "editor.action.showHover" },
  { "L", "LazyVim Changelog", standalone_only("LazyVim Changelog", "workbench.action.showCommands") },
  { "S", "Select Scratch Buffer", "workbench.action.showAllEditors" },
  { "W", "Save without formatting", "workbench.action.files.saveWithoutFormatting" },
  { "`", "Switch to other buffer", "workbench.action.quickOpenPreviousRecentlyUsedEditorInGroup" },
  { "-", "Split Window Below", "workbench.action.splitEditorDown" },
  { "|", "Split Window Right", "workbench.action.splitEditorRight" },

  { "aa", "Open Codex", "chatgpt.openSidebar" },
  { "an", "New Codex agent", "chatgpt.newCodexPanel" },
  { "aq", "Codex command menu", "chatgpt.openCommandMenu" },

  { "bD", "Close current file", "workbench.action.closeActiveEditor" },
  { "bb", "Switch to other buffer", "workbench.action.quickOpenPreviousRecentlyUsedEditorInGroup" },
  { "bd", "Close current file", "workbench.action.closeActiveEditor" },
  { "be", "Buffer Explorer", "workbench.action.showAllEditors" },
  { "bi", "Delete Invisible Buffers", "workbench.action.closeEditorsInOtherGroups" },
  { "bo", "Delete Other Buffers", "workbench.action.closeOtherEditors" },

  { "ca", "Code action", "editor.action.quickFix", nil, { "n", "x" } },
  { "cF", "Format Injected Langs", "editor.action.formatSelection", nil, { "n", "x" } },
  { "cS", "LSP references/definitions", "references-view.findReferences" },
  { "cd", "Line Diagnostics", "editor.action.showHover" },
  { "cf", "Format", "editor.action.formatDocument", nil, { "n", "x" } },
  { "cm", "Mason", "workbench.extensions.action.installedExtensions" },
  { "cr", "Rename symbol", "editor.action.rename" },
  { "cs", "Aerial (Symbols)", "workbench.action.gotoSymbol" },

  { "dB", "Breakpoint Condition", "editor.debug.action.conditionalBreakpoint" },
  { "dC", "Run to Cursor", "editor.debug.action.runToCursor" },
  { "dO", "Step Over", "workbench.action.debug.stepOver" },
  { "dP", "Pause", "workbench.action.debug.pause" },
  { "da", "Run with Args", "workbench.action.debug.selectandstart" },
  { "db", "Toggle Breakpoint", "editor.debug.action.toggleBreakpoint" },
  { "dc", "Run/Continue", "workbench.action.debug.continue" },
  { "de", "Eval", "editor.debug.action.selectionToRepl", nil, { "n", "x" } },
  { "dg", "Go to Line (No Execute)", "debug.jumpToCursor" },
  { "di", "Step Into", "workbench.action.debug.stepInto" },
  { "dj", "Down", "workbench.action.debug.callStackDown" },
  { "dk", "Up", "workbench.action.debug.callStackUp" },
  { "dl", "Run Last", "workbench.action.debug.restart" },
  { "do", "Step Out", "workbench.action.debug.stepOut" },
  { "dph", "Toggle Profiler Highlights", "workbench.view.debug" },
  { "dpp", "Toggle Profiler", "workbench.view.debug" },
  { "dps", "Profiler Scratch Buffer", "workbench.view.debug" },
  { "dr", "Toggle REPL", "workbench.debug.action.toggleRepl" },
  { "ds", "Session", "workbench.view.debug" },
  { "dt", "Terminate", "workbench.action.debug.stop" },
  { "du", "Dap UI", "workbench.view.debug" },
  { "dw", "Widgets", "workbench.debug.action.focusWatchView" },

  { "e", "Explorer NeoTree (Root Dir)", "workbench.view.explorer" },
  { "er", "Explorer: reveal active file", "workbench.files.action.showActiveFileInExplorer" },

  { "fB", "Buffers (all)", "workbench.action.showAllEditors" },
  { "fE", "Explorer NeoTree (cwd)", "workbench.view.explorer" },
  { "fF", "Find Files (cwd)", "workbench.action.quickOpen" },
  { "fR", "Recent (cwd)", "workbench.action.openRecent" },
  { "fT", "Terminal (cwd)", "workbench.action.terminal.toggleTerminal" },
  { "fb", "Switch Open File", "workbench.action.showAllEditors" },
  { "fc", "Find Config File", "workbench.action.openSettingsJson" },
  { "fe", "Explorer NeoTree (Root Dir)", "workbench.view.explorer" },
  { "ff", "Find Files (Root Dir)", "workbench.action.quickOpen" },
  { "fg", "Find Files (git-files)", "workbench.action.quickOpen" },
  { "fn", "New named file", "workbench.action.files.newUntitledFile" },
  { "fp", "Projects", "workbench.action.openRecent" },
  { "fr", "Recent", "workbench.action.openRecent" },
  { "ft", "Terminal (Root Dir)", "workbench.action.terminal.toggleTerminal" },
  { "fw", "Workspaces", "workbench.action.openRecent" },

  { "gB", "Git Browse (open)", "pr.openFileOnGitHub", nil, { "n", "x" } },
  { "gD", "Git Diff (origin)", "git.openChange" },
  { "gG", "Lazygit (cwd)", "lazygit-vscode.toggle" },
  { "gI", "GitHub Issues (all)", "issues.openIssuesWebsite" },
  { "gL", "Git Log (cwd)", "timeline.focus" },
  { "gP", "GitHub Pull Requests (all)", "pr.openPullsWebsite" },
  { "gS", "Git Stash", "git.stash" },
  { "gY", "Git Browse (copy)", "issue.copyGithubPermalink", nil, { "n", "x" } },
  { "gb", "Git Blame Line", "git.blame.toggleStatusBarItem" },
  { "gd", "Git Diff (hunks)", "git.openChange" },
  { "ge", "Git Explorer", "workbench.view.scm" },
  { "gf", "Git Current File History", "timeline.focus" },
  { "gg", "Lazygit (Root Dir)", "lazygit-vscode.toggle" },
  { "gi", "GitHub Issues (open)", "issues.openIssuesWebsite" },
  { "gl", "Git Log", "timeline.focus" },
  { "gp", "GitHub Pull Requests (open)", "pr.pick" },
  { "gs", "Git Status", "workbench.view.scm" },

  { "l", "Lazy", "workbench.extensions.action.installedExtensions" },
  { "mc", "Multi-cursor", "editor.action.addSelectionToNextFindMatch" },
  { "mt", "Markdown Table Edit", "markdown.showPreviewToSide" },
  { "n", "Notification History", "notifications.showList" },

  { "oo", "Run task", "workbench.action.tasks.runTask" },
  { "ot", "Task action", "workbench.action.tasks.manageAutomaticRunning" },
  { "ow", "Task list", "workbench.action.tasks.runTask" },
  { "p", "Open Yank History", standalone_only("Yank history", "workbench.action.showCommands"), nil, { "n", "x" } },

  { "qS", "Select Session", "workbench.action.openRecent" },
  { "qd", "Don't Save Current Session", "workbench.action.closeActiveEditor" },
  { "ql", "Restore Last Session", "workbench.action.openRecent" },
  { "qq", "Quit all safely", "workbench.action.closeWindow" },
  { "qs", "Restore Session", "workbench.action.openRecent" },

  { "rF", "Extract Function To File", "editor.action.refactor", nil, { "n", "x" } },
  { "rP", "Debug Print Location", "editor.action.insertSnippet" },
  { "rc", "Debug Cleanup", "editor.action.refactor", nil, { "n", "x" } },
  { "rf", "Extract Function", "editor.action.refactor", nil, { "n", "x" } },
  { "ri", "Inline Variable", "editor.action.refactor", nil, { "n", "x" } },
  { "rp", "Debug Print Variable", "editor.action.insertSnippet", nil, { "n", "x" } },
  { "rs", "Select Refactor", "editor.action.refactor", nil, { "n", "x" } },
  { "rx", "Extract Variable", "editor.action.refactor", nil, { "n", "x" } },

  { 's"', "Registers", standalone_only("Register picker", "workbench.action.showCommands") },
  { "s/", "Search History", "actions.find" },
  { "sB", "Grep Open Buffers", "workbench.action.findInFiles" },
  { "sC", "Commands", "workbench.action.showCommands" },
  { "sD", "Buffer Diagnostics", "workbench.actions.view.problems" },
  { "sG", "Grep (cwd)", "workbench.action.findInFiles" },
  { "sH", "Highlights", "editor.action.inspectTMScopes" },
  { "sM", "Man Pages", "workbench.action.showCommands" },
  { "sR", "Resume", "workbench.action.quickOpen" },
  { "ss", "Symbols", "workbench.action.gotoSymbol" },
  { "sT", "Todo/Fix/Fixme", action("workbench.action.findInFiles", { query = "TODO|FIX|FIXME", isRegex = true }) },
  {
    "sW",
    "Visual selection or word (cwd)",
    function()
      vscode.action("workbench.action.findInFiles", { args = { query = vim.fn.expand("<cword>") } })
    end,
    nil,
    { "n", "x" },
  },
  { "sa", "Autocmds", "workbench.action.showCommands" },
  { "sb", "Buffer Lines", "actions.find" },
  { "sc", "Command History", "workbench.action.showCommands" },
  { "sd", "Diagnostics", "workbench.actions.view.problems" },
  { "sg", "Grep (Root Dir)", "workbench.action.findInFiles" },
  { "sh", "Help Pages", "workbench.action.showCommands" },
  { "si", "Icons", "workbench.action.gotoSymbol" },
  { "sj", "Jumps", "workbench.action.navigateBackInEditLocations" },
  { "sk", "Keymaps", "workbench.action.openGlobalKeybindings" },
  { "sl", "Location List", "workbench.actions.view.problems" },
  { "sm", "Marks", standalone_only("Mark picker", "workbench.action.gotoLine") },
  { "sna", "Noice All", "notifications.showList" },
  { "snd", "Dismiss All", "notifications.clearAll" },
  { "snh", "Noice History", "notifications.showList" },
  { "snl", "Noice Last Message", "notifications.showList" },
  { "snt", "Noice Picker", "notifications.showList" },
  { "sp", "Search for Plugin Spec", action("workbench.action.findInFiles", { query = "return {" }) },
  { "sq", "Quickfix List", "workbench.actions.view.problems" },
  { "sr", "Search and Replace", "workbench.action.replaceInFiles", nil, { "n", "x" } },
  { "st", "Todo", action("workbench.action.findInFiles", { query = "TODO" }) },
  { "su", "Undotree", "timeline.focus" },
  {
    "sw",
    "Visual selection or word (Root Dir)",
    function()
      vscode.action("workbench.action.findInFiles", { args = { query = vim.fn.expand("<cword>") } })
    end,
    nil,
    { "n", "x" },
  },

  { "tO", "Toggle Output Panel (Neotest)", "testing.showMostRecentOutput" },
  { "tS", "Stop (Neotest)", "testing.cancelRun" },
  { "tT", "Run All Test Files (Neotest)", "testing.runAll" },
  { "ta", "Attach to Test (Neotest)", "workbench.view.extension.test" },
  { "td", "Debug Nearest", "testing.debugAtCursor" },
  { "tl", "Run Last (Neotest)", "testing.reRunLastRun" },
  { "to", "Show Output (Neotest)", "testing.showMostRecentOutput" },
  { "tr", "Run Nearest (Neotest)", "testing.runAtCursor" },
  { "ts", "Toggle Summary (Neotest)", "workbench.view.extension.test" },
  { "tt", "Run File (Neotest)", "testing.runCurrentFile" },
  { "tw", "Toggle Watch (Neotest)", "workbench.view.extension.test" },

  { "uA", "Toggle Tabline", "workbench.action.toggleTabsVisibility" },
  { "uC", "Colorschemes", "workbench.action.selectTheme" },
  { "uD", "Toggle Dimming", "workbench.action.toggleZenMode" },
  { "uF", "Toggle Auto Format (Buffer)", toggle_config("editor.formatOnSave", true, false) },
  { "uI", "Inspect Tree", "editor.action.inspectTMScopes" },
  { "uL", "Toggle Relative Number", toggle_config("editor.lineNumbers", "relative", "on") },
  { "uS", "Toggle Smooth Scroll", toggle_config("editor.smoothScrolling", true, false) },
  { "uT", "Toggle Treesitter Highlight", "editor.action.inspectTMScopes" },
  { "uZ", "Toggle Zoom Mode", "workbench.action.toggleMaximizedPanel" },
  { "ua", "Toggle mixed Arabic/English bidi", standalone_only("Neovim bidi display", "workbench.action.openSettings") },
  { "ub", "Toggle Dark Background", "workbench.action.selectTheme" },
  { "uc", "Toggle Conceal Level", "editor.action.toggleRenderWhitespace" },
  { "ud", "Toggle Diagnostics", "workbench.actions.view.problems" },
  { "uf", "Toggle Auto Format (Global)", toggle_config("editor.formatOnSave", true, false) },
  { "ug", "Toggle Indent Guides", toggle_config("editor.guides.indentation", true, false) },
  { "uh", "Toggle Inlay Hints", toggle_config("editor.inlayHints.enabled", "on", "off") },
  { "ui", "Inspect Pos", "editor.action.inspectTMScopes" },
  { "ul", "Toggle Line Numbers", toggle_config("editor.lineNumbers", "on", "off") },
  { "un", "Dismiss All Notifications", "notifications.clearAll" },
  { "up", "Toggle Mini Pairs", standalone_only("Mini Pairs toggle", "workbench.action.openSettings") },
  {
    "ur",
    "Redraw / Clear hlsearch / Diff Update",
    function()
      vim.cmd("nohlsearch")
      vim.cmd("redraw")
    end,
  },
  { "us", "Toggle Spelling", "cSpell.toggleEnableSpellChecker" },
  { "uw", "Toggle Wrap", "editor.action.toggleWordWrap" },
  { "uz", "Toggle Zen Mode", "workbench.action.toggleZenMode" },

  { "wL", "Workspace Layout", actions({
    "workbench.action.evenEditorWidths",
    "workbench.view.explorer",
  }) },
  { "wQ", "Close current window", "workbench.action.closeEditorsInGroup" },
  { "w=", "Window: equalize", "workbench.action.evenEditorWidths" },
  { "wa", "Workspace: save current", "workbench.action.addRootFolder" },
  { "wc", "Workspace: close tab", "workbench.action.closeFolder" },
  { "wd", "Close window safely", "workbench.action.closeEditorsInGroup" },
  { "wh", "Window: focus left", "workbench.action.focusLeftGroup" },
  { "wj", "Window: focus down", "workbench.action.focusBelowGroup" },
  { "wk", "Window: focus up", "workbench.action.focusAboveGroup" },
  { "wl", "Window: focus right", "workbench.action.focusRightGroup" },
  { "wm", "Toggle Zoom Mode", "workbench.action.toggleMaximizedPanel" },
  { "wq", "Close current file", "workbench.action.closeActiveEditor" },
  { "ws", "Window: split below", "workbench.action.splitEditorDown" },
  { "wv", "Window: split right", "workbench.action.splitEditorRight" },
  { "wW", "Window: focus previous", "workbench.action.focusPreviousGroup" },
  { "ww", "Window: focus next", "workbench.action.focusNextGroup" },

  { "xL", "Location List (Trouble)", "workbench.actions.view.problems" },
  { "xQ", "Quickfix List (Trouble)", "workbench.actions.view.problems" },
  {
    "xT",
    "Todo/Fix/Fixme (Trouble)",
    action("workbench.action.findInFiles", { query = "TODO|FIX|FIXME", isRegex = true }),
  },
  { "xX", "Buffer Diagnostics (Trouble)", "workbench.actions.view.problems" },
  { "xl", "Location List", "workbench.actions.view.problems" },
  { "xq", "Quickfix List", "workbench.actions.view.problems" },
  { "xt", "Todo (Trouble)", action("workbench.action.findInFiles", { query = "TODO" }) },
  { "xx", "Diagnostics (Trouble)", "workbench.actions.view.problems" },

  { "RJ", "Run Julia File", "language-julia.executeActiveFile" },
  { "RC", "Build and Run C++ File", "workbench.action.tasks.build" },
  { "RM", "Run Make Target", "workbench.action.tasks.runTask" },
  { "RP", "Run Python File", "python.execInTerminal" },
  { "Rc", "Build and Run C File", "workbench.action.tasks.build" },
  { "Rj", "Julia REPL", "language-julia.startREPL" },
  { "Rm", "Run Make", "workbench.action.tasks.build" },
  { "Rp", "Python REPL", "python.startREPL" },
}

local group_names = {
  ["<Tab>"] = "+pane tabs",
  a = "+Codex",
  b = "+buffers",
  c = "+code",
  d = "+debug",
  f = "+file/find",
  g = "+git",
  m = "+markdown/multicursor",
  o = "+tasks",
  q = "+quit/session",
  r = "+refactor",
  R = "+run",
  s = "+search",
  sn = "+notifications",
  t = "+test",
  u = "+toggle/UI",
  w = "+windows/workspace",
  x = "+diagnostics",
}

local function setup_leader_actions()
  for _, spec in ipairs(leader_specs) do
    local keys, desc, rhs, modes = spec[1], spec[2], spec[3], spec[5]
    bind(modes or "n", "<leader>" .. keys, rhs, desc)
  end

  for index = 1, 4 do
    bind("n", "<leader><Tab>" .. index, "workbench.action.openEditorAtIndex" .. index, "Pane tab: select " .. index)
  end
  bind("n", "<leader><Tab><Tab>", "workbench.action.nextEditor", "Pane tab: next")
  bind("n", "<leader><Tab>]", "workbench.action.nextEditor", "Pane tab: next")
  bind("n", "<leader><Tab>[", "workbench.action.previousEditor", "Pane tab: previous")
  bind("n", "<leader><Tab>f", "workbench.action.firstEditorInGroup", "Pane tab: first")
  bind("n", "<leader><Tab>l", "workbench.action.lastEditorInGroup", "Pane tab: last")
  bind("n", "<leader><Tab>d", "workbench.action.closeActiveEditor", "Pane tab: close file")
  bind("n", "<leader><Tab>o", "workbench.action.closeOtherEditors", "Pane tab: close others")
  bind("n", "<leader><Tab>w", "workbench.action.openRecent", "Workspaces")
end

local function tokenize(lhs)
  local tokens = {}
  local index = 1
  while index <= #lhs do
    if lhs:sub(index, index) == "<" then
      local close = lhs:find(">", index, true)
      if close then
        tokens[#tokens + 1] = lhs:sub(index, close)
        index = close + 1
      else
        tokens[#tokens + 1] = "<"
        index = index + 1
      end
    else
      local byte = lhs:byte(index)
      local width = byte < 0x80 and 1 or byte < 0xE0 and 2 or byte < 0xF0 and 3 or 4
      tokens[#tokens + 1] = lhs:sub(index, index + width - 1)
      index = index + width
    end
  end
  return tokens
end

local function whichkey_key(token)
  return ({
    ["<Tab>"] = "\t",
    ["<CR>"] = "\r",
    ["<Space>"] = " ",
    ["<BS>"] = "\b",
  })[token] or token
end

local function sequence_for_send(lhs)
  return lhs:sub(1, 1) == " " and ("<Space>" .. lhs:sub(2)) or lhs
end

local function insert_mapping(root, mapping)
  if mapping.lhs:sub(1, 1) ~= " " or mapping.lhs == " " or not mapping.desc or mapping.desc == "" then
    return
  end

  local node = root
  local path = ""
  for _, token in ipairs(tokenize(mapping.lhs:sub(2))) do
    path = path .. token
    node.children[token] = node.children[token] or { children = {}, path = path }
    node = node.children[token]
  end
  node.leaf = {
    name = mapping.desc:gsub("^%+", ""),
    sequence = sequence_for_send(mapping.lhs),
  }
end

local function menu_items(node)
  local items = {}
  for token, child in pairs(node.children) do
    if child.leaf then
      local item = command_item(whichkey_key(token), child.leaf.name, "vscode-neovim.send", child.leaf.sequence)
      -- A Neovim mapping can also be a prefix (for example, <leader>e and
      -- <leader>er). Which Key supports an item with both a command and nested
      -- bindings, so keep the parent action and every longer mapping visible.
      if next(child.children) then
        item.type = "bindings"
        item.bindings = menu_items(child)
      end
      items[#items + 1] = item
    else
      items[#items + 1] =
        group_item(whichkey_key(token), group_names[child.path] or ("+" .. child.path), menu_items(child))
    end
  end
  table.sort(items, function(left, right)
    local left_group = left.bindings and 0 or 1
    local right_group = right.bindings and 0 or 1
    if left_group ~= right_group then
      return left_group < right_group
    end
    return left.key < right.key
  end)
  return items
end

local function build_leader_menu()
  local root = { children = {} }
  for _, mapping in ipairs(vim.api.nvim_get_keymap("n")) do
    insert_mapping(root, mapping)
  end
  for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
    insert_mapping(root, mapping)
  end
  return menu_items(root)
end

function M.show_leader()
  show_which_key(build_leader_menu())
end

local function setup_direct_parity()
  bind("n", "u", counted_action("undo"), "VS Code undo")
  bind("n", "<C-r>", "workbench.action.openRecent", "Recent")
  bind("n", "<C-q>", "workbench.action.closeActiveEditor", "Close current file")
  bind("n", "<C-\\>", "workbench.action.toggleEditorWidths", "Toggle current file wide")
  map("v", "<C-c>", '"+y', { silent = true, desc = "Copy visual selection to system clipboard" })

  bind("n", "<C-p>", "workbench.action.quickOpen", "Quick Open")
  bind("n", "<C-S-p>", "workbench.action.showCommands", "Command Palette")
  bind("n", "<C-A-q>", "workbench.action.findInFiles", "Search: find in files")
  bind("n", "<C-A-d>", "workbench.explorer.fileView.focus", "Explorer: open or focus")
  bind("n", "<C-S-e>", "workbench.view.explorer", "Explorer: show or hide")
  bind("n", "<C-S-f>", "workbench.action.toggleActivityBarVisibility", "Toggle activity bar / Explorer")
  bind("n", "<A-f>", "workbench.action.toggleSidebarVisibility", "Explorer: show or hide")
  bind("n", "<C-Tab>", "workbench.action.nextEditor", "Next open editor")
  bind("n", "<C-S-Tab>", "workbench.action.previousEditor", "Previous open editor")
  bind("n", "<M-l>", "workbench.action.nextEditor", "Cycle files across all panes")
  bind("n", "[b", "workbench.action.previousEditor", "Previous file in pane")
  bind("n", "]b", "workbench.action.nextEditor", "Next file in pane")
  bind("n", "H", "workbench.action.previousEditor", "Previous editor")
  bind("n", "L", "workbench.action.nextEditor", "Next editor")
  bind("n", "<C-S-n>", "workbench.action.moveEditorToNewWindow", "Move editor to new tab")
  bind("n", "<S-A-q>", "workbench.action.closeWindow", "Close Neovim")
  bind("n", "<A-t>", "workbench.action.terminal.toggleTerminal", "Terminal group: show or hide")
  bind("n", "<C-A-b>", "workbench.action.terminal.toggleTerminal", "Terminal group: show or hide")
  bind("n", "<A-b>", "workbench.action.terminal.new", "Terminal: split or select pane (max 2)")
  bind("n", "<C-S-b>", "workbench.action.terminal.new", "Terminal: second pane (max 2)")

  bind("n", "<F2>", "editor.action.rename", "Rename symbol")
  bind("n", "<F8>", "editor.action.marker.nextInFiles", "Next problem")
  bind("n", "<S-F8>", "editor.action.marker.prevInFiles", "Previous problem")
  bind("n", "<F12>", "editor.action.revealDefinition", "Go to definition")
  bind("n", "<S-F12>", "editor.action.goToReferences", "Go to references")
  bind("n", "<C-CR>", "editor.action.revealDefinition", "Open definition under cursor")
  bind({ "n", "x" }, "<C-.>", "editor.action.quickFix", "Quick fix / code action")
  bind("n", "<A-Left>", "workbench.action.navigateBack", "Navigate back")
  bind("n", "<A-Right>", "workbench.action.navigateForward", "Navigate forward")
  bind({ "n", "x" }, "<S-A-f>", "editor.action.formatDocument", "Format document")
  bind({ "n", "x" }, "<A-Down>", "editor.action.moveLinesDownAction", "Move line/selection down")
  bind({ "n", "x" }, "<A-Up>", "editor.action.moveLinesUpAction", "Move line/selection up")

  bind("n", "<S-A-2>", "workbench.action.splitEditorRight", "Split editor right")
  bind("n", "<C-A-w>", "workbench.action.moveEditorToLeftGroup", "Move file to left editor pane")
  bind("n", "<C-A-e>", "workbench.action.moveEditorToRightGroup", "Move file to right editor pane")
  bind("n", "<C-A-t>", "workbench.action.toggleMaximizedPanel", "Toggle maximized panel")
  bind("n", "<F11>", "workbench.action.toggleZenMode", "Toggle fullscreen / Zen mode")
  bind("n", "<C-A-f>", "workbench.action.toggleAuxiliaryBar", "Toggle auxiliary sidebar")
  bind("n", "<C-A-g>", "lazygit-vscode.toggle", "Source control")
  bind("n", "<C-A-v>", "workbench.view.scm", "Source control files")
  bind("n", "<A-,>", "workbench.action.compareEditor.previousChange", "Previous change")
  bind("n", "<A-.>", "workbench.action.compareEditor.nextChange", "Next change")
  bind("n", "<A-r>", "git.openChange", "Preview change")
  bind("n", "<A-d>", "revealFileInOS", "Reveal file in system explorer")
  bind("n", "<C-A-s>", "copyFilePath", "Copy file path")
  bind("n", "<C-A-p>", "workbench.extensions.action.installedExtensions", "Package explorer")
  bind("n", "<C-S-g>", "foam-vscode.show-graph", "Markdown link graph")
  bind("n", "<C-S-Left><Delete>", "foam-vscode.open-daily-note", "Open daily note")
  bind(
    "n",
    "<C-S-A-r>",
    standalone_only("Neovim bidi display", "workbench.action.openSettings"),
    "Toggle mixed Arabic/English bidi"
  )
  bind("n", "<A-g>", "workbench.action.chat.open", "Gemini / AI chat")
  bind("n", "<C-A-o>", "opencode.openNewTerminal", "OpenCode CLI")
  bind("n", "<C-A-x>", "chatgpt.sidebarSecondaryView.focus", "Codex / Claude")
  bind("n", "<S-A-b>", "matlab.openCommandWindow", "MATLAB command window")
  bind("n", "<C-A-n>", "matlab.openCommandWindow", "MATLAB terminal")

  bind("n", "<C-/>", "workbench.action.terminal.toggleTerminal", "Terminal")
  bind("n", "<C-_>", "workbench.action.terminal.toggleTerminal", "Terminal")

  local function move_wrapped(direction, select)
    return function()
      vscode.action("cursorMove", {
        args = {
          to = direction == "j" and "down" or "up",
          by = "wrappedLine",
          value = vim.v.count1,
          select = select,
        },
      })
    end
  end

  bind("n", "gj", move_wrapped("j", false), "Next display line", { nowait = true })
  bind("n", "gk", move_wrapped("k", false), "Previous display line", { nowait = true })
  bind("v", "gj", move_wrapped("j", true), "Select next display line", { nowait = true })
  bind("v", "gk", move_wrapped("k", true), "Select previous display line", { nowait = true })
end

function M.health()
  local report = {
    errors = {},
    warnings = {},
    leader_maps = 0,
    menu_items = 0,
  }

  for _, mapping in ipairs(vim.api.nvim_get_keymap("n")) do
    if mapping.lhs:sub(1, 1) == " " and mapping.lhs ~= " " then
      report.leader_maps = report.leader_maps + 1
      if not mapping.desc or mapping.desc == "" then
        report.errors[#report.errors + 1] = "leader mapping has no description: " .. mapping.lhs
      end
    end
  end

  local function count(items)
    for _, item in ipairs(items) do
      report.menu_items = report.menu_items + 1
      if item.command == "vscode-neovim.send" then
        report.menu_sequences[item.args] = true
      elseif item.command then
        report.errors[#report.errors + 1] = "menu leaf does not return through Neovim: " .. item.name
      end
      if item.bindings then
        count(item.bindings)
      elseif not item.command then
        report.errors[#report.errors + 1] = "menu leaf does not return through Neovim: " .. item.name
      end
    end
  end
  report.menu_sequences = {}
  count(build_leader_menu())

  for _, mappings in ipairs({ vim.api.nvim_get_keymap("n"), vim.api.nvim_buf_get_keymap(0, "n") }) do
    for _, mapping in ipairs(mappings) do
      if mapping.lhs:sub(1, 1) == " " and mapping.lhs ~= " " and mapping.desc and mapping.desc ~= "" then
        local sequence = sequence_for_send(mapping.lhs)
        if not report.menu_sequences[sequence] then
          report.errors[#report.errors + 1] = "leader mapping is missing from the menu: " .. mapping.lhs
        end
      end
    end
  end
  report.menu_sequences = nil

  for _, spec in ipairs(leader_specs) do
    local modes = type(spec[5]) == "table" and spec[5] or { spec[5] or "n" }
    for _, mode in ipairs(modes) do
      local lhs = "<leader>" .. spec[1]
      local mapping = vim.fn.maparg(lhs, mode, false, true)
      if vim.tbl_isempty(mapping) then
        report.errors[#report.errors + 1] = ("missing declared leader action: %s %s"):format(mode, lhs)
      elseif mapping.desc ~= spec[2] then
        report.errors[#report.errors + 1] = ("wrong declared leader owner: %s %s (%s)"):format(
          mode,
          lhs,
          mapping.desc or "no description"
        )
      end
    end
  end

  for _, lhs in ipairs({ " ", "g", "z", "[", "]", '"', "q", "@", "m", "'", "`", "<C-w>" }) do
    if vim.tbl_isempty(vim.fn.maparg(lhs, "n", false, true)) then
      report.errors[#report.errors + 1] = "missing discovery prefix: " .. lhs
    end
  end

  for _, expected in ipairs({
    { "<C-r>", "Recent" },
    { "<C-q>", "Close current file" },
    { "<C-\\>", "Toggle current file wide" },
    { "<C-S-f>", "Toggle activity bar / Explorer" },
  }) do
    local mapping = vim.fn.maparg(expected[1], "n", false, true)
    if vim.tbl_isempty(mapping) then
      report.errors[#report.errors + 1] = "missing shared utility key: " .. expected[1]
    elseif mapping.desc ~= expected[2] then
      report.errors[#report.errors + 1] = ("wrong shared utility key owner: %s (%s)"):format(
        expected[1],
        mapping.desc or "no description"
      )
    end
  end

  report.ok = #report.errors == 0 and report.leader_maps >= 150 and report.menu_items >= 150
  if report.leader_maps < 150 then
    report.errors[#report.errors + 1] = "too few leader mappings: " .. report.leader_maps
  end
  if report.menu_items < 150 then
    report.errors[#report.errors + 1] = "too few menu items: " .. report.menu_items
  end
  return report
end

function M.setup()
  if M._setup then
    return
  end
  M._setup = true

  vim.opt.timeout = true
  vim.opt.timeoutlen = 300

  setup_leader_actions()
  setup_direct_parity()
  setup_native_prefixes()

  map("n", "<leader>", M.show_leader, { silent = true, desc = "Leader (Which Key)" })

  vim.api.nvim_create_user_command("VscodeParityHealth", function()
    local report = M.health()
    local lines = {
      ("VS Code parity: %s"):format(report.ok and "PASS" or "FAIL"),
      ("Leader mappings: %d | menu items: %d"):format(report.leader_maps, report.menu_items),
    }
    for _, error in ipairs(report.errors) do
      lines[#lines + 1] = "ERROR: " .. error
    end
    vscode.notify(table.concat(lines, "\n"), report.ok and vim.log.levels.INFO or vim.log.levels.ERROR)
  end, { desc = "Audit VSCode-Neovim key and menu parity" })
end

return M
