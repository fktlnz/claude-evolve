---
description: Interactively author a structured, reusable SKILL.md from a workflow the user just did or is about to repeat — not a one-line auto-promoted lesson.
argument-hint: "[name of the workflow/skill to build]"
---

You are authoring a **structured skill** at `.claude/skills/<name>/SKILL.md`. This is a
deliberate authoring act, distinct from `claude-evolve`'s automatic `evolve-*` skills:

- `evolve-*` skills (written by `consolidate.py`) are a **single observation** —
  one correction or one recurring build error, auto-generated the moment it recurs twice.
  No judgment involved, no procedure captured, just "this happened before."
- A skill built by this command is a **reusable procedure**: multiple steps, known
  pitfalls, a way to verify it worked. Write one when the user explicitly asks ("make
  this a skill", "/claude-evolve:build-skill"), or when you judge a workflow you just
  completed is complex enough and will recur often enough to be worth the file — in
  which case, propose it and wait for the user to confirm before writing anything. Never
  silently create one.

Ported from how the Hermes Agent authors skills: `When to Use` triggers, numbered
`Procedure` steps each with a checkable completion criterion, a `Pitfalls` section for
known traps, and a `Verification` checklist — not prose that just describes what
happened.

## Before writing anything

1. Check `.claude/skills/` for an existing skill that already covers this ground —
   extend it instead of creating a near-duplicate. `search_files` for the topic.
2. Check `.claude/evolve/learnings.json` for related `fix`/`correction`/`build_failure`
   records (`seen_count`, `body`) — fold concrete, hard-won details from there into the
   `Pitfalls` section instead of re-deriving them from memory.
3. Confirm with the user: skill name (lowercase, hyphens), and roughly what should and
   should NOT trigger it (the `description` is what Claude Code matches against future
   tasks — vague descriptions mean the skill never gets invoked).

## SKILL.md structure to produce

```markdown
---
name: <lowercase-hyphenated-name>
description: >-
  Use when <concrete trigger, ≤160 chars, no marketing words>.
metadata:
  source: claude-evolve build-skill
  created: <ISO date>
---

# <Title>

1-2 sentences: what this does, what it explicitly does NOT do.

## When to Use

- Bulleted triggers (positive cases)
- "Don't use for: ..." (counter-triggers, if any apply)

## Prerequisites

Exact tools/env vars/installs needed, if any. Omit the section if none.

## Procedure

1. Step with a checkable completion criterion.
2. Step with a checkable completion criterion.
...

## Pitfalls

- Known traps, things that look broken but aren't, edge cases hit before.
  Pull concrete ones from `.claude/evolve/learnings.json` if relevant (cite what
  recurred and how many times).

## Verification

- [ ] Checkable item
- [ ] Checkable item
```

Rules while drafting:
- **`description` is budget, paid on every future turn** — make every word a trigger
  signal, not a restatement of the title. This is what decides whether Claude Code ever
  invokes the skill again.
- **Every `Procedure` step ends with something checkable** ("tests pass", "file exists
  at X", "returns 200") — not "do the thing carefully."
- **No marketing language, no filler** ("be careful", "use best practices" are no-ops —
  replace with a concrete check or cut the line).
- Keep it tight: a simple skill is ~60-100 lines, a complex one ~150-200. Bulky reference
  material (long code samples, large tables) goes in a sibling `references/*.md` file
  inside the skill directory, linked from `SKILL.md`, not inlined.

## After writing

1. Show the user the full file content before (or right after) writing it — they should
   see exactly what gets auto-loaded in future sessions.
2. Write it to `.claude/skills/<name>/SKILL.md` (create the directory).
3. Tell the user: this skill is now auto-discoverable; Claude Code loads it when a future
   task's description matches. It is NOT touched by `claude-evolve`'s consolidation loop
   (that only writes to `evolve-*` directories) — editing or removing it is a normal file
   operation, not a `/claude-evolve:review` action.

## Pitfalls

1. **Writing the skill before the user confirms the trigger description.** A skill with
   a vague `description` never gets invoked — confirm the concrete trigger first.
2. **Silently creating a skill from a judgment call.** Propose it, wait for a yes.
3. **Duplicating an existing skill instead of extending it.** Always search first.
4. **Padding `Procedure` with unchecke­d narration.** Every step needs a completion
   criterion or it isn't a procedure, it's a description.
5. **Ignoring `.claude/evolve/learnings.json`.** Concrete pitfalls hard-won in this
   project (with a `seen_count`) are stronger than generic advice — pull them in.

## Verification

- [ ] Searched `.claude/skills/` for an existing skill to extend first
- [ ] Checked `.claude/evolve/learnings.json` for relevant fixes/corrections to fold in
- [ ] Confirmed name and trigger description with the user before writing
- [ ] `description` states a concrete trigger, not a restatement of the title
- [ ] Every `Procedure` step has a checkable completion criterion
- [ ] File written to `.claude/skills/<name>/SKILL.md`
- [ ] Shown the full content to the user
