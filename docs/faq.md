# FAQ

## Why was my ask refused?

There was nothing to work on, or a rule missing, and the message says
what: for example `/review` with nothing selected, `/review:pr` on a
branch with no changes, a persona's `rule:test-setup` on a machine without
it, or `#comments` with no comments. `--force` sends a persona with nothing
to work on. See
[when a persona can be asked](personas.md#frontmatter).

## How do I change what `/review` does?

Copy it to one of your `vim-prompts.personas` directories and edit the copy,
or build on it with `{base}`: see
[which persona is used](personas.md#which-persona-is-used).

## How do I share rules between repositories but let one differ?

The shared ones in a group's git config, the repository's in its own, which
wins: see [configuration](config.md#a-group-of-repositories). To replace one
of the shared files rather than add to it, give yours the same file name;
`:AiRules` shows which applies.

## How do I send rules only for some asks?

Put them in a `vim-prompts.task-rules` directory and ask for them by name, `#rule:testing`, or have
the persona for the task take them: see
[rules for a task](config.md#rules-for-a-task).

## Can a script or an agent check the setup without Vim open?

Git config is the setup, so the shell sees all of it: what is set and in
which file, then whether each path is there.

```sh
git config --show-scope --show-origin --get-regexp '^vim-prompts\.'
git config --get-all vim-prompts.task-rules | while read -r d; do d=${d/#\~/$HOME}; test -d "$d" || echo "missing: $d"; done
```

## How do I remove something I set?

`:AiUnset`, with `<Tab>`: see [removing a setting](config.md#removing-a-setting).

## How do I change what a source tells the agent?

Copy it to `~/.vim/autoload/prompts/sources/` and edit the copy: see
[changing a source](sources/writing.md#changing-a-source).

## Does the agent get my files' contents?

No: it gets their paths, and the commands to read them (`git diff`,
`git show`, `gh`), and reads them itself. The prompt is saved in
`.git/vim-prompts/prompts/`, so you can see exactly what was sent; the
newest 50 are kept ([the prompt it gets](agent.md#the-prompt-it-gets)).

## Where does the agent open, and how do I leave it?

In a tmux window, or a Vim terminal tab: see [the agent](agent.md#where-it-opens).

## Does it work with both Claude Code and Copilot CLI?

Yes, and one vimrc serves both: see
[which agent runs](agent.md#which-agent-runs).

## How do I ask about `#include` or `@decorator`?

Put your query after `--`: `:Ai /review -- why is #include here?`
