" #changes[:scope]: the files a change touches, from git, and the git diff to
" read each with. The scopes are git-extras' :BranchDiff's: without one, the
" branch's changes, committed or not (the merge-base with the default branch
" against the work tree, plus untracked files), which on the default branch
" is what isn't committed; `staged`, the index against HEAD; a branch name,
" that branch's commits, without checking it out.
function! prompts#sources#changes#info() abort
  return {'needs': 'changes (on this branch; #changes:staged; #changes:<branch>)', 'arg': 'optional'}
endfunction

" stdout lines, or v:null when git fails
function! s:git(bufnr, args) abort
  let l:result = FugitiveExecute(a:args, a:bufnr)
  return l:result.exit_status ? v:null : filter(copy(l:result.stdout), '!empty(v:val)')
endfunction

" [diff args, what they are], or [] when the scope isn't one
function! s:scope(bufnr, scope) abort
  if a:scope ==# 'staged'
    return [['--cached'], 'Staged changes']
  endif
  let l:branch = empty(a:scope) ? 'HEAD' : a:scope
  if s:git(a:bufnr, ['rev-parse', '--verify', '--quiet', l:branch . '^{commit}']) is v:null
    return []
  endif
  let l:main = git_extras#main_ref()
  let l:base = empty(l:main) ? v:null : s:git(a:bufnr, ['merge-base', l:branch, l:main])
  if empty(l:base)
    " No default branch to fork from: what isn't committed, or the branch's
    " last commit
    return empty(a:scope) ? [['HEAD'], 'Uncommitted changes']
          \ : [[l:branch . '^', l:branch], 'Changes in the last commit of ' . l:branch]
  endif
  if empty(a:scope) && l:base[0] ==# s:git(a:bufnr, ['rev-parse', 'HEAD'])[0]
    " No commits of its own (the default branch itself)
    return [['HEAD'], 'Uncommitted changes']
  endif
  let l:base = l:base[0][:6]
  return empty(a:scope)
        \ ? [[l:base], 'Changes on this branch since it forked from ' . l:main
        \   . ' at ' . l:base . ', committed or not']
        \ : [[l:base, l:branch], 'Changes on ' . l:branch . ' since it forked from '
        \   . l:main . ' at ' . l:base . ' (not checked out)']
endfunction

function! prompts#sources#changes#context(request, arg) abort
  let l:scope = s:scope(a:request.bufnr, a:arg)
  if empty(l:scope)
    return ''
  endif
  let [l:args, l:what] = l:scope
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
