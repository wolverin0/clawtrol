# factoryctl

`bin/factoryctl` is a lightweight CLI for Factory execution ops.

## Commands

```bash
bin/factoryctl clone <repo_url> [--dest PATH] [--branch BRANCH]
bin/factoryctl worktree-add <repo_path> <branch> [--path PATH]
bin/factoryctl backlog-next [--file PATH]
bin/factoryctl backlog-mark <line> <todo|in_progress|done> [--file PATH]
bin/factoryctl backlog-run --cmd "<command with {task}>" [--file PATH]
```

## Backlog States

- `todo` -> `- [ ]`
- `in_progress` -> `- [-]`
- `done` -> `- [x]`

## Backlog Runner Placeholders

`backlog-run --cmd` supports:
- `{task}`: item text
- `{line}`: markdown line number
- `{file}`: backlog path

Example:

```bash
bin/factoryctl backlog-run \
  --file FACTORY_BACKLOG.md \
  --cmd 'echo "Executing line {line}: {task}"'
```

## Safety Notes

- `clone` never overwrites non-git folders.
- `worktree-add` creates branch if missing and writes into isolated `worktrees/`.
- `backlog-run` marks item `in_progress`, executes command, then:
  - marks `done` on success,
  - rolls back to `todo` on failure.
