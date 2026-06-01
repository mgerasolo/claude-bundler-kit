# Detail: Document the idea → ship workflow

Reconstruct how the user goes from "idea" to "shipped, working code," using evidence from config, command history, and the components captured. Write `WORKFLOW.md` as a numbered checklist someone else could follow.

Cover:
1. Start of a task — planning, brainstorming, specs?
2. Context across sessions — memory tools, notes.
3. Building — how Claude is driven (TDD? small steps? which skills?).
4. Independent code review — when/how a separate model or review plugin runs, and what's done with its output.
5. Testing & verification — how code is confirmed to work.
6. "Done" definition.

```markdown
# Idea → Ship Workflow
1. <step> — <what I do, which tool/skill, why>
...
## Where each tool fits
| Stage | Tool/skill | What it's for |
|-------|-----------|---------------|
```

Mark inferred lines `(inferred — confirm)`.
