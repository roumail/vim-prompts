" #quickfix: docs/sources/quickfix.md
function! prompts#sources#quickfix#info() abort
  return {'needs': 'a quickfix list (:Grep, :vimgrep, :make)', 'arg': 'none'}
endfunction

" The entries on a line of a file; a line of output alone (a compiler's
" summary) is left out
function! prompts#sources#quickfix#context(request, arg) abort
  let l:list = getqflist({'title': 1, 'items': 1})
  let l:items = filter(l:list.items, 'v:val.valid && v:val.bufnr > 0')
  if empty(l:items)
    return ''
  endif
  let l:max = get(g:, 'prompts_quickfix_max', 100)
  let l:lines = []
  for l:item in l:items[: l:max - 1]
    " A search's buffers aren't loaded, so fugitive doesn't know their
    " repository: paths are relative to the asking buffer's
    let l:name = bufname(l:item.bufnr)
    let l:path = l:name =~# '^fugitive://' ? prompts#source#describe(l:item.bufnr).object
          \ : prompts#source#path(fnamemodify(l:name, ':p'), a:request.bufnr)
    let l:text = trim(substitute(l:item.text, '\s\+', ' ', 'g'))
    call add(l:lines, '- ' . l:path . ':' . l:item.lnum
          \ . (empty(l:text) ? '' : ': ' . strcharpart(l:text, 0, 200)))
  endfor
  let l:title = trim(l:list.title)
  return 'My quickfix list' . (empty(l:title) ? '' : ' (' . l:title . ')')
        \ . (len(l:items) > l:max ? ', its first ' . l:max . ' of ' . len(l:items) . ' entries' : '')
        \ . " (path:line: text):\n" . join(l:lines, "\n")
endfunction
