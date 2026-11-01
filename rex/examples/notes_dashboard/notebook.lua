-- A self-contained editor setup; does not change the user's Neovim config.
vim.opt.termguicolors = true
vim.opt.number = true
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.scrolloff = 3
vim.opt.swapfile = false
vim.opt.showmode = true
vim.opt.laststatus = 2
vim.opt.shortmess:append('I')
vim.cmd('syntax enable')
vim.cmd('colorscheme habamax')
vim.opt.statusline = '  SESSION NOTEBOOK  |  i: edit   Esc: finish   :q: close  %=%m  autosave  '
vim.api.nvim_set_hl(0, 'StatusLine', {fg='#0e1828', bg='#7dd3fc', bold=true})
vim.api.nvim_set_hl(0, 'markdownH1', {fg='#7dd3fc', bold=true})
vim.api.nvim_create_autocmd({'TextChanged', 'TextChangedI', 'InsertLeave', 'FocusLost'}, {
  callback = function()
    if vim.bo.modified and vim.bo.buftype == '' and vim.bo.modifiable then
      vim.cmd('silent update')
    end
  end,
})
