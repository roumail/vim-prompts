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

`:AiRules` shows the rules files and the repository's file from inside Vim,
where each is set, and those hidden; `:AiPersonas` shows each persona.

`:AiRule` opens one of the rules files from inside Vim, or creates one for
a scope and names it there ([usage](usage.md#airule)); `:AiUnset` removes a
value from the file that sets it ([removing a setting](#removing-a-setting)).

## Settings

| Key | Value | Where |
| --- | --- | --- |
| `vim-prompts.personas` | A directory of [personas](personas.md). Every value counts; for two of a name, the later wins. | anywhere |
| `vim-prompts.rules` | A file of rules for every ask: how you push, what never to do. Every value counts, in order. | anywhere |
| `vim-prompts.library` | A directory of rules files sent only when asked for by name, `#rule:<name>` for `<name>.md`: how tests are written, how migrations are. For two of a name, the later wins. | anywhere |
| `vim-prompts.repository` | The file that describes this repository: what it is, its layout, its conventions, how to run its tests. Exactly one may apply. | its own config, or a file included for its folder alone |

- **Paths** are relative to the work tree's root (outside a repository, to
  the working directory), and `~` and `$VARS` are expanded.
- **An empty value** (`git config --add vim-prompts.rules ""`) drops every
  value of that key before it, as it does for git's `credential.helper`.
- **A missing file or directory, an unknown key, or `repository` set more
  than once** where you ask refuses every ask, saying which setting and
  which files: what you name must be there, and one file describes the
  repository. `:AiUnset` removes the extra one.
- **`repository` belongs to one repository.** Set it in the repository's
  own config, or in a file only that repository includes
  ([kept with the prompts](#a-worked-example-dotfiles-and-a-teams-prompts-repository)),
  never in a file a whole group includes: there, every repository without
  its own would be described as that one.

## Scopes

Each value lives in one of git's config scopes, and the scope says where
it applies. These are the names `:AiRules` and `:AiPersonas` show in their
last column, next to the file that sets the value, and the flags `:AiRule`
and `git config` take:

| Scope | File | Applies to | Layer |
| --- | --- | --- | --- |
| `system` | git's own, e.g. `/etc/gitconfig` | every user of the machine | rarely used |
| `global` | `~/.gitconfig`, and every file it includes | everything you work on | yours, and a group's |
| `local` | the repository's `.git/config` (`.bare/config` in a bare repository with worktrees) | one repository, in all its worktrees | one repository |
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
- **`local` is the same file from every worktree.** In a bare repository
  with one worktree per branch (`repo/.bare`, `repo/main/`, `repo/feature/`)
  it is `.bare/config`; `--show-origin` names it, and `git config --local`
  or `:AiUnset` reach it from any worktree.
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
- **Libraries** stack like personas: `#rule:testing` is the last
  `testing.md` of any of them, so a repository's own `testing.md` replaces
  the group's in that repository only. `:AiRules` lists each name and what
  it hides.

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

### A worked example: dotfiles and a team's prompts repository

A setup in daily use, with the names changed. `~/.gitconfig` is in the
dotfiles, shared by every machine; the work repositories, and the prompts
for them, are only on the work laptop, under `~/projects/acme/`. Some are
bare repositories with a worktree per branch (`api/.bare`, `api/main/`),
some plain clones (`etl/.git`).

The prompts are a repository of their own, `~/projects/acme/prompts`:

```
work.gitconfig            the group's settings, below
rules/general.md          sent with every ask: never push, changelog entries
rules/api-branches.md     sent with every ask in api only
library/testing.md        #rule:testing: how tests are written, everywhere
library/test-setup.md     #rule:test-setup: how they run, the fallback
library-api/test-setup.md #rule:test-setup in api: its services, its venv
library-api/migrations.md #rule:migrations, api only
library-etl/test-setup.md
personas/tests.md         /tests: context [file, "rule:testing", "rule:test-setup"]
personas/migrations.md    /migrations: context [file, "rule:migrations"]
repos/api.md, repos/etl.md   each repository's description
```

The same names everywhere, `/tests` and `#rule:test-setup`, with what they
hold differing per repository: a repository's library comes after the
group's, so its `test-setup.md` hides the group's there and nowhere else.

**The config files, in the order git reads them:**

```ini
# ~/.gitconfig, in the dotfiles: yours, everywhere
[vim-prompts]
	rules = ~/.config/vim-prompts/git.md

# Last, so this machine's settings win
[include]
	path = ~/.gitconfig.local
```

```ini
# ~/.gitconfig.local, this machine only, never committed
[includeIf "gitdir:~/projects/acme/"]
	path = ~/projects/acme/prompts/work.gitconfig
```

```ini
# ~/projects/acme/prompts/work.gitconfig
[vim-prompts]
	rules = ~/projects/acme/prompts/rules/general.md
	library = ~/projects/acme/prompts/library
	personas = ~/projects/acme/prompts/personas

# Each repository's own, after the group's so they win; a path relative
# to this file
[includeIf "gitdir:~/projects/acme/api/"]
	path = repos/api.gitconfig
[includeIf "gitdir:~/projects/acme/etl/"]
	path = repos/etl.gitconfig
```

```ini
# ~/projects/acme/prompts/repos/api.gitconfig: api's alone
[vim-prompts]
	repository = ~/projects/acme/prompts/repos/api.md
	library = ~/projects/acme/prompts/library-api
	rules = ~/projects/acme/prompts/rules/api-branches.md
```

Each repository's settings are in the prompts repository too, versioned
with the rest, in a file loaded only inside that repository: `gitdir:`
names the folder holding its `.git` or `.bare`, with a trailing `/` so that
`api-tools/` isn't `api/`. That reaches every worktree of it, bare or not,
even one checked out outside the folder, since the match is on the git
directory.

**What `:AiRules` shows** in `api/main/`:

```
git.md          ~/.config/vim-prompts/git.md          global ~/.gitconfig
general.md      ~/projects/acme/prompts/rules/general.md global ~/projects/acme/prompts/work.gitconfig
api-branches.md ~/projects/acme/prompts/rules/api-branches.md global ~/projects/acme/prompts/repos/api.gitconfig
repository      ~/projects/acme/prompts/repos/api.md  global ~/projects/acme/prompts/repos/api.gitconfig
#rule:migrations ~/projects/acme/prompts/library-api/migrations.md global ~/projects/acme/prompts/repos/api.gitconfig
#rule:test-setup ~/projects/acme/prompts/library-api/test-setup.md global ~/projects/acme/prompts/repos/api.gitconfig
                hides ~/projects/acme/prompts/library/test-setup.md
#rule:testing   ~/projects/acme/prompts/library/testing.md global ~/projects/acme/prompts/work.gitconfig
```

and in `/tests` from there, the prompt is: the rules (yours, the group's,
api's), the description, `testing.md` then api's `test-setup.md`, the
persona's task, the file, your query; each later one winning where they
differ.

Worth knowing about this layout:

- **Setting up a new machine** is the clone and one command, nothing per
  repository:

  ```sh
  git config -f ~/.gitconfig.local 'includeIf.gitdir:~/projects/acme/.path' ~/projects/acme/prompts/work.gitconfig
  ```

- **`gitdir:` is the git directory**, not the checkout: `.git`, or `.bare`
  and `.bare/worktrees/<name>` in a bare repository, where `.git` in each
  worktree is a file pointing there. A trailing `/` matches everything
  under the folder, so every worktree of every repository there.
- **The included files are `global`**, each value with the file it comes
  from. `:AiRule --global` opens yours in `~/.gitconfig`, never these;
  `:AiUnset` removes a value from whichever file sets it.
- **A new repository** is a commit: its `repos/<name>.gitconfig` and its
  `includeIf` in `work.gitconfig`. Nothing is set in the repository's own
  config (`.git/config`, `.bare/config`); a value left there next to the
  included one is refused for `repository`, so you see it.
- **Nothing in the repository itself is read.** What briefs the agent is
  in your prompts repository and your config files, so a repository you
  clone still can't brief it.

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

## Rules for a task

`vim-prompts.rules` goes with every ask, `/review` and `/explain` included.
Rules that only matter for one kind of task (writing tests, writing a
migration) go in a library instead, a directory of rules files named in
git config, and are sent when an ask names them:

```ini
# ~/work/.gitconfig, the group's
[vim-prompts]
	rules = ~/work/prompts/rules/general.md     # every ask
	library = ~/work/prompts/library            # testing.md, migrations.md
```

```vim
:Ai #rule:testing add a test for the empty case
:Ai #rule:<Tab>
```

`<Tab>` lists the names that apply where you are, so the same name works in
every repository: give one its own version by naming a library of its own,
with a file of the same name, in its config:

```sh
git config --add vim-prompts.library ~/work/prompts/library-gecowt   # its testing.md
```

A persona for the task takes the rule itself, so it is never forgotten:

```markdown
---
context: [file, "rule:testing"]
---
```

A persona's rule that isn't found anywhere is left out; one you ask for with
`#rule:` that isn't found refuses the ask.

Rules for the task go with the other rules, last, as the most specific of
them, so the persona's own instructions and your query, which come after
the rules, still win over them: "fix the first failure" in `testing.md`
doesn't override a persona's "don't edit unless I ask". `--bare` leaves out
the other rules but keeps these, since the ask names them.

## Removing a setting

`:AiUnset {key} [value]` removes a value from the file that sets it: yours,
a group's included file, the repository's or the worktree's. `<Tab>`
completes the keys set here, then their values as git stores them.

```vim
:AiUnset dir                         " a key no longer read
:AiUnset rules testing.md            " a rules file, by its file name
:AiUnset rules ""                    " the empty value
:AiUnset library ~/work/prompts/library
```

Without a value it removes the key's only one. A value set in several
files is removed from the last, the one that applies; run it again for the
next.

By hand, `git config --unset` matches the value as written, `~` and all,
fails when a key has several values, and only reaches the file you name:

```sh
git config --show-origin --get-regexp '^vim-prompts\.'     # the file, and the value as written
git config -f <file> --fixed-value --unset-all vim-prompts.rules '~/work/prompts/rules/testing.md'
```

## A repository you didn't write

Its `.vim-prompts/` (or anything else) is not read until you name it in its
config. Read it first: a persona can pass the agent arguments (`args:`).
