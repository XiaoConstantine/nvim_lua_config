# Rex Agents for SwiftBar

A local menu-bar list of agents in the local Rex server. Click a row to select
its session, tab and pane, and bring Rex forward. Updates every five seconds
and when opened. Requires the existing Rex CLI, SwiftBar and Homebrew Python 3.

`snapshot.lua` reads the documented Rex APIs through one `rex do` connection.
`rex_agents.py` formats SwiftBar's native menu and handles click actions.
No daemon, network service, transcript capture, account or external package is used.

## Status

Recognizes Codex, Claude, Pi, OpenCode, Amp, Gemini, Droid and Cursor process
names. Agents reporting OSC 7501 status show working, waiting, done, failed or
idle. Detected agents without a report say **Status unavailable**; a process
existing does not tell us whether it is busy. Hooks may only take effect in
new agent sessions. Pi/OpenCode may need their own status integration.

Each pane counts once; a failed or blocked child record wins over a working
parent. Multiple records can still belong to one agent. A disappearing pane
is skipped, and partial read failures are indicated. Closed Rex servers show
unavailable and are not automatically started.

The Options submenu can include demo workers and other reporting programs
(builds, etc.). Both are hidden by default. Settings live in `settings.json`.
Click actions validate the current pane location and use its owning Mac app
when there is more than one. Errors appear in the menu until dismissed.

## Files and commands

The installed plugin is a symlink at `~/.swiftbar/rex-agents.5s.py`.
All source files stay here in `~/.config/rex/menubar`.

```sh
python3 ~/.config/rex/menubar/rex_agents.py                 # menu text
python3 ~/.config/rex/menubar/rex_agents.py --snapshot-json # status diagnostics
cd ~/.config/rex/menubar && python3 -m unittest -v
```

Change the symlink's `.5s.` to `.10s.` for a slower refresh interval.
Remove that symlink to uninstall; the source files and Rex settings are kept.
The plugin does not type into agents, approve requests, or stop processes.
