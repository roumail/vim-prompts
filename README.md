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
- **You decide how it's briefed, per project.** A persona (`/review`, or
  your own) is a saved prompt that frames your question;
  rules apply to every ask. Each project can describe itself once and bring
  its own personas and rules.

**Vim or Neovim:** Vim only, 9.1 and newer. It calls Vim-only functions
(`job_start()`, `term_getstatus()`), so it doesn't work on Neovim.

## Install

Requires Vim 9.1+ and the agent CLI, installed and logged in. The core is
vim-prompts and four plugins:

- [vim-fugitive](https://github.com/tpope/vim-fugitive): finds the
  repository and runs git.
- [vim-dispatch](https://github.com/tpope/vim-dispatch): starts the agent
  (`:Start`), in a Vim terminal or a tmux window.
- [vim-place](https://github.com/vimoured/vim-place): where settings are
  read from and prompts are kept, for each repository and work tree.
- [vim-lists](https://github.com/vimoured/vim-lists): the lists at the
  bottom, `:AiRules`, `:AiPersonas` and `:AiSources`.

```vim
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-dispatch'
Plug 'vimoured/vim-place'
Plug 'vimoured/vim-lists'
Plug 'vimoured/vim-prompts'
```

The core gives you:

- **Asking:** `:Ai`, `:Ai!` and `:AiPreview`.
- **Briefing:** the rules and personas, with `:AiRules`, `:AiRule`,
  `:AiPersonas`, `:AiUnset` and `/default`.
- **Sources:** `@path`, `#here`, `#commits`, `#quickfix`, `#repo`,
  `#stackoverflow` and `#url`, and rules for the task by name, `+testing`;
  `:AiSources` lists them all, what to work on apart from how (`+name`,
  `#agent_comments`).

Each row below adds a module on top of the core, and **Needs** is the whole
set of plugins it takes besides the core:

| Needs | Module | Adds |
| --- | --- | --- |
| [vim-draft](https://github.com/vimoured/vim-draft) | Drafts | `:AiDraft`, an ask written in a buffer |
| [fugitive-extras](https://github.com/vimoured/fugitive-extras) | Your branch and your review | `#changes`, diffed against your default branch, and with it `/review:pr`; `#diff_pairs`, which names `:BranchDiff`'s comparisons; `#comments`, your `:Comment`s |
| [vim-review](https://github.com/vimoured/vim-review) | The agent's comments | `#agent_comments`, read in vim-review's format: `:AiComments` steps through them, `:AiReply` and `:AiThread` go back and forth on one, `:AiCommentsList` lists the reviews here, to open or clear, and `:AiCommentsClear` clears them |
| vim-review + vim-draft | Replies in a draft | `:AiReplyDraft` |
| vim-review + fugitive-extras | The agent's comments as yours | `:AiCommentsLoad`, which puts the agent's comments in fugitive-extras' Review list, to change and post as your own |

All of it:

```vim
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-dispatch'
Plug 'vimoured/vim-place'
Plug 'vimoured/vim-lists'
Plug 'vimoured/vim-draft'
Plug 'vimoured/fugitive-extras'
Plug 'vimoured/vim-review'
Plug 'vimoured/vim-prompts'
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
that asks for you. Without one you get `/default`, which adds nothing to
your query but your rules.

**If you want it to look at your change** (with fugitive-extras), `/review:pr`
brings in the diffs you have open, else your branch, committed or not;
`#changes:staged` narrows it to what's staged, `#changes:unstaged` to what
isn't yet. `/review` reviews what you
give it, a selection or `@files`. A review is a one-off: the answer comes
into a buffer below while you keep working, and its comments on your lines
into `:AiComments`. `:Ai! /review` opens a session instead, to go on from:

```vim
:Ai /review:pr is the error handling consistent
:Ai /review:pr #changes:staged
:'<,'>Ai /review
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
context to send. `<Tab>` completes everything.

**If you only want an answer, not a session,** `:Ai!` asks once and puts
the answer in a scratch buffer below, while you keep working:
`:'<,'>Ai! what does this return on an empty list`. `:Ai!` alone goes back
to it ([usage](docs/usage.md#ai)). A persona can answer that way without
the `!` (`answer: oneoff`, as `/review` does), and then `!` opens a session.

**If the agent left comments on your lines** (with vim-review), reply on one to go back and
forth on it alone: `:AiReplyDraft` on it in the `:AiComments` list writes a
reply, the agent answers as a one-off into that comment's thread, and `=` shows the
thread ([replying](docs/sources/agent_comments.md#replying)).

**If your ask is longer than a command line** (with vim-draft), `:AiDraft` opens it in a
buffer to write: the same words `:Ai` takes on its first line, and your
query over as many lines as you like below it. `:w` saves it and `:wq` sends it ([usage](docs/usage.md#aidraft)).

**If you want to see what an ask would send,** `:AiPreview` takes the same
words as `:Ai` and shows the prompt, rules included, without sending it
([usage](docs/usage.md#aipreview)).

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

Nothing is picked up for being in some directory, and `:AiRules` lists
which rules apply and where each is set ([configuration](docs/config.md)). A
rules file hides an earlier one of its file name, so a group's `git.md`
replaces yours.
`:AiRule git.md <text>` adds to a rules file, and `:AiRule --local` starts
one for this repository, kept outside it ([usage](docs/usage.md#airule));
`:AiUnset` removes a setting.
Rules for one kind of task go in a `vim-prompts.task-rules` directory and are
sent when asked for, `:Ai +testing ...` (`<Tab>` lists them), a
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
  on them, variants (`/review:pr`), writing your own, skills
- [The agent](docs/agent.md): which CLI runs, where it opens, adding another
- [FAQ](docs/faq.md)

## Tests

The specs in [vim-suite](https://github.com/vimoured/vim-suite) define what it
does: `test/vim-prompts.vim`, `test/vim-prompts-outside-a-repository.vim` and
`test/vim-prompts-copilot.vim`.
