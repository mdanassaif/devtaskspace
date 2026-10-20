# Devtaskspace

devtaskspace is a self-hosted operations workspace for builders who want one place to manage tasks, domain renewals, subscriptions, planning notes, collections, blog drafts, and email alerts.

<img width="1335" height="658" alt="Screenshot 2026-03-25 at 7 52 05 PM" src="https://github.com/user-attachments/assets/2fbcc729-46f3-4337-843d-e466c1097c14" />


The project is now structured to be contributor-friendly and open-source-ready:

- App Router + TypeScript + Tailwind
- Signed cookie auth with protected API routes
- Supabase-backed sync for shared operational data
- Local-first modules for lightweight personal workflows
- Repo quality checks for type safety, linting, and production builds

## What devtaskspace Covers

| Area | Purpose |
| --- | --- |
| Overview | Daily snapshot of active work, renewals, billing, and shortcuts |
| Tasks | Track work with status, priority, due dates, tags, and notifications |
| Domains | Watch expirations, registrars, cost, and auto-renew status |
| Subscriptions | Monitor recurring spend and upcoming billing |
| Planning | Capture meetings, writing, reading, and coding plans |
| Collections | Organize links and references into reusable groups |
| Blog | Draft and manage lightweight content ideas and posts |
| Email Logs | Review sent alerts and resend when needed |
| Settings | Configure integrations and delivery defaults |

## Tech Stack

- Next.js 14
- React 18
- TypeScript
- Tailwind CSS
- Supabase
- Resend

## Local Setup

```bash
npm install
cp .env.example .env.local
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

## Environment Variables

```env
# Authentication
AUTH_SECRET=replace-with-a-long-random-string
AUTH_USERNAME=admin
AUTH_PASSWORD=change-this-password

# Email
RESEND_API_KEY=re_...
ALERT_EMAIL=you@example.com
FROM_EMAIL=devtaskspace <alerts@yourdomain.com>

# Data sync
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

Notes:

- Wrap `AUTH_PASSWORD` in quotes if it contains `#`, spaces, or shell-sensitive characters.
- Resend values can also be managed from the in-app settings screen.
- `AUTH_SECRET` should be unique per deployment.

## Database Setup

1. Create a Supabase project.
2. Run the SQL in [`server/supabase/schema.sql`](/Users/mohdkhan/Downloads/files/server/supabase/schema.sql).
3. Add your Supabase credentials to `.env.local`.
4. Restart the dev server.

Current shared resources:

- Tasks
- Domains
- Subscriptions

Planning, collections, and blog content remain local-first.

## Quality Checks

```bash
npm run typecheck
npm run lint
npm run build
```

Or run the full verification suite:

```bash
npm run check
```

## Project Structure

```text
src/app                 App Router pages and API routes
src/components          Shared UI building blocks
src/hooks               Local and synced collection hooks
src/lib                 Auth, helpers, sync, and integration utilities
server/supabase         Schema and backend setup assets
```

## Contributing

Contributions are welcome. Start with [`CONTRIBUTING.md`](/Users/mohdkhan/Downloads/files/CONTRIBUTING.md) for setup and expectations.

If you plan to publish this project publicly, add a license before calling it fully open source.

## Roadmap Ideas

- Team workspaces and multi-user roles
- Import/export flows for operational data
- Better audit history for synced changes
- Public docs site and example deployment guides

## Anas HQ (local Mac app)

A local-first version of the workspace that runs entirely on your Mac: tasks, goals and habits, a Spin wheel that picks your next habit, notes and journal, ideas, documents, domains, subscriptions, revenue and spending.

- `server.js`: Node 22+ server on port 4777 using Node's built-in SQLite (no npm install). Every change is logged to a `history` table, with a JSON backup every 6 hours.
- `mcp.js`: MCP server so Claude can read and update the dashboard (`hq_overview`, `hq_list`, `hq_add`, `hq_update`, `hq_delete`, `hq_history`).
- `mac/`: native SwiftUI app with a menu bar icon. Build and install with `bash mac/build.sh`.
- `public/index.html`: the original web page, served at http://localhost:4777.

Setup: `bash setup.sh` installs a launchd agent for the server and registers the MCP server with Claude Code and Claude Desktop.

Your data stays in `data/` (gitignored) and never leaves your Mac.
