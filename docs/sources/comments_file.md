# #comments_file

Has the agent write its comments on lines to a file too, which
`:AiComments` opens as a quickfix list, so you step through them in Vim on
their lines (`:cnext`, `:cprev`). It is [`#comments`](comments.md) the other
way: that one sends your comments to the agent, this one brings the agent's
back.

```vim
:Ai /review #comments_file
```

The file is new for each ask, in the repository's git dir (each worktree's
own), next to the prompts: `<git dir>/vim-prompts/comments/<time>.txt`. The
agent is told the path and the format, which is
[vim-review](https://github.com/roumail/vim-review)'s save format:

```
src/app.py:12: 1. [blocking] could you check the None case here?
src/app.py:20-24: 2. [question] is this loop needed?
	It seems to repeat line 8.
```

`path:line: text` or `path:start-end: text`, paths from the work tree's
root, further lines of a comment tab-indented. Number and kind come first
when the persona's answer has them (as `/review`'s does), so the list
matches the answer.

## :AiComments

`:AiComments` loads the newest file into a **new** quickfix list titled
`Agent comments: <file>`; `:AiComments <Tab>` lists the files, newest
first, or takes a path. Lines that aren't in the format are left out, and
counted.

Your own comments stay where they are: vim-review's `Review` list is a
list of its own, and `:colder` goes back to it. To make one of the agent's
comments yours, `:Comment` on its line.

A persona can take it, so its answers always come with the file:

```markdown
---
context: [changes, comments_file]
---
```

Outside a repository there is nowhere to put the file, and the ask is
refused (`:Ai!` asks anyway, without it).
