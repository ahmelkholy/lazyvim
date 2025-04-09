-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

vim.opt.linebreak = true
vim.opt.wrap = true

-- Map j/k to gj/gk for better navigation of wrapped lines
vim.keymap.set('n', 'j', 'gj', { noremap = true })
vim.keymap.set('n', 'k', 'gk', { noremap = true })
vim.keymap.set('v', 'j', 'gj', { noremap = true })
vim.keymap.set('v', 'k', 'gk', { noremap = true })

vim.opt.shell = "pwsh"
vim.opt.shellcmdflag = "-NoLogo -Command"
