# Share your Claude setup with me (2 min, totally safe)

Hey — I've been trying to get more reliable results out of Claude Code and you're
clearly doing something right. I built a little tool that packages up your Claude
setup into one bundle so I can see how you've got it dialed in. It's genuinely
2 minutes and it's built to be safe to share.

**What it does:** copies your Claude config (CLAUDE.md, rules, skills, subagents,
commands, hooks, MCP servers), figures out how you actually work (worktrees, issue
tracking, testing/CI, which tools + MCPs you use a lot), and writes it up as a
readable summary. I get a `PROFILE.md` (quick highlights) and an `ANALYSIS.md`
(here's your rules/hooks/MCPs and what's high vs low usage).

## Security — why it's safe (this was the whole point of building it)

- 🔒 **Read-only.** It only *reads and copies* — it never changes or deletes anything on your machine.
- 🚫 **Never touches credential files.** `.env`, `.pem`, `.ssh`, API keys — those are skipped entirely, never copied.
- ✂️ **Redacts as it copies.** Every file is scrubbed of secrets/keys/emails/IPs the instant it's copied — no raw secret ever sits in the bundle.
- 🔎 **Real scanners gate it.** It then runs proper secret scanners (gitleaks/betterleaks) and **refuses to produce anything shareable if even one secret is flagged.**
- 🙈 **Your chat history is never copied.** For the "what do you use a lot" stats it only counts tool names — it never includes your conversations or command arguments.
- 🔐 **Nothing public.** It goes to a **private** repo only I'm invited to (you delete it after I pull). Public sharing is disabled by default.
- 👀 **You can review before it leaves** — it drops a `SECRETS-REPORT.md` and `DEEPSCAN-REPORT.md` in the bundle showing exactly what was scrubbed.

## Step 1 — check your Mac is ready (builds nothing, 10 sec)

```bash
git clone https://github.com/mgerasolo/claude-bundler-kit.git
cd claude-bundler-kit
./claude-bundler.sh --preflight
```

Send me whatever that prints. If anything's missing it'll say so. For the best
secret-scanning (optional but recommended):

```bash
brew install betterleaks gitleaks gh
```

## Step 2 — build it and send it privately

```bash
gh auth login        # one time, if you haven't
./claude-bundler.sh --auto --share github-private --invite mgerasolo
```

That builds it, scrubs + scans it, pushes a **private** repo, and invites me. I pull
it, you delete the repo. Done.

*(No GitHub? Just run `./claude-bundler.sh --auto` and it makes a small zip you can
send me instead.)*

## What I get back

A self-contained bundle to read top-to-bottom:

- **PROFILE.md** — one-glance highlights + "things worth learning from"
- **ANALYSIS.md** — your rules, hooks, MCP servers, and what's high vs low usage
- **PROCESS-FLOW.md** — worktrees, testing/CI, git discipline, dev-env per repo
- **WORKFLOW.md** — your idea→ship process, written up
- **SECRETS-REPORT.md** + **DEEPSCAN-REPORT.md** — proof of what was scrubbed
- **sources/** — the redacted config itself

Thanks man 🙏
