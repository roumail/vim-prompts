function! prompts#comments#dir(bufnr) abort
  let l:dir = FugitiveGitDir(a:bufnr)
  if empty(l:dir)
    " From the quickfix window, say
    let l:dir = FugitiveExtractGitDir(getcwd())
  endif
  return empty(l:dir) ? '' : l:dir . '/vim-prompts/comments'
endfunction

function! s:files(dir) abort
  return empty(a:dir) ? []
        \ : sort(map(glob(a:dir . '/*.txt', 1, 1), 'fnamemodify(v:val, ":t")'),
        \   {a, b -> getftime(a:dir . '/' . b) - getftime(a:dir . '/' . a)})
endfunction

function! prompts#comments#complete(lead, cmdline, pos) abort
  if a:lead =~# '[/~.]'
    return getcompletion(a:lead, 'file')
  endif
  return filter(s:files(prompts#comments#dir(bufnr())), 'stridx(v:val, a:lead) == 0')
endfunction

function! s:file(file) abort
  let l:dir = prompts#comments#dir(bufnr())
  let l:files = s:files(l:dir)
  if empty(a:file)
    if empty(l:files)
      call prompts#error('no comments from the agent here: ask with #agent_comments')
      return ''
    endif
    let l:file = l:dir . '/' . l:files[0]
  else
    let l:file = index(l:files, a:file) >= 0 ? l:dir . '/' . a:file : fnamemodify(expand(a:file), ':p')
  endif
  if !filereadable(l:file)
    call prompts#error('no file ' . fnamemodify(l:file, ':~'))
    return ''
  endif
  return l:file
endfunction

function! prompts#comments#review(file) abort
  let l:file = s:file(a:file)
  if !empty(l:file)
    call review#load(l:file)
  endif
endfunction

function! prompts#comments#load(file) abort
  let l:file = s:file(a:file)
  if empty(l:file)
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
  " A list of its own: vim-review's Review list holds my comments, and
  " :colder goes back to it
  call setqflist([], ' ', {'title': 'Agent comments: ' . fnamemodify(l:file, ':t'), 'items': l:items})
  copen
  redraw
  echo 'Agent comments: ' . len(l:items)
        \ . (l:skipped ? ', ' . l:skipped . ' line(s) not in the format, left out' : '')
endfunction
