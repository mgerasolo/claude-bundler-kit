# Share your Claude setup with me (private, ~2 minutes)

I want to learn from how you've got Claude set up. This tool packages your
config into one bundle, **automatically strips out every secret/API key/email**,
runs real secret scanners, and gives it to me **privately** (nothing public).
It's read-only — it won't change anything on your machine.

## Step 1 — check your Mac is ready (10 seconds, builds nothing)

```bash
git clone https://github.com/mgerasolo/claude-bundler-kit.git
cd claude-bundler-kit
./claude-bundler.sh --preflight
```

That prints what's installed. If anything REQUIRED is missing it'll say so —
send me that output and I'll help. For the best secret-scanning (recommended):

```bash
brew install betterleaks gitleaks gh
```

## Step 2 — build it and send it to me privately

**Recommended — a private repo only I'm invited to (nothing public):**

```bash
gh auth login          # one time, if you haven't
./claude-bundler.sh --auto --share github-private --invite mgerasolo
```

That builds the bundle, scrubs + scans it, pushes it to a **private** repo, and
invites me. I'll pull it, then you can delete the repo. Done.

(`--invite` defaults to my username and accepts any GitHub username, so you can
review/redirect it. To also capture how you use **worktrees** in a project, add
`--project ~/path/to/your/repo` — repeat it for more repos.)

**No GitHub? Send a file instead:**

```bash
./claude-bundler.sh --auto          # makes <name>-bundle.zip in this folder
```

It'll tell you the size. If it's small, email/AirDrop/message it to me. If it's
big, use the private-repo option above instead.

## Why it's safe to send

1. Redacts **each file the moment it's copied** — no raw secret ever sits in the bundle.
2. **Never copies** credential files (`.env`, `.pem`, `.ssh`, keys) at all.
3. Runs real scanners and, in `--auto`, **refuses to produce anything shareable
   if a secret is still flagged**.
4. **Won't go public** — the public option is disabled unless you explicitly force it.
5. Leaves `SECRETS-REPORT.md` + `DEEPSCAN-REPORT.md` in the bundle so you can see
   exactly what was scrubbed before it leaves your machine.
