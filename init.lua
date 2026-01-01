--[[

=====================================================================
==================== READ THIS BEFORE CONTINUING ====================
=====================================================================
========                                    .-----.          ========
========         .----------------------.   | === |          ========
========         |.-""""""""""""""""""-.|   |-----|          ========
========         ||                    ||   | === |          ========
========         ||   KICKSTART.NVIM   ||   |-----|          ========
========         ||                    ||   | === |          ========
========         ||                    ||   |-----|          ========
========         ||:Tutor              ||   |:::::|          ========
========         |'-..................-'|   |____o|          ========
========         `"")----------------(""`   ___________      ========
========        /::::::::::|  |::::::::::\  \ no mouse \     ========
========       /:::========|  |==hjkl==:::\  \ required \    ========
========      '""""""""""""'  '""""""""""""'  '""""""""""'   ========
========                                                     ========
=====================================================================
=====================================================================

What is Kickstart?

  Kickstart.nvim is *not* a distribution.

  Kickstart.nvim is a starting point for your own configuration.
    The goal is that you can read every line of code, top-to-bottom, understand
    what your configuration is doing, and modify it to suit your needs.

    Once you've done that, you can start exploring, configuring and tinkering to
    make Neovim your own! That might mean leaving kickstart just the way it is for a while
    or immediately breaking it into modular pieces. It's up to you!

    If you don't know anything about Lua, I recommend taking some time to read through
    a guide. One possible example which will only take 10-15 minutes:
      - https://learnxinyminutes.com/docs/lua/

    After understanding a bit more about Lua, you can use `:help lua-guide` as a
    reference for how Neovim integrates Lua.
    - :help lua-guide
    - (or HTML version): https://neovim.io/doc/user/lua-guide.html

Kickstart Guide:

  TODO: The very first thing you should do is to run the command `:Tutor` in Neovim.

    If you don't know what this means, type the following:
      - <escape key>
      - :
      - Tutor
      - <enter key>

    (If you already know how the Neovim basics, you can skip this step)

  Once you've completed that, you can continue working through **AND READING** the rest
  of the kickstart init.lua

  Next, run AND READ `:help`.
    This will open up a help window with some basic information
    about reading, navigating and searching the builtin help documentation.

    This should be the first place you go to look when you're stuck or confused
    with something. It's one of my favorite neovim features.

    MOST IMPORTANTLY, we provide a keymap "<space>sh" to [s]earch the [h]elp documentation,
    which is very useful when you're not sure exactly what you're looking for.

  I have left several `:help X` comments throughout the init.lua
    These are hints about where to find more information about the relevant settings,
    plugins or neovim features used in kickstart.

   NOTE: Look for lines like this

    Throughout the file. These are for you, the reader, to help understand what is happening.
    Feel free to delete them once you know what you're doing, but they should serve as a guide
    for when you are first encountering a few different constructs in your nvim config.

If you experience any errors while trying to install kickstart, run `:checkhealth` for more info

I hope you enjoy your Neovim journey,
- TJ

P.S. You can delete this when you're done too. It's your config now! :)
--]]

-- Set <space> as the leader key
-- See `:help mapleader`
--  NOTE: Must happen before plugins are loaded (otherwise wrong leader will be used)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Lazy-cached uv python path (computed on first use, not at startup)
local _cached_uv_python = nil
local function get_uv_python()
  if _cached_uv_python then
    return _cached_uv_python
  end
  -- Defer expensive system call until actually needed
  vim.schedule(function() end) -- yield to event loop
  if vim.fn.executable "uv" == 1 then
    local handle = io.popen "uv run which python 2>/dev/null"
    if handle then
      _cached_uv_python = handle:read "*l" or ""
      handle:close()
    end
  end
  if not _cached_uv_python or _cached_uv_python == "" then
    _cached_uv_python = vim.fn.exepath "python3" or vim.fn.exepath "python" or "python"
  end
  return _cached_uv_python
end

-- [[ Setting options ]]
-- See `:help vim.opt`
-- NOTE: You can change these options as you wish!
--  For more options, you can see `:help option-list`

-- Make line numbers default
vim.opt.number = true
-- Relative line numbers help with jump commands (5j, 12k, etc.)
vim.opt.relativenumber = true

-- Enable mouse mode, can be useful for resizing splits for example!
vim.opt.mouse = "a"

-- Don't show the mode, since it's already in status line
vim.opt.showmode = false

-- Sync clipboard between OS and Neovim.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.opt.clipboard = "unnamedplus"

-- Enable break indent
vim.opt.breakindent = true

-- Save undo history
vim.opt.undofile = true

-- Case-insensitive searching UNLESS \C or capital in search
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Keep signcolumn on by default
vim.opt.signcolumn = "yes"

-- Decrease update time
vim.opt.updatetime = 250
vim.opt.timeoutlen = 300

-- Configure how new splits should be opened
vim.opt.splitright = true
vim.opt.splitbelow = true

-- Sets how neovim will display certain whitespace in the editor.
--  See `:help 'list'`
--  and `:help 'listchars'`
vim.opt.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- Preview substitutions live, as you type!
vim.opt.inccommand = "split"

-- Show which line your cursor is on
vim.opt.cursorline = true

-- Minimal number of screen lines to keep above and below the cursor.
vim.opt.scrolloff = 10

