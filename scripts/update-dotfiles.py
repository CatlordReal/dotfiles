#!/usr/bin/env python3
"""Safely preview and apply tracked dotfiles from a dedicated Git cache."""
from __future__ import annotations

import argparse
import datetime as dt
import fcntl
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import sys
import tempfile
from typing import Any

REMOTE = "https://github.com/CatlordReal/dotfiles.git"
BRANCH = "main"
CONFIG_COMPONENTS = {
    "alacritty", "btop", "espanso", "karabiner", "kitty", "lazygit", "nvim", "yazi",
}
ROOT_FILES = {".p10k.zsh", ".tmux.conf", ".zshrc"}
CONFIG_FILES = {"starship.toml": "starship.toml", "tmux.conf": "tmux.conf"}


class UpdateError(RuntimeError):
    pass


def run(*args: str, cwd: Path | None = None) -> str:
    try:
        return subprocess.check_output(args, cwd=cwd, text=True, stderr=subprocess.STDOUT, timeout=60).strip()
    except subprocess.TimeoutExpired as exc:
        raise UpdateError(f"git command timed out after 60 seconds: {' '.join(args)}") from exc
    except subprocess.CalledProcessError as exc:
        raise UpdateError(exc.output.strip() or "git command failed") from exc


def inside(path: Path, root: Path) -> bool:
    try:
        path.resolve(strict=False).relative_to(root.resolve(strict=False))
        return True
    except ValueError:
        return False


def reject_symlink_path(path: Path, root: Path) -> None:
    """Reject every symlink between root and path, including destination itself."""
    relative = path.relative_to(root)
    current = root
    if current.is_symlink():
        raise UpdateError(f"refusing symlinked root: {root}")
    for part in relative.parts:
        current = current / part
        if current.is_symlink():
            raise UpdateError(f"refusing symlinked destination: {current}")


def lock(state_dir: Path):
    state_dir.mkdir(parents=True, exist_ok=True)
    handle = (state_dir / "update.lock").open("a+")
    try:
        fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError as exc:
        handle.close()
        raise UpdateError("another dotfiles update is already running") from exc
    return handle


def refresh_cache(cache: Path, remote: str, branch: str) -> str:
    if cache.exists() and not (cache / ".git").is_dir():
        raise UpdateError(f"cache exists but is not a Git clone: {cache}")
    if not cache.exists():
        cache.parent.mkdir(parents=True, exist_ok=True)
        run("git", "clone", "--no-checkout", remote, str(cache))
    origin = run("git", "-C", str(cache), "remote", "get-url", "origin")
    if origin != remote:
        raise UpdateError(f"cache origin differs from requested remote: {origin}")
    run("git", "-C", str(cache), "fetch", "--prune", "origin", branch)
    revision = run("git", "-C", str(cache), "rev-parse", "FETCH_HEAD")
    run("git", "-C", str(cache), "checkout", "--detach", "--force", revision)
    return revision


def checkout_revision(cache: Path, revision: str) -> str:
    resolved = run("git", "-C", str(cache), "rev-parse", revision + "^{commit}")
    run("git", "-C", str(cache), "checkout", "--detach", "--force", resolved)
    return resolved


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def tracked_paths(repo: Path) -> list[PurePosixPath]:
    listing = run("git", "-C", str(repo), "ls-files", "-z")
    result: list[PurePosixPath] = []
    for entry in listing.split("\0"):
        if not entry:
            continue
        rel = PurePosixPath(entry)
        if rel.is_absolute() or ".." in rel.parts or rel.parts[0] == ".git":
            raise UpdateError(f"unsafe tracked path: {entry}")
        if rel.parts[0] in CONFIG_COMPONENTS or str(rel) in ROOT_FILES or str(rel) == "zshrc" or str(rel) in CONFIG_FILES:
            result.append(rel)
    return result


def destination_for(rel: PurePosixPath, config_home: Path, home: Path, include_root_shell: bool) -> Path | None:
    text = str(rel)
    if rel.parts[0] in CONFIG_COMPONENTS:
        component_root = config_home / rel.parts[0]
        if not component_root.exists() and not component_root.is_symlink():
            return None
        if not component_root.is_dir():
            raise UpdateError(f"refusing non-directory component root: {component_root}")
        return config_home.joinpath(*rel.parts)
    if text in ROOT_FILES:
        if text == ".zshrc" and sys.platform != "darwin":
            return None
        if not include_root_shell:
            return None
        target = home / text
        return target if target.exists() or target.is_symlink() else None
    if text == "zshrc":
        if sys.platform == "darwin" or not include_root_shell:
            return None
        target = home / ".zshrc"
        return target if target.exists() or target.is_symlink() else None
    if text in CONFIG_FILES:
        target = config_home / CONFIG_FILES[text]
        return target if target.exists() or target.is_symlink() else None
    return None


def make_plan(repo: Path, config_home: Path, home: Path, include_root_shell: bool) -> tuple[list[dict[str, str]], list[dict[str, str]]]:
    plan: list[dict[str, str]] = []
    skipped: list[dict[str, str]] = []
    for rel in tracked_paths(repo):
        source = repo.joinpath(*rel.parts)
        if source.is_symlink() or not source.is_file():
            raise UpdateError(f"refusing non-regular tracked source: {rel}")
        target = destination_for(rel, config_home, home, include_root_shell)
        if target is None:
            reason = "root shell file requires --include-root-shell" if str(rel) in ROOT_FILES or str(rel) == "zshrc" else "component not installed"
            skipped.append({"source": str(rel), "reason": reason})
            continue
        root = config_home if target == config_home or config_home in target.parents else home
        if not inside(target, root):
            raise UpdateError(f"destination escapes its root: {target}")
        reject_symlink_path(target, root)
        if target.exists() and not target.is_file():
            raise UpdateError(f"refusing non-file destination: {target}")
        source_hash = sha256_file(source)
        target_hash = sha256_file(target) if target.exists() else None
        if target_hash == source_hash:
            skipped.append({"source": str(rel), "reason": "unchanged"})
            continue
        action = "update" if target.exists() else "create"
        plan.append({"source": str(rel), "target": str(target), "action": action, "source_sha256": source_hash, "target_sha256": target_hash or "absent"})
    return sorted(plan, key=lambda item: item["target"]), sorted(skipped, key=lambda item: item["source"])


