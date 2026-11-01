#!/opt/homebrew/bin/python3
# <xbar.title>Rex Agents</xbar.title>
# <xbar.version>1.0</xbar.version>
# <xbar.desc>Local Rex agent status. Click an agent to focus its pane.</xbar.desc>
# <xbar.dependencies>python3,rex</xbar.dependencies>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>
# <swiftbar.refreshOnOpen>true</swiftbar.refreshOnOpen>
"""SwiftBar front end for Rex's documented CLI; Python standard library only."""
import base64
from collections import Counter
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import unicodedata

ROOT = Path(__file__).resolve().parent
SETTINGS = ROOT / 'settings.json'
ERROR_FILE = ROOT / '.action-error'
ORDER = {'error': 0, 'blocked': 1, 'working': 2, 'done': 3, 'idle': 4, 'unknown': 5}
STATES = {
    'error': ('🔴', 'Failed'), 'blocked': ('🟡', 'Needs you'),
    'working': ('🔵', 'Working'), 'done': ('🟢', 'Done'),
    'idle': ('⚪', 'Idle'), 'unknown': ('◌', 'Status unavailable'),
}
DEFAULTS = {'show_demo': False, 'show_programs': False}


def clean(value, limit=160):
    """Status text must not become SwiftBar markup, commands, or new menu rows."""
    text = str(value or '')
    text = ''.join(' ' if unicodedata.category(c).startswith('C') else c for c in text)
    return ' '.join(text.replace('|', '¦').split())[:limit]


def settings():
    if not SETTINGS.exists():
        return dict(DEFAULTS)
    value = json.loads(SETTINGS.read_text())
    return {key: value.get(key, default) is True for key, default in DEFAULTS.items()}


def write_settings(value):
    temp = SETTINGS.with_suffix('.tmp')
    temp.write_text(json.dumps(value, indent=2) + '\n')
    temp.replace(SETTINGS)


def rex_path():
    candidates = [
        os.environ.get('REX_BIN_PATH'), shutil.which('rex'),
        str(Path.home() / 'Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS/rex'),
    ]
    for candidate in candidates:
        if candidate and os.path.isfile(candidate) and os.access(candidate, os.X_OK):
            return candidate
    raise RuntimeError('Rex CLI not found. Open Rex, then refresh.')


def run_rex(*args, as_json=True):
    env = dict(os.environ)
    for key in ('REX_SESSION', 'REX_BLOCK', 'REX_CLIENT'):
        env.pop(key, None)
    completed = subprocess.run(
        [rex_path(), '--autostart=false', '--timeout', '3s', *args],
        capture_output=True, text=True, timeout=12, env=env,
    )
    if completed.returncode:
        raise RuntimeError(clean(completed.stderr or 'Rex request failed', 280))
    return json.loads(completed.stdout) if as_json else completed.stdout


def snapshot():
    return run_rex('do', str(ROOT / 'snapshot.lua'), '--json')


def rows_from(data, config):
    rows = []
    for pane in data.get('panes') or []:
        if pane.get('demo') and not config['show_demo']:
            continue
        if not pane.get('agent') and not pane.get('demo') and not config['show_programs']:
            continue
        records = [r for r in (pane.get('records') or []) if r.get('state') != 'clear']
        # One entry per pane. A blocked subtask takes precedence over a busy parent.
        record = min(records, key=lambda r: ORDER.get(r.get('state'), 5)) if records else {}
        state = record.get('state', 'unknown')
        if state not in ORDER or pane.get('status_error'):
            state = 'unknown'
        name = pane.get('agent') or record.get('effective_app') or record.get('app') or pane['block_label']
        rows.append(dict(pane, name=name, state=state, message=record.get('msg', ''),
                         kind=record.get('kind', ''), title=record.get('title', ''),
                         progress=record.get('progress'), updated_at=record.get('updated_at', '')))
    return sorted(rows, key=lambda r: (r['session_label'].casefold(), ORDER[r['state']], r['name'].casefold()))


def token_for(row):
    target = {key: row[key] for key in ('session_id', 'block_id')}
    return base64.urlsafe_b64encode(json.dumps(target).encode()).decode()


def decode_target(token):
    target = json.loads(base64.b64decode(token, altchars=b'-_', validate=True))
    for key, prefix in (('session_id', 'session'), ('block_id', 'block')):
        if not re.fullmatch(prefix + r':[0-9a-fA-F-]{36}', str(target.get(key, ''))):
            raise ValueError('Invalid Rex target')
    return target


def action(name, argument=''):
    # Only fixed action names, validated IDs encoded in base64, or fixed option
    # names enter command parameters. No reported program text becomes shell code.
    values = [str(Path(sys.executable).resolve()), str(Path(__file__).resolve()), name]
    if argument:
        values.append(argument)
    if any(re.search(r'[\s\x00-\x1f"\'`$|;&<>\\]', value) for value in values):
        raise RuntimeError('Plugin executable path contains unsupported shell characters')
    return 'bash=' + values[0] + ' ' + ' '.join(
        f'param{i}={value}' for i, value in enumerate(values[1:], 1)
    ) + ' terminal=false refresh=true'


def menu_item(title, attributes=''):
    return clean(title) + ' | ansi=false emojize=false symbolize=false ' + attributes


