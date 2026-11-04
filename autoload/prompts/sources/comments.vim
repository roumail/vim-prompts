" #comments: docs/sources/comments.md
function! prompts#sources#comments#info() abort
  " fugitive-extras keeps the review comments
  return {'needs': prompts#installed('fugitive_extras') ? 'review comments (:Comment)' : 'fugitive-extras, which is not installed',
        \ 'arg': 'none'}
endfunction

function! prompts#sources#comments#context(request, arg) abort
  if !prompts#installed('fugitive_extras')
    return ''
  endif
  let l:comments = fugitive_extras#comments#list()
  if empty(l:comments)
    return ''
  endif
  let l:root = FugitiveWorkTree()
  let l:blocks = []
  for l:c in l:comments
    call add(l:blocks, l:c.path . ':' . l:c.start . (l:c.end > l:c.start ? '-' . l:c.end : '')
          \ . "\n" . join(map(prompts#comments#lines(l:root . '/' . l:c.path, l:c.start, l:c.end),
          \   '"> " . v:val'), "\n") . "\n" . l:c.body)
  endfor
  return "My review comments (each quotes the lines it is on, then my comment):\n\n"
        \ . join(l:blocks, "\n\n")
endfunction
