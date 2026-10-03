#!/bin/sh
# Tests for scripts/log-run.sh. Run: sh tests/hook_test.sh
HERE=$(cd "$(dirname "$0")" && pwd)
SCRIPT="$HERE/../scripts/log-run.sh"
TMP=$(mktemp -d)
trap 'chmod -R u+w "$TMP" 2>/dev/null; rm -rf "$TMP"' EXIT
export CLAUDE_PLUGIN_DATA="$TMP/data"
LOG="$CLAUDE_PLUGIN_DATA/runs.jsonl"
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1 (got '$2', want '$3')"; fail=1; fi; }
lines() { if [ -f "$LOG" ]; then wc -l < "$LOG" | tr -d ' '; else echo 0; fi; }
last_verdict() { tail -1 "$LOG" | python3 -c 'import json,sys; print(json.loads(sys.stdin.read())["verdict"])'; }
# send AGENT MESSAGE (message may contain real newlines)
send() {
    python3 -c 'import json,sys; print(json.dumps({"session_id":"s1","cwd":"/x","agent_type":sys.argv[1],"last_assistant_message":sys.argv[2]}))' "$1" "$2" | sh "$SCRIPT"
}
# expect verdict V after sending AGENT MESSAGE; V=NOLINE means nothing written
case_verdict() {
    name=$1; agent=$2; msg=$3; want=$4
    before=$(lines)
    send "$agent" "$msg"
    if [ "$want" = NOLINE ]; then check "$name" "$(lines)" "$before"
    else check "$name" "$(last_verdict)" "$want"; fi
}
J=plan-code-judge:judge; C=plan-code-judge:critic; K=plan-code-judge:coder
NL='
'

case_verdict "judge FAIL" $J "notes${NL}VERDICT: FAIL" FAIL
check "one line written" "$(lines)" "1"
case_verdict "judge PASS" $J "VERDICT: PASS" PASS
case_verdict "judge PASS_WITH_NOTES" $J "x${NL}VERDICT: PASS_WITH_NOTES${NL}${NL}" PASS_WITH_NOTES
case_verdict "judge BLOCKED" $J "VERDICT: BLOCKED" BLOCKED
# shellcheck disable=SC2016
case_verdict "judge backticks" $J 'VERDICT: `PASS`' None
case_verdict "judge PASSED is not PASS" $J "VERDICT: PASSED" None
# shellcheck disable=SC2016
case_verdict "verdict in code block, not last line" $J "$(printf '```\nVERDICT: PASS\n```\ntrailing text')" None
case_verdict "verdict not on last line" $J "VERDICT: PASS${NL}more" None
case_verdict "judge says READY (wrong set)" $J "VERDICT: READY" None
case_verdict "critic READY" $C "VERDICT: READY" READY
case_verdict "critic REVISE" $C "VERDICT: REVISE" REVISE
case_verdict "critic says PASS (wrong set)" $C "VERDICT: PASS" None
case_verdict "coder verdict ignored" $K "VERDICT: PASS" None
case_verdict "coder no verdict" $K "done" None
case_verdict "foreign agent" Explore "VERDICT: PASS" NOLINE

before=$(lines)
echo 'not json {' | sh "$SCRIPT"; check "malformed exit 0" "$?" "0"
check "malformed writes nothing" "$(lines)" "$before"

# read-only data dir: exit 0 and silent stderr
RO="$TMP/ro"; mkdir -p "$RO/data"; : > "$RO/data/runs.jsonl"; chmod a-w "$RO/data/runs.jsonl" "$RO/data"
err=$(CLAUDE_PLUGIN_DATA="$RO/data" send $J "VERDICT: PASS" 2>&1 >/dev/null); rc=$?
check "read-only exit 0" "$rc" "0"
check "read-only stderr silent" "$err" ""

exit $fail
