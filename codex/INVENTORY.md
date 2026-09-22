# Inventory

## Exported instructions and skills

- `AGENTS.md`: current global working rules, including mandatory automatic
  reading of global and workspace `AGENTS.md` files before work.
- `skills/cave-orchestrator`: orchestration, delegation, review, and wait rules.
- `agents/skills/caveman`: concise response mode.
- `agents/skills/cavecrew`: delegation guide.
- `agents/skills/caveman-commit`, `caveman-compress`, `caveman-discover`,
  `caveman-evidence-review`, `caveman-explore`, `caveman-help`,
  `caveman-learn`, `caveman-manage`, `caveman-optimize`, `caveman-review`,
  `caveman-setup`, and `caveman-stats`.
- `agents/skills/investigate-first`, `lean-build`, `migration`,
  `safe-refactor`, `surgical-patch`, and `verify-and-stop`: custom development
  workflow skills with their agent definitions.

`caveman-compress` includes its source scripts and its security guidance. No
compiled Python files are exported.

## Configuration and tools

- `config.toml`: OpenAI baseline plus portable terminal, follow-up queue, and
  Catppuccin desktop appearance preferences; no alternate base URL.
- `tools/optional-caveman-mcp.toml`: disabled local Caveman MCP template.
- Codex desktop/browser/computer-use tooling, bundled plugins, and marketplace
  plugins remain installed and managed by Codex on each target machine. This
  export records no executable paths, plugin binaries, caches, or local hashes.

The source configuration currently enables plugin capabilities for GitHub,
documents, spreadsheets, presentations, Hugging Face, Cloudflare, PDF,
computer use, templates, visualization, browser, Codex app tools, and unified
computer use. Its Codex-managed skills are `codex-primary-runtime`,
`develop-web-game`, `gh-address-comments`, `gh-fix-ci`, `imagegen`,
`openai-docs`, `pdf`, `playwright`, `screenshot`, `sora`, `speech`,
`transcribe`, and `yeet`. Install only the capabilities wanted on the
destination; this bundle does not force or vendor them.

Install or update those managed capabilities through Codex. Reference:
https://developers.openai.com/plugins/concepts/plugins
