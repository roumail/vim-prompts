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

Requires Vim 9.1+, [vim-fugitive](https://github.com/tpope/vim-fugitive),
[vim-dispatch](https://github.com/tpope/vim-dispatch),
[git-extras](https://github.com/roumail/git-extras),
[vim-review](https://github.com/roumail/vim-review), and the agent CLI,
installed and logged in.

```vim
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-dispatch'
Plug 'roumail/git-extras'
Plug 'roumail/vim-review'
Plug 'roumail/vim-prompts'
```

## Use

**Explain code.** Select lines, then:

```vim
:'<,'>Ai /explain
:'<,'>Ai why is this loop reversed
```

**Review a change.** Your branch, committed or not, or only what's staged:

```vim
:Ai /review is the error handling consistent
:Ai /review #changes:staged
```

**Ask about your review comments.** Leave them with `:Comment` (vim-review),
then:

```vim
:Ai #comments I think the second one is wrong
:Ai /review #comments
```

**Bring in more.** Files with `@`, other context with `#`
([all of them](docs/sources/)):

```vim
:Ai @src/api.py @~/notes/design.md how do these fit together
:Ai #repo:tpope/vim-dispatch how does :Start pick a handler
```

**Edit the prompt first.** `:AiDraft` opens it in a buffer; `:w` sends it.

`:Ai` alone goes back to the agent. `<Tab>` completes everything. To leave a
Vim terminal agent, use `/exit` or Ctrl-D.

## How it reads

```
:Ai /persona #context @files your question
```

- Your **query** is what you type.
- A **persona** (`/explain`, `/review`, ...) is a saved prompt that brings the
  context it needs. Without one you get `/default`, which adds nothing.
- **Context** is what you add on top: `#sources` (a diff, your comments, a
  GitHub repo) and `@files`. A selection always goes too.
- Together they make one **prompt**, the first message of an agent session.
  Only that is sent; the rest of the conversation happens in the agent.

`:Ai` refuses when there's no context to send; `:Ai!` asks anyway.

## Per project

Each repository can brief the agent its own way, from `.vim-prompts/` at its
root:

- `repository.md`: what the project is, its layout and conventions, how to
  run the tests. It opens every ask made there.
- `personas/<name>.md`: a persona for this project only, or one that replaces
  a built-in (`personas/review.md` with your team's review checklist).

Commit it to share it, or list `.vim-prompts/` in `.git/info/exclude` to keep
it to yourself. Personas for every project go in `~/.vim/personas/`.

## More

- [Usage](docs/usage.md): the commands, drafts, mappings
- [Sources](docs/sources/): each `#source` and `@files` in detail, changing
  one, writing your own
- [Personas](docs/personas.md): the built-in ones, overriding them, writing
  your own, repository context, skills
- [The agent](docs/agent.md): which CLI runs, where it opens, adding another
- [FAQ](docs/faq.md)
