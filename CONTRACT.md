# The persona contract, version 1

What vim-prompts promises a persona, and what a persona must be. A pack (a
repository of personas) that keeps to it works with any vim-prompts that
implements its version.

## Vocabulary

- **Query**: what the user types.
- **Context source**: something Vim shows, turned into text: the review
  comments, the diffs open, a `:G diff --name-only` list. Asked for as
  `#name`. Sources are part of vim-prompts, not of packs.
- **Persona**: a template, the sources it always takes, and how the agent
  runs for it. Asked for as `@name`. Packs provide personas.
- **Request**: the query, the persona, the sources (the persona's and those
  asked for), and where it was asked: buffer, line, range or selection.
- **Template**: the persona's text, with slots for the query, the selection
  and the context.
- **Prompt**: the template rendered for the request. It is the agent's first
  message, sent at once or after editing it as a draft; the session then goes
  on in the agent.

The user asks, Copilot Chat style:

```vim
:Ai @review #comments why is this here
```

`@review` is the persona (`default` when none is given, and only as the first
word), `#comments` adds a context source to the persona's own, and the rest is
the query. After `--` everything is query as typed, `#` and `@` included.

## Packs

A pack is a directory named `personas/` holding one file per persona,
`<name>.md`:

- in a Vim plugin, so `Plug 'someone/review-personas'` installs it (any
  `personas/` on `'runtimepath'`, including `~/.vim/personas/`), or
- at the root of a git repository, as `.vim-personas/`, for that repo only.

`<name>` is letters, digits, `-` and `_`, starting with a letter; it is asked
for as `@<name>`. `default` is the persona asked without one.

The same name in two packs is an error the user must resolve. vim-prompts'
own personas give way to any pack's; a repo's give way to none unless the user
sets `g:prompts_repo_override`.

## Persona files

Markdown: optional frontmatter between `---` lines, then the template.

```markdown
---
contract: 1
context: [diff_files, diff_pairs]
args: {claude: [--permission-mode, plan]}
---
I am reviewing a change in Vim. Don't edit any files.

{context}

{selection}

Start with a short summary, then go file by file.

{query}
```

### Frontmatter

One `key: value` per line; values are words, `"quoted strings"`, `[lists]` and
`{maps}`, on one line. `#` after a space starts a comment. Unknown keys are an
error, so a typo doesn't pass silently.

| Key | Value | Default |
| --- | --- | --- |
| `contract` | The contract version the persona is written for. A newer one than vim-prompts implements is an error that asks to update it. | `1` |
| `context` | The sources the persona always takes. The user adds more with `#name`. | `[]` |
| `agent` | `claude` or `copilot`: the agent to prefer, when installed. | the user's |
| `args` | Extra CLI arguments: a list, or a map from agent to list (`{claude: [...], copilot: [...]}`); an agent not in the map gets none. | `[]` |
| `consume_comments` | `true`: the user's review comments are cleared once the agent has started with them. | `false` |

### When a persona can be asked

Context is explicit: the persona's `context` plus what the user asks for with
`#`; nothing else is sent, whatever is open. Asking is refused, saying what is
missing, when

- a source the user asked for with `#` has nothing, or
- the persona has sources and none of them has anything, and there is no
  selection.

`:Ai!` asks anyway. A persona with no `context` can always be asked.

### Template

Text with slots; anything else in braces stays as written.

| Slot | Becomes |
| --- | --- |
| `{query}` | The query. |
| `{selection}` | The range or visual selection, fenced, with path and lines. A range is always sent; it is not a source. |
| `{context}` | The context of the request's sources, in order: the persona's, then those asked for. |
| `{<source>}` | That source's context, here instead of in `{context}`; empty when the request doesn't have it. |

Nothing asked for is dropped. Without `{query}` the query is appended last,
after "Additional request from the user:"; without `{context}` or
`{selection}`, those go just before the query. So put the query last ("here is
the situation, here is what I want").

A slot with nothing becomes empty, and runs of blank lines left behind are
collapsed. So give each slot its own paragraph and write no heading for it:
every source brings its own. Context text is never taken for a slot, so a
comment that says `{query}` stays as written.

## Context sources

Each gives a whole block, with its heading, or nothing.

Paths are relative to the root of the git work tree, which is the agent's
working directory. A version of a file that isn't in the work tree (the index,
a commit) is named by its git object, which the agent reads with
`git show <object>`, e.g. `git show :0:foo.c`.

| Source | Has context when | Gives |
| --- | --- | --- |
| `#file` | the buffer is a file or git object | its path and the line (the range's first, or the cursor's) |
| `#diff_files` | a `:G diff --name-only` or `--name-status` buffer is in the tab | its files (only the range's, when asked from that buffer) and the `git diff` command to read each one with |
| `#diff_pairs` | a tab has a diff of two or more files or git objects | each diff's sides, left to right |
| `#comments` | the user has review comments (git-extras `:Comment`) | each comment: `path:line` or `path:start-end`, the lines quoted with `> `, then the comment |

A source's text is for the agent to read, not for a template to parse; its
wording may change. What doesn't change within a version: the source names,
when each has context, and the kind of information it gives.

## Versions

Every change to the contract is a new version, additions included (a new
source, a new frontmatter key, a new slot), so an older vim-prompts can tell
that a persona needs more than it has. A persona sets `contract:` to the
version whose sources, keys and slots it uses.

Changes only add: a source, key or slot, once in the contract, keeps its name
and meaning, so a persona written for version 1 works with every later
vim-prompts.
