# Project stats

Project stats are opt-in. Press `<leader>wT` to start or stop recording;
`<leader>wP` to pause or resume without ending the session; `<leader>wS` to show
totals for the current saved file and its project. Commands are `:ProjectStatsStart`,
`:ProjectStatsStop`, `:ProjectStatsToggle`, `:ProjectStatsPause`,
`:ProjectStatsResume`, `:ProjectStatsPauseToggle`, and `:ProjectStatsShow`.

The recorder accumulates active editor time and characters typed in Insert mode,
grouped by Git project and file. It stores counts and paths only, never buffer
text. Pausing excludes both time and typed characters. Data lives at
`stdpath("state")/project-stats.json`. Active recording resumes after restarting
Neovim; paused state stays paused. Press `<leader>wT` to stop the session.

On Linux, `<leader>wR` or `:ProjectTerminalRecord` opens a new shell in a
Neovim terminal split and records that shell session with `asciinema`. The cast
file is saved under `stdpath("state")/asciinema/`. Asciinema input capture is
not enabled. This records the new shell session, not the already-running Neovim
session. Casts can contain visible command text and terminal output; review
before sharing. Install `asciinema` through the Neovim setup script to enable it.
