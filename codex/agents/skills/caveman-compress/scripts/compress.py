#!/usr/bin/env python3
"""
Caveman Memory Compression Orchestrator

Usage:
    python scripts/compress.py <filepath>
"""

import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import List

OUTER_FENCE_REGEX = re.compile(
    r"\A\s*(`{3,}|~{3,})[^\n]*\n(.*)\n\1\s*\Z", re.DOTALL
)
FENCE_OPEN_REGEX = re.compile(r"^(\s{0,3})(`{3,}|~{3,})(.*)$")

# YAML frontmatter: starts at file start with --- on its own line, ends with --- on its own line.
# Captures the entire block (including delimiters and trailing newline) and the body after.
FRONTMATTER_REGEX = re.compile(
    r"\A(---\r?\n.*?\r?\n---\r?\n)(.*)", re.DOTALL
)


def split_frontmatter(text: str):
    """Split YAML frontmatter from body. Returns (frontmatter, body).

    Memory files (and many other markdown docs) start with a YAML frontmatter
    block delimited by `---` lines. The compression LLM has a habit of stripping
    or rewriting these despite preserve-structure rules in the prompt — so we
    surgically remove the frontmatter before compression and prepend it back
    verbatim to the output. Files without frontmatter pass through unchanged.
    """
    m = FRONTMATTER_REGEX.match(text)
    if m:
        return m.group(1), m.group(2)
    return "", text

# Filenames and paths that almost certainly hold secrets or PII. Compressing
# them ships raw bytes to the Anthropic API — a third-party data boundary that
# developers on sensitive codebases cannot cross. detect.py already skips .env
# by extension, but credentials.md / secrets.txt / ~/.aws/credentials would
# slip through the natural-language filter. This is a hard refuse before read.
SENSITIVE_BASENAME_REGEX = re.compile(
    r"(?ix)^("
    r"\.env(\..+)?"
    r"|\.netrc"
    r"|credentials(\..+)?"
    r"|secrets?(\..+)?"
    r"|passwords?(\..+)?"
    r"|id_(rsa|dsa|ecdsa|ed25519)(\.pub)?"
    r"|authorized_keys"
    r"|known_hosts"
    r"|.*\.(pem|key|p12|pfx|crt|cer|jks|keystore|asc|gpg)"
    r")$"
)

SENSITIVE_PATH_COMPONENTS = frozenset({".ssh", ".aws", ".gnupg", ".kube", ".docker"})

SENSITIVE_NAME_TOKENS = (
    "secret", "credential", "password", "passwd",
    "apikey", "accesskey", "token", "privatekey",
)


def backup_dir_for(filepath: Path) -> Path:
    """Resolve the out-of-tree backup directory for a given source file.

    Backups must live OUTSIDE the source directory so skill auto-loaders
    (Claude Code rules/, opencode instructions/, etc.) stop re-ingesting the
    `.original.md` copies as live files. Base dir is platform-aware:
      - Windows: %LOCALAPPDATA%\\caveman-compress\\backups
      - else:    $XDG_DATA_HOME/caveman-compress/backups if set,
                 else ~/.local/share/caveman-compress/backups

    The source file's parent-dir name is mirrored under the base to reduce
    cross-project collisions (e.g. two `task.md` files in different repos).
    """
    if os.name == "nt" or sys.platform == "win32":
        local_appdata = os.environ.get("LOCALAPPDATA")
        base = Path(local_appdata) if local_appdata else Path.home() / "AppData" / "Local"
        base = base / "caveman-compress" / "backups"
    else:
        xdg = os.environ.get("XDG_DATA_HOME")
        base = Path(xdg) if xdg else Path.home() / ".local" / "share"
        base = base / "caveman-compress" / "backups"
    return base / filepath.parent.name


def is_sensitive_path(filepath: Path) -> bool:
    """Heuristic denylist for files that must never be shipped to a third-party API."""
    name = filepath.name
    if SENSITIVE_BASENAME_REGEX.match(name):
        return True
    lowered_parts = {p.lower() for p in filepath.parts}
    if lowered_parts & SENSITIVE_PATH_COMPONENTS:
        return True
    # Normalize separators so "api-key" and "api_key" both match "apikey".
    lower = re.sub(r"[_\-\s.]", "", name.lower())
    return any(tok in lower for tok in SENSITIVE_NAME_TOKENS)


