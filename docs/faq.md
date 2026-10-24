# FAQ

## Why was my ask refused?

There was no context to send, and the message says what is missing: for
example `/review` with no `:G diff --name-only` buffer in the tab, or
`#comments` with no comments. `:Ai!` asks anyway. See
[when a persona can be asked](personas.md#frontmatter).

## How do I change what `/review` does?

Copy it to `~/.vim/personas/` and edit the copy: see
[which persona is used](personas.md#which-persona-is-used).

## How do I change what a source tells the agent?

Copy it to `~/.vim/autoload/prompts/sources/` and edit the copy: see
[changing a source](sources.md#changing-a-source).

## Does the agent get my files' contents?

No: it gets their paths, and the commands to read them (`git diff`,
`git show`, `gh`), and reads them itself. The prompt is saved in
`.git/vim-prompts/prompts/`, so you can see exactly what was sent.

## Where does the agent open, and how do I leave it?

In a tmux window, or a Vim terminal tab: see [the agent](agent.md#where-it-opens).

## Does it work with both Claude Code and Copilot CLI?

Yes, and one vimrc serves both: see
[which agent runs](agent.md#which-agent-runs).

## How do I ask about `#include` or `@decorator`?

Put your query after `--`: `:Ai /review -- why is #include here?`
