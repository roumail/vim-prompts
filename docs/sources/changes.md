# #changes

The files a change touches, worked out from git: nothing to open first.

| | The change |
| --- | --- |
| `#changes` | Your branch: everything since it forked from the default branch (`origin/main`, or `main`/`master`), committed or not, and new untracked files. On the default branch itself, what isn't committed. |
| `#changes:staged` | What you're about to commit: the index against `HEAD`. |
| `#changes:<branch>` | Another branch's commits since it forked, without checking it out (`#changes:origin/feature`). |

These are the same scopes as git-extras' `:BranchDiff`. The agent gets the
files with their status, and the `git diff` that shows each, so it reads the
same change you'd see:

```
Changes on this branch since it forked from origin/main at e309eb0, committed or not (status, path):
- M src/app.py
- A src/retry.py
- ? notes.txt
Read each with `git diff e309eb0 -- <path>`; a `?` file is new and untracked, read it as it is.
```

`/review` takes it, so `:Ai /review` reviews your branch, and
`:Ai /review #changes:staged` what you're about to commit. To review only some
files, name them instead: `:Ai /review @src/app.py`.
