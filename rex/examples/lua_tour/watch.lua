-- Standalone event monitor; run with rex do, not require() in init.lua.
-- rex do ~/.config/rex/examples/lua_tour/watch.lua --for 1m
-- Add --all to listen across sessions. Ctrl+C stops the monitor.
local function observe(event_name)
  rex.on(event_name, function(ctx, event)
    local line, err = rex.json.encode{
      event = event_name,
      session = ctx.session_id,
      block = ctx.block_id,
      data = event,
    }
    if not line then error(err, 0) end
    print(line)
  end)
end

observe("window_created")
observe("window_closed")
observe("terminal.child_exited")
observe("terminal.program_status_changed")
print("Watching tab, process-exit, and reported program-status events.")
