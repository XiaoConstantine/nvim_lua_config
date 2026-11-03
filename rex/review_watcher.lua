-- Opens the agent review (agent_review.lua) when a coding agent finishes a turn
-- that made new commits. It only works while it keeps running:
--   rex do --all ~/.config/rex/review_watcher.lua
local terminal = "com.superlogical.terminal"
local git = "/usr/bin/git"
local agents = { ["claude-code"] = true, codex = true }
local finished = { done = true, idle = true, error = true }

-- The repo and HEAD of each working agent's pane when its turn began, by block.
local started = {}

local function repo_head(session_id, block_id)
  local p = rex.block.call(terminal, "process", { session_id = session_id, block_id = block_id })
  local cwd = p and p.foreground and p.foreground.cwd
  if cwd == nil then return nil end
  local r = rex.exec({ git, "rev-parse", "--show-toplevel", "HEAD" }, { cwd = cwd })
  if r == nil or not r.ok then return nil end
  return r.stdout:match("^([^\n]+)\n(%x+)")
end

rex.on("terminal.program_status_changed", function(ctx, ev)
  local record = ev.record or {}
  if not agents[record.effective_app or record.app] then return end
  local block = ctx.block_id

  if record.state == "working" then
    if started[block] == nil then
      local root, head = repo_head(ctx.session_id, block)
      if root then started[block] = { root = root, head = head } end
    end
  elseif finished[record.state] then
    local start = started[block]
    started[block] = nil
    if start == nil then return end
    local root, head = repo_head(ctx.session_id, block)
    if root ~= start.root or head == start.head then return end
    -- Only commits made on top of where the turn began.
    local r = rex.exec({ git, "merge-base", "--is-ancestor", start.head, head }, { cwd = root })
    if r == nil or not r.ok then return end
    local _, err = rex.invoke("review_agent", { session_id = ctx.session_id, block_id = block, base = start.head })
    if err ~= nil then rex.log("warn", "review_agent: " .. err) end
  end
end)

rex.on("terminal.child_exited", function(ctx)
  started[ctx.block_id] = nil
end)
