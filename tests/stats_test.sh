#!/bin/sh
# Tests for scripts/stats.py with a fixture of 8 valid and 2 malformed lines.
HERE=$(cd "$(dirname "$0")" && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
F="$TMP/runs.jsonl"
L() { printf '{"ts":"2026-01-01T00:00:00Z","session_id":"%s","cwd":"%s","agent_type":"plan-code-judge:%s","verdict":%s}\n' "$1" "$2" "$3" "$4"; }
{
  L A /a coder null
  L A /a judge '"FAIL"'
  echo 'not json'
  L A /a coder null
  L A /a judge '"PASS"'
  L B /b critic '"REVISE"'
  L B /b coder null
  L B /b judge '"PASS"'
  echo '{"agent_type":'
  L C /c judge '"PASS_WITH_NOTES"'
} > "$F"
OUT=$(python3 "$HERE/../scripts/stats.py" "$F")
echo "$OUT"
fail=0
has() { if printf '%s\n' "$OUT" | grep -qxF "$1"; then echo "ok   $1"; else echo "FAIL missing line: $1"; fail=1; fi; }
has "runs judge: 4"
has "runs coder: 3"
has "runs critic: 1"
has "verdicts judge: FAIL=1 PASS=2 PASS_WITH_NOTES=1"
has "verdicts critic: REVISE=1"
has "tasks: 3"
has "rounds per task (judge runs): 1 round: 2 tasks, 2 rounds: 1 task"
has "first judge verdict not PASS: 2 of 3 tasks (66.7%)"
has "malformed lines: 2"
exit $fail
