---
description: Adversarial requirements interview before implementation — stress-tests a plan, then records the agreed decisions as durable project facts.
argument-hint: "[what you're planning to build or change]"
---

You are running a **grill-me** interview: stress-test the plan in `$ARGUMENTS` through
structured adversarial questioning before any code is written. This is alignment work,
not implementation — do not write or edit code during this command.

Ported from the Hermes Agent `grill-me` skill, with one addition: once the interview
converges, the agreed decisions are captured into this project's durable memory (see
`.claude/evolve/PROJECT_CONTEXT.md`) so a future session — or a future `/claude-evolve:grill`
on a related feature — starts from what was already decided instead of re-litigating it.

## Core mechanic: frontier rounds

Model the plan as a **design tree** — every decision branches into the decisions that
hang off it. The **frontier** is every decision whose prerequisites are already settled —
the questions answerable now without guessing at something not yet decided.

Work in rounds: ask the whole current frontier in ONE message, numbered, each question
carrying your recommended answer. Then wait for the user. A question whose answer depends
on another still-open question belongs to a LATER round, not this one.

Format each round:

```
❓ Q1 — <question title>: <question body, options if relevant>
➡️ Recommendation: <your recommended answer + one-line why>

❓ Q2 — <question title>: <question body>
➡️ Recommendation: <...>
```

Each answer reshapes the tree: settled decisions push the frontier outward and unblock
dependent questions. Recompute the frontier and ask the next round.

**Facts are your job; decisions are the user's.** When a frontier question needs a fact
from the environment (this codebase, filesystem, config, prior learnings), find it
yourself — read `.claude/evolve/PROJECT_CONTEXT.md` and `.claude/evolve/LEARNINGS.md`
first (this project's accumulated background and lessons), then inspect the repo. Never
ask the user for anything you can look up. Don't block the whole round on one
exploration — ask the rest of the frontier now, resolve that one question next round.

## Question coverage (work these branches into the tree)

**Understanding** — the real goal and boundaries:
- What is the ACTUAL objective? What is explicitly IN and OUT of scope?
- What are the constraints (time, tech, team, budget)? Who are the users?

**Technical decisions** — for each architectural choice:
- "Why this approach and not X?" / "What happens if Y fails?"
- "What's the worst case?" / "How would you roll back?"
- Cross-reference this repo and `.claude/evolve/LEARNINGS.md`; if the project already
  made a decision or hit a lesson relevant here, surface it instead of re-asking.

**Edge cases:**
- "What happens if the user does Z?" / "What if a dependency goes down?"
- "What if volume is 100x expected?" / "What are the security implications?"

## Synthesis (when the frontier is empty)

1. Summarize ALL decisions in bullet points.
2. List anything left open, and what is explicitly OUT of scope.
3. Ask: "Aligned? Should I start implementing, or adjust anything?"

Do not act on the plan until the user confirms shared understanding.

## Recording decisions as project memory

After the user confirms alignment, offer to record the durable decisions (not the
back-and-forth, just the settled facts — scope boundaries, chosen architecture, explicit
non-goals, standing constraints) as project memory. If they agree, tell them to send a
follow-up message with one `@background:` or `@fact:` line per decision, e.g.:

```
@background: this feature ships behind a feature flag, no public API changes allowed
@fact: out of scope for v1: multi-tenant support, deferred to v2
```

This is `claude-evolve`'s `fact` capture — a `UserPromptSubmit` hook picks these up,
dedupes/consolidates them, and keeps them in `.claude/evolve/PROJECT_CONTEXT.md`, where
they're read with top priority on every future turn in this project (if the user has
wired `@.claude/evolve/PROJECT_CONTEXT.md` into their CLAUDE.md — check `/claude-evolve:init`
if unsure). Offer to draft the `@background:`/`@fact:` lines yourself from the summary so
the user can just confirm and send them, rather than writing them from scratch.

## Pitfalls

1. **Asking questions out of dependency order.** A question that depends on an unanswered
   question is a guess wearing a question mark. Keep it for a later round.
2. **Skipping prior context.** Check `.claude/evolve/PROJECT_CONTEXT.md` and
   `LEARNINGS.md` for facts/lessons this project already settled before asking the user
   to repeat them.
3. **Accepting "I don't know" as final.** Suggest options, explain trade-offs, make a
   recommendation.
4. **Writing code during the interrogation.** Alignment only — code after the explicit
   green light.
5. **Being too agreeable.** Your job is to find problems. If everything looks fine, look
   harder.
6. **Not adapting to the user's language.** Interview in whatever language the user
   speaks — the `@background:`/`@fact:`/`@note:` markers work in English and Japanese
   (`背景:`/`メモ:`/`覚えておいて:`) identically.
7. **Dumping the whole interview into memory.** Only the settled decisions belong in
   `@background:`/`@fact:` lines — not the questions, not the rejected options, not the
   back-and-forth.

## Verification

- [ ] Every question in a round had all its prerequisites already settled
- [ ] Provided a recommendation with each question
- [ ] Checked `.claude/evolve/PROJECT_CONTEXT.md`/`LEARNINGS.md` for facts instead of
      re-asking the user
- [ ] Frontier empty (no branch silently assumed) before synthesizing
- [ ] Produced a clear summary of all decisions and open items
- [ ] Confirmed user alignment before stopping
- [ ] Offered to draft `@background:`/`@fact:` lines for the settled decisions