-- Treesitter folding (disabled by default, enable with zi)
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldtext = ""
vim.opt.foldenable = false
vim.opt.foldlevel = 99
vim.opt.foldlevelstart = 99

-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`

-- Set highlight on search, but clear on pressing <Esc> in normal mode
vim.opt.hlsearch = true
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- Diagnostic keymaps (updated for Neovim 0.11+)
vim.keymap.set("n", "[d", function()
  vim.diagnostic.jump { count = -1 }
end, { desc = "Go to previous [D]iagnostic message" })
vim.keymap.set("n", "]d", function()
  vim.diagnostic.jump { count = 1 }
end, { desc = "Go to next [D]iagnostic message" })
-- Severity-filtered navigation (errors only)
vim.keymap.set("n", "[e", function()
  vim.diagnostic.jump { count = -1, severity = vim.diagnostic.severity.ERROR }
end, { desc = "Go to previous [E]rror" })
vim.keymap.set("n", "]e", function()
  vim.diagnostic.jump { count = 1, severity = vim.diagnostic.severity.ERROR }
end, { desc = "Go to next [E]rror" })
-- Severity-filtered navigation (warnings only)
vim.keymap.set("n", "[w", function()
  vim.diagnostic.jump { count = -1, severity = vim.diagnostic.severity.WARN }
end, { desc = "Go to previous [W]arning" })
vim.keymap.set("n", "]w", function()
  vim.diagnostic.jump { count = 1, severity = vim.diagnostic.severity.WARN }
end, { desc = "Go to next [W]arning" })
vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, { desc = "Show diagnostic [E]rror messages" })
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostic [Q]uickfix list" })

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- TIP: Disable arrow keys in normal mode
-- vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
-- vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
-- vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
-- vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
--
--  See `:help wincmd` for a list of all window commands
vim.keymap.set("n", "<C-h>", "<C-w><C-h>", { desc = "Move focus to the left window" })
vim.keymap.set("n", "<C-l>", "<C-w><C-l>", { desc = "Move focus to the right window" })
vim.keymap.set("n", "<C-j>", "<C-w><C-j>", { desc = "Move focus to the lower window" })
vim.keymap.set("n", "<C-k>", "<C-w><C-k>", { desc = "Move focus to the upper window" })

-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.highlight.on_yank()`
vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight when yanking (copying) text",
  group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- [[ Install `lazy.nvim` plugin manager ]]
