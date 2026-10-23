" Context sources: what Vim shows, as text for a prompt, asked for as #name.
" Each gives its whole block, heading included, or '' when it has nothing
" here. Paths are relative to the work
" tree, where the agent runs; a fugitive:// buffer becomes its path plus the
" git object to read it with (`git show :0:foo.c`), since no agent can open
" those names.

" ---------------------------------------------------------------------------
" Buffers

" {path, object, side}: object is '' for a file in the work tree
function! s:describe(bufnr) abort
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
function! s:side(bufnr) abort
  let l:d = s:describe(a:bufnr)
  return empty(l:d.object) ? '`' . l:d.path . '` (work tree)'
        \ : '`' . l:d.object . '` (' . l:d.side . ')'
endfunction

" A file or a fugitive object; not a terminal, quickfix or :Git output
function! s:is_file(bufnr) abort
  let l:name = bufname(a:bufnr)
  return l:name =~# '^fugitive://'
        \ || !empty(l:name) && empty(getbufvar(a:bufnr, '&buftype'))
        \ && empty(FugitiveResult(a:bufnr))
endfunction

" The args of a `:G diff --name-only` (or --name-status) buffer, else []
function! s:file_list_args(bufnr) abort
  let l:args = get(FugitiveResult(a:bufnr), 'args', [])
  return get(l:args, 0, '') ==# 'diff'
        \ && (index(l:args, '--name-only') >= 0 || index(l:args, '--name-status') >= 0)
        \ ? l:args : []
endfunction

" Whether the buffer is such a file list: there a range picks files, it
" doesn't select text
function! prompts#source#is_file_list(bufnr) abort
  return !empty(s:file_list_args(a:bufnr))
endfunction

" A file list in this tab, the current buffer first; 0 if none
function! s:file_list() abort
  for l:nr in [bufnr()] + tabpagebuflist()
    if prompts#source#is_file_list(l:nr)
      return l:nr
    endif
  endfor
  return 0
endfunction

" Lines a to b of a file, from its buffer when loaded (unsaved edits count)
function! s:lines(file, a, b) abort
  for l:info in getbufinfo({'bufloaded': 1})
    if fnamemodify(l:info.name, ':p') ==# a:file
      return getbufline(l:info.bufnr, a:a, a:b)
    endif
  endfor
  return filereadable(a:file) ? readfile(a:file, '', a:b)[a:a - 1 :] : []
endfunction

function! s:shellarg(arg) abort
  return a:arg =~# '^[[:alnum:]_./:=@^~-]\+$' ? a:arg : shellescape(a:arg)
endfunction

" ---------------------------------------------------------------------------
" The request's range or visual selection, fenced, with path and lines. Not a
" source: a range is always sent.
function! prompts#source#selection(request) abort
  if empty(a:request.selection)
    return ''
  endif
  let l:d = s:describe(a:request.bufnr)
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

" ---------------------------------------------------------------------------
" Sources: s:<name>(request) -> text

" The file the request was made in, and the cursor's line
function! s:file(request) abort
  if !s:is_file(a:request.bufnr)
    return ''
  endif
  let l:d = s:describe(a:request.bufnr)
  return 'Current file: `' . l:d.path . '`, line ' . a:request.line
        \ . (empty(l:d.object) ? ''
        \ : ' (' . l:d.side . ' version: `git show ' . l:d.object . '`)')
endfunction

" Every tab with a diff: its sides, left to right
function! s:diff_pairs(request) abort
  let l:diffs = []
  for l:tab in gettabinfo()
    let l:sides = []
    for l:winid in l:tab.windows
      if getwinvar(l:winid, '&diff') && s:is_file(winbufnr(l:winid))
        call add(l:sides, s:side(winbufnr(l:winid)))
      endif
    endfor
    if len(l:sides) > 1
      call add(l:diffs, '- ' . join(l:sides, ' vs '))
    endif
  endfor
  return empty(l:diffs) ? ''
        \ : "Diffs open in Vim, one per tab:\n" . join(l:diffs, "\n")
        \ . "\nRead a side that is not the work tree with `git show <object>`."
endfunction

" The file list's files (the range's, when asked from it) and the git diff
" that lists them
function! s:diff_files(request) abort
  let l:nr = s:file_list()
  if !l:nr
    return ''
  endif
  let l:args = s:file_list_args(l:nr)
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
  return 'Changed files (`git ' . join(map(copy(l:args), 's:shellarg(v:val)')) . "`):\n"
        \ . join(map(l:lines, '"- " . v:val'), "\n") . "\n"
        \ . 'Read each with `' . join(['git', 'diff'] + map(l:diff, 's:shellarg(v:val)'))
        \ . ' -- <path>`.'
endfunction

" git-extras' review comments, each with the lines it is on
function! s:render_comments(comments) abort
  if empty(a:comments)
    return ''
  endif
  let l:tree = FugitiveWorkTree()
  let l:blocks = []
  for l:c in a:comments
    let l:start = get(l:c, 'start_line', l:c.line)
    let l:lines = s:lines(l:tree . '/' . l:c.path, l:start, l:c.line)
    call add(l:blocks, l:c.path . ':' . (l:start == l:c.line ? l:c.line : l:start . '-' . l:c.line)
          \ . "\n" . join(map(l:lines, '"> " . v:val'), "\n") . "\n" . l:c.body)
  endfor
  return "My review comments (each quotes the lines it is on, then my comment):\n\n"
        \ . join(l:blocks, "\n\n")
endfunction

function! s:comments(request) abort
  return s:render_comments(git_extras#comments#list())
endfunction

" name -> what it needs, for when it has nothing here
let s:sources = {
      \ 'file': 'a file',
      \ 'diff_files': 'a :G diff --name-only buffer in this tab',
      \ 'diff_pairs': 'a diff (:DiffThis, :BranchDiff)',
      \ 'comments': 'review comments (:Comment)',
      \ }

function! prompts#source#names() abort
  return sort(keys(s:sources))
endfunction

function! prompts#source#exists(name) abort
  return type(a:name) == v:t_string && has_key(s:sources, a:name)
endfunction

function! prompts#source#needs(name) abort
  return s:sources[a:name]
endfunction

" The source's context for the request, gathered once per request
function! prompts#source#context(name, request) abort
  if !has_key(a:request.context, a:name)
    let a:request.context[a:name] = call('s:' . a:name, [a:request])
  endif
  return a:request.context[a:name]
endfunction
