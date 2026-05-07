-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

vim.opt.linebreak = true
vim.opt.wrap = true

-- require("nvim-treesitter.install").prefer_git = false
-- require("nvim-treesitter.install").compilers = { "clang" }
-- Remove or comment out the following line if present:
-- neovim.stop()

if vim.fn.executable("pwsh") == 1 then
  vim.opt.shell = "pwsh"
  vim.opt.shellcmdflag = "-NoLogo -Command"
end
