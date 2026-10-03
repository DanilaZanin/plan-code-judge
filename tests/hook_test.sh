#!/bin/sh
# Tests for scripts/log-run.sh. Run: sh tests/hook_test.sh
HERE=$(cd "$(dirname "$0")" && pwd)
SCRIPT="$HERE/../scripts/log-run.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export CLAUDE_PLUGIN_DATA="$TMP/data"
LOG="$CLAUDE_PLUGIN_DATA/runs.jsonl"
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1 (got '$2', want '$3')"; fail=1; fi; }

# 1. valid input: one line, verdict FAIL, valid JSON
printf '%s\n' '{"session_id":"s1","cwd":"/x","agent_type":"plan-code-judge:judge","last_assistant_message":"notes\nVERDICT: FAIL"}' | sh "$SCRIPT"
check "exit code 0" "$?" "0"
check "one line" "$(wc -l < "$LOG" | tr -d ' ')" "1"
check "verdict FAIL" "$(python3 -c 'import json,sys; print(json.loads(open(sys.argv[1]).readline())["verdict"])' "$LOG")" "FAIL"

# 2. malformed input: exit 0, nothing added
echo 'not json {' | sh "$SCRIPT"
check "malformed exit 0" "$?" "0"
check "malformed writes nothing" "$(wc -l < "$LOG" | tr -d ' ')" "1"

# 3. foreign agent: nothing added
echo '{"session_id":"s1","cwd":"/x","agent_type":"Explore","last_assistant_message":"VERDICT: PASS"}' | sh "$SCRIPT"
check "foreign exit 0" "$?" "0"
check "foreign writes nothing" "$(wc -l < "$LOG" | tr -d ' ')" "1"

# 4. coder without verdict: line with null verdict
echo '{"session_id":"s1","cwd":"/x","agent_type":"plan-code-judge:coder","last_assistant_message":"done"}' | sh "$SCRIPT"
check "coder line added" "$(wc -l < "$LOG" | tr -d ' ')" "2"
check "coder verdict null" "$(tail -1 "$LOG" | python3 -c 'import json,sys; print(json.loads(sys.stdin.read())["verdict"])')" "None"

exit $fail
