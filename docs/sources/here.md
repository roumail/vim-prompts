# #here

The file you asked from and your line (the range's first, or the cursor's).
Not a file to read: those are [`@path`](files.md). From a listing (netrw, a
quickfix window) or a scratch buffer it has nothing, and a persona that takes
it says so.

```
Current file: `src/app.py`, line 42
```

In a fugitive buffer (a commit's or the index's version of a file), the agent
is told the git object to read it with: `` (index version: `git show :0:src/app.py`) ``.
