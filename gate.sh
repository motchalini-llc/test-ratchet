#!/usr/bin/env bash
# Test Ratchet gate (language-agnostic, zero-dependency).
#
# Given a test suite that passes, this ensures tests aren't quietly disabled
# to keep CI green:
#   Python:     @pytest.mark.skip/skipif/xfail, pytest.skip(), unittest @skip
#   TypeScript: it/test/describe.skip, .todo, .fails, xit/xdescribe
# and bans focused tests outright (it/describe.only) — a stray .only makes the
# runner execute only that subset while CI still reports green.
#
# It does NOT rerun your tests (that's your test runner's job). It catches what
# a green test run can't show you: tests silenced or narrowed instead of fixed.
#
# Inputs come from INPUT_* env vars (set by action.yml). Runs locally with the
# same env.
set -uo pipefail

cd "${INPUT_WORKING_DIRECTORY:-.}"

# GitHub inline annotations (::error) need paths relative to the repo root, so
# prefix offending paths when working-directory is not ".".
ANNOT_PREFIX=""
[ "${INPUT_WORKING_DIRECTORY:-.}" != "." ] && ANNOT_PREFIX="${INPUT_WORKING_DIRECTORY%/}/"

LANGUAGE="${INPUT_LANGUAGE:-auto}"
if [ "$LANGUAGE" = "auto" ]; then
  if [ -f pyproject.toml ] || [ -f setup.cfg ] || [ -f mypy.ini ] || [ -f setup.py ]; then
    LANGUAGE=python
  elif [ -f tsconfig.json ] || [ -f package.json ]; then
    LANGUAGE=typescript
  else
    echo "Could not auto-detect language. Set 'language' to python or typescript." >&2
    exit 2
  fi
fi

case "$LANGUAGE" in
  python)
    # pytest's default test-file conventions.
    INCLUDES=(--include="test_*.py" --include="*_test.py")
    SKIP_PAT='@pytest\.mark\.(skip|skipif|xfail)\b|\bpytest\.skip\(|@(unittest\.)?skip(Unless|If)?\b|\.skipTest\('
    ONLY_PAT=''   # pytest has no focused-test concept
    ;;
  typescript)
    INCLUDES=(--include="*.test.ts" --include="*.test.tsx"
              --include="*.spec.ts" --include="*.spec.tsx")
    SKIP_PAT='\b(it|test|describe|bench)\.(skip|todo|fails)\b|\bx(it|test|describe)\b'
    ONLY_PAT='\b(it|test|describe|bench)\.only\b'
    ;;
  *)
    echo "Unknown language: $LANGUAGE" >&2
    exit 2
    ;;
esac

# Baseline: the numeric input is the default; baseline-file overrides it
# (SKIP_BASELINE).
SKIP_BASELINE="${INPUT_BASELINE_SKIP:-0}"
if [ -n "${INPUT_BASELINE_FILE:-}" ] && [ -f "${INPUT_BASELINE_FILE}" ]; then
  # shellcheck disable=SC1090
  source "${INPUT_BASELINE_FILE}"
fi
FORBID_ONLY="${INPUT_FORBID_ONLY:-true}"

read -ra PATHS <<< "${INPUT_PATHS:-.}"

# grep exits 1 on zero matches (fatal under pipefail), so wrap with { ...; || true; }
# and count lines with wc. An empty pattern would match everything, so guard it.
count() {
  [ -n "$1" ] || { echo 0; return; }
  { grep -rnIE "${INCLUDES[@]}" "$1" "${PATHS[@]}" || true; } | wc -l | tr -d ' '
}
# List offending locations and emit GitHub Actions inline annotations (::error).
report() {
  local pat="$1" kind="$2" m file line
  [ -n "$pat" ] || return 0
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    file="${m%%:*}"
    file="${file#./}"   # paths default to "."; drop the leading ./ for clean annotations
    line="$(printf '%s' "$m" | cut -d: -f2)"
    echo "  ${ANNOT_PREFIX}${file}:${line}"
    echo "::error file=${ANNOT_PREFIX}${file},line=${line}::Test Ratchet: ${kind}"
  done < <(grep -rnIE "${INCLUDES[@]}" "$pat" "${PATHS[@]}" 2>/dev/null || true)
}

# Write a results table to the job summary if GITHUB_STEP_SUMMARY is set.
write_summary() {
  [ -n "${GITHUB_STEP_SUMMARY:-}" ] || return 0
  local s o
  [ "$SKIP_NOW" -gt "$SKIP_BASELINE" ] && s="❌ regression" || s="✅"
  {
    echo "## Test Ratchet"
    echo ""
    echo "| metric | now | limit | status |"
    echo "|---|---|---|---|"
    echo "| skipped/xfail | ${SKIP_NOW} | ${SKIP_BASELINE} | ${s} |"
    if [ -n "$ONLY_PAT" ]; then
      [ "$FORBID_ONLY" = "true" ] && [ "$ONLY_NOW" -gt 0 ] && o="❌ forbidden" || o="✅"
      echo "| focused (.only) | ${ONLY_NOW} | 0 | ${o} |"
    fi
    echo ""
    echo "language \`${LANGUAGE}\` · paths \`${PATHS[*]}\`"
  } >> "$GITHUB_STEP_SUMMARY"
}

SKIP_NOW=$(count "$SKIP_PAT")
ONLY_NOW=$(count "$ONLY_PAT")

echo "language=${LANGUAGE}  paths=${PATHS[*]}"
echo "skipped/xfail:   now=${SKIP_NOW}  baseline=${SKIP_BASELINE}"
[ -n "$ONLY_PAT" ] && echo "focused(.only):  now=${ONLY_NOW}  forbid-only=${FORBID_ONLY}"

status=0
if [ "$SKIP_NOW" -gt "$SKIP_BASELINE" ]; then
  echo "❌ REGRESSION: skipped/xfail tests increased (${SKIP_NOW} > ${SKIP_BASELINE})"
  report "$SKIP_PAT" "skipped/disabled test not allowed (exceeds baseline)"
  status=1
fi
if [ -n "$ONLY_PAT" ] && [ "$FORBID_ONLY" = "true" ] && [ "$ONLY_NOW" -gt 0 ]; then
  echo "❌ FORBIDDEN: focused test(s) found — .only makes CI run only a subset (${ONLY_NOW})"
  report "$ONLY_PAT" "focused test (.only) not allowed — it makes CI skip the rest"
  status=1
fi
if [ "$status" -eq 0 ]; then
  if [ "$SKIP_NOW" -lt "$SKIP_BASELINE" ]; then
    echo "✅ IMPROVED: below baseline — lower the baseline to tighten the ratchet."
  else
    echo "✅ HELD: at baseline."
  fi
fi

write_summary

# Optional: also run the test suite (e.g. "pnpm test" / "uv run pytest").
if [ -n "${INPUT_TEST_COMMAND:-}" ]; then
  echo "--- tests: ${INPUT_TEST_COMMAND} ---"
  bash -c "${INPUT_TEST_COMMAND}" || status=1
fi

exit "$status"
