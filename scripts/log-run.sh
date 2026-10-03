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
allowed = {
    "plan-code-judge:judge": ("PASS", "PASS_WITH_NOTES", "FAIL", "BLOCKED"),
    "plan-code-judge:critic": ("READY", "REVISE"),
}.get(agent, ())
def parse(text):
    lines = [l.strip() for l in str(text or "").splitlines() if l.strip()]
    if not lines:
        return None
    m = re.fullmatch(r"VERDICT: ([A-Z_]+)", lines[-1])
    return m.group(1) if m and m.group(1) in allowed else None
def from_transcript(path):
    # When the agent ends with the SubagentHandback tool instead of a text message,
    # last_assistant_message is empty. The verdict is the final statement of the agent: the
    # last handback message if there is one (a short text after it must not hide it),
    # otherwise the last assistant text block. Any surprise gives None.
    try:
        last_text = last_handback = None
        with open(path, encoding="utf-8", errors="replace") as f:
            for line in f:
                try:
                    r = json.loads(line)
                except Exception:
                    continue
                if not isinstance(r, dict) or r.get("type") != "assistant":
                    continue
                msg = r.get("message")
                content = msg.get("content") if isinstance(msg, dict) else None
                for c in content if isinstance(content, list) else []:
                    if not isinstance(c, dict):
                        continue
                    if c.get("type") == "text":
                        last_text = c.get("text")
                    elif c.get("type") == "tool_use" and c.get("name") == "SubagentHandback":
                        inp = c.get("input")
                        last_handback = inp.get("message") if isinstance(inp, dict) else None
        return parse(last_handback if last_handback is not None else last_text)
    except Exception:
        return None
verdict = parse(d.get("last_assistant_message"))
if verdict is None and allowed and d.get("agent_transcript_path"):
    verdict = from_transcript(d["agent_transcript_path"])
print(json.dumps({
    "ts": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "session_id": d.get("session_id"),
    "cwd": d.get("cwd"),
    "agent_type": agent,
    "verdict": verdict,
}))
' 2>/dev/null | {
    read -r LINE || exit 0
    mkdir -p "$(dirname "$LOG")" || exit 0
    printf '%s\n' "$LINE" >> "$LOG"
} 2>/dev/null
exit 0
