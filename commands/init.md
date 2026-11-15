---
description: Initialize the claude-evolve store in the current project
---

Initialize claude-evolve for this project:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/status.py"
```

The store lives at `.claude/evolve/` and is created automatically on the first captured
signal — no manual init is strictly required. If the user wants learnings committed to
the repo, tell them to add `.claude/evolve/` to git; if they want them local-only, add
`.claude/evolve/` to `.gitignore`.

**Strongly recommend** the user wire the highest-reliability channels: add these lines to
the project's `CLAUDE.md`:

```
@.claude/evolve/LEARNINGS.md
@.claude/evolve/PROJECT_CONTEXT.md
```

`claude-evolve` regenerates `.claude/evolve/LEARNINGS.md` (corrections/build-failures/fixes)
and `.claude/evolve/PROJECT_CONTEXT.md` (durable project/user background, captured via
explicit `@remember:` / `@note:` / `@background:` / `@fact:` lines in a prompt — or the
Japanese `覚えておいて:` / `メモ:` / `背景:`) on every turn with the top lessons/facts.
Because `CLAUDE.md` is always read with top priority, this guarantees Claude applies
them — more reliable than auto-loaded skills (which only fire when their description
matches the task) or SessionStart injection (which is capped). Offer to add the import
lines to their CLAUDE.md for them if they aren't there yet.

Explain the loop in one or two lines so the user knows what to expect:
corrections, build failures and fixes are captured as they happen → consolidated on each
turn-end → recurring lessons auto-become skills under `.claude/skills/` → injected into
the next session. Nothing else for them to do.
