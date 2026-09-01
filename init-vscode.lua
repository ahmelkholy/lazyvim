-- VSCode-Neovim entrypoint.
--
-- Use the same LazyVim configuration as standalone Neovim. LazyVim's VS Code
-- extra keeps only editing-safe plugins active, while config.vscode_parity
-- translates file/UI actions to native VS Code commands and supplies the same
-- discoverable prefix menus.

if not vim.g.vscode then
  return
end

dofile(vim.fn.stdpath("config") .. "/init.lua")
