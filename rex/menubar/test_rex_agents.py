import unittest
import rex_agents as app


def pane(records=None, **overrides):
    return dict(session_id='session:00000000-0000-0000-0000-000000000001',
                block_id='block:00000000-0000-0000-0000-000000000002',
                session_label='project', window_label='work', block_label='shell',
                agent='Codex', demo=False, records=records or [], **overrides)


class MenuTests(unittest.TestCase):
    def test_missing_status_is_not_idle_or_working(self):
        rows = app.rows_from({'panes': [pane()]}, app.DEFAULTS)
        self.assertEqual(rows[0]['state'], 'unknown')
        self.assertIn('without status', app.render({'panes': [pane()]}, app.DEFAULTS))

    def test_child_blocked_overrides_working_and_counts_once(self):
        data = {'panes': [pane([{'state': 'working'}, {'id': 'review', 'state': 'blocked'}])]}
        self.assertEqual(len(app.rows_from(data, app.DEFAULTS)), 1)
        self.assertTrue(app.render(data, app.DEFAULTS).startswith('Rex · 1 waiting'))

    def test_demo_and_nonagents_are_opt_in(self):
        demo = pane([{'state': 'working'}]); demo.update(demo=True, agent=None)
        build = pane([{'state': 'working', 'app': 'cargo'}]); build.update(agent=None)
        data = {'panes': [demo, build]}
        self.assertEqual(app.rows_from(data, app.DEFAULTS), [])
        self.assertEqual(len(app.rows_from(data, {'show_demo': True, 'show_programs': True})), 2)

    def test_status_cannot_inject_menu_actions(self):
        text = 'hello\n---\nBad | bash=/tmp/evil param1=yes\x1b\u202e'
        item = app.menu_item(text)
        self.assertEqual(item.count('|'), 1)
        self.assertNotIn('\n', item)
        self.assertNotIn('\x1b', item)
        self.assertNotIn('\u202e', item)

    def test_target_validation(self):
        original = pane()
        self.assertEqual(app.decode_target(app.token_for(original))['block_id'], original['block_id'])
        with self.assertRaises(ValueError):
            app.decode_target(app.token_for(dict(original, block_id='$(touch /tmp/bad)')))

    def test_jump_resolves_moved_pane_and_selects_owner(self):
        from unittest.mock import patch
        target = app.decode_target(app.token_for(pane()))
        moved = {'window_id': 'window:new', 'layers': [{'blocks': [dict(target, owner='client:mine')]}]}
        clients = {'clients': [{'client_id': 'client:other', 'info': {'kind': 'app', 'platform': 'macos'}},
                               {'client_id': 'client:mine', 'info': {'kind': 'app', 'platform': 'macos'}}]}
        with patch.object(app, 'run_rex', side_effect=[{'windows': [moved]}, clients, '', {}]) as call:
            app.jump_to(target)
        args = call.call_args_list[-2].args
        self.assertIn('client:mine', args)
        self.assertIn('window_id=window:new', args)
        self.assertIn('session.focus_block', call.call_args_list[-1].args)


if __name__ == '__main__':
    unittest.main()
