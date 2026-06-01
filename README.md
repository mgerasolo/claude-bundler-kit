# Claude Bundler Kit

**Gather everything you use with Claude into one clean, secret-scrubbed bundle — then send it to someone for review and learning.**

It copies your real config (CLAUDE.md files, settings, plugins, MCP servers, skills, slash commands, hooks), writes a plain-English summary of each piece, records where each one came from (original path + GitHub URL for public projects), reconstructs your idea-to-ship workflow, **scrubs out every secret**, and packages it so it's trivially easy to share.

---

## Quick start

```bash
git clone https://github.com/mgerasolo/claude-bundler-kit.git
cd claude-bundler-kit
./claude-bundler.sh
```

That's it. `claude-bundler.sh` is an interactive wizard. It will:

1. **Ask you to name** your bundle.
2. **Show you an overview** of exactly what it's about to do (and confirm before touching anything).
3. **Gather** copies of your Claude config into `<name>-bundle/sources/`, mirroring your original layout.
4. **Scrub secrets** — API keys, tokens, passwords, private keys, JWTs, and emails are replaced with `[REDACTED]`, and you get a `SECRETS-REPORT.md` showing what was caught.
5. **Add summaries + workflow docs** — runs Claude to explain each component (or hands you a prompt to paste into Claude Code if the CLI isn't available).
6. **Ask how you want to share it:**
   - Push to a **public** GitHub repo
   - Push to a **private** GitHub repo
   - Build a **zip** you can email
   - Upload to a **temporary file-share** link

Everything that leaves your machine is scrubbed first — sharing is blocked until the scrub step has run.

---

## Prefer to drive it from inside Claude?

Open Claude Code at the root of your main project and paste the contents of [`prompts/WIZARD-PROMPT.md`](prompts/WIZARD-PROMPT.md). Claude will run the same wizard interactively: name it, show the overview, gather, summarize, scrub, and help you publish.

---

## What you get

```
<name>-bundle/
├── README.md                 # "Here's what I'm doing. Here's my setup. Learn from it."
├── CONFIG-INVENTORY.md       # CLAUDE.md files, settings, plugins, MCP, skills, hooks
├── TOOLS-AND-REFERENCES.md   # your named tools + what each does + source URLs
├── WORKFLOW.md               # how you go from idea to shipped code
├── SUMMARY-TABLE.md          # one-line index of every component with its source
├── SECRETS-REPORT.md         # what the scrubber caught, per file
└── sources/                  # redacted COPIES of every real file
```

## Safety

- **Read-only on your machine.** The kit only reads and *copies* your files — it never edits or deletes your real config.
- **Scrub-before-share.** No share option will run until secrets have been scrubbed and a report generated for you to review.
- **You choose visibility.** Public repo, private repo, local zip, or temp link — your call, every run.

## License

MIT — see [LICENSE](LICENSE).
