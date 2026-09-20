"""Verify the real ioctl path against a PTY with known terminal pixel dimensions."""
import fcntl
import os
from pathlib import Path
import pty
import select
import struct
import subprocess
import tempfile
import termios
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]


class TerminalTests(unittest.TestCase):
    def test_cell_metrics_from_controlling_terminal(self):
        self.check_metrics(True)

    def test_detached_child_uses_inherited_terminal_descriptors(self):
        self.check_metrics(False)

    def check_metrics(self, attach):
        with tempfile.TemporaryDirectory() as directory:
            script = Path(directory) / "metrics.lua"
            script.write_text('vim.opt.rtp:prepend(' + repr(str(ROOT)) + ')\n'
                              'local s = assert(require("kitty_cells.terminal").cell_size())\n'
                              'assert(s.width == 11 and s.height == 23, vim.inspect(s))\n'
                              'require("kitty_cells.terminal").write(string.rep("x", 200000) .. "TRANSPORT_PASS")\n'
                              'print("METRICS_PASS")\nvim.cmd("qa!")\n')
            master, slave = pty.openpty()
            fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 30, 80, 880, 690))
            fcntl.fcntl(slave, fcntl.F_SETFL, fcntl.fcntl(slave, fcntl.F_GETFL) | os.O_NONBLOCK)

            def controlling_terminal():
                os.setsid()
                if attach:
                    fcntl.ioctl(0, termios.TIOCSCTTY, 0)

            process = subprocess.Popen(
                ["nvim", "--headless", "-u", "NONE", "-i", "NONE", "-l", str(script)],
                stdin=slave, stdout=slave, stderr=slave, preexec_fn=controlling_terminal,
            )
            os.close(slave)
            output = bytearray()
            deadline = time.monotonic() + 10
            try:
                while time.monotonic() < deadline:
                    if select.select([master], [], [], 0.1)[0]:
                        try:
                            chunk = os.read(master, 65536)
                        except OSError:
                            break
                        if not chunk:
                            break
                        output.extend(chunk)
                    if process.poll() is not None and not select.select([master], [], [], 0)[0]:
                        break
                self.assertEqual(process.wait(timeout=1), 0, output.decode(errors="replace"))
                self.assertIn(b"METRICS_PASS", output)
                self.assertIn(b"TRANSPORT_PASS", output)
            finally:
                if process.poll() is None:
                    process.kill()
                    process.wait()
                os.close(master)


if __name__ == "__main__":
    unittest.main()
