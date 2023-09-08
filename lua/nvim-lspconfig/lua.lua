vim.cmd [[packadd nvim-lspconfig]]
vim.cmd [[packadd nvim-compe]]
vim.cmd [[packadd nvim-cmp]]
vim.cmd [[packadd cmp-nvim-lsp]]

require("cmp").setup {
  sources = {
    { name = "nvim_lsp" },
  },
}

local function map(mode, lhs, rhs, opts)
  local options = { noremap = true }
  if opts then
    options = vim.tbl_extend("force", options, opts)
  end
  vim.api.nvim_set_keymap(mode, lhs, rhs, options)
end

local signature = require "lsp_signature"
local home = os.getenv "HOME"
local opts = { noremap = true, silent = true }
local lspconfig = require "lspconfig"

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.textDocument.completion.completionItem.snippetSupport = true
capabilities.textDocument.completion.completionItem.resolveSupport = {
  properties = {
    "documentation",
    "detail",
    "additionalTextEdits",
  },
}

local custom_attach = function(_)
  --[[
     [local filetype = vim.api.nvim_buf_get_option(0, "filetype")
     ]]

  -- mappings
  map("n", "gd", "<Cmd>lua vim.lsp.buf.definition()<CR>", opts)
  map("n", "gD", "<Cmd>lua vim.lsp.buf.declaration()<CR>", opts)
  map("n", "gr", "<cmd>lua vim.lsp.buf.references()<CR>", opts)
  --[[
       [map("n", "K", "<Cmd>lua vim.lsp.buf.hover()<CR>", opts)
       ]]
  map("n", "gi", "<cmd>lua vim.lsp.buf.implementation()<CR>", opts)
  map("n", "<C-k>", "<cmd>lua vim.lsp.buf.signature_help()<CR>", opts)
  map("n", "<space>wa", "<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>", opts)
  map("n", "<space>wr", "<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>", opts)
  map("n", "<space>wl", "<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>", opts)
  map("n", "<space>D", "<cmd>lua vim.lsp.buf.type_definition()<CR>", opts)
  map("n", "<space>e", "<cmd>lua vim.lsp.diagnostic.show_line_diagnostics()<CR>", opts)
  map("n", "[d", "<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>", opts)
  map("n", "]d", "<cmd>lua vim.lsp.diagnostic.goto_next()<CR>", opts)
  map("n", "<space>q", "<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>", opts)
  map("n", "<space>f", "<cmd>lua vim.lsp.buf.formatting_sync({}, 1000)<CR>", opts)
  vim.api.nvim_buf_set_option(0, "omnifunc", "v:lua.vim.lsp.omnifunc")
end

local cfg = {
  debug = false, -- set to true to enable debug logging
  log_path = "debug_log_file_path", -- debug log path
  verbose = false, -- show debug line number

  bind = true, -- This is mandatory, otherwise border config won't get registered.
  -- If you want to hook lspsaga or other signature handler, pls set to false
  doc_lines = 10, -- will show two lines of comment/doc(if there are more than two lines in doc, will be truncated);
  -- set to 0 if you DO NOT want any API comments be shown
  -- This setting only take effect in insert mode, it does not affect signature help in normal
  -- mode, 10 by default

  floating_window = true, -- show hint in a floating window, set to false for virtual text only mode

  floating_window_above_cur_line = true, -- try to place the floating above the current line when possible Note:
  -- will set to true when fully tested, set to false will use whichever side has more space
  -- this setting will be helpful if you do not want the PUM and floating win overlap
  fix_pos = false, -- set to true, the floating window will not auto-close until finish all parameters
  hint_enable = true, -- virtual hint enable
  hint_prefix = "",
  hint_scheme = "String",
  use_lspsaga = false, -- set to true if you want to use lspsaga popup
  hi_parameter = "LspSignatureActiveParameter", -- how your parameter will be highlight
  max_height = 12, -- max height of signature floating_window, if content is more than max_height, you can scroll down
  -- to view the hiding contents
  max_width = 120, -- max_width of signature floating_window, line will be wrapped if exceed max_width
  transpancy = 10, -- set this value if you want the floating windows to be transpant (100 fully transpant),
  -- nil to disable(default)
  handler_opts = {
    border = "single", -- double, single, shadow, none
  },

  always_trigger = false, -- sometime show signature on new line or in middle of parameter can be confusing,
  -- set it to false for #58

  auto_close_after = nil, -- autoclose signature float win after x sec, disabled if nil.
  extra_trigger_chars = {}, -- Array of extra characters that will trigger signature completion, e.g., {"(", ","}
  zindex = 200, -- by default it will be on top of all floating windows, set to <= 50 send it to bottom

  padding = "", -- character to pad on left and right of signature can be ' ', or '|'  etc

  shadow_blend = 36, -- if you using shadow as border use this set the opacity
  shadow_guibg = "Black", -- if you using shadow as border use this set the color e.g. 'Green' or '#121315'
  timer_interval = 200, -- default timer check interval set to lower value if you want to reduce latency
  toggle_key = nil, -- toggle signature on and off in insert mode,  e.g. toggle_key = '<M-x>'
}

--  lsp for python
lspconfig.pyright.setup { capabilities = capabilities, on_attach = custom_attach }

lspconfig.zls.setup {
  cmd = {
    home .. "/development/github.com/zls/zig-out/bin/zls",
  },
  on_attach = custom_attach,
  capabilities = capabilities,
  handlers = {
    ["textDocument/publishDiagnostics"] = vim.lsp.with(
      vim.lsp.diagnostic.on_publish_diagnostics,
      { virtual_text = false }
    ),
    ["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = "rounded" }),
    ["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = "rounded" }),
  },
  signature.setup(cfg),
}
-- lsp for go
local updated_capabilities = capabilities

local custom_init = function(client)
  client.config.flags = client.config.flags or {}
  client.config.flags.allow_incremental_sync = true
end

lspconfig.gopls.setup {
  on_init = custom_init,
  on_attach = custom_attach,
  capabilities = updated_capabilities,
  settings = {
    gopls = {
      codelenses = { test = true },
    },
  },
  signature.setup(cfg),
}

lspconfig.lua_ls.setup {
  cmd = {
    home .. "/development/lua-language-server/bin/lua-language-server",
    "-E",
    home .. "/development/lua-language-server/main.lua",
  },
  on_attach = custom_attach,
  capabilities = capabilities,
  settings = {
    Lua = {
      runtime = {
        -- Tell the language server which version of Lua you're using (LuaJIT in the case of Neovim)
        version = "LuaJIT",
      },
      diagnostics = {
        enable = true,
        -- Get the language server to recognize the `vim` global
        globals = { "vim" },
      },
      workspace = {
        -- Make the server aware of Neovim runtime files
        library = {
          [vim.fn.expand "$VIMRUNTIME/lua"] = true,
          [vim.fn.expand "$VIMRUNTIME/lua/vim/lsp"] = true,
        },
      },
    },
  },
  signature.setup(cfg),
}

-- neovim doesn't support the full 3.16 spec, but latest rust-analyzer requires the following capabilities.
-- Remove once implemented.
local rust_capabilities = vim.lsp.protocol.make_client_capabilities()
rust_capabilities.workspace.workspaceEdit = {
  normalizesLineEndings = true,
  changeAnnotationSupport = { groupsOnLabel = true },
}
rust_capabilities.textDocument.rename.prepareSupportDefaultBehavior = 1
-- lsp for rust
lspconfig.rust_analyzer.setup {
  cmd = { "rust-analyzer" },
  capabilities = rust_capabilities,
  on_attach = custom_attach,
}

local servers = { "dockerls", "bashls", "jsonls" }

for _, server in ipairs(servers) do
  lspconfig[server].setup { on_attach = custom_attach, capabilities = capabilities }
end

local DATA_PATH = home .. "/go/bin"
lspconfig.efm.setup {
  cmd = { DATA_PATH .. "/efm-langserver", "-logfile", home .. "/efm.log", "-loglevel", "5" },
  on_attach = custom_attach,
  capabilities = capabilities,
  init_options = { documentFormatting = true, codeAction = false },
  filetypes = { "python", "sh", "json", "yaml", "markdown", "rust" },
  settings = {
    rootMarkers = { ".git/" },
    languages = {
      python = {
        {
          LintCommand = "flake8 --max-line-length=100 "
            .. "--ignore=E111,E114,E121,E125,E129,E203,E402,E722,E741,F405,F601,F999,W503,TYP001 "
            .. "--stdin-display-name ${INPUT} -",
          lintStdin = true,
          lintFormats = { "%f:%l:%c: %m" },
        },
        { formatCommand = "black -l 100 -", formatStdin = true },
      },
    },
  },
}
