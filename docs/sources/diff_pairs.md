# #diff_pairs

What you're looking at: the diffs open in Vim, in every tab, the two sides of
each, left to right. Unlike `#changes` it depends on your windows, so use it
when you've set up the comparison yourself: a branch checked out and
`:BranchDiff` open, or `:Gdiffsplit` / `:DiffThis` against a commit.

```
Diffs open in Vim, one per tab:
- `:0:src/app.py` (index) vs `src/app.py` (work tree)
Read a side that is not the work tree with `git show <object>`.
```

```vim
:Ai /review #diff_pairs        " review the diffs I have open
```