def render(data, config, action_error=''):
    rows = rows_from(data, config)
    counts = Counter(row['state'] for row in rows)
    waiting = counts['blocked'] + counts['error']
    bits = []
    if waiting:
        bits.append(f'{waiting} waiting')
    if counts['working']:
        bits.append(f"{counts['working']} working")
    if not bits:
        bits.append(f'{len(rows)} agent' + ('' if len(rows) == 1 else 's'))
    header = 'Rex · ' + ' · '.join(bits)
    if data.get('errors'):
        header += ' !'
    lines = [menu_item(header, 'dropdown=false'), '---', menu_item('Rex agents', 'size=15')]
    summary = ', '.join(f'{counts[state]} {label}' for state, label in [
        ('blocked', 'waiting'), ('error', 'failed'), ('working', 'working'),
        ('done', 'done'), ('idle', 'idle'), ('unknown', 'without status'),
    ] if counts[state])
    if summary:
        lines.append(menu_item(summary, 'size=11 color=gray'))
    if action_error:
        lines.extend(['---', menu_item('Last action: ' + action_error, 'color=#d97706'),
                      menu_item('Dismiss error', action('dismiss'))])
    current_session = None
    for row in rows:
        if row['session_id'] != current_session:
            current_session = row['session_id']
            lines.extend(['---', menu_item(row['session_label'], 'size=11 color=gray')])
        icon, label = STATES[row['state']]
        name = clean(row['name'], 32)
        location = clean(row['window_label'], 32)
        if row['demo']:
            label += ' · demo'
        if row['state'] in ('working', 'blocked') and isinstance(row.get('progress'), (int, float)):
            label += f" {max(0, min(100, int(row['progress'])))}%"
        jump = action('jump', token_for(row))
        lines.append(menu_item(f'{icon} {name} · {location} — {label}', jump))
        detail = row['message'] or ('Running; no status reported to Rex' if row['state'] == 'unknown' else '')
        if detail:
            lines.append(menu_item('    ' + clean(detail, 95), 'size=11 color=gray ' + jump))
    if not rows:
        lines.extend(['---', menu_item('No agent panes found', 'color=gray')])
    if data.get('errors'):
        lines.extend(['---', menu_item('Some panes could not be read; retrying next refresh.', 'color=#d97706')])
    lines.extend(['---', menu_item('Click an agent to open its pane · refreshes every 5s', 'size=11 color=gray'),
                  menu_item('Refresh now', 'refresh=true'), menu_item('Options')])
    for key, title in [('show_demo', 'Include demo workers'), ('show_programs', 'Include other reported programs')]:
        lines.append('--' + menu_item(title, f"checked={'true' if config[key] else 'false'} " + action('toggle', key)))
    lines.append('--' + menu_item('Open source folder', action('source')))
    return '\n'.join(lines)


def jump_to(target):
    sid, bid = target['session_id'], target['block_id']
    view = run_rex('api', 'call', '-s', sid, 'session.view', '{}')
    placement = next(((w, b) for w in view.get('windows') or []
                      for l in w.get('layers') or [] for b in l.get('blocks') or []
                      if b['block_id'] == bid), None)
    if not placement:
        raise RuntimeError('That pane has closed. Refresh the menu.')
    window, block = placement
    clients = run_rex('client', 'ls', '--json').get('clients', [])
    apps = [c for c in clients if c.get('info', {}).get('kind') == 'app'
            and c.get('info', {}).get('platform') == 'macos']
    owned = [c for c in apps if c['client_id'] == block.get('owner')]
    candidates = owned or apps
    if len(candidates) != 1:
        raise RuntimeError('Open one Rex app on this Mac, then try again.')
    app = candidates[0]
    run_rex('-C', app['client_id'], 'do', 'session.select',
            'session_id=' + sid, 'window_id=' + window['window_id'], as_json=False)
    # Bring the existing local app forward after the menu dismisses.
    app_name = app.get('info', {}).get('name')
    if app_name in ('Rex', 'Rex Beta'):
        subprocess.run(['/usr/bin/open', '-a', app_name], check=True, timeout=5)
    # Selecting/activating the app can restore its previous pane. Focus the
    # requested block last so that restoration cannot immediately undo the jump.
    run_rex('api', 'call', '-s', sid, 'session.focus_block', json.dumps({'block_id': bid}))


def main():
    if len(sys.argv) > 1 and sys.argv[1] not in ('--snapshot-json', '--rows-json'):
        try:
            command = sys.argv[1]
            if command == 'jump':
                jump_to(decode_target(sys.argv[2]))
            elif command == 'toggle' and sys.argv[2] in DEFAULTS:
                config = settings()
                config[sys.argv[2]] = not config[sys.argv[2]]
                write_settings(config)
            elif command == 'source':
                subprocess.run(['/usr/bin/open', str(ROOT)], check=True, timeout=5)
            elif command != 'dismiss':
                raise ValueError('Unknown action')
            ERROR_FILE.unlink(missing_ok=True)
        except Exception as exc:
            ERROR_FILE.write_text(clean(exc, 240))
            print(clean(exc), file=sys.stderr)
            return 1
        return 0
    try:
        data = snapshot()
        if '--snapshot-json' in sys.argv:
            print(json.dumps(data, indent=2))
        elif '--rows-json' in sys.argv:
            config = settings()
            rows = rows_from(data, config)
            for row in rows:
                row['target'] = token_for(row)
            print(json.dumps({'rows': rows, 'errors': data.get('errors') or [], 'settings': config}))
        else:
            error = ERROR_FILE.read_text() if ERROR_FILE.exists() else ''
            print(render(data, settings(), error))
    except Exception as exc:
        if '--snapshot-json' in sys.argv or '--rows-json' in sys.argv:
            print(clean(exc), file=sys.stderr)
            return 1
        print(menu_item('Rex · unavailable', 'dropdown=false'))
        print('---')
        print(menu_item(clean(exc, 180)))
        print(menu_item('Refresh now', 'refresh=true'))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
