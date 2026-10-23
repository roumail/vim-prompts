" #diff_files: the files in the tab's :G diff --name-only buffer (the
" range's, when asked from it) and the git diff that lists them
function! prompts#sources#diff_files#info() abort
  return {'needs': 'a :G diff --name-only buffer in this tab', 'arg': 'none'}
endfunction

function! prompts#sources#diff_files#context(request, arg) abort
  let l:nr = prompts#source#file_list()
  if !l:nr
    return ''
  endif
  let l:args = prompts#source#file_list_args(l:nr)
  let l:lines = l:nr == a:request.bufnr && a:request.range
        \ ? getbufline(l:nr, a:request.line1, a:request.line2)
        \ : getbufline(l:nr, 1, '$')
  call filter(l:lines, 'v:val =~# "\\S"')
  if empty(l:lines)
    return ''
  endif
  let l:diff = filter(copy(l:args[1:]), 'v:val !~# "^--name-\\%(only\\|status\\)$"')
  let l:end = index(l:diff, '--')
  if l:end >= 0
    let l:diff = l:end ? l:diff[: l:end - 1] : []
  endif
  return 'Changed files (`git ' . join(map(copy(l:args), 'prompts#source#shellarg(v:val)')) . "`):\n"
        \ . join(map(l:lines, '"- " . v:val'), "\n") . "\n"
        \ . 'Read each with `' . join(['git', 'diff'] + map(l:diff, 'prompts#source#shellarg(v:val)'))
        \ . ' -- <path>`.'
endfunction
