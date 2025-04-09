
-- Only load this plugin if we're inside VSCode (Neovim extension)
if not vim.g.vscode then
  return {}
end

-- When in VSCode, disable spell checking since VSCode handles it
vim.opt.spell = false
vim.opt.spelllang = {}

return {
  "mg979/vim-visual-multi",
  branch = "master",

  -- Optional: lazy-load on an event
  event = "BufReadPost",

  config = function()
    -- Disable default mappings if you want a custom <C-d> setup
    vim.g.VM_default_mappings = 0

    -- Map Ctrl+D in Normal mode
    vim.keymap.set("n", "<C-d>", "<Plug>(VM-Find-Under)", {})
    -- Map Ctrl+D in Visual mode
    vim.keymap.set("x", "<C-d>", "<Plug>(VM-Find-Subword-Under)", {})
  end,
}
