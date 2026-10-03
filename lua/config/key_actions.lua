local M = {}

-- Only reviewed equivalents belong here. Arbitrary extension commands and
-- language/terminal/OS contexts cannot be safely translated to a Vim mapping.
M.targets = {
  ["workbench.action.openRecent"] = "<C-r>",
  ["workbench.action.quickOpen"] = "<C-p>",
  ["workbench.action.showAllEditors"] = "<leader>,",
  ["workbench.action.showCommands"] = "<C-S-p>",
  ["workbench.action.closeActiveEditor"] = "<C-q>",
  ["workbench.action.closeWindow"] = "<leader>qq",
  ["workbench.action.files.save"] = "<C-s>",
  ["workbench.action.files.saveWithoutFormatting"] = "<leader>W",
  ["workbench.action.files.newUntitledFile"] = "<leader>fn",
  ["workbench.action.findInFiles"] = "<C-A-q>",
  ["actions.find"] = "<C-f>",
  ["undo"] = "<C-z>",
  ["redo"] = "<C-S-z>",
  ["workbench.action.focusLeftGroup"] = "<leader>wh",
  ["workbench.action.focusBelowGroup"] = "<leader>wj",
  ["workbench.action.focusAboveGroup"] = "<leader>wk",
  ["workbench.action.focusRightGroup"] = "<leader>wl",
  ["workbench.action.focusNextGroup"] = "<leader>ww",
  ["workbench.action.focusPreviousGroup"] = "<leader>wW",
  ["workbench.action.splitEditorRight"] = "<leader>wv",
  ["workbench.action.splitEditorDown"] = "<leader>ws",
  ["workbench.action.evenEditorWidths"] = "<leader>w=",
  ["workbench.action.toggleEditorWidths"] = "<C-\\>",
  ["workbench.action.nextEditor"] = "<C-Tab>",
  ["workbench.action.previousEditor"] = "<C-S-Tab>",
  ["workbench.action.moveEditorToLeftGroup"] = "<C-A-w>",
  ["workbench.action.moveEditorToRightGroup"] = "<C-A-e>",
  ["workbench.action.toggleActivityBarVisibility"] = "<C-S-f>",
  ["workbench.view.explorer"] = "<C-S-e>",
  ["workbench.action.toggleSidebarVisibility"] = "<A-f>",
  ["workbench.action.terminal.toggleTerminal"] = "<C-A-b>",
  ["workbench.action.terminal.new"] = "<A-b>",
  ["workbench.action.toggleZenMode"] = "<leader>uz",
  ["editor.action.rename"] = "<F2>",
  ["editor.action.revealDefinition"] = "<F12>",
  ["editor.action.goToReferences"] = "<S-F12>",
  ["editor.action.quickFix"] = "<C-.>",
  ["editor.action.formatDocument"] = "<S-A-f>",
  ["editor.action.marker.nextInFiles"] = "<F8>",
  ["editor.action.marker.prevInFiles"] = "<S-F8>",
  ["workbench.action.navigateBack"] = "<A-Left>",
  ["workbench.action.navigateForward"] = "<A-Right>",
  ["copyFilePath"] = "<C-A-s>",
  ["revealFileInOS"] = "<A-d>",
  ["lazygit-vscode.toggle"] = "<C-A-g>",
  ["workbench.view.scm"] = "<C-A-v>",
}

function M.infer(binding)
  if binding.command == "vscode-neovim.send" and type(binding.args) == "string" and binding.args ~= "" then
    return binding.args
  end
  if binding.args ~= nil then
    return nil, "command arguments need an explicit reviewed Neovim equivalent"
  end
  if M.targets[binding.command] then
    return M.targets[binding.command]
  end
  return nil, "no reviewed Neovim equivalent for " .. tostring(binding.command)
end

function M.editor_scope(binding)
  local when = binding.when
  if when == nil or when == "" then
    return true
  end
  local allowed = {
    editorTextFocus = true,
    ["neovim.init"] = true,
    ["!lazygitFocus"] = true,
    ["neovim.mode == 'normal'"] = true,
    ["neovim.mode == 'visual'"] = true,
    ["neovim.mode != 'insert'"] = true,
    ["neovim.mode != 'cmdline'"] = true,
  }
  for _, clause in ipairs(vim.split(when, "&&", { plain = true })) do
    clause = vim.trim(clause)
    if not allowed[clause] then
      return false, "context cannot be mirrored safely: " .. clause
    end
  end
  if
    when:find("'visual'", 1, true)
    and binding.command ~= "vscode-neovim.send"
    and binding.command ~= "editor.action.quickFix"
    and binding.command ~= "editor.action.formatDocument"
  then
    return false, "no reviewed Visual-mode equivalent for " .. tostring(binding.command)
  end
  return true
end

return M
