#!/usr/bin/env python3
"""Summarise the plan-code-judge run log. Usage: stats.py [path-to-runs.jsonl]"""
import json
import os
import sys
from collections import Counter, defaultdict

AGENTS = ("coder", "judge", "critic")


def default_path():
    data = os.environ.get("CLAUDE_PLUGIN_DATA")
    if data:
        return os.path.join(data, "runs.jsonl")
    return os.path.expanduser("~/.claude/plan-code-judge/runs.jsonl")


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else default_path()
    if not os.path.exists(path):
        fallback = os.path.expanduser("~/.claude/plan-code-judge/runs.jsonl")
        path = fallback if os.path.exists(fallback) else None
    if path is None:
        print("no run log found")
        return 0

    runs, bad = [], 0
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            if not line.strip():
                continue
            try:
                d = json.loads(line)
                if not isinstance(d, dict) or "agent_type" not in d:
                    raise ValueError
            except ValueError:
                bad += 1
                continue
            runs.append(d)

    by_agent = {a: [r for r in runs if r["agent_type"] == "plan-code-judge:" + a] for a in AGENTS}
    print("log: " + path)
    for a in AGENTS:
        print("runs %s: %d" % (a, len(by_agent[a])))
    for a in ("judge", "critic"):
        c = Counter(r.get("verdict") for r in by_agent[a] if r.get("verdict"))
        print("verdicts %s: %s" % (a, " ".join("%s=%d" % kv for kv in sorted(c.items())) or "none"))

    tasks = defaultdict(list)
    for r in runs:
        if r["agent_type"].startswith("plan-code-judge:"):
            tasks[(r.get("session_id"), r.get("cwd"))].append(r)
    print("tasks: %d" % len(tasks))

    rounds = Counter()
    first = []
    for t in tasks.values():
        judges = [r for r in t if r["agent_type"] == "plan-code-judge:judge"]
        if judges:
            rounds[len(judges)] += 1
            first.append(judges[0].get("verdict"))
    parts = ["%d %s: %d %s" % (n, "round" if n == 1 else "rounds", c, "task" if c == 1 else "tasks")
             for n, c in sorted(rounds.items())]
    print("rounds per task (judge runs): " + (", ".join(parts) or "none"))
    # A first verdict of BLOCKED means the judge could not run checks; it says nothing about the code.
    counted = [v for v in first if v != "BLOCKED"]
    blocked = len(first) - len(counted)
    if counted:
        n = sum(1 for v in counted if v != "PASS")
        print("first judge verdict not PASS: %d of %d tasks (%.1f%%)" % (n, len(counted), 100.0 * n / len(counted)))
    else:
        print("first judge verdict not PASS: no judged tasks")
    if blocked:
        print("tasks whose first judge verdict was BLOCKED (excluded above): %d" % blocked)
    print("malformed lines: %d" % bad)
    return 0


if __name__ == "__main__":
    sys.exit(main())
