-- check if packer is installed (~/local/share/nvim/site/pack)
local packer_exists = pcall(vim.cmd, [[packadd packer.nvim]])

return require("packer").startup(
    function()
        use {"wbthomason/packer.nvim", opt = true}
        use {"kyazdani42/nvim-web-devicons"}
        use {"kyazdani42/nvim-tree.lua"}
        use {"nvim-lua/plenary.nvim"}
        use {"lewis6991/gitsigns.nvim"}
        use {"glepnir/galaxyline.nvim", 
            config = function() require'eviline' end,
            requires = {'kyazdani42/nvim-web-devicons', opt = true}
        }
        use {"akinsho/nvim-bufferline.lua"}
        use {"907th/vim-auto-save"}
        use {"nvim-treesitter/nvim-treesitter"}
        use {"chriskempson/base16-vim"}
        use {"norcalli/nvim-colorizer.lua"}
        use {"Yggdroot/indentLine"}
        use {"ryanoasis/vim-devicons"}
        use {"sbdchd/neoformat"}
        use {"neovim/nvim-lspconfig"}
        use {"hrsh7th/nvim-compe"}
        use {"windwp/nvim-autopairs"}
        use {"tweekmonster/startuptime.vim"}
        use {"onsails/lspkind-nvim"}
        use {"nvim-telescope/telescope.nvim"}
        use {'nvim-telescope/telescope-fzf-native.nvim', run = 'make' }
        use {"nvim-telescope/telescope-media-files.nvim"}
        use {"nvim-lua/popup.nvim"}
        use {"glepnir/lspsaga.nvim"}
        --[[
           [use {"pwntester/octo.nvim", requires = {
		   [    {'nvim-lua/popup.nvim'},
		   [    {'nvim-lua/plenary.nvim'},
		   [    {'nvim-telescope/telescope.nvim'}
           [}}
           ]]
        use {'nvim-lua/lsp_extensions.nvim'}
        -- plugins I use frequently
        use {"junegunn/fzf", run = "./install"}
        use {"junegunn/fzf.vim"}
        use {"mhinz/vim-startify"}
        use {"iamcco/markdown-preview.nvim", run = 'cd app & yarn install'}
        use { "scrooloose/nerdcommenter" }
    end
)
