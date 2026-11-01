" Context sources and the helpers they use: docs/sources/writing.md

let s:sources = {}

function! prompts#source#load() abort
  let s:sources = {}
  for l:file in globpath(&runtimepath, 'autoload/prompts/sources/*.vim', 1, 1)
    let l:name = fnamemodify(l:file, ':t:r')
    if l:name =~# '^\h\w*$' && !has_key(s:sources, l:name)
      try
        let s:sources[l:name] = call('prompts#sources#' . l:name . '#info', [])
      catch
        call prompts#error('source ' . fnamemodify(l:file, ':~') . ': ' . v:exception)
      endtry
    endif
  endfor
endfunction

function! prompts#source#names() abort
  return sort(keys(s:sources))
endfunction

function! prompts#source#exists(name) abort
  return type(a:name) == v:t_string && has_key(s:sources, a:name)
endfunction

function! prompts#source#info(name) abort
  return s:sources[a:name]
endfunction

function! prompts#source#parse(text) abort
  let l:m = matchlist(a:text, '^\(\h\w*\)\%(:\(.*\)\)\=$')
  if empty(l:m) || !prompts#source#exists(l:m[1])
    return {'error': 'no context source #' . a:text . ' (#'
          \ . join(filter(prompts#source#names(), 'v:val !=# "files"'), ', #')
          \ . '; files are @path)'}
  endif
  let l:arg = l:m[2]
  let l:takes = s:sources[l:m[1]].arg
  if l:takes ==# 'required' && empty(l:arg)
    return {'error': '#' . l:m[1] . ' needs ' . s:sources[l:m[1]].needs}
  elseif l:takes ==# 'none' && !empty(l:arg)
    return {'error': '#' . l:m[1] . ' takes no argument'}
  endif
  return {'name': l:m[1], 'arg': l:arg}
endfunction

function! prompts#source#context(source, request) abort
  let l:key = a:source.name . ':' . a:source.arg
  if !has_key(a:request.context, l:key)
    let a:request.context[l:key] = call('prompts#sources#' . a:source.name . '#context',
          \ [a:request, a:source.arg])
  endif
  return a:request.context[l:key]
endfunction

function! prompts#source#describe(bufnr) abort
  let l:name = bufname(a:bufnr)
  " No agent can open a fugitive:// name: its path, and the object to read
  if l:name =~# '^fugitive://'
    let l:object = substitute(FugitiveParse(l:name)[0], '^\(\x\{7}\)\x*:', '\1:', '')
    return {'path': FugitivePath(l:name, ''), 'object': l:object,
          \ 'side': l:object =~# '^:0:' ? 'index'
          \   : l:object =~# '^:\d:' ? 'merge stage ' . l:object[1]
          \   : 'commit ' . matchstr(l:object, '^\x\+')}
  endif
  return {'path': prompts#source#path(fnamemodify(l:name, ':p'), a:bufnr), 'object': '', 'side': 'work tree'}
endfunction

function! prompts#source#path(file, bufnr) abort
  let l:tree = FugitiveWorkTree(a:bufnr)
  return !empty(l:tree) && stridx(a:file, l:tree . '/') == 0 ? a:file[len(l:tree) + 1 :] : a:file
endfunction

function! prompts#source#is_file(bufnr) abort
  let l:name = bufname(a:bufnr)
  " A file browser's listing (netrw, dirvish) is not a file
  return l:name =~# '^fugitive://'
        \ || !empty(l:name) && empty(getbufvar(a:bufnr, '&buftype'))
        \ && empty(FugitiveResult(a:bufnr))
        \ && getbufvar(a:bufnr, '&filetype') !=# 'netrw' && !isdirectory(l:name)
endfunction
