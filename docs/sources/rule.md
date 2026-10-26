# #rule

Rules for the task at hand, by name: `#rule:testing` sends `testing.md`
from the `vim-prompts.library` directories that apply where you are, the
last of that name ([rules for a task](../config.md#rules-for-a-task)).
`<Tab>` after `#rule:` lists the names.

```vim
:Ai #rule:testing add a test for the empty case
:'<,'>Ai /explain #rule:migrations is this reversible
```

Unlike the other sources, the text goes in, not a path: rules are short,
and must be followed rather than looked up. It goes with the other rules,
last (in `{rules}`, not `{context}`), so the persona's instructions and your
query come after it and win where they differ; `{rule}` in a template puts
it there instead.

```
Rules for this task (~/work/prompts/library/testing.md):

- Group tests in classes: tests sharing setup share a class.
...
```

A persona takes one with `context: [file, "rule:testing"]`; there it is
left out where no library has it, while `#rule:` in the ask refuses the
ask.
