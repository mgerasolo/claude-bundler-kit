# Detail: Gather config (copy + summarize + source-reference)

For each item: (a) copy the real file into `<name>-bundle/sources/` (redacted, mirroring original layout), and (b) write an entry in `CONFIG-INVENTORY.md`.

## Crawl and copy
- **CLAUDE.md files** — global (`~/.claude/CLAUDE.md`) and every project `CLAUDE.md` / `.claude/CLAUDE.md`.
- **Settings** — `~/.claude/settings.json`, `settings.local.json`, project `.claude/settings.json`.
- **Plugins / MCP servers** — `.claude.json`, `.mcp.json`, plugin/MCP manifests.
- **Skills** — `~/.claude/skills/` and project `.claude/skills/` (copy each `SKILL.md`).
- **Slash commands** — `~/.claude/commands/` and project `.claude/commands/`.
- **Hooks** — settings hook entries + the scripts they call.

## Entry format
```markdown
### <component name>
- **Type:** CLAUDE.md | settings | plugin | MCP server | skill | command | hook
- **Summary:** <2-4 plain-English sentences>
- **Source path:** <original absolute path>
- **Source URL:** <GitHub/homepage if public; else "not found in config">
- **Copy:** sources/<mirrored path>
```

Mirror original layout under `sources/`. Redact secrets before copying. For plugins/MCP, hunt for the GitHub/homepage URL in manifests/package.json/install commands. End with: "Captured N components across M files."
