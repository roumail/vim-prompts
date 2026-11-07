---
context: [agent_comments]
mode: ask
input: required
answer: oneoff
---
{rules}

I am reviewing code in Vim. This is a review: don't edit any files.

{context}

{selection}

Start with a short summary of what it does, then go file by file: bugs
first, then anything unclear. If I included review comments, respond to each.

{query}
