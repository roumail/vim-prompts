# Changing and writing sources

## Changing a source

A source is a file, `autoload/prompts/sources/<name>.vim`, and the first one
on `'runtimepath'` is used. `~/.vim` comes before your plugins, so to change
`#stackoverflow` (to prefer answers from the last few years, say), copy it
and edit the copy:

```sh
mkdir -p ~/.vim/autoload/prompts/sources
cp ~/.vim/plugged/vim-prompts/autoload/prompts/sources/stackoverflow.vim ~/.vim/autoload/prompts/sources/
```

To change *where* a source's text goes in the prompt, not what it says, use
its slot in a persona instead: see [templates](../personas.md#template).

## Writing a source

A new file there adds `#name` (letters, digits and `_`). It defines two
functions:

```vim
" What it needs, said when it has nothing; whether it takes an argument
function! prompts#sources#jira#info() abort
  return {'needs': 'a ticket: #jira:KEY-123', 'arg': 'required'}
endfunction

" Its text, heading included, or '' when it has nothing here
function! prompts#sources#jira#context(request, arg) abort
  return 'Jira ticket ' . a:arg . ': read it with `jira issue view ' . a:arg . '`.'
endfunction
```

`arg` is `'none'`, `'optional'` or `'required'`; an ask that gives the wrong
kind is refused before `context()` is called. `context()` is called at most
once per ask, and must not change anything or wait on the network: tell the
agent where to look instead. Returning `''` means it has nothing, and an ask
that needs it is refused with `needs`.

A third function, optional, completes the argument after `#name:<Tab>`:

```vim
" The arguments that start with lead
function! prompts#sources#jira#complete(lead) abort
  return filter(['KEY-1', 'KEY-2'], 'stridx(v:val, a:lead) == 0')
endfunction
```

`request` is read only:

| Key | Value |
| --- | --- |
| `query` | the query |
| `bufnr`, `line` | the buffer the ask was made in, and its line |
| `range`, `line1`, `line2` | `0` without a range; the range's lines |
| `selection`, `charwise` | the selected lines (or text, when `charwise`) |

The `prompts#source#*` helpers the built-in sources use are internal and may
change.
