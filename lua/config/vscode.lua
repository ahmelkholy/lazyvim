-- Only load this plugin if we're inside VSCode (Neovim extension)
if not vim.g.vscode then
  return {}
end

local vscode = require("vscode")

local function vscode_action(name)
  return function()
    vscode.action(name)
  end
end

-- VS Code owns wrapped-line geometry, so delegate gj/gk in both normal and
-- visual mode instead of relying on Neovim's incomplete viewport model.
local function move(d, select)
  return function()
    vscode.action("cursorMove", {
      args = {
        to = d == "j" and "down" or "up",
        by = "wrappedLine",
        value = vim.v.count1,
        select = select,
      },
    })
  end
end

-- Set up movement keymaps
vim.keymap.set("n", "gj", move("j", false), { silent = true, desc = "Down one wrapped line" })
vim.keymap.set("n", "gk", move("k", false), { silent = true, desc = "Up one wrapped line" })
vim.keymap.set("v", "gj", move("j", true), { silent = true, desc = "Select down one wrapped line" })
vim.keymap.set("v", "gk", move("k", true), { silent = true, desc = "Select up one wrapped line" })
vim.keymap.set("n", "u", vscode_action("undo"), { silent = true, desc = "VS Code undo" })
vim.keymap.set("n", "<C-r>", vscode_action("redo"), { silent = true, desc = "VS Code redo" })

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
