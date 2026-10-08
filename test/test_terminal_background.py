import os
import pathlib
import pty
import select
import subprocess
import termios
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
CONFIG = ROOT / '.terminal-background.bash'


def run_bash(script, environment=None):
    variables = os.environ.copy()
    for name in ['TERM_BACKGROUND', 'TERM_BACKGROUND_OVERRIDE', 'COLORFGBG', 'BAT_THEME', 'TMUX', 'TMUX_PANE', 'SSH_TTY']:
        variables.pop(name, None)
    variables.update(environment or {})
    result = subprocess.run(['bash', '--noprofile', '--norc', '-c', script, 'test', str(CONFIG)],
                            env=variables, capture_output=True, text=True, check=True)
    return result.stdout.strip()


class TerminalBackgroundTest(unittest.TestCase):
    def test_initial_value_precedence_and_unknown(self):
        script = 'source "$1"; printf "%s|%s|%s" "${TERM_BACKGROUND-unset}" "${COLORFGBG-unset}" "${BAT_THEME-unset}"'
        self.assertEqual(run_bash(script), 'unset|unset|unset')
        self.assertEqual(run_bash(script, {'COLORFGBG': '15;0'}), 'dark|15;0|Monokai Extended')
        self.assertEqual(run_bash(script, {'TERM_BACKGROUND': 'light', 'COLORFGBG': '15;0', 'TERM_BACKGROUND_OVERRIDE': 'invalid'}),
                         'light|0;15|Monokai Extended Light')
        self.assertEqual(run_bash(script, {'TERM_BACKGROUND': 'light', 'TERM_BACKGROUND_OVERRIDE': 'dark'}),
                         'dark|15;0|Monokai Extended')

    def test_tmux_attachment_value_and_manual_override(self):
        script = '''
source "$1"
TMUX=test
TMUX_PANE=%1
SSH_TTY=/dev/pts/test
TEST_TMUX_BACKGROUND=light
tmux() { printf 'TERM_BACKGROUND=%s\\n' "$TEST_TMUX_BACKGROUND"; }
refresh_terminal_background
printf '%s|' "$TERM_BACKGROUND"
TERM_BACKGROUND=dark
COLORFGBG='15;0'
BAT_THEME='Monokai Extended'
refresh_terminal_background
printf '%s|' "$TERM_BACKGROUND"
term-background dark >/dev/null
refresh_terminal_background
printf '%s|' "$TERM_BACKGROUND"
term-background auto >/dev/null
printf '%s|' "$TERM_BACKGROUND"
_set_terminal_background dark
refresh_terminal_background
printf '%s|' "$TERM_BACKGROUND"
TEST_TMUX_BACKGROUND=dark
refresh_terminal_background
TEST_TMUX_BACKGROUND=light
refresh_terminal_background
printf '%s' "$TERM_BACKGROUND"
'''
        self.assertEqual(run_bash(script, {'TERM_BACKGROUND': 'dark'}), 'light|light|dark|light|dark|light')

    def test_sourcing_replaces_old_hooks_without_duplicates(self):
        script = '''
precmd_functions=(first refresh_terminal_background second)
preexec_functions=(first colorfgbg_from_system_appearance refresh_terminal_background second)
source "$1"
source "$1"
printf '%s|%s' "${precmd_functions[*]}" "${preexec_functions[*]}"
'''
        self.assertEqual(run_bash(script),
                         'first second refresh_terminal_background|first second refresh_terminal_background')

    def test_detection_preserves_input_and_recovers_after_failures(self):
        master, slave = pty.openpty()
        settings = termios.tcgetattr(slave)
        settings[3] &= ~termios.ECHO
        termios.tcsetattr(slave, termios.TCSANOW, settings)
        release_read, release_write = os.pipe()
        ready_read, ready_write = os.pipe()
        script = '''
source "$1"
OSTYPE=darwin
TERM=xterm-256color
TERM_PROGRAM=Apple_Terminal
TEST_RELEASE_FD=$2
TEST_READY_FD=$3
unset SSH_TTY TMUX
TEST_APPEARANCE=Light
_terminal_background_system_appearance() { printf '%s' "$TEST_APPEARANCE"; }
_terminal_background_from_app() { printf invalid; }
refresh_terminal_background
printf 'INVALID=%s|%s|%s\\n' "$TERM_BACKGROUND" "$COLORFGBG" "$BAT_THEME"
unset _TERM_BACKGROUND_LAST_POLL _TERM_BACKGROUND_NEXT_QUERY_AT
_terminal_background_from_app() { return 1; }
refresh_terminal_background
printf 'FAILED=%s|%s|%s\\n' "$TERM_BACKGROUND" "$COLORFGBG" "$BAT_THEME"
unset _TERM_BACKGROUND_LAST_POLL _TERM_BACKGROUND_NEXT_QUERY_AT
_terminal_background_from_app() {
    printf 'ready\\n' >&"$TEST_READY_FD"
    IFS= read -r ignored <&"$TEST_RELEASE_FD"
    printf dark
}
refresh_terminal_background
IFS= read -r typed
printf 'RESULT=%s|%s|%s|%s\\n' "$TERM_BACKGROUND" "$COLORFGBG" "$BAT_THEME" "$typed"
_terminal_background_from_app() { printf light; }
unset _TERM_BACKGROUND_LAST_POLL
refresh_terminal_background
printf 'CACHED=%s\\n' "$TERM_BACKGROUND"
TEST_APPEARANCE=Dark
unset _TERM_BACKGROUND_LAST_POLL
refresh_terminal_background
printf 'APPEARANCE_CHANGED=%s\\n' "$TERM_BACKGROUND"
'''
        variables = os.environ.copy()
        variables['TERM_BACKGROUND'] = 'light'
        for name in ['TERM_BACKGROUND_OVERRIDE', 'TMUX', 'TMUX_PANE', 'SSH_TTY']:
            variables.pop(name, None)
        process = subprocess.Popen(['bash', '--noprofile', '--norc', '-c', script, 'test', str(CONFIG), str(release_read), str(ready_write)],
                                   stdin=slave, stdout=slave, stderr=subprocess.PIPE, env=variables,
                                   pass_fds=(release_read, ready_write))
        os.close(release_read)
        os.close(ready_write)
        try:
            ready, _, _ = select.select([ready_read], [], [], 5)
            self.assertTrue(ready, 'detector did not start')
            os.read(ready_read, 64)
            os.write(master, b'typed during detection\n')
            os.write(release_write, b'continue\n')
            _, error = process.communicate(timeout=5)
            output = bytearray()
            while True:
                readable, _, _ = select.select([master], [], [], 0)
                if not readable:
                    break
                try:
                    chunk = os.read(master, 4096)
                except OSError:
                    break
                if not chunk:
                    break
                output.extend(chunk)
            text = output.decode().replace('\r', '')
            self.assertEqual(process.returncode, 0, error.decode())
            self.assertIn('INVALID=light|0;15|Monokai Extended Light', text)
            self.assertIn('FAILED=light|0;15|Monokai Extended Light', text)
            self.assertIn('RESULT=dark|15;0|Monokai Extended|typed during detection', text)
            self.assertIn('CACHED=dark', text)
            self.assertIn('APPEARANCE_CHANGED=light', text)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
            for fd in [master, slave, release_write, ready_read]:
                os.close(fd)


if __name__ == '__main__':
    unittest.main()
