# vim-prompts

Ask an AI agent CLI ([Claude Code](https://claude.com/claude-code) or
[Copilot CLI](https://github.com/github/copilot-cli)) the way you ask Copilot
Chat in an editor: pick a **persona** with `@`, add **context** with `#`, type
your **query**.

```vim
:Ai @review #comments why is this here
```

The persona's template, rendered with your query and the context, is the
agent's first **prompt**; the session then goes on in the agent, started with
vim-dispatch's `:Start`. You can also edit the prompt first, as a draft.

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
| `:[range]Ai[!] [@persona] [#source...] [query] [-- text]` | Ask the persona (`@default` without one) with its context and the sources you add. A range or visual selection is sent too. Refused, saying what is missing, when there is no context to send; `!` asks anyway. |
| `:Ai` | With nothing: open the agent, or go back to the session `:Ai` opened before. |
| `:[range]AiDraft[!] ...` | The same, but the prompt opens in a buffer to edit first. `:w` sends it, `:wq` sends and closes, `:q!` drops it. |
| `:AiPersonas[!]` | The personas, their context, where each comes from, and what each needs that isn't here. With `!`, reload the persona files first. |

`<Tab>` completes `@personas` (first word) and `#sources` (anywhere). After
`--`, everything is your query as typed, so text with `#include`, a leading
`@` or `--flags` needs nothing special: `:Ai @review #comments -- why is
#include here?`. The `#` and `@` grammar only reads what comes before `--`; an
unknown `#word` there is an error, so a typo doesn't get sent as text.

```vim
:G diff --cached --name-only
:Ai @review I don't understand why the gate runs at call time
:Ai @review #comments I have the following comments
:Ai @comments I think the second comment is wrong
:'<,'>Ai @explain
:'<,'>Ai what does this do
:AiDraft @review #comments
```

### Context sources

Only what the persona takes and what you add is sent, whatever else is open.

| Source | What it sends |
| --- | --- |
| `#file` | The current file and line. |
| `#diff_files` | The files in the tab's `:G diff --name-only` buffer, and the `git diff` to read each with: `:G diff --cached --name-only` gives `git diff --cached -- <path>`. Delete lines, or ask from a range of that buffer, to send fewer. |
| `#diff_pairs` | Every tab's diff, side by side: `` `:0:foo.c` (index) vs `foo.c` (work tree) ``. The agent reads a side with `git show`. |
| `#comments` | Your review comments from [git-extras](https://github.com/roumail/git-extras) (`:Comment`), each with the lines it is on. |

### Personas

| Persona | Context | Does |
| --- | --- | --- |
| `@default` | | Your query, the selection, and what you add. |
| `@review` | `#diff_files #diff_pairs` | Reviews the change; add `#comments` to have it answer yours. Read only (Claude: plan mode). |
| `@explain` | `#file` | Explains the selection, or the code at your line. |
| `@comments` | `#comments` | Talks about your comments. |
| `@fix-comments` | `#comments` | Changes the code to address them, then clears them. |

Your own go in `~/.vim/personas/<name>.md`, a repo's in `.vim-personas/` at its
root, and a plugin can ship them in `personas/` (a pack). Yours replace these
by name. A persona file is read again each time, so edits apply at once; new
files need `:AiPersonas!`.

### Mappings

No keys are bound; the `<Plug>` mappings type the command for you to finish
(`:'<,'>Ai ` from visual mode):

```vim
nmap <leader>aa <Plug>(prompts-ask)
xmap <leader>aa <Plug>(prompts-ask)
nmap <leader>ad <Plug>(prompts-draft)
xmap <leader>ad <Plug>(prompts-draft)
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
`claude [args] <prompt>` and `copilot [args] -i <prompt>`; add or change one
with `g:prompts_agent_table`:

```vim
let g:prompts_agent_table = {'mycli': {'cmd': ['mycli', '--tui'], 'prompt': ['--prompt']}}
```

## Configuration

```vim
let g:prompts_namespace = 'Ai'     " command prefix
let g:prompts_repo_override = 0    " 1: a repo's persona may replace yours of the same name
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
