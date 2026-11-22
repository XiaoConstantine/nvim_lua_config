-- Puck's core: live agent state from Rex, plus every Claude Code, Codex, and pi
-- conversation read from the agents' own transcripts.
--
-- Runs in `rex do` scripts (see agents.lua). Puck's notes about conversations
-- (titles, topics, archive marks) live in ~/.local/state/puck/threads.json.
-- Agents' transcripts and databases are only ever read.

local M = {}
math.randomseed(os.time())

local T = "com.superlogical.terminal"
local SHELL = "com.superlogical.terminal.shell"
local HOME = os.getenv("HOME")
local STATE = (os.getenv("XDG_STATE_HOME") or (HOME .. "/.local/state")) .. "/puck"
local REGISTRY = STATE .. "/threads.json"
local PANES = STATE .. "/panes"
local CLAUDE_PROJECTS = HOME .. "/.claude/projects"
local CLAUDE_PIDS = HOME .. "/.claude/sessions"
local CODEX_DB = HOME .. "/.codex/state_5.sqlite"
local CODEX_INDEX = HOME .. "/.codex/session_index.jsonl"
local PI_SESSIONS = HOME .. "/.pi/agent/sessions"

M.RANK = { blocked = 0, error = 0, failed = 0, done = 1, idle = 2, working = 3 }
M.ICON = { blocked = "!!", error = "xx", failed = "xx", done = "ok", idle = "..", working = ">>" }
local PREFIX = { claude = "cl", codex = "cx", pi = "pi" }
M.AGENT_OF = { ["claude-code"] = "claude", claude = "claude", codex = "codex", pi = "pi" }

-- ------------------------------------------------------------------ utilities

local function exec(argv, opts)
  local r, err = rex.exec(argv, opts)
  if not r then return nil, err end
  if not r.ok then return nil, (r.stderr ~= "" and r.stderr or ("exit " .. tostring(r.code))) end
  return r.stdout
end
M.exec = exec