def strip_llm_wrapper(text: str) -> str:
    """Strip outer ```markdown ... ``` fence when it wraps the entire output."""
    m = OUTER_FENCE_REGEX.match(text)
    if m:
        return m.group(2)
    return text


def write_text_atomic(path: Path, text: str) -> None:
    """Write ``text`` to ``path`` atomically as UTF-8.

    Path.write_text() truncates the destination before encoding the string —
    a UnicodeEncodeError (or any other failure) partway through leaves a
    0-byte file, destroying whatever was there before (issue #655). Encode
    first, write the bytes to a sibling temp file, fsync, then os.replace()
    so the destination only ever moves from one complete, valid file to
    another. Preserves the original file's permission bits across the swap.
    """
    data = text.encode("utf-8")
    fd, tmp_name = tempfile.mkstemp(
        dir=str(path.parent), prefix=path.name + ".", suffix=".tmp"
    )
    tmp_path = Path(tmp_name)
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(data)
            f.flush()
            os.fsync(f.fileno())
        if path.exists():
            os.chmod(tmp_path, stat.S_IMODE(path.stat().st_mode))
        os.replace(tmp_path, path)
    except Exception:
        try:
            tmp_path.unlink()
        except OSError:
            pass
        raise


def first_nonblank_line(text: str) -> str:
    """Return the first non-blank line, stripped — used to detect a prose
    preamble smuggled in ahead of the real content (issue #588)."""
    for line in text.splitlines():
        if line.strip():
            return line.strip()
    return ""


def _write_target(filepath: Path, text: str, backup_path: Path) -> None:
    """Write to the target file, surfacing the backup location if the write
    itself fails. write_text_atomic already leaves the target untouched on
    failure, but the caller still needs to know where the pre-compression
    original lives instead of being left to guess (issue #652)."""
    try:
        write_text_atomic(filepath, text)
    except Exception:
        print(f"❌ Write to {filepath} failed. Original preserved at backup: {backup_path}")
        raise


from .detect import should_compress
from .validate import validate

MAX_RETRIES = 2
DEFAULT_CHUNK_CHARS = 12_000
DEFAULT_CODEX_TIMEOUT_SECONDS = 300
CODEX_APP_BINARY = Path("/Applications/ChatGPT.app/Contents/Resources/codex")


# ---------- LLM Calls ----------


def configured_provider() -> str:
    """Return selected compressor provider.

    This Codex installation defaults to ``codex`` so compression uses the
    existing ChatGPT login. Set CAVEMAN_COMPRESS_PROVIDER=claude to retain the
    upstream Claude CLI/SDK path.
    """
    provider = os.environ.get("CAVEMAN_COMPRESS_PROVIDER", "codex").strip().lower()
    if provider not in {"codex", "claude"}:
        raise ValueError(
            f"Unsupported caveman-compress provider: {provider}. "
            "Supported providers: codex, claude"
        )
    return provider


def configured_chunk_chars() -> int:
    raw = os.environ.get("CAVEMAN_COMPRESS_CHUNK_CHARS", str(DEFAULT_CHUNK_CHARS))
    try:
        value = int(raw)
    except ValueError as exc:
        raise ValueError("CAVEMAN_COMPRESS_CHUNK_CHARS must be an integer") from exc
    if value < 2_000:
        raise ValueError("CAVEMAN_COMPRESS_CHUNK_CHARS must be at least 2000")
    return value


def resolve_codex_binary() -> str:
    configured = os.environ.get("CAVEMAN_CODEX_BIN")
    if configured:
        return configured
    if CODEX_APP_BINARY.is_file():
        return str(CODEX_APP_BINARY)
    return shutil.which("codex") or "codex"


