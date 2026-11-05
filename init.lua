-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

require("config.clipboard").setup()

if vim.fn.executable("pwsh") == 1 then
  require("lazyvim.util.terminal").setup("pwsh")
end
