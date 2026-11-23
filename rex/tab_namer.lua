-- Names each tab after the agent conversation in it, using the title the agent gives its
-- terminal: Claude Code's conversation topic, or Codex's task. init.lua starts it:
--   rex do --all ~/.config/rex/tab_namer.lua
-- It only touches tabs that still have Rex's default name ("Window 3ed7d2a9") or a name it
-- gave them itself, so a tab you or Puck rename keeps that name. A tab follows one agent:
-- the first whose title named it.
local dir = (debug.getinfo(1, "S").source or ""):match("^@?(.*/)") or (os.getenv("HOME") .. "/.config/rex/")
package.path = dir .. "?.lua;" .. package.path
local clip = require("puck.lib").clip

local T = "com.superlogical.terminal"
local AGENTS = { ["claude-code"] = true, claude = true, codex = true, pi = true }
local GENERIC = { ["claude code"] = true, claude = true, codex = true, pi = true, zsh = true, nvim = true }

local named = {}    -- window_id -> { label, block_id } this script set
local seen = {}     -- block_id -> the last title handled, to skip spinner frames cheaply
local attached = {}

local function attach(sid)
  if not attached[sid] then
    rex.call("session.attach", { session_id = sid })
    attached[sid] = true
  end
end

-- A tab name from a terminal title, or nil for titles that don't name a conversation.
local function label_of(title)
  if title == nil or title:find("^π") then return nil end                  -- pi: "π - repo"
  if title:find("^[%w._-]+@[%w._-]+:") or title:find("^~") or title:find("^/") then return nil end
  local t = title:gsub("^[^%w]+", "")          -- Claude's ✳ and the spinners
  t = t:gsub("%s+|%s+[^|]*$", "")               -- Codex's " | repo"
  t = t:gsub("%s+", " "):gsub("%s+$", "")
  if #t < 4 or GENERIC[t:lower()] then return nil end
  return clip(t, 40)
end

local function is_agent(sid, block_id)
  local st = rex.block.call(T, "program_status", { session_id = sid, block_id = block_id })
  for _, r in ipairs((st and st.records) or {}) do
    if AGENTS[r.effective_app or r.app or ""] then return true end
  end
  return false
end

local function name_tab(sid, block_id, title)
  if seen[block_id] == title then return end
  seen[block_id] = title
  local label = label_of(title)
  if label == nil then return end
  attach(sid)
  local d = rex.call("session.describe_block", { session_id = sid, block_id = block_id })
  local wid = d and d.block and d.block.window_id
  if wid == nil then return end
  local v = rex.call("session.view", { session_id = sid })
  local current
  for _, w in ipairs((v and v.windows) or {}) do
    if w.window_id == wid then current = w.label end
  end
  local mine = named[wid]
  local default = current == nil or current == "" or current:find("^Window %x+$")
  if not default and not (mine and mine.label == current and mine.block_id == block_id) then return end
  if current == label or not is_agent(sid, block_id) then return end
  if rex.args.dry then print((current or "?") .. "  ->  " .. label) return end
  local _, err = rex.call("session.set_window_label", { session_id = sid, window_id = wid, label = label })
  if err then rex.log("warn", "tab_namer: " .. err) return end
  named[wid] = { label = label, block_id = block_id }
end

rex.on("terminal.title_changed", function(ctx, ev)
  name_tab(ctx.session_id, ctx.block_id, ev.title)
end)

rex.on("window_closed", function(ctx, ev)
  named[ev.window_id or ""] = nil
end)

rex.on("block_closed", function(ctx, ev)
  seen[ev.block_id or ""] = nil
end)

-- Catch up on the tabs that are already open. `dry=true` prints what it would rename, then stops.
for _, s in ipairs((rex.call("session.list", {}) or {}).sessions or {}) do
  attach(s.session_id)
  local v = rex.call("session.view", { session_id = s.session_id })
  for _, w in ipairs((v and v.windows) or {}) do
    for _, l in ipairs(w.layers or {}) do
      for _, b in ipairs(l.blocks or {}) do
        if b.creator_name == T then
          local t = rex.block.call(T, "title", { session_id = s.session_id, block_id = b.block_id })
          name_tab(s.session_id, b.block_id, t and t.title)
        end
      end
    end
  end
end

if rex.args.dry then rex.stop(0) end
