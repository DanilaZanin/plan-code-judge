# plan-code-judge

A Claude Code plugin for one workflow. The main session plans and decides. A cheaper model writes the code. A stronger, independent model judges the result by running it.

The judge agent has no Edit or Write tools. It has Bash to run checks, and it is told not to change the project. In one test it still left a `__pycache__` directory behind, which is a side effect of running Python tests. The coder never grades its own work.

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
3. The `judge` agent (Opus, high effort) runs the checks, tries to break the promise, and ends with `VERDICT: PASS`, `PASS_WITH_NOTES`, `FAIL` or `BLOCKED`.
4. On FAIL the findings go back to the coder. At most 2 rounds, then the main session asks you. On BLOCKED (the judge could run nothing because of permissions) nothing goes to the coder. The main session shows you the refused commands and asks you to allow them.
5. The main session runs one fresh check itself before it says done.

`/plan-code-judge:big-task <task>` is for architecture, security, production work and vague requirements.

1. The main session reads the relevant code and writes `.ai/plan.md` (Decision, Steps, Verification, Rollback, Risks).
2. The `critic` agent reviews the plan once and ends with `VERDICT: READY` or `REVISE`.
3. The main session amends the plan and stops. It continues only after you say ok.
4. Then the same coder and judge loop as above.

`/plan-code-judge:stats` summarises the local run log: runs per agent, verdicts, rounds per task, and the share of tasks where the first judge verdict was not PASS.

### Example run

An outline of one real headless run of `/plan-code-judge:task` on a small task ("add `parse_duration` for strings like `1h30m`, with pytest tests") in a throwaway repo:

```
main     writes .ai/state.md
coder    (sonnet) writes durations.py and test_durations.py
judge    (opus)   runs the tests, mutates the code     VERDICT: PASS_WITH_NOTES
coder    (sonnet) takes the notes, adds a test case
judge    (opus)   could not run Python (permission)    VERDICT: FAIL
main     2 rounds used, stops and asks the user
```

The second FAIL came from missing permissions, not from the code. That case is what `BLOCKED` is for now. See Permissions below.

## Permissions

The judge must run your project's checks. Plugin subagents ignore `permissionMode`, so the judge uses your normal permission rules. Without a rule, a command such as `python3 -m pytest` needs approval. In an interactive session you approve it. In a headless run (`claude -p`) it is refused, and the judge reports `VERDICT: BLOCKED`.

Allow the commands in the project's `.claude/settings.json`:

```json
{
  "permissions": {
    "allow": [
      "Bash(python3 -m pytest:*)",
      "Bash(npm test:*)",
      "Bash(go test:*)"
    ]
  }
}
```

Keep only the commands your project needs. A rule matches the start of a command. `cd dir && python3 -m pytest` does not match a `python3` rule, so the judge is told to run plain commands from the project directory. For a headless run, pass the same rule on the command line:

```
claude -p --permission-mode acceptEdits --allowedTools "Bash(python3:*)" \
  "/plan-code-judge:task add a function that parses durations, with tests"
```

The judge also reports what it could not run. A FAIL means a defect it showed with evidence. BLOCKED means it ran nothing.

## Rules

- The judge runs things. Reading the diff is not a review. If it cannot run anything, it says BLOCKED.
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

A hook runs when one of this plugin's agents stops. It appends one JSON line to `runs.jsonl` in the plugin data directory (`${CLAUDE_PLUGIN_DATA}`, under `~/.claude/plugins/data/`), or to `~/.claude/plan-code-judge/runs.jsonl` if that variable is not set. The line has five fields: timestamp, session id, working directory, agent name and verdict. No prompts, no code and no file contents are logged. The log stays on your machine. Claude Code removes the plugin data directory when you uninstall the plugin from its last install location, unless you pass `--keep-data`.

The verdict is read only from the last non-empty line of the agent's answer, and only if it is in the allowed set for that agent. Otherwise it is logged as null.

`/plan-code-judge:stats` runs `scripts/stats.py` (Python 3, standard library) and prints the numbers. The model does not compute them.

The hook needs `python3`. Without it, the hook does nothing and the session is not affected.

## Tests

```
sh tests/hook_test.sh
sh tests/stats_test.sh
shellcheck scripts/log-run.sh tests/*.sh
```

## Limits

- It uses more tokens and more wall time than a single session.
- The judge can be wrong. Read its evidence.
- Rounds can keep finding new things. Define "done" before you start.

## Configuration

Models and effort are set in the frontmatter of `agents/coder.md`, `agents/judge.md` and `agents/critic.md`. The values are the documented aliases (`sonnet`, `opus`) and effort levels. Change them there.

## License

MIT. See `LICENSE`.
