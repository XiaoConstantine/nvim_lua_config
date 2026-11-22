-- Palette pickers for an agent-heavy workflow, built on rex.ui (preview.21, API 17+).
--   prefix g        Jump to an agent: every agent pane across sessions, needs-you first
--   prefix shift+c  New agent: pick a project (z + ghq), then claude / codex / pi
--   prefix shift+o  Second opinion: split a reviewer agent beside this pane, on the diff or an MR
--   prefix shift+x  Tidy: tick the idle agent panes to close (conversations stay resumable)
--   prefix i        Prompt: type one of your most-used prompts into the focused agent
-- Each action also takes its answers as arguments, so `rex do agent_jump id=4a6a9b` works
-- without the palette. `rex do workflow_agents` prints the agent list as JSON.
local P = require("puck.lib")

local T = "com.superlogical.terminal"
local SHELL = T .. ".shell"
local HOME = os.getenv("HOME")
local ICON = { blocked = "🔴", error = "❌", failed = "❌", done = "🟢", idle = "⚪", working = "🟡" }

local function check(value, err)
  if err ~= nil then error(err, 0) end
  return value
end

local function q(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end
local function tilde(p) return (p or ""):gsub("^" .. HOME:gsub("%p", "%%%0"), "~") end
local function base(p) return (p or ""):gsub("/+$", ""):match("([^/]+)$") or p end

-- A pane that runs cmd in dir with the repo's direnv/devenv environment, then leaves a
-- login shell when it exits. Typing cmd into a fresh shell (initial_input) instead races
-- devenv's loading screen, which takes the keystrokes: "/" opens its process search.
local function agent_block(dir, cmd, label)
  return rex.layout.block{
    flavor = SHELL, label = label,
    options = { cwd = dir, shell = "none", command = { "/bin/zsh", "-lic",
      'if [ -f .envrc ]; then direnv exec . /bin/sh -c "$1"; else /bin/sh -c "$1"; fi; exec /bin/zsh -l',
      "zsh", cmd,
    } },
  }
end

local function cwd_of(session_id, block_id)
  if block_id == nil then return nil end
  local p = rex.block.call(T, "process", { session_id = session_id, block_id = block_id })
  return p and p.foreground and p.foreground.cwd
end

-- Puck's index of live conversations, by block: title, MR links, and the transcript's
-- last write, which survives server restarts (status timestamps don't).
local REX_DIR = "/Users/xiao/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS"
local function threads()
  local r = rex.exec({ HOME .. "/.config/rex/puck/agents", "threads", "--live", "--json" }, {
    env = { PATH = REX_DIR .. ":/opt/homebrew/bin:/usr/bin:/bin" }, timeout = 5,
  })
  local by_block = {}
  local list = r and r.ok and rex.json.decode(r.stdout)
  for _, t in ipairs(type(list) == "table" and list or {}) do
    if t.live and t.live.block_id then by_block[t.live.block_id] = t end
  end
  return by_block
end

-- Every terminal pane that reports an agent status, needs-you first, then most recent.
local function agents()
  local out = {}
  local th = threads()
  local list = rex.call("session.list", {}) or {}
  for _, s in ipairs(list.sessions or {}) do
    -- A call only reaches sessions it's attached to; attaching also returns the view.
    local a = rex.call("session.attach", { session_id = s.session_id })
    local v = (a and a.view) or rex.call("session.view", { session_id = s.session_id }) or {}
    for ti, w in ipairs(v.windows or {}) do
      for _, l in ipairs(w.layers or {}) do
        for _, b in ipairs(l.blocks or {}) do
          if b.creator_name == T then
            local st = rex.block.call(T, "program_status", { session_id = s.session_id, block_id = b.block_id })
            local best
            for _, r in ipairs((st and st.records) or {}) do
              if best == nil or (P.RANK[r.state] or 9) < (P.RANK[best.state] or 9) then best = r end
            end
            if best then
              local cwd = cwd_of(s.session_id, b.block_id) or ""
              local t = th[b.block_id] or {}
              local updated = math.max(P.iso_epoch(best.updated_at) or 0, 0)
              if best.state == "idle" or best.state == "done" then updated = t.updated or updated end
              local title = t.title
              if title == nil or title == "" then
                local tt = rex.block.call(T, "title", { session_id = s.session_id, block_id = b.block_id })
                title = tt and tt.title and tt.title:gsub("^[^%w]+%s*", "") or ""
              end
              local tab = w.label or ("tab " .. ti)
              if tab:find("^Window %x+$") then tab = "tab " .. ti end
              out[#out + 1] = {
                id = b.block_id:sub(-6), block_id = b.block_id, session_id = s.session_id,
                window_id = w.window_id, session = s.label or "", tab = tab, title = title,
                sid = t.sid, links = t.links,
                agent = P.AGENT_OF[best.effective_app or best.app] or best.effective_app or best.app or "?",
                state = best.state or "?", msg = best.msg or "", cwd = cwd, repo = base(cwd),
                updated = updated, age = P.ago(updated),
              }
            end
          end
        end
      end
    end
  end
  table.sort(out, function(a, b)
    local ra, rb = P.RANK[a.state] or 9, P.RANK[b.state] or 9
    if ra ~= rb then return ra < rb end
    return a.updated > b.updated
  end)
  return out
end

local function find_agent(list, id)
  for _, a in ipairs(list) do
    if a.block_id == id or a.id == id then return a end
  end
end

local function go(a)
  rex.call("session.attach", { session_id = a.session_id })
  check(rex.session.focus_block{ session_id = a.session_id, block_id = a.block_id })
  rex.client.queue("session.expand", { session_id = a.session_id })
  rex.client.queue("session.select", { session_id = a.session_id, window_id = a.window_id })
end

rex.action{
  name        = "workflow_agents",
  title       = "List Agents (JSON)",
  description = "Every agent pane across sessions with its state, needs-you first.",
  category    = "Agents",
  run         = function() return agents() end,
}

rex.action{
  name        = "agent_jump",
  title       = "Jump to Agent…",
  description = "Pick any Claude, Codex, or pi pane across sessions, needs-you first, and go to it.",
  category    = "Agents",
  keywords    = "agent claude codex pi blocked done idle switch go puck",
  args        = { id = "string?" },
  run         = function(ctx, args)
    local list = agents()
    local id = args.id
    if id == nil then
      local items = {}
      for _, a in ipairs(list) do
        if a.block_id ~= ctx.block_id then
          items[#items + 1] = {
            id       = a.block_id,
            title    = (ICON[a.state] or "·") .. " " .. (a.title ~= "" and P.clip(a.title, 70) or a.tab),
            subtitle = a.session .. " › " .. a.tab .. " · " .. a.agent .. " · " .. a.repo
              .. (a.msg ~= "" and (" · " .. P.clip(a.msg, 60)) or ""),
            detail   = a.state .. " " .. a.age,
          }
        end
      end
      if #items == 0 then error("no other agent panes are reporting status", 0) end
      id = rex.ui.pick{ title = "Jump to agent", placeholder = "Filter by session, tab, repo, state…", items = items }
      if id == nil then return end
    end
    local a = find_agent(list, id)
    if a == nil then error("no agent pane matches " .. id, 0) end
    go(a)
    return { block_id = a.block_id, session = a.session, tab = a.tab }
  end,
}

-- Projects: the focused pane's directory, then z's frecent dirs, then every ghq repo.
local function projects(here)
  local items, seen = {}, {}
  local function add(path, detail)
    if path == nil or path == "" or seen[path] then return end
    seen[path] = true
    items[#items + 1] = { id = path, title = base(path), subtitle = tilde(path), icon = "folder", detail = detail }
  end
  add(here, "here")
  local z, now = {}, os.time()
  local f = io.open(HOME .. "/.z")
  if f then
    for line in f:lines() do
      local path, rank, t = line:match("^(.-)|([%d%.]+)|(%d+)$")
      if path and not path:find("^/private/tmp") and not path:find("^/tmp") then
        local age = now - tonumber(t)
        -- z's own frecency weighting.
        local w = tonumber(rank) * (age < 3600 and 4 or age < 86400 and 2 or age < 604800 and 0.5 or 0.25)
        z[#z + 1] = { path = path, w = w }
      end
    end
    f:close()
  end
  table.sort(z, function(a, b) return a.w > b.w end)
  for _, e in ipairs(z) do add(e.path, "z") end
  local r = rex.exec({ "/opt/homebrew/bin/ghq", "list", "-p" })
  if r and r.ok then
    for path in r.stdout:gmatch("[^\n]+") do add(path, "ghq") end
  end
  return items
end

local LAUNCHERS = {
  { id = "claude --permission-mode auto", title = "Claude Code", subtitle = "--permission-mode auto", icon = "terminal" },
  { id = "claude --resume", title = "Claude Code: resume", subtitle = "pick a past conversation", icon = "clock" },
  { id = "codex --yolo", title = "Codex", subtitle = "--yolo", icon = "terminal" },
  { id = "codex resume", title = "Codex: resume", icon = "clock" },
  { id = "pi", title = "pi", icon = "terminal" },
  { id = "pi -r", title = "pi: resume", icon = "clock" },
  { id = "dev", title = "Dev session", subtitle = "Claude + nvim in a new session", icon = "code" },
}

rex.action{
  name        = "new_agent",
  title       = "New Agent in Project…",
  description = "Pick a project from z and ghq, then start Claude, Codex, or pi there in a new tab.",
  category    = "Agents",
  keywords    = "new agent claude codex pi project repo ghq z resume tab",
  args        = { dir = "string?", command = "string?" },
  run         = function(ctx, args)
    local dir = args.dir
    if dir == nil then
      local pick = rex.ui.pick{
        title = "Project", placeholder = "Filter projects, or type a path",
        items = projects(cwd_of(ctx.session_id, ctx.block_id)), allow_other = true,
      }
      if pick == nil then return end
      dir = type(pick) == "table" and pick.text:gsub("^~", HOME) or pick
    end
    local command = args.command or rex.ui.pick{ title = "Start in " .. base(dir), items = LAUNCHERS }
    if command == nil then return end
    if command == "dev" then return rex.invoke("dev_session", { dir = dir }) end
    local w = check(rex.session.new_window{
      window_label = base(dir), focus = true,
      layout = agent_block(dir, command),
    })
    rex.client.queue("session.select", { session_id = ctx.session_id, window_id = w.window_id })
    return w
  end,
}

-- Reviewer agents, started with the prompt as their first message.
local REVIEWERS = {
  { id = "pi", title = "pi", subtitle = "a different model family's take", icon = "person" },
  { id = "codex --yolo", title = "Codex", icon = "person" },
  { id = "claude --permission-mode auto", title = "Claude Code", subtitle = "a fresh context", icon = "person" },
}

local function git_out(dir, ...)
  local r = rex.exec({ "/usr/bin/git", ... }, { cwd = dir })
  if r == nil or not r.ok then return nil end
  return (r.stdout:gsub("%s+$", ""))
end

rex.action{
  name        = "second_opinion",
  title       = "Second Opinion Review…",
  description = "Split a reviewer agent beside this pane for an adversarial review of the repo's changes or a merge request.",
  category    = "Review",
  keywords    = "review adversarial second opinion pi codex claude mr merge request diff",
  -- target: "diff" for the repo's changes, or an MR number or URL.
  args        = { reviewer = "string?", target = "string?" },
  run         = function(ctx, args)
    local cwd = cwd_of(ctx.session_id, ctx.block_id)
    local root = cwd and git_out(cwd, "rev-parse", "--show-toplevel")
    if root == nil then error("the focused pane isn't in a git repository", 0) end

    local target = args.target
    if target == nil then
      local branch = git_out(root, "rev-parse", "--abbrev-ref", "HEAD") or "HEAD"
      local pick = rex.ui.pick{
        title = "Review what?", placeholder = "Or type an MR number or URL", allow_other = true,
        items = {
          { id = "diff", title = "This branch's changes", subtitle = base(root) .. " · " .. branch, icon = "branch" },
          { id = "mr", title = "The open MR for " .. branch, subtitle = "via glab", icon = "link" },
        },
      }
      if pick == nil then return end
      target = type(pick) == "table" and pick.text or pick
    end
    local reviewer = args.reviewer or rex.ui.pick{ title = "Reviewer", items = REVIEWERS }
    if reviewer == nil then return end

    local rules = " Report findings ranked by severity, each with file:line, the failure scenario, and a "
      .. "suggested fix. Separate confirmed bugs from suspicions. Don't edit files, commit, or post comments."
    local prompt
    if target == "diff" then
      local default = git_out(root, "symbolic-ref", "--short", "refs/remotes/origin/HEAD") or "origin/main"
      local mb = git_out(root, "merge-base", default, "HEAD") or "HEAD~1"
      prompt = ("Do an adversarial code review of this branch's changes: `git diff %s` (merge-base with %s, "
        .. "including uncommitted work)."):format(mb:sub(1, 12), default) .. rules
    elseif target == "mr" then
      prompt = "Do an adversarial code review of the open GitLab merge request for the current branch. "
        .. "Read it with `glab mr view` and `glab mr diff`, including existing discussion." .. rules
    else
      local mr = target:match("merge_requests/(%d+)") or target:match("^!?(%d+)$")
      prompt = "Do an adversarial code review of GitLab merge request " .. (mr and ("!" .. mr) or target)
        .. (target:find("^https?://") and (" (" .. target .. ")") or "")
        .. ". Read it with `glab mr view` and `glab mr diff`, including existing discussion." .. rules
    end

    local split = check(rex.session.new_split{
      anchor_id = ctx.block_id, direction = "horizontal", side = "after", ratio = 0.5, focus = false,
      layout = agent_block(root, reviewer .. " " .. q(prompt), "2nd opinion"),
    })
    return split
  end,
}

rex.action{
  name        = "tidy_agents",
  title       = "Tidy Idle Agent Panes…",
  description = "Tick idle agent panes to close. Panes idle over a day start ticked. Conversations stay resumable.",
  category    = "Agents",
  keywords    = "close idle agents cleanup tidy panes archive",
  args        = { hours = "number?" },
  run         = function(ctx, args)
    local cutoff = os.time() - (args.hours or 24) * 3600
    local items, by_id = {}, {}
    local list = agents()
    table.sort(list, function(a, b) return a.updated < b.updated end)
    for _, a in ipairs(list) do
      if (a.state == "idle" or a.state == "done") and a.block_id ~= ctx.block_id and a.session ~= "puck" then
        by_id[a.block_id] = a
        items[#items + 1] = {
          id = a.block_id, title = a.title ~= "" and P.clip(a.title, 70) or (a.session .. " › " .. a.tab),
          subtitle = a.session .. " › " .. a.tab .. " · " .. a.agent .. " · " .. a.repo,
          detail = a.state .. " " .. a.age, selected = a.state == "idle" and a.updated > 0 and a.updated < cutoff,
        }
      end
    end
    if #items == 0 then error("no idle agent panes", 0) end
    local ids = rex.ui.pick{
      title = "Close idle agent panes", placeholder = "Filter", items = items, multiple = true, confirm = "Close",
    }
    if ids == nil or #ids == 0 then return end
    local closed = 0
    for _, id in ipairs(ids) do
      local a = by_id[id]
      local _, err = rex.call("block.close", { session_id = a.session_id, block_id = id })
      if err then rex.log("warn", "tidy_agents: " .. a.session .. " › " .. a.tab .. ": " .. err)
      else closed = closed + 1 end
    end
    return { closed = closed }
  end,
}

-- The prompts typed most into Claude, Codex, and pi (mined from their histories, Nov 2026).
-- Placeholders: {mr} asks for a merge request (clipboard first, then the repo's open MRs),
-- {agent} for another agent pane (and fills {agent_name} and {agent_session}), {path} for a
-- file (clipboard first), and {text} for free text using the prompt's ask and placeholder.
local PROMPTS = {
  { id = "adv_review", title = "Adversarial review of an MR",
    text = "Do an adversarial review on: {mr}" },
  { id = "adv_again", title = "Another round of adversarial review",
    text = "Do another round of adversarial review on {mr}, including the replies to previous comments." },
  { id = "address_again", title = "Address it, then ask for another round",
    text = "Go ahead and address it, then ask for another round of adversarial review." },
  { id = "share", title = "Share findings with another agent",
    text = "Share your findings with the {agent_name} agent in Rex pane {agent} (session \"{agent_session}\") "
      .. "using the rex CLI. Ask it to adversarially review them rather than simply agree, align with it, "
      .. "and report back where you agree and disagree." },
  { id = "commit_loop", title = "Commit each item, reviewed by Codex",
    text = "Go ahead: for each item, create a commit and have codex do an adversarial code review until "
      .. "you're fully aligned on its review items, then move on to the next." },
  { id = "dd", title = "Investigate with the dd skill", text = "Use your dd skill, {text}",
    ask = "Use your dd skill, …", placeholder = "check why production agentic-chat pods are restarting" },
  { id = "follow", title = "Read and follow a file", text = "Read and follow {path} exactly." },
  { id = "merged", title = "MR is merged", text = "{mr} is merged." },
  { id = "review_cwd", title = "Review cwd for simplification",
    text = "Review cwd thoroughly and look for opportunities: 1. Pythonic implementation "
      .. "2. Simplification of over-engineered code" },
  { id = "flaky", title = "Find broken and flaky integration tests",
    text = "Go through the last 30 days of this repo's integration test runs on main and identify which "
      .. "failing tests are completely broken and which are flaky." },
  { id = "status", title = "Where are we now?",
    text = "Where are we now? Briefly: what's done, what's in progress, what's blocked, and what you need from me." },
  { id = "diff", title = "Show me the full diff", text = "Show me the full diff." },
  { id = "commit_push", title = "Create a commit and push", text = "Create a commit and push." },
}

local GLAB_PATH = HOME .. "/.nix-profile/bin:/opt/homebrew/bin:/usr/bin:/bin"

local function clipboard()
  local r = rex.exec({ "/usr/bin/pbpaste" })
  return r and r.ok and r.stdout or ""
end

local function ask_mr(dir)
  local items, seen = {}, {}
  local c = clipboard():match("https?://%S+/merge_requests/%d+")
  if c then
    items[1] = { id = c, title = "From the clipboard", subtitle = c, icon = "link" }
    seen[c] = true
  end
  local r = dir and rex.exec({ HOME .. "/.nix-profile/bin/glab", "mr", "list", "--per-page", "30", "-F", "json" },
    { cwd = dir, env = { PATH = GLAB_PATH }, timeout = 8 })
  local list = r and r.ok and rex.json.decode(r.stdout)
  for _, m in ipairs(type(list) == "table" and list or {}) do
    if m.web_url and not seen[m.web_url] then
      items[#items + 1] = { id = m.web_url, title = "!" .. tostring(m.iid) .. " " .. (m.title or ""),
        subtitle = m.author and m.author.username, icon = "branch", detail = m.draft and "draft" or nil }
    end
  end
  local pick = rex.ui.pick{ title = "Merge request", placeholder = "Filter, or paste a URL", items = items,
    allow_other = true }
  if type(pick) == "table" then return pick.text end
  return pick
end

rex.action{
  name        = "prompt",
  title       = "Insert Prompt…",
  description = "Type one of your most-used prompts into the focused agent, filling in the MR, agent, or file.",
  category    = "Agents",
  keywords    = "prompt snippet template adversarial review mr merged dd datadog status diff commit",
  -- id picks the prompt; send=true also presses Enter. mr, agent, path, and text skip their questions.
  args        = { id = "string?", send = "boolean?", mr = "string?", agent = "string?", path = "string?",
                  text = "string?" },
  run         = function(ctx, args)
    if ctx.block_id == nil then error("no focused pane to type into", 0) end
    local id = args.id
    if id == nil then
      local items = {}
      for _, p in ipairs(PROMPTS) do
        items[#items + 1] = { id = p.id, title = p.title, subtitle = P.clip(p.text, 90), icon = "star" }
      end
      id = rex.ui.pick{ title = "Prompt", placeholder = "Filter prompts", items = items }
      if id == nil then return end
    end
    local prompt
    for _, p in ipairs(PROMPTS) do if p.id == id then prompt = p end end
    if prompt == nil then error("no prompt named " .. id, 0) end

    local fill = {}
    local text = prompt.text
    if text:find("{mr}", 1, true) then
      fill.mr = args.mr or ask_mr(cwd_of(ctx.session_id, ctx.block_id))
      if fill.mr == nil then return end
    end
    if text:find("{agent}", 1, true) then
      local list, items = agents(), {}
      local chosen = args.agent
      if chosen == nil then
        for _, a in ipairs(list) do
          if a.block_id ~= ctx.block_id then
            items[#items + 1] = { id = a.block_id, title = a.agent .. " · " .. (a.title ~= "" and P.clip(a.title, 60) or a.tab),
              subtitle = a.session .. " › " .. a.tab .. " · " .. a.repo, detail = a.state .. " " .. a.age,
              icon = "person" }
          end
        end
        chosen = rex.ui.pick{ title = "Share with which agent?", items = items }
        if chosen == nil then return end
      end
      local a = find_agent(list, chosen)
      if a == nil then error("no agent pane matches " .. chosen, 0) end
      fill.agent, fill.agent_name, fill.agent_session = a.block_id, a.agent, a.session
    end
    if text:find("{path}", 1, true) then
      local c = clipboard():match("^%s*([~/][^\n]-)%s*$")
      fill.path = args.path or rex.ui.input{ title = "File to read and follow", value = c, placeholder = "/path/to/handoff.md" }
      if fill.path == nil then return end
    end
    if text:find("{text}", 1, true) then
      fill.text = args.text or rex.ui.input{ title = prompt.ask or prompt.title, placeholder = prompt.placeholder }
      if fill.text == nil then return end
    end
    text = text:gsub("{([%w_]+)}", function(k) return fill[k] end)

    check(rex.block.call(T, "write", { session_id = ctx.session_id, block_id = ctx.block_id,
      data = text .. (args.send and "\r" or "") }))
    return { typed = text }
  end,
}

rex.bind("ctrl+b>g", "agent_jump")
rex.bind("ctrl+b>shift+c", "new_agent")
rex.bind("ctrl+b>shift+o", "second_opinion")
rex.bind("ctrl+b>shift+x", "tidy_agents")
rex.bind("ctrl+b>i", "prompt")
