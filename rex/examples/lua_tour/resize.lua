-- Config module: load with require("examples.lua_tour.resize") in init.lua.
-- Ctrl+b, then m enters this mode. Escape leaves it.
rex.mode("tour_resize", { exclusive = true })
rex.bind("ctrl+b>m", "client.mode.enter", { name = "tour_resize" })

local directions = { h = "left", j = "down", k = "up", l = "right" }
for key, direction in pairs(directions) do
  rex.bind("tour_resize/" .. key, "pane.resize", {
    direction = direction,
    amount = 5,
  })
  rex.bind("tour_resize/shift+" .. key, "pane.resize", {
    direction = direction,
    amount = 15,
  })
end
rex.bind("tour_resize/enter", "client.mode.exit")
