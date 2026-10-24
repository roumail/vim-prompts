# #repo

A GitHub repository, for the agent to read with `gh` (installed and logged
in). Only read: the agent is told not to change it.

```vim
:Ai #repo:tpope/vim-dispatch how does :Start pick a handler
:Ai #repo:https://github.com/tpope/vim-dispatch ...
```

```
GitHub repository `tpope/vim-dispatch` (https://github.com/tpope/vim-dispatch).
Read what you need with `gh repo view tpope/vim-dispatch`, `gh api
repos/tpope/vim-dispatch/contents/<path>` or `gh search code --repo
tpope/vim-dispatch <terms>`, or shallow-clone it into a temporary directory.
Only read it.
```
