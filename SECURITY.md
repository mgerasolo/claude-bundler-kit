# Security

Claude Bundler Kit is built to be shared between people. This document states
exactly what it does to keep your bundle safe, and where its limits are.

## Guarantees

- **Read-only on your machine.** The kit only reads and *copies* your config.
  It never edits, moves, or deletes your real files.
- **Hard exclude-list — never copied at all.** Credential-shaped files are
  skipped before any copy happens, regardless of where they're found:
  `*.env`, `*.pem`, `*.key`, `*.p12`, `*.pfx`, keystores, `id_rsa`/`id_ed25519`/etc.,
  anything under `.ssh/`, `.aws/credentials`, `.netrc`, `.npmrc`, `.pypirc`,
  `.gnupg/`, and files matching `*credentials*` / `*secret*`.
- **Scrub before share.** No share path (GitHub, zip, temp link) will run until
  the scrub step has produced `SECRETS-REPORT.md` and you confirm it. The full
  bundle is re-scrubbed immediately before sharing to catch any docs written
  after the first pass.

## What the scrubber redacts

Secrets: OpenAI, Anthropic, GitHub (PAT + tokens), AWS access keys, Google API
keys, Slack tokens, JWTs, bearer headers, PEM private-key blocks, and sensitive
`KEY=VALUE` / JSON `"KEY": "VALUE"` assignments (token/secret/password/api_key/…).

PII & infra: email addresses, internal IPs (10/192.168/172.16-31), private
hostnames (`.local`/`.lan`/`.internal`/`.home`/`.corp`), phone numbers, AWS
account IDs inside ARNs, and your username in `/home/<you>` paths (tokenized to
`<USER>`).

## Verification layer (external scanners)

The regex scrubber is a fast first pass over **known** formats. Because regex
can't catch every custom or high-entropy secret, the kit runs a second,
authoritative pass with whichever scanner is installed — and **blocks the share
if anything is still flagged**:

- **betterleaks** (recommended — by the Gitleaks creators) — `betterleaks dir <bundle>`
- **gitleaks** — `gitleaks detect --no-git --source <bundle>`
- **trufflehog** — `trufflehog filesystem <bundle>` (can verify live secrets)
- **detect-secrets** — entropy + plugin baseline

Results land in `DEEPSCAN-REPORT.md`. If none of these are installed, a built-in
Shannon-entropy flag still runs and the report tells you to install one. The
share step re-runs this scan and requires an explicit `share anyway` to override
a finding.

## Recipient protection

The bundle includes `EXECUTABLE-CONTENT.md`: an inventory of every script and
hook in the bundle, a best-effort "what it does," and a scan that flags risky
patterns (remote-exec `curl | bash`, destructive `rm -rf`, base64 exfil,
`/dev/tcp`, and prompt-injection phrasing like "ignore previous instructions").
**Always review flagged files before running anything from a bundle.**

## Known limits

- The scrubber matches **common** formats. A custom/proprietary secret format
  with no recognizable shape and a non-sensitive key name can slip through.
  **Skim `SECRETS-REPORT.md` and the files before sharing.**
- Pattern matching can over-redact (e.g. a 16-char value that looks like a key).
  That's intentional — it fails safe toward redaction.
- It does not inspect binary files or files larger than 512 KB.

## Reporting

Found a leak class the scrubber misses, or a false-negative? Open an issue with
a **sanitized** example (never paste a real secret).
