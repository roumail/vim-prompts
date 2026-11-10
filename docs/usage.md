# Usage

## :Ai

```
:[range]Ai[!] [/persona[:variant]] [#source...] [@file...] [--<mode>-mode] [--bare] [--force] [query] [-- text]
```

Asks the [persona](personas.md) (`/default` without one) with its context,
the [sources and files](sources/) you add, and a range or visual selection.

- **Nothing to work on, or a rule missing:** refused, saying what is
  missing ([when](personas.md#frontmatter)).
- **`/persona:variant`**: a persona's [variant](personas.md#variants),
  `/review:pr`.
- **Nothing at all** (`:Ai`): opens the agent, or goes back to the session
  `:Ai` opened before.
- **`!`, a one-off** (`:'<,'>Ai! what does this do`): instead of a session,
  the agent answers once, without asking you anything, into a scratch buffer
  below (`claude -p`, `copilot -p`). The answer comes in while you keep
  working, and the statusline says when it's done. It needs a question or a
  persona with a task, since there is no session to ask in afterwards.
  `:Ai!` alone goes back to the last answer. Anything the agent would ask
  you about it doesn't do, so a one-off starts in `auto` mode
  (`g:prompts_oneoff_mode`), unless the persona or the ask names another. A persona with
  [`answer: oneoff`](personas.md#frontmatter), `/review` among them, is a
  one-off without the `!`, and with it opens a session: `:Ai! /review:pr`.
  A one-off's [`#agent_comments`](sources/agent_comments.md) come in its
  answer, and are saved for `:AiComments` once it is in.
- **`--ask-mode`, `--plan-mode`, `--agent-mode` or `--auto-mode`**
  (anywhere before `--`): the [mode](agent.md#modes) the agent starts in, over the persona's
  and `g:prompts_mode` (`g:prompts_oneoff_mode` for a one-off). `:Ai --plan-mode` alone opens it bare that way.
- **`--bare`** (anywhere before `--`): leaves the [rules](personas.md#rules)
  and the repository's description out, so only the persona, what you name
  (`+name` included) and your query go. `:Ai --bare question` sends the question alone.
- **`--force`** (anywhere before `--`): sends a persona with nothing to work
  on, which is refused otherwise: `:Ai /review --force look around
  src/retry.py`. A missing rule is still refused.
- **Context but no query** (`:Ai @`, `:'<,'>Ai #comments`): sends the context
  and the agent waits for your question, which you type in the session.

## Typing the query

`<Tab>` completes `/personas` (first word), `#sources`, `@files` and the
modes and `--bare`.

Before `--`, an unknown `#word` or a missing `@file` is an error, so a typo
isn't sent as text. After `--`, everything is your query as typed, so
`#include`, `@decorator` or `--flags` need nothing special:

```vim
:'<,'>Ai /review -- why is #include here?
```

## :AiDraft

`:[range]AiDraft[!] ...` opens a buffer holding the ask, for when it is
longer than a command line; `!` goes the other way from the persona, as with `:Ai!`.
It asks from where you are when you close it, as `:Ai` would there: open it
from a listing, open a file in that window, and the file is what `#here`
sends. A selection you opened it with is kept.
Its first line is what you would type after `:Ai`, read when you send it as
`:Ai` reads its arguments when you press Enter: a persona first, then `#sources`, `@files` and flags anywhere, and
the rest is your query. After `--`, as with `:Ai`, everything is taken as
written. The lines below it are your query too, taken as written with
their indentation kept, so a pasted `@decorator`, `# comment` or `--flag`
is only text.

```
/review +testing #changes
Is the retry safe here? This part:

    for attempt in range(3):
        send()
```

Pasting a whole document under the first line, a handoff for one, needs
nothing special:

```
/review:pr
Is the retry safe here?

@celery.task(bind=True)
def archive(): ...
```

It works as a git commit message:

| | |
| --- | --- |
| `:w` | Save it; nothing is sent. |
| `:wq` (or `:q` after `:w`) | Close the draft and send what was last saved; the agent opens. |
| `:q!` before any `:w` | Drop it. To drop a saved draft, empty it and `:wq`. |

Closing the draft never quits Vim, even when it is the last window (after
`:only`), so the prompt is still sent. The draft is
[vim-draft](https://github.com/roumail/vim-draft)'s.

The range, the selection and the cursor line are taken when the draft
opens, so you can move around before sending it. When the ask can't be sent
(a source that doesn't exist, a persona's context missing), the draft opens
again with your text and the error.

In the draft, `prompts#tokens()` lists every word it can take, but files:
the personas, the sources with their arguments (`+testing`,
`#diff_pairs:<name>`) and the flags, as `<Tab>` completes them after `:Ai`. Hand
it to an insert-mode picker. For fzf.vim's, `prompts#fzf()` has them ready to
pick several with `<Tab>`, inserted with a space between:

```vim
inoremap <expr> <C-x><C-a> fzf#vim#complete(prompts#fzf())
```

The word before the cursor completes there as it does after `:Ai`: `#ch` to
`#changes` and `#changes:`, `+` to the rules, `@src/` to files, `--p` to `--plan-mode`,
one match inserted at once. A word that completes to nothing, or none, gives
every word, filtered by what you typed. `#commits:` is left to
`prompts#sources#commits#fzf()`, its own picker.

## :AiPreview

`:[range]AiPreview[!] ...` takes what `:Ai` takes and shows, in a buffer on
the right, the prompt `:Ai` would send: the rules and the repository's
description, the persona, its context and your query, as the agent would
read them. Nothing is sent from it. Its statusline has the persona and the
command line the agent would run, `<prompt>` standing for the prompt; with
`!`, the one-off's. It goes the same way `:Ai` does up to sending, so an ask
`:Ai` would refuse is refused here too, saying why. `:AiRules` says which
rules files apply; this shows what they add up to for one ask.

The buffer can't be changed, and the next `:AiPreview` refills it while it
is shown.

## :AiComments

`:AiComments[!] [file]` opens the agent's comments on lines, written for an ask
with [`#agent_comments`](sources/agent_comments.md), as a new quickfix list:
the newest file without an argument, `<Tab>` for the others. Those you `dd`
from the list are done and left out next time; `!` shows them too.
`:AiCommentsList` shows the reviews kept here, `:AiCommentsClear` deletes
one with its threads ([keeping them](sources/agent_comments.md#keeping-them)). Step through
them with `:cnext`; `:colder` goes back to the list before (your `Review`
comments, say). In its window, `:AiReply` replies on the comment under the
cursor and `=` shows its thread ([replying](sources/agent_comments.md#replying)).

## :AiReply

`:AiReply[!] [text]` replies on one of the agent's comments: the one under
the cursor in the `:AiComments` list or in a thread, else the list's
current one (where `:cnext` took you). It prompts unless `text` is given,
and takes what `:Ai` takes (`/persona`, `#source`, `@file`, flags). The
agent answers as a one-off into the comment's thread; with `!`, in a
session instead. Leaving the prompt with `<Esc>` keeps what you typed:
`:AiReply` or `:AiReplyDraft` on the same comment goes on from it.

## :AiReplyDraft

`:AiReplyDraft[!] [text]` writes the
reply in a draft above, starting with `text` if given, else with what you
left at the `:AiReply` prompt. Its first line is read as `:Ai` reads its
arguments, the rest taken as written, as in `:AiDraft`. `:w` saves it,
closing it sends it, `:q!` before any `:w` drops it.

## :AiThread

`:AiThread` (`=` in the list) shows the comment's thread: the comment, then
each reply and answer, kept in a file next to the comments'. The buffer is
read-only, as the file is the thread: replies go in with `:AiReply` or
`:AiReplyDraft`.

## :AiCommentsLoad

`:AiCommentsLoad [file]` loads the same comments into fugitive-extras' `Review`
list, to make them yours, as `:CommentsLoad` does with a save: they replace
what the list holds (`:CommentsSave` first to keep those). The same files
as `:AiComments`, the newest without an argument.

## :AiPersonas

`:AiPersonas[!]` lists the personas where you are, a line each: where its
file is, where it comes from (`bundled` with vim-prompts, or the
[scope](config.md#scopes) and file that set `vim-prompts.personas`), the
context it asks for (its `+name` rules included), those it builds on, and what
it needs that isn't there from where you opened the list. One hidden by a
later persona of its name is dimmed under it. `!` reloads the source files
first. The rules and the repository's description are `:AiRules`.

```
Personas (5)  <CR> open  / filter  r refresh  q close
  /default    ~/.vim/plugged/vim-prompts/personas/default.md    bundled
  /review     ~/.vim/plugged/vim-prompts/personas/review.md     bundled  #agent_comments  /review needs something to work on: …
  /review:pr  ~/.vim/plugged/vim-prompts/personas/review/pr.md  bundled  #agent_comments [#diff_pairs #changes]  on {base} ~/.vim/plugged/vim-prompts/personas/review.md
  /tests      ~/work/handbook/personas/tests.md                 global ~/work/.gitconfig  #here +testing  /tests needs a file to ask from, not a listing or a scratch buffer
  /tests      ~/dotfiles/prompts/personas/tests.md              global ~/.gitconfig  hidden by ~/work/handbook/personas/tests.md
```

## :AiSources

`:AiSources` lists the [sources](sources/), a line each, in two groups:
what to work on (`#here`, `#changes`, `@path`, …) and how to work on it,
the instructions (`+name`, `#agent_comments`), which don't count as
something to work on. For each: how it is written (`#changes[:arg]` takes an
argument or not, `#url:arg` needs one), its file, and whether it has
something from where you opened the list, or what it needs. A source that
needs an argument says what it takes; `+name` lists the rules there are,
which `:AiRules` shows with their files. A copy of a source earlier on
`'runtimepath'` ([changing a source](sources/writing.md#changing-a-source))
hides the bundled one, which is dimmed under it. `r` loads the source files
again, so a new one shows.

```
Sources (12)  <CR> open  / filter  r refresh  q close
what to work on
  #changes[:arg]     ~/.vim/plugged/vim-prompts/autoload/prompts/sources/changes.vim   has something here
  #quickfix          ~/.vim/plugged/vim-prompts/autoload/prompts/sources/quickfix.vim  nothing here: needs a quickfix list (:Grep, :vimgrep, :make)
  #url:arg           ~/.vim/plugged/vim-prompts/autoload/prompts/sources/url.vim       a link: #url:https://...
  …
how to work on it
  #agent_comments    ~/.vim/plugged/vim-prompts/autoload/prompts/sources/agent_comments.vim  a directory to write the file in
  +name              ~/.vim/plugged/vim-prompts/autoload/prompts/sources/rule.vim      +testing +style  (:AiRules)
```

## :AiRules

`:AiRules` lists the rules files where you are, in the order they are
sent, the repository's description, then the rules you ask for by name,
`+<name>` ([rules for a task](config.md#rules-for-a-task)): for each,
its file and where it comes from, the [scope](config.md#scopes) and the
file that sets it. A rules file hides an earlier one of its file name, so a
group's `git.md` replaces yours: the hidden one is dimmed under it. A
setting that is wrong (a file that isn't there, an unknown key) is under
the title.

```
Rules (6)  <CR> open  / filter  r refresh  q close
rules
  comments.md    ~/dotfiles/prompts/comments.md         global ~/.gitconfig
  git.md         ~/work/handbook/git.md                 global ~/work/.gitconfig
  git.md         ~/dotfiles/prompts/git.md              global ~/.gitconfig  hidden by ~/work/handbook/git.md
repository
  repository     .vim-prompts/repository.md             local ~/work/app/.git/config
task rules, sent when asked for
  +testing       .vim-prompts/task-rules/testing.md     local ~/work/app/.git/config
  +testing       ~/work/handbook/task-rules/testing.md  global ~/work/.gitconfig  hidden by .vim-prompts/task-rules/testing.md
```

Both are [vim-lists](https://github.com/roumail/vim-lists) lists: `<CR>`
opens the file under the cursor in the window you came from, `/` filters on
the name and the file, `r` reads the settings again, and `q` closes.

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
:AiUnset task-rules
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

`<Plug>(prompts-reply)` leaves `:AiReply ` on the command line to finish,
and `<Plug>(prompts-reply-draft)` is `:AiReplyDraft`, to bind the keys
fugitive-extras' `:Comment` has. `<Plug>(prompts-reply-session)` and
`<Plug>(prompts-reply-draft-session)` are the same with `!`, to a session:

```vim
nmap <leader>cr <Plug>(prompts-reply)
```

## Command prefix

```vim
let g:prompts_namespace = 'Ai'      " :Ai, :AiDraft, :AiPreview, :AiComments, :AiCommentsLoad, :AiCommentsList, :AiCommentsClear, :AiReply, :AiReplyDraft, :AiThread, :AiPersonas, :AiRules, :AiRule, :AiSources, :AiUnset
```
