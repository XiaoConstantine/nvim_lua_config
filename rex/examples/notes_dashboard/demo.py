"""Local Rex examples. Workers are simulations; status APIs and notes are real."""
import base64
import curses
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

REX = shutil.which('rex')
COLORS = {'blocked': 3, 'working': 2, 'done': 4, 'error': 5, 'idle': 1}


def api(method, data):
    result = subprocess.run(
        [REX, '--timeout', '2s', 'api', 'call', method, json.dumps(data)],
        capture_output=True, text=True, timeout=4, check=True)
    return json.loads(result.stdout)


def setup(screen):
    curses.curs_set(0)
    curses.start_color()
    curses.use_default_colors()
    for i, color in enumerate([curses.COLOR_WHITE, curses.COLOR_CYAN,
                               curses.COLOR_YELLOW, curses.COLOR_GREEN,
                               curses.COLOR_RED], 1):
        curses.init_pair(i, color, -1)
    screen.timeout(150)
    screen.keypad(True)


def put(screen, y, x, text, color=1, bold=False):
    height, width = screen.getmaxyx()
    if 0 <= y < height and x < width - 1:
        # Treat all status messages as plain text, including control characters.
        clean = ''.join(c if c.isprintable() else ' ' for c in str(text))
        try:
            screen.addnstr(y, x, clean, width-x-1,
                           curses.color_pair(color) | (curses.A_BOLD if bold else 0))
        except curses.error:
            pass


def report(role, state, msg, progress=None):
    encoded = base64.b64encode(msg.encode()).decode()
    fields = [f'state={state}', f'app=Demo-{role}', f'msg={encoded}']
    if state == 'blocked':
        fields.append('kind=question')
    if progress is not None:
        fields.append(f'progress={progress}')
    sys.stdout.write('\x1b]7501;' + ':'.join(fields) + '\x1b\\')
    sys.stdout.flush()


def worker(screen, role):
    setup(screen)
    began = time.monotonic()
    approved = False
    last_report = None
    while True:
        elapsed = time.monotonic() - began
        if role == 'Reviewer':
            state = 'done' if approved else 'blocked'
            msg = 'Decision recorded. Review complete.' if approved else 'Use a 24-hour cache? Awaiting your choice.'
            lines = ['Reviewing a sample change', '', 'Question for you:',
                     'Use a 24-hour cache?', '', '[y] Yes, continue    [r] Reset question']
            if approved:
                lines += ['', 'You chose yes. Dashboard now shows DONE.']
            progress = None
        elif role == 'Builder':
            state, msg = 'working', 'Implementing a sample settings page'
            progress = 10 + int(elapsed * 2) % 81
            n = progress * 22 // 100
            lines = ['Sample implementation loop', '', '[' + '#' * n + '.' * (22-n) + f'] {progress}%',
                     '', 'This loops so you can watch it live.']
        else:
            state, msg, progress = 'done', 'Example checks: 12 of 12 passed', None
            lines = ['Sample test result', '', 'PASS  settings form', 'PASS  cache handling',
                     'PASS  error messages', '', '12 / 12 sample checks passed']
        current = (state, msg, progress)
        screen.erase()
        put(screen, 1, 2, role.upper(), 2, True)
        put(screen, 3, 2, state.upper(), COLORS[state], True)
        h, _ = screen.getmaxyx()
        for row, line in enumerate(lines, 5):
            if row < h-4:
                put(screen, row, 2, line)
        put(screen, h-4, 2, 'Ctrl+b then Shift+a: dashboard', 2)
        put(screen, h-2, 2, 'SIMULATED WORKER  /  no model calls', 3)
        screen.refresh()
        if current != last_report:
            report(role, state, msg, progress)
            last_report = current
        key = screen.getch()
        if key == ord('y') and role == 'Reviewer':
            approved = True
        elif key == ord('r') and role == 'Reviewer':
            approved = False
        elif key in (ord('q'), 27):
            report(role, 'clear', '')
            return


