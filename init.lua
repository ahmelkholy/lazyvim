-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

vim.keymap.set("v", "<C-c>", '"+y', { desc = "Copy visual selection to system clipboard", silent = true })

if vim.fn.executable("pwsh") == 1 then
  require("lazyvim.util.terminal").setup("pwsh")
end
