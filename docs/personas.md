# Personas

A persona is a Markdown file, `<name>.md`, asked for as `/name`: optional
frontmatter saying which context it takes and how the agent runs, then the
prompt itself, with slots that vim-prompts fills in.

```markdown
---
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

A persona file is read again on each ask, so edits apply at once. New files
need `:AiPersonas!`, which also lists where every persona comes from.

## Where personas go

| Where | For |
| --- | --- |
| `~/.vim/personas/` | yours, in every repository |
| `personas/` in a plugin | personas a plugin ships |
| `.vim-prompts/personas/` in a repository | that repository's; commit them to share |

Names are letters, digits, `-` and `_`, starting with a letter.

## Overriding a persona

To change `/review`, copy it and edit the copy:

```sh
mkdir -p ~/.vim/personas
cp ~/.vim/plugged/vim-prompts/personas/review.md ~/.vim/personas/
```

Then `:AiPersonas!`. Yours now replaces the built-in `/review` everywhere.

Which one wins when two have the same name:

- **Built-in** personas give way to any other.
- **Yours and plugins'** (both are on `'runtimepath'`) can't share a name:
  the second is an error, and the first one found is used.
- **A repository's** replaces a built-in one, but not yours: the same name as
  yours is an error, and yours is used. A repository persona can pass the
  agent arguments (`args:`), so a repository you clone can't change what your
  `/review` does unless you allow it:

  ```vim
  let g:prompts_repo_override = 1   " a repository's persona may replace yours
  ```

## Frontmatter

One `key: value` per line; values are words, `"quoted strings"`, `[lists]` and
`{maps}`, on one line. `#` after a space starts a comment. An unknown key is
an error, so a typo doesn't pass silently.

| Key | Value | Default |
| --- | --- | --- |
| `context` | The sources the persona always takes, as `name` or `"name:arg"` (`["repo:tpope/vim-dispatch"]`). The user adds more. | `[]` |
| `agent` | `claude` or `copilot`: the agent to prefer, when installed. | the user's |
| `args` | Extra CLI arguments: a list, or a map from agent to list (`{claude: [...], copilot: [...]}`); an agent not in the map gets none. | `[]` |
| `consume_comments` | `true`: the user's review comments are cleared once the agent has started with them. | `false` |

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

## Context sources

What each source gives, for choosing a persona's `context`. Paths are relative
to the repository root, the agent's working directory. A version of a file
that isn't in the work tree is named by its git object (`git show :0:foo.c`).

| Source | Argument | Has something when | Gives |
| --- | --- | --- | --- |
| `file` | none | the buffer is a file or git object | its path and the line |
| `diff_files` | none | a `:G diff --name-only` or `--name-status` buffer is in the tab | its files (the range's, when asked from it), and the `git diff` to read each |
| `diff_pairs` | none | a tab has a diff of two or more files or git objects | each diff's sides, left to right |
| `comments` | none | there are review comments (git-extras `:Comment`) | each comment with `path:line` and the lines quoted |
| `files` (`@path`) | the files | always | the files for the agent to read |
| `repo` | required: `owner/name` or its URL | the argument is a repository | the repository, and how to read it with `gh` |
| `stackoverflow` | optional: search terms | always | a request to search Stack Overflow and link the answers used |

Remote sources fetch nothing: they tell the agent where to look.

## Writing a source

A plugin, or your `~/.vim`, adds `#name` with
`autoload/prompts/sources/<name>.vim` (letters, digits and `_`), defining two
functions:

```vim
" What it needs, said when it has nothing; whether it takes an argument
function! prompts#sources#jira#info() abort
  return {'needs': 'a ticket: #jira:KEY-123', 'arg': 'required'}
endfunction

" Its text, heading included, or '' when it has nothing here
function! prompts#sources#jira#context(request, arg) abort
  return 'Jira ticket ' . a:arg . ': read it with `jira issue view ' . a:arg . '`.'
endfunction
```

`arg` is `'none'`, `'optional'` or `'required'`; an ask that gives the wrong
kind is refused before `context()` is called. `context()` is called at most
once per ask, and must not change anything or wait on the network.

`request` is read only:

| Key | Value |
| --- | --- |
| `query` | the query |
| `bufnr`, `line` | the buffer the ask was made in, and its line |
| `range`, `line1`, `line2` | `0` without a range; the range's lines |
| `selection`, `charwise` | the selected lines (or text, when `charwise`) |

Of two sources with the same name, the first on `'runtimepath'` is used. The
`prompts#source#*` helpers are internal and may change.