def get_rows(session):
    view = api('session.view', {'session_id': session})
    rows = []
    for window in view['windows']:
        for layer in window['layers']:
            for block in layer['blocks']:
                if block['block_id'] == os.getenv('REX_BLOCK') or block.get('creator_name') != 'com.superlogical.terminal':
                    continue
                result = api('com.superlogical.terminal.program_status', {
                    'session_id': session, 'block_id': block['block_id'], 'args': {}})
                for record in result['records']:
                    rows.append(dict(record, block_id=block['block_id'], label=block['label']))
    return rows


def dashboard(screen, session):
    setup(screen)
    selected, next_read, rows, error = 0, 0, [], ''
    while True:
        if time.monotonic() >= next_read:
            try:
                rows, error = get_rows(session), ''
            except (subprocess.SubprocessError, ValueError, OSError, KeyError) as exc:
                error = 'Could not refresh status: ' + str(exc)[:80]
            next_read = time.monotonic() + 1
        selected = min(selected, max(0, len(rows)-1))
        screen.erase()
        h, w = screen.getmaxyx()
        put(screen, 1, 3, 'AGENT DASHBOARD', 2, True)
        put(screen, 2, 3, 'Live Rex statuses | current session | refresh 1s')
        for i, row in enumerate(rows):
            y = 4 + i*3
            if y+1 >= h-5:
                break
            state = row['state']
            marker = '>' if i == selected else ' '
            progress = f" {row['progress']}%" if row.get('progress') is not None else ''
            put(screen, y, 3, f"{marker} {i+1}  {row.get('effective_app', row['label']):<21} {state.upper()}{progress}", COLORS.get(state, 1), True)
            put(screen, y+1, 8, row.get('msg', ''))
        if not rows:
            put(screen, 6, 3, 'No programs have reported status in this session.')
        put(screen, h-5, 3, error or 'Demo-* entries are simulated; statuses come from the real Rex API.', 3)
        put(screen, h-3, 3, 'Up/Down or j/k: select    Enter: jump to pane', 2)
        put(screen, h-2, 3, '1-9: jump directly       q / Esc: dismiss', 2)
        screen.refresh()
        key = screen.getch()
        if key in (ord('q'), 27):
            return None
        if key in (curses.KEY_DOWN, ord('j')):
            selected = (selected+1) % max(1, len(rows))
        if key in (curses.KEY_UP, ord('k')):
            selected = (selected-1) % max(1, len(rows))
        if key in (10, 13, curses.KEY_ENTER) and rows:
            return rows[selected]['block_id']
        if ord('1') <= key <= ord('9') and key-ord('1') < len(rows):
            return rows[key-ord('1')]['block_id']


def seed_notes(path, label):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        with path.open('x') as file:
            file.write(f'''# {label} / session notebook

Your workspace's memory: plans, decisions, and next steps.
This is a real Markdown file, saved automatically as you edit.

## Try it

1. Move to the last line. Press A, type a note, then Esc.
2. Click the Workers tab. Return with Ctrl+b then Shift+n.
3. Your note stays here. Closing this tab keeps the file too.

## A useful everyday workflow

- Goal: ship the settings page.
- Decision: keep the cache duration configurable.
- Next: ask the reviewer about the default duration.

## Try compact agent activity

Ctrl+b then Shift+a opens Rex's Activity list from the top bar.
Click a listed tab to jump to its work. Esc dismisses the list.
In Reviewer, y answers its question and r resets it.
All workers in this playground are simulations.

## Your scratchpad

My first note: 
''')
    except FileExistsError:
        pass


if __name__ == '__main__':
    mode = sys.argv[1]
    if mode == 'seed-notes':
        seed_notes(sys.argv[2], sys.argv[3])
    elif mode == 'worker':
        curses.wrapper(worker, sys.argv[2])
    elif mode == 'dashboard':
        target = curses.wrapper(dashboard, sys.argv[2])
        if target:
            api('session.focus_block', {'session_id': sys.argv[2], 'block_id': target})
            view = api('session.view', {'session_id': sys.argv[2]})
            client = ['-C', sys.argv[3]] if len(sys.argv) > 3 and sys.argv[3] else []
            subprocess.run([REX, *client, 'do', 'session.select',
                            'session_id=' + sys.argv[2],
                            'window_id=' + view['active_window_id']], check=True)
