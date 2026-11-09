local M = {}

function M.options()
  -- Keep Vim's register/paste behavior; mirror yanks and deletes below.
  vim.opt.clipboard = ""
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
  vim.api.nvim_create_autocmd("TextYankPost", {
    group = vim.api.nvim_create_augroup("system_clipboard_yanks", { clear = true }),
    callback = function()
      local operator = vim.v.event.operator
      if (operator == "y" or operator == "d") and vim.v.event.regname ~= "+" and vim.v.event.regname ~= "_" then
        vim.fn.setreg("+", vim.v.event.regcontents, vim.v.event.regtype)
      end
    end,
    desc = "Copy yanked or deleted text to the system clipboard, except black-hole operations",
  })
end

return M
