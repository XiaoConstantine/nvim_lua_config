-- Try this action without installing it:
-- rex do ~/.config/rex/examples/lua_tour/layout.lua --action lua_tour_layout dir="$PWD"
-- Add preview=true to print its layout without opening terminals.
-- For permanent use, add require("examples.lua_tour.layout") to init.lua.
rex.action{
  name = "lua_tour_layout",
  title = "Open Lua Lab",
  description = "Three shell panes in a chosen directory, built from nested splits.",
  category = "Learning",
  args = { dir = "string", preview = "boolean?", focus = "boolean?" },
  run = function(ctx, args)
    local function shell(label)
      return rex.layout.block{
        flavor = "com.superlogical.terminal.shell",
        label = label,
        options = { cwd = args.dir },
      }
    end

    -- The first ratio gives 60% to the left pane.
    -- The second gives 65% of the right column to its upper pane.
    local layout = rex.layout.horizontal(0.6,
      shell("Work"),
      rex.layout.vertical(0.65, shell("Commands"), shell("Scratch")))

    if args.preview then return { layout = layout } end

    local opened, err = rex.session.new_window{
      window_label = "Lua Lab",
      focus = args.focus ~= false,
      layout = layout,
    }
    if not opened then error(err, 0) end
    return opened
  end,
}
