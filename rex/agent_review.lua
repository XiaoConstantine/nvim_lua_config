-- Review an agent's work in a floating Hunk and hand your notes back to it.
--   prefix v on an agent's pane  open Hunk, live on everything since the base
--   c on a line, ctrl+s          write a note
--   prefix v inside Hunk         send the notes; the agent replies under each one
-- Closing Hunk discards the notes, so send them first. review_watcher.lua opens a
-- review when an agent finishes a turn with new commits.
local terminal = "com.superlogical.terminal"
local shell = "com.superlogical.terminal.shell"
local hunk = "/opt/homebrew/bin/hunk"
local git = "/usr/bin/git"
-- Hunk is a node script, so it needs node on its PATH.
local hunk_path = "/opt/homebrew/bin:/usr/bin:/bin"

-- Open Hunk pop-ups, by block: the agent and repo each one reviews.
local popups = {}

local function check(value, err)
  if err ~= nil then error(err, 0) end
  return value
end

local function git_out(dir, ...)
  local r = rex.exec({ git, ... }, { cwd = dir })
  if r == nil or not r.ok then return nil end
  return (r.stdout:gsub("%s+$", ""))
end

local function is_agent(session_id, block_id)
  local p = rex.block.call(terminal, "process", { session_id = session_id, block_id = block_id })
  local fg = p and p.foreground or {}
  local program = (fg.argv0 or "") .. " " .. (fg.path or "")
  return program:find("claude") ~= nil or program:find("codex") ~= nil
end

local function type_into(session_id, block_id, text)
  check(rex.block.call(terminal, "write", { session_id = session_id, block_id = block_id, data = text }))
  check(rex.block.call(terminal, "write", { session_id = session_id, block_id = block_id, data = "\r" }))
end

-- The Hunk session running in a pop-up: the one whose process descends from the pop-up's,
-- so another Hunk open on the same repo isn't picked by mistake.
local function hunk_session(session_id, popup_id)
  local p = check(rex.block.call(terminal, "process", { session_id = session_id, block_id = popup_id }))
  local root_pid = p.child and p.child.pid
  local r = rex.exec({ hunk, "session", "list", "--json" }, { env = { PATH = hunk_path } })
  local list = r and r.ok and rex.json.decode(r.stdout).sessions or {}
  for _, s in ipairs(list) do
    local pid = s.pid
    for _ = 1, 8 do
      if pid == root_pid then return s.sessionId end
      local ps = rex.exec({ "/bin/ps", "-o", "ppid=", "-p", tostring(pid) })
      pid = ps and ps.ok and tonumber(ps.stdout:match("%d+")) or nil
      if pid == nil or pid <= 1 then break end
    end
  end
end

-- Prefix v inside a Hunk pop-up: save the notes, then point the agent at them.
local function send_notes(session_id, popup_id, review)
  local id = hunk_session(session_id, popup_id)
  local target = id or ("--repo " .. review.root)
  local argv = { hunk, "session", "comment", "list", unpack(id and { id } or { "--repo", review.root }) }
  for _, arg in ipairs({ "--type", "user", "--json" }) do argv[#argv + 1] = arg end
  local r = check(rex.exec(argv, { cwd = review.root, env = { PATH = hunk_path } }))
  if not r.ok then error("couldn't read the Hunk notes: " .. r.stderr, 0) end
  local notes = rex.json.decode(r.stdout)
  local list = type(notes) == "table" and (notes.comments or notes) or {}
  if #list == 0 then error("no notes yet: press c on a line in Hunk to write one", 0) end

  local dir = git_out(review.root, "rev-parse", "--absolute-git-dir") .. "/reviews"
  rex.exec({ "/bin/mkdir", "-p", dir })
  local path = dir .. "/" .. os.date("%Y%m%d-%H%M%S") .. "-hunk.json"
  local file = check(io.open(path, "w"))
  file:write(r.stdout)
  file:close()

  if not is_agent(session_id, review.agent) then
    error("saved the notes to " .. path .. ", but the reviewed pane isn't running an agent", 0)
  end
  type_into(session_id, review.agent, string.format(
    "I left %d review note(s) on %s in the open Hunk window (copy: %s). Use the hunk-review skill: "
      .. "read them with `hunk session comment list %s --type user --json`, address each one, "
      .. "and reply under it with `hunk session comment add %s --reply-to <id> --summary ...`.",
    #list, review.range, path, target, target
  ))
  return { sent = #list, saved = path }
end

rex.action{
  name        = "review_agent",
  title       = "Review Agent Changes",
  description = "Review an agent pane's changes in a floating Hunk; inside Hunk, send your notes to the agent.",
  category    = "Review",
  keywords    = "review diff hunk notes comments agent claude codex commit",
  -- base reviews everything since that commit; without it, the uncommitted changes
  -- or else the last commit.
  args        = { session_id = "string?", block_id = "string?", base = "string?" },
  run         = function(ctx, args)
    local session_id = args.session_id or ctx.session_id
    local block_id = args.block_id or ctx.block_id
    if block_id == nil then error("no pane to review", 0) end
    if popups[block_id] then return send_notes(session_id, block_id, popups[block_id]) end
    local placement = check(rex.session.describe_block{ session_id = session_id, block_id = block_id })
    if (placement.block.label or ""):find("^Review ") then
      -- A pop-up from before the config last reloaded, which forgot whose review it is.
      error("Rex reloaded since this review opened: press q, then prefix v on the agent's pane", 0)
    end

    local p = check(rex.block.call(terminal, "process", { session_id = session_id, block_id = block_id }))
    local cwd = p.foreground and p.foreground.cwd
    local root = cwd and git_out(cwd, "rev-parse", "--show-toplevel")
    if root == nil then error("the pane isn't in a git repository", 0) end

    -- Diff the base against the working tree and keep watching, so the agent's fixes show up.
    local dirty = git_out(root, "status", "--porcelain") ~= ""
    local base = args.base or git_out(root, "rev-parse", dirty and "HEAD" or "HEAD~1")
    local hunk_args, range
    if base then
      hunk_args, range = { "diff", base, "--watch" }, base:sub(1, 7) .. "..working tree"
    else
      hunk_args, range = { "show", "HEAD" }, "the first commit"
    end
    local command = { "/usr/bin/env", "PATH=" .. hunk_path, hunk }
    for _, arg in ipairs(hunk_args) do command[#command + 1] = arg end
    command[#command + 1] = "--agent-notes"
    command[#command + 1] = "--sidebar"

    local layer = check(rex.session.new_layer{
      session_id = session_id,
      window_id  = placement.block.window_id,
      bounds     = { 0.04, 0.04, 0.92, 0.92 },
      focus      = true,
      layout     = rex.layout.block{
        flavor  = shell,
        label   = "Review " .. range,
        options = { cwd = root, shell = "none", command = command },
      },
    })
    popups[layer.block_ids[1]] = { agent = block_id, root = root, range = range }
    return layer
  end,
}

rex.bind("ctrl+b>v", "review_agent")
