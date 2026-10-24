" Context sources: what Vim shows, or where the agent should look, as text
" for a prompt; asked for as #name or #name:arg, files as @path. Each is a
" file, autoload/prompts/sources/<name>.vim, found on 'runtimepath', so a
" plugin or ~/.vim can add or replace sources (docs/sources.md):
"
"   prompts#sources#<name>#info()  {'needs': what it needs, said when it has
"                                   nothing; 'arg': 'none', 'optional' or
"                                   'required'}
"   prompts#sources#<name>#context(request, arg)  its block, heading
"                                   included, or '' when it has nothing here
"
" The helpers below are for sources. Paths are relative to the work tree,
" where the agent runs; a fugitive:// buffer becomes its path plus the git
" object to read it with (`git show :0:foo.c`), since no agent can open those
" names.

" ---------------------------------------------------------------------------
" Registry

" name -> info, for the sources on 'runtimepath'
let s:sources = {}

function! prompts#source#load() abort
  let s:sources = {}
  for l:file in globpath(&runtimepath, 'autoload/prompts/sources/*.vim', 1, 1)
    let l:name = fnamemodify(l:file, ':t:r')
    if l:name =~# '^\h\w*$' && !has_key(s:sources, l:name)
      try
        let s:sources[l:name] = call('prompts#sources#' . l:name . '#info', [])
      catch
        echohl ErrorMsg
        echomsg 'vim-prompts: source ' . fnamemodify(l:file, ':~') . ': ' . v:exception
        echohl None
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

" {needs, arg}
function! prompts#source#info(name) abort
  return s:sources[a:name]
endfunction

" {name, arg} from `name` or `name:arg`; {'error': ...} when there is no such
" source, or the argument doesn't fit it
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

" The source's context for the request, gathered once per request
function! prompts#source#context(source, request) abort
  let l:key = a:source.name . ':' . a:source.arg
  if !has_key(a:request.context, l:key)
    let a:request.context[l:key] = call('prompts#sources#' . a:source.name . '#context',
          \ [a:request, a:source.arg])
  endif
  return a:request.context[l:key]
endfunction

" ---------------------------------------------------------------------------
" Buffers

" {path, object, side}: object is '' for a file in the work tree
function! prompts#source#describe(bufnr) abort
  let l:name = bufname(a:bufnr)
  if l:name =~# '^fugitive://'
    let l:object = substitute(FugitiveParse(l:name)[0], '^\(\x\{7}\)\x*:', '\1:', '')
    let l:side = l:object =~# '^:0:' ? 'index'
          \ : l:object =~# '^:\d:' ? 'merge stage ' . l:object[1]
          \ : 'commit ' . matchstr(l:object, '^\x\+')
    return {'path': FugitivePath(l:name, ''), 'object': l:object, 'side': l:side}
  endif
  let l:file = fnamemodify(l:name, ':p')
  let l:tree = FugitiveWorkTree(a:bufnr)
  let l:path = !empty(l:tree) && stridx(l:file, l:tree . '/') == 0
        \ ? l:file[len(l:tree) + 1 :] : l:file
  return {'path': l:path, 'object': '', 'side': 'work tree'}
endfunction

" `foo.c` (work tree) or `:0:foo.c` (index)
function! prompts#source#side(bufnr) abort
  let l:d = prompts#source#describe(a:bufnr)
  return empty(l:d.object) ? '`' . l:d.path . '` (work tree)'
        \ : '`' . l:d.object . '` (' . l:d.side . ')'
endfunction

" A file or a fugitive object; not a terminal, quickfix or :Git output
function! prompts#source#is_file(bufnr) abort
  let l:name = bufname(a:bufnr)
  return l:name =~# '^fugitive://'
        \ || !empty(l:name) && empty(getbufvar(a:bufnr, '&buftype'))
        \ && empty(FugitiveResult(a:bufnr))
endfunction

" Lines a to b of a file, from its buffer when loaded (unsaved edits count)
function! prompts#source#lines(file, a, b) abort
  for l:info in getbufinfo({'bufloaded': 1})
    if fnamemodify(l:info.name, ':p') ==# a:file
      return getbufline(l:info.bufnr, a:a, a:b)
    endif
  endfor
  return filereadable(a:file) ? readfile(a:file, '', a:b)[a:a - 1 :] : []
endfunction

" ---------------------------------------------------------------------------
" The request's range or visual selection, fenced, with path and lines. Not a
" source: a range is always sent.
function! prompts#source#selection(request) abort
  if empty(a:request.selection)
    return ''
  endif
  let l:d = prompts#source#describe(a:request.bufnr)
  let l:where = a:request.line1
        \ . (a:request.line2 != a:request.line1 ? '-' . a:request.line2 : '')
  let l:head = (a:request.charwise ? 'Selected text, ' : 'Selected lines, ')
        \ . (empty(bufname(a:request.bufnr)) ? 'line ' . l:where
        \ : l:d.path . ':' . l:where)
  if !empty(l:d.object)
    let l:head .= ' (' . l:d.side . ' version: `git show ' . l:d.object . '`)'
  endif
  let l:fence = match(a:request.selection, '^\s*```') >= 0 ? '````' : '```'
  return l:head . ":\n" . l:fence . getbufvar(a:request.bufnr, '&filetype') . "\n"
        \ . join(a:request.selection, "\n") . "\n" . l:fence
endfunction

