# Context sources

A source turns something you have in Vim, or somewhere the agent should look,
into text for the prompt. You add one with `#name` (or `#name:argument`),
files with `@path`; a persona can take some by default. Only what is asked
for is sent, whatever else is open.

| | For |
| --- | --- |
| [`#file`](file.md) | the file and line you're on |
| [`#changes`](changes.md) | the files your branch changes, committed or not |
| [`#commits`](commits.md) | commits by hash: `#commits:a1b2c3d,e4f5a6b` |
| [`#diff_pairs`](diff_pairs.md) | the diffs you have open in Vim, or one `:BranchDiff`'s |
| [`#comments`](comments.md) | your review comments |
| [`#agent_comments`](agent_comments.md) | the agent's comments on lines, also as a file `:AiComments` opens as a quickfix list |
| [`#quickfix`](quickfix.md) | your quickfix list: a search's hits, a build's errors |
| [`@path`](files.md) | files for the agent to read |
| [`+name`](rule.md) | rules for the task, by name: `+testing` |
| [`#repo`](repo.md) | a GitHub repository |
| [`#stackoverflow`](stackoverflow.md) | a Stack Overflow search |
| [`#url`](url.md) | a link: a GitHub issue or pull request, a Stack Overflow question, docs |

A range or visual selection isn't a source: it always goes too.

`:AiSources` lists them where you are, those for what to work on apart from
`+name` rules and `#agent_comments`, which say how
([:AiSources](../usage.md#aisources)).

Sources don't paste file contents or fetch anything. They tell the agent what
to read and how (`git diff`, `git show`, `gh`), and the agent reads it with
its own tools, so Vim never waits and the prompt stays short. A `+name` rule is
the exception: rules are short and must be followed, so their text goes in,
as the [rules](../personas.md#rules) do.

To change what a source says, or add your own, see
[changing and writing sources](writing.md).
