---
name: stats
description: Summarise the local run log of this plugin. Use as /plan-code-judge:stats.
disable-model-invocation: true
allowed-tools: Bash(python3 "${CLAUDE_PLUGIN_ROOT}/scripts/stats.py" *)
---

Run exactly this command and show its output unchanged:

```
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/stats.py" "${CLAUDE_PLUGIN_DATA}/runs.jsonl"
```

Do not parse the log yourself and do not recompute any number. If the script prints "no run log found", say so.

After the output, add one sentence saying how many tasks the numbers rest on. With fewer than 5 tasks, say they are too few to mean anything.
