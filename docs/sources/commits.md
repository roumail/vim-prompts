# #commits

Commits by hash, each on its own: what it changed, not the range around it.

```vim
:Ai /review #commits:a1b2c3d,e4f5a6b why did these break retries
```

The agent gets each commit's subject and files, and the `git show` that
shows each:

```
Commits (hash subject, then status path):
- a1b2c3d Fix retry backoff
  - M src/retry.py
- e4f5a6b Drop the old client
  - D src/old.py
Read each with `git show <hash> -- <path>`.
```

Separate hashes with commas. `<Tab>` after `#commits:` or a comma completes
the last 50 commits' hashes. A hash that isn't a commit sends nothing, so the
ask stops.

To pick them in fzf, `prompts#sources#commits#fzf()` is the repository's log
for fzf.vim's insert-mode completion: mark commits with `<Tab>`, and Enter
inserts `#commits:<hash>,<hash>` in your `:AiDraft` (on its first line, where
sources are read):

```vim
inoremap <expr> <C-x><C-g> fzf#vim#complete(prompts#sources#commits#fzf())
```

It inserts the whole word, so use it in place of typing `#commits:`. Hashes
copied elsewhere, comma-separated, can be pasted after `#commits:` too. For a
branch's whole change, use [`#changes`](changes.md).
