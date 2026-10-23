" Files on disk, asked for as @path (the arg is the absolute paths, one per
" line). Paths in the work tree are relative to it; others stay absolute,
" and their directories are given to the agent with --add-dir.
function! prompts#sources#files#info() abort
  return {'needs': 'files: @path', 'arg': 'required'}
endfunction

function! prompts#sources#files#context(request, arg) abort
  let l:tree = FugitiveWorkTree(a:request.bufnr)
  let l:files = []
  for l:file in split(a:arg, "\n")
    let l:path = !empty(l:tree) && stridx(l:file, l:tree . '/') == 0
          \ ? l:file[len(l:tree) + 1 :] : l:file
    call add(l:files, '- `' . l:path . '`')
  endfor
  return empty(l:files) ? '' : "Files to read:\n" . join(l:files, "\n")
endfunction
