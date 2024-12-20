-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

--require('nvim-treesitter.install').compilers = { "clang" }
require("nvim-treesitter.install").compilers = { "gcc" }
-- Remove or comment out the following line if present:
-- neovim.stop()
