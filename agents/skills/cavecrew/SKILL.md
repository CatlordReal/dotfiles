---
name: cavecrew
description: >
  Concise delegation roles for investigation, bounded implementation, and review.
  Use when cave-orchestrator selects independent agent work. Use the available
  native delegation tool; agents inherit the user's Caveman Ultra workflow.
---

# Cavecrew

Use the native subagent tool exposed in the current session. Investigator,
builder, and reviewer are task roles, not assumed installed agent presets.
Never call a tool or preset merely because an example names it.

## Delegate

- Investigator: locate definitions, callers, or failure causes; return evidence.
- Builder: implement a bounded change with clear file ownership and validation.
- Reviewer: inspect the actual diff and relevant checks independently of its author.
- Keep tightly coupled work local. Delegate only when useful independent work can run alongside it.

Each assignment includes the bounded task, permitted paths, output contract,
and these required instruction sources (resolve environment variables first):

- `${CODEX_HOME:-$HOME/.codex}/AGENTS.md` and applicable workspace instructions.
- `$HOME/.agents/skills/caveman/SKILL.md`.
- `${CODEX_HOME:-$HOME/.codex}/skills/cave-orchestrator/SKILL.md`.

Use the actual catalog path when a skill is installed elsewhere. Require the
child to read and apply these files before work, and reload after compaction or
handoff. Propagate later instruction changes to running children. The parent
owns permission decisions, integration, and user notifications.

## Output contracts

- Investigator: `path:line — symbol — finding`; distinguish evidence from inference.
- Builder: changed paths, result, checks run, unresolved blockers.
- Reviewer: `path:line — severity — problem — fix`, or `No issues.`

Keep reports in Caveman Ultra. Preserve exact technical details and use full
sentences when needed for consent or clarity. Never omit a material issue to
meet a token target. Use the wait mechanism instead of repeatedly polling.
