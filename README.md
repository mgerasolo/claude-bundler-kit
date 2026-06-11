# Claude Bundler Kit

![CI](https://github.com/mgerasolo/claude-bundler-kit/actions/workflows/ci.yml/badge.svg)

**Gather everything you use with Claude into one clean, secret-scrubbed bundle — then send it to someone for review and learning.**

It copies your real config (CLAUDE.md files + `@imports`, settings, plugins, MCP servers, **subagents**, skills, slash commands, hooks, output-styles, plus claude-related shell/cron lines), records each component's source (original path + GitHub URL for public projects), captures your environment/versions, reconstructs your idea-to-ship workflow, **scrubs out secrets and PII**, inventories any executable content for whoever you send it to, and packages it so it's trivially easy to share.

See [SECURITY.md](SECURITY.md) for exactly what's excluded, scrubbed, and flagged.

---

## Quick start (one command, fully automatic)

```bash
git clone https://github.com/mgerasolo/claude-bundler-kit.git
cd claude-bundler-kit
./claude-bundler.sh --auto
```

That builds the whole bundle with **no questions asked** — gather → redact → scan → package. Verify your machine first, then pick how it's delivered:

```bash
./claude-bundler.sh --preflight                                    # check deps only, build nothing
./claude-bundler.sh --auto                                         # makes a zip (size reported)
./claude-bundler.sh --auto --share github-private --invite USER    # private repo, auto-invite a reviewer
./claude-bundler.sh --auto --share templink                        # unlisted temp link
./claude-bundler.sh --auto --name my-setup                         # name it
```

**Recommended private hand-off** (nothing public, revocable): `--share github-private --invite <their-github-username>` — it pushes a private repo and invites them; they pull, you delete it.

Public sharing is **off by default** — `--share github-public` does nothing unless you also pass `--allow-public`.

In `--auto` mode, if the secret scanners flag anything, it **refuses to produce a shareable artifact** and tells you what to fix — it will never hand out a bundle with detected secrets.

> **macOS:** fully supported. Run `./claude-bundler.sh --preflight` first; for the best scan, `brew install betterleaks gitleaks gh`.

## Guided mode

Prefer to be walked through it? Run it with no flags:

```bash
./claude-bundler.sh
```

`claude-bundler.sh` is then an interactive wizard. It will:

1. **Ask you to name** your bundle.
2. **Show you an overview** and confirm before touching anything.
3. **Gather** copies of your Claude config into `<name>-bundle/sources/`, mirroring your original layout — and skip credential-shaped files (`.env`/`.pem`/`.ssh/`…) entirely.
4. **Scrub secrets + PII** — keys, tokens, passwords, private keys, JWTs, emails, internal IPs, private hostnames, phone numbers, and your username in paths → `[REDACTED]`, with a `SECRETS-REPORT.md` showing what was caught.
5. **Inventory executable content** — `EXECUTABLE-CONTENT.md` lists every script/hook + a risk scan, so whoever you send it to knows what's runnable before running it.
6. **Add summaries + workflow docs** — runs Claude to explain each component (or hands you a prompt to paste in if the CLI isn't available).
7. **Ask how you want to share it:** public GitHub repo · private GitHub repo · emailable **zip** · **temporary file-share** link.

Everything that leaves your machine is scrubbed first — sharing is blocked until the scrub step has run, and the full bundle is re-scrubbed right before share.

### Defense in depth: regex scrub + real scanners

Our regex scrubber catches **known** secret/PII formats fast. As a second, authoritative layer the kit then runs whichever industry secret-scanner you have installed and **stops the share if anything is still flagged**:

```bash
# Recommended — by the Gitleaks creators:
brew install betterleaks      # https://github.com/betterleaks/betterleaks
# Alternatives it will also use if present:
brew install gitleaks
brew install trufflehog
pipx install detect-secrets
```

If none are installed, the kit still runs a built-in high-entropy flag and tells you to install one. See [SECURITY.md](SECURITY.md).

### Just want to see what it would grab?

```bash
./claude-bundler.sh --dry-run
```

Lists every file it would copy (and what it would skip) without touching anything.

---

## Prefer to drive it from inside Claude?

Open Claude Code at the root of your main project and paste the contents of [`prompts/WIZARD-PROMPT.md`](prompts/WIZARD-PROMPT.md). Claude will run the same wizard interactively: name it, show the overview, gather, summarize, scrub, and help you publish.

---

## What you get

```
<name>-bundle/
├── README.md                 # "Here's what I'm doing. Here's my setup. Learn from it."
├── PROFILE.md                # ⭐ one-glance highlights + "things worth learning from"
├── ANALYSIS.md               # narrative: rules, hooks, MCP usage (high/low), Claude tooling
├── CONFIG-INVENTORY.md       # CLAUDE.md, settings, plugins, MCP, subagents, skills, hooks
├── TOOLS-AND-REFERENCES.md   # your named tools + what each does + source URLs
├── WORKFLOW.md               # how you go from idea to shipped code
├── SUMMARY-TABLE.md          # one-line index of every component with its source
├── ENVIRONMENT.md            # claude version, installed plugins, MCP servers
├── PROCESS-FLOW.md           # worktrees, issues/Linear, testing/CI, git discipline, dev-env, command usage
├── EXECUTABLE-CONTENT.md     # inventory of every script/hook + risk flags
├── SECRETS-REPORT.md         # what the regex scrubber caught, per file
├── DEEPSCAN-REPORT.md        # external scanner verification (betterleaks/gitleaks/…)
├── PROJECT-FINGERPRINT.md    # (optional) manifests + layout — not your source
└── sources/                  # redacted COPIES of every real file
```

## Safety

- **Read-only on your machine.** The kit only reads and *copies* your files — it never edits or deletes your real config.
- **Scrub-before-share.** No share option will run until secrets have been scrubbed and a report generated for you to review.
- **You choose visibility.** Public repo, private repo, local zip, or temp link — your call, every run.

## License

MIT — see [LICENSE](LICENSE).
