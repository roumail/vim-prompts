# FAQ

## Where does the agent open?

In the repository root, through vim-dispatch's `:Start`, so wherever your
`:Start` strategy puts it: a tmux window, or a Vim terminal in a new tab (see
`g:prompts_start_mods` in [configuration](configuration.md#the-agent)).

## How do I get out of the agent in a Vim terminal?

Your keys go to the agent. Leave it with `/exit` (Claude) or Ctrl-D, which
closes the tab. Or press `Ctrl-\ Ctrl-n` for normal mode, then `gt` to another
tab, `:q` to hide it, or `:bwipe!` to end it. `:Ai` alone goes back to it.

## Why was my ask refused?

There was no context to send, and the message says what is missing: for
example `/review` with no `:G diff --name-only` buffer in the tab, or
`/comments` with no comments. `:Ai!` asks anyway.

## Does it work with both Claude Code and Copilot CLI?

Yes. With no `g:prompts_agent`, each machine uses the first CLI in
`g:prompts_agents` it has, so one vimrc serves a machine with Claude Code and
one with Copilot CLI. The plugin only starts the CLI: logging in, the model
and its settings are set up in the CLI itself.

## What exactly is sent?

The persona's template, rendered with your query, its context, what you
added, and the repository context. Each prompt is written to
`.git/vim-prompts/prompts/` and passed as `"$(cat <file>)"`. A prompt longer
than `g:prompts_max_arg` is not passed inline: the agent is told to read the
file.

## How do I ask about `#include` or `@decorator`?

Put your query after `--`: `:Ai /review -- why is #include here?`
