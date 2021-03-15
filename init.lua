-- load plugins
require("pluginsList.lua")
require("web-devicons.lua")

require("utils.lua")
require("nvimTree.lua")
require("bufferline.lua")
require("statusline.lua")
require("telescope-nvim.lua")

-- lsp
require("nvim-lspconfig.lua")
require("nvim-compe.lua")

require("gitsigns.lua")

require "colorizer".setup()

local cmd = vim.cmd
local g = vim.g
local indent = 2

vim.wo.relativenumber = true
vim.wo.number = true
-- This will be available for everyone when I merge:
--  https://github.com/neovim/neovim/pull/13479
-- Until then, you can check out `./lua/tj/globals/opt.lua
--[[
   [local opt = vim.opt
   ]]


-- Will move these to its own place
--[[
   [opt.wildignore = '__pycache__'
   [opt.wildignore = opt.wildignore + { '*.o' , '*~', '*.pyc', '*pycache*' }
   [opt.showmode       = false
   [opt.showcmd        = true
   [opt.cmdheight      = 1     -- Height of the command bar
   [opt.incsearch      = true  -- Makes search act like search in modern browsers
   [opt.showmatch      = true  -- show matching brackets when text indicator is over them
   [opt.relativenumber = true  -- Show line numbers
   [opt.number         = true  -- But show the actual number for the line we're on
   [opt.ignorecase     = true  -- Ignore case when searching...
   [opt.smartcase      = true  -- ... unless there is a capital letter in the query
   [opt.hidden         = true  -- I like having buffers stay around
   [opt.cursorline     = true  -- Highlight the current line
   [opt.equalalways    = false -- I don't like my windows changing all the time
   [opt.splitright     = true  -- Prefer windows splitting to the right
   [opt.splitbelow     = true  -- Prefer windows splitting to the bottom
   [opt.updatetime     = 1000  -- Make updates happen faster
   [opt.hlsearch       = true  -- I wouldn't use this without my DoNoHL function
   [opt.scrolloff      = 10    -- Make it so there are always ten lines below my cursor
   [
   [-- Tabs
   [opt.autoindent     = true
   [opt.cindent        = true
   [opt.wrap           = true
   [
   [opt.tabstop        = 4
   [opt.shiftwidth     = 4
   [opt.softtabstop    = 4
   [opt.expandtab      = true
   [
   [opt.breakindent    = true
   [opt.showbreak      = string.rep(' ', 3) -- Make it so that long lines wrap smartly
   [opt.linebreak      = true
   [
   [opt.foldmethod     = 'marker'
   [opt.foldlevel      = 0
   [opt.modelines      = 1
   [
   [opt.belloff        = 'all' -- Just turn the dang bell off
   [
   [opt.clipboard      = 'unnamedplus'
   [
   [opt.inccommand     = 'split'
   [opt.swapfile       = false -- Living on the edge
   [opt.shada          = { "!", "'1000", "<50", "s10", "h" }
   [
   ]]

cmd "colorscheme base16-onedark"
cmd "syntax enable"
cmd "syntax on"

-- Global mapping TODO worth move into its own file
-- nmap <leader>w :w!<cr>
vim.api.nvim_set_keymap("n", "<leader>w", ":w!<cr>", {})
vim.api.nvim_set_keymap("v", "Y", "+y", {noremap = true})


g.indentLine_enabled = 1
g.indentLine_char_list = {'▏'}
g.mapleader = ","

require("treesitter.lua")
require("mappings.lua")

-- highlights
cmd("hi LineNr guibg=NONE")
cmd("hi SignColumn guibg=NONE")
cmd("hi VertSplit guibg=NONE")
cmd("highlight DiffAdd guifg=#81A1C1 guibg = none")
cmd("highlight DiffChange guifg =#3A3E44 guibg = none")
cmd("highlight DiffModified guifg = #81A1C1 guibg = none")
cmd("hi EndOfBuffer guifg=#282c34")

cmd("highlight TelescopeBorder   guifg=#3e4451")
cmd("highlight TelescopePromptBorder   guifg=#3e4451")
cmd("highlight TelescopeResultsBorder  guifg=#3e4451")
cmd("highlight TelescopePreviewBorder  guifg=#525865")
cmd("highlight PmenuSel  guibg=#98c379")

-- tree folder name , icon color
cmd("highlight NvimTreeFolderIcon guifg = #61afef")
cmd("highlight NvimTreeFolderName guifg = #61afef")

require("nvim-autopairs").setup()

require("lspkind").init(
    {
        File = " "
    }
)
