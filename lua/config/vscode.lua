-- Only load this plugin if we're inside VSCode (Neovim extension)
if not vim.g.vscode then
  return {}
end

-- LazyVim installs its default/plugin mappings during startup. Apply the
-- parity layer afterwards so native VS Code surfaces win only where a terminal
-- Neovim UI or plugin cannot work inside the embedded editor.
vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  once = true,
  callback = function()
    -- Other LazyVim extras also install mappings from this event. Scheduling
    -- makes the parity layer the deterministic final owner of shared keys.
    vim.schedule(function()
      require("config.vscode_parity").setup()
    end)
  end,
  desc = "Install full Neovim key and menu parity in VS Code",
})

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
