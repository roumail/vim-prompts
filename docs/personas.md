# Personas

A persona is a Markdown file, `<name>.md`, asked for as `/name`: optional
frontmatter saying which context it takes and how the agent runs, then the
prompt itself, with slots that vim-prompts fills in.

```markdown
---
context: [changes]
mode: ask
---
{rules}

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
| `/review` | `#agent_comments` | Reviews what you give it (a selection, `@files`, `#changes`, …), and answers your comments if you add `#comments`; refused with nothing to review (`input: required`). A one-off (`answer: oneoff`): the answer in a buffer, its comments back as a list for `:AiComments`. Ask mode. |
| `/review:pr` | `[#diff_pairs, #changes]` | [A variant](#variants) of `/review`: the diffs you have open, else your branch's changes. |

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
context: [here]
---
{base}

In this repository, tests go only through the Flask test client.
```

- **The template below** goes where `{base}` is, without its `{query}` and
  without any slot this one names itself: each slot is filled once, where
  this one puts it (the query, if this one doesn't, last). A `{context}`
  after your own instructions keeps the context there, not where the one
  below had it.
- **Its frontmatter** applies under this one's: a key this one sets wins,
  and `context` is both, the one below's first.
- **The one below** may have its own `{base}`, down to the built-in one.
  `{base}` with nothing below is an error.

`:AiPersonas` lists the files each persona builds on.

## Variants

A variant is a persona's version for one kind of ask, `/review:pr`, kept in
a directory named for the persona: `<dir>/review/pr.md`. Its files go above
the persona's, so with `{base}` it builds on `/review` as it is where you
ask (the bundled one, or yours on it) and says only what differs. The
bundled `/review:pr` is all frontmatter:

```markdown
---
context: [[diff_pairs, changes]]
---
{base}
```

So your `/review`, with your rules and the shape of answer you want, is
your `/review:pr` too, and a variant of your own adds to the bundled one as
a persona does, say a rule only pull requests need:

```markdown
---
context: [+testing]
---
{base}
```

Variants stack across directories as personas do, and without `{base}` one
replaces everything below it, the persona included. `/review<Tab>`
completes `/review` and `/review:`, and `/review:<Tab>` its variants.
`:AiPersonas` lists each variant after its persona.

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
| `context` | The [sources](sources/) the persona always takes, as `name` or `"name:arg"` (`["repo:tpope/vim-dispatch"]`). `[a, b]` is the first of them that has something (`[[diff_pairs, changes]]`). `+name` is a rule for the task (`[here, +testing]`), and `+name?` one it goes without where there is none. The user adds more, and one added whose argument says which of it (`#changes:staged`) takes the place of the persona's of that name. | `[]` |
| `input` | `required`: refused with nothing to work on, even without a `context` of its own ([refused](#frontmatter)). | `optional` |
| `agent` | `claude` or `copilot`: the agent to prefer, when installed ([which agent runs](agent.md#which-agent-runs)). | the user's |
| `mode` | `ask`, `plan`, `agent` or `auto`: the [mode](agent.md#modes) the agent starts in. `--<mode>-mode` in the ask wins. | `g:prompts_mode` |
| `answer` | `oneoff`: the agent answers once, into a buffer, as with `:Ai!`, and `:Ai!` opens a session instead ([one-off](usage.md#ai)). `session`: it opens a session. | `session` |
| `args` | Extra CLI arguments: a list, or a map from agent to list (`{claude: [...], copilot: [...]}`); an agent not in the map gets none. | `[]` |

An ask is refused, saying why, when:

- **There is nothing to work on.** None of the persona's sources, those
  added or the `@` files has anything, and there is no selection. This
  applies to a persona with `context`, and to one with `input: required`
  even without a `context` of its own. Your query doesn't count, so
  `:Ai /review is this right` with nothing selected is refused rather than
  sent to an agent with nothing to review. Sources that only say how to
  work, `+name` rules and `#agent_comments`, don't count either. `--force` sends
  it anyway.
- **A rule the persona names isn't there.** Each `+name` in `context` must
  be in a task-rules directory where you ask: one that isn't is a typo, or a
  directory not set up on this machine, and should be fixed rather than
  missed. `+name?` marks a rule the persona goes without where there
  is none. `--force` doesn't send it.
- **A source you typed has nothing**, or an `@file` is missing.

## Template

Everything after the frontmatter. Slots are replaced; anything else in braces
stays as written.

| Slot | Becomes |
| --- | --- |
| `{query}` | What the user typed. |
| `{selection}` | The range or visual selection, fenced, with path and lines. |
| `{rules}` | The [rules](#rules), the repository's description, then the rules for the task (`+name`); with `--bare`, only those for the task. |
| `{base}` | The persona this one hides ([building on it](#building-on-another-persona)). |
| `{context}` | Every source's text, in order: the persona's, those added, then the files. |
| `{<source>}` | One source's text here instead of in `{context}` (`{comments}`, `{files}` for the `@` files). |

Nothing is dropped. Without `{query}` the query goes last, after "Additional
request from the user:"; without `{rules}`, `{context}` or `{selection}`,
those go just before the query. So write the situation first and the query
last.

A slot with nothing becomes empty, and the blank lines left behind collapse.
Give each slot its own paragraph and no heading: every source brings its own.

## Rules

`{rules}` is what git config says about where you ask: each
`vim-prompts.rules` file (a later one hiding an earlier one of its file
name), then the repository's own description,
`vim-prompts.repository`, last, as the most specific rule, with the agent
told the later wins where they differ. See [configuration](config.md).
`--bare` leaves them out of one ask.

Rules for one kind of task come from `vim-prompts.task-rules`, by name, as a source:
`context: [here, +testing]` in the persona, or `+testing` in the
ask ([rules for a task](config.md#rules-for-a-task)); either way the ask is
refused where there is none, unless the persona's is `+testing?`. They go last in
`{rules}`, so what the persona says after `{rules}` wins over them; a
template with `{rule}` places them there instead, outside `{rules}`.
