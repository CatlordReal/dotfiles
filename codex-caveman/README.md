# Codex + Caveman configuration

Portable backup of the user-owned configuration and skill sources for this
Codex/Caveman setup. It intentionally excludes credentials and mutable runtime
state.

## Included

- `codex/`: sanitized global instructions and provider-routing template.
- `agents/skills/`: installed Cavecrew and Caveman skill sources/scripts.
- `launchagents/`: persistent local Caveman proxy service definition.
- `patches/caveman-cli-openai-provider.patch`: local fix that keeps Codex's
  logical provider identity `openai` while routing through Caveman.
- `docs/`: setup overview and verification commands.

## Never included

`auth.json`, API keys, OAuth tokens, SQLite databases, transcripts, memories,
logs, runtime/session keys, caches, backups, or downloaded Caveman binaries.

## Restore

1. Install current Codex and Caveman CLI normally.
2. Replace every literal `__HOME__` in `codex/config.toml` and the LaunchAgent
   with the absolute home path. Neither TOML nor launchd expands `${HOME}`.
3. Copy `codex/AGENTS.md` into `~/.codex/`; merge the small `config.toml`
   template into the existing file rather than replacing unrelated settings.
4. Copy each directory under `agents/skills/` into `~/.agents/skills/`.
5. Copy the LaunchAgent to `~/Library/LaunchAgents/`, then load/kickstart it.
6. Keep these provider lines exactly unless Caveman upstream has incorporated
   the same fix:

   ```toml
   model_provider = "openai"
   openai_base_url = "http://127.0.0.1:8790/chatgpt"
   ```

7. Verify with `codex --strict-config --version`, `codex resume --all`, and
   `curl -fsS http://127.0.0.1:8790/health/ready`.

Do not restore `model_provider = "caveman"`; Codex Desktop/Mobile Remote can
filter custom-provider threads during reconciliation.
