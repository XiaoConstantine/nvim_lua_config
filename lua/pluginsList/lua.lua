-- check if packer is installed (~/local/share/nvim/site/pack)
vim.cmd [[packadd packer.nvim]]

return require("packer").startup(function(use)
  use { "wbthomason/packer.nvim", opt = true }
  use { "kyazdani42/nvim-web-devicons" }
  use { "kyazdani42/nvim-tree.lua" }
  use { "nvim-lua/plenary.nvim" }
  use { "lewis6991/gitsigns.nvim" }
  --[[
           [use {"glepnir/galaxyline.nvim",
           [    branch = 'main',
           [    config = function() require'spaceline' end,
           [    requires = {'kyazdani42/nvim-web-devicons', opt = true}
           [}
           ]]
  use {
    "NTBBloodbath/galaxyline.nvim",
    -- your statusline
    config = function()
      require "galaxyline.themes.eviline"
    end,
    -- some optional icons
    requires = { "kyazdani42/nvim-web-devicons", opt = true },
  }
  use { "akinsho/nvim-bufferline.lua", tag = "v1.*" }
  use { "907th/vim-auto-save" }
  use { "nvim-treesitter/nvim-treesitter" }
  use { "chriskempson/base16-vim" }
  use { "norcalli/nvim-colorizer.lua" }
  use { "Yggdroot/indentLine" }
  use { "ryanoasis/vim-devicons" }
  use { "sbdchd/neoformat" }
  use { "neovim/nvim-lspconfig" }
  use { "hrsh7th/nvim-compe" }
  use { "windwp/nvim-autopairs" }
  use { "tweekmonster/startuptime.vim" }
  use { "onsails/lspkind-nvim" }
  use { "nvim-telescope/telescope.nvim" }
  use { "nvim-telescope/telescope-fzf-native.nvim", run = "make" }
  use { "nvim-telescope/telescope-media-files.nvim" }
  use { "nvim-lua/popup.nvim" }
  use {
    "phaazon/mind.nvim",
    branch = "v2.2",
    requires = { "nvim-lua/plenary.nvim" },
    config = function()
      require("mind").setup()
    end,
  }
  use {
    "glepnir/lspsaga.nvim",
    branch = "main",
    config = function()
      require("lspsaga").setup {}
    end,
    requires = {
      { "nvim-tree/nvim-web-devicons" },
      --Please make sure you install markdown and markdown_inline parser
      { "nvim-treesitter/nvim-treesitter" },
    },
  }
  --[[
           [use {"pwntester/octo.nvim", requires = {
		   [    {'nvim-lua/popup.nvim'},
		   [    {'nvim-lua/plenary.nvim'},
		   [    {'nvim-telescope/telescope.nvim'}
           [}}
           ]]
  use { "nvim-lua/lsp_extensions.nvim" }
  -- plugins I use frequently
  use { "junegunn/fzf", run = "./install" }
  use { "junegunn/fzf.vim" }
  use { "mhinz/vim-startify" }
  use { "iamcco/markdown-preview.nvim", run = "cd app & yarn install" }
  use { "scrooloose/nerdcommenter" }
  use { "hrsh7th/cmp-nvim-lsp", after = "nvim-lspconfig" }
  use { "hrsh7th/nvim-cmp", after = "nvim-lspconfig" }
  use { "nvim-telescope/telescope-file-browser.nvim" }
  use { "rhysd/accelerated-jk", opt = true }
  use { "bfredl/nvim-luadev" }
  use { "ray-x/lsp_signature.nvim" }
end)
