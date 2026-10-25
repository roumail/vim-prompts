" #file: docs/sources/file.md
function! prompts#sources#file#info() abort
  return {'needs': 'a file', 'arg': 'none'}
endfunction

function! prompts#sources#file#context(request, arg) abort
  if !prompts#source#is_file(a:request.bufnr)
    return ''
  endif
  let l:d = prompts#source#describe(a:request.bufnr)
  return 'Current file: `' . l:d.path . '`, line ' . a:request.line
        \ . (empty(l:d.object) ? ''
        \ : ' (' . l:d.side . ' version: `git show ' . l:d.object . '`)')
endfunction
