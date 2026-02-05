vim.opt.rtp:append(".")
vim.opt.rtp:append("../plenary.nvim")

vim.cmd("runtime plugin/plenary.vim")

vim.o.swapfile = false
vim.bo.swapfile = false