--    See `:help lazy.nvim.txt` or https://github.com/folke/lazy.nvim for more info
local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system { "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath }
end ---@diagnostic disable-next-line: undefined-field
vim.opt.rtp:prepend(lazypath)

-- [[ Configure and install plugins ]]
--
--  To check the current status of your plugins, run
--    :Lazy
--
--  You can press `?` in this menu for help. Use `:q` to close the window
--
--  To update plugins, you can run
--    :Lazy update
--
-- NOTE: Here is where you install your plugins.
require("lazy").setup({
  -- NOTE: Plugins can be added with a link (or for a github repo: 'owner/repo' link).
  "tpope/vim-sleuth", -- Detect tabstop and shiftwidth automatically

  -- NOTE: Plugins can also be added by using a table,
  -- with the first argument being the link and the following
  -- keys can be used to configure plugin behavior/loading/etc.
  --
  -- Use `opts = {}` to force a plugin to be loaded.
  --
  --  This is equivalent to:
  --    require('Comment').setup({})

  -- "gc" to comment visual regions/lines
  { "numToStr/Comment.nvim", event = { "BufReadPre", "BufNewFile" }, opts = {} },
  -- Note: inlay-hints.nvim removed - Neovim 0.10+ has native inlay hints (toggle with <leader>th)

  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = { "markdown" },
    build = function()
      vim.fn["mkdp#util#install"]()
    end,
  },

  { -- Adds git related signs to the gutter, as well as utilities for managing changes
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      signs = {
        add = { text = "+" },
        change = { text = "~" },
        delete = { text = "_" },
        topdelete = { text = "‾" },
        changedelete = { text = "~" },
      },
      -- Enable line blame by default
      current_line_blame = true,
      -- Customize the blame line format
      current_line_blame_formatter = "<author>, <author_time:%Y-%m-%d> - <summary>",
      -- Show blame info with a slight delay (in milliseconds)
      current_line_blame_delay = 500,
      -- Add keymaps for git operations
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns

        -- Navigation between hunks
        vim.keymap.set("n", "]c", function()
          if vim.wo.diff then
            return "]c"
          end
          vim.schedule(function()
            gs.next_hunk()
          end)
          return "<Ignore>"
        end, { expr = true, buffer = bufnr, desc = "Next git hunk" })

        vim.keymap.set("n", "[c", function()
          if vim.wo.diff then
            return "[c"
          end
          vim.schedule(function()
            gs.prev_hunk()
          end)
          return "<Ignore>"
        end, { expr = true, buffer = bufnr, desc = "Previous git hunk" })

        -- Line blame
        vim.keymap.set(
          "n",
          "<leader>gb",
          gs.toggle_current_line_blame,
          { buffer = bufnr, desc = "Toggle git blame line" }
        )

        -- Full file blame
        vim.keymap.set("n", "<leader>gB", function()
          gs.blame_line { full = true }
        end, { buffer = bufnr, desc = "Show full git blame" })

        -- View line history
        vim.keymap.set("n", "<leader>gh", gs.preview_hunk, { buffer = bufnr, desc = "Preview git hunk" })

        -- View file history
        vim.keymap.set("n", "<leader>gH", function()
          vim.cmd "Gitsigns diffthis HEAD~1"
        end, { buffer = bufnr, desc = "View file history diff" })

        -- View line history in a new buffer
        -- vim.keymap.set("n", "<leader>gl", function()
        -- 	-- Open line history in Telescope
        -- 	require("telescope.builtin").git_bcommits_range()
        -- end, { buffer = bufnr, desc = "View line history" })

        -- Stage/unstage hunk
        vim.keymap.set("n", "<leader>gs", gs.stage_hunk, { buffer = bufnr, desc = "Stage hunk" })
        vim.keymap.set("n", "<leader>gr", gs.reset_hunk, { buffer = bufnr, desc = "Reset hunk" })
        vim.keymap.set("v", "<leader>gs", function()
          gs.stage_hunk { vim.fn.line ".", vim.fn.line "v" }
        end, { buffer = bufnr, desc = "Stage selected lines" })
        vim.keymap.set("v", "<leader>gr", function()
          gs.reset_hunk { vim.fn.line ".", vim.fn.line "v" }
        end, { buffer = bufnr, desc = "Reset selected lines" })
        -- View project history
        vim.keymap.set("n", "<leader>gp", function()
          -- Open project history in Telescope
          require("telescope.builtin").git_commits()
        end, { buffer = bufnr, desc = "View project history" })
      end,
    },
  },
  {
    "XiaoConstantine/mongoose.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    dir = vim.fn.stdpath "data" .. "/lazy/mongoose.nvim",
    event = "VeryLazy",
    config = function()
      require("mongoose").setup()
      require("mongoose").configure_llm {
        provider = "llamacpp",
      }

      -- Register the keybinding after the plugin is loaded
      vim.keymap.set("n", "<leader>ma", "<cmd>Mongoose<cr>", {
        silent = true,
        desc = "Show Mongoose Analytics",
      })
      -- Add keybinding for LLM analysis
      vim.keymap.set("n", "<leader>ml", "<cmd>MongooseLLMAnalyze<cr>", {
        silent = true,
        desc = "Analyze Vim usage with LLM",
      })
    end,
  },

  -- NOTE: Plugins can also be configured to run lua code when they are loaded.
  --
  -- This is often very useful to both group configuration, as well as handle
  -- lazy loading plugins that don't need to be loaded immediately at startup.
  --
  -- For example, in the following configuration, we use:
  --  event = 'VimEnter'
  --
  -- which loads which-key before all the UI elements are loaded. Events can be
  -- normal autocommands events (`:help autocmd-events`).
  --
  -- Then, because we use the `config` key, the configuration only runs
  -- after the plugin has been loaded:
  --  config = function() ... end

  { -- Useful plugin to show you pending keybinds.
    "folke/which-key.nvim",
    event = "VimEnter", -- Sets the loading event to 'VimEnter'
    config = function() -- This is the function that runs, AFTER loading
      require("which-key").setup()

      -- Document existing key chains (which-key v3 API)
      require("which-key").add {
        { "<leader>c", group = "[C]ode" },
        { "<leader>d", group = "[D]ebug" },
        { "<leader>g", group = "[G]it" },
        { "<leader>r", group = "[R]ename" },
        { "<leader>s", group = "[S]earch" },
        { "<leader>t", group = "[T]est" },
        { "<leader>w", group = "[W]orkspace" },
      }
    end,
  },

  -- NOTE: Plugins can specify dependencies.
  --
  -- The dependencies are proper plugin specifications as well - anything
  -- you do for a plugin at the top level, you can do for a dependency.
  --
  -- Use the `dependencies` key to specify the dependencies of a particular plugin

  { -- Fuzzy Finder (files, lsp, etc) - lazy-loaded on keys
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      { -- If encountering errors, see telescope-fzf-native README for install instructions
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
        cond = function()
          return vim.fn.executable "make" == 1
        end,
      },
      { "nvim-telescope/telescope-ui-select.nvim" },
      { "nvim-tree/nvim-web-devicons" },
    },
    cmd = "Telescope",
    keys = {
      {
        "<leader>sh",
        function()
          require("telescope.builtin").help_tags()
        end,
        desc = "[S]earch [H]elp",
      },
      {
        "<leader>sk",
        function()
          require("telescope.builtin").keymaps()
        end,
        desc = "[S]earch [K]eymaps",
      },
      {
        "<leader>sf",
        function()
          require("telescope.builtin").find_files()
        end,
        desc = "[S]earch [F]iles",
      },
      {
        "<leader>ss",
        function()
          require("telescope.builtin").builtin()
        end,
        desc = "[S]earch [S]elect Telescope",
      },
      {
        "<leader>sw",
        function()
          require("telescope.builtin").grep_string()
        end,
        desc = "[S]earch current [W]ord",
      },
      {
        "<leader>sg",
        function()
          require("telescope.builtin").live_grep()
        end,
        desc = "[S]earch by [G]rep",
      },
      {
        "<leader>sd",
        function()
          require("telescope.builtin").diagnostics()
        end,
        desc = "[S]earch [D]iagnostics",
      },
      {
        "<leader>sr",
        function()
          require("telescope.builtin").resume()
        end,
        desc = "[S]earch [R]esume",
      },
      {
        "<leader>s.",
        function()
          require("telescope.builtin").oldfiles()
        end,
        desc = "[S]earch Recent Files",
      },
      {
        "<leader><leader>",
        function()
          require("telescope.builtin").buffers()
        end,
        desc = "Find existing buffers",
      },
      {
        "<leader>sm",
        function()
          require("telescope.builtin").git_status()
        end,
        desc = "[S]earch [M]odified files",
      },
      {
        "<leader>/",
        function()
          require("telescope.builtin").current_buffer_fuzzy_find(
            require("telescope.themes").get_dropdown { winblend = 10, previewer = false }
          )
        end,
        desc = "[/] Fuzzily search in current buffer",
      },
      {
        "<leader>s/",
        function()
          require("telescope.builtin").live_grep { grep_open_files = true, prompt_title = "Live Grep in Open Files" }
        end,
        desc = "[S]earch [/] in Open Files",
      },
      {
        "<leader>sn",
        function()
          require("telescope.builtin").find_files { cwd = vim.fn.stdpath "config" }
        end,
        desc = "[S]earch [N]eovim files",
      },
    },
    config = function()
      require("telescope").setup {
        extensions = {
          ["ui-select"] = {
            require("telescope.themes").get_dropdown(),
          },
        },
      }
      pcall(require("telescope").load_extension, "fzf")
      pcall(require("telescope").load_extension, "ui-select")
    end,
  },

  { -- LSP Configuration & Plugins
    "neovim/nvim-lspconfig",
    dependencies = {
      -- Automatically install LSPs and related tools to stdpath for neovim
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "WhoIsSethDaniel/mason-tool-installer.nvim",

      -- Useful status updates for LSP.
      { "j-hui/fidget.nvim", opts = {} },
    },
    config = function()
      -- Neovim 0.11+ LspAttach: Configure buffer-local keymaps and settings
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("kickstart-lsp-attach", { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc)
            vim.keymap.set("n", keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
          end

          -- Navigation keymaps using Telescope for enhanced UI
          map("gd", require("telescope.builtin").lsp_definitions, "[G]oto [D]efinition")
          map("gr", require("telescope.builtin").lsp_references, "[G]oto [R]eferences")
          map("gI", require("telescope.builtin").lsp_implementations, "[G]oto [I]mplementation")
          map("<leader>D", require("telescope.builtin").lsp_type_definitions, "Type [D]efinition")
          map("<leader>ds", require("telescope.builtin").lsp_document_symbols, "[D]ocument [S]ymbols")
          map("<leader>ws", require("telescope.builtin").lsp_dynamic_workspace_symbols, "[W]orkspace [S]ymbols")

          -- LSP actions
          map("<leader>rn", vim.lsp.buf.rename, "[R]e[n]ame")
          map("<leader>ca", vim.lsp.buf.code_action, "[C]ode [A]ction")
          map("K", vim.lsp.buf.hover, "Hover Documentation")
          map("gD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")

          -- Document highlight on cursor hold (Neovim 0.11+ uses supports_method)
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
            local highlight_augroup = vim.api.nvim_create_augroup("kickstart-lsp-highlight", { clear = false })
            vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.document_highlight,
            })
            vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })
            vim.api.nvim_create_autocmd("LspDetach", {
              group = vim.api.nvim_create_augroup("kickstart-lsp-detach", { clear = true }),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds { group = "kickstart-lsp-highlight", buffer = event2.buf }
              end,
            })
          end

          -- Toggle inlay hints if supported (Neovim 0.10+ feature)
          if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
            map("<leader>th", function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
            end, "[T]oggle Inlay [H]ints")
          end
        end,
      })

      -- Extended capabilities for nvim-cmp
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      capabilities = vim.tbl_deep_extend("force", capabilities, require("cmp_nvim_lsp").default_capabilities())

      -- Neovim 0.11+ LSP configuration using vim.lsp.config()
      -- This is the new declarative way to configure LSP servers
      vim.lsp.config("gopls", {
        capabilities = capabilities,
        settings = {
          gopls = {
            hints = {
              assignVariableTypes = true,
              compositeLiteralFields = true,
              constantValues = true,
              functionTypeParameters = true,
              parameterNames = true,
              rangeVariableTypes = true,
            },
          },
        },
      })

      vim.lsp.config("pyright", {
        capabilities = capabilities,
        settings = {
          pyright = {
            disableOrganizeImports = true,
          },
          python = {
            analysis = {
              autoSearchPaths = true,
              useLibraryCodeForTypes = true,
            },
          },
        },
      })

      vim.lsp.config("ruff", {
        capabilities = capabilities,
        on_attach = function(client, bufnr)
          -- Disable hover in favor of Pyright
          client.server_capabilities.hoverProvider = false
        end,
      })

      vim.lsp.config("rust_analyzer", {
        capabilities = capabilities,
        settings = {
          ["rust-analyzer"] = {
            checkOnSave = {
              command = "clippy",
            },
          },
        },
      })

      vim.lsp.config("lua_ls", {
        capabilities = capabilities,
        settings = {
          Lua = {
            runtime = { version = "LuaJIT" },
            diagnostics = { globals = { "vim" } },
            workspace = {
              checkThirdParty = false,
              library = {
                "${3rd}/luv/library",
                unpack(vim.api.nvim_get_runtime_file("", true)),
              },
            },
            completion = { callSnippet = "Replace" },
            hint = { enable = true },
          },
        },
      })

      -- Enable configured LSP servers (Neovim 0.11+ API)
      vim.lsp.enable { "gopls", "pyright", "ruff", "rust_analyzer", "lua_ls" }

      -- Mason setup for installing LSP servers and tools
      require("mason").setup()

      local ensure_installed = {
        "gopls",
        "pyright",
        "ruff",
        "rust-analyzer",
        "lua-language-server",
        "stylua",
        "debugpy",
        "delve",
        "golangci-lint",
      }
      require("mason-tool-installer").setup { ensure_installed = ensure_installed }

      -- Mason-lspconfig is still useful for automatic installation triggers
      require("mason-lspconfig").setup()
    end,
  },

  { -- Autoformat
    "stevearc/conform.nvim",
    opts = {
      notify_on_error = false,
      format_on_save = {
        timeout_ms = 500,
        lsp_fallback = true,
      },
      formatters_by_ft = {
        lua = { "stylua" },
        -- Conform can also run multiple formatters sequentially
        -- python = { "isort", "black" },
        --
        -- You can use a sub-list to tell conform to run *until* a formatter
        -- is found.
        -- javascript = { { "prettierd", "prettier" } },
      },
    },
    keys = {
      {
        "<leader>cf",
        function()
          require("conform").format { async = true, lsp_fallback = true }
        end,
        desc = "[C]ode [F]ormat",
      },
    },
  },

  { -- Autocompletion
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      -- Snippet Engine & its associated nvim-cmp source
      {
        "L3MON4D3/LuaSnip",
        build = (function()
          -- Build Step is needed for regex support in snippets
          -- This step is not supported in many windows environments
          -- Remove the below condition to re-enable on windows
          if vim.fn.has "win32" == 1 or vim.fn.executable "make" == 0 then
            return
          end
          return "make install_jsregexp"
        end)(),
      },
      "saadparwaiz1/cmp_luasnip",

      -- Adds other completion capabilities.
      --  nvim-cmp does not ship with all sources by default. They are split
      --  into multiple repos for maintenance purposes.
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-buffer",

      -- If you want to add a bunch of pre-configured snippets,
      --    you can use this plugin to help you. It even has snippets
      --    for various frameworks/libraries/etc. but you will have to
      --    set up the ones that are useful for you.
      -- 'rafamadriz/friendly-snippets',
    },
    config = function()
      -- See `:help cmp`
      local cmp = require "cmp"
      local luasnip = require "luasnip"
      luasnip.config.setup {}

      cmp.setup {
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        completion = { completeopt = "menu,menuone,noinsert" },

        -- For an understanding of why these mappings were
        -- chosen, you will need to read `:help ins-completion`
        --
        -- No, but seriously. Please read `:help ins-completion`, it is really good!
        mapping = cmp.mapping.preset.insert {
          -- Select the [n]ext item
          ["<C-n>"] = cmp.mapping.select_next_item(),
          -- Select the [p]revious item
          ["<C-p>"] = cmp.mapping.select_prev_item(),

          -- Accept ([y]es) the completion.
          --  This will auto-import if your LSP supports it.
          --  This will expand snippets if the LSP sent a snippet.
          ["<C-y>"] = cmp.mapping.confirm { select = true },

          -- Manually trigger a completion from nvim-cmp.
          --  Generally you don't need this, because nvim-cmp will display
          --  completions whenever it has completion options available.
          ["<C-Space>"] = cmp.mapping.complete {},

          -- Think of <c-l> as moving to the right of your snippet expansion.
          --  So if you have a snippet that's like:
          --  function $name($args)
          --    $body
          --  end
          --
          -- <c-l> will move you to the right of each of the expansion locations.
          -- <c-h> is similar, except moving you backwards.
          ["<C-l>"] = cmp.mapping(function()
            if luasnip.expand_or_locally_jumpable() then
              luasnip.expand_or_jump()
            end
          end, { "i", "s" }),
          ["<C-h>"] = cmp.mapping(function()
            if luasnip.locally_jumpable(-1) then
              luasnip.jump(-1)
            end
          end, { "i", "s" }),
        },
        sources = {
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "path" },
          { name = "buffer", keyword_length = 3 },
        },
      }
    end,
  },

  { -- You can easily change to a different colorscheme.
    -- Change the name of the colorscheme plugin below, and then
    -- change the command in the config to whatever the name of that colorscheme is
    --
    -- If you want to see what colorschemes are already installed, you can use `:Telescope colorscheme`
    "folke/tokyonight.nvim",
    lazy = false, -- make sure we load this during startup if it is your main colorscheme
    priority = 1000, -- make sure to load this before all the other start plugins
    config = function()
      -- Load the colorscheme here
      vim.cmd.colorscheme "tokyonight-night"

      -- You can configure highlights by doing something like
      vim.cmd.hi "Comment gui=none"
    end,
  },

  -- Highlight todo, notes, etc in comments
  {
    "folke/todo-comments.nvim",
    event = "VimEnter",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = { signs = false },
  },

  -- mini.ai: Better Around/Inside textobjects (va), ci', etc.)
  {
    "echasnovski/mini.ai",
    event = { "BufReadPre", "BufNewFile" },
    opts = { n_lines = 500 },
  },

  -- mini.surround: Add/delete/replace surroundings (saiw), sd', sr)')
  {
    "echasnovski/mini.surround",
    event = { "BufReadPre", "BufNewFile" },
    opts = {},
  },

  -- mini.statusline: Simple statusline (loads immediately for UI)
  {
    "echasnovski/mini.statusline",
    lazy = false,
    priority = 999,
    config = function()
      local statusline = require "mini.statusline"
      statusline.setup()
      ---@diagnostic disable-next-line: duplicate-set-field
      statusline.section_location = function()
        return ""
      end
    end,
  },

  { -- Code outline viewer - provides a tree-like view of your code structure
    "stevearc/aerial.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-telescope/telescope.nvim",
    },
    config = function()
      require("aerial").setup {
        -- Aerial will automatically attach to buffers when you open them
        attach_mode = "global",

        -- When true, aerial will show guides from your cursor up to the aerial item
        guides = {
          mid_item = "├─",
          last_item = "└─",
          nested_top = "│ ",
          whitespace = "  ",
        },

        -- Set up custom keymaps inside the aerial window
        keymaps = {
          -- Jump to symbol under cursor
          ["<CR>"] = "actions.jump",
          -- Jump to symbol and close aerial
          ["<Space>"] = "actions.jump_and_close",
          -- Navigate to prev/next symbol
          ["p"] = "actions.prev",
          ["n"] = "actions.next",
          -- Close aerial
          ["q"] = "actions.close",
        },

        -- Options for the floating preview window
        float = {
          -- Show detailed symbol info in a floating window when you hover
          override = function(conf)
            conf.width = 50
            conf.height = 15
            return conf
          end,
        },

        -- Customize the layout of the aerial window
        layout = {
          -- Width of the aerial window
          max_width = 40,
          -- Minimum width of the aerial window
          min_width = 30,
          default_direction = "prefer_left",
          -- Default placement is on the right
          placement = "edge",
          -- When true, aerial window will close when selecting a symbol
          close_automatic_events = {},
        },

        -- Control icons and text displayed in the aerial window
        icons = {
          -- Use a custom icon set that matches your other UI elements
          Field = "󰄶 ",
          Function = "󰊕 ",
          Module = " ",
          Method = "󰆧 ",
          Class = " ",
          Constructor = " ",
          Enum = " ",
          Interface = " ",
          Struct = " ",
          Variable = " ",
        },
      }

      -- Set up keymaps for Aerial
      -- Toggle aerial window with <leader>a
      vim.keymap.set("n", "<leader>a", "<cmd>AerialToggle!<CR>", { desc = "Toggle code outline" })
      -- Jump to previous/next symbol
      vim.keymap.set("n", "[s", "<cmd>AerialPrev<CR>", { desc = "Previous symbol" })
      vim.keymap.set("n", "]s", "<cmd>AerialNext<CR>", { desc = "Next symbol" })

      -- Integrate with telescope for symbol searching
      require("telescope").load_extension "aerial"

      -- Document the new keymaps in which-key (v3 API)
      require("which-key").add {
        { "<leader>a", group = "Code [A]erial" },
        { "[s", desc = "Previous symbol" },
        { "]s", desc = "Next symbol" },
      }
    end,
    -- Only load aerial when you open a suitable file
    -- This makes your Neovim startup faster
    event = { "BufReadPost", "BufNewFile" },
  },
  {
    "stevearc/oil.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("oil").setup {
        -- Oil will take over directory buffers (e.g. `vim .` or `:e dir`)
        default_file_explorer = true,
        -- Keymaps in oil buffer. Can be any value that `vim.keymap.set` accepts OR a table of keymap
        -- options with a `callback` (e.g. { callback = function() ... end, desc = "", mode = "n" })
        keymaps = {
          ["g?"] = "actions.show_help",
          ["<CR>"] = "actions.select",
          ["<C-v>"] = "actions.select_vsplit",
          ["<C-s>"] = "actions.select_split",
          ["<C-t>"] = "actions.select_tab",
          ["<C-p>"] = "actions.preview",
          ["<C-c>"] = "actions.close",
          ["<C-r>"] = "actions.refresh",
          ["-"] = "actions.parent",
          ["_"] = "actions.open_cwd",
          ["`"] = "actions.cd",
          ["~"] = "actions.tcd",
          ["gs"] = "actions.change_sort",
          ["gx"] = "actions.open_external",
          ["g."] = "actions.toggle_hidden",
        },
        -- Set to false to disable all of the above keymaps
        use_default_keymaps = false,
        -- Configuration for the floating window in oil.open_float
        float = {
          -- Padding around the floating window
          padding = 2,
          max_width = 100,
          max_height = 40,
          border = "rounded",
          win_options = {
            winblend = 0,
          },
        },
        -- Configuration for the actions floating preview window
        preview = {
          -- Width dimensions can be integers or a float between 0 and 1 (e.g. 0.4 for 40%)
          -- min_width and max_width can be a single value or a list of mixed integer/float types.
          max_width = 0.9,
          -- min_width = {40, 0.4} means "the greater of 40 columns or 40% of total"
          min_width = { 40, 0.4 },
          -- optionally define an integer/float for the exact width of the preview window
          width = nil,
          -- Height dimensions can be integers or a float between 0 and 1 (e.g. 0.4 for 40%)
          -- min_height and max_height can be a single value or a list of mixed integer/float types.
          max_height = 0.9,
          -- min_height = {15, 0.1} means "the greater of 15 columns or 10% of total"
          min_height = { 15, 0.1 },
          -- optionally define an integer/float for the exact height of the preview window
          height = nil,
          border = "rounded",
          win_options = {
            winblend = 0,
          },
        },
        -- Configuration for the floating progress window
        progress = {
          max_width = 0.9,
          min_width = { 40, 0.4 },
          width = nil,
          max_height = { 10, 0.9 },
          min_height = { 5, 0.1 },
          height = nil,
          border = "rounded",
          minimized_border = "none",
          win_options = {
            winblend = 0,
          },
        },
        -- List of hidden file patterns. Oil will never show entries matching these patterns
        -- By default, oil hides gitignore'd files. Set `skip_confirm_for_simple_edits` to false to disable this
        hidden_patterns = { "^\\.git/$" },
        -- Set to true to skip the confirm step for simple operations (move, delete)
        skip_confirm_for_simple_edits = true,
        -- Don't show LSP and COC diagnostics in the oil buffer
        lsp_file_methods = {
          ["textDocument/codeAction"] = false,
          ["textDocument/hover"] = false,
          ["textDocument/definition"] = false,
          ["textDocument/declaration"] = false,
          ["textDocument/implementation"] = false,
          ["textDocument/references"] = false,
          ["textDocument/rename"] = false,
        },
        view_options = {
          -- Show files and directories that start with "."
          show_hidden = true,
          -- This function defines what is considered a "hidden" file
          is_hidden_file = function(name, bufnr)
            return vim.startswith(name, ".")
          end,
          -- This function defines what will never be shown, even when `show_hidden` is set
          is_always_hidden = function(name, bufnr)
            return false
          end,
          sort = {
            -- sort order can be "asc" or "desc"
            -- see :help oil-columns to see which columns are sortable
            order = "asc",
            -- sort by "name", "mtime" (modification time), "size", "type"
            fn = "name",
          },
        },
      }

      -- Set up the - keymap to open oil
      vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })
    end,
  },
  { -- Highlight, edit, and navigate code
    "nvim-treesitter/nvim-treesitter",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter-textobjects",
    },
    build = ":TSUpdate",
    main = "nvim-treesitter.configs",
    config = function()
      -- [[ Configure Treesitter ]] See `:help nvim-treesitter`

      ---@diagnostic disable-next-line: missing-fields
      require("nvim-treesitter.configs").setup {
        ensure_installed = { "bash", "c", "html", "lua", "markdown", "vim", "vimdoc", "python", "go", "rust" },
        -- Autoinstall languages that are not installed
        auto_install = true,
        highlight = { enable = true },
        indent = { enable = true },
        textobjects = {
          select = {
            enable = true,
            lookahead = true,
            keymaps = {
              -- You can use the capture groups defined in textobjects.scm
              ["af"] = "@function.outer",
              ["if"] = "@function.inner",
              ["ac"] = "@class.outer",
              ["ic"] = "@class.inner",
            },
          },
          -- You can also add move operations
          move = {
            enable = true,
            set_jumps = true, -- whether to set jumps in the jumplist
            goto_next_start = {
              ["]f"] = "@function.outer",
              ["]c"] = "@class.outer",
            },
            goto_next_end = {
              ["]F"] = "@function.outer",
              ["]C"] = "@class.outer",
            },
            goto_previous_start = {
              ["[f"] = "@function.outer",
              ["[c"] = "@class.outer",
            },
            goto_previous_end = {
              ["[F"] = "@function.outer",
              ["[C"] = "@class.outer",
            },
          },
        },
      }

      -- There are additional nvim-treesitter modules that you can use to interact
      -- with nvim-treesitter. You should go explore a few and see what interests you:
      --
      --    - Incremental selection: Included, see `:help nvim-treesitter-incremental-selection-mod`
      --    - Show your current context: https://github.com/nvim-treesitter/nvim-treesitter-context
      --    - Treesitter + textobjects: https://github.com/nvim-treesitter/nvim-treesitter-textobjects
    end,
  },

  -- Enhanced linting with uv ruff and golangci-lint
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local lint = require "lint"

      -- Configure linters
      lint.linters_by_ft = {
        python = { "ruff" },
        go = { "golangcilint" },
      }

      -- Use uv ruff if available
      if vim.fn.executable "uv" == 1 then
        lint.linters.ruff.cmd = "uv"
        lint.linters.ruff.args = { "run", "ruff", "check", "--output-format", "json", "-" }
      end

      -- Auto-lint on events (debounced, removed BufEnter to avoid excessive linting)
      vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave" }, {
        callback = function()
          -- Debounce lint calls
          local timer = vim.uv.new_timer()
          timer:start(
            100,
            0,
            vim.schedule_wrap(function()
              lint.try_lint()
              timer:close()
            end)
          )
        end,
      })

      -- Manual lint keybinding
      vim.keymap.set("n", "<leader>cl", "<cmd>lua require('lint').try_lint()<cr>", { desc = "Lint current buffer" })
    end,
  },

  -- Modern test runner (lazy-loaded on keymaps)
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "nvim-neotest/neotest-python",
      "fredrikaverpil/neotest-golang",
    },
    keys = {
      {
        "<leader>tt",
        function()
          require("neotest").run.run()
        end,
        desc = "Run nearest test",
      },
      {
        "<leader>tf",
        function()
          require("neotest").run.run(vim.fn.expand "%")
        end,
        desc = "Run test file",
      },
      {
        "<leader>td",
        function()
          require("neotest").run.run { strategy = "dap" }
        end,
        desc = "Debug nearest test",
      },
      {
        "<leader>ts",
        function()
          require("neotest").summary.toggle()
        end,
        desc = "Toggle test summary",
      },
      {
        "<leader>to",
        function()
          require("neotest").output.open { enter = true }
        end,
        desc = "Show test output",
      },
    },
    config = function()
      require("neotest").setup {
        adapters = {
          require "neotest-python" {
            dap = { justMyCode = false },
            runner = "pytest",
            python = get_uv_python,
          },
          require "neotest-golang" {
            go_test_args = { "-v", "-race", "-count=1", "-timeout=60s" },
            dap_go_enabled = true,
          },
        },
      }
    end,
  },

  -- Core debugging (lazy-loaded on keymaps)
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "theHamsta/nvim-dap-virtual-text",
      "nvim-neotest/nvim-nio",
      "williamboman/mason.nvim",
    },
    keys = {
      {
        "<leader>db",
        function()
          require("dap").toggle_breakpoint()
        end,
        desc = "Toggle breakpoint",
      },
      {
        "<leader>dc",
        function()
          require("dap").continue()
        end,
        desc = "Continue/Start debugging",
      },
      {
        "<leader>di",
        function()
          require("dap").step_into()
        end,
        desc = "Step into",
      },
      {
        "<leader>do",
        function()
          require("dap").step_over()
        end,
        desc = "Step over",
      },
      {
        "<leader>dO",
        function()
          require("dap").step_out()
        end,
        desc = "Step out",
      },
      {
        "<leader>dr",
        function()
          require("dap").repl.open()
        end,
        desc = "Open debug REPL",
      },
      {
        "<leader>dt",
        function()
          require("dapui").toggle()
        end,
        desc = "Toggle debug UI",
      },
    },
    config = function()
      local dap = require "dap"
      local dapui = require "dapui"

      dapui.setup()
      require("nvim-dap-virtual-text").setup()

      -- Auto-open/close UI
      dap.listeners.after.event_initialized["dapui_config"] = dapui.open
      dap.listeners.before.event_terminated["dapui_config"] = dapui.close
      dap.listeners.before.event_exited["dapui_config"] = dapui.close
    end,
  },

  -- Python debugging
  {
    "mfussenegger/nvim-dap-python",
    ft = "python",
    dependencies = { "mfussenegger/nvim-dap" },
    config = function()
      require("dap-python").setup(get_uv_python())

      -- Python-specific debug keybindings
      vim.keymap.set(
        "n",
        "<leader>dpt",
        "<cmd>lua require('dap-python').test_method()<cr>",
        { desc = "Debug test method" }
      )
      vim.keymap.set(
        "n",
        "<leader>dpc",
        "<cmd>lua require('dap-python').test_class()<cr>",
        { desc = "Debug test class" }
      )
    end,
  },

  -- Go debugging
  {
    "leoluz/nvim-dap-go",
    ft = "go",
    dependencies = { "mfussenegger/nvim-dap" },
    config = function()
      require("dap-go").setup()

      -- Go-specific debug keybindings
      vim.keymap.set("n", "<leader>dgt", "<cmd>lua require('dap-go').debug_test()<cr>", { desc = "Debug Go test" })
      vim.keymap.set(
        "n",
        "<leader>dgl",
        "<cmd>lua require('dap-go').debug_last_test()<cr>",
        { desc = "Debug last Go test" }
      )
    end,
  },

  -- The following two comments only work if you have downloaded the kickstart repo, not just copy pasted the
  -- init.lua. If you want these files, they are in the repository, so you can just download them and
  -- put them in the right spots if you want.

  -- NOTE: Next step on your Neovim journey: Add/Configure additional plugins for kickstart
  --
  --  Here are some example plugins that I've included in the kickstart repository.
  --  Uncomment any of the lines below to enable them (you will need to restart nvim).
  --
  -- require 'kickstart.plugins.debug',
  -- require 'kickstart.plugins.indent_line',

  -- NOTE: The import below can automatically add your own plugins, configuration, etc from `lua/custom/plugins/*.lua`
  --    This is the easiest way to modularize your config.
  --
  --  Uncomment the following line and add your plugins to `lua/custom/plugins/*.lua` to get going.
  --    For additional information, see `:help lazy.nvim-lazy.nvim-structuring-your-plugins`
  -- { import = 'custom.plugins' },
}, {
  -- Performance optimizations
  performance = {
    cache = {
      enabled = true,
    },
    rtp = {
      -- Disable unused built-in plugins
      disabled_plugins = {
        "gzip",
        "matchit",
        "matchparen",
        "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
  -- Check for plugin updates weekly
  checker = {
    enabled = false, -- Disable auto-check to avoid startup delay
  },
  -- Don't notify on config changes
  change_detection = {
    notify = false,
  },
})

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
