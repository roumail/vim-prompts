" #diff_pairs[:name]: docs/sources/diff_pairs.md
function! prompts#sources#diff_pairs#info() abort
  return {'needs': 'a diff (:DiffThis, :BranchDiff), or a comparison listed in :Compares',
        \ 'arg': 'optional'}
endfunction

function! s:dir(bufnr) abort
  let l:dir = FugitiveGitDir(a:bufnr)
  return empty(l:dir) ? FugitiveExtractGitDir(getcwd()) : l:dir
endfunction

function! prompts#sources#diff_pairs#complete(lead) abort
  return filter(map(git_extras#compares#list(s:dir(bufnr())), 'v:val.name'),
        \ 'stridx(v:val, a:lead) == 0')
endfunction

function! s:pair(tabnr) abort
  let l:sides = []
  for l:winid in gettabinfo(a:tabnr)[0].windows
    " Not getwinvar(), which finds only the current tab's windows
    if gettabwinvar(a:tabnr, l:winid, '&diff') && prompts#source#is_file(winbufnr(l:winid))
      call add(l:sides, prompts#source#side(winbufnr(l:winid)))
    endif
  endfor
  return len(l:sides) > 1 ? join(l:sides, ' vs ') : ''
endfunction

" A comparison opened twice repeats its pairs
function! s:unique(list) abort
  let l:unique = []
  for l:item in a:list
    if !empty(l:item) && index(l:unique, l:item) < 0
      call add(l:unique, l:item)
    endif
  endfor
  return l:unique
endfunction

function! s:diff(compare) abort
  return '`git diff ' . a:compare.base[:6] . (empty(a:compare.head) ? '' : ' ' . a:compare.head) . '`'
endfunction

function! s:compare(compare) abort
  let l:pairs = s:unique(map(copy(a:compare.tabs), 's:pair(v:val)'))
  let l:what = 'the comparison ' . a:compare.name . ' (' . s:diff(a:compare) . ', '
        \ . a:compare.files . ' files)'
  if empty(l:pairs)
    return 'All of ' . l:what . '; none of its diffs are open in Vim. List its files with '
          \ . substitute(s:diff(a:compare), 'diff', 'diff --name-status', '') . '.'
  endif
  return 'Diffs open in Vim from ' . l:what . ', one per tab:' . "\n- " . join(l:pairs, "\n- ")
        \ . "\nRead a side that is not the work tree with `git show <object>`."
endfunction

function! prompts#sources#diff_pairs#context(request, arg) abort
  let l:compares = git_extras#compares#list(s:dir(a:request.bufnr))
  let l:named = empty(a:arg)
        \ ? filter(copy(l:compares), 'index(v:val.tabs, tabpagenr()) >= 0')
        \ : filter(copy(l:compares), 'v:val.name ==# a:arg')
  if !empty(l:named)
    return s:compare(l:named[0])
  elseif !empty(a:arg)
    return ''
  endif
  " Every diff open, under the comparison its tab is in
  let l:groups = {}
  let l:order = []
  for l:tab in gettabinfo()
    let l:pair = s:pair(l:tab.tabnr)
    if empty(l:pair)
      continue
    endif
    let l:in = filter(copy(l:compares), 'index(v:val.tabs, l:tab.tabnr) >= 0')
    let l:group = empty(l:in) ? '' : 'From the comparison ' . l:in[0].name
          \ . ' (' . s:diff(l:in[0]) . '):'
    if !has_key(l:groups, l:group)
      let l:groups[l:group] = []
      call add(l:order, l:group)
    endif
    call add(l:groups[l:group], '- ' . l:pair)
  endfor
  if empty(l:order)
    return ''
  endif
  let l:lines = []
  for l:group in l:order
    if len(l:order) > 1 || !empty(l:group)
      call add(l:lines, empty(l:group) ? 'Not in a comparison:' : l:group)
    endif
    call extend(l:lines, s:unique(l:groups[l:group]))
  endfor
  return "Diffs open in Vim, one per tab:\n" . join(l:lines, "\n")
        \ . "\nRead a side that is not the work tree with `git show <object>`."
endfunction
