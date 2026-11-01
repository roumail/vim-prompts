" #comments: docs/sources/comments.md
function! prompts#sources#comments#info() abort
  return {'needs': 'review comments (:Comment)', 'arg': 'none'}
endfunction

function! prompts#sources#comments#context(request, arg) abort
  let l:comments = review#list()
  if empty(l:comments)
    return ''
  endif
  let l:root = review#root()
  let l:blocks = []
  for l:c in l:comments
    let l:file = l:root . '/' . l:c.path
    " From its buffer when loaded: unsaved edits count
    let l:info = filter(getbufinfo({'bufloaded': 1}), 'fnamemodify(v:val.name, ":p") ==# l:file')
    call add(l:blocks, l:c.path . ':' . l:c.start . (l:c.end > l:c.start ? '-' . l:c.end : '')
          \ . "\n" . join(map(!empty(l:info) ? getbufline(l:info[0].bufnr, l:c.start, l:c.end)
          \   : filereadable(l:file) ? readfile(l:file, '', l:c.end)[l:c.start - 1 :] : [],
          \   '"> " . v:val'), "\n") . "\n" . l:c.body)
  endfor
  return "My review comments (each quotes the lines it is on, then my comment):\n\n"
        \ . join(l:blocks, "\n\n")
endfunction
