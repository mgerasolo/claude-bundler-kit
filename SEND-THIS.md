# Share your Claude setup with me (2 minutes)

I want to learn from how you've got Claude set up. This tool packages your
config into one bundle, **automatically strips out every secret/API key/email**,
and gives you something safe to send me. It's read-only — it won't change
anything on your machine.

## Run this

```bash
git clone https://github.com/mgerasolo/claude-bundler-kit.git
cd claude-bundler-kit
./claude-bundler.sh --auto
```

That creates a file called **`my-claude-setup-bundle.zip`** in that folder.
Email it to me and you're done.

## Want me to be able to just pull it instead of emailing?

Pick one of these instead of the plain `--auto`:

```bash
# Uploads it and prints a private link you text/email me:
./claude-bundler.sh --auto --share templink

# Pushes it to a public GitHub repo I can clone (needs `gh` logged in):
./claude-bundler.sh --auto --share github-public
```

## What it does (so you can trust it)

1. Copies your Claude config — CLAUDE.md, settings, skills, agents, commands,
   hooks, MCP, plugins — **redacting each file the moment it's copied**.
2. Never even copies credential files (`.env`, `.pem`, `.ssh`, keys).
3. Runs real secret scanners (gitleaks/betterleaks/etc. if you have them) and
   **refuses to make a shareable file if anything is still flagged**.
4. Leaves a `SECRETS-REPORT.md` and `DEEPSCAN-REPORT.md` in the bundle so you
   can see exactly what was scrubbed before you send it.

Optional, for the best scan (recommended): `brew install betterleaks` first.
