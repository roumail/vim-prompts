# #url

A link, for the agent to read the way that suits the site. Give one `#url`
per link; quote nothing, a link has no spaces.

```vim
:Ai #url:https://github.com/tpope/vim-dispatch/issues/312 is this the bug I hit
:Ai #url:https://flask.palletsprojects.com/en/stable/testing/ /tests for this view
```

| Link | The agent is told to read it with |
| --- | --- |
| A GitHub issue, `github.com/<owner>/<repo>/issues/<n>` | `gh issue view <n> --repo <owner>/<repo> --comments` |
| A GitHub pull request, `.../pull/<n>` (and its tabs) | `gh pr view ... --comments` and `gh pr diff ...` |
| A Stack Overflow, Super User, Server Fault, Ask Ubuntu or `*.stackexchange.com` question, `.../questions/<id>` or `.../q/<id>` | the Stack Exchange API, its answers by votes, then the question |
| An answer, `.../a/<id>` | the API, then the question it answers |
| Anything else: docs, a blog post, a GitHub file | fetching the page, and the pages it links to as far as the request needs |

```
GitHub issue tpope/vim-dispatch#312 (https://github.com/tpope/vim-dispatch/issues/312).
Read it with `gh issue view 312 --repo tpope/vim-dispatch --comments`. Only read it.
```

A whole repository, rather than one of its issues, is [`#repo`](repo.md). A
search, rather than one question, is [`#stackoverflow`](stackoverflow.md).

`#url:<Tab>` completes the links in your registers (`"`, `+` and `*`), so
copy a link in the browser, then type `#url:` and `<Tab>`.

## Links a persona always reads

A persona can take a link like any source, for the docs it always needs:

```markdown
---
context: ["url:https://flask.palletsprojects.com/en/stable/testing/"]
---
```

The agent needs web access for anything but GitHub (`gh`, installed and logged
in); it may ask you to allow it.
