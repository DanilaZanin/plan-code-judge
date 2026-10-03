#!/bin/sh
# SubagentStop hook: append one JSON line per run of this plugin's agents.
# Logged: ts, session_id, cwd, agent_type, verdict. Nothing else.
# Never fails the session: always exits 0.

LOG="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plan-code-judge}/runs.jsonl"
INPUT=$(cat) || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

printf '%s' "$INPUT" | python3 -c '
import sys, json, re, datetime
try:
    d = json.load(sys.stdin)
    agent = d["agent_type"]
except Exception:
    sys.exit(0)
if agent not in ("plan-code-judge:coder", "plan-code-judge:judge", "plan-code-judge:critic"):
    sys.exit(0)
m = re.findall(r"VERDICT:\s*(PASS_WITH_NOTES|PASS|FAIL|READY|REVISE)", str(d.get("last_assistant_message") or ""))
print(json.dumps({
    "ts": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "session_id": d.get("session_id"),
    "cwd": d.get("cwd"),
    "agent_type": agent,
    "verdict": m[-1] if m else None,
}))
' 2>/dev/null | {
    read -r LINE || exit 0
    mkdir -p "$(dirname "$LOG")" 2>/dev/null || exit 0
    printf '%s\n' "$LINE" >> "$LOG" 2>/dev/null
}
exit 0
