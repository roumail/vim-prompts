# #agent_comments

Has the agent write its comments on lines to a file too, which
`:AiComments` opens as a quickfix list, so you step through them in Vim on
their lines (`:cnext`, `:cprev`). It is [`#comments`](comments.md) the other
way: that one sends your comments to the agent, this one brings the agent's
back.

```vim
:Ai /review #agent_comments
```

The file is new for each ask, in the repository's git dir (each worktree's
own), next to the prompts: `<git dir>/vim-prompts/comments/<time>.txt`.
Outside a repository it goes where
[vim-place](https://github.com/roumail/vim-place) keeps the current
directory's files (`g:roumail_place_dir`, else the XDG state directory),
and the agent is let write there (`--add-dir`); `:AiComments` finds it from
that directory. The
agent is told the path and the format, which is
[vim-review](https://github.com/roumail/vim-review)'s format, the one
fugitive-extras saves your comments in:

```
src/app.py:12: 1. [blocking] could you check the None case here?
src/app.py:20-24: 2. [question] is this loop needed?
	It seems to repeat line 8.
```

`path:line: text` or `path:start-end: text`, paths from the work tree's
root (outside a repository, from the current directory), further lines of a comment tab-indented. Number and kind come first
when the persona's answer has them (as `/review`'s does), so the list
matches the answer.

## :AiComments

`:AiComments` loads the newest file into a **new** quickfix list titled
`Agent comments: <file>`; `:AiComments <Tab>` lists the files, newest
first, or takes a path. Lines that aren't in the format are left out, and
counted.

A comment you are done with, `dd` it from the list
([qf-tools](https://github.com/roumail/qf-tools)' `dd`, `3dd` or visual
`d`): it stays done, recorded beside its thread in
`<git dir>/vim-prompts/comments/<time>/done`, and the next `:AiComments`
leaves it out. `u` in the list puts it back, not done. `:AiComments!` shows
the done ones too; what you `dd` or `u` there changes only those.

## Keeping them

Reviews are kept until you clear them, in the git dir of the work tree
they were asked in, so removing a work tree removes its reviews.

| Command | What it does |
| --- | --- |
| `:AiCommentsList` | The reviews here, newest first: when, how many comments, done and threads, and the files they are on. `<CR>` opens one as `:AiComments`, `dd` clears it as `:AiCommentsClear` does. A [vim-lists](https://github.com/roumail/vim-lists) list: its heading shows its keys, `dd`, `/` (on name and files), `r` and `q` are as in every list. |
| `:AiCommentsClear [file]` | Delete a review with its threads and what is done in it, once you confirm. Without `file`, the one in the agent's list; `<Tab>` lists them. A list showing it is emptied. |

Your own comments stay where they are: fugitive-extras' `Review` list is a
list of its own, and `:colder` goes back to it. To make the agent's
comments yours, `:AiCommentsLoad` loads the file into the `Review` list
instead, replacing what it holds, as `:CommentsLoad` does; for one of
them, `:Comment` on its line.

## Replying

To take one comment further without the rest, reply on it. In the
`:AiComments` list, on a comment's line:

| Key / command | What it does |
| --- | --- |
| `:AiReply [text]` | Send `text` on the comment; prompts unless it is given. Leaving the prompt with `<Esc>` keeps what you typed: `:AiReply` or `:AiReplyDraft` on the same comment goes on from it. |
| `:AiReplyDraft [text]` | Write the reply in a draft above (`g:prompts_reply_height`, default 10), starting with `text` if given, else with what you left at the `:AiReply` prompt. `:w` saves it, closing it sends it, `:q!` before any `:w` drops it. |
| `:AiThread` (`=`) | Show the comment's thread. |

Outside the list they work on its current comment, where `:cnext` took
you, so you can read the code and reply from there. In a thread, they reply
on its comment.

A reply is an ask: it takes `/persona`, `#source`, `@file` and the flags
as `:Ai` does, and your rules go with it. What it sends first is the
comment, the lines it is on as they are now, and the thread so far, so the
agent answers on that comment alone, without a session to remember it.

The agent answers as a one-off (`claude -p`, `copilot -p`): the thread
opens above, the answer comes into it while you keep working, and the
statusline says when it's done. The thread is a file,
`<git dir>/vim-prompts/comments/<time>/<n>.md` for the file's `n`th
comment, so it is there the next time you load the comments. If a reply
can't go, `:AiReply` keeps its text for the next reply on the comment, and
a draft opens again with it.

With `!` (`:AiReply!`, `:AiReplyDraft!`), the reply opens a session
instead, briefed the same way, for when the answer is "fix it". The thread
notes the reply; the answer is in the session.

To take a reply you're typing to a draft, change `AiReply` to
`AiReplyDraft` on the command line and press Enter. To bind fugitive-extras'
`:Comment` keys, `<Plug>(prompts-reply)` leaves `:AiReply ` on the command line and
`<Plug>(prompts-reply-draft)` is `:AiReplyDraft`;
`<Plug>(prompts-reply-session)` and `<Plug>(prompts-reply-draft-session)`
are the same with `!`, to a session. In the list, where every quickfix
window is `qf`, `prompts#comments#in_list()` tells the agent's comments from
the others; a thread's buffer is `ai-thread://…`:

```vim
autocmd FileType qf nmap <buffer><expr> <leader>cc
      \ prompts#comments#in_list() ? '<Plug>(prompts-reply)' : '<Plug>(fugitive-extras-comment)'
autocmd FileType qf nmap <buffer><expr> <leader>cC
      \ prompts#comments#in_list() ? '<Plug>(prompts-reply-session)' : ''
autocmd BufEnter ai-thread://* nmap <buffer> <leader>cc <Plug>(prompts-reply)
autocmd BufEnter ai-thread://* nmap <buffer> <leader>cC <Plug>(prompts-reply-session)
nmap <leader>cr <Plug>(prompts-reply)
```

A persona can take it, so its answers always come with the file, as
`/review` does:

```markdown
---
context: [changes, agent_comments]
---
```
