" #commits:<hash>[,<hash>...]: docs/sources/commits.md
function! prompts#sources#commits#info() abort
  return {'needs': 'commits: #commits:<hash>,<hash>', 'arg': 'required'}
endfunction

function! s:git(bufnr, args) abort
  let l:result = FugitiveExecute(a:args, a:bufnr)
  return l:result.exit_status ? v:null : filter(copy(l:result.stdout), '!empty(v:val)')
endfunction

" Completes the last hash of the list, from recent commits
function! prompts#sources#commits#complete(lead) abort
  let [l:done, l:last] = matchlist(a:lead, '^\(.\{-}\)\([^,]*\)$')[1:2]
  let l:log = s:git(bufnr(), ['log', '--format=%h', '-n', '50'])
  return l:log is v:null ? []
        \ : map(filter(l:log, 'stridx(v:val, l:last) == 0'), 'l:done . v:val')
endfunction

" For fzf#vim#complete(): the log of the buffer's repository, to mark
" commits in and insert as one #commits:<hash>,<hash>
function! prompts#sources#commits#fzf() abort
  let l:tree = FugitiveWorkTree(bufnr())
  let l:git = 'git -C ' . shellescape(empty(l:tree) ? getcwd() : l:tree)
  return {'source': l:git . ' log --oneline --color=always',
        \ 'options': ['--multi', '--ansi', '--no-sort', '--prompt', 'Commits> ',
        \   '--preview', l:git . ' show --stat --oneline --color=always {1}',
        \   '--preview-window', 'right:60%:wrap'],
        \ 'reducer': {lines -> '#commits:' . join(map(copy(lines), 'matchstr(v:val, ''^\x\+'')'), ',')},
        \ 'prefix': '$'}
endfunction

" Each hash's subject and files; one that isn't a commit sends nothing
function! prompts#sources#commits#context(request, arg) abort
  let l:lines = []
  for l:hash in uniq(split(a:arg, '[,[:space:]]\+'))
    let l:show = s:git(a:request.bufnr, ['show', '--name-status', '--format=%h %s',
          \ l:hash . '^{commit}', '--'])
    if empty(l:show)
      return ''
    endif
    call add(l:lines, '- ' . l:show[0])
    let l:lines += map(l:show[1:], '"  - " . substitute(v:val, "\t", " ", "g")')
  endfor
  return empty(l:lines) ? ''
        \ : "Commits (hash subject, then status path):\n" . join(l:lines, "\n") . "\n"
        \ . 'Read each with `git show <hash> -- <path>`.'
endfunction
