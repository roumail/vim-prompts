" #changes[:scope]: docs/sources/changes.md
function! prompts#sources#changes#info() abort
  return {'needs': 'changes (on this branch; #changes:staged; #changes:<branch>)', 'arg': 'optional'}
endfunction

function! s:git(bufnr, args) abort
  let l:result = FugitiveExecute(a:args, a:bufnr)
  return l:result.exit_status ? v:null : filter(copy(l:result.stdout), '!empty(v:val)')
endfunction

function! prompts#sources#changes#context(request, arg) abort
  if a:arg ==# 'staged'
    let [l:args, l:what] = [['--cached'], 'Staged changes']
  else
    let l:branch = empty(a:arg) ? 'HEAD' : a:arg
    if s:git(a:request.bufnr, ['rev-parse', '--verify', '--quiet', l:branch . '^{commit}']) is v:null
      return ''
    endif
    let l:main = fugitive_extras#main_ref()
    let l:base = empty(l:main) ? v:null : s:git(a:request.bufnr, ['merge-base', l:branch, l:main])
    if empty(l:base)
      " No default branch to fork from: what isn't committed, or the branch's
      " last commit
      let [l:args, l:what] = empty(a:arg) ? [['HEAD'], 'Uncommitted changes']
            \ : [[l:branch . '^', l:branch], 'Changes in the last commit of ' . l:branch]
    elseif empty(a:arg) && l:base[0] ==# s:git(a:request.bufnr, ['rev-parse', 'HEAD'])[0]
      " No commits of its own (the default branch itself)
      let [l:args, l:what] = [['HEAD'], 'Uncommitted changes']
    else
      let l:base = l:base[0][:6]
      let [l:args, l:what] = empty(a:arg)
            \ ? [[l:base], 'Changes on this branch since it forked from ' . l:main
            \   . ' at ' . l:base . ', committed or not']
            \ : [[l:base, l:branch], 'Changes on ' . l:branch . ' since it forked from '
            \   . l:main . ' at ' . l:base . ' (not checked out)']
    endif
  endif
  let l:files = s:git(a:request.bufnr, ['diff', '--name-status'] + l:args)
  let l:files = l:files is v:null ? [] : map(l:files, '"- " . substitute(v:val, "\t", " ", "g")')
  if empty(a:arg)
    let l:new = s:git(a:request.bufnr, ['ls-files', '--others', '--exclude-standard'])
    let l:files += l:new is v:null ? [] : map(l:new, '"- ? " . v:val')
  endif
  if empty(l:files)
    return ''
  endif
  return l:what . " (status, path):\n" . join(l:files, "\n") . "\n"
        \ . 'Read each with `git diff ' . join(l:args) . ' -- <path>`'
        \ . (empty(a:arg) ? '; a `?` file is new and untracked, read it as it is.' : '.')
endfunction
