# Configuration

What briefs an ask, besides your query and its context, is set in git
config: the personas you can ask, the rules every ask follows, and the file
that describes the repository. Git reads its config in layers (yours, a
group of repositories', one repository's, one worktree's), so the same
layers compose vim-prompts: rules shared by everything you work on, more
for a group, a repository's own on top, and a branch's on top of that, the
more specific winning where they differ.

Every part is optional: with nothing set, `:Ai` works anywhere with the
built-in personas, and each layer you add only adds to it.

Nothing is read for being in some place. A `.vim-prompts/` in a repository is
only a directory until git config names it, so a repository you clone can't
brief your agent, and what applies is always what git config lists:

```sh
git config --show-origin --get-regexp '^vim-prompts\.'
```

`:AiPersonas` shows the same, from inside Vim: the rules, the repository's
file, each persona and where each is set.

`:AiRule` opens one of the rules files from inside Vim, or creates one for
a scope and names it there ([usage](usage.md#airule)).

## Settings

| Key | Value | Where |
| --- | --- | --- |
| `vim-prompts.personas` | A directory of [personas](personas.md). Every value counts; for two of a name, the later wins. | anywhere |
| `vim-prompts.rules` | A file of rules for every ask: how you push, how tests are written. Every value counts, in order. | anywhere |
| `vim-prompts.repository` | The file that describes this repository: what it is, its layout, its conventions, how to run its tests. | the repository's own config only |

- **Paths** are relative to the work tree's root (outside a repository, to
  the working directory), and `~` and `$VARS` are expanded.
- **An empty value** (`git config --add vim-prompts.rules ""`) drops every
  value of that key before it, as it does for git's `credential.helper`.
- **A missing file or directory, an unknown key, or a `repository` set
  outside the repository's own config** refuses every ask, saying which
  setting and which file: what you name must be there.

## Order

Values come in the order git reads them: system, global (`~/.gitconfig`,
with each file it includes where the include is), the repository's
`.git/config`, then its worktree's. Later is more specific, and wins:

- **Personas** stack: this plugin's, then each directory in order. A persona
  hides the one of its name below it, or builds on it with `{base}`
  ([templates](personas.md#building-on-another-persona)).
- **Rules** all go in the prompt, the repository's file last, under
  "where two parts differ, follow the later one".

Put an `includeIf` after your own `[vim-prompts]` section, so the group's
values come after yours.

## Setting it up

### Yours, everywhere

```ini
# ~/.gitconfig
[vim-prompts]
	personas = ~/dotfiles/prompts/personas
	rules = ~/dotfiles/prompts/rules.md       # push branches only, never open a PR
```

Outside any repository (a scratch directory, an experiment), only these
apply.

### A group of repositories

Every repository under `~/work/`, with a file kept beside them:

```ini
# ~/.gitconfig, after the section above
[includeIf "gitdir:~/work/"]
	path = ~/work/.gitconfig
```

```ini
# ~/work/.gitconfig
[vim-prompts]
	personas = ~/work/handbook/prompts/personas   # /tests, /migrate: the team's
	rules = ~/work/handbook/prompts/testing.md    # factories, the legacy tests rule
```

A group's rules say what is common and point at what is longer: "Follow the
Testing and Factories sections of ~/work/handbook/CONTRIBUTING.md." The agent
reads it there.

### One repository

Its description, committed with it and named in its config:

```sh
git config vim-prompts.repository .vim-prompts/repository.md
```

```markdown
<!-- .vim-prompts/repository.md -->
A Flask app. Tests go only through the Flask test client, `client.get(...)`,
never by calling functions directly: no unit tests. Assert on the response
status and JSON body, not on the database. Run them with `make test`.
```

Its config is shared by all its worktrees, so what you set here reaches every
branch you check out beside it (`repo/main`, `repo/feature-x`). A relative
path is read from each worktree's own checkout, so every branch has the
description it committed.
To keep a description to yourself, give an absolute path outside the
repository instead (`~/notes/flaskapp.md`); every worktree reads that one
file.

The same goes for personas of its own, which win over the group's:

```sh
git config --add vim-prompts.personas .vim-prompts/personas
```

### A repository that is different

Its own config comes last, so it overrides the group:

- **A persona** of the same name in its own directory replaces the group's,
  or builds on it with `{base}`.
- **The group's rules**, dropped: `git config --add vim-prompts.rules ""`,
  then add its own.

### One branch

With `extensions.worktreeConfig`, `git config --worktree ...` does the same
for one worktree only, on top of the repository's: an experiment branch with
a persona or rules of its own.

## A repository you didn't write

Its `.vim-prompts/` (or anything else) is not read until you name it in its
config. Read it first: a persona can pass the agent arguments (`args:`).
