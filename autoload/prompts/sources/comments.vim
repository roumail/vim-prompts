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
    let l:lines = prompts#source#lines(l:root . '/' . l:c.path, l:c.start, l:c.end)
    call add(l:blocks, l:c.path . ':' . l:c.start . (l:c.end > l:c.start ? '-' . l:c.end : '')
          \ . "\n" . join(map(l:lines, '"> " . v:val'), "\n") . "\n" . l:c.body)
  endfor
  return "My review comments (each quotes the lines it is on, then my comment):\n\n"
        \ . join(l:blocks, "\n\n")
endfunction
