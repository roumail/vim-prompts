# Usage

## :Ai

```
:[range]Ai[!] [/persona] [#source...] [@file...] [--<mode>-mode] [--bare] [query] [-- text]
```

Asks the [persona](personas.md) (`/default` without one) with its context,
the [sources and files](sources/) you add, and a range or visual selection.

- **No context to send:** refused, saying what is missing. `:Ai!` asks anyway.
- **Nothing at all** (`:Ai`): opens the agent, or goes back to the session
  `:Ai` opened before.
- **`--ask-mode`, `--plan-mode`, `--agent-mode` or `--auto-mode`**
  (anywhere before `--`): the [mode](agent.md#modes) the agent starts in, over the persona's
  and `g:prompts_mode`. `:Ai --plan-mode` alone opens it bare that way.
- **`--bare`** (anywhere before `--`): leaves the [rules](personas.md#rules)
  and the repository's description out, so only the persona, what you name
  (`#rule:` included) and your query go. `:Ai --bare question` sends the question alone.
- **Context but no query** (`:Ai @`, `:'<,'>Ai #comments`): sends the context
  and the agent waits for your question, which you type in the session.

## Typing the query

`<Tab>` completes `/personas` (first word), `#sources`, `@files` and the
modes and `--bare`.

Before `--`, an unknown `#word` or a missing `@file` is an error, so a typo
isn't sent as text. After `--`, everything is your query as typed, so
`#include`, `@decorator` or `--flags` need nothing special:

```vim
:Ai /review -- why is #include here?
```

## :AiDraft

`:[range]AiDraft[!] ...` takes the same arguments but opens the prompt in a
buffer to edit first. It works as a git commit message:

| | |
| --- | --- |
| `:w` | Save it; nothing is sent. |
| `:wq` (or `:q` after `:w`) | Close the draft and send what was last saved; the agent opens. |
| `:q!` before any `:w` | Drop it. To drop a saved draft, empty it and `:wq`. |

Closing the draft never quits Vim, even when it is the last window (after
`:only`), so the prompt is still sent. The draft is
[vim-draft](https://github.com/roumail/vim-draft)'s.

The [rules](config.md) are folded: they are the same in every draft, and are
sent all the same. `zo` shows them.

## :AiComments

`:AiComments [file]` opens the agent's comments on lines, written for an ask
with [`#comments_file`](sources/comments_file.md), as a new quickfix list:
the newest file without an argument, `<Tab>` for the others. Step through
them with `:cnext`; `:colder` goes back to the list before (your `Review`
comments, say).

## :AiCommentsLoad

`:AiCommentsLoad [file]` loads the same comments into vim-review's `Review`
list, to make them yours, as `:CommentsLoad` does with a save: they replace
what the list holds (`:CommentsSave` first to keep those). The same files
as `:AiComments`, the newest without an argument.

## :AiPersonas

`:AiPersonas[!]` shows the personas where you are: for each, whether it is
loaded or hidden by a later one of its name, where it comes from (bundled
with vim-prompts, or the `vim-prompts.personas` setting and the
[scope](config.md#scopes) and file that set it), the context it asks for
(its `#rule:`s included), those it builds on, and what it needs that isn't
there. `!` reloads the source files first. The rules and the repository's
description are `:AiRules`.

## :AiRules

`:AiRules` shows the rules files where you are, in the order they are
sent, the repository's description, then the rules you ask for by name,
`#rule:<name>` ([rules for a task](config.md#rules-for-a-task)). For each,
whether it is loaded or hidden, and where it comes from: the setting, its
[scope](config.md#scopes) and the file that sets it. A rules file hides an
earlier one of its file name, so a group's `git.md` replaces yours.

```
comments.md
  ~/dotfiles/prompts/comments.md
  loaded
  from vim-prompts.rules, global ~/.gitconfig
git.md
  ~/work/handbook/git.md
  loaded
  from vim-prompts.rules, global ~/work/.gitconfig
repository
  .vim-prompts/repository.md
  loaded
  from vim-prompts.repository, local ~/work/app/.git/config
git.md
  ~/dotfiles/prompts/git.md
  hidden by ~/work/handbook/git.md
  from vim-prompts.rules, global ~/.gitconfig
#rule:testing
  .vim-prompts/library/testing.md
  loaded
  from vim-prompts.library, local ~/work/app/.git/config
#rule:testing
  ~/work/handbook/library/testing.md
  hidden by .vim-prompts/library/testing.md
  from vim-prompts.library, global ~/work/.gitconfig
```

## :AiRule

`:[range]AiRule {file} [text]` opens a rules file that applies here (the ones
`:AiRules` lists, by file name; `<Tab>` completes them) in a split, with
the text and the selected lines appended for you to finish; `:w` saves it,
and the next ask reads it.

`--global`, `--local` or `--worktree` in place of the file picks a
[scope](config.md#scopes): yours everywhere, this repository, or this
worktree's branch. It opens the last rules file that scope names, or, with
none, asks for a new one and names it there (`git config --<scope> --add
vim-prompts.rules <file>`). A file that a later one hides still counts, so
`--global` opens yours even where the group's `git.md` replaces it:

| Flag | Opens | A new one, by default |
| --- | --- | --- |
| `--global` | the last rules file in `~/.gitconfig` (not a file it includes, so never a group's) | `~/.config/vim-prompts/rules.md`, named in `~/.gitconfig` |
| `--local` | the last one in this repository's `.git/config` | `~/.config/vim-prompts/repos/<repository>.md` |
| `--worktree` | the last one in this worktree's config | `~/.config/vim-prompts/repos/<repository>-<worktree>.md` |

A new one goes outside the repository, so a shared repository never sees
it; the path is yours to change before it is created. `--worktree` needs
`extensions.worktreeConfig` turned on in the repository
([scopes](config.md#scopes)).

```vim
:AiRule git.md never rebase a pushed branch
:'<,'>AiRule --local
```

## :AiUnset

`:AiUnset {key} [value]` removes a value from the git config file that sets
it, wherever that is: `~/.gitconfig`, a file it includes, the repository's
or the worktree's. `<Tab>` completes the keys set here, then their values;
a rules file can be named by its file name, and `""` is the empty value.
Without a value it removes the key's only one; of a value set in several
files, the last ([removing a setting](config.md#removing-a-setting)).

```vim
:AiUnset dir
:AiUnset rules testing.md
```

## Mappings

No keys are bound. The `<Plug>` mappings type the command for you to finish
(`:'<,'>Ai ` from visual mode):

```vim
nmap <leader>aa <Plug>(prompts-ask)
xmap <leader>aa <Plug>(prompts-ask)
nmap <leader>ad <Plug>(prompts-draft)
xmap <leader>ad <Plug>(prompts-draft)
nmap <leader>ar <Plug>(prompts-rule)
xmap <leader>ar <Plug>(prompts-rule)
```

## Command prefix

```vim
let g:prompts_namespace = 'Ai'      " :Ai, :AiDraft, :AiComments, :AiCommentsLoad, :AiPersonas, :AiRules, :AiRule, :AiUnset
```
