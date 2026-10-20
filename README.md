# Anas HQ (local)

Open the **Anas HQ** app (in `~/Applications`, so it shows in Spotlight, Launchpad and the Dock). It's a native SwiftUI app (`mac/Sources/`) with a menu bar icon that shows how many tasks are due. The old web page still works at http://localhost:4777.

Rebuild after changing the Swift code: `bash mac/build.sh`

## Where your data lives
- `data/anashq.db`: one SQLite file holding everything. Every change (yours or Claude's) is also written to a `history` table with before/after values, so nothing is ever truly lost.
- `~/Documents/Anas HQ Backups/anashq-YYYY-MM-DD.json`: a readable full export, refreshed every 6 hours, with one file per day.

## Talking to it from Claude
After `setup.sh`, Claude Code and the Claude desktop app have these tools:
`hq_overview`, `hq_list`, `hq_add`, `hq_update`, `hq_delete`, `hq_history`.
Just say things like "add a task to renew trustseo.me friday, high priority" or
"what renews this month?" The open app updates live.

## Commands
- One-time setup: `bash ~/Desktop/anas-hq/setup.sh`
- Restart: `launchctl kickstart -k gui/$(id -u)/com.anashq.server`
- Stop for good: `launchctl bootout gui/$(id -u)/com.anashq.server`
- Log: `data/server.log`

Needs Node 22+ (uses Node's built-in SQLite, no npm install). If you switch Node versions with nvm, run `setup.sh` again.
