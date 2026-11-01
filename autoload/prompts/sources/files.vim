" @path: docs/sources/files.md. The arg is absolute paths, one per line.
function! prompts#sources#files#info() abort
  return {'needs': 'files: @path', 'arg': 'required'}
endfunction

function! prompts#sources#files#context(request, arg) abort
  let l:files = []
  for l:file in split(a:arg, "\n")
    call add(l:files, '- `' . prompts#source#path(l:file, a:request.bufnr) . '`')
  endfor
  return empty(l:files) ? '' : "Files to read:\n" . join(l:files, "\n")
endfunction
