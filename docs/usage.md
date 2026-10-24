# Usage

## Commands

The prefix is `Ai` unless you change it (see [configuration](configuration.md#command-prefix)).

```
:[range]Ai[!] [/persona] [#source...] [@file...] [query] [-- text]
```

Asks the persona (`/default` without one) with its context and what you add.
A range or visual selection is sent too.

- **No context to send:** refused, saying what is missing. `:Ai!` asks anyway.
- **Nothing at all** (`:Ai`): opens the agent, or goes back to the session
  `:Ai` opened before.
- **Context but no query** (`:Ai @`, `:'<,'>Ai #comments`): sends the context
  and the agent waits for your question, which you type in the session.

`:[range]AiDraft[!] ...` takes the same arguments but opens the prompt in a
buffer to edit first:

| | |
| --- | --- |
| `:w` | Send it and keep the draft open (edit and `:w` again for another session). |
| `:wq` | Send it and close the draft. |
| `:q!` | Drop it. |

`:AiPersonas[!]` lists the personas, their context, where each comes from and
what each needs that isn't there. `!` reloads persona and source files first.

## The query

`<Tab>` completes `/personas` (first word), `#sources` and `@files`.

Before `--`, an unknown `#word` or a missing `@file` is an error, so a typo
isn't sent as text. After `--`, everything is your query as typed, so
`#include`, `@decorator` or `--flags` need nothing special:

```vim
:Ai /review -- why is #include here?
```

## Context

| | What it sends |
| --- | --- |
| `#file` | The current file and line. |
| `#diff_files` | The files in the tab's `:G diff --name-only` buffer, and the `git diff` to read each with: `:G diff --cached --name-only` gives `git diff --cached -- <path>`. Delete lines, or ask from a range of that buffer, to send fewer. |
| `#diff_pairs` | Every tab's diff, side by side: `` `:0:foo.c` (index) vs `foo.c` (work tree) ``. The agent reads a side with `git show`. |
| `#comments` | Your review comments from git-extras (`:Comment`), each with the lines it is on. |
| `@path` | Files for the agent to read: `@src/app.py`, `@~/notes/*.md`, `@"~/My Notes/a.md"`. A bare `@` picks files in the project, `@~/` or any `@dir/` picks there (needs `g:prompts_file_picker`). Files outside the repo are opened to the agent with `--add-dir`. |
| `#repo:owner/name` | A GitHub repository, for the agent to read with `gh` (a full `https://github.com/...` URL works too). |
| `#stackoverflow[:"terms"]` | Has the agent search Stack Overflow, for the terms or for your query, and link the answers it used. |

The agent fetches remote context itself, so Vim never waits on the network.

## Personas

| Persona | Context | Does |
| --- | --- | --- |
| `/default` | | Your query, the selection, and what you add. |
| `/review` | `#diff_files #diff_pairs` | Reviews the change; add `#comments` to have it answer yours. Read only (Claude: plan mode). |
| `/explain` | `#file` | Explains the selection, or the code at your line. |

Every ask in a repository also carries its
[repository context](personas.md#repository-context), if it has one.
