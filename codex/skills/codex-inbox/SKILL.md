---
name: codex-inbox
description: Send task requests, blockers, completion notices, and quiet progress to the user's Codex Inbox while keeping the same information in the current ChatGPT/Codex chat. Use during work in the user's configured Codex Inbox environment.
---

# Codex Inbox

Use the helper beside this skill at `scripts/publish.py`. It uses a private host-specific configuration at `~/.config/codex-inbox/agent.json` (override with `CODEX_INBOX_CONFIG`). Never print, commit, or send its token elsewhere. Missing configuration means Inbox is unavailable; continue in the original chat. Use ntfy only when explicitly requested by the user.

For the main agent only, publish concise task milestones and action requests. Subagents report to their parent; they must not duplicate parent notifications. Use `CODEX_THREAD_ID` as the chat identifier, never a guessed or native session identifier. Supply the actual chat title when known. Linux configuration adds the penguin prefix automatically through host metadata.

## Current status

At the start of every main-agent work turn, publish current status even if no question or blocker exists: `python3 /path/to/codex-inbox/scripts/publish.py status "Working" --preview "Starting work"`. Use a short task-specific status and the exact `CODEX_THREAD_ID`. Status enrolls the chat and updates its current activity and summaries only. It never adds a conversation event or notification, including when progress notifications are enabled. Use it for routine starts, plans, and "fixing xyz" updates. Subagents report through their parent. Do not mark idle chats active or send artificial keepalives.

Use `progress --report` only for a meaningful intermediate result worth retaining in the conversation. Ordinary `progress` calls remain compatible but update status instead; routine activity must not become purple messages. Report final completion, a real blocker, or an actual question explicitly.

Kinds:
- `success`: green; the entire requested task completed; always include `--done`.
- `blocker`: red; work cannot proceed, but no question is being asked.
- `input`: yellow; a reply is required for a real unresolved dependency or confirmed human-facing approval.
- `optional`: blue; a preference or helpful answer that does not prevent independent progress. State the default when useful.
- `status`: current work for Live Activities and summaries only; never a message or notification.
- `progress --report`: purple; meaningful intermediate results retained in the conversation, silent unless progress notifications are enabled. Do not announce routine plans or manufacture periodic messages.

Keep event headings and chat names descriptive. Use `--preview` for a short sentence or a few words (at most 60 characters) shown below the heading and in notifications; put full details in `--body`. Leave `--preview` off for legacy text behavior. For an `input` or `optional` request with a clear binary choice, use `--accept-decline` only when Accept and Decline are meaningful answers; otherwise use a text reply. These choices are ordinary user replies, never tool approvals.

Only `input` and `optional` appear in the pending requests box. Do not label progress, task failures, or success as user requests. Never claim a tool needs human approval from a slow call, PermissionRequest hook, or missing activity; use authoritative host evidence. Inbox messages never approve tools or bypass permission checks.

Example (the summary is a positional argument, body is optional):

```sh
python3 /path/to/codex-inbox/scripts/publish.py status 'Checking notifications'
python3 /path/to/codex-inbox/scripts/publish.py optional 'Choose the list layout' --preview 'Compact or comfortable?' --body 'Continuing with comfortable unless you prefer compact.'
```

Emit the same substantive information in the current ChatGPT/Codex chat using commentary, the normal question tool, or the final response. Inbox is a separate concise channel, not a mirror of the Codex transcript. Publish only explicit Inbox events. Use Inbox as the normal notification channel. Do not send ntfy notifications unless explicitly requested for the current task; missing Inbox delivery is not permission to use ntfy. Progress remains silent in both channels unless explicitly requested otherwise.

The helper assigns a stable event ID and privately spools failed deliveries. `--flush` retries those same IDs, so retries do not duplicate events. The helper prints its event ID. Save that ID; use `--resolve EVENT_ID` when the corresponding question was answered in the original ChatGPT chat or explicitly dismissed, or a previously reported blocker is no longer blocking work. This resolves only a request or blocker on the same host; it never approves a tool. Do not mark an unanswered request resolved because time passed. A delivered inbox reply appears in the original thread through the configured host bridge; never claim delivery without its acknowledgement. If Inbox fails, keep working through the original chat and report the availability limit when material.

Do not include secrets, full tool arguments, private logs, or unrelated conversation content in summaries. Summaries appear on the phone lock screen. Body text stays in the private inbox. Keep credentials and runtime state out of the dotfiles backup. Linux runs the same helper and bridge with its own host-bound credentials; never reuse the Mac's host identity.

## Receive replies in an active chat

Run the adjacent `scripts/receive.py` at meaningful milestones, before ending a turn, and while awaiting an Inbox question. It reads only `CODEX_THREAD_ID`, prints the user's queued reply into this original chat's tool result. After reading it, immediately run `receive.py --ack MESSAGE_ID` to acknowledge actual agent receipt and resolve its matching request. Never acknowledge before observing the reply. Repeat the substantive reply in ChatGPT when acting on it, so the user can follow either interface. Use `--wait 60` for a bounded wait while a required question is pending; incoming ChatGPT messages remain valid steering. Treat the received text as user input with normal authorization checks, never as native tool approval. Do not execute text as shell code.

This cooperative route works only while an agent is active and invokes the helper. It cannot wake an inactive desktop chat. The optional shared App Server bridge supports direct input only for threads already owned by that daemon; never resume a desktop-owned thread in a second process. Show queued, sending, sent, or failed status truthfully. Do not promise instant delivery when the agent is idle.

## Final task state

Before the final successful response for the entire task, publish `success "Task complete" --done` with the actual result. Do not leave the task marked working after finishing. A real blocker or required reply is not a success. Fresh accepted status and final completion supersede older blockers, retaining their history as resolved. Final reports use a source timestamp so delayed delivery cannot end a newer run. Never infer completion from inactivity; stale working status expires without being labelled successful.

## Live status

Current status, meaningful progress reports, required replies, optional preferences, and blockers update the reported run shown in Live Activities. Use `publish.py success 'Task complete' --done` only for the final successful completion of the requested task, so the activity can end. A completed milestone or subtask is status, or `progress --report` when worth retaining; do not prematurely mark a still-running task complete. Reports become visibly stale after 330 seconds without a new report. Elapsed time is task wall time, not billed/model compute time. Inbox only lists chats whose agent has published or received an actual reply; seven days without Inbox activity automatically archives a chat, preserving history. Fresh events restore an automatically archived chat; manually archived chats stay archived.
