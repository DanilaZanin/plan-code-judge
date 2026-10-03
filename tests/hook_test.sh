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

# agent ended with the SubagentHandback tool: last_assistant_message is empty, the verdict
# is in the agent transcript (last assistant record, handback message or text block)
T="$TMP/agent.jsonl"
send_t() { # AGENT LAST_MESSAGE TRANSCRIPT_PATH
    python3 -c 'import json,sys; print(json.dumps({"session_id":"s1","cwd":"/x","agent_type":sys.argv[1],"last_assistant_message":sys.argv[2],"agent_transcript_path":sys.argv[3]}))' "$1" "$2" "$3" | sh "$SCRIPT"
}
rec() { # TYPE NAME TEXT -> one transcript line with an assistant tool_use or text block
    python3 -c 'import json,sys
t,n,x=sys.argv[1:4]
c={"type":"text","text":x} if t=="text" else {"type":"tool_use","name":n,"input":{"message":x}}
print(json.dumps({"type":"assistant","message":{"role":"assistant","content":[c]}}))' "$1" "$2" "$3"
}
{ echo '{"type":"user","message":{"role":"user","content":"go"}}'; rec text - "VERDICT: FAIL"; rec tool_use Bash "ls"; rec tool_use SubagentHandback "notes${NL}VERDICT: READY"; } > "$T"
send_t $C "" "$T"; check "handback verdict from transcript" "$(last_verdict)" READY
send_t $J "" "$T"; check "handback verdict must be in the agent set, earlier text does not count" "$(last_verdict)" None
{ rec text - "VERDICT: PASS"; rec tool_use SubagentHandback "VERDICT: FAIL"; rec text - "VERDICT: PASS_WITH_NOTES"; } > "$T"
send_t $J "" "$T"; check "handback beats text blocks" "$(last_verdict)" FAIL
{ rec tool_use SubagentHandback "VERDICT: PASS_WITH_NOTES"; rec text - "Report handed back."; } > "$T"
send_t $J "" "$T"; check "text after handback does not hide the verdict" "$(last_verdict)" PASS_WITH_NOTES
{ echo '[1,2]'; echo 'null'; echo '{"type":"assistant","message":null}'; echo '{"type":"assistant","message":{"content":[1,{"type":"tool_use","name":"SubagentHandback","input":"s"}]}}'; rec tool_use SubagentHandback "VERDICT: PASS"; } > "$T"
send_t $J "" "$T"; check "odd records are skipped, not fatal" "$(last_verdict)" PASS
send_t $J "VERDICT: FAIL" "$T"; check "last_assistant_message has priority" "$(last_verdict)" FAIL
send_t $J "" "$TMP/missing.jsonl"; check "missing transcript gives None" "$(last_verdict)" None
printf 'garbage\n{"type":"assistant","message":{"content":"str"}}\n' > "$T"
send_t $J "" "$T"; check "garbage transcript gives None" "$(last_verdict)" None
send_t $K "" "$T"; check "coder transcript ignored" "$(last_verdict)" None

before=$(lines)
echo 'not json {' | sh "$SCRIPT"; check "malformed exit 0" "$?" "0"
check "malformed writes nothing" "$(lines)" "$before"

# read-only data dir: exit 0 and silent stderr
RO="$TMP/ro"; mkdir -p "$RO/data"; : > "$RO/data/runs.jsonl"; chmod a-w "$RO/data/runs.jsonl" "$RO/data"
err=$(CLAUDE_PLUGIN_DATA="$RO/data" send $J "VERDICT: PASS" 2>&1 >/dev/null); rc=$?
check "read-only exit 0" "$rc" "0"
check "read-only stderr silent" "$err" ""

exit $fail
