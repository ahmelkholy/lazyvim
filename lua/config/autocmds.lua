-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

vim.api.nvim_create_user_command("NvimTransition", function()
  local guide = vim.fn.stdpath("config") .. "/NVIM_TRANSITION_GUIDE.md"
  vim.cmd.tabnew(vim.fn.fnameescape(guide))
end, { desc = "Open the personalized VS Code to Neovim transition guide" })

require("config.workspace").setup()
require("config.workspaces").setup()
require("config.symbol_links").setup()

vim.api.nvim_create_user_command("ShortcutHealth", function()
  require("config.shortcut_health").show()
end, { desc = "Audit leader and custom shortcut availability" })

-- Match Ctrl+C in graphical editors: every yank is also copied to the system
-- clipboard without changing the normal behavior of delete/change registers.
vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("system_clipboard_yanks", { clear = true }),
  callback = function()
    if vim.v.event.operator == "y" then
      pcall(vim.fn.setreg, "+", vim.v.event.regcontents, vim.v.event.regtype)
    end
  end,
  desc = "Mirror yanks to the system clipboard",
})

local writing_aids = vim.api.nvim_create_augroup("writing_aids", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
  group = writing_aids,
  pattern = { "gitcommit", "markdown", "markdown.mdx", "plaintex", "tex" },
  callback = function()
    vim.opt_local.spell = true
    vim.opt_local.spelloptions:append("camel")
  end,
  desc = "Enable lightweight spelling only in prose-oriented files",
})
-- Keep all real code and document buffers inside the visible window. Plugins
-- can create windows after the global options are applied, so reinforce these
-- display-only settings without affecting terminals, pickers, or dashboards.
local visual_wrap = vim.api.nvim_create_augroup("visual_wrap", { clear = true })

local function is_readable_buffer(buf)
  return vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "" and vim.bo[buf].filetype ~= "snacks_picker_input"
end

local function apply_visual_wrap(win)
  if not vim.api.nvim_win_is_valid(win) then
    return
  end
  local buf = vim.api.nvim_win_get_buf(win)
  if not is_readable_buffer(buf) and not vim.wo[win].diff then
    return
  end
  local table_wrap_owned = false
  if vim.bo[buf].filetype:match("^markdown") then
    local ok, markdown_tables = pcall(require, "config.markdown_tables")
    if ok then
      table_wrap_owned = markdown_tables.update_wrap(buf, win)
    end
  end
  if not table_wrap_owned then
    vim.wo[win].wrap = true
  end
  vim.wo[win].linebreak = true
  -- Clear this locally as well as globally so restored sessions and plugin
  -- windows cannot retain an old continuation marker.
  vim.wo[win].showbreak = ""
  if vim.bo[buf].filetype == "markdown" then
    -- Render prose like a normal paragraph: continuation lines begin at the
    -- left edge without a wrap marker or synthetic indentation.
    vim.wo[win].breakindent = false
  else
    vim.wo[win].breakindent = true
  end
end

vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter", "WinEnter" }, {
  group = visual_wrap,
  callback = function()
    apply_visual_wrap(vim.api.nvim_get_current_win())
  end,
  desc = "Wrap code, documents, and diffs cleanly",
})

vim.api.nvim_create_autocmd("OptionSet", {
  group = visual_wrap,
  pattern = "diff",
  callback = function()
    vim.schedule(function()
      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.wo[win].diff then
          apply_visual_wrap(win)
        end
      end
    end)
  end,
  desc = "Wrap both sides as soon as diff mode starts",
})