def call_codex(prompt: str) -> str:
    """Use ChatGPT-auth Codex while isolating compressor subprocess context.

    ``--ignore-user-config`` prevents recursive loading of global Caveman
    provider/config, plugins, and MCP servers. ``--ephemeral`` avoids adding
    compressor jobs to chat history. Final output goes to a file while process
    streams go to DEVNULL, preventing pipe/output-limit stalls on large jobs.
    """
    model = os.environ.get("CAVEMAN_COMPRESS_MODEL", "gpt-5.6-sol")
    timeout_raw = os.environ.get(
        "CAVEMAN_COMPRESS_TIMEOUT_SECONDS", str(DEFAULT_CODEX_TIMEOUT_SECONDS)
    )
    try:
        timeout = int(timeout_raw)
    except ValueError as exc:
        raise ValueError("CAVEMAN_COMPRESS_TIMEOUT_SECONDS must be an integer") from exc

    with tempfile.TemporaryDirectory(prefix="caveman-compress-codex-") as tmp:
        tmp_path = Path(tmp)
        output_path = tmp_path / "final.md"
        command = [
            resolve_codex_binary(),
            "exec",
            "--ignore-user-config",
            "--ephemeral",
            "--skip-git-repo-check",
            "--sandbox",
            "read-only",
            "--color",
            "never",
            "--model",
            model,
            "--output-last-message",
            str(output_path),
            "-",
        ]
        try:
            subprocess.run(
                command,
                input=prompt,
                text=True,
                cwd=tmp,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=True,
                encoding="utf-8",
                errors="replace",
                timeout=timeout,
            )
        except FileNotFoundError as exc:
            raise RuntimeError(f"Codex CLI not found: {command[0]}") from exc
        except subprocess.TimeoutExpired as exc:
            raise RuntimeError(f"Codex call timed out after {timeout} seconds") from exc
        except subprocess.CalledProcessError as exc:
            raise RuntimeError(f"Codex call failed with exit code {exc.returncode}") from exc
        if not output_path.exists():
            raise RuntimeError("Codex call completed without a final output file")
        return strip_llm_wrapper(output_path.read_text(encoding="utf-8").strip())


def call_claude(prompt: str) -> str:
    """Send a prompt to Claude.

    Prefers the Anthropic SDK when ANTHROPIC_API_KEY is set; otherwise falls
    back to the ``claude --print`` CLI (which handles desktop auth).

    On Windows the CLI subprocess decoding defaults to the system codepage
    (cp1251 / cp1252) and crashes on UTF-8 output — see issue #152. Pinning
    ``encoding="utf-8"`` with ``errors="replace"`` matches the CLI's actual
    native I/O and prevents the UnicodeDecodeError before validation can
    report. Windows users with non-ASCII content can also set
    ``ANTHROPIC_API_KEY`` to route through the SDK and skip the subprocess.
    """
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if api_key:
        try:
            import anthropic

            client = anthropic.Anthropic(api_key=api_key)
            msg = client.messages.create(
                model=os.environ.get("CAVEMAN_MODEL", "claude-sonnet-4-5"),
                max_tokens=8192,
                messages=[{"role": "user", "content": prompt}],
            )
            return strip_llm_wrapper(msg.content[0].text.strip())
        except ImportError:
            pass  # anthropic not installed, fall back to CLI
    # Fallback: use claude CLI (handles desktop auth).
    # Resolve binary via shutil.which so Windows .cmd/.bat shims (e.g.
    # %APPDATA%\npm\claude.CMD) work without shell=True. On POSIX,
    # shutil.which returns the same absolute path as the implicit lookup,
    # so this is a no-op there. Falls back to bare "claude" if not found
    # on PATH so subprocess raises a clear FileNotFoundError.
    claude_bin = shutil.which("claude") or "claude"
    try:
        result = subprocess.run(
            [claude_bin, "--print"],
            input=prompt,
            text=True,
            capture_output=True,
            check=True,
            encoding="utf-8",
            errors="replace",
        )
        return strip_llm_wrapper(result.stdout.strip())
    except subprocess.CalledProcessError as e:
        raise RuntimeError(f"Claude call failed:\n{e.stderr}")


def call_llm(prompt: str) -> str:
    if configured_provider() == "codex":
        return call_codex(prompt)
    return call_claude(prompt)


