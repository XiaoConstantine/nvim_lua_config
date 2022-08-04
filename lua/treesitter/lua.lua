require 'nvim-treesitter.install'.compilers = { "clang" }
local ts_config = require("nvim-treesitter.configs")

ts_config.setup {
    ensure_installed = {
        "python",
        "bash",
        "rust",
        "go",
        "lua",
        "zig",
    },
    highlight = {
        enable = true,
    },
    textobjects = {
      select = {
        enable = true,
        keymaps = {
          ["af"] = "@function.outer",
          ["if"] = "@function.inner",
          ["ac"] = "@class.outer",
          ["ic"] = "@class.inner",
        },
      },
    },
}
