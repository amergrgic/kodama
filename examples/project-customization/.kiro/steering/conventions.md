# Example project conventions

- Use the existing module structure under `src/`; do not introduce a new top-level source directory.
- Prefer small, focused functions and keep public behavior backward compatible.
- Do not edit files under `src/generated/`; regenerate them with the documented project command.
- Run the checks documented in `AGENTS.md` after code changes.
