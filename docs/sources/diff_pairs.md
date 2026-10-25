# #diff_pairs

What you're looking at: the diffs open in Vim, one per tab, the two sides of
each, left to right. Unlike `#changes` it depends on your windows, so use it
when you've set up the comparison yourself: `:BranchDiff`, or `:Gdiffsplit` /
`:DiffThis` against a commit.

Each `:BranchDiff` is a comparison in git-extras' `:Compares`, named for the
branch, and its tabs carry the name. Close the files that raise no
questions, and `#diff_pairs:<name>` sends the ones left, whatever else is
open:

| | The diffs |
| --- | --- |
| `#diff_pairs:<name>` | The comparison's tabs still open; all of it, as a `git diff`, when you've closed them all. `<Tab>` completes the names. |
| `#diff_pairs` | Asked from a comparison's tab, that comparison. Otherwise every diff open, by comparison. |

```
Diffs open in Vim from the comparison feature (`git diff e309eb0`, 12 files), one per tab:
- `e309eb0:src/app.py` (commit e309eb0) vs `src/app.py` (work tree)
- `e309eb0:src/retry.py` (commit e309eb0) vs `src/retry.py` (work tree)
Read a side that is not the work tree with `git show <object>`.
```

```vim
:Ai /review #diff_pairs:feature   " the files of :BranchDiff I kept open
:Ai /review #diff_pairs           " the diffs I have open
```
