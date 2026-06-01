# Detail: Assemble + verify

## 1. `README.md`
```markdown
# My Claude Code Setup
Everything I use with Claude, copied and explained so you can learn from it.
- CONFIG-INVENTORY.md — config: CLAUDE.md, settings, plugins, MCP, skills, hooks.
- TOOLS-AND-REFERENCES.md — named tools + what each does + source URLs.
- WORKFLOW.md — how I go from idea to shipped code.
- SUMMARY-TABLE.md — index of every component with its source.
- SECRETS-REPORT.md — what the scrubber caught.
- sources/ — redacted copies of every real file.
Read CONFIG-INVENTORY.md and WORKFLOW.md first. Take this and learn from it.
```

## 2. `SUMMARY-TABLE.md`
One row per component:
```markdown
| Component | Type | What it does | Source path | Source URL | Copy in bundle |
|-----------|------|--------------|-------------|------------|----------------|
```

## 3. Verify
- Every summary-table row has a redacted copy under `sources/`.
- Re-scan copies for any secret/token/email that slipped through; redact.
- Build a **"Couldn't find"** list.

## 4. Final print
- Full `SUMMARY-TABLE.md`.
- "Couldn't find" list (or "Nothing missing").
- The chosen share location/command.
