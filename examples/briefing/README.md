# Briefing fixtures

A home directory whose git config sets rules, task rules, personas and a
repository's description at every scope, for `:AiRules` and `:AiPersonas`
to list. Copy `home/` somewhere, point `HOME` at the copy, then make the
repository:

```sh
git init "$HOME/work/app"
cat app.gitconfig >> "$HOME/work/app/.git/config"
```

What it sets, in `$HOME/work/app`:

| Where | Sets | Shows |
| --- | --- | --- |
| `home/.gitconfig` (global) | rules `git.md`, `comments.md`; task rules `testing`; personas `review`, `explain` | yours |
| `home/work/handbook/work.gitconfig` (global, `includeIf gitdir:~/work/`) | rules `git.md`; task rules `testing`, `test-setup`; personas `tests`, `explain` | the group's `git.md`, `#rule:testing` and `/explain` hide yours |
| `app.gitconfig` (local) | repository `.vim-prompts/repository.md` | the description, by its path in the repository |

- `/review` builds on the bundled one with `{base}`: it lists it, and hides nothing.
- `/tests` asks for `#file`, so from a buffer without a file it says what it needs.

`broken.gitconfig`, added to a repository's config, gives the errors: a rules
file that isn't there, and an unknown key (`library`).
