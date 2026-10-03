---
name: task
description: Run an ordinary coding task through coder and judge. Use as /plan-code-judge:task followed by what to do.
argument-hint: "<what to do>"
disable-model-invocation: true
---

Task: $ARGUMENTS

Run this loop. You are the main session: you decide, the subagents work.

1. Write `.ai/state.md` in the project: the task, the check command if known, and "round 0". Create `.ai/` if needed.
2. Delegate to the subagent `plan-code-judge:coder` (Agent tool, `subagent_type: "plan-code-judge:coder"`). Give it the task, the working directory and the check command.
3. Delegate to the subagent `plan-code-judge:judge` the same way. Give it the task statement, the working directory, and the coder's report. Do not tell it what to conclude.
4. Read the judge's last line.
   - `VERDICT: PASS`: go to step 6.
   - `VERDICT: PASS_WITH_NOTES`: decide which notes to take. Send the ones you take to the coder, then judge again. List the notes you reject, each with a reason.
   - `VERDICT: FAIL`, or the coder reports something broken: send the findings back to the coder, then judge again.
   - `VERDICT: BLOCKED`: the judge could not run checks because of permissions. This is not a code failure. Do not send it to the coder and do not count a round. Show the user the refused commands and ask them to allow those commands (see the Permissions section of the README), then judge again.
5. Do at most 2 coder/judge rounds. If the second judge run is not PASS, stop and ask the user what to do.
6. Before you say done, run one fresh check command yourself and read the output.
7. Update `.ai/state.md`. Reply with a short summary: what changed, how it was verified, what is left open.

Do not commit or push unless the user asked.
