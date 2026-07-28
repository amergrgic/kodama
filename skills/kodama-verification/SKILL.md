---
name: kodama-verification
description: Define measurable success criteria and collect targeted test, build, lint, type-check, or smoke-test evidence before claiming work is complete.
---

# Verification Playbook

## Define success before implementation

For non-trivial changes, record:

- **Functional:** what behavior must change or remain unchanged.
- **Observable:** what a test, command, or user flow must show.
- **Pass/fail:** binary conditions that demonstrate success.

Select the smallest meaningful evidence path from the repository's own tooling. Do not invent commands when project guidance already specifies them.

## Implement and validate

1. Read the affected code and tests.
2. Add or update a targeted test when behavior changes.
3. Run the targeted test first.
4. Run the relevant lint, type check, build, or smoke test when available and proportionate to the change.
5. For user-facing behavior, perform a manual verification when automation does not cover the flow.

## Report evidence

Completion reports must state:

```markdown
## Verification
- Command: `…`
- Result: exit code and meaningful summary
- Coverage: behavior or requirement verified
- Limitations: checks that could not run and why
```

## Required evidence by change type

| Change | Minimum evidence |
|---|---|
| Bug fix | Reproduction or regression test plus fixed behavior. |
| New behavior | Targeted test plus relevant build/type/lint check. |
| Refactor | Existing targeted tests plus no behavior-change evidence. |
| Configuration | Validation command and expected output. |
| Documentation | Render, link, or example verification where applicable. |

Never say "should work", "tests pass", or "complete" without naming the evidence actually observed.
