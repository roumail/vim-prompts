# vim-prompts

Use your coding agent ([Claude Code](https://claude.com/claude-code) or
[Copilot CLI](https://github.com/github/copilot-cli)) from inside Vim.

```vim
:'<,'>Ai why is this loop reversed
```

opens the agent already holding your question and the lines you selected,
and you carry on the conversation there.

- **The agent runs next to your code.** In a Vim terminal tab, or a tmux
  window under tmux; `:Ai` alone takes you back to it.
- **You say what it sees.** A short syntax hands it what Vim knows: a
  selection, `@files`, the change on your branch (`#changes`), your review
  comments (`#comments`). Nothing else is sent.
- **You decide how it's briefed, per project.** A persona (`/review`,
  `/explain`, or your own) is a saved prompt that frames your question. Each
  project can describe itself once and bring its own personas.

## Install

Requires Vim 9.1+, the agent CLI (installed and logged in), and:

- [vim-fugitive](https://github.com/tpope/vim-fugitive): finds the
  repository and runs git.
- [vim-dispatch](https://github.com/tpope/vim-dispatch): starts the agent
  (`:Start`), in a Vim terminal or a tmux window.
- [git-extras](https://github.com/roumail/git-extras): knows your default
  branch, which `#changes` diffs against, and the `:BranchDiff` comparisons
  `#diff_pairs` names.
- [vim-review](https://github.com/roumail/vim-review): the review comments
  (`:Comment`) that `#comments` sends.

```vim
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-dispatch'
Plug 'roumail/git-extras'
Plug 'roumail/vim-review'
Plug 'roumail/vim-prompts'
```

## Use

Each step adds one thing to the one before it; stop at whichever is enough.

**If all you want is to ask about some code,** select it and ask:

```vim
:'<,'>Ai why is this loop reversed
```

The agent opens with your question and the lines. Carry on the conversation
there; `:Ai` alone brings you back to it, and `/exit` or Ctrl-D leaves it.
Only this first prompt is sent from Vim.

**If you don't want to write a question,** use a persona, a saved prompt
that asks for you. `/explain` asks what the code does, why it's written that
way and what's surprising, and sends the whole file around your lines:

```vim
:'<,'>Ai /explain
```

Without a selection it explains the code at your cursor. Without a persona
you get `/default`, which adds nothing to your query.

**If you want it to look at your change,** `/review` brings in your branch,
committed or not; `#changes:staged` narrows it to what's staged:

```vim
:Ai /review is the error handling consistent
:Ai /review #changes:staged
```

**If it needs more than that,** add files with `@` and other context with `#`
([all of them](docs/sources/)):

```vim
:Ai @src/api.py @~/notes/design.md how do these fit together
:Ai #repo:tpope/vim-dispatch how does :Start pick a handler
```

Put together, an ask reads:

```
:Ai /persona #context @files your question
```

A selection, if you made one, always goes. `:Ai` refuses when there's no
context to send; `:Ai!` asks anyway. `<Tab>` completes everything.

**If you want to edit the prompt before it goes,** `:AiDraft` opens it in a
buffer; `:w` sends it ([usage](docs/usage.md)).

**If you want every ask in a project briefed the same way,** add
`.vim-prompts/` at the repository root:

- `repository.md`: what the project is, its layout and conventions, how to
  run the tests. It opens every ask made there.
- `personas/<name>.md`: a persona for this project only, or one that replaces
  a built-in (`personas/review.md` with your team's review checklist).

Commit it to share it, or list `.vim-prompts/` in `.git/info/exclude` to keep
it to yourself. Personas for every project go in `~/.vim/personas/`
([personas](docs/personas.md)).

## More

- [Usage](docs/usage.md): the commands, drafts, mappings
- [Sources](docs/sources/): each `#source` and `@files` in detail, changing
  one, writing your own
- [Personas](docs/personas.md): the built-in ones, overriding them, writing
  your own, repository context, skills
- [The agent](docs/agent.md): which CLI runs, where it opens, adding another
- [FAQ](docs/faq.md)
