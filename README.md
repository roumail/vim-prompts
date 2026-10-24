# vim-prompts

An AI agent ([Claude Code](https://claude.com/claude-code) or
[Copilot CLI](https://github.com/github/copilot-cli)) can't see your editor.
vim-prompts lets you ask it from Vim and choose exactly what it sees: the
lines you selected, the change you're reviewing, your review comments, other
files. Nothing else is sent.

```vim
:'<,'>Ai /explain
```

The agent opens with your question and that context, and you carry on the
conversation there.

## Install

Requires Vim 9.1+, [vim-fugitive](https://github.com/tpope/vim-fugitive),
[vim-dispatch](https://github.com/tpope/vim-dispatch),
[git-extras](https://github.com/roumail/git-extras), and the agent CLI,
installed and logged in.

```vim
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-dispatch'
Plug 'roumail/git-extras'
Plug 'roumail/vim-prompts'
```

Optional, to pick files with a bare `@` (here with
[fzf-utils](https://github.com/roumail/fzf-utils)):

```vim
let g:prompts_file_picker = 'fzf_utils#fd#files#pick'
```

## Use

**Explain code.** Select lines, then:

```vim
:'<,'>Ai /explain
:'<,'>Ai why is this loop reversed
```

**Review a change.** List the changed files with fugitive, then ask:

```vim
:G diff --cached --name-only
:Ai /review is the error handling consistent
```

**Talk about your review comments.** Leave them with `:Comment` (git-extras),
then:

```vim
:Ai /comments I think the second one is wrong
:Ai /fix-comments
```

**Bring in more.** Files with `@`, other context with `#`:

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

## More

- [docs/usage.md](docs/usage.md): every command, context source and persona
- [docs/configuration.md](docs/configuration.md): mappings, the file picker,
  which agent runs and where it opens
- [docs/personas.md](docs/personas.md): writing your own personas, overriding
  the built-in ones, repository context, new `#sources`
- [docs/faq.md](docs/faq.md)
