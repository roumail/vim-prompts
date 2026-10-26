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
  and your query go. `:Ai --bare question` sends the question alone.
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
buffer to edit first:

| | |
| --- | --- |
| `:w` | Send it and keep the draft open (edit and `:w` again for another session). |
| `:wq` | Send it and close the draft. |
| `:q!` | Drop it. |

The [rules](config.md) are folded: they are the same in every draft, and are
sent all the same. `zo` shows them.

## :AiPersonas

`:AiPersonas[!]` shows what applies where you are, and where git config sets
each part ([configuration](config.md)): the rules (as `:AiRules`), the repository's
description, then the personas, their context, where each comes from, those
it builds on, and what each needs that isn't there. `!` reloads the source
files first.

## :AiRules

`:AiRules` shows the rules files that apply where you are, in the order
they are sent, and where each is set: the [scope](config.md#scopes) and
the file that names it. A rules file hides an earlier one of its file name,
so a group's `git.md` replaces yours; the hidden ones are listed after them,
with what hides them. Last come the rules you ask for by name, `#rule:<name>`
([rules for a task](config.md#rules-for-a-task)), and what each hides.

```
comments.md     ~/dotfiles/prompts/comments.md        global ~/.gitconfig
git.md          ~/work/handbook/git.md                global ~/work/.gitconfig
repository      .vim-prompts/repository.md            local ~/work/app/.git/config
git.md          ~/dotfiles/prompts/git.md             global ~/.gitconfig
                hidden by ~/work/handbook/git.md
#rule:testing   .vim-prompts/library/testing.md       local ~/work/app/.git/config
                hides ~/work/handbook/library/testing.md
```

`:AiPersonas` starts with the same list.

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
let g:prompts_namespace = 'Ai'      " :Ai, :AiDraft, :AiPersonas, :AiRules, :AiRule, :AiUnset
```
