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

A persona file is read again on each ask, so edits apply at once. New files
need `:AiPersonas!`, which also lists where every persona comes from.

## Built-in personas

| Persona | Context | Does |
| --- | --- | --- |
| `/default` | | Your query, the selection, and what you add. Used without a `/persona`. |
| `/explain` | `#file` | Explains the selection, or the code at your line. Doesn't edit. |
| `/review` | `#changes` | Reviews your branch's changes, and answers your comments if you add `#comments`. Ask mode. |

## Where personas go

There are two kinds:

- **General**, for every project: `~/.vim/personas/<name>.md` (keep it in
  your dotfiles to have it on every machine), or `personas/` in a plugin.
- **Project**, for one repository: `.vim-prompts/personas/<name>.md` at its
  root. Commit it to share it, or list `.vim-prompts/` in
  `.git/info/exclude` to keep it to yourself.

Names are letters, digits, `-` and `_`, starting with a letter.

## Which persona is used

The most specific one: **project** over **general** over **built-in**. A
general `/review` replaces the built-in one everywhere; a project `/review`
replaces both in that project. Two of the same name at one level (two general
`/review`s) are an error, and the first is used. `:AiPersonas` shows where
each one comes from.

To change the built-in `/review` everywhere, copy it and edit the copy:

```sh
mkdir -p ~/.vim/personas
cp ~/.vim/plugged/vim-prompts/personas/review.md ~/.vim/personas/
```

then `:AiPersonas!`. For one project, copy it to `.vim-prompts/personas/`
instead.

A project persona can pass the agent arguments (`args:`), so check
`.vim-prompts/personas/` in a repository you didn't write.

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
| `mode` | `ask`, `plan` or `agent`: the [mode](agent.md#modes) the agent starts in. `--<mode>-mode` in the ask wins. | `g:prompts_mode` |
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
| `{repository}` | The [repository context](#repository-context); empty without one. |
| `{context}` | Every source's text, in order: the persona's, those added, then the files. |
| `{<source>}` | One source's text here instead of in `{context}` (`{comments}`, `{files}` for the `@` files). |

Nothing is dropped. Without `{query}` the query goes last, after "Additional
request from the user:"; without `{repository}`, `{context}` or `{selection}`,
those go just before the query. So write the situation first and the query
last.

A slot with nothing becomes empty, and the blank lines left behind collapse.
Give each slot its own paragraph and no heading: every source brings its own.

## Repository context

`.vim-prompts/repository.md` at a repository's root says what it is: a Flask
app, an ETL tool; its layout, conventions, how to run the tests. It goes in
`{repository}`, under "About this repository", in every ask made there. Commit
it to share it, or list `.vim-prompts/` in `.git/info/exclude` to keep it to
yourself.
