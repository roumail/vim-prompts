# The vim-prompts contract, version 2

What vim-prompts promises personas and context sources, and what they must
be. A pack (a repository of personas and sources) that keeps to it works with
any vim-prompts that implements its version.

## Vocabulary

- **Query**: what the user types.
- **Context source**: something Vim shows (the review comments, the diffs
  open), or somewhere the agent should look (files, a GitHub repository, a
  Stack Overflow search), turned into text. Asked for as `#name` or
  `#name:arg`; files as `@path`.
- **Persona**: a template, the sources it always takes, and how the agent
  runs for it. Asked for as `/name`.
- **Repository context**: what the repository the user is in is, from its
  `.vim-prompts/repository.md`. Part of every ask in that repository.
- **Request**: the query, the persona, the sources (the persona's, those
  asked for, the files), the repository context, and where it was asked:
  buffer, line, range or selection.
- **Template**: the persona's text, with slots for all of these.
- **Prompt**: the template rendered for the request. It is the agent's first
  message, sent at once or after editing it as a draft; the session then goes
  on in the agent.

The grammar is the agent CLIs' own:

```vim
:Ai /review #comments @~/notes/design.md why does this differ
```

- `/review`, as the first word: the persona (`default` without one).
- `#comments`, `#repo:owner/name`, `#stackoverflow:"terms"`: context sources,
  added to the persona's own. An argument with spaces is quoted.
- `@path`: files (globs work; quote paths with spaces). A bare `@`, or `@dir`,
  lets the user pick files there.
- The rest is the query; after `--` everything is query as typed, `/`, `#`
  and `@` included.

## Packs

A pack is a directory with any of:

- `personas/<name>.md`: one file per persona;
- `autoload/prompts/sources/<name>.vim`: one file per context source.

It is found:

- as a Vim plugin, on `'runtimepath'` (`Plug 'someone/review-personas'`, or
  `~/.vim/`), for both personas and sources, or
- as `.vim-prompts/` at the root of a git repository, for that repository's
  personas (`.vim-prompts/personas/`) and its repository context
  (`.vim-prompts/repository.md`). A repository can't add sources: those are
  code, and run as soon as Vim opens the repository.

Names are letters, digits, `-` and `_` (sources: no `-`), starting with a
letter. The same persona name in two packs is an error the user must resolve.
vim-prompts' own personas give way to any pack's; a repository's give way to
none unless the user sets `g:prompts_repo_override`. Of two sources with the
same name, the first on `'runtimepath'` is used.

## Persona files

Markdown: optional frontmatter between `---` lines, then the template.

```markdown
---
contract: 2
context: [diff_files, diff_pairs]
args: {claude: [--permission-mode, plan]}
---
{repository}

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
| `context` | The sources the persona always takes, as `name` or `"name:arg"` (`["repo:tpope/vim-dispatch"]`). The user adds more. | `[]` |
| `agent` | `claude` or `copilot`: the agent to prefer, when installed. | the user's |
| `args` | Extra CLI arguments: a list, or a map from agent to list (`{claude: [...], copilot: [...]}`); an agent not in the map gets none. | `[]` |
| `consume_comments` | `true`: the user's review comments are cleared once the agent has started with them. | `false` |

### When a persona can be asked

Context is explicit: the persona's `context`, what the user asks for, and the
repository context; nothing else is sent, whatever is open. Asking is refused,
saying what is missing, when

- a source the user asked for with `#` has nothing, or a file given with `@`
  doesn't exist, or
- the persona has sources, none of the request's sources (the persona's,
  those added, the files) has anything, and there is no selection.

`:Ai!` asks anyway. A persona with no `context` can always be asked.

### Template

Text with slots; anything else in braces stays as written.

| Slot | Becomes |
| --- | --- |
| `{query}` | The query. |
| `{selection}` | The range or visual selection, fenced, with path and lines. A range is always sent; it is not a source. |
| `{repository}` | The repository context, with its heading; empty outside a repository that has one. |
| `{context}` | The context of the request's sources, in order: the persona's, those asked for, then the files. |
| `{<source>}` | That source's context, here instead of in `{context}`; empty when the request doesn't have it. `{files}` is the `@` files. |

