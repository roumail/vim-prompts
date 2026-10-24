# Usage

## :Ai

```
:[range]Ai[!] [/persona] [#source...] [@file...] [query] [-- text]
```

Asks the [persona](personas.md) (`/default` without one) with its context,
the [sources and files](sources.md) you add, and a range or visual selection.

- **No context to send:** refused, saying what is missing. `:Ai!` asks anyway.
- **Nothing at all** (`:Ai`): opens the agent, or goes back to the session
  `:Ai` opened before.
- **Context but no query** (`:Ai @`, `:'<,'>Ai #comments`): sends the context
  and the agent waits for your question, which you type in the session.

## Typing the query

`<Tab>` completes `/personas` (first word), `#sources` and `@files`.

Before `--`, an unknown `#word` or a missing `@file` is an error, so a typo
isn't sent as text. After `--`, everything is your query as typed, so
`#include`, `@decorator` or `--flags` need nothing special:

```vim
:Ai /review -- why is #include here?
```

## :AiDraft

`:[range]AiDraft[!] ...` takes the same arguments but opens the prompt in a
buffer to edit first:

| | |
| --- | --- |
| `:w` | Send it and keep the draft open (edit and `:w` again for another session). |
| `:wq` | Send it and close the draft. |
| `:q!` | Drop it. |

## :AiPersonas

`:AiPersonas[!]` lists the personas, their context, where each comes from and
what each needs that isn't there. `!` reloads persona and source files first.

## Mappings

No keys are bound. The `<Plug>` mappings type the command for you to finish
(`:'<,'>Ai ` from visual mode):

```vim
nmap <leader>aa <Plug>(prompts-ask)
xmap <leader>aa <Plug>(prompts-ask)
nmap <leader>ad <Plug>(prompts-draft)
xmap <leader>ad <Plug>(prompts-draft)
```

## Command prefix

```vim
let g:prompts_namespace = 'Ai'     " :Ai, :AiDraft, :AiPersonas
```
