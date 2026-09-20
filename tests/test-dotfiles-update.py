#!/usr/bin/env python3
import json
import importlib.util
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
UPDATER = ROOT / "scripts" / "update-dotfiles.py"
SPEC = importlib.util.spec_from_file_location("dotfiles_update_script", UPDATER)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class DotfilesUpdateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.base = Path(self.temp.name)
        self.repo = self.base / "repo"
        self.config = self.base / "config"
        self.home = self.base / "home"
        self.state = self.base / "state"
        self.repo.mkdir()
        self.home.mkdir()
        (self.repo / "nvim").mkdir()
        (self.repo / "kitty").mkdir()
        (self.repo / "nvim" / "init.lua").write_text("new nvim\n")
        (self.repo / "kitty" / "kitty.conf").write_text("new kitty\n")
        (self.repo / ".zshrc").write_text("upstream zsh\n")
        (self.repo / "zshrc").write_text("linux zsh\n")
        subprocess.run(["git", "init", "-q", str(self.repo)], check=True)
        subprocess.run(["git", "-C", str(self.repo), "add", "."], check=True)
        subprocess.run(["git", "-C", str(self.repo), "-c", "user.name=test", "-c", "user.email=test@example.invalid", "commit", "-qm", "fixture"], check=True)
        (self.config / "nvim").mkdir(parents=True)
        (self.config / "kitty").mkdir()
        (self.config / "nvim" / "init.lua").write_text("old nvim\n")
        (self.config / "nvim" / "local.lua").write_text("keep me\n")
        (self.home / ".zshrc").write_text("private token=keep\n")

    def tearDown(self):
        self.temp.cleanup()

    def invoke(self, *extra):
        return subprocess.run([
            "python3", str(UPDATER), "--json", "--cache-dir", str(self.repo),
            "--state-dir", str(self.state), "--config-home", str(self.config), "--home", str(self.home), *extra,
        ], text=True, capture_output=True, check=False)

    def approved_args(self, include_root_shell=False):
        preview_args = ("--include-root-shell",) if include_root_shell else ()
        preview = json.loads(self.invoke(*preview_args).stdout)
        return ("--apply", "--yes", "--revision", preview["revision"], "--plan-id", preview["plan_id"], *preview_args)

    def test_preview_and_apply_copy_only_tracked_component_files(self):
        preview = self.invoke()
        self.assertEqual(preview.returncode, 0, preview.stderr)
        result = json.loads(preview.stdout)
        self.assertEqual([item["source"] for item in result["plan"]], ["kitty/kitty.conf", "nvim/init.lua"])
        self.assertEqual(result["backup_scope"], [str(self.config / "kitty" / "kitty.conf"), str(self.config / "nvim" / "init.lua")])
        self.assertEqual(result["skipped"], [
            {"source": ".zshrc", "reason": "root shell file requires --include-root-shell"},
            {"source": "zshrc", "reason": "root shell file requires --include-root-shell"},
        ])

        applied = self.invoke(*self.approved_args())
        self.assertEqual(applied.returncode, 0, applied.stderr)
        self.assertEqual((self.config / "nvim" / "init.lua").read_text(), "new nvim\n")
        self.assertEqual((self.config / "kitty" / "kitty.conf").read_text(), "new kitty\n")
        self.assertEqual((self.config / "nvim" / "local.lua").read_text(), "keep me\n")
        self.assertEqual((self.home / ".zshrc").read_text(), "private token=keep\n")
        backup = Path(json.loads(applied.stdout)["backup"])
        self.assertEqual((backup / "0002").read_text(), "old nvim\n")
        repeated = self.invoke()
        self.assertEqual(repeated.returncode, 0, repeated.stderr)
        self.assertEqual(json.loads(repeated.stdout)["plan"], [])

    def test_apply_refuses_changed_preview_fingerprint(self):
        preview = json.loads(self.invoke().stdout)
        (self.config / "nvim" / "init.lua").write_text("changed after preview\n")
        result = self.invoke("--apply", "--yes", "--revision", preview["revision"], "--plan-id", preview["plan_id"])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("planned files changed since confirmation", json.loads(result.stdout)["error"])
        self.assertEqual((self.config / "nvim" / "init.lua").read_text(), "changed after preview\n")

    def test_root_shell_needs_explicit_opt_in(self):
        result = self.invoke(*self.approved_args(True))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.home / ".zshrc").read_text(), "upstream zsh\n")

    def test_linux_uses_zshrc_not_macos_dotfile(self):
        with mock.patch.object(MODULE.sys, "platform", "linux"):
            plan, _ = MODULE.make_plan(self.repo, self.config, self.home, True)
        roots = [item["source"] for item in plan if item["target"] == str(self.home / ".zshrc")]
        self.assertEqual(roots, ["zshrc"])

    def test_symlink_destination_is_rejected(self):
        target = self.config / "nvim" / "init.lua"
        target.unlink()
        target.symlink_to(self.base / "outside")
        result = self.invoke()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("destination escapes its root", json.loads(result.stdout)["error"])

    def test_non_directory_component_root_is_rejected(self):
        shutil.rmtree(self.config / "nvim")
        (self.config / "nvim").write_text("not a directory\n")
        result = self.invoke()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("refusing non-directory component root", json.loads(result.stdout)["error"])

    def test_copy_failure_rolls_back_created_and_replaced_files(self):
        plan, _ = MODULE.make_plan(self.repo, self.config, self.home, False)
        original_copy2 = MODULE.shutil.copy2

        def fail_nvim_source(source, destination, *args, **kwargs):
            if Path(source) == self.repo / "nvim" / "init.lua":
                raise OSError("injected copy failure")
            return original_copy2(source, destination, *args, **kwargs)

        MODULE.shutil.copy2 = fail_nvim_source
        try:
            with self.assertRaises(MODULE.UpdateError):
                MODULE.apply_plan(self.repo, plan, self.state)
        finally:
            MODULE.shutil.copy2 = original_copy2
        self.assertEqual((self.config / "nvim" / "init.lua").read_text(), "old nvim\n")
        self.assertFalse((self.config / "kitty" / "kitty.conf").exists())


if __name__ == "__main__":
    unittest.main()
