local M = {}

function M.options()
  -- Use the same clipboard for native y/d/c/x and p/P, including Yanky puts.
  vim.opt.clipboard = "unnamedplus"
  if vim.g.vscode and type(vim.g.vscode_clipboard) == "table" then
    -- The clipboard belongs to the VS Code client, including remote sessions.
    vim.g.clipboard = vim.g.vscode_clipboard
  end
end

function M.setup()
  M.options()
  vim.keymap.set("n", "<C-c>", '"+yy', { silent = true, desc = "Copy current line to system clipboard" })
  vim.keymap.set("x", "<C-c>", '"+y', { silent = true, desc = "Copy selection to system clipboard" })
  vim.keymap.set("s", "<C-c>", '<C-g>"+y', { silent = true, desc = "Copy selection to system clipboard" })
  -- Clear the former copy-only mirror on reload. Native clipboard handling
  -- avoids duplicate writes and preserves explicit named/black-hole registers.
  vim.api.nvim_create_augroup("system_clipboard_yanks", { clear = true })
end

return M
