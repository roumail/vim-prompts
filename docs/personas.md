# Personas

A persona is a Markdown file, `<name>.md`, asked for as `/name`: optional
frontmatter saying which context it takes and how the agent runs, then the
prompt itself, with slots that vim-prompts fills in.

```markdown
---
context: [changes]
mode: ask
---
{repository}

I am reviewing a change in Vim. Don't edit any files.

{context}

{selection}

Start with a short summary, then go file by file.

{query}
```

A persona file is read again on each ask, so edits and new files apply at
once. `:AiPersonas` lists where every persona comes from.

## Built-in personas

| Persona | Context | Does |
| --- | --- | --- |
| `/default` | | Your query, the selection, and what you add. Used without a `/persona`. |
| `/explain` | `#file` | Explains the selection, or the code at your line. Doesn't edit. |
| `/review` | `#changes` | Reviews your branch's changes, and answers your comments if you add `#comments`. Ask mode. |

## Where personas go

In directories that git config names, `vim-prompts.personas`, at whatever
level they apply: yours in `~/.gitconfig`, a group's in a file it includes,
one repository's in its own config ([configuration](config.md)):

```sh
git config --global --add vim-prompts.personas ~/dotfiles/prompts/personas
git config --add vim-prompts.personas .vim-prompts/personas   # this repository's
```

Names are letters, digits, `-` and `_`, starting with a letter.

## Which persona is used

The last of its name: the built-in ones first, then each directory in the
order git config lists them, so a repository's beats its group's, and a
group's beats yours. `:AiPersonas` shows where each one comes from.

To change the built-in `/review`, copy it into one of your directories and
edit the copy:

```sh
cp ~/.vim/plugged/vim-prompts/personas/review.md ~/dotfiles/prompts/personas/
```

## Building on another persona

A persona that hides one of its name replaces it, unless its template has
`{base}`: then the one below goes there, so a repository adds to its group's
`/tests` instead of copying it:

```markdown
---
context: [file]
---
{base}

In this repository, tests go only through the Flask test client.
```

- **The template below** goes where `{base}` is, without its `{query}`: the
  query goes where this one puts it, or last.
- **Its frontmatter** applies under this one's: a key this one sets wins,
  and `context` is both, the one below's first.
- **The one below** may have its own `{base}`, down to the built-in one.
  `{base}` with nothing below is an error.

`:AiPersonas` lists the files each persona builds on.

## Skills

A persona says how to ask and with what; a skill says how the agent does
something (your way of rebasing, say). Skills belong to the agents, not to
vim-prompts: put one in `~/.claude/skills/<name>/SKILL.md`, which Claude Code
and Copilot CLI both read, and the agent uses it when a request calls for it.
A persona that should always use one says so in its text: "Follow the
`rebase` skill."

## Frontmatter

One `key: value` per line; values are words, `"quoted strings"`, `[lists]` and
`{maps}`, on one line. `#` after a space starts a comment. An unknown key is
an error, so a typo doesn't pass silently.

| Key | Value | Default |
| --- | --- | --- |
| `context` | The [sources](sources/) the persona always takes, as `name` or `"name:arg"` (`["repo:tpope/vim-dispatch"]`). The user adds more. | `[]` |
| `agent` | `claude` or `copilot`: the agent to prefer, when installed ([which agent runs](agent.md#which-agent-runs)). | the user's |
| `mode` | `ask`, `plan`, `agent` or `auto`: the [mode](agent.md#modes) the agent starts in. `--<mode>-mode` in the ask wins. | `g:prompts_mode` |
| `args` | Extra CLI arguments: a list, or a map from agent to list (`{claude: [...], copilot: [...]}`); an agent not in the map gets none. | `[]` |

A persona with `context` is refused, saying what is missing, when none of its
sources (its own, those added, the files) has anything and there is no
selection. A source asked for with `#` that has nothing, or a missing `@file`,
is always refused. `:Ai!` asks anyway.

## Template

Everything after the frontmatter. Slots are replaced; anything else in braces
stays as written.

| Slot | Becomes |
| --- | --- |
| `{query}` | What the user typed. |
| `{selection}` | The range or visual selection, fenced, with path and lines. |
| `{repository}` | The [repository context](#repository-context): the rules and the repository's description; empty without them. |
| `{base}` | The persona this one hides ([building on it](#building-on-another-persona)). |
| `{context}` | Every source's text, in order: the persona's, those added, then the files. |
| `{<source>}` | One source's text here instead of in `{context}` (`{comments}`, `{files}` for the `@` files). |

Nothing is dropped. Without `{query}` the query goes last, after "Additional
request from the user:"; without `{repository}`, `{context}` or `{selection}`,
those go just before the query. So write the situation first and the query
last.

A slot with nothing becomes empty, and the blank lines left behind collapse.
Give each slot its own paragraph and no heading: every source brings its own.

## Repository context

`{repository}` is what git config says about where you ask: each
`vim-prompts.rules` file, then the repository's own description,
`vim-prompts.repository`, last, with the agent told the later wins where they
differ. See [configuration](config.md).
