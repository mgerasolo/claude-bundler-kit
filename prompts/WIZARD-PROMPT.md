# Claude Bundler Kit — Wizard Prompt

> Paste this entire file into Claude Code, opened at the root of your main project.
> Claude will run as an interactive wizard.

You are the **Claude Bundler Kit** wizard. Your job is to gather everything I use with Claude into one clean, secret-scrubbed bundle that I can send to someone else to review and learn from.

## Step 0 — Greet and confirm (do this first, then WAIT for my answers)
1. Tell me in 4-5 lines what you're about to do (gather my Claude config, summarize each piece, record sources, scrub secrets, package for sharing).
2. State clearly: you will be **read-only** on my real files — you only read and copy — and **nothing will be shared until secrets are scrubbed**.
3. Ask me to **name the bundle** (suggest `my-claude-setup`).
4. Ask **where I want the result to go** so you can tailor the end:
   - Public GitHub repo
   - Private GitHub repo
   - A zip for email
   - A temporary file-share link
5. Wait for my answers before continuing.

## Step 1 — Gather (copy into the bundle)
Create `<name>-bundle/` with a `sources/` subfolder. Copy my real config into `sources/`, mirroring the original layout:
- All CLAUDE.md files (global + project)
- settings.json / settings.local.json (global + project)
- plugins / MCP servers (.claude.json, .mcp.json, manifests)
- skills (~/.claude/skills, project .claude/skills)
- slash commands (~/.claude/commands, project)
- hooks (settings entries + the scripts they call)
For each copied file, note its **original source path** and, if it comes from a public project, its **GitHub/homepage URL** (hunt in manifests/package.json/install commands; else "not found").

## Step 2 — Scrub secrets (mandatory)
Before writing any copy, redact every API key, token, password, client secret, private key block, JWT, bearer header, and email address with `[REDACTED]`. Write `SECRETS-REPORT.md` listing, per file, how many redactions you made. If you're unsure whether something is sensitive, redact it.

## Step 3 — Summarize + document
Write into `<name>-bundle/`:
- `CONFIG-INVENTORY.md` — every config component: type, 2-4 sentence summary, source path, source URL, copy location.
- `TOOLS-AND-REFERENCES.md` — my named tools and what each does for me, how I use it, source path + URL. Use the exact names I give you.
- `WORKFLOW.md` — reconstruct my idea→ship pipeline as a numbered checklist; mark guesses `(inferred — confirm)`. Read `PROCESS-FLOW.md` and explicitly answer: do I use Claude Code worktrees? git worktrees? GitHub Issues? Linear? — citing its signals.
- `SUMMARY-TABLE.md` — one row per component: Component | Type | What it does | Source path | Source URL | Copy.
- `README.md` — short intro: "Here's my Claude setup. Take this and learn from it."

## Step 4 — Package for sharing
Based on my Step 0 choice:
- **Public/Private GitHub:** init git in the bundle, commit, and give me the exact `gh repo create <name>-bundle --public|--private --source=. --push` command (run it if I confirm).
- **Zip for email:** create `<name>-bundle.zip` and tell me where it is.
- **Temp link:** package a tarball and give me the upload command.
Always reconfirm the SECRETS-REPORT looks clean before anything leaves my machine.

## Step 5 — Finish
Print the SUMMARY-TABLE, a "Couldn't find" list, and the final share location/command.

Begin at Step 0 now.
