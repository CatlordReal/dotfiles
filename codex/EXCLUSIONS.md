# Deliberately excluded

This export excludes all live or machine-bound Codex state:

- `auth.json`, API keys, tokens, cookies, credentials, and environment files.
- Conversation/session history, memory databases, logs, transcripts, and
  task-specific artifacts.
- Trusted project lists and every local path-specific project preference.
- Local proxy URLs, notification executables, application paths, browser trust
  hashes, computer-use configuration, and local MCP service paths.
- Plugin binaries, marketplaces, caches, temporary files, Python bytecode,
  symlinks, and downloaded runtime dependencies.

Skill text may name environment-variable placeholders such as `CAVE_API_KEY`.
Those are instructions, not exported values. Supply secrets through the target
machine's secure environment only when a chosen integration requires them.