def split_markdown_chunks(text: str, max_chars: int) -> List[str]:
    """Split Markdown only at safe top-level boundaries.

    Fenced code blocks remain indivisible. Boundaries occur before headings or
    after blank lines outside fences. Oversized indivisible blocks pass through
    as one chunk so protected exact content is never split.
    """
    blocks = []
    current = []
    fence_char = None
    fence_len = 0

    for line in text.splitlines(keepends=True):
        fence_match = FENCE_OPEN_REGEX.match(line.rstrip("\r\n"))
        if fence_char is None and fence_match:
            fence_char = fence_match.group(2)[0]
            fence_len = len(fence_match.group(2))
        elif fence_char is not None and fence_match:
            if (
                fence_match.group(2)[0] == fence_char
                and len(fence_match.group(2)) >= fence_len
                and fence_match.group(3).strip() == ""
            ):
                fence_char = None
                fence_len = 0

        is_heading = fence_char is None and re.match(r"^#{1,6}\s+", line)
        if is_heading and current:
            blocks.append("".join(current))
            current = []
        current.append(line)
        if fence_char is None and not line.strip():
            blocks.append("".join(current))
            current = []

    if current:
        blocks.append("".join(current))

    chunks = []
    current = ""
    for block in blocks:
        if current and len(current) + len(block) > max_chars:
            chunks.append(current)
            current = ""
        if len(block) > max_chars:
            if current:
                chunks.append(current)
                current = ""
            chunks.append(block)
        else:
            current += block
    if current:
        chunks.append(current)
    return chunks


def compress_body(body: str) -> str:
    chunks = split_markdown_chunks(body, configured_chunk_chars())
    outputs = []
    total = len(chunks)
    for index, chunk in enumerate(chunks, start=1):
        if total > 1:
            print(f"Compressing chunk {index}/{total} ({len(chunk)} chars)")
        output = call_llm(build_compress_prompt(chunk))
        if output is None or not output.strip():
            raise RuntimeError(f"Compression provider returned empty chunk {index}/{total}")
        prefix = re.match(r"^\s*", chunk).group(0)
        suffix = re.search(r"\s*$", chunk).group(0)
        outputs.append(prefix + output.strip() + suffix)
    return "".join(outputs)


def build_compress_prompt(original: str) -> str:
    return f"""
Compress this markdown into caveman format.

STRICT RULES:
- Do NOT modify anything inside ``` code blocks
- Do NOT modify anything inside inline backticks
- Preserve ALL URLs exactly
- Preserve ALL headings exactly
- Preserve file paths and commands
- Preserve all constraints, negations, names, dates, versions, and numeric values
- Do not add commentary, preambles, or summaries
- Return ONLY the compressed markdown body — do NOT wrap the entire output in a ```markdown fence or any other fence. Inner code blocks from the original stay as-is; do not add a new outer fence around the whole file.

Only compress natural language.

TEXT:
{original}
"""


def build_fix_prompt(original: str, compressed: str, errors: List[str]) -> str:
    errors_str = "\n".join(f"- {e}" for e in errors)
    return f"""You are fixing a caveman-compressed markdown file. Specific validation errors were found.

CRITICAL RULES:
- DO NOT recompress or rephrase the file
- ONLY fix the listed errors — leave everything else exactly as-is
- The ORIGINAL is provided as reference only (to restore missing content)
- Preserve caveman style in all untouched sections

ERRORS TO FIX:
{errors_str}

HOW TO FIX:
- Missing URL: find it in ORIGINAL, restore it exactly where it belongs in COMPRESSED
- Code block mismatch: find the exact code block in ORIGINAL, restore it in COMPRESSED
- Heading mismatch: restore the exact heading text from ORIGINAL into COMPRESSED
- Do not touch any section not mentioned in the errors

ORIGINAL (reference only):
{original}

COMPRESSED (fix this):
{compressed}

Return ONLY the fixed compressed file. No explanation.
"""


# ---------- Core Logic ----------


