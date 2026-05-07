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

-- Return plugin configurations that disable UI plugins handled by VS Code.
return {
  -- Disable UI-heavy plugins in VSCode. VS Code owns these surfaces there.
  { "goolord/alpha-nvim", enabled = false },
  { "akinsho/bufferline.nvim", enabled = false },
  { "nvimdev/dashboard-nvim", enabled = false },
  { "nvim-neo-tree/neo-tree.nvim", enabled = false },
  { "folke/noice.nvim", enabled = false },
  { "nvim-lualine/lualine.nvim", enabled = false },
  { "nvim-mini/mini.starter", enabled = false },
  { "folke/trouble.nvim", enabled = false },
}
