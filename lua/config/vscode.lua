-- Only load this plugin if we're inside VSCode (Neovim extension)
if not vim.g.vscode then
  return {}
end

-- When in VSCode, disable spell checking since VSCode handles it
vim.opt.spell = false
vim.opt.spelllang = {}

-- Movement functions for VSCode
local function move(d)
  return function()
    -- Only works in charwise visual mode
    if vim.api.nvim_get_mode().mode ~= 'v' then return 'g' .. d end
    require('vscode-neovim').action('cursorMove', {
      args = {
        {
          to = d == 'j' and 'down' or 'up',
          by = 'wrappedLine',
          value = vim.v.count1,
          select = true,
        },
      },
    })
    return '<Ignore>'
  end
end

-- Set up movement keymaps
vim.keymap.set({ 'v' }, 'gj', move('j'), { expr = true })
vim.keymap.set({ 'v' }, 'gk', move('k'), { expr = true })

-- Return plugin configurations that disable dashboard plugins and configure vim-visual-multi
return {
  -- Disable dashboard/startup plugins in VSCode
  { "alpha-nvim", enabled = false },
  { "dashboard-nvim", enabled = false },
  { "mini.starter", enabled = false },

  -- Configure vim-visual-multi for VSCode
  {
    "mg979/vim-visual-multi",
    branch = "master",
    event = "BufReadPost",
    config = function()
      -- Disable default mappings if you want a custom <C-d> setup
      vim.g.VM_default_mappings = 0

      -- Map Ctrl+D in Normal mode
      vim.keymap.set("n", "<C-d>", "<Plug>(VM-Find-Under)", {})
      -- Map Ctrl+D in Visual mode
      vim.keymap.set("x", "<C-d>", "<Plug>(VM-Find-Subword-Under)", {})
    end,
  },
}