local function read_file(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

local function write_file(path, data)
  local tmp = path .. ".tmp"
  local f = assert(io.open(tmp, "wb"))
  f:write(data)
  f:close()
  assert(os.rename(tmp, path))
end

local function mkdir_p(dir) exec({ "mkdir", "-p", dir }) end

local function decode(s)
  if not s or s == "" then return nil end
  return rex.json.decode(s)
end

-- The last `n` bytes of a file, without the partial first line.
local function tail(path, n)
  local f = io.open(path, "rb")
  if not f then return "" end
  local size = f:seek("end")
  local start = math.max(0, size - n)
  f:seek("set", start)
  local s = f:read("*a") or ""
  f:close()
  if start > 0 then
    local nl = s:find("\n", 1, true)
    s = nl and s:sub(nl + 1) or ""
  end
  return s
end

local function head(path, n)
  local f = io.open(path, "rb")
  if not f then return "" end
  local s = f:read(n) or ""
  f:close()
  return s
end

-- Line iterator using plain find; Rex's Lua refuses patterns over multi-MB lines.
local function lines(s)
  local pos, n = 1, #s
  return function()
    while pos <= n do
      local e = s:find("\n", pos, true) or (n + 1)
      local l = s:sub(pos, e - 1)
      pos = e + 1
      if l ~= "" then return l end
    end
    return nil
  end
end

-- Position of the last newline in s[from..to], or 0 when there is none.
local function last_nl(s, from, to)
  local found, i = 0, from
  while true do
    local j = s:find("\n", i, true)
    if not j or j > to then return found end
    found, i = j, j + 1
  end
end

local function startswith(s, p) return s:sub(1, #p) == p end

-- Collapse whitespace and cut to n bytes without splitting a UTF-8 character.
function M.clip(s, n)
  n = n or 160
  -- Trim first: Rex's Lua refuses patterns over very long input.
  s = (s or ""):sub(1, n * 4 + 64):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
  if #s <= n then return s end
  local cut = n - 3
  while cut > 0 do
    local b = s:byte(cut + 1)
    if not b or b < 0x80 or b >= 0xC0 then break end
    cut = cut - 1
  end
  return s:sub(1, cut) .. "…"
end
local clip = M.clip

local UTC_OFFSET = os.time() - os.time(os.date("!*t"))

function M.iso_epoch(ts)
  if not ts then return 0 end
  local y, mo, d, h, mi, s = ts:match("^(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
  if not y then return 0 end
  local t = os.time({ year = y, month = mo, day = d, hour = h, min = mi, sec = s }) + UTC_OFFSET
  local sign, oh, om = ts:match("([+-])(%d%d):?(%d%d)$")
  if sign and not ts:find("Z$") then
    local off = tonumber(oh) * 3600 + tonumber(om) * 60
    t = t - (sign == "+" and off or -off)
  end
  return t
end

function M.ago(epoch)
  local s = os.time() - math.floor(epoch or 0)
  if s < 0 then s = 0 end
  if s < 60 then return s .. "s" end
  if s < 3600 then return math.floor(s / 60) .. "m" end
  if s < 86400 then return string.format("%dh%02dm", s / 3600, (s % 3600) / 60) end
  return math.floor(s / 86400) .. "d"
end

local function text_of(content)
  if type(content) == "string" then return content end
  local parts = {}
  for _, c in ipairs(content or {}) do
    if type(c) == "table" and (c.type == "text" or c.type == "input_text" or c.type == "output_text") and c.text then
      parts[#parts + 1] = c.text
    end
  end
  return table.concat(parts, "\n")
end

local NOISE = { "<command-", "<local-command", "<system-reminder", "<task-notification", "Caveat:", "[Request interrupted" }
local function noise(txt)
  local t = txt:gsub("^%s+", "")
  for _, p in ipairs(NOISE) do
    if startswith(t, p) then return true end
  end
  return false
end

-- Files under dir at the given depth, with modification times: { {path, mtime}, ... }.
local function list_files(dir, depth, days)
  local argv = { "find", dir, "-mindepth", tostring(depth), "-maxdepth", tostring(depth), "-name", "*.jsonl" }
  if days and days > 0 then
    argv[#argv + 1] = "-mtime"
    argv[#argv + 1] = "-" .. days
  end
  for _, a in ipairs({ "-exec", "stat", "-f", "%m %N", "{}", "+" }) do argv[#argv + 1] = a end
  local out = exec(argv) or ""
  local files = {}
  for l in lines(out) do
    local m, p = l:match("^(%d+) (.+)$")
    if m then files[#files + 1] = { path = p, mtime = tonumber(m) } end
  end
  return files
end

-- ------------------------------------------------------------------ registry

function M.load_registry()
  return decode(read_file(REGISTRY)) or {}
end

function M.save_registry(reg)
  mkdir_p(STATE)
  write_file(REGISTRY, rex.json.encode(reg, { indent = true }))
end

local function key(agent, id) return agent .. ":" .. id end

local function short(agent, id)
  local hex = id:gsub("-", "")
  return PREFIX[agent] .. "-" .. hex:sub(-6)
end

-- ------------------------------------------------------------------ live panes

-- A script sees only its own session until it attaches to others; every helper
-- that touches a pane calls this first.
local attached = {}
function M.attach(session_id)
  if session_id and not attached[session_id] then
    local a = rex.call("session.attach", { session_id = session_id })
    attached[session_id] = true
    return a
  end
end

-- Every terminal pane in every session, with its tab.
function M.panes()
  local out = {}
  local list = rex.call("session.list", {}) or { sessions = {} }
  for _, s in ipairs(list.sessions or {}) do
    local a = rex.call("session.attach", { session_id = s.session_id })
    attached[s.session_id] = true
    local v = a and a.view
    for ti, w in ipairs((v and v.windows) or {}) do
      for _, l in ipairs(w.layers or {}) do
        for _, b in ipairs(l.blocks or {}) do
          if b.creator_name == T then
            out[#out + 1] = {
              session = s.label or s.session_id:sub(-8), session_id = s.session_id,
              tab = w.label or ("tab " .. ti), tab_index = ti, window_id = w.window_id,
              pane = b.label or "", block_id = b.block_id, id = b.block_id:sub(-6),
            }
          end
        end
      end
    end
  end
  return out
end

local CHROME_CHARS = { "─", "━", "│", "┃", "┌", "┐", "└", "┘", "├", "┤", "┬", "┴", "┼", "╭", "╮", "╯", "╰",
  "═", "║", "╔", "╗", "╚", "╝", "▔", "▁", "▏", "▕", "·", "•", "⏵", "⏴", "↵", "❯", "›" }
local FOOTER_PREFIX = { "⏵⏵", "› Ask Codex", "← for agents", "GPT-", "gpt-", "pup: ", "~/", "Jump to bottom",
  "⏺ Compacted while idle" }
local FOOTER_HAS = { "new task? /clear", "disable recaps", "recaps in /config", "? for shortcuts", '"idleCompaction"' }

local function chrome(l)
  local s = l:gsub("[%s>]", "")
  for _, c in ipairs(CHROME_CHARS) do
    if s == "" then break end
    local i = s:find(c, 1, true)
    while i do
      s = s:sub(1, i - 1) .. s:sub(i + #c)
      i = s:find(c, 1, true)
    end
  end
  if s == "" then return true end
  local t = l:gsub("^%s+", "")
  for _, p in ipairs(FOOTER_PREFIX) do
    if startswith(t, p) then return true end
  end
  for _, p in ipairs(FOOTER_HAS) do
    if l:find(p, 1, true) then return true end
  end
  if t:find("^↑[%d%.]+[kMG]? ↓") or l:find("settings%.json%s*$") then return true end
  return false
end

function M.screen(session_id, block_id, n)
  M.attach(session_id)
  local r = rex.block.call(T, "format", { session_id = session_id, block_id = block_id, trim = true, unwrap = true })
  local out = {}
  for l in lines((r and r.content) or "") do
    l = l:gsub("%s+$", "")
    if l:find("%S") and not chrome(l) then out[#out + 1] = l end
  end
  local first = math.max(1, #out - n + 1)
  local res = {}
  for i = first, #out do res[#res + 1] = out[i] end
  return res
end

-- Panes running an agent that reports its status, needs-you first.
function M.collect(opts)
  opts = opts or {}
  local me = os.getenv("REX_BLOCK") or rex.block_id or ""
  local ps = M.panes()
  local agents = {}
  for _, p in ipairs(ps) do
    local st = rex.block.call(T, "program_status", { session_id = p.session_id, block_id = p.block_id })
    local recs = (st and st.records) or {}
    if #recs > 0 then
      local r = recs[1]
      for _, x in ipairs(recs) do
        if (M.RANK[x.state] or 9) < (M.RANK[r.state] or 9) then r = x end
      end
      local proc = rex.block.call(T, "process", { session_id = p.session_id, block_id = p.block_id }) or {}
      local cwd = (proc.foreground and proc.foreground.cwd) or ""
      local a = {}
      for k, v in pairs(p) do a[k] = v end
      a.cwd = cwd
      a.repo = cwd:gsub("/+$", ""):match("([^/]+)$") or ""
      a.agent = r.effective_app or r.app or (r.owner and r.owner.name) or "?"
      a.state = r.state or "?"
      a.msg = r.msg or ""
      a.updated_at = r.updated_at or ""
      a.updated = M.iso_epoch(r.updated_at)
      a.age = M.ago(a.updated)
      a.self = (p.block_id == me)
      a.pid = r.owner and r.owner.pid
      if opts.tail and opts.tail > 0 and (a.state ~= "working" or opts.working_tail) then
        a.screen = M.screen(p.session_id, p.block_id, opts.tail)
      end
      agents[#agents + 1] = a
    end
  end
  table.sort(agents, function(x, y)
    local rx, ry = M.RANK[x.state] or 9, M.RANK[y.state] or 9
    if rx ~= ry then return rx < ry end
    return x.updated > y.updated
  end)
  return agents, ps
end

-- ------------------------------------------------------------------ conversations

local function new_thread(agent, path, mtime)
  return { agent = agent, id = "", path = path, updated = mtime or 0, title = "", cwd = "", branch = "",
    first_prompt = "", last_prompt = "", links = {} }
end

local function claude_read(path, mtime)
  local t = new_thread("claude", path, mtime)
  t.id = path:match("([^/]+)%.jsonl$")
  local n = 0
  for l in lines(head(path, 512000)) do
    n = n + 1
    if n > 200 then break end
    if l:find('"type":"user"', 1, true) then
      local o = decode(l)
      if o and not o.isMeta and not o.isSidechain then
        if t.cwd == "" then t.cwd = o.cwd or "" end
        local txt = text_of(o.message and o.message.content)
        if txt ~= "" and not noise(txt) then
          t.first_prompt = clip(txt, 300)
          break
        end
      end
    end
  end
  local custom, links, seen = nil, {}, {}
  for l in lines(tail(path, 1500000)) do
    local h = l:sub(1, 60)
    if h:find('"type":"ai-title"', 1, true) then
      local o = decode(l); if o and o.aiTitle then t.title = o.aiTitle end
    elseif h:find('"type":"custom-title"', 1, true) then
      local o = decode(l); if o and o.customTitle then custom = o.customTitle end
    elseif h:find('"type":"last-prompt"', 1, true) then
      local o = decode(l); if o and o.lastPrompt then t.last_prompt = clip(o.lastPrompt, 300) end
    elseif h:find('"type":"pr-link"', 1, true) then
      local u = l:match('"prUrl":"([^"]+)"')
      if u and not seen[u] then seen[u] = true; links[#links + 1] = u end
    elseif #l < 400000 and l:find('"type":"user"', 1, true) then
      t.cwd = l:match('"cwd":"([^"]*)"') or t.cwd
      t.branch = l:match('"gitBranch":"([^"]*)"') or t.branch
    end
  end
  t.title = custom or (t.title ~= "" and t.title) or clip(t.first_prompt, 80)
  for i = math.max(1, #links - 2), #links do t.links[#t.links + 1] = links[i] end
  if t.first_prompt == "" and t.title == "" then return nil end
  return t
end

local function claude_threads(days)
  local out = {}
  for _, f in ipairs(list_files(CLAUDE_PROJECTS, 2, days)) do
    local t = claude_read(f.path, f.mtime)
    if t then out[#out + 1] = t end
    collectgarbage("collect")
  end
  return out
end

local codex_names
local function codex_threads(days, include_archived, only_id)
  if not io.open(CODEX_DB, "rb") then return {} end
  if not codex_names then
    codex_names = {}
    for l in lines(read_file(CODEX_INDEX) or "") do
      local o = decode(l)
      if o and o.id then codex_names[o.id] = o.thread_name end
    end
  end
  local where = { "thread_source = 'user'" }
  if only_id then
    where = { "id = '" .. only_id:gsub("[^%w-]", "") .. "'" }
  else
    if days and days > 0 then where[#where + 1] = "updated_at >= " .. (os.time() - days * 86400) end
    if not include_archived then where[#where + 1] = "archived = 0" end
  end
  local q = "select id, rollout_path, updated_at, cwd, title, name, git_branch, first_user_message, archived "
    .. "from threads where " .. table.concat(where, " and ")
  local out = {}
  for _, r in ipairs(decode(exec({ "sqlite3", "-readonly", "-json", CODEX_DB, q })) or {}) do
    local t = new_thread("codex", r.rollout_path, tonumber(r.updated_at) or 0)
    t.id = r.id
    t.title = clip(r.name or codex_names[r.id] or r.title or r.first_user_message or "", 80)
    t.cwd, t.branch = r.cwd or "", r.git_branch or ""
    t.first_prompt = clip(r.first_user_message, 300)
    t.codex_archived = (tonumber(r.archived) or 0) ~= 0
    out[#out + 1] = t
  end
  return out
end

local function pi_read(path, mtime)
  local t = new_thread("pi", path, mtime)
  local n = 0
  for l in lines(head(path, 512000)) do
    n = n + 1
    if n > 400 then break end
    local h = l:sub(1, 300)
    if h:find('"type":"session"', 1, true) and t.id == "" then
      local o = decode(l); if o then t.id, t.cwd = o.id or "", o.cwd or "" end
    elseif h:find('"type":"session_info"', 1, true) then
      local o = decode(l); if o and o.name then t.title = o.name end
    elseif h:find('"role":"user"', 1, true) then
      local o = decode(l)
      local txt = o and o.message and text_of(o.message.content) or ""
      if txt ~= "" then t.first_prompt = clip(txt, 300); break end
    end
  end
  for l in lines(tail(path, 800000)) do
    local h = l:sub(1, 300)
    if h:find('"type":"session_info"', 1, true) then
      local o = decode(l); if o and o.name then t.title = o.name end
    elseif h:find('"role":"user"', 1, true) then
      local o = decode(l)
      local txt = o and o.message and text_of(o.message.content) or ""
      if txt ~= "" then t.last_prompt = clip(txt, 300) end
    end
  end
  if t.id == "" then t.id = (path:match("_([^_/]+)%.jsonl$") or path) end
  if t.title == "" then t.title = clip(t.first_prompt, 80) end
  if t.first_prompt == "" then return nil end
  return t
end

local function pi_threads(days)
  local out = {}
  for _, f in ipairs(list_files(PI_SESSIONS, 2, days)) do
    local t = pi_read(f.path, f.mtime)
    if t then out[#out + 1] = t end
    collectgarbage("collect")
  end
  return out
end

-- One conversation outside the listing window, for a live pane.
local function stub(agent, id, path)
  if agent == "claude" and id then
    local found = exec({ "find", CLAUDE_PROJECTS, "-mindepth", "2", "-maxdepth", "2", "-name", id .. ".jsonl" }) or ""
    local p = found:match("[^\n]+")
    if p then return claude_read(p, tonumber((exec({ "stat", "-f", "%m", p }) or "0"):match("%d+"))) end
  elseif agent == "codex" and id then
    return codex_threads(0, true, id)[1]
  elseif agent == "pi" and path then
    local m = exec({ "stat", "-f", "%m", path })
    if m then return pi_read(path, tonumber(m:match("%d+"))) end
  end
  return nil
end

local function pane_map()
  local out = {}
  local found = exec({ "find", PANES, "-name", "*.json" }) or ""
  for p in lines(found) do
    local o = decode(read_file(p))
    if o and o.block_id then out[o.block_id] = o end
  end
  return out
end

function M.write_pane(rec)
  mkdir_p(PANES)
  write_file(PANES .. "/" .. rec.block_id:gsub("[^%w_.-]", "_") .. ".json", rex.json.encode(rec))
end

-- Which conversation each live agent pane runs, from exact sources only:
-- Claude's pid file, the command line (codex resume / pi --session), or the
-- pane record pi's extension writes. Returns { [block_id] = {agent, id, path, how} }.
function M.resolve_live(live)
  local pmap = pane_map()
  local argv_of, pids = {}, {}
  for _, a in ipairs(live) do
    if a.pid and M.AGENT_OF[a.agent] ~= "claude" then pids[#pids + 1] = tostring(a.pid) end
  end
  if #pids > 0 then
    for l in lines(exec({ "ps", "-o", "pid=,command=", "-p", table.concat(pids, ",") }) or "") do
      local pid, cmd = l:match("^%s*(%d+)%s+(.*)$")
      if pid then argv_of[tonumber(pid)] = cmd end
    end
  end
  local out = {}
  for _, a in ipairs(live) do
    local agent = M.AGENT_OF[a.agent] or a.agent
    local id, path, how
    if agent == "claude" and a.pid then
      local o = decode(read_file(CLAUDE_PIDS .. "/" .. a.pid .. ".json"))
      if o and o.sessionId then id, how = o.sessionId, "pid" end
    end
    local cmd = a.pid and argv_of[a.pid]
    if not id and cmd then
      local cid = cmd:match("codex.-%sresume%s+([%x%-]+)")
      if cid and #cid == 36 then id, how = cid, "argv" end
      local pth = cmd:match("%-%-session%s+'?([^']+%.jsonl)")
      if pth then path, how = pth, "argv" end
    end
    local rec = pmap[a.block_id]
    if not id and not path and rec and rec.agent == agent and (not rec.pid or rec.pid == a.pid) then
      id = (rec.session_id ~= "" and rec.session_id) or nil
      path = (rec.session_file ~= "" and rec.session_file) or nil
      how = rec.source or "hook"
    end
    out[a.block_id] = { agent = agent, id = id, path = path, how = how }
  end
  return out
end

-- Tie each live agent pane to its conversation.
local function link_live(threads, live)
  local by_key, by_path = {}, {}
  for _, t in ipairs(threads) do
    by_key[key(t.agent, t.id)] = t
    by_path[t.path] = t
  end
  local resolved = M.resolve_live(live)
  local claimed, unresolved = {}, {}

  local function attach(t, a, how)
    if t.live then
      t.also_live = t.also_live or {}
      t.also_live[#t.also_live + 1] = a.id .. " (" .. a.session .. ")"
      return
    end
    t.live = { id = a.id, block_id = a.block_id, session_id = a.session_id, window_id = a.window_id,
      session = a.session, tab = a.tab, pane = a.pane, state = a.state, msg = a.msg, age = a.age, how = how }
    claimed[key(t.agent, t.id)] = true
  end

  for _, a in ipairs(live) do
    local r = resolved[a.block_id]
    local agent, id, path, how = r.agent, r.id, r.path, r.how
    local t
    if path and by_path[path] then
      t = by_path[path]
    elseif id and by_key[key(agent, id)] then
      t = by_key[key(agent, id)]
    elseif id or path then
      t = stub(agent, id, path)
      if t then
        threads[#threads + 1] = t
        by_key[key(agent, t.id)], by_path[t.path] = t, t
      end
    end
    if t then attach(t, a, how) else unresolved[#unresolved + 1] = { agent = agent, a = a } end
  end

  -- Fallback: same directory, last written closest to the pane's last status.
  for _, u in ipairs(unresolved) do
    local a, best, gap = u.a, nil, 6 * 3600
    local cwd = (a.cwd or ""):gsub("/+$", "")
    for _, t in ipairs(threads) do
      if t.agent == u.agent and not claimed[key(t.agent, t.id)] and cwd ~= "" and (t.cwd or ""):gsub("/+$", "") == cwd then
        local g = math.abs(t.updated - (a.updated > 0 and a.updated or os.time()))
        if g < gap then best, gap = t, g end
      end
    end
    if best then attach(best, a, "guess") end
  end
  return threads
end

function M.index(opts)
  opts = opts or {}
  local days = opts.days == nil and 14 or opts.days
  local threads = {}
  for _, t in ipairs(claude_threads(days)) do threads[#threads + 1] = t end
  for _, t in ipairs(codex_threads(days, opts.archived)) do threads[#threads + 1] = t end
  for _, t in ipairs(pi_threads(days)) do threads[#threads + 1] = t end
  link_live(threads, opts.live or {})
  local reg = M.load_registry()
  local out = {}
  for _, t in ipairs(threads) do
    t.key = key(t.agent, t.id)
    t.sid = short(t.agent, t.id)
    t.repo = (t.cwd or ""):gsub("/+$", ""):match("([^/]+)$") or ""
    local note = reg[t.key] or {}
    t.title = note.title or t.title
    t.topic = note.topic or ""
    t.archived = note.archived == true or t.codex_archived == true
    if not t.archived or opts.archived or t.live then out[#out + 1] = t end
  end
  table.sort(out, function(x, y) return x.updated > y.updated end)
  return out
end

function M.resume_command(t)
  if t.agent == "claude" then return "claude --resume " .. t.id end
  if t.agent == "codex" then return "codex resume " .. t.id end
  return "pi --session '" .. t.path:gsub("'", "'\\''") .. "'"
end

-- The conversation's recent turns, oldest first: { {role, text}, ... }.
function M.transcript(t, n)
  local turns = {}
  local function add(role, txt)
    if role == "agent" and #turns > 0 and turns[#turns][1] == "agent" then
      turns[#turns][2] = turns[#turns][2] .. "\n" .. txt
    else
      turns[#turns + 1] = { role, txt }
    end
  end
  for l in lines(tail(t.path, 3000000)) do
    if #l < 2000000 then
      if t.agent == "claude" then
        local h = l:sub(1, 400)
        if h:find('"type":"user"', 1, true) or h:find('"type":"assistant"', 1, true) or l:find('"type":"assistant"', 1, true) then
          local o = decode(l)
          if o and (o.type == "user" or o.type == "assistant") and not o.isSidechain and not o.isMeta then
            local txt = text_of(o.message and o.message.content)
            if txt ~= "" and not noise(txt) then add(o.type == "user" and "you" or "agent", txt) end
          end
        end
      elseif t.agent == "codex" then
        if l:find('"type":"response_item"', 1, true) and l:find('"type":"message"', 1, true) then
          local o = decode(l)
          local p = o and o.payload or {}
          if p.role == "user" or p.role == "assistant" then
            local txt = text_of(p.content)
            local s = txt:gsub("^%s+", "")
            if txt ~= "" and not (startswith(s, "<environment_context") or startswith(s, "<user_instructions")
                or startswith(s, "# AGENTS.md") or startswith(s, "<permissions")) then
              add(p.role == "user" and "you" or "agent", txt)
            end
          end
        end
      else
        local h = l:sub(1, 300)
        if h:find('"role":"user"', 1, true) or h:find('"role":"assistant"', 1, true) then
          local o = decode(l)
          local m = o and o.message or {}
          local txt = text_of(m.content)
          if txt ~= "" then add(m.role == "user" and "you" or "agent", txt) end
        end
      end
    end
  end
  local out = {}
  for i = math.max(1, #turns - n + 1), #turns do out[#out + 1] = turns[i] end
  return out
end

-- Conversations that mention `query`, case-insensitively, with a snippet.
function M.search(query, days)
  local ql = query:lower()
  local files = {}
  for _, t in ipairs(claude_threads(days)) do files[#files + 1] = t end
  for _, t in ipairs(codex_threads(days, true)) do files[#files + 1] = t end
  for _, t in ipairs(pi_threads(days)) do files[#files + 1] = t end

  local function strings(v, acc)
    if type(v) == "string" then acc[#acc + 1] = v
    elseif type(v) == "table" then for _, x in pairs(v) do strings(x, acc) end end
    return acc
  end
  local function snippet_from(line)
    if #line > 400000 or line:sub(1, 200):find('"api-request', 1, true) then return nil end
    local o = decode(line)
    if not o then return nil end
    for _, s in ipairs(strings(o, {})) do
      local i = s:lower():find(ql, 1, true)
      if i then return clip(s:sub(math.max(1, i - 90), i + #query + 110), 200) end
    end
    return nil
  end
  local function scan(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local matched, tries, carry = false, 0, ""
    while tries < 20 do
      local chunk = f:read(2 * 1024 * 1024)
      if not chunk then break end
      local buf = carry .. chunk
      local low = buf:lower()
      local pos = low:find(ql, 1, true)
      while pos and tries < 20 do
        matched, tries = true, tries + 1
        local b = buf:find("\n", pos, true)
        if not b then break end
        local a = last_nl(buf, math.max(1, pos - 500000), pos) + 1
        local snip = snippet_from(buf:sub(a, b - 1))
        if snip then f:close(); return snip end
        pos = low:find(ql, b, true)
      end
      local nl = last_nl(buf, math.max(1, #buf - 1000000), #buf)
      carry = nl > 0 and buf:sub(nl + 1) or buf:sub(-#ql)
    end
    f:close()
    return matched and "" or nil
  end

  local hits = {}
  for _, t in ipairs(files) do
    local snip = scan(t.path)
    if snip then hits[t.path] = snip end
    collectgarbage("collect")
  end
  return hits
end

-- ------------------------------------------------------------------ snapshot & restore
--
-- A snapshot records, for every pane running an agent, how to bring that agent
-- back. `agents watch` refreshes it every minute. When the Rex server restarts
-- (a new instance_id), the previous snapshot is kept as snapshot-<time>.json
-- and `agents restore` replays the newest one from an earlier server.

M.SNAPSHOT = STATE .. "/snapshot.json"

local function server_instance()
  local st = rex.call("server.status", {}) or {}
  return st.instance_id or "", st.started_at or ""
end

function M.snapshot()
  mkdir_p(STATE)
  local instance, started = server_instance()
  local prev = decode(read_file(M.SNAPSHOT))
  if prev and prev.instance_id ~= instance and prev.entries and #prev.entries > 0 then
    -- The server restarted: keep what ran before it, for `restore`.
    os.rename(M.SNAPSHOT, STATE .. "/snapshot-" .. os.date("%Y%m%d-%H%M%S", prev.taken_at or os.time()) .. ".json")
    prev = nil
  end
  local live = M.collect()
  local resolved = M.resolve_live(live)
  local entries = {}
  for _, a in ipairs(live) do
    local r = resolved[a.block_id]
    local e = { block_id = a.block_id, id = a.id, session = a.session, session_id = a.session_id,
      window_id = a.window_id, tab = a.tab, pane = a.pane, cwd = a.cwd, agent = r.agent,
      thread_id = r.id, path = r.path, how = r.how, state = a.state, updated = a.updated }
    if r.agent == "claude" and r.id then e.resume = "claude --resume " .. r.id
    elseif r.agent == "codex" and r.id then e.resume = "codex resume " .. r.id
    elseif r.agent == "pi" and r.path then e.resume = "pi --session '" .. r.path:gsub("'", "'\\''") .. "'"
    else e.resume = r.agent end  -- no conversation yet: start it fresh
    if not a.self then entries[#entries + 1] = e end
  end
  local snap = { instance_id = instance, server_started = started, taken_at = os.time(), entries = entries }
  write_file(M.SNAPSHOT, rex.json.encode(snap, { indent = true }))
  return snap
end

-- The newest snapshot taken under an earlier server, or the file given.
function M.last_snapshot(from)
  if from then return decode(read_file(from)), from end
  local instance = server_instance()
  local found = exec({ "sh", "-c", "ls -t \"$0\"/snapshot*.json 2>/dev/null", STATE }) or ""
  for p in lines(found) do
    local s = decode(read_file(p))
    if s and s.instance_id ~= instance and s.entries and #s.entries > 0 then return s, p end
  end
  return nil
end

function M.free_percent()
  local out = exec({ "memory_pressure" }) or ""
  return tonumber(out:match("free percentage:%s*(%d+)")) or 100
end

function M.devenv_running()
  local out = exec({ "pgrep", "-f", "devenv direnv-export" }) or ""
  local n = 0
  for _ in lines(out) do n = n + 1 end
  return n
end

-- ------------------------------------------------------------------ delegated tasks
--
-- Agents Puck starts with `agents start` are recorded in tasks.json, so
-- `agents wait` knows what to watch and `agents result` where to read.

M.TASKS = STATE .. "/tasks.json"

function M.load_tasks() return decode(read_file(M.TASKS)) or {} end

function M.save_tasks(tasks)
  mkdir_p(STATE)
  write_file(M.TASKS, rex.json.encode(tasks, { indent = true }))
end

function M.new_task_id()
  local tasks = M.load_tasks()
  local id
  repeat id = string.format("t%03d", math.random(0, 999)) until not tasks[id]
  return id
end

-- The conversation for a live pane, or nil when it can't be told exactly.
function M.thread_for(agent, id, path) return stub(agent, id, path) end

-- Whether Claude Code has been told to trust this folder (or a parent of it).
function M.claude_trusts(dir)
  local cfg = decode(read_file(HOME .. "/.claude.json")) or {}
  local projects = cfg.projects or {}
  local real = (exec({ "realpath", dir }) or ""):gsub("%s+$", "")
  for _, start in ipairs({ dir, real }) do
    local d = start:gsub("/+$", "")
    while d ~= "" do
      local p = projects[d]
      if p and p.hasTrustDialogAccepted then return true end
      d = d:match("^(.*)/[^/]*$") or ""
    end
  end
  return false
end

function M.shell_quote(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end

-- A macOS notification (from the script, so it fires even if Puck is busy).
function M.notify(title, body)
  local function q(x) return '"' .. tostring(x or ""):gsub("\\", "\\\\"):gsub('"', '\\"') .. '"' end
  exec({ "osascript", "-e", "display notification " .. q(clip(body, 220)) .. " with title " .. q(title) .. ' sound name "Glass"' })
end

-- A pane's most urgent status record; exists is false once the pane is gone.
function M.pane_status(session_id, block_id)
  M.attach(session_id)
  local st, err = rex.block.call(T, "program_status", { session_id = session_id, block_id = block_id })
  if not st then return nil, not (tostring(err):find("not found", 1, true) or tostring(err):find("not_found", 1, true)) end
  local r
  for _, x in ipairs(st.records or {}) do
    if not r or (M.RANK[x.state] or 9) < (M.RANK[r.state] or 9) then r = x end
  end
  return r, true
end

-- ------------------------------------------------------------------ acting

-- Show a pane in the Rex app.
function M.go(x)
  local ok, err = pcall(function()
    rex.client.queue("session.expand", { session_id = x.session_id })
    rex.client.queue("session.select", { session_id = x.session_id, window_id = x.window_id })
  end)
  if not ok then
    -- Several apps connected: pick the one on this Mac.
    local cl = rex.call("client.list", {}) or {}
    local pick
    for _, c in ipairs(cl.clients or {}) do
      if c.info and c.info.kind == "app" and c.principal and c.principal.transport == "unix" then pick = c.client_id end
    end
    if not pick then error(err, 0) end
    exec({ "rex", "-C", pick, "do", "session.expand", "session_id=" .. x.session_id })
    local _, e = exec({ "rex", "-C", pick, "do", "session.select", "session_id=" .. x.session_id, "window_id=" .. x.window_id })
    if e then error(e, 0) end
  end
  rex.call("session.focus_block", { session_id = x.session_id, block_id = x.block_id })
end

-- Type a line into a shell (a carriage return runs it).
function M.type_line(session_id, block_id, text)
  M.attach(session_id)
  local _, err = rex.block.call(T, "write", { session_id = session_id, block_id = block_id, data = text .. "\r" })
  if err then error(err, 0) end
end

function M.foreground(session_id, block_id)
  M.attach(session_id)
  local p = rex.block.call(T, "process", { session_id = session_id, block_id = block_id }) or {}
  return (p.foreground and p.foreground.name) or ""
end

-- Type a message into a pane and press Enter.
function M.tell(x, msg)
  M.attach(x.session_id)
  local _, err = rex.block.call(T, "write", { session_id = x.session_id, block_id = x.block_id, data = msg })
  if err then error(err, 0) end
  rex.sleep(0.15)
  local _, e = rex.call("block.event", { session_id = x.session_id, block_id = x.block_id,
    event = { type = "key", payload = { key = "enter" } } })
  if e then error(e, 0) end
end

function M.rename_tab(session_id, window_id, label)
  M.attach(session_id)
  local _, err = rex.call("session.set_window_label", { session_id = session_id, window_id = window_id, label = label })
  if err then error(err, 0) end
end

function M.close_block(session_id, block_id)
  M.attach(session_id)
  local _, err = rex.call("block.close", { session_id = session_id, block_id = block_id })
  if err then error(err, 0) end
end

-- Open a new background tab in a session that types `command` into its shell.
function M.open_tab(session_id, label, cwd, command)
  M.attach(session_id)
  local w, err = rex.call("session.new_window", {
    session_id = session_id, window_label = label, focus = false,
    layout = rex.layout.block{ flavor = SHELL, options = { cwd = cwd, initial_input = command .. "\r" } },
  })
  if err then error(err, 0) end
  return w
end

return M
