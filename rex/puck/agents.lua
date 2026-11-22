-- agents.lua: see, organize, and steer every coding agent running in Rex.
-- Run through the `agents` wrapper next to this file, which passes its command
-- line in PUCK_ARGV (fields separated by \31), or with `rex do agents.lua cmd=status`.

local USAGE = [[
agents [status] [--all] [--tail N] [--json]   agents across sessions, needs-you first
agents peek ID [-n N]                          the last N lines of an agent's screen
agents go ID                                   show that agent in the Rex app
agents tell ID MESSAGE...                      type MESSAGE into the agent and press Enter

Conversations (every Claude Code, Codex, and pi thread, running or not):
agents threads [--days N] [--repo R] [--live|--ended] [--archived] [--long] [--json]
agents show THREAD [-n N] [--chars N]          title, links, and the last N turns
agents search TEXT... [--days N]               conversations that mention TEXT
agents name THREAD TITLE... [--tab]            give it a title (and its tab, if running)
agents topic TOPIC THREAD... [--clear]         group conversations under a topic
agents archive THREAD... [--close]             hide it; --close also ends its pane
agents unarchive THREAD...
agents resume THREAD [--session S] [--go]      reopen it in a new tab in Rex
agents tab ID LABEL...                         rename the tab an agent is in

Delegating (Puck starts agents and is told when they finish):
agents start [--agent claude|codex|pi] (--session S | --cwd DIR) [--label L] [--go] TASK...
                                               start an agent on TASK in a new tab
agents wait [TASK|ID...] [--any] [--all] [--timeout SECONDS]
                                               block until a delegated task (or a named agent)
                                               finishes or needs you; notify, then exit.
                                               --any watches every agent: blocked, errors, and
                                               turns that worked a minute or more (--long SECS)
agents tasks [--all]                           delegated tasks and their state
agents result TASK [-n N]                      what the task's agent said last

Surviving restarts:
agents snapshot                                record which conversation runs in which pane
agents watch [--every SECONDS]                 keep the snapshot fresh (default every 60 s)
agents restore [--dry-run] [--min-free PCT] [--only SESSION,...] [--from FILE]
                                               after a restart, reopen every agent in its pane,
                                               at most 3 devenv loads at once, pausing while
                                               free memory is under PCT (default 25)

ID: the 6-character pane id from `status`, a block id, a pane or tab label that
matches one agent, or a running thread's id. THREAD: a thread id from `threads`
(cl-, cx-, pi-), a full session id, or words from its title.]]

local dir = (debug.getinfo(1, "S").source or ""):match("^@?(.*/)") or (os.getenv("HOME") .. "/.config/rex/puck/")
package.path = dir .. "?.lua;" .. package.path
local P = require("lib")
local clip, ago = P.clip, P.ago

-- ------------------------------------------------------------------ arguments

