# Example project guide

## Layout

- `src/` contains application code.
- `tests/` contains automated tests.
- `src/generated/` is generated; do not edit it manually.

## Required checks

```bash
npm test
npm run lint
```

## Repository rules

- Keep public API changes backward compatible unless a versioned migration is included.
- Read `.kiro/steering/` before modifying code.
- Use the local `project-reviewer` agent for API compatibility reviews.
