-- Persistent session notes, plus Rex's compact native Activity popover.
local home = os.getenv("HOME")
local dir = home .. "/.config/rex/examples/notes_dashboard"
local python = "/opt/homebrew/bin/python3"
local shell = "com.superlogical.terminal.shell"
local notes_label = "Session notebook (Lua)"
local function check(value, err)
  if err ~= nil then error(err, 0) end
  return value
end

rex.action{
  name = "session_notebook",
  title = "Open Session Notebook",
  description = "Open this session's persistent Markdown notes in Neovim.",
  category = "Lua examples",
  run = function(ctx)
    local view = check(rex.session.view{})
    for _, window in ipairs(view.windows) do
      for _, layer in ipairs(window.layers) do
        for _, block in ipairs(layer.blocks) do
          if block.label == notes_label then
            local result = check(rex.session.focus_block{block_id = block.block_id})
            rex.client.queue("session.select", {session_id = ctx.session_id, window_id = window.window_id})
            return result
          end
        end
      end
    end
    -- Stable session ID: renaming a session does not lose its notebook.
    local path = home .. "/.local/share/rex/notes/" .. ctx.session_id:gsub(":", "-") .. ".md"
    local seed = check(rex.exec({python, dir .. "/demo.py", "seed-notes", path, view.label}))
    if not seed.ok then error(seed.stderr, 0) end
    local result = check(rex.session.new_window{
      window_label = "Notebook", focus = true,
      layout = rex.layout.block{
        flavor = shell, label = notes_label,
        options = {shell = "none", command = {
          "/opt/homebrew/bin/nvim", "-u", dir .. "/notebook.lua", "-n", path,
        }},
      },
    })
    rex.client.queue("session.select", {session_id = ctx.session_id, window_id = result.window_id})
    return result
  end,
}

rex.action{
  name = "agent_dashboard",
  title = "Toggle Agent Activity",
  description = "Expand or collapse Rex's native Activity list in the top bar.",
  category = "Lua examples",
  run = function()
    rex.client.queue("client.sidebar.activity.toggle")
  end,
}

rex.bind("ctrl+b>shift+n", "session_notebook")
rex.bind("ctrl+b>shift+a", "agent_dashboard")
