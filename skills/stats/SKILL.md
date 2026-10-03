---
name: stats
description: Summarise the local run log of this plugin. Use as /plan-code-judge:stats.
disable-model-invocation: true
---

Summarise the run log of this plugin.

1. Find the log. Use `${CLAUDE_PLUGIN_DATA}/runs.jsonl`. If that file does not exist, use `~/.claude/plan-code-judge/runs.jsonl`. If neither exists, say so and stop.
2. Each line is one JSON object with `ts`, `session_id`, `cwd`, `agent_type` and `verdict`. Read the file with a shell command or a short script. Do not guess.
3. Report:
   - Runs per agent type.
   - Count of each verdict.
   - Rounds per task: count judge runs per `session_id`.
   - Share of tasks where the first judge verdict in the session was not PASS.
4. Say how many sessions and runs the numbers are based on. With few runs, say the numbers are not meaningful.
