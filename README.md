# Test Ratchet

[![Marketplace](https://img.shields.io/badge/Marketplace-Test%20Ratchet-2ea44f?logo=github)](https://github.com/marketplace/actions/test-ratchet)
[![Release](https://img.shields.io/github/v/release/motchalini-llc/test-ratchet?sort=semver)](https://github.com/motchalini-llc/test-ratchet/releases)
[![self-test](https://github.com/motchalini-llc/test-ratchet/actions/workflows/self-test.yml/badge.svg)](https://github.com/motchalini-llc/test-ratchet/actions/workflows/self-test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A zero-dependency GitHub Action that **stops tests from being quietly disabled to keep CI green**.

A green test run hides two cheats: tests that were **skipped** (`it.skip`, `@pytest.mark.skip`, `xfail`) instead of fixed, and a stray **focused** test (`it.only` / `describe.only`) that makes the runner execute *only that block* while CI still reports ✅. Test Ratchet counts skipped tests and **fails the PR if the count goes up** — and bans focused tests outright — so a green suite stays honestly green (a ratchet).

It does **not** rerun your tests. It catches what a passing test run can't show you: a test silenced or narrowed instead of fixed.

**Why now:** AI coding agents are very good at making CI green — and the fastest route to green is `it.skip`, not a fix. A reviewer can miss one skipped test in a 400-line diff; a counter can't. No AI, no SaaS, no config: the whole gate is [one bash script](gate.sh) you can read.

> 📖 Launch article: [Your AI makes CI green by cheating. I built three GitHub Actions to stop it.](https://dev.to/motchalini/your-ai-makes-ci-green-by-cheating-i-built-three-github-actions-to-stop-it-4pal) · [日本語版 (Zenn)](https://zenn.dev/motchalini/articles/99f743d923fb54)

[![Demo: one 'quick fix' PR trips all three ratchet gates](https://raw.githubusercontent.com/motchalini-llc/ratchet-demo/main/docs/ratchet-demo.gif)](https://github.com/motchalini-llc/ratchet-demo/pull/1)

> 🔴 **Live demo:** [ratchet-demo#1](https://github.com/motchalini-llc/ratchet-demo/pull/1) — one "quick fix" PR that silences the type checker, skips a test and mutes the linter. All three gates go red with inline annotations.

## The Ratchet family

Three zero-dependency PR gates, each blocking a different way a green check gets faked:

| Action | Blocks the cheat |
|---|---|
| [Type Ratchet](https://github.com/marketplace/actions/type-ratchet) | type escape hatches — `any` / `as any` / `# type: ignore` |
| [Test Ratchet](https://github.com/marketplace/actions/test-ratchet) **← this repo** | disabled tests — `it.skip` / `.only` / `@pytest.mark.skip` |
| [Suppress Ratchet](https://github.com/marketplace/actions/suppress-ratchet) | linter suppressions — `eslint-disable` / `biome-ignore` / `# noqa` |

## Usage

Add one step to a PR workflow:

```yaml
# .github/workflows/test-ratchet.yml
name: Test Ratchet Gate
on:
  pull_request:
    branches: [main]
jobs:
  gate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: motchalini-llc/test-ratchet@v1
        with:
          language: typescript   # python | typescript | auto
```

### TypeScript (also run the suite)

```yaml
      - uses: actions/checkout@v4
      - run: corepack enable
      - run: pnpm install --frozen-lockfile
      - uses: motchalini-llc/test-ratchet@v1
        with:
          language: typescript
          test-command: pnpm test
```

### Python (also run pytest)

```yaml
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v5
      - run: uv sync --frozen
      - uses: motchalini-llc/test-ratchet@v1
        with:
          language: python
          baseline-skip: '3'        # legitimately skipped tests already in the suite
          test-command: uv run pytest
```

## Inputs

| Input | Default | Description |
|---|---|---|
| `language` | `auto` | `python` \| `typescript` \| `auto` (detects from `pyproject.toml` / `tsconfig.json`) |
| `paths` | `.` | Space-separated directories to scan for test files |
| `baseline-skip` | `0` | Max allowed skipped/xfail test count |
| `baseline-file` | `''` | Optional file defining `SKIP_BASELINE` (overrides the numeric input) |
| `forbid-only` | `true` | Fail if any focused test (`.only`) is found |
| `test-command` | `''` | Optional command also run as part of the gate (e.g. `pnpm test`) |
| `working-directory` | `.` | Directory to run in |

## What counts

| | skipped / disabled (ratcheted) | focused (banned) |
|---|---|---|
| **Python** | `@pytest.mark.skip` / `skipif` / `xfail`, `pytest.skip(...)`, `unittest` `@skip` / `skipIf` / `skipUnless`, `.skipTest(...)` | — (pytest has no focused-test concept) |
| **TypeScript** | `it`/`test`/`describe`/`bench`.`skip` / `.todo` / `.fails`, `xit` / `xtest` / `xdescribe` | `it`/`test`/`describe`/`bench`.`only` |

Only test files are scanned: Python `test_*.py` / `*_test.py`, TypeScript `*.test.ts(x)` / `*.spec.ts(x)`.

## Output

On failure the action:

- Emits **inline annotations** (`::error`) on the exact offending lines, so violations show up right on the PR's *Files changed* tab.
- Writes a **job summary** table (skipped count vs. baseline, focused count) to the run summary.

## Tightening the ratchet

When you re-enable a skipped test and the count drops below the baseline, the gate prints `IMPROVED` — lower the baseline and commit it. The count can only go down.

## License

MIT
