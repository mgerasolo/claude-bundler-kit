# Detail: Named tools & references

Document the specific named pieces of the setup AS THEY ARE ACTUALLY USED — read real config, no generic descriptions. Copy relevant config/output into `sources/`; record source path + GitHub URL for public projects. Write to `TOOLS-AND-REFERENCES.md`.

Ask the user for the exact names of the tools they rely on and use those names verbatim. Common examples to probe for: a memory tool, a CLAUDE.md authoring approach/reference, a plugin that runs independent code reviews via another model, and any custom skills.

## Entry format (per tool)
```markdown
## <component name>
- **What it does for me:** <plain English, specific to this setup>
- **How I use it:** <trigger / command / when in the flow>
- **Source path:** <original path or "tool, not a local file">
- **Source URL:** <GitHub/homepage or "not found in config">
- **Copy:** sources/<mirrored path> (if a file was copied)
```

If a tool runs an independent code review through a separate model/plugin, document how it's installed, how it authenticates, and the exact command used to trigger a review — and copy one sanitized review output into `sources/`.
