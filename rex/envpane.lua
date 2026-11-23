-- A terminal that runs a command in a directory with the repo's direnv/devenv environment,
-- then leaves a login shell when the command exits.
--
-- Typing the command into a fresh shell (initial_input) instead races devenv's loading
-- screen, which takes the keystrokes: "/" opens its process search, and the rest is lost.
-- Running it under `direnv exec` sends no keystrokes at all.
local SHELL = "com.superlogical.terminal.shell"

-- options(dir, cmd) returns terminal options; block(dir, cmd, label) a whole layout block.
local M = {}

function M.options(dir, cmd)
  return { cwd = dir, shell = "none", command = { "/bin/zsh", "-lic",
    'if [ -f .envrc ]; then direnv exec . /bin/sh -c "$1"; else /bin/sh -c "$1"; fi; exec /bin/zsh -l',
    "zsh", cmd,
  } }
end

function M.block(dir, cmd, label)
  return rex.layout.block{ flavor = SHELL, label = label, options = M.options(dir, cmd) }
end

return M
