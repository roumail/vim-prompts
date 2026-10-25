# #stackoverflow

Has the agent search Stack Overflow, for the terms you give, or for your
question without them, and answer from what it finds, with links.

```vim
:Ai #stackoverflow why does term_start ignore cwd
:Ai #stackoverflow:"vim term_start cwd" why does my terminal open elsewhere
```

```
Search Stack Overflow for `vim term_start cwd`. Use the answers that fit
(accepted, well voted and recent ones first), say where they disagree, and
link the ones you used.
```

## The terms or the question

Without terms, the agent searches for your question as you asked it: good
when the question is the search. Give terms when they differ: the question
says what you want to know about your code, and the terms are what someone
else would have titled theirs. Quote terms with spaces.

The terms are passed as you write them, so Stack Overflow's `[tag]` syntax
works: `#stackoverflow:"[vim] term_start cwd"`.

Terms that are only tags search for your question in those tags:

```vim
:Ai #stackoverflow:"[python] [pytest]" why does my fixture run twice
```

```
Search Stack Overflow for answers to my question, in [python] [pytest]
(tags). ...
```

## A search you always want

A persona can take a search, so you don't type it each time. Tags suit it
best, since they keep your question as the search. A `/vimhelp` persona that
answers from Vim's help and the Vim tags:

```markdown
---
context: ["stackoverflow:[vim] [vimscript]"]
mode: ask
---
{rules}

Answer from Vim's own help first (`:help`), then from Stack Overflow.

{selection}

{query}
```

`:Ai /vimhelp why does term_start ignore cwd` then searches for your question
in those tags. Put it with your other
[personas](../personas.md#where-personas-go).

## One question rather than a search

To have the agent read a question you found, not search, give its link to
[`#url`](url.md): `#url:https://stackoverflow.com/questions/<id>`.

## Changing what it says

To prefer recent answers, or another site, change the source: see
[changing a source](writing.md#changing-a-source).

The agent needs web access; it may ask you to allow it.
