" The agent's comments on lines, written where #comments_file asks: a file
" per ask in <git dir>/vim-prompts/comments/, in vim-review's save format
" (`path:line: text`, `path:start-end: text`, further lines tab-indented,
" paths from the work tree's root). :AiComments reads one into a quickfix
" list of its own: vim-review's Review list holds my comments, so it is left
" alone, and `:colder` goes back to it.

function! s:error(msg) abort
  echohl ErrorMsg
  echomsg 'vim-prompts: ' . a:msg
  echohl None
endfunction

" The buffer's repository's, else the working directory's (from the quickfix
" window, say); '' outside a repository
function! prompts#comments#dir(bufnr) abort
  let l:dir = FugitiveGitDir(a:bufnr)
  if empty(l:dir)
    let l:dir = FugitiveExtractGitDir(getcwd())
  endif
  return empty(l:dir) ? '' : l:dir . '/vim-prompts/comments'
endfunction

" A new file for an ask's comments, named for the time; nothing is created
let s:asked = 0
function! prompts#comments#new_file(bufnr) abort
  let l:dir = prompts#comments#dir(a:bufnr)
  if empty(l:dir)
    return ''
  endif
  let s:asked += 1
  return printf('%s/%s-%d.txt', l:dir, strftime('%Y%m%d-%H%M%S'), s:asked)
endfunction

" The files' names, newest first
function! s:files(dir) abort
  return empty(a:dir) ? []
        \ : sort(map(glob(a:dir . '/*.txt', 1, 1), 'fnamemodify(v:val, ":t")'),
        \   {a, b -> getftime(a:dir . '/' . b) - getftime(a:dir . '/' . a)})
endfunction

" The agent's files, newest first; files once the argument looks like a path
function! prompts#comments#complete(lead, cmdline, pos) abort
  if a:lead =~# '[/~.]'
    return getcompletion(a:lead, 'file')
  endif
  return filter(s:files(prompts#comments#dir(bufnr())), 'stridx(v:val, a:lead) == 0')
endfunction

" :AiComments [file]: the comments in the file (a name from the completion,
" or a path), else in the newest one, as a new quickfix list
function! prompts#comments#load(file) abort
  let l:dir = prompts#comments#dir(bufnr())
  let l:files = s:files(l:dir)
  if empty(a:file)
    if empty(l:files)
      call s:error('no comments from the agent here: ask with #comments_file')
      return
    endif
    let l:file = l:dir . '/' . l:files[0]
  else
    let l:file = index(l:files, a:file) >= 0 ? l:dir . '/' . a:file : fnamemodify(expand(a:file), ':p')
  endif
  if !filereadable(l:file)
    call s:error('no file ' . fnamemodify(l:file, ':~'))
    return
  endif
  let l:root = prompts#config#place(bufnr()).dir
  let l:items = []
  let l:skipped = 0
  for l:line in readfile(l:file)
    if l:line[0] ==# "\t" && !empty(l:items)
      let l:items[-1].text .= "\n" . l:line[1:]
      continue
    endif
    let l:m = matchlist(l:line, '^\(.\{-}\):\(\d\+\)\%(-\(\d\+\)\)\=: \(.*\)$')
    if empty(l:m)
      let l:skipped += !empty(trim(l:line))
      continue
    endif
    let l:item = {'filename': l:root . '/' . l:m[1], 'lnum': str2nr(l:m[2]), 'text': l:m[4]}
    if !empty(l:m[3])
      let l:item.end_lnum = str2nr(l:m[3])
    endif
    call add(l:items, l:item)
  endfor
  call setqflist([], ' ', {'title': 'Agent comments: ' . fnamemodify(l:file, ':t'), 'items': l:items})
  copen
  redraw
  echo 'Agent comments: ' . len(l:items)
        \ . (l:skipped ? ', ' . l:skipped . ' line(s) not in the format, left out' : '')
endfunction
