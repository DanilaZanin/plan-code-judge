---
name: big-task
description: Run a complex task (architecture, security, production, vague requirements) with a written plan, one critique, a stop for approval, then coder and judge. Use as /plan-code-judge:big-task followed by the task.
argument-hint: "<task>"
disable-model-invocation: true
---

Task: $ARGUMENTS

You are the main session: you decide, the subagents work.

1. Read the code that matters for this task.
2. Write `.ai/plan.md` with these sections: Decision, Steps, Verification, Rollback, Risks. Keep it under 400 words.
3. Delegate to the subagent `plan-code-judge:critic` (Agent tool, `subagent_type: "plan-code-judge:critic"`) once. Give it the path of the plan. Amend the plan for the remarks you accept. Note the ones you reject, with a reason.
4. Stop. Show the plan, the critic's verdict and the rejected remarks. Continue only after the user says ok in plain words. If they ask for changes, change the plan and show it again.
5. Write `.ai/state.md`, then run the coder and judge loop:
   - Delegate to `plan-code-judge:coder` with the approved plan.
   - Delegate to `plan-code-judge:judge` with the plan, the working directory and the coder's report.
   - On `VERDICT: FAIL`, or `VERDICT: PASS_WITH_NOTES` with notes you accept, send the findings back to the coder and judge again. List the notes you reject, with a reason.
   - On `VERDICT: BLOCKED` the judge could not run checks because of permissions. Do not send it to the coder and do not count a round. Show the user the refused commands, ask them to allow those commands, then judge again.
   - At most 2 rounds. If the second judge run is not PASS, stop and ask the user.
   - Use two coders in parallel only for parts that are independent, each in its own git worktree.
6. Before you say done, run one fresh check command yourself and read the output.
7. Reply with a short summary: what changed, how it was verified, what is left open, and how many coder and judge runs happened.

Do not commit or push unless the user asked.
