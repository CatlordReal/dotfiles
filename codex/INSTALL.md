# Portable Codex bundle

This directory is a selected export of portable instructions, skills, and a safe
configuration baseline. It is not a copy of a live `~/.codex` directory.

## Install

1. Review `AGENTS.md`, then place it at `~/.codex/AGENTS.md` if its policies
   suit the target machine.
2. Merge reviewed keys from `config.toml` into `~/.codex/config.toml`. Do not
   replace an existing configuration wholesale.
3. Copy `skills/cave-orchestrator` to `~/.codex/skills/cave-orchestrator`.
4. Copy each directory in `agents/skills` to `~/.agents/skills`, including the
   Caveman/Cavecrew tools and `investigate-first`, `lean-build`, `migration`,
   `safe-refactor`, `surgical-patch`, and `verify-and-stop`.
5. If Caveman is installed, replace `__HOME__` in
   `tools/optional-caveman-mcp.toml` and opt in to that MCP server. Otherwise
   leave it disabled.

Use a normal Codex plugin installation for platform-provided tools and plugins.
Their executables, caches, and trust records are machine-specific and absent.

## Verify

Run these checks from this directory after copying files:

```sh
python3 -c 'import tomllib; tomllib.load(open("config.toml", "rb"))'
python3 tools/verify-export.py
shasum -a 256 -c CHECKSUMS.sha256
```

The verification script must pass. It checks for likely live credentials and
excluded cache/authentication files without flagging documented variable names.
`CHECKSUMS.sha256` is generated from
the exported files and gives a transport-integrity check, not a signature.

## Default workflow loading

The `developer_instructions` setting provides a compact startup reminder for
Caveman Ultra and Cave Orchestrator. Merge this key as well as installing the
skills. The global instructions and skill descriptions agree that these are
user defaults; explicit user opt-outs and higher-priority requirements still apply.
Cavecrew uses native delegation roles rather than assuming another agent
platform's presets exist.

Start a new task after installing or restart Codex when convenient to reload
configuration. Existing running tasks can retain earlier instruction snapshots.
This improves loading and handoff consistency; it cannot guarantee perfect model
adherence on every turn. No proxy, model, approval, or sandbox settings are changed
by the startup reminder.
