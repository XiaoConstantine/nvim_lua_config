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

Notes
-----

* pyright doesn't provide much code_actions. it only has
```bash
codeActionKinds = { "quickfix", "source.organizeImports" }

:lua print(vim.inspect(vim.lsp.buf_get_clients(0)[1].resolved_capabilities))
```

TroubleShooting
---------------
* Update treesitter

When there's issue with treesitter, I found manually update source control works most of time:
```bash
cd ~/.local/share/nvim/site/pack/packer/start/nvim-treesitter
git pull --rebase origin master

```
Then open vim and `PackerSync`

* Treesitter related parser issue
in vim:

```vim
TSUpdate

```



M1 Related
----------

* Use `arch -arm64 brew` instead of `brew` to get around wrong arch Rosseta 2 error
