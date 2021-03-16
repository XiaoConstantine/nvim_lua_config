Nvim Lua config migration
---------------------
Lua only Neovim config WIP


Getting started
---------------

#### Require Neovim nightly before 0.5 release
[nvim-release](https://github.com/neovim/neovim/releases)

#### Require Packer
[packer.nvim](https://github.com/wbthomason/packer.nvim)

```bash
git clone https://github.com/wbthomason/packer.nvim\
 ~/.local/share/nvim/site/pack/packer/start/packer.nvim
```


LSP Setup
---------

Besides config under `nvim-lspconfig`, make sure you have corresponding
language server running:

```bash
# For python
npm install -g pyright

# For go
brew install gopls

# For rust
brew install rust-analyzer

# For dockerls
npm install -g dockerfile-language-server-nodejs

```

Goals
-----
* #### playing around with built-in LSP

  [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig)

  [nvim-compe](https://github.com/hrsh7th/nvim-compe)

* #### playing around telescope!

  [nvim-telescope](https://github.com/nvim-telescope/telescope.nvim)
