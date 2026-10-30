# The agent

vim-prompts starts the agent CLI with your prompt as its first message, and
the conversation goes on there. Install the CLI and set it up (login, model,
settings) in the CLI itself.

## Which agent runs

The first of these that applies:

1. `g:prompts_agent`, if you set one: always that agent.
2. The persona's `agent:`, when it's installed.
3. The first installed one of `g:prompts_agents`.

```vim
let g:prompts_agents = ['claude', 'copilot']   " the default
let g:prompts_agent = 'copilot'                 " always this one
```

So with neither set, one vimrc serves a machine with Claude Code and one with
Copilot CLI.

## Where it opens

In the repository root, through vim-dispatch's `:Start`: in a tmux window when
Vim runs in tmux, otherwise in a Vim terminal, in a new tab by default:

```vim
let g:prompts_start_mods = 'tab'   " or 'vertical', or '' for a split
```

In a Vim terminal your keys go to the agent. Leave it with `/exit` (Claude) or
Ctrl-D, which closes the tab. Or press `Ctrl-\ Ctrl-n` for normal mode, then
`gt` to another tab, `:q` to hide it, or `:bwipe!` to end it. `:Ai` alone goes
back to the session it opened.

## Modes

The agent starts in one of four modes:

| Mode | The agent | Claude | Copilot |
| --- | --- | --- | --- |
| `ask` | asks you before each edit or command | `--permission-mode default` | (its config) |
| `plan` | looks around and plans, but doesn't edit | `--permission-mode plan` | `--plan` |
| `agent` | edits without asking (commands still ask) | `--permission-mode acceptEdits` | `--allow-tool=write` |
| `auto` | runs what a model judges safe, asks otherwise | `--permission-mode auto` | (its config) |

It starts in `ask` unless you say otherwise. The first of these that
applies:

1. `--ask-mode`, `--plan-mode`, `--agent-mode` or `--auto-mode` in the ask.
2. The persona's `mode:` (`/review` has `mode: ask`).
3. `g:prompts_mode`.

```vim
let g:prompts_mode = 'auto'   " the default is 'ask'
```

```vim
:'<,'>Ai --plan-mode how would you split this
:Ai /review --agent-mode fix what you find
:Ai --plan-mode
```

Switch modes in the session as usual (Shift+Tab in both).

Copilot can't be started in `ask` or `auto` with a flag, so both start it as
its config says. For `auto`, set that to assisted approval:

```sh
copilot config defaultPermissionMode assisted
```

`ask` then starts it that way too; switch with `/permissions` in the
session.

## The prompt it gets

Each prompt is written to `.git/vim-prompts/prompts/` (never committed) and
passed as `"$(cat <file>)"`, so you can read what was sent. A prompt longer
than `g:prompts_max_arg` characters (100000) isn't passed inline: the agent is
told to read the file.

## Another CLI

The built-in agents start as `claude [args] <prompt> [--add-dir dir...]` and
`copilot [args] -i <prompt> [--add-dir dir...]`. Add one, or change these,
with `g:prompts_agent_table`:

```vim
let g:prompts_agent_table = {'mycli': {'cmd': ['mycli', '--tui'], 'prompt': ['--prompt'], 'dir': '--allow'}}
```

`cmd` starts it, `prompt` goes before the prompt, `dir` before each
directory it may read outside the repository, and `modes` (optional) maps
`ask`, `plan`, `agent` and `auto` to the arguments that start it in that
[mode](#modes); a mode it doesn't have starts it as is. Then add `mycli` to
`g:prompts_agents`.
