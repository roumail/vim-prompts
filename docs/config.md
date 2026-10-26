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

`:AiRules` shows the rules files from inside Vim, where each is set, and
those hidden; `:AiPersonas` adds the repository's file and each persona.

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

## Scopes

Each value lives in one of git's config scopes, and the scope says where
it applies. These are the names `:AiRules` and `:AiPersonas` show in their
last column, next to the file that sets the value, and the flags `:AiRule`
and `git config` take:

| Scope | File | Applies to | Layer |
| --- | --- | --- | --- |
| `system` | git's own, e.g. `/etc/gitconfig` | every user of the machine | rarely used |
| `global` | `~/.gitconfig`, and every file it includes | everything you work on | yours, and a group's |
| `local` | the repository's `.git/config` | one repository, in all its worktrees | one repository |
| `worktree` | `.git/worktrees/<name>/config.worktree` | one worktree | one branch |

- **A group is `global` too.** A file included with `includeIf` is read as
  part of `~/.gitconfig`, so git calls its values `global`; the file after
  the scope tells them apart (`global ~/.gitconfig` is yours,
  `global ~/work/.gitconfig` the group's). `:AiRule --global` only looks
  in `~/.gitconfig`, where `git config --global` writes, so inside a group
  it still opens yours; the group's you open by name (`:AiRule git.md`).
- **`local` is not committed.** `.git/config` belongs to your clone, not to
  the repository, so what you set there is yours alone. A file it names can
  be committed (a relative path, read from the checkout) or kept outside
  the repository (an absolute one).
- **`worktree` is one checkout.** A worktree is another checkout of the
  same repository, on its own branch (`git worktree add ../app-feature
  feature`); the first checkout is one too. Its scope needs turning on once
  per repository:

  ```sh
  git config extensions.worktreeConfig true
  ```

  Without it, git writes a `--worktree` value to the repository's
  `.git/config`, as `--local` does, and refuses once there is more than one
  worktree.

By hand, the scope is the flag:

```sh
git config --global --add vim-prompts.rules ~/dotfiles/prompts/git.md
git config --local --add vim-prompts.rules ~/.config/vim-prompts/repos/app.md
git config --worktree --add vim-prompts.rules ~/.config/vim-prompts/repos/app-feature.md
```

`:AiRule --global`, `--local` and `--worktree` do the same from Vim
([usage](usage.md#airule)).

## Order

Values come in the order git reads the [scopes](#scopes): `system`,
`global` (with each included file where the include is), `local`, then
`worktree`. Later is more specific, and wins:

- **Personas** stack: this plugin's, then each directory in order. A persona
  hides the one of its name below it, or builds on it with `{base}`
  ([templates](personas.md#building-on-another-persona)).
- **Rules** stack: a rules file hides an earlier one of its file name (a
  group's `git.md` replaces yours), and the rest all go in the prompt, the
  repository's file last, under "where two parts differ, follow the later
  one". `:AiRules` lists both.

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
- **One of the group's rules files**, replaced by one of the same file
  name.
- **The group's rules**, dropped: `git config --add vim-prompts.rules ""`,
  then add its own.

### One branch

A worktree's own config comes after the repository's, so an experiment
branch can have a persona or rules of its own. Turn the scope on once
([scopes](#scopes)), then, in that worktree:

```sh
git config --worktree --add vim-prompts.rules ~/.config/vim-prompts/repos/app-experiment.md
```

or `:AiRule --worktree`.

## A repository you didn't write

Its `.vim-prompts/` (or anything else) is not read until you name it in its
config. Read it first: a persona can pass the agent arguments (`args:`).
