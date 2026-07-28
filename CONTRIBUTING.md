# Contributing

Thanks for your interest in kodama! Here's how to help.

## Quick start

```bash
git clone git@github.com:amergrgic/oh-my-kiro.git
cd oh-my-kiro
./scripts/validate.sh
```

The validation suite requires only `bash` and `python3`. It uses a stub Kiro CLI — no real installation needed.

## Making changes

1. Create a branch from `main`.
2. Make your changes.
3. Run `./scripts/validate.sh` — all checks must pass.
4. Open a pull request with a clear description of what changed and why.

## Adding an agent

1. Create `agents/<name>.json` with `name`, `description`, `prompt`, `model`, `tools`, `allowedTools`, and `resources`.
2. Add the name to `AGENT_NAMES` in `setup.sh`.
3. Reference any skills via `skill://__KODAMA_SKILLS_DIR__/<skill>/SKILL.md`.
4. Run validation.

## Modifying a skill

Edit the Markdown under `skills/<name>/SKILL.md`. Keep the YAML frontmatter — `name` must match the directory name and `description` is required.

## Conventions

- Agents use `model: "auto"` — don't hardcode provider-specific model IDs.
- `allowedTools` must be a subset of `tools`.
- Keep prompts self-contained inside the agent JSON (no external prompt files).
- Use `__KODAMA_SKILLS_DIR__` and `__KODAMA_STATE_DIR__` as placeholders — the installer resolves them.
- Don't add dependencies beyond `bash` and `python3`.

## Commit messages

Keep them short and descriptive. No strict format required, but prefer imperative mood:

```
Add kodama-debugger agent for runtime inspection
Fix uninstall skipping modified skills
```

## Releases

Maintainers handle releases:

1. Bump `KODAMA_VERSION` in `setup.sh`.
2. Add an entry to `CHANGELOG.md`.
3. Commit, tag (`v<version>`), push.
4. Create a GitHub Release from the tag.

## Code of conduct

Be kind, be constructive. This is a small community project — treat others the way you'd want to be treated.
