-- One CLI connection gathers status without capturing terminal contents.
local terminal = "com.superlogical.terminal"
local aliases = {
  codex = "Codex", ["codex-cli"] = "Codex",
  claude = "Claude", ["claude-code"] = "Claude",
  pi = "Pi", opencode = "OpenCode", amp = "Amp", gemini = "Gemini",
  droid = "Droid", ["cursor-agent"] = "Cursor", mu = "Mu",
}
local function agent_name(value)
  if type(value) ~= "string" then return nil end
  return aliases[(value:match("([^/]+)$") or value):lower()]
end
local function identify(process)
  if not process then return nil end
  return agent_name(process.argv0) or agent_name(process.invoked_path)
    or agent_name(process.path) or agent_name(process.name)
end
local list, err = rex.call("session.list")
if err then error(err, 0) end
local result = {panes = {}, errors = {}}
for _, session in ipairs(list.sessions or {}) do
  local attached, attach_err = rex.session.attach{session_id = session.session_id}
  if attached then
    for _, window in ipairs(attached.view.windows or {}) do
      for _, layer in ipairs(window.layers or {}) do
        for _, block in ipairs(layer.blocks or {}) do
          if block.creator_name == terminal then
            local args = {session_id = session.session_id, block_id = block.block_id}
            local status, status_err = rex.block.call(terminal, "program_status", args)
            local process, process_err = rex.block.call(terminal, "process", args)
            local agent = process and identify(process.foreground)
            if not agent and process then
              for _, parent in ipairs(process.ancestors or {}) do
                agent = identify(parent)
                if agent then break end
              end
            end
            local records = status and status.records or {}
            local demo = false
            for _, record in ipairs(records) do
              local app = record.effective_app or record.app or ""
              agent = agent or agent_name(app)
              if app:lower():match("^demo%-") then demo = true end
            end
            if agent or #records > 0 then
              table.insert(result.panes, {
                session_id = session.session_id, session_label = session.label,
                window_id = window.window_id, window_label = window.label,
                block_id = block.block_id, block_label = block.label,
                agent = agent, demo = demo, records = records,
                status_error = status_err, process_error = process_err,
              })
            end
            if status_err or process_err then
              table.insert(result.errors, "A pane changed or could not be read: " .. session.label)
            end
          end
        end
      end
    end
  else
    table.insert(result.errors, "Session unavailable: " .. session.label)
  end
end
return result