def compress_file(filepath: Path) -> bool:
    # Resolve and validate path
    filepath = filepath.resolve()
    MAX_FILE_SIZE = 500_000  # 500KB
    if not filepath.exists():
        raise FileNotFoundError(f"File not found: {filepath}")
    if filepath.stat().st_size > MAX_FILE_SIZE:
        raise ValueError(f"File too large to compress safely (max 500KB): {filepath}")

    # Refuse files that look like they contain secrets or PII. Compressing ships
    # the raw bytes to the Anthropic API — a third-party boundary — so we fail
    # loudly rather than silently exfiltrate credentials or keys. Override is
    # intentional: the user must rename the file if the heuristic is wrong.
    if is_sensitive_path(filepath):
        raise ValueError(
            f"Refusing to compress {filepath}: filename looks sensitive "
            "(credentials, keys, secrets, or known private paths). "
            "Compression sends file contents to the Anthropic API. "
            "Rename the file if this is a false positive."
        )

    print(f"Processing: {filepath}")

    if not should_compress(filepath):
        print("Skipping (not natural language)")
        return False

    original_text = filepath.read_text(encoding="utf-8", errors="ignore")
    # Store backup outside the source directory so skill auto-loaders don't
    # re-ingest the `.original.md` copy as a live file. Mirror the source's
    # parent-dir name + stem under a platform-aware base to reduce collisions.
    backup_dir = backup_dir_for(filepath)
    backup_path = backup_dir / (filepath.stem + ".original.md")

    if not original_text.strip():
        print("❌ Refusing to compress: file is empty or whitespace-only.")
        return False

    # Check if backup already exists to prevent accidental overwriting
    if backup_path.exists():
        print(f"⚠️ Backup file already exists: {backup_path}")
        print("The original backup may contain important content.")
        print("Aborting to prevent data loss. Please remove or rename the backup file if you want to proceed.")
        return False

    # Split YAML frontmatter off before compression. Claude tends to strip or
    # rewrite frontmatter despite preserve-structure rules; we keep it verbatim
    # by removing it from the input and re-prepending it to the output.
    frontmatter, body = split_frontmatter(original_text)
    if frontmatter:
        print(f"Detected YAML frontmatter ({len(frontmatter)} chars) — preserving verbatim")

    if not body.strip():
        print("❌ Refusing to compress: body is empty after frontmatter removal.")
        return False

    # Step 1: Compress (body only, frontmatter excluded)
    provider = configured_provider()
    print(f"Compressing with {provider}...")
    compressed_body = compress_body(body)

    if compressed_body is None or not compressed_body.strip():
        print(f"❌ Compression aborted: {provider} returned an empty response.")
        print("   Original file is untouched (no backup created).")
        return False

    # Compare the BODY (not the whole file) — frontmatter is preserved verbatim
    # and would never change, so identity must be judged on the compressible part.
    if compressed_body.strip() == body.strip():
        print("❌ Compression aborted: output is identical to input.")
        print("   Likely causes: Claude refused, returned the prompt verbatim, or the file is")
        print("   already in caveman form. Original file is untouched (no backup created).")
        return False

    # Reassemble: frontmatter (verbatim) + compressed body
    compressed = frontmatter + compressed_body

    # Save original as backup, then verify the backup readback before
    # touching the input file. If the filesystem dropped bytes (encoding,
    # antivirus, disk full), unlink the bad backup and abort instead of
    # leaving the user with a corrupt backup + compressed primary.
    backup_dir.mkdir(parents=True, exist_ok=True)
    write_text_atomic(backup_path, original_text)
    backup_readback = backup_path.read_text(encoding="utf-8", errors="ignore")
    if backup_readback != original_text:
        print(f"❌ Backup write verification failed: {backup_path}")
        print("   In-memory original differs from on-disk backup. Aborting before touching the input file.")
        try:
            backup_path.unlink()
        except OSError:
            pass
        return False
    _write_target(filepath, compressed, backup_path)

    # Step 2: Validate + Retry
    for attempt in range(MAX_RETRIES):
        print(f"\nValidation attempt {attempt + 1}")

        result = validate(backup_path, filepath)

        if result.is_valid:
            print("Validation passed")
            break

        print("❌ Validation failed:")
        for err in result.errors:
            print(f"   - {err}")

        if attempt == MAX_RETRIES - 1:
            # Restore original on failure
            _write_target(filepath, original_text, backup_path)
            backup_path.unlink(missing_ok=True)
            print("❌ Failed after retries — original restored")
            return False

        print(f"Fixing with {provider}...")
        compressed = call_llm(
            build_fix_prompt(original_text, compressed, result.errors)
        )

        if compressed is None or not compressed.strip():
            print("❌ Fix attempt aborted: Claude returned an empty response.")
            print("   Skipping this attempt.")
            continue

        # Guard against a prose preamble smuggled in ahead of the real fixed
        # content (issue #588). Only enforced when the original starts with a
        # structural anchor (frontmatter `---` or a heading) — plain-prose
        # first lines get legitimately rewritten by compression, and requiring
        # them verbatim would reject every valid fix.
        anchor = first_nonblank_line(original_text)
        if anchor.startswith(("---", "#")) and first_nonblank_line(compressed) != anchor:
            print("❌ Fix attempt aborted: output does not start with the original's first line.")
            print("   Possible preamble leak. Skipping this attempt.")
            continue

        _write_target(filepath, compressed, backup_path)

    return True
