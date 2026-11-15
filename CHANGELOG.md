# Changelog

## Unreleased — Hermes extensions (fktlnz fork)

### Docs: external-communication audit (README)
- Audited the full repo for network calls: no `urllib`/`requests`/`socket`/analytics
  SDKs anywhere in `scripts/`; every hook is local file I/O only. The only `https://`
  occurrences in the repo are in `README.md` (prose) and `install.sh` (the user-run
  `git clone` install step).
- Documented the one exception: `EVOLVE_LLM=1` makes `consolidate.py`'s `_llm_polish()`
  call `claude -p <lesson text>` automatically from the `Stop` hook, every turn, with no
  explicit user action that turn — sends up to ~600 chars of lesson/correction/error text
  as a new model API call. Default is unset (off). Recommended to leave it off on
  corporate/restricted machines. Added to the README Security section.

### Added: `/claude-evolve:build-skill` — deliberate structured-skill authoring
- Ports the Hermes Agent skill-authoring conventions as a Claude Code slash command:
  produces a full `SKILL.md` (frontmatter, `When to Use`, `Prerequisites`, numbered
  `Procedure` with a checkable completion criterion per step, `Pitfalls`, `Verification`)
  — not the one-line `evolve-*` auto-promoted skills `consolidate.py` already writes.
- Explicitly distinct from auto-promotion: only runs on user request or explicit proposal
  + confirmation, never silently. Searches `.claude/skills/` first to extend instead of
  duplicating, and pulls concrete `fix`/`correction`/`build_failure` entries out of
  `.claude/evolve/learnings.json` into the `Pitfalls` section instead of inventing generic
  advice.
- Verified end-to-end in a live interactive session (tmux): confirmed the trigger
  description via an `AskUserQuestion` prompt, generated a `.claude/skills/npm-build-fix/
  SKILL.md` that correctly folded in a seeded `learnings.json` fix (seen 3x) as the first
  Pitfall, with every Procedure step carrying a checkable "Done when" criterion.

### Added: `/claude-evolve:grill` — grill-me requirements interview
- Ports the Hermes Agent `grill-me` skill as a Claude Code slash command: models a plan
  as a design tree, interviews the user in "frontier rounds" (every answerable question
  asked at once, each with a recommendation), never writes code during the interview.
- Checks `.claude/evolve/PROJECT_CONTEXT.md`/`LEARNINGS.md` first so prior decisions and
  lessons aren't re-asked.
- On alignment, offers to draft `@background:`/`@fact:` lines for the settled decisions —
  bridges requirements-gathering directly into the new fact-memory channel below, instead
  of the decisions evaporating at the end of the conversation.
- Verified end-to-end: command loads via plugin, frontier-round format holds up in a real
  session, and the "propose fact lines on alignment" step behaves correctly (including
  declining gracefully when there's no session to summarize — each `claude -p` call is an
  independent session; this is expected in interactive use within one conversation).

### Added: "fact" channel — durable project/user memory
- **New signal type `fact`**: explicit-marker capture (`@remember:`, `@note:`,
  `@background:`, `@fact:`, and Japanese `覚えておいて:` / `メモ:` / `背景:`) via
  `UserPromptSubmit`. Unlike `correction` (heuristic phrase matching, tolerant of false
  positives), facts require an explicit marker — mirrors Hermes writing memory only from
  deliberate intent, never a guess.
- **`store.FACT_MAX_CHARS` budget** (`EVOLVE_MEMORY_MAX_CHARS`, default 1500): once the
  active fact set exceeds the budget, the least-confident facts (lowest frequency x
  recency) are archived — not deleted, just excluded from injection/export — to make
  room. Mirrors Hermes' memory tool: consolidate/evict before growing unbounded.
- **`.claude/evolve/PROJECT_CONTEXT.md`**: a separate CLAUDE.md-importable channel from
  `LEARNINGS.md`. Facts are durable background to carry forward (who the user is, what
  phase the project is in), not mistakes to avoid — kept out of the lessons file so one
  doesn't drown out the other.
- **`inject.py` reserves a fact slice**: facts get their own capped block in
  `SessionStart` injection so a build-failure-heavy project never crowds out project
  context.
- Facts are never promoted to skills (`_promote` still only accepts `fix`/`correction`/
  `build_failure`) — background context isn't a trigger-matched procedure.

## 0.1.0 — 2026-06-19

### Resurfacing reliability
- **Trigger-oriented skill descriptions**: promoted skills now describe WHEN to use them
  ("Use when `cargo` fails with E0382…") instead of restating the observation, so Claude
  Code actually invokes them when the task matches.
- **CLAUDE.md channel**: `scripts/export_md.py` regenerates `.claude/evolve/LEARNINGS.md`
  every turn; add `@.claude/evolve/LEARNINGS.md` to your project CLAUDE.md for the
  highest-reliability resurfacing (read on every turn, top priority).

### Hardening (pre-release, adversarial review + eval/AB harness)
- **Concurrency**: file-lock (`fcntl`) around all `learnings.json` mutations; signals
  claimed by atomic rename (`take_signals`) so racing hooks never lose a signal.
- **Timezone**: age math fixed to parse UTC (`calendar.timegm`) — curator/confidence were
  wrong by the local offset (broke on every non-UTC machine).
- **Noise filter**: env-noise guard now applies ONLY to raw build-error text at capture —
  no longer silently drops corrections/fixes that mention "api key", "rate limit", etc.
- **Dedup**: error-code matcher anchored to known prefixes (no false codes like `GMT2026`);
  `normalize` keeps quoted identifiers so `'Foo'` vs `'Bar'` errors stay distinct.
- **Slugs**: unicode-only titles (e.g. Vietnamese) get hash-suffixed unique skill dirs
  instead of all collapsing to one `evolve-/` dir.
- **Injection safety**: injected context + SKILL.md bodies sanitized and framed as
  untrusted reference data (supply-chain hardening for shared stores).
- **Robustness**: build-error field probing across versions, unique tmp on save,
  signal-size guard, `EVOLVE_DEBUG` log, accurate injection char cap.
- Added `tests/eval.py` (17/17) and `tests/ab.py` (parameter A/B study).

### Initial

Initial release. Self-improving skill loop for Claude Code, ported from the Hermes Agent
learning loop.

- **Capture** hooks: corrections (UserPromptSubmit), build/test failures
  (PostToolUseFailure), fixes (PostToolUse success-after-failure pairing).
- **Consolidate** (Stop): signals → learnings with patch-not-append dedup by normalized
  key, environment/transient noise guardrails.
- **Promote**: lessons seen ≥ `EVOLVE_PROMOTE_AT` become auto-loading `.claude/skills/`
  SKILL.md files.
- **Inject** (SessionStart): real learning content (ranked by frequency × recency) added
  to context — closing the loop that count-only systems leave open.
- **Curate**: ACTIVE → STALE (60d) → ARCHIVED (120d) state machine.
- Commands: `/claude-evolve:status`, `:review`, `:init`. Agent: `learning-reviewer`.
- Zero pip dependencies; model-agnostic core with optional `claude -p` polish.
- Installable via Claude Code marketplace (Gitea + GitHub mirror) or `install.sh`.
