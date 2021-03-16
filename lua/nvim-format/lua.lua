local g = vim.g
local opt = {noremap = true}


g.neoformat_only_msg_on_error = 1
g.neoformat_python_black = {
   exe = 'black',
   args = {'--line-length=100'},
   stdin = 1,
}

g.neoformat_disalbe_on_save = 1
g.neoformat_enabled_python = {'black'}

vim.api.nvim_set_keymap("n", "<Leader>fm", [[<Cmd> Neoformat<CR>]], opt)
