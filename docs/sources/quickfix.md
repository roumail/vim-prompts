# #quickfix

The quickfix list you have now: a search's hits, a build's errors.

```vim
:Grep retry_after
:Ai #quickfix which of these still use the old backoff
```

Anything that fills the quickfix list works: `:vimgrep`, `:make`, and an fzf
search such as fzf-utils' `:Grep`, where `<Tab>` marks hits (`alt-a` all of
them) and Enter sends them to the list. The agent gets the list's title, which
is often the search, and its entries, with paths relative to the repository:

```
My quickfix list (:vimgrep /retry_after/j src/**) (path:line: text):
- src/retry.py:42: delay = resp.headers["retry_after"]
- src/client.py:7: from retry import retry_after
```

Entries without a file and line, such as a compiler's summary, are left out.
So the prompt stays short, only the first 100 entries go; set another cap with:

```vim
let g:prompts_quickfix_max = 300
```

The agent reads the files itself. To send whole files, name them with
[`@path`](files.md).
