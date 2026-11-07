# +name, rules for the task

Rules for the task at hand, by name: `+testing` sends `testing.md`
from the `vim-prompts.task-rules` directories that apply where you are, the
last of that name ([rules for a task](../config.md#rules-for-a-task)).
`<Tab>` after `+` lists the names. It is `+`, not `#`, as a rule says how
to work, not what on: `#` is for sources, so they stay apart in a picker.

```vim
:Ai +testing add a test for the empty case
:'<,'>Ai +migrations is this reversible
```

Unlike the other sources, the text goes in, not a path: rules are short,
and must be followed rather than looked up. It goes with the other rules,
last (in `{rules}`, not `{context}`), so the persona's instructions and your
query come after it and win where they differ; `{rule}` in a template puts
it there instead.

```
Rules for this task (~/work/prompts/task-rules/testing.md):

- Group tests in classes: tests sharing setup share a class.
...
```

A persona takes one with `context: [here, +testing]`. Where no
task-rules directory has it, the ask is refused, as with `+name` in the
ask, unless the persona marks it as one to go without:
`+testing?`.
