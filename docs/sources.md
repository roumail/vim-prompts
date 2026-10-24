# Context sources

A source turns something you have in Vim, or somewhere the agent should look,
into text for the prompt. You add one with `#name` (or `#name:argument`),
files with `@path`; a persona can take some by default. Only what is asked
for is sent, whatever else is open.

| | For |
| --- | --- |
| [`#file`](#file) | the file and line you're on |
| [`#diff_files`](#diff_files) | the files of a change, listed with `:G diff --name-only` |
| [`#diff_pairs`](#diff_pairs) | the diffs open in Vim |
| [`#comments`](#comments) | your review comments |
| [`@path`](#files) | files for the agent to read |
| [`#repo`](#repo) | a GitHub repository |
| [`#stackoverflow`](#stackoverflow) | a Stack Overflow search |

A range or visual selection isn't a source: it always goes too.

Sources don't paste file contents or fetch anything. They tell the agent what
to read and how (`git diff`, `git show`, `gh`), and the agent reads it with
its own tools, so Vim never waits and the prompt stays short.

## #file

The file you asked from and your line (the range's first, or the cursor's).
`/explain` takes it.

```
Current file: `src/app.py`, line 42
```

In a fugitive buffer (a commit's or the index's version of a file), the agent
is told the git object to read it with: `` (index version: `git show :0:src/app.py`) ``.

## #diff_files

The files of a change. List them in a tab with fugitive, then ask from that
tab:

```vim
:G diff --cached --name-only        " staged
:G diff main...HEAD --name-only     " the branch
:Ai /review
```

The agent gets the list and the `git diff` to read each file with, so it sees
the same change you do:

```
Changed files (`git diff --cached --name-only`):
- src/app.py
- src/db.py
Read each with `git diff --cached -- <path>`.
```

To send fewer files, delete lines from that buffer, or select some and ask
from there (`:'<,'>Ai /review`). `--name-status` works too. `/review` takes
it.

## #diff_pairs

The diffs open in Vim, in every tab: the two sides of each, left to right.
Open one with `:Gdiffsplit`, or git-extras' `:DiffThis` or `:BranchDiff`.

```
Diffs open in Vim, one per tab:
- `:0:src/app.py` (index) vs `src/app.py` (work tree)
Read a side that is not the work tree with `git show <object>`.
```

`/review` takes it, so a review covers the files you're looking at side by
side as well as the listed ones.

## #comments

Your review comments, from [git-extras](https://github.com/roumail/git-extras).
Leave one on a line or a selection with `:Comment`; they collect in a
quickfix list called Review (`:Comments` opens it), and `:CommentsSave` /
`:CommentsLoad` keep them per branch.

Each comment goes with the lines it is on, quoted from the file as it is now:

```
My review comments (each quotes the lines it is on, then my comment):

src/app.py:40-42
> def handle(event):
>     data = parse(event)
>     return save(data)
why isn't this retried?

src/db.py:7
> TIMEOUT = 5
too short for the batch job
```

Say what you want done with them; the comments alone aren't a question:

```vim
:Ai #comments which of these are worth fixing before merging
:Ai /review #comments
:Ai #comments address each one, and answer the questions
```

`/review #comments` reviews the change and answers each comment. Comments
stay in the list after an ask; clear them in git-extras when you're done.

## Files

`@path` names files for the agent to read:

```vim
:Ai @src/app.py @src/db.py how do these two talk
:Ai @~/notes/*.md what did I decide about retries
:Ai @"~/My Notes/a.md" summarize this
```

Globs, `~` and `$VARS` work; quote a path with spaces. A file that doesn't
exist is an error, not text. The agent gets the paths, relative to the
repository when they're in it:

```
Files to read:
- `src/app.py`
- `/Users/me/notes/retries.md`
```

Files outside the repository have their directories opened to the agent
(`--add-dir`), so it may read them.

### Picking files

A bare `@` picks files in the project, and `@~/` or any `@dir/` picks there.
That needs a picker: a function called with the directory and a callback,
which it calls with the absolute paths picked, at once or later (fzf runs in
a terminal and calls back when you're done).
[fzf-utils](https://github.com/roumail/fzf-utils) has one:

```vim
let g:prompts_file_picker = 'fzf_utils#fd#files#pick'
```

`:Ai @` alone sends the files you pick and waits for your question in the
agent.

## #repo

A GitHub repository, for the agent to read with `gh` (installed and logged
in). Only read: the agent is told not to change it.

```vim
:Ai #repo:tpope/vim-dispatch how does :Start pick a handler
:Ai #repo:https://github.com/tpope/vim-dispatch ...
```

```
GitHub repository `tpope/vim-dispatch` (https://github.com/tpope/vim-dispatch).
Read what you need with `gh repo view tpope/vim-dispatch`, `gh api
repos/tpope/vim-dispatch/contents/<path>` or `gh search code --repo
tpope/vim-dispatch <terms>`, or shallow-clone it into a temporary directory.
Only read it.
```

## #stackoverflow

Has the agent search Stack Overflow: for the terms you give, or for your
question without them. Quote terms with spaces.

```vim
:Ai #stackoverflow why does term_start ignore cwd
:Ai #stackoverflow:"vim term_start cwd" why does my terminal open elsewhere
```

```
Search Stack Overflow for `vim term_start cwd`. Use the answers that fit
(accepted, well voted and recent ones first), say where they disagree, and
link the ones you used.
```

The agent needs web access; it may ask you to allow it.

## Changing a source

A source is a file, `autoload/prompts/sources/<name>.vim`, and the first one
on `'runtimepath'` is used. `~/.vim` comes before your plugins, so to change
`#stackoverflow` (to prefer answers from the last few years, say), copy it
and edit the copy:

```sh
mkdir -p ~/.vim/autoload/prompts/sources
cp ~/.vim/plugged/vim-prompts/autoload/prompts/sources/stackoverflow.vim ~/.vim/autoload/prompts/sources/
```

To change *where* a source's text goes in the prompt, not what it says, use
its slot in a persona instead: see [templates](personas.md#template).

## Writing a source

A new file there adds `#name` (letters, digits and `_`). It defines two
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
once per ask, and must not change anything or wait on the network: tell the
agent where to look instead. Returning `''` means it has nothing, and an ask
that needs it is refused with `needs`.

`request` is read only:

| Key | Value |
| --- | --- |
| `query` | the query |
| `bufnr`, `line` | the buffer the ask was made in, and its line |
| `range`, `line1`, `line2` | `0` without a range; the range's lines |
| `selection`, `charwise` | the selected lines (or text, when `charwise`) |

The `prompts#source#*` helpers the built-in sources use are internal and may
change.