local raw = {}
local env = os.getenv("PUCK_ARGV")
if env and env ~= "" then
  for field in (env .. "\31"):gmatch("([^\31]*)\31") do
    if field ~= "" then raw[#raw + 1] = field end
  end
elseif rex.args and rex.args.cmd then
  raw[1] = rex.args.cmd
end

local VALUED = { ["--long"] = 1, ["--agent"] = 1, ["--cwd"] = 1, ["--label"] = 1, ["--timeout"] = 1, ["--every"] = 1, ["--min-free"] = 1, ["--only"] = 1, ["--from"] = 1, ["--days"] = 1, ["--tail"] = 1, ["--repo"] = 1, ["--session"] = 1, ["-n"] = 1, ["--chars"] = 1 }
local pos, opt = {}, {}
do
  local i = 1
  while i <= #raw do
    local a = raw[i]
    if VALUED[a] then
      opt[a:gsub("^%-+", "")] = raw[i + 1]
      i = i + 2
    elseif a:sub(1, 2) == "--" and #a > 2 then
      opt[a:sub(3)] = true
      i = i + 1
    elseif a == "-h" then
      opt.help = true
      i = i + 1
    else
      pos[#pos + 1] = a
      i = i + 1
    end
  end
end
local function num(name, default) return tonumber(opt[name]) or default end
local cmd = table.remove(pos, 1) or "status"
if opt.help or cmd == "help" then print(USAGE) return end

local function fail(msg) error(msg, 0) end

local DEFAULT_TAB = "^Window %x%x%x%x%x%x%x%x$"

-- ------------------------------------------------------------------ helpers

local function find_thread(target, ts)
  local tl = target:lower()
  local tests = {
    function(t) return t.sid == tl or t.key == target or t.id == target end,
    function(t) return #tl >= 6 and t.id:gsub("-", ""):sub(-#tl:gsub("-", "")) == tl:gsub("-", "") end,
    function(t) return t.live and t.live.id == tl end,
    function(t) return (t.title or ""):lower():find(tl, 1, true) ~= nil end,
  }
  for _, test in ipairs(tests) do
    local hits = {}
    for _, t in ipairs(ts) do if test(t) then hits[#hits + 1] = t end end
    if #hits == 1 then return hits[1] end
    if #hits > 1 then
      local names = {}
      for i = 1, math.min(8, #hits) do names[#names + 1] = hits[i].sid .. " " .. clip(hits[i].title, 50) end
      fail(("%q matches %d conversations: %s"):format(target, #hits, table.concat(names, "; ")))
    end
  end
  fail(("no conversation matches %q (try --days 0, or `agents search`)"):format(target))
end

local function all_threads(live)
  return P.index({ days = 0, archived = true, live = live or P.collect() })
end

local function resolve(target)
  local agents, ps = P.collect()
  if target:match("^%a%a%-%x%x%x%x%x%x$") then
    local t = find_thread(target, all_threads(agents))
    if not t.live then fail(target .. " isn't running in any pane; use `agents resume " .. target .. "`") end
    target = t.live.block_id
  end
  local pool = #agents > 0 and agents or ps
  local tl = target:lower()
  local tests = {
    function(a) return a.block_id == target or a.block_id:sub(-#target) == target end,
    function(a) return a.pane:lower() == tl or a.tab:lower() == tl end,
    function(a) return (a.session .. "/" .. a.tab .. "/" .. a.pane):lower():find(tl, 1, true) ~= nil end,
  }
  for _, test in ipairs(tests) do
    local hits = {}
    for _, a in ipairs(pool) do if test(a) then hits[#hits + 1] = a end end
    if #hits == 1 then return hits[1] end
    if #hits > 1 then
      local names = {}
      for i = 1, math.min(8, #hits) do names[#names + 1] = hits[i].id .. " (" .. hits[i].session .. "/" .. hits[i].tab .. ")" end
      fail(("%q matches %d agents: %s"):format(target, #hits, table.concat(names, ", ")))
    end
  end
  fail(("no agent matches %q"):format(target))
end

local function place(a)
  local bits = { a.session }
  if not a.tab:match(DEFAULT_TAB) then bits[#bits + 1] = a.tab end
  if a.pane ~= "" and a.pane ~= "shell" and a.pane ~= a.tab then bits[#bits + 1] = a.pane end
  return table.concat(bits, " / ")
end

local function where(t)
  local l = t.live
  if not l then return "ended" end
  return ("%s %-7s %s%s"):format(l.id, l.state, place(l), l.how == "guess" and " (guess)" or "")
end

local function pad(s, n)
  s = clip(s, n)
  local len = 0
  for _ in s:gmatch("[^\128-\191]") do len = len + 1 end
  return s .. string.rep(" ", math.max(0, n - len))
end

local function print_thread(t, long)
  print(("%s  %4s  %s  %s%s"):format(t.sid, ago(t.updated), pad(where(t), 44), clip(t.title, 70),
    t.archived and " [archived]" or ""))
  if long then
    local repo = t.repo .. ((t.branch ~= "" and t.branch ~= "main" and t.branch ~= "master" and t.branch ~= "HEAD") and ("@" .. t.branch) or "")
    print("           repo: " .. repo)
    if t.last_prompt ~= "" and t.last_prompt ~= t.first_prompt then
      print("           last ask: " .. clip(t.last_prompt, 150))
    elseif t.first_prompt ~= "" then
      print("           ask: " .. clip(t.first_prompt, 150))
    end
    for _, u in ipairs(t.links or {}) do print("           " .. u) end
  end
  for _, d in ipairs(t.also_live or {}) do print("           also running in pane " .. d .. " (same conversation, two panes)") end
end

local function save_note(t, field, value)
  local reg = P.load_registry()
  reg[t.key] = reg[t.key] or {}
  reg[t.key][field] = value
  P.save_registry(reg)
end

-- ------------------------------------------------------------------ commands

local C = {}

function C.status()
  local agents = P.collect({ tail = num("tail", 0), working_tail = opt.all })
  local shown = {}
  for _, a in ipairs(agents) do if opt.all or not a.self then shown[#shown + 1] = a end end
  if opt.json then return shown end
  local counts, order = {}, {}
  for _, a in ipairs(shown) do
    if not counts[a.state] then order[#order + 1] = a.state end
    counts[a.state] = (counts[a.state] or 0) + 1
  end
  local parts = {}
  for _, s in ipairs(order) do parts[#parts + 1] = s .. ": " .. counts[s] end
  print(#parts > 0 and table.concat(parts, "  ") or "no agents")
  local last
  for _, a in ipairs(shown) do
    if a.state ~= last then print("\n== " .. a.state:upper() .. " =="); last = a.state end
    print(("%s %s  %-12s %6s  %s%s"):format(P.ICON[a.state] or "??", a.id, a.agent, a.age, place(a),
      a.repo ~= "" and ("  [" .. a.repo .. "]") or ""))
    if a.msg ~= "" then print("           " .. a.msg) end
    for _, l in ipairs(a.screen or {}) do print("           | " .. clip(l, 160)) end
  end
end

function C.peek()
  local x = resolve(pos[1] or fail("usage: agents peek ID [-n N]"))
  print(("# %s / %s / %s  [%s %s]"):format(x.session, x.tab, x.pane, x.agent or "?", x.state or ""))
  print(table.concat(P.screen(x.session_id, x.block_id, num("n", 40)), "\n"))
end

function C.go()
  local x = resolve(pos[1] or fail("usage: agents go ID"))
  P.go(x)
  print("showing " .. place(x))
end

function C.tell()
  local target = table.remove(pos, 1) or fail("usage: agents tell ID MESSAGE...")
  local msg = table.concat(pos, " ")
  if msg == "" then fail("usage: agents tell ID MESSAGE...") end
  local x = resolve(target)
  if x.block_id == (os.getenv("REX_BLOCK") or rex.block_id) then fail("refusing to type into my own pane") end
  P.tell(x, msg)
  print(("sent to %s (%s): %s"):format(place(x), x.id, clip(msg, 80)))
end

function C.threads()
  local days = num("days", 14)
  local ts = P.index({ days = days, archived = opt.archived, live = P.collect() })
  local out = {}
  for _, t in ipairs(ts) do
    local ok = true
    if opt.repo then
      local r = opt.repo:lower()
      ok = (t.repo:lower():find(r, 1, true) or (t.cwd or ""):lower():find(r, 1, true)) ~= nil
    end
    if opt.live and not t.live then ok = false end
    if opt.ended and t.live then ok = false end
    if ok then out[#out + 1] = t end
  end
  if opt.json then return out end
  local live = 0
  for _, t in ipairs(out) do if t.live then live = live + 1 end end
  print(("%d conversations in the last %s days (%d running in panes)"):format(#out, days > 0 and days or "all", live))
  local groups, names = {}, {}
  for _, t in ipairs(out) do
    local g = t.topic ~= "" and t.topic or ("repo: " .. (t.repo ~= "" and t.repo or "?"))
    if not groups[g] then groups[g] = {}; names[#names + 1] = g end
    table.insert(groups[g], t)
  end
  table.sort(names, function(a, b)
    local ra, rb = a:sub(1, 6) == "repo: ", b:sub(1, 6) == "repo: "
    if ra ~= rb then return rb end
    return groups[a][1].updated > groups[b][1].updated
  end)
  for _, g in ipairs(names) do
    print(("\n== %s (%d) =="):format(g, #groups[g]))
    for _, t in ipairs(groups[g]) do print_thread(t, opt.long) end
  end
end

function C.show()
  local t = find_thread(pos[1] or fail("usage: agents show THREAD"), all_threads())
  print("# " .. t.title)
  print(("%s  %s  updated %s ago  %s"):format(t.sid, t.agent, ago(t.updated), where(t)))
  print("repo: " .. (t.cwd or "") .. (t.branch ~= "" and (" @ " .. t.branch) or ""))
  if t.topic ~= "" then print("topic: " .. t.topic) end
  for _, u in ipairs(t.links or {}) do print("link: " .. u) end
  for _, d in ipairs(t.also_live or {}) do print("also running in pane " .. d) end
  print("transcript: " .. t.path)
  print("resume: " .. P.resume_command(t))
  if t.first_prompt ~= "" then print("\nfirst ask: " .. clip(t.first_prompt, 400)) end
  print("")
  local chars = num("chars", 2500)
  for _, turn in ipairs(P.transcript(t, num("n", 6))) do
    local txt = turn[2]:gsub("^%s+", ""):gsub("%s+$", "")
    if #txt > chars then txt = txt:sub(1, chars) .. (" … [%d more chars]"):format(#txt - chars) end
    print("--- " .. turn[1] .. "\n" .. txt .. "\n")
  end
end

function C.search()
  local q = table.concat(pos, " ")
  if q == "" then fail("usage: agents search TEXT...") end
  local hits = P.search(q, num("days", 30))
  if not next(hits) then print("no matches") return end
  local me = os.getenv("REX_BLOCK") or rex.block_id
  local out = {}
  for _, t in ipairs(all_threads()) do
    if hits[t.path] and not (t.live and t.live.block_id == me) then
      t.snippet = hits[t.path]
      out[#out + 1] = t
    end
  end
  if opt.json then return out end
  for _, t in ipairs(out) do
    print_thread(t)
    if t.snippet ~= "" then print("           … " .. t.snippet) end
  end
end

function C.name()
  local target = table.remove(pos, 1) or fail("usage: agents name THREAD TITLE...")
  local title = table.concat(pos, " ")
  if title == "" then fail("usage: agents name THREAD TITLE...") end
  local t = find_thread(target, all_threads())
  save_note(t, "title", title)
  print(('%s is now "%s"'):format(t.sid, title))
  if opt.tab and t.live then
    P.rename_tab(t.live.session_id, t.live.window_id, clip(title, 40))
    print("renamed its tab in " .. t.live.session)
  end
end

function C.topic()
  local topic = table.remove(pos, 1) or fail("usage: agents topic TOPIC THREAD...")
  if #pos == 0 then fail("usage: agents topic TOPIC THREAD...") end
  local ts = all_threads()
  local reg = P.load_registry()
  for _, target in ipairs(pos) do
    local t = find_thread(target, ts)
    reg[t.key] = reg[t.key] or {}
    reg[t.key].topic = (not opt.clear) and topic or nil
    print(("%s %s  %s"):format(t.sid, opt.clear and "cleared" or ("-> " .. topic), clip(t.title, 60)))
  end
  P.save_registry(reg)
end

local function archive(flag)
  if #pos == 0 then fail("usage: agents " .. (flag and "archive" or "unarchive") .. " THREAD...") end
  local ts = all_threads()
  local reg = P.load_registry()
  for _, target in ipairs(pos) do
    local t = find_thread(target, ts)
    reg[t.key] = reg[t.key] or {}
    reg[t.key].archived = flag
    local msg = flag and "archived" or "unarchived"
    if flag and opt.close and t.live then
      if t.live.state ~= "done" and t.live.state ~= "idle" then
        print(("%s: not closing its pane, it is %s"):format(t.sid, t.live.state))
      else
        P.close_block(t.live.session_id, t.live.block_id)
        msg = msg .. (", closed pane %s in %s"):format(t.live.id, t.live.session)
      end
    end
    print(("%s %s  %s"):format(t.sid, msg, clip(t.title, 60)))
  end
  P.save_registry(reg)
end
function C.archive() archive(true) end
function C.unarchive() archive(false) end

function C.resume()
  local agents = P.collect()
  local t = find_thread(pos[1] or fail("usage: agents resume THREAD [--session S] [--go]"), all_threads(agents))
  if t.live then
    print(("%s is already running in pane %s (%s)"):format(t.sid, t.live.id, t.live.session))
    if opt.go then P.go(t.live) end
    return
  end
  if t.cwd == "" or not P.exec({ "test", "-d", t.cwd }) then
    fail("its directory " .. (t.cwd ~= "" and t.cwd or "(unknown)") .. " no longer exists")
  end
  local sessions = (rex.call("session.list", {}) or {}).sessions or {}
  local sid
  if opt.session then
    for _, s in ipairs(sessions) do
      if s.session_id == opt.session or (s.label or ""):lower() == opt.session:lower() then sid = s.session_id end
    end
    if not sid then fail("no session named " .. opt.session) end
  else
    local score, best = {}, 0
    for _, a in ipairs(agents) do
      if a.cwd:gsub("/+$", "") == t.cwd:gsub("/+$", "") then
        score[a.session_id] = (score[a.session_id] or 0) + 1
        if score[a.session_id] > best then best, sid = score[a.session_id], a.session_id end
      end
    end
    if not sid and t.repo ~= "" then
      for _, s in ipairs(sessions) do
        if (s.label or ""):lower():find(t.repo:lower(), 1, true) then sid = s.session_id end
      end
    end
    if not sid then fail("no session works in that repo yet; pass --session NAME") end
  end
  local label = clip(t.title, 32)
  local w = P.open_tab(sid, label, t.cwd, 'eval "$(direnv export zsh 2>/dev/null)"; ' .. P.resume_command(t))
  save_note(t, "archived", false)
  local sname = sid
  for _, s in ipairs(sessions) do if s.session_id == sid then sname = s.label or sid end end
  print(('resumed %s in a new tab "%s" in %s (pane %s)'):format(t.sid, label, sname, w.block_ids[1]:sub(-6)))
  if opt.go then
    P.go({ session_id = sid, window_id = w.window_id, block_id = w.block_ids[1] })
  end
end

function C.tab()
  local target = table.remove(pos, 1) or fail("usage: agents tab ID LABEL...")
  local label = table.concat(pos, " ")
  if label == "" then fail("usage: agents tab ID LABEL...") end
  local x = resolve(target)
  P.rename_tab(x.session_id, x.window_id, label)
  print(('renamed tab in %s to "%s"'):format(x.session, label))
end

local FINAL = { done = true, error = true, failed = true, exited = true, closed = true }

local function task_place(t) return (t.session or "?") .. " / " .. (t.label or t.block_id:sub(-6)) end

function C.start()
  local task = table.concat(pos, " ")
  local usage = "usage: agents start [--agent claude|codex|pi] (--session S | --cwd DIR) [--label L] [--go] TASK..."
  if task == "" then fail(usage) end
  local agent = opt.agent or "claude"
  if agent ~= "claude" and agent ~= "codex" and agent ~= "pi" then fail("--agent must be claude, codex, or pi") end
  local min_free, free = num("min-free", 25), P.free_percent()
  if free < min_free then
    fail(("only %d%% of memory is free (need %d%%); close some agents first, or pass --min-free"):format(free, min_free))
  end
  local cwd = opt.cwd and tostring(opt.cwd):gsub("^~/", os.getenv("HOME") .. "/"):gsub("/+$", "")
  local agents = P.collect()
  local sessions = (rex.call("session.list", {}) or {}).sessions or {}
  local sid, sname
  if opt.session then
    for _, x in ipairs(sessions) do
      if x.session_id == opt.session or (x.label or ""):lower() == tostring(opt.session):lower() then sid, sname = x.session_id, x.label end
    end
    if not sid then fail("no session named " .. tostring(opt.session)) end
  end
  if sid and not cwd then
    -- The directory most agents in that session work in.
    local count, best = {}, 0
    for _, a in ipairs(agents) do
      if a.session_id == sid and a.cwd ~= "" then
        count[a.cwd] = (count[a.cwd] or 0) + 1
        if count[a.cwd] > best then best, cwd = count[a.cwd], a.cwd end
      end
    end
  end
  if cwd and not sid then
    local count, best = {}, 0
    for _, a in ipairs(agents) do
      if a.cwd:gsub("/+$", "") == cwd then
        count[a.session_id] = (count[a.session_id] or 0) + 1
        if count[a.session_id] > best then best, sid, sname = count[a.session_id], a.session_id, a.session end
      end
    end
    if not sid then fail("no session works in " .. cwd .. " yet; pass --session NAME") end
  end
  if not sid or not cwd then fail(usage) end
  if not P.exec({ "test", "-d", cwd }) then fail(cwd .. " is not a directory") end

  if agent == "claude" and not P.claude_trusts(cwd) then
    print(("note: Claude hasn't been trusted in %s yet, so it will first ask \"Do you trust this folder?\" in its pane"):format(cwd))
  end
  local id = P.new_task_id()
  local label = opt.label or clip(task, 28)
  local command = agent .. " " .. P.shell_quote(task)
  local w = P.open_tab(sid, label, cwd, 'eval "$(direnv export zsh 2>/dev/null)"; ' .. command)
  local tasks = P.load_tasks()
  tasks[id] = { id = id, agent = agent, task = task, label = label, cwd = cwd, session = sname, session_id = sid,
    window_id = w.window_id, block_id = w.block_ids[1], started_at = os.time(), since = os.time(), status = "running" }
  P.save_tasks(tasks)
  print(('started %s: %s in a new tab "%s" in %s (pane %s, %s)'):format(id, agent, label, sname, w.block_ids[1]:sub(-6), cwd))
  if opt.go then P.go({ session_id = sid, window_id = w.window_id, block_id = w.block_ids[1] }) end
  if opt.json then return tasks[id] end
end

-- Watch delegated tasks (and, with --any, every agent) until something happens
-- that Xiao should hear about, then notify, print it, and exit so Puck wakes.
--
-- Event-driven: Rex pushes terminal.program_status_changed whenever an agent's
-- state changes, so this costs nothing while idle and reacts at once. The
-- wrapper runs `wait` with `rex do --all` so events from every session arrive.
-- Timers cover what events can't: a new agent that never reports a status
-- (stuck on a startup prompt) and --timeout.
function C.wait()
  local tasks = P.load_tasks()
  local me = os.getenv("REX_BLOCK") or rex.block_id
  local LONG = num("long", 60)     -- with --any, a finished turn counts if it worked this long
  local SETTLE = 15                -- after the first event, collect more for this long
  local VERB = { done = "finished", blocked = "needs you", error = "hit an error", failed = "failed",
    exited = "exited", closed = "was closed" }

  local watch = {}        -- block_id -> tracked entry
  local places = {}       -- block_id -> pane info, for labels
  local function learn_panes()
    for _, p in ipairs(P.panes()) do places[p.block_id] = p end
  end
  learn_panes()

  local function track(t) watch[t.block_id] = watch[t.block_id] or t; return watch[t.block_id] end
  local function track_agent(block_id, agent)
    if block_id == me then return nil end
    if not watch[block_id] then
      local p = places[block_id]
      if not p then learn_panes(); p = places[block_id] end
      if not p then return nil end
      watch[block_id] = { id = p.id, agent = agent or "agent", block_id = block_id, session_id = p.session_id,
        session = p.session, label = place(p), started_at = os.time(), since = os.time(), ephemeral = true }
    end
    return watch[block_id]
  end

  -- What to watch.
  local delegated = 0
  for _, t in pairs(tasks) do
    if not FINAL[t.status] and (#pos == 0 or opt.any) then track(t); delegated = delegated + 1 end
  end
  for _, target in ipairs(pos) do
    if tasks[target] then track(tasks[target]); delegated = delegated + 1
    else
      local a = resolve(target)
      local t = track_agent(a.block_id, a.agent)
      if t then t.named = true end
    end
  end
  local open = 0
  for _ in pairs(watch) do open = open + 1 end
  if open == 0 and not opt.any then
    print("nothing to wait for: no delegated task is still running (use --any to watch every agent)") return
  end

  local batch, flushing = {}, false
  local function flush()
    local fresh = P.load_tasks()
    local lines = {}
    for _, b in ipairs(batch) do
      local t = b.t
      local line = ("%s %s %s%s"):format(t.agent, VERB[b.state] or b.state, task_place(t),
        b.msg and b.msg ~= "" and (" — " .. b.msg) or "")
      lines[#lines + 1] = line
      print(("%s  %s %s: %s"):format(os.date("%H:%M:%S"), t.id, b.state, line))
      if not t.ephemeral and fresh[t.id] then
        local f = fresh[t.id]
        f.status, f.since, f.last_event_at, f.last_msg = b.state, os.time(), os.time(), b.msg
        if FINAL[b.state] then f.finished_at = os.time() end
      end
    end
    P.save_tasks(fresh)
    if #batch == 1 then
      local b = batch[1]
      P.notify("Puck: " .. b.t.agent .. " " .. (VERB[b.state] or b.state),
        task_place(b.t) .. (b.msg and b.msg ~= "" and (" — " .. b.msg) or ""))
    else
      P.notify(("Puck: %d updates"):format(#batch), table.concat(lines, "; "))
    end
    batch, flushing = {}, false
    local remaining = 0
    for _, t in pairs(watch) do if not t.ephemeral and not t.final then remaining = remaining + 1 end end
    if opt.all and remaining > 0 then return end
    if opt.any then print("run `agents wait --any` again to keep watching")
    elseif remaining > 0 then print(("%d still running; run `agents wait` again to keep watching"):format(remaining)) end
    print("read results with `agents result TASK` (delegated) or `agents peek ID`")
    rex.stop(0)
  end
  local function report(t, state, msg)
    t.since, t.seen_working, t.working_since = os.time(), false, nil
    if FINAL[state] then t.final = true end
    batch[#batch + 1] = { t = t, state = state, msg = msg }
    if not flushing then flushing = true; rex.after(SETTLE, flush) end
  end

  -- Decide whether a status record is news.
  local function consider(t, r)
    if not r or t.final then return end
    t.has_status = true
    if r.state == "working" then
      t.seen_working = true
      t.working_since = t.working_since or P.iso_epoch(r.updated_at)
      return
    end
    if P.iso_epoch(r.updated_at) <= (t.since or 0) then return end
    if r.state == "blocked" or r.state == "error" or r.state == "failed" then
      report(t, r.state, r.msg)
    elseif r.state == "done" or (r.state == "idle" and t.seen_working) then
      local worked = t.working_since and (os.time() - t.working_since) or 0
      if not t.ephemeral or t.named or worked >= LONG then
        local msg = r.msg
        if t.ephemeral and worked > 0 then msg = (msg and msg ~= "" and (msg .. "; ") or "") .. "worked " .. ago(os.time() - worked) end
        report(t, "done", msg)
      else
        t.since, t.seen_working, t.working_since = os.time(), false, nil  -- a quick interactive turn
      end
    end
  end

  -- Catch up: delegated tasks that changed before this watch started.
  for _, t in pairs(watch) do
    if not t.ephemeral then
      local r, exists = P.pane_status(t.session_id, t.block_id)
      if not exists then report(t, "closed") else consider(t, r) end
    end
  end

  -- Events.
  rex.on("terminal.program_status_changed", function(ctx, ev)
    local r = ev.record or (ev.payload and ev.payload.record)
    local t = watch[ctx.block_id]
    if not t and opt.any and r then t = track_agent(ctx.block_id, r.effective_app or r.app) end
    if t then
      if r and (t.agent == "agent" or not t.agent) then t.agent = r.effective_app or r.app end
      consider(t, r)
    end
  end)
  rex.on("terminal.program_status_removed", function(ctx, ev)
    -- The agent's status went away: usually the agent exited back to the shell.
    local t = watch[ctx.block_id]
    if t and not t.ephemeral and not t.final then
      rex.after(2, function()
        if not t.final and P.foreground(t.session_id, t.block_id):match("sh$") then report(t, "exited") end
      end)
    end
  end)
  rex.on("block_closed", function(ctx, ev)
    local t = watch[ev.block_id or ""]
    if t and not t.final then
      if t.ephemeral then t.final = true else report(t, "closed") end
    end
  end)

  -- Timers for what events can't tell us.
  for _, t in pairs(watch) do
    if not t.ephemeral and not t.has_status then
      local wait_for = math.max(5, 45 - (os.time() - (t.started_at or 0)))
      rex.after(wait_for, function()
        if t.final or t.has_status then return end
        if P.foreground(t.session_id, t.block_id):match("sh$") then report(t, "exited") return end
        local screen = P.screen(t.session_id, t.block_id, 12)
        local ask = ""
        for _, l in ipairs(screen) do if l:find("?", 1, true) then ask = l; break end end
        report(t, "blocked", "stuck before starting: " .. clip(ask ~= "" and ask or (screen[1] or "no output"), 140))
      end)
    end
  end
  local timeout = num("timeout", 0)
  if timeout > 0 then
    rex.after(timeout, function()
      if #batch == 0 then print(("timed out after %ds; nothing new"):format(timeout)); rex.stop(0) end
    end)
  end

  local n = 0
  for _ in pairs(watch) do n = n + 1 end
  print(("watching %s%s (%s; event-driven)"):format(opt.any and "every agent" or (n .. " agents"),
    delegated > 0 and (", " .. delegated .. " delegated") or "",
    opt.any and "until any needs you or finishes a long run" or (opt.all and "until all finish" or "until one finishes or needs you")))
end

function C.tasks()
  local tasks = P.load_tasks()
  local list = {}
  for _, t in pairs(tasks) do
    if opt.all or not FINAL[t.status] or os.time() - (t.finished_at or 0) < 86400 then list[#list + 1] = t end
  end
  table.sort(list, function(a, b) return (a.started_at or 0) > (b.started_at or 0) end)
  if opt.json then return list end
  if #list == 0 then print("no delegated tasks") return end
  for _, t in ipairs(list) do
    print(("%s  %-8s %-6s %5s  pane %s  %s  %s"):format(t.id, t.status, t.agent, ago(t.started_at or 0),
      t.block_id:sub(-6), t.session or "?", clip(t.task, 70)))
    if t.last_msg and t.last_msg ~= "" then print("           " .. clip(t.last_msg, 120)) end
  end
end

function C.result()
  local id = pos[1] or fail("usage: agents result TASK [-n N]")
  local tasks = P.load_tasks()
  local t = tasks[id] or fail("no delegated task " .. id .. " (see `agents tasks`)")
  local th
  if not (t.thread_id or t.path) then
    for _, a in ipairs(P.collect()) do
      if a.block_id == t.block_id then
        local r = P.resolve_live({ a })[a.block_id]
        t.thread_id, t.path = r.id, r.path
        tasks[id] = t
        P.save_tasks(tasks)
      end
    end
  end
  if t.thread_id or t.path then th = P.thread_for(t.agent, t.thread_id, t.path) end
  print(("# %s  %s  %s  (%s)"):format(t.id, t.agent, task_place(t), t.status))
  print("task: " .. clip(t.task, 300))
  if not th then
    print("\ncan't find its conversation yet; the screen shows:")
    print(table.concat(P.screen(t.session_id, t.block_id, num("n", 6) * 6), "\n"))
    return
  end
  print("conversation: " .. th.path .. "\n")
  local chars = num("chars", 2500)
  for _, turn in ipairs(P.transcript(th, num("n", 4))) do
    local txt = turn[2]:gsub("^%s+", ""):gsub("%s+$", "")
    if #txt > chars then txt = txt:sub(1, chars) .. (" … [%d more chars]"):format(#txt - chars) end
    print("--- " .. turn[1] .. "\n" .. txt .. "\n")
  end
end

function C.snapshot()
  local snap = P.snapshot()
  if opt.json then return snap end
  print(("recorded %d agents to %s"):format(#snap.entries, P.SNAPSHOT))
end

function C.watch()
  local every = num("every", 60)
  local function tick()
    local ok, snap = pcall(P.snapshot)
    print(os.date("%H:%M:%S") .. "  " .. (ok and (#snap.entries .. " agents recorded") or ("snapshot failed: " .. tostring(snap))))
    collectgarbage("collect")
  end
  tick()
  rex.every(every, tick)
  print(("watching; snapshot every %ds to %s (Ctrl-C to stop)"):format(every, P.SNAPSHOT))
end

function C.restore()
  local snap, from = P.last_snapshot(opt.from)
  if not snap then fail("no snapshot from before the last Rex restart; pass --from FILE") end
  local min_free = num("min-free", 25)
  local only
  if opt.only then
    only = {}
    for name in tostring(opt.only):gmatch("[^,]+") do only[name:lower()] = true end
  end
  local me = os.getenv("REX_BLOCK") or rex.block_id
  local agents, ps = P.collect()
  local exists, busy = {}, {}
  for _, p in ipairs(ps) do exists[p.block_id] = p end
  for _, a in ipairs(agents) do busy[a.block_id] = true end

  local entries = {}
  for _, e in ipairs(snap.entries) do entries[#entries + 1] = e end
  table.sort(entries, function(a, b) return (a.updated or 0) > (b.updated or 0) end)  -- most recently used first

  local todo, skipped, seen = {}, {}, {}
  for _, e in ipairs(entries) do
    local k = e.agent .. ":" .. (e.thread_id or e.path or ("fresh:" .. e.block_id))
    local why
    if only and not only[(e.session or ""):lower()] then
      -- not asked for
    elseif seen[k] then why = "same conversation as pane " .. seen[k]
    elseif not exists[e.block_id] then why = "pane no longer exists"
    elseif e.block_id == me then why = "that's this pane"
    elseif busy[e.block_id] then why = "an agent is already running there"
    else
      local fg = P.foreground(e.session_id, e.block_id)
      if fg ~= "" and not fg:match("sh$") then why = "pane is busy running " .. fg end
    end
    if why then
      skipped[#skipped + 1] = { e = e, why = why }
    elseif not only or only[(e.session or ""):lower()] then
      seen[k] = e.id
      todo[#todo + 1] = e
    end
  end

  print(("snapshot from %s (%s), %d agents to restore, %d skipped"):format(
    os.date("%Y-%m-%d %H:%M", snap.taken_at or 0), from or P.SNAPSHOT, #todo, #skipped))
  for _, x in ipairs(skipped) do
    print(("  skip %s  %-8s %s: %s"):format(x.e.id, x.e.agent, x.e.session, x.why))
  end
  for i, e in ipairs(todo) do
    print(("  %2d. %s  %-7s %-24s %s"):format(i, e.id, e.agent, clip(e.session, 24), clip(e.resume, 70)))
  end
  if opt["dry-run"] then return end

  for i, e in ipairs(todo) do
    local waited = 0
    while P.devenv_running() >= 3 or P.free_percent() < min_free do
      if waited >= 180 then
        print(("\nstopped: free memory stayed under %d%% for 3 minutes (%d%% now). Not restored:"):format(min_free, P.free_percent()))
        for j = i, #todo do print(("  %s  %s  %s"):format(todo[j].id, todo[j].session, todo[j].resume)) end
        print("Close some agents, then run `agents restore` again; it skips the ones already running.")
        return
      end
      rex.sleep(3)
      waited = waited + 3
    end
    P.type_line(e.session_id, e.block_id, 'eval "$(direnv export zsh 2>/dev/null)"; ' .. e.resume)
    print(("%s  [%d/%d] %s %s in %s (free %d%%)"):format(os.date("%H:%M:%S"), i, #todo, e.agent, e.id, e.session, P.free_percent()))
    rex.sleep(4)
    collectgarbage("collect")
  end
  print("done")
end

local f = C[cmd] or fail("unknown command " .. cmd .. "\n\n" .. USAGE)
return f()
