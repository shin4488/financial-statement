import json
import unittest
from hook_test_support import HookTestCase


class FormatLintTests(HookTestCase):
    def test_codex_patch_checks_backend_and_frontend(self):
        ruby = self.file('application/backend/app/a.rb')
        ts = self.file('application/frontend/src/a.ts')
        result = self.invoke(cwd=self.root / 'sub', tool_name='apply_patch', tool_input={'command':
            '*** Begin Patch\n*** Update File: ../application/backend/app/a.rb\n*** Update File: ../application/frontend/src/a.ts\n*** End Patch'})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(any(name == 'bundle' and str(ruby) in args for name, args in self.commands()))
        self.assertTrue(any(name == 'eslint' and str(ts) in args for name, args in self.commands()))
        self.assertTrue(any(name == 'prettier' and str(ts) in args for name, args in self.commands()))
        self.assertIn(['tsc', ['--noEmit']], self.commands())

    def test_claude_and_codex_handle_backend_files_without_extensions(self):
        for agent in ['claude', 'codex']:
            for name in ['Gemfile', 'Rakefile', 'config.ru', 'task.rake']:
                with self.subTest(agent=agent, name=name):
                    path = self.file('application/backend/' + name)
                    result = self.invoke(agent=agent, tool_input={'file_path': str(path)})
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertTrue(any(tool == 'bundle' and str(path) in args for tool, args in self.commands()))

    def test_stderr_diagnostics_become_nonblocking_context(self):
        for name, file in [('bundle', 'application/backend/a.rb'), ('tsc', 'application/frontend/a.ts')]:
            self.env['HOOK_FAIL_MATCH'] = name
            path = self.file(file)
            result = self.invoke(tool_input={'file_path': str(path)})
            self.assertEqual(result.returncode, 0, result.stderr)
            output = json.loads(result.stdout)
            self.assertIn('fixture diagnostic', output['hookSpecificOutput']['additionalContext'])

    def test_missing_local_formatter_is_reported_without_installing_packages(self):
        (self.root / 'application/frontend/node_modules/.bin/eslint').unlink()
        path = self.file('application/frontend/a.ts')
        result = self.invoke(tool_input={'file_path': str(path)})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('eslint', json.loads(result.stdout)['hookSpecificOutput']['additionalContext'])
        self.assertFalse(any(name in ['npm', 'npx'] for name, _ in self.commands()))

    def test_docs_do_not_run_formatters(self):
        path = self.file('README.md')
        result = self.invoke(tool_input={'file_path': str(path)})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.commands(), [])


if __name__ == '__main__':
    unittest.main()
