# #comments

Your review comments, from [vim-review](https://github.com/roumail/vim-review).
Leave one on a line or a selection with `:Comment`; they collect in a
quickfix list called Review (`:Comments` opens it), and `:CommentsSave` /
`:CommentsLoad` keep them (per branch, with git-extras).

Each comment goes with the lines it is on, quoted from the file as it is now:

```
My review comments (each quotes the lines it is on, then my comment):

src/app.py:40-42
> def handle(event):
>     data = parse(event)
>     return save(data)
why isn't this retried?

src/db.py:7
> TIMEOUT = 5
too short for the batch job
```

Say what you want done with them; the comments alone aren't a question:

```vim
:Ai #comments which of these are worth fixing before merging
:Ai /review #comments
:Ai #comments address each one, and answer the questions
```

`/review #comments` reviews the change and answers each comment. Comments
stay in the list after an ask, until you load others over them or clear
them (`review#clear()`).
