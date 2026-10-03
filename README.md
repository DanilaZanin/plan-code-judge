# plan-code-judge

A Claude Code plugin for one workflow. The main session plans and decides. A cheaper model writes the code. A stronger, independent model judges the result by running it.

The judge never edits. The coder never grades its own work.

## Install

```
/plugin marketplace add DanilaZanin/plan-code-judge
/plugin install plan-code-judge@plan-code-judge
```

## Commands

The three commands are namespaced by the plugin name.

`/plan-code-judge:task <what to do>` is for an ordinary task.

1. The main session writes `.ai/state.md`.
2. The `coder` agent (Sonnet, high effort) writes the code test first and reports real command output.
3. The `judge` agent (Opus, high effort) runs the checks, tries to break the promise, and ends with `VERDICT: PASS`, `PASS_WITH_NOTES` or `FAIL`.
4. On FAIL the findings go back to the coder. At most 2 rounds, then the main session asks you.
5. The main session runs one fresh check itself before it says done.

`/plan-code-judge:big-task <task>` is for architecture, security, production work and vague requirements.

1. The main session reads the relevant code and writes `.ai/plan.md` (Decision, Steps, Verification, Rollback, Risks).
2. The `critic` agent reviews the plan once and ends with `VERDICT: READY` or `REVISE`.
3. The main session amends the plan and stops. It continues only after you say ok.
4. Then the same coder and judge loop as above.

`/plan-code-judge:stats` summarises the local run log: runs per agent, verdicts, rounds per task, and the share of tasks where the first judge verdict was not PASS.

## Rules

- The judge runs things. Reading the diff is not a review.
- Every finding needs evidence: command output, or file:line plus the mechanism.
- The coder cannot grade itself.
- At most 2 coder and judge rounds, then a human decides.
- A big task stops for your ok after the plan.
- State lives in `.ai/state.md`: done and verified, next command, what is broken.
- No commit or push unless you ask.

## What it cost and what it caught

This is the experience of one author on eight projects. It is not a benchmark. In each project a coder model reported green tests before review.

- Plan critique before coding: 8 of 8 plans came back "revise", typically with 12 remarks. In 2 of them the critic found a blocker before any code existed. In vault-map, an HTTP redirect would have turned a LIST into a GET that reads a secret. In am-blocks, a silence built from group labels would have muted more than the alert group.
- First independent review after "all tests green": 8 of 8 came back "fix first", with 13 to 28 findings per project.
- Rounds to acceptance: 2 to 5 per project.

Examples the judge reproduced by running the software:

- [helm-unstick](https://github.com/DanilaZanin/helm-unstick) rolled back a Helm operation that was still alive.
- [ci-why](https://github.com/DanilaZanin/ci-why) gave confidently wrong answers in 7 classes of GitLab CI configs.
- [vault-db-access](https://github.com/DanilaZanin/vault-db-access) had TLS settings covered by unit tests but never passed to the connections.
- [runner-disk-report](https://github.com/DanilaZanin/runner-disk-report) counted build cache twice.
- [argocd-sync-explain](https://github.com/DanilaZanin/argocd-sync-explain) sent a config token to a different server.
- [vault-map](https://github.com/DanilaZanin/vault-map) reported a filtered listing as complete.

Other tools by the same author: [kubectl-whydied](https://github.com/DanilaZanin/kubectl-whydied), [devops-starters](https://github.com/DanilaZanin/devops-starters).

## Run log and privacy

A hook runs when one of this plugin's agents stops. It appends one JSON line to `${CLAUDE_PLUGIN_DATA}/runs.jsonl`, or to `~/.claude/plan-code-judge/runs.jsonl` if that variable is not set. The line has five fields: timestamp, session id, working directory, agent name and verdict. No prompts, no code and no file contents are logged. The log stays on your machine.

The hook needs `python3`. Without it, the hook does nothing and the session is not affected.

## Limits

- It uses more tokens and more wall time than a single session.
- The judge can be wrong. Read its evidence.
- Rounds can keep finding new things. Define "done" before you start.

## Configuration

Models and effort are set in the frontmatter of `agents/coder.md`, `agents/judge.md` and `agents/critic.md`. The values are the documented aliases (`sonnet`, `opus`) and effort levels. Change them there.

## License

MIT. See `LICENSE`.
