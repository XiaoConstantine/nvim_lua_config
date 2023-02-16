local bind = require "mappings.bind"
local map_cr = bind.map_cr
local map_cu = bind.map_cu
local map_cmd = bind.map_cmd
local map_args = bind.map_args
require "mappings.config"

local plug_map = {
  ["n|<Leader>w"] = map_cr(":w!"):with_noremap():with_silent(),
  ["v|Y"] = map_cmd("+y"):with_noremap(),
  ["i|<TAB>"] = map_cmd("v:lua.tab_complete()"):with_expr():with_silent(),
  ["i|<S-TAB>"] = map_cmd("v:lua.s_tab_complete()"):with_silent():with_expr(),
  -- Packer
  ["n|<leader>pu"] = map_cr("PackerUpdate"):with_silent():with_noremap():with_nowait(),
  ["n|<leader>pi"] = map_cr("PackerInstall"):with_silent():with_noremap():with_nowait(),
  ["n|<leader>pc"] = map_cr("PackerCompile"):with_silent():with_noremap():with_nowait(),
  -- Lsp mapp work when insertenter and lsp start
  ["n|<leader>li"] = map_cr("LspInfo"):with_noremap():with_silent():with_nowait(),
  ["n|<leader>ll"] = map_cr("LspLog"):with_noremap():with_silent():with_nowait(),
  ["n|<leader>lr"] = map_cr("LspRestart"):with_noremap():with_silent():with_nowait(),
  ["n|<C-f>"] = map_cmd("<cmd>lua require('lspsaga.action').smart_scroll_with_saga(1)<CR>")
    :with_silent()
    :with_noremap()
    :with_nowait(),
  ["n|<C-b>"] = map_cmd("<cmd>lua require('lspsaga.action').smart_scroll_with_saga(-1)<CR>")
    :with_silent()
    :with_noremap()
    :with_nowait(),
  ["n|[e"] = map_cr("Lspsaga diagnostic_jump_next"):with_noremap():with_silent(),
  ["n|]e"] = map_cr("Lspsaga diagnostic_jump_prev"):with_noremap():with_silent(),
  ["n|K"] = map_cr("Lspsaga hover_doc"):with_noremap():with_silent(),
  ["n|ga"] = map_cr("Lspsaga code_action"):with_noremap():with_silent(),
  ["v|ga"] = map_cu("Lspsaga range_code_action"):with_noremap():with_silent(),
  ["n|gd"] = map_cr("Lspsaga preview_definition"):with_noremap():with_silent(),
  ["n|gD"] = map_cmd("<cmd>lua vim.lsp.buf.implementation()<CR>"):with_noremap():with_silent(),
  ["n|gs"] = map_cr("Lspsaga signature_help"):with_noremap():with_silent(),
  ["n|gr"] = map_cr("Lspsaga rename"):with_noremap():with_silent(),
  ["n|gh"] = map_cr("Lspsaga lsp_finder"):with_noremap():with_silent(),
  ["n|gt"] = map_cmd("<cmd>lua vim.lsp.buf.type_definition()<CR>"):with_noremap():with_silent(),
  ["n|<Leader>cw"] = map_cmd("<cmd>lua vim.lsp.buf.workspace_symbol()<CR>"):with_noremap():with_silent(),
  ["n|<Leader>ce"] = map_cr("Lspsaga show_line_diagnostics"):with_noremap():with_silent(),
  ["n|<Leader>ct"] = map_args "Template",
  -- Plugin MarkdownPreview
  ["n|<Leader>om"] = map_cu("MarkdownPreview"):with_noremap():with_silent(),
  -- Plugin Telescope
  ["n|<Leader>fb"] = map_cu("Telescope buffers"):with_noremap():with_silent(),
  ["n|<Leader>ff"] = map_cu("Telescope file_browser"):with_noremap():with_silent(),
  ["n|<Leader>fo"] = map_cu("Telescope oldfiles"):with_noremap():with_silent(),
  ["n|<Leader>fg"] = map_cu("Telescope git_files"):with_noremap():with_silent(),
  ["n|<Leader>fs"] = map_cu("Telescope grep_string"):with_noremap():with_silent(),
  ["n|<Leader>fl"] = map_cu("Telescope loclist"):with_noremap():with_silent(),
  ["n|<Leader>fc"] = map_cu("Telescope git_commits"):with_noremap():with_silent(),
  ["n|<Leader>ft"] = map_cu("Telescope help_tags"):with_noremap():with_silent(),
  --[[
       [["n|<Leader>fs"]     = map_cu('Telescope gosource'):with_noremap():with_silent(),
       ]]
  -- Plugin vim-operator-surround
  ["n|sa"] = map_cmd("<Plug>(operator-surround-append)"):with_silent(),
  ["n|sd"] = map_cmd("<Plug>(operator-surround-delete)"):with_silent(),
  ["n|sr"] = map_cmd("<Plug>(operator-surround-replace)"):with_silent(),
  -- acceleratedjk
  ["n|j"] = map_cmd('v:lua.enhance_jk_move("j")'):with_silent():with_expr(),
  ["n|k"] = map_cmd('v:lua.enhance_jk_move("k")'):with_silent():with_expr(),
}

bind.nvim_load_mapping(plug_map)
