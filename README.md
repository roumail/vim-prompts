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
  comments (`#comments`). Nothing else is sent, but the rules you set.
- **You decide how it's briefed, per project.** A persona (`/review`,
  `/explain`, or your own) is a saved prompt that frames your question;
  rules apply to every ask. Each project can describe itself once and bring
  its own personas and rules.

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
you get `/default`, which adds nothing to your query but your rules.

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

**If you want every ask briefed the same way,** name the files that brief it
in git config, so they layer the way git config does: yours, a group of
repositories' (with `includeIf`), then one repository's, which wins:

```ini
[vim-prompts]
	rules = ~/work/handbook/testing.md         # every ask follows these
	personas = ~/work/handbook/personas        # /tests, your team's /review
```

```sh
# in one repository: what it is, how its tests differ
git config vim-prompts.repository .vim-prompts/repository.md
```

Nothing is picked up for being in some directory, and `:AiRules` shows
which rules apply and where each is set ([configuration](docs/config.md)). A
rules file hides an earlier one of its file name, so a group's `git.md`
replaces yours.
`:AiRule git.md <text>` adds to a rules file, and `:AiRule --local` starts
one for this repository, kept outside it ([usage](docs/usage.md#airule));
`:AiUnset` removes a setting.
Rules for one kind of task go in a `vim-prompts.library` directory and are
sent when asked for, `:Ai #rule:testing ...` (`<Tab>` lists them), a
repository's `testing.md` replacing the group's
([rules for a task](docs/config.md#rules-for-a-task)).
`--bare` leaves the rules and the description out of one ask:
`:Ai --bare is this idiomatic` sends just the question.
A persona of a repository can build on its group's with `{base}`
([personas](docs/personas.md)).

## More

- [Usage](docs/usage.md): the commands, drafts, mappings
- [Sources](docs/sources/): each `#source` and `@files` in detail, changing
  one, writing your own
- [Configuration](docs/config.md): rules, personas and the repository's
  description, for you, a group of repositories and one repository
- [Personas](docs/personas.md): the built-in ones, overriding them, building
  on them, writing your own, skills
- [The agent](docs/agent.md): which CLI runs, where it opens, adding another
- [FAQ](docs/faq.md)
