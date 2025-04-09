-- Only load if we're inside VSCode
if not vim.g.vscode then
  return {}
end

-- When in VSCode, disable spell checking since VSCode handles it
vim.opt.spell = false
vim.opt.spelllang = {}

-- Common options for all mappings
local opts = { noremap = true, silent = true }

-- Normal mode mappings
vim.keymap.set('n', 'j', 'gj', opts)
vim.keymap.set('n', 'k', 'gk', opts)

-- Visual mode mappings (includes Select mode)
vim.keymap.set('x', 'j', 'gj', opts)
vim.keymap.set('x', 'k', 'gk', opts)

-- Keep original j/k behavior with gj/gk
vim.keymap.set('n', 'gj', 'j', opts)
vim.keymap.set('n', 'gk', 'k', opts)
vim.keymap.set('x', 'gj', 'j', opts)
vim.keymap.set('x', 'gk', 'k', opts)

-- Return the plugin configuration
return {
  "mg979/vim-visual-multi",
  branch = "master",
  event = "BufReadPost",
  config = function()
    -- Disable default mappings for custom setup
    vim.g.VM_default_mappings = 0

    -- Map Ctrl+D in Normal and Visual modes
    vim.keymap.set("n", "<C-d>", "<Plug>(VM-Find-Under)", {})
    vim.keymap.set("x", "<C-d>", "<Plug>(VM-Find-Subword-Under)", {})
  end,
}
