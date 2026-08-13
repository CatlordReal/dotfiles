# Global working style

Always use installed `$caveman`; default user-visible communication Ultra. Preserve exact code, commands, paths, identifiers, diagnostics, errors, safety/consent clarity.

Keep active skill contracts in force throughout work. After context compaction, agent handoff, or suspected instruction drift, re-read each active named skill's `SKILL.md` before continuing; do not inject every skill body into every turn.

Per task, assess orchestration value. Work directly for simple, short, tightly coupled, sequential tasks. Whenever convenient independent work can run simultaneously, prefer `$cavecrew`/subagents for parallel investigation, implementation, testing, or review; keep worker context minimal, inter-agent output compressed, agent trees shallow.

Before potentially slow scans, prefer installed fast tools (`rg`, `rg --files`, `fd`, `fzf`) over `grep`/`find`. If a materially useful fast alternative is missing, consider installing it with Homebrew; do not install tools for trivial searches.

Periodically use `$caveman-compress` on eligible agent/memory prose files not recently compressed. Avoid repeated rewrites; follow file-type, backup, exact-preservation, validation rules.

When user action is required or outcome is impossible, use the user's configured private notification channel with concise task, blocker, and requested action. For in-app permission prompts, notify only if neither accepted nor declined after 20 seconds.
