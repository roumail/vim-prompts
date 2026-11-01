# @files

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
(`--add-dir`), so it may read them. That is done for you: name or pick the
files, and each one's directory is added once. `--add-dir` is the agent's
flag, not one `:Ai` takes.

## Picking files

A bare `@` picks files in the project, and `@~/` or any `@dir/` picks there.
That needs a picker: a function called with the directory and a callback,
which it calls with the absolute paths picked, at once or later (fzf runs in
a terminal and calls back when you're done).
[fzf-utils](https://github.com/roumail/fzf-utils) has one:

```vim
let g:prompts_file_picker = 'fzf_utils#pick_files'
```

`:Ai @` alone sends the files you pick and waits for your question in the
agent.

The picker lists files, not directories, and fzf-utils' takes several
(`<Tab>` marks one). An ask opens one picker, so a second `@dir/` is an
error: to pick in `~/A/B` and `~/A/C`, pick from their parent, `:Ai @~/A/`.
Files named outright (`@~/A/B/*.py`) can go with it, as many as you like.
