# vim-prompts

Ask an AI agent CLI ([Claude Code](https://claude.com/claude-code) or
[Copilot CLI](https://github.com/github/copilot-cli)) from Vim, in its own
grammar: a **persona** with `/`, **context** with `#`, files with `@`, then
your **query**.

```vim
:Ai /review #comments @~/notes/design.md why does this differ
```

The persona's template, rendered with your query, the context and what the
repository is (its `.vim-prompts/repository.md`), is the agent's first
**prompt**; the session then goes on in the agent, started with vim-dispatch's
`:Start`. You can also edit the prompt first, as a draft.

The agent can't see your editor; this tells it what you're looking at, and only
what you ask for. It is a launcher: install the CLI and set it up (login,
model, settings) yourself. The plugin checks that it is executable, the way a
plugin checks for `gh`.

[CONTRACT.md](CONTRACT.md) defines personas, templates and context sources,
for writing your own or a pack of them.

## Commands

The prefix is `g:prompts_namespace`, `Ai` by default.

| Command | What it does |
| --- | --- |
| `:[range]Ai[!] [/persona] [#source...] [@file...] [query] [-- text]` | Ask the persona (`/default` without one) with its context and what you add. A range or visual selection is sent too. Refused, saying what is missing, when there is no context to send; `!` asks anyway. |
| `:Ai` | With nothing: open the agent, or go back to the session `:Ai` opened before. |
| `:[range]AiDraft[!] ...` | The same, but the prompt opens in a buffer to edit first. `:w` sends it and keeps the draft open (edit and `:w` again for another session), `:wq` sends it and closes the draft, `:q!` drops it. |
| `:AiPersonas[!]` | The personas, their context, where each comes from, and what each needs that isn't here. With `!`, reload the persona and source files first. |

```vim
:G diff --cached --name-only
:Ai /review I don't understand why the gate runs at call time
:Ai /review #comments I have the following comments
:Ai /comments I think the second comment is wrong
:'<,'>Ai /explain
:Ai @ @~/src/other-service/api.py how do these two fit together
:Ai #repo:tpope/vim-dispatch how does :Start pick a handler
:Ai #stackoverflow:"vim term_start cwd" why does my terminal open elsewhere
:AiDraft /review #comments
```

`<Tab>` completes `/personas` (first word), `#sources` and `@files`. After
`--`, everything is your query as typed, so `#include`, `@decorator` or
`--flags` need nothing special: `:Ai /review -- why is #include here?`. Before
`--`, an unknown `#word` or a missing `@file` is an error, so a typo doesn't
get sent as text.

### Context

Only what the persona takes and what you add is sent, whatever else is open.

| | What it sends |
| --- | --- |
| `#file` | The current file and line. |
| `#diff_files` | The files in the tab's `:G diff --name-only` buffer, and the `git diff` to read each with: `:G diff --cached --name-only` gives `git diff --cached -- <path>`. Delete lines, or ask from a range of that buffer, to send fewer. |
| `#diff_pairs` | Every tab's diff, side by side: `` `:0:foo.c` (index) vs `foo.c` (work tree) ``. The agent reads a side with `git show`. |
| `#comments` | Your review comments from [git-extras](https://github.com/roumail/git-extras) (`:Comment`), each with the lines it is on. |
| `@path` | Files for the agent to read: `@src/app.py`, `@~/notes/*.md`, `@"~/My Notes/a.md"`. A bare `@` picks files in the project, `@~/` or any `@dir/` picks there (needs `g:prompts_file_picker`). Files outside the repo are opened to the agent with `--add-dir`. |
| `#repo:owner/name` | A GitHub repository, for the agent to read with `gh` (`#repo:https://github.com/owner/name` works too). |
| `#stackoverflow[:"terms"]` | Has the agent search Stack Overflow, for the terms or for your query, and link the answers it used. |

The agent fetches remote context itself, so Vim never waits on the network.
A plugin (or your `~/.vim`) can add sources: see
[Writing a source](CONTRACT.md#writing-a-source).

### Repository context

Put what a repository is in `.vim-prompts/repository.md` at its root: a Flask
app, an ETL tool, a FastAPI service; its layout, conventions, how to run the
tests. It goes with every ask made in that repository, so your query always
comes with it. Commit it to share it, or list `.vim-prompts/` in
`.git/info/exclude` to keep it to yourself.

### Personas

| Persona | Context | Does |
| --- | --- | --- |
| `/default` | | Your query, the selection, and what you add. |
| `/review` | `#diff_files #diff_pairs` | Reviews the change; add `#comments` to have it answer yours. Read only (Claude: plan mode). |
| `/explain` | `#file` | Explains the selection, or the code at your line. |
| `/comments` | `#comments` | Talks about your comments. |
| `/fix-comments` | `#comments` | Changes the code to address them, then clears them. |

Your own go in `~/.vim/personas/<name>.md`, a repository's in
`.vim-prompts/personas/`, and a plugin can ship them in `personas/` (a pack).
Yours replace these by name. A persona file is read again each time, so edits
apply at once; new files need `:AiPersonas!`.

### Mappings

No keys are bound; the `<Plug>` mappings type the command for you to finish
(`:'<,'>Ai ` from visual mode):

```vim
nmap <leader>aa <Plug>(prompts-ask)
xmap <leader>aa <Plug>(prompts-ask)
nmap <leader>ad <Plug>(prompts-draft)
xmap <leader>ad <Plug>(prompts-draft)
```

## Picking files

A bare `@`, or `@dir/`, calls `g:prompts_file_picker` with the directory and a
callback, which it calls with the absolute paths picked (now, or later, as
fzf does). [fzf-utils](https://github.com/roumail/fzf-utils) has one, using
the same fd listing as `:FdFiles`:

```vim
let g:prompts_file_picker = 'fzf_utils#fd#files#pick'
```

## The agent

The agent starts with `:Start`, in the repo root, so it opens where your
`:Start` strategy puts it (a tmux window, a Vim terminal). Each prompt is
written to `.git/vim-prompts/prompts/` and passed as `"$(cat <file>)"`.

```vim
let g:prompts_agents = ['claude', 'copilot'] " the first installed one is used
let g:prompts_agent = ''                     " force one
let g:prompts_max_arg = 100000               " longer prompts: the agent is told to read the file
```

With no `g:prompts_agent`, each machine uses whichever CLI it has, so one vimrc
serves a machine with Claude Code and one with Copilot CLI. They start as
`claude [args] <prompt> [--add-dir dir...]` and
`copilot [args] -i <prompt> [--add-dir dir...]`; add or change one with
`g:prompts_agent_table`:

```vim
let g:prompts_agent_table = {'mycli': {'cmd': ['mycli', '--tui'], 'prompt': ['--prompt'], 'dir': '--allow'}}
```

## Configuration

```vim
let g:prompts_namespace = 'Ai'     " command prefix
let g:prompts_repo_override = 0    " 1: a repository's persona may replace yours of the same name
```

## Install

Requires Vim 9.1 or later, [vim-fugitive](https://github.com/tpope/vim-fugitive),
[vim-dispatch](https://github.com/tpope/vim-dispatch) and
[git-extras](https://github.com/roumail/git-extras); without them the plugin
warns once and defines nothing. Plus the agent CLI.

```vim
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-dispatch'
Plug 'roumail/git-extras'
Plug 'roumail/vim-prompts'
```