Nothing asked for is dropped. Without `{query}` the query is appended last,
after "Additional request from the user:"; without `{repository}`, `{context}`
or `{selection}`, those go just before the query, in that order. So put the
query last ("here is the situation, here is what I want").

A slot with nothing becomes empty, and runs of blank lines left behind are
collapsed. So give each slot its own paragraph and write no heading for it:
every source brings its own. Context text is never taken for a slot, so a
comment that says `{query}` stays as written.

## Repository context

`.vim-prompts/repository.md` at the root of a git repository: plain markdown,
what the repository is and how to work in it (a Flask app, an ETL tool: the
layout, the conventions, how to run the tests). It goes in `{repository}` in
every ask made in that repository, under the heading "About this repository".

## Context sources

Paths are relative to the root of the git work tree, which is the agent's
working directory. A version of a file that isn't in the work tree (the index,
a commit) is named by its git object, which the agent reads with
`git show <object>`, e.g. `git show :0:foo.c`. Directories of files outside
the work tree are given to the agent (`--add-dir`), so it may read them.

| Source | Argument | Has context when | Gives |
| --- | --- | --- | --- |
| `#file` | none | the buffer is a file or git object | its path and the line (the range's first, or the cursor's) |
| `#diff_files` | none | a `:G diff --name-only` or `--name-status` buffer is in the tab | its files (only the range's, when asked from that buffer) and the `git diff` command to read each one with |
| `#diff_pairs` | none | a tab has a diff of two or more files or git objects | each diff's sides, left to right |
| `#comments` | none | the user has review comments (git-extras `:Comment`) | each comment: `path:line` or `path:start-end`, the lines quoted with `> `, then the comment |
| `@path` (`files`) | the files | always | the files for the agent to read |
| `#repo` | required: `owner/name` (or its GitHub URL) | the argument is a repository | the repository, and how to read it with `gh` without changing it |
| `#stackoverflow` | optional: search terms | always | a request to search Stack Overflow for the terms, or for the query, and to link the answers used |

Remote sources (`#repo`, `#stackoverflow`) don't fetch anything: they tell the
agent where to look, and the agent reads it with its own tools.

A source's text is for the agent to read, not for a template to parse; its
wording may change. What doesn't change within a version: the source names,
their arguments, when each has context, and the kind of information it gives.

### Writing a source

`autoload/prompts/sources/<name>.vim` defines two functions:

```vim
" What it needs, said when it has nothing; whether it takes an argument
function! prompts#sources#<name>#info() abort
  return {'needs': 'a ticket: #jira:KEY-123', 'arg': 'required'}
endfunction

" Its block, heading included, or '' when it has nothing here
function! prompts#sources#<name>#context(request, arg) abort
  return 'Jira ticket ' . a:arg . ': read it with `jira issue view ' . a:arg . '`.'
endfunction
```

`arg` is `'none'`, `'optional'` or `'required'`; vim-prompts refuses an ask
that gives a source the wrong kind of argument, before calling it. `context()`
is called at most once per request and source, and must not change anything
or wait on the network: a source that needs remote content tells the agent
where to find it.

`request` is read only:

| Key | Value |
| --- | --- |
| `query` | the query |
| `bufnr`, `line` | the buffer the ask was made in, and its line |
| `range`, `line1`, `line2` | `0` without a range; the range's lines |
| `selection`, `charwise` | the selected lines (or text, when `charwise`) |

The `prompts#source#*` helpers vim-prompts' own sources use (path of a
buffer, its git object) may change between versions; a pack's source should
not depend on them.

## Versions

Every change to the contract is a new version, additions included (a new
source, key, slot or request key), so an older vim-prompts can tell that a
persona needs more than it has. A persona sets `contract:` to the version
whose sources, keys and slots it uses.

Changes only add: a source, key or slot, once in the contract, keeps its name
and meaning, so a persona written for an older version works with every later
vim-prompts. Version 2 added sources with arguments, sources as files, `@`
files, `{repository}`, `{files}`, and `/persona` (which was `@persona` in
version 1: the one change that is not an addition, made before any pack
used it).