def backup_one(target: Path, backup_root: Path, ordinal: int) -> dict[str, Any]:
    backup = backup_root / f"{ordinal:04d}"
    if not target.exists():
        return {"target": str(target), "exists": False}
    backup.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(target, backup)
    return {"target": str(target), "exists": True, "backup": str(backup)}


def apply_plan(repo: Path, plan: list[dict[str, str]], state_dir: Path) -> Path:
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    backups = state_dir / "backups"
    backups.mkdir(parents=True, exist_ok=True)
    backup_root = Path(tempfile.mkdtemp(prefix=stamp + "-", dir=backups))
    manifest: list[dict[str, Any]] = []
    changed: list[dict[str, str]] = []
    try:
        for ordinal, item in enumerate(plan, start=1):
            manifest.append(backup_one(Path(item["target"]), backup_root, ordinal))
        (backup_root / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
        for item in plan:
            source = repo.joinpath(*PurePosixPath(item["source"]).parts)
            target = Path(item["target"])
            target.parent.mkdir(parents=True, exist_ok=True)
            fd, temporary = tempfile.mkstemp(prefix=".dotfiles-update-", dir=target.parent)
            os.close(fd)
            try:
                shutil.copy2(source, temporary)
                os.replace(temporary, target)
            finally:
                if os.path.exists(temporary):
                    os.unlink(temporary)
            changed.append(item)
    except Exception as exc:
        rollback_errors: list[str] = []
        for entry in reversed(manifest):
            target = Path(entry["target"])
            try:
                if entry["exists"]:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(Path(entry["backup"]), target)
                elif target.exists():
                    target.unlink()
            except OSError as rollback_exc:
                rollback_errors.append(f"{target}: {rollback_exc}")
        suffix = "" if not rollback_errors else "; rollback failed: " + "; ".join(rollback_errors)
        raise UpdateError(f"copy failed; restored prior files{suffix}: {exc}") from exc
    (state_dir / "last-update.json").write_text(json.dumps({"backup": str(backup_root), "changed": changed}, indent=2) + "\n")
    return backup_root


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="copy planned files after preview")
    parser.add_argument("--yes", action="store_true", help="required with --apply")
    parser.add_argument("--refresh", action="store_true", help="fetch origin/main before planning")
    parser.add_argument("--include-root-shell", action="store_true", help="allow existing root shell files to be updated")
    parser.add_argument("--json", action="store_true", help="emit machine-readable result")
    parser.add_argument("--remote", default=REMOTE)
    parser.add_argument("--branch", default=BRANCH)
    parser.add_argument("--revision", help="exact revision approved by a prior preview")
    parser.add_argument("--plan-id", help="exact plan approved by a prior preview")
    parser.add_argument("--cache-dir", type=Path, default=Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "dotfiles-update/repo")
    parser.add_argument("--state-dir", type=Path, default=Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "dotfiles-update")
    parser.add_argument("--config-home", type=Path, default=Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))))
    parser.add_argument("--home", type=Path, default=Path.home())
    args = parser.parse_args(argv)
    if args.apply and (not args.yes or not args.revision or not args.plan_id):
        parser.error("--apply requires --yes, --revision, and --plan-id from a preview")
    held_lock = None
    try:
        held_lock = lock(args.state_dir)
        if args.refresh and args.revision:
            raise UpdateError("--refresh cannot be combined with --revision")
        revision = refresh_cache(args.cache_dir, args.remote, args.branch) if args.refresh else checkout_revision(args.cache_dir, args.revision or "HEAD")
        plan, skipped = make_plan(args.cache_dir, args.config_home, args.home, args.include_root_shell)
        plan_id = hashlib.sha256(json.dumps({"revision": revision, "plan": plan}, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
        if args.plan_id and args.plan_id != plan_id:
            raise UpdateError("planned files changed since confirmation; run preview again")
        result: dict[str, Any] = {"revision": revision, "plan_id": plan_id, "remote": args.remote, "branch": args.branch, "plan": plan, "skipped": skipped, "backup_scope": [item["target"] for item in plan], "applied": False}
        if args.apply:
            result["backup"] = str(apply_plan(args.cache_dir, plan, args.state_dir))
            result["applied"] = True
        if args.json:
            print(json.dumps(result, indent=2))
        else:
            print(f"{len(plan)} files planned from {revision}")
            for item in plan:
                print(f"{item['action']}: {item['target']}  ({item['source']})")
            for item in skipped:
                print(f"skip: {item['source']}  ({item['reason']})")
            print("backup scope:")
            for target in result["backup_scope"]:
                print(f"  {target}")
            if result["applied"]:
                print(f"backup: {result['backup']}")
        return 0
    except UpdateError as exc:
        if args.json:
            print(json.dumps({"error": str(exc)}))
        else:
            print(f"dotfiles update failed: {exc}", file=sys.stderr)
        return 1
    finally:
        if held_lock is not None:
            held_lock.close()


if __name__ == "__main__":
    raise SystemExit(main())
