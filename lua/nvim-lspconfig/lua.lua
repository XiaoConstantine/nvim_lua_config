vim.cmd [[packadd nvim-lspconfig]]
vim.cmd [[packadd nvim-compe]]

local function map(mode, lhs, rhs, opts)
    local options = {noremap = true}
    if opts then options = vim.tbl_extend("force", options, opts)
    end
    vim.api.nvim_set_keymap(mode, lhs, rhs, options)
end

local opts = {noremap = true, silent = true}
local lspconfig = require'lspconfig'

-- snippetSupport
local capabilities = vim.lsp.protocol.make_client_capabilities()
-- TODO no snippetSupport yet
--[[
   [capabilities.textDocument.completion.completionItem.snippetSupport = true
   ]]

local function preview_location_callback(_, _, result)
  if result == nil or vim.tbl_isempty(result) then
    return nil
  end
  vim.lsp.util.preview_location(result[1])
end

function PeekDefinition()
  local params = vim.lsp.util.make_position_params()
  return vim.lsp.buf_request(0, 'textDocument/definition', params, preview_location_callback)
end

local custom_attach = function(client)
    -- mappings
    map("n", "gd", "<Cmd>lua vim.lsp.buf.definition()<CR>", opts)
    map("n", "gD", "<Cmd>lua vim.lsp.buf.declaration()<CR>", opts)
    map("n", "gr", "<cmd>lua vim.lsp.buf.references()<CR>", opts)
    map("n", "K", "<Cmd>lua vim.lsp.buf.hover()<CR>", opts)
    map("n", "gi", "<cmd>lua vim.lsp.buf.implementation()<CR>", opts)
    map("n", "<C-k>", "<cmd>lua vim.lsp.buf.signature_help()<CR>", opts)
    map("n", "<space>wa", "<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>", opts)
    map("n", "<space>wr", "<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>", opts)
    map("n", "<space>wl", "<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>", opts)
    map("n", "<space>D", "<cmd>lua vim.lsp.buf.type_definition()<CR>", opts)
    map("n", "<space>rn", "<cmd>lua vim.lsp.buf.rename()<CR>", opts)
    map("n", "<space>e", "<cmd>lua vim.lsp.diagnostic.show_line_diagnostics()<CR>", opts)
    map("n", "[d", "<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>", opts)
    map("n", "]d", "<cmd>lua vim.lsp.diagnostic.goto_next()<CR>", opts)
    map("n", "<space>q", "<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>", opts)

    map("n", "la", "<Cmd>lua vim.lsp.buf.code_action()<CR>", opts)
    vim.api.nvim_buf_set_option(0, 'omnifunc', 'v:lua.vim.lsp.omnifunc')
end

--  lsp for python
lspconfig.pyright.setup {
  enable = true,
  capabilities = capabilities,
  on_attach = custom_attach,
  settings = {
    python = {

    },
    pyright = {
      -- temp disable warning
      stubPath = ""
    }
  }
}

-- lsp for go
lspconfig.gopls.setup {
  cmd = {"gopls","--remote=auto"},
  on_attach = custom_attach,
  capabilities = capabilities,
  init_options = {
    usePlaceholders=true,
    completeUnimported=true,
  }
}

-- lsp for lua
local home = os.getenv("HOME")
local system_name
if vim.fn.has("mac") == 1 then
  system_name = "macOS"
elseif vim.fn.has("unix") == 1 then
  system_name = "Linux"
elseif vim.fn.has('win32') == 1 then
  system_name = "Windows"
else
  print("Unsupported system for sumneko")
end

lspconfig.sumneko_lua.setup {
  cmd = { home .. "/development/lua-language-server/bin/"..system_name.."/lua-language-server", "-E", home .. "/development/lua-language-server/main.lua"};
  on_attach = custom_attach,
  capabilities = capabilities;
  settings = {
      Lua = {
          runtime = {
              -- Tell the language server which version of Lua you're using (LuaJIT in the case of Neovim)
              version = 'LuaJIT',
          },
          diagnostics = {
              enable = true,
              -- Get the language server to recognize the `vim` global
              globals = {'vim'},
          },
          workspace = {
              -- Make the server aware of Neovim runtime files
              library = {
                  [vim.fn.expand('$VIMRUNTIME/lua')] = true,
                  [vim.fn.expand('$VIMRUNTIME/lua/vim/lsp')] = true,
              },
          },
      },
  },
}

-- lsp for rust
lspconfig.rust_analyzer.setup {
  capabilities = capabilities,
  on_attach = custom_attach,
}

local servers = {
  'dockerls','bashls','rust_analyzer','pyright', 'jsonls'
}

for _, server in ipairs(servers) do
  lspconfig[server].setup {
    on_attach = custom_attach,
    capabilities = capabilities,
  }
end
