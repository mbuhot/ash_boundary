# AshBoundary — Unattended Build Process

This governs how each unit of work in GOAL.md gets built, reviewed, and shipped
during an unsupervised `/goal` run. Adapted from a ticket-driven process used
on another project — two departures are called out inline rather than left
implicit: there is no ticket/QA system here (GOAL.md is the sole binding
spec), and commits carry NO AI attribution of any kind — no Co-Authored-By
trailer, no "Generated with" line. The repo's history has been rewritten once
already to strip this out; do not reintroduce it.

1. **Select a unit of work** — pick the next incomplete, appropriately-scoped
   item off GOAL.md's Deliverables checklist (track progress with
   TaskCreate/TaskUpdate). Right-size it: "the transformer spike" is a unit;
   "all four sample projects" is not. Note which GOAL.md section(s) — Core
   mechanism, Confirmed design rules, a specific Deliverables bullet — bind
   this unit.

2. **Implement** — spawn an implementer agent with the `Agent` tool. Model by
   difficulty: Sonnet high by default, Haiku for trivial mechanical edits,
   Opus for genuinely hard foundational work (the Spark transformer/Boundary
   injection spike is the clear candidate). The prompt states: the relevant
   GOAL.md section(s) verbatim, the Confirmed design rules that bind it, scope
   boundaries (what this unit deliberately excludes), environment quirks
   (Elixir/Mix/Ash/Spark/Boundary versions in use), the gates (step 6), where
   the code lives, "do the work yourself; do NOT spawn subagents", "do NOT
   commit", and that ambiguities get a sensible documented default rather than
   a pause.

3. **Adversarial review** — spawn a SEPARATE reviewer agent (Opus) with no
   sight of the implementer's reasoning, only the diff and the same GOAL.md
   sections. It must verify claims with evidence — actually run `mix test`,
   `mix credo --strict`, `mix dialyzer`, compile the affected sample project,
   and for anything touching exports/violations, confirm a deliberately
   non-exported reference genuinely fails to compile — not eyeball the diff.
   Feed it the implementer's own "scrutinize this" list. Require structured
   findings via the `ReportFindings` tool: one entry per finding (file, line,
   summary, failure scenario, verdict) plus explicit one-line "checked and
   clean" entries for areas that passed.

4. **Fix** — send findings back to the SAME implementer (`SendMessage`,
   context intact) with explicit instructions per finding, including which
   findings to skip and why (e.g. out of scope for this unit, already covered
   by an accepted limitation in GOAL.md).

5. **Verify** — resume the SAME reviewer (`SendMessage`) for a focused
   verification pass: re-run its own original failing probes independently;
   verdict is safe-to-commit or another fix round. Nothing commits without
   this verdict. On tiny, purely mechanical units (a typo, a moduledoc tweak)
   this pass may be trimmed, but keep it full for anything touching the
   transformer, the verifier, export/deps computation, or a sample project
   that demonstrates a violation.

6. **Gate** — implementer and reviewer must both show, on the current tree:
   `mix format --check-formatted` clean, `mix credo --strict` clean,
   `mix dialyzer` clean, `mix test` green, and — when the unit touches a
   sample project — that sample's own compile/test check green, *including*
   the deliberate-violation sample actually failing to compile in the
   expected way (a green check there means the violation was NOT caught,
   which is a failure, not a pass).

7. **Commit** — orchestrator (you, in the main `/goal` run, not a subagent)
   commits directly on `main`: conventional prefix, prose body (what + why,
   not a diff restatement), noting which GOAL.md item this closes. NO
   Co-Authored-By trailer, NO "Generated with Claude Code" line, no AI
   attribution of any form — the user has stated this explicitly and
   strongly. Stage only this unit's files; exclude scratch/task-tracking
   artifacts (batch-orchestration files, if any accumulate, get their own
   commit).

8. **Push** — push to `origin/main` immediately after each commit. There is
   no separate driver reviewing commits as they land in this project, so the
   gate in step 6 is the only backstop — do not weaken it to move faster.
