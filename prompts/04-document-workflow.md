# Detail: Document the idea → ship workflow

Reconstruct how the user goes from "idea" to "shipped, working code," using evidence from config, command history, and the components captured. Write `WORKFLOW.md` as a numbered checklist someone else could follow.

Read `PROCESS-FLOW.md` (worktree, issue-tracker, and command-usage signals) and
fold its evidence into the answers below.

Cover:
1. Start of a task — planning, brainstorming, specs?
2. Context across sessions — memory tools, notes.
3. Building — how Claude is driven (TDD? small steps? which skills?).
4. **Worktrees** — does he use Claude Code worktrees? Git worktrees? How (one per
   task/branch/experiment)? Cite PROCESS-FLOW.md signals.
5. **Issue / work tracking** — GitHub Issues? Linear? something else? How does a
   task go from idea → tracked item → done? Cite PROCESS-FLOW.md signals.
6. Independent code review — when/how a separate model or review plugin runs, and
   what's done with its output.
7. Testing & verification — how code is confirmed to work.
8. "Done" definition.

```markdown
# Idea → Ship Workflow
1. <step> — <what I do, which tool/skill, why>
...
## Where each tool fits
| Stage | Tool/skill | What it's for |
|-------|-----------|---------------|
```

Mark inferred lines `(inferred — confirm)`.
