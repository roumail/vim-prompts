# Context sources

A source turns something you have in Vim, or somewhere the agent should look,
into text for the prompt. You add one with `#name` (or `#name:argument`),
files with `@path`; a persona can take some by default. Only what is asked
for is sent, whatever else is open.

| | For |
| --- | --- |
| [`#file`](file.md) | the file and line you're on |
| [`#changes`](changes.md) | the files your branch changes, committed or not |
| [`#diff_pairs`](diff_pairs.md) | the diffs you have open in Vim, or one `:BranchDiff`'s |
| [`#comments`](comments.md) | your review comments |
| [`@path`](files.md) | files for the agent to read |
| [`#repo`](repo.md) | a GitHub repository |
| [`#stackoverflow`](stackoverflow.md) | a Stack Overflow search |

A range or visual selection isn't a source: it always goes too.

Sources don't paste file contents or fetch anything. They tell the agent what
to read and how (`git diff`, `git show`, `gh`), and the agent reads it with
its own tools, so Vim never waits and the prompt stays short.

To change what a source says, or add your own, see
[changing and writing sources](writing.md).
