local M = {}

local group = vim.api.nvim_create_augroup("semantic_symbol_links", { clear = true })

local function apply_highlights()
  local identifier = vim.api.nvim_get_hl(0, { name = "Identifier", link = false })
  local function_color = identifier.fg or vim.api.nvim_get_hl(0, { name = "Function", link = false }).fg
  vim.api.nvim_set_hl(0, "SymbolLink", { fg = function_color })

  -- Calls look link-like without bold/underline. Semantic definition modifiers
  -- restore the colorscheme's normal declaration styling when the server
  -- provides that distinction.
  for _, name in ipairs({
    "@function.call",
    "@method.call",
    "@lsp.type.function",
    "@lsp.type.method",
  }) do
    vim.api.nvim_set_hl(0, name, { link = "SymbolLink" })
  end
  for _, name in ipairs({
    "@lsp.typemod.function.declaration",
    "@lsp.typemod.function.definition",
    "@lsp.typemod.method.declaration",
    "@lsp.typemod.method.definition",
  }) do
    vim.api.nvim_set_hl(0, name, { link = "Function" })
  end
end

local function supports_definition(buf)
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
    if client:supports_method("textDocument/definition") then
      return true
    end
  end
  return false
end

local function open_mouse_definition()
  local position = vim.fn.getmousepos()
  local win = tonumber(position.winid)
  if not win or win == 0 or position.line < 1 or position.column < 1 or not vim.api.nvim_win_is_valid(win) then
    return
  end

  local buf = vim.api.nvim_win_get_buf(win)
  if not supports_definition(buf) then
    vim.notify("No definition provider is attached to this file", vim.log.levels.INFO, { title = "Definition" })
    return
  end

  vim.api.nvim_set_current_win(win)
  vim.api.nvim_win_set_cursor(win, { position.line, math.max(0, position.column - 1) })
  vim.lsp.buf.definition({ reuse_win = true })
end

local function open_cursor_definition()
  local buf = vim.api.nvim_get_current_buf()
  if not supports_definition(buf) then
    vim.notify("No definition provider is attached to this file", vim.log.levels.INFO, { title = "Definition" })
    return
  end
  vim.lsp.buf.definition({ reuse_win = true })
end

local function map_buffer(buf)
  if vim.b[buf].semantic_symbol_links_mapped or not supports_definition(buf) then
    return
  end
  vim.b[buf].semantic_symbol_links_mapped = true
  vim.keymap.set("n", "<C-LeftMouse>", open_mouse_definition, {
    buffer = buf,
    desc = "Open function or symbol definition",
    nowait = true,
    silent = true,
  })
  vim.keymap.set("n", "<C-CR>", open_cursor_definition, {
    buffer = buf,
    desc = "Open function or symbol definition",
    nowait = true,
    silent = true,
  })
end

function M.setup()
  apply_highlights()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = apply_highlights,
    desc = "Keep function calls subtly link-colored",
  })
  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(args)
      map_buffer(args.buf)
    end,
    desc = "Enable Ctrl+click definition links when supported",
  })

  for _, client in ipairs(vim.lsp.get_clients()) do
    for buf in pairs(client.attached_buffers or {}) do
      map_buffer(buf)
    end
  end
end

return M
