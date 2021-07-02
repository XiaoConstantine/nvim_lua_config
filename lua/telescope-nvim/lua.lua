require("telescope").setup {
    extensions = {
        media_files = {
            filetypes = {"png", "webp", "jpg", "jpeg"},
            find_cmd = "rg" -- find command (defaults to `fd`)
        },
        fzf = {
              fuzzy = true,
              override_generic_sorter = false, -- override the generic sorter
              override_file_sorter = true,     -- override the file sorter
        }
    }
}

require("telescope").load_extension("media_files")
--[[
   [require('telescope').load_extension('octo')
   ]]
require("telescope").load_extension("fzf")
