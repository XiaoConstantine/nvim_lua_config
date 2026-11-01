-- Rex configuration, ported from ~/.tmux.conf.
--
-- Apply changes with `rex config reload` (or ctrl+b Shift+r) and check them with
-- `rex config check`. `rex keymap` shows what loaded.
--
-- Left out because Rex already does it: mouse, scrollback (about 64 MiB per
-- pane), escape-time, base-index (tabs count from 1), 256 colors, passthrough,
-- hyperlinks, clipboard, extended-keys, and the S-Enter remap (Claude Code
-- turns on the kitty keyboard protocol, so Rex sends it CSI 13;2u itself).
--
-- No Rex equivalent: vi copy mode (Find… in the command palette searches the
-- scrollback) and the status bar.

local terminal = "com.superlogical.terminal"
local shell = "com.superlogical.terminal.shell"

-- Switch panes without the prefix (tmux: bind -n C-h/C-l select-pane).
-- Like in tmux, this shadows ctrl+h/ctrl+l in the shell and in nvim.
rex.bind("ctrl+h", "pane.focus", { direction = "left" })
rex.bind("ctrl+l", "pane.focus", { direction = "right" })

-- The tmux prefix, ctrl+b, with custom split and reload keys. Press ctrl+b twice to
-- send ctrl+b itself to the program in the pane.
rex.bind("ctrl+b>ctrl+b", "pane.send_key", { key = "ctrl+b" })
rex.bind("ctrl+b>shift+r", "client.config.reload")

-- Windows are tabs in Rex.
rex.bind("ctrl+b>c", "client.tab.new")
rex.bind("ctrl+b>n", "client.tab.next")
rex.bind("ctrl+b>p", "client.tab.previous")
rex.bind("ctrl+b>,", "client.tab.rename")
rex.bind("ctrl+b>shift+7", "client.tab.close") -- &
for i = 1, 9 do
  rex.bind("ctrl+b>" .. i, "client.tab.goto", { index = i })
end

-- Panes.
rex.bind("ctrl+b>r", "pane.split", { direction = "right" })
rex.bind("ctrl+b>b", "pane.split", { direction = "down" })
rex.bind("ctrl+b>left", "pane.focus", { direction = "left" })
rex.bind("ctrl+b>right", "pane.focus", { direction = "right" })
rex.bind("ctrl+b>up", "pane.focus", { direction = "up" })
rex.bind("ctrl+b>down", "pane.focus", { direction = "down" })
rex.bind("ctrl+b>o", "pane.focus_next")
rex.bind("ctrl+b>z", "pane.zoom")
rex.bind("ctrl+b>x", "pane.close")
rex.bind("ctrl+b>shift+1", "pane.move_to_new_tab") -- ! (break-pane)

-- Sessions.
rex.bind("ctrl+b>s", "session.switch")
rex.bind("ctrl+b>shift+4", "session.rename") -- $
rex.bind("ctrl+b>shift+9", "session.previous") -- (
rex.bind("ctrl+b>shift+0", "session.next") -- )

-- The dev session, from tmux's session-created hook and
-- ~/.tmux/scripts/dev-session.sh: Claude Code on the left, nvim on the right,
-- focus on Claude. Each program is typed into a shell, as send-keys did, so
-- quitting it leaves a shell in its pane.
local function focused_dir(block_id)
  if block_id ~= nil then
    local p = rex.block.call(terminal, "process", { block_id = block_id })
    if p ~= nil and p.foreground ~= nil and p.foreground.cwd ~= nil then
      return p.foreground.cwd
    end
  end
  return os.getenv("HOME")
end

rex.action{
  name        = "dev_session",
  title       = "New Dev Session (Claude + nvim)",
  description = "Opens a session with Claude Code beside nvim, in the focused pane's directory.",
  category    = "Sessions",
  keywords    = "claude code nvim neovim editor dev tmux",
  args        = { dir = "string?", show = "boolean?" },
  run         = function(ctx, args)
    local dir = args.dir or focused_dir(ctx.block_id)
    local function pane(command)
      return rex.layout.block{
        flavor  = shell,
        options = { cwd = dir, initial_input = command .. "\r" },
      }
    end

    local s, err = rex.call("session.create", {
      label = dir:match("([^/]+)/*$") or "dev",
      initial_windows = {
        { window_label = "dev", layout = rex.layout.horizontal(0.5, pane("claude"), pane("nvim")) },
      },
    })
    if err ~= nil then error(err, 0) end

    local claude = s.initial_windows[1].block_ids[1]
    rex.session.focus_block{ session_id = s.session_id, block_id = claude }
    if args.show ~= false then
      rex.client.queue("session.select", { session_id = s.session_id })
    end
    return { session_id = s.session_id, block_ids = s.initial_windows[1].block_ids }
  end,
}

rex.bind("ctrl+b>shift+d", "dev_session")

-- Session notebook (prefix N) and compact native Activity popover (prefix A).
require("notes_dashboard")
