---
name: omk-behavior
description: Classify requests, assess unfamiliar codebases, delegate work safely, and recover from failed attempts. Use for multi-step, ambiguous, or parallelizable work.
---

# Behavior Playbook

## Classify before acting

| Request shape | Default response |
|---|---|
| Single known edit or direct question | Act directly. |
| Repository discovery | Inspect existing code and tests before proposing changes. |
| Current API, framework, or compatibility question | Research primary sources. |
| Ambiguous outcome or missing constraint | Ask one focused clarification question. |
| Multi-step work | Define success criteria and a task list before editing. |

## Delegate deliberately

Use a specialist when delegation improves quality or speed:

- `omk-explorer`: repository structure, established patterns, dependencies, and tests.
- `omk-librarian`: current external documentation and examples.
- `omk-oracle`: hard debugging, architecture, and high-impact tradeoffs.
- `omk-designer`: user-facing UI, UX, and accessibility work.
- `omk-fixer`: bounded implementation after scope is clear.
- `omk-reviewer`: independent review of a non-trivial diff.

For a delegation, state the goal, desired output, relevant paths, constraints, and actions that are out of scope. Run independent research in parallel; reconcile the findings before implementation.

## Assess before modifying

Before changing unfamiliar code, identify:

1. a similar implementation;
2. local naming and organization conventions;
3. dependencies already available;
4. the relevant test location and test runner;
5. the smallest safe validation command.

## Recover from failures

1. Read the error and identify the failing boundary.
2. Form a root-cause hypothesis and gather evidence.
3. Retry only with a materially different approach.
4. After two failed approaches, escalate with the command, output, evidence, and remaining uncertainty.

Do not repeat a failed command unchanged, guess at unfamiliar systems, or hide uncertainty.
