local saga = require 'lspsaga'

saga.init_lsp_saga()

local function map(mode, lhs, rhs, opts)
    local options = {noremap = true}
    if opts then options = vim.tbl_extend("force", options, opts)
    end
    vim.api.nvim_set_keymap(mode, lhs, rhs, options)
end

map("n", "<space>ca", "<Cmd>lua require('lspsaga.codeaction').code_action()<CR>", {noremap = true, silent = true})
map("v", "<space>ca", "<C-U>lua require('lspsaga.codeaction').range_code_action<CR>", {noremap = true, silent = true})
map("n", "<space>gr", "<Cmd>lua require('lspsaga.rename').rename()<CR>", {noremap = true, silent = true})
