require("telescope").setup {
    defaults = { vimgrep_arguments = {
            "rg",
            "--color=never",
            "--no-heading", "--with-filename",
            "--line-number",
            "--column",
            "--smart-case"
        },
        prompt_position = "bottom",
        prompt_prefix = "> ",
        selection_caret = "> ",
        entry_prefix = "  ",
        initial_mode = "insert",
        selection_strategy = "reset",
        sorting_strategy = "descending",
        layout_strategy = "horizontal",
        layout_defaults = {
            horizontal = {
                mirror = false,
                preview_width = 0.5
            },
            vertical = {
                mirror = false
            }
        },
        file_sorter = require "telescope.sorters".get_fuzzy_file,
        file_ignore_patterns = {},
        generic_sorter = require "telescope.sorters".get_generic_fuzzy_sorter,
        shorten_path = true,
        winblend = 0,
        width = 0.75,
        preview_cutoff = 120,
        results_height = 1,
        results_width = 0.8,
        border = {},
        borderchars = {"─", "│", "─", "│", "╭", "╮", "╯", "╰"},
        color_devicons = true,
        use_less = true,
        set_env = {["COLORTERM"] = "truecolor"}, -- default = nil,
        file_previewer = require "telescope.previewers".vim_buffer_cat.new,
        grep_previewer = require "telescope.previewers".vim_buffer_vimgrep.new,
        qflist_previewer = require "telescope.previewers".vim_buffer_qflist.new,
        -- Developer configurations: Not meant for general override
        buffer_previewer_maker = require "telescope.previewers".buffer_previewer_maker
    },
    extensions = {
        media_files = {
            filetypes = {"png", "webp", "jpg", "jpeg"},
            find_cmd = "rg" -- find command (defaults to `fd`)
        }
    }
}

require("telescope").load_extension("media_files")
require('telescope').load_extension('octo')

local opt = {noremap = true, silent = true}
vim.g.mapleader = ","

-- mappings
vim.api.nvim_set_keymap("n", "<Leader>ff", [[<Cmd>lua require('telescope.builtin').find_files()<CR>]], opt)
vim.api.nvim_set_keymap(
    "n",
    "<Leader>fp",
    [[<Cmd>lua require('telescope').extensions.media_files.media_files()<CR>]],
    opt
)
vim.api.nvim_set_keymap("n", "<Leader>fb", [[<Cmd>lua require('telescope.builtin').buffers()<CR>]], opt)
vim.api.nvim_set_keymap("n", "<Leader>fh", [[<Cmd>lua require('telescope.builtin').help_tags()<CR>]], opt)
vim.api.nvim_set_keymap("n", "<Leader>fo", [[<Cmd>lua require('telescope.builtin').oldfiles()<CR>]], opt)
vim.api.nvim_set_keymap("n", "<C-a>", [[ <Cmd> %y+<CR>]], opt)


function _G.find_uc()
    require('telescope.builtin').find_files {
       prompt_title = "~ Compass ~",
       shorten_path = false,
       cwd = "~/development/urbancompass/",
       width = .25,
       layout_strategy = "horizontal",
       layout_config = {
           preview_width = 0.65
       },
    }
end


function _G.find_uc_sq()
    require('telescope.builtin').find_files {
       prompt_title = "~ Compass ~",
       shorten_path = false,
       cwd = "~/development/search-quality/",
       width = .25,
       layout_strategy = "horizontal",
       layout_config = {
           preview_width = 0.65
       },
    }
end

--[[
   [Specific command related to my daily work
   ]]
vim.api.nvim_set_keymap("n", "<leader>fc", [[<Cmd>lua find_uc()<CR>]], opt)
vim.api.nvim_set_keymap("n", "<leader>fq", [[<Cmd>lua find_uc_sq()<CR>]], opt)
