# Roadmap

Guiding principle: **ship the light, free version first; build the heavy version only once there's demand.** The gate (counting skipped tests, banning focused tests, failing the PR) is the core value — everything else is demand-driven.

## Shipped

- v1 gate: Python (`@pytest.mark.skip`/`skipif`/`xfail`, `pytest.skip`, `unittest` skips) and TypeScript (`.skip`/`.todo`/`.fails`, `xit`/`xdescribe`), auto-detected
- Focused-test ban (`it`/`describe.only`) — a stray `.only` silently narrows CI to a subset
- Baseline ratchet for skips (count can only go down), `baseline-file` support
- Inline PR annotations + job summary table
- Optional `test-command` (run `pytest` / `pnpm test` alongside the gate)
- Self-test on fixtures; published to GitHub Marketplace

## Next (when there's a clear signal)

- **Demo GIF in the README** — show a PR going red on a stray `.only`, then green after removing it. (Cheap, lifts conversion. Do this early.)
- **Assertion-free test detection (heavy version)** — flag tests that run but assert nothing ("green but verifies nothing"). Needs more than grep: parse the AST or the test runner's JSON output. Build only after users ask for it.
- **More precise detection (opt-in)** — back the TypeScript count with the ESLint `no-only-tests` / `vitest` plugins to avoid comment/string false positives.

## Ideas backlog

- Per-path / per-package baselines (monorepos).
- A config file (`.test-ratchet.yml`) as an alternative to action inputs.
- More runners (Go `t.Skip`, Rust `#[ignore]`, JUnit `@Disabled`) if requested.
- `warn-only` mode (annotate without failing) for gradual adoption.
- Auto-suggest lowering the baseline when the skip count drops (IMPROVED state).

## Later / business

- Marketplace verified publisher (requires the org) once monetizing.
- Decide free vs. paid tiers based on usage and requests.

## Non-goals

- Re-running the test suite for you (that's your existing CI's job; this catches what a green run can't: silencing vs. fixing).
- Becoming a general linter.

## How to validate / what to watch

Marketplace views, stars, issues, and "I tried it" mentions. Issues are the best signal for what to build next.
