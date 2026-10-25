" Where the personas, the rules and the repository's description come from:
" git config, read the way git reads it (system, global and the files it
" includes, then the repository's own), so what applies to an ask is what
" `git config --show-origin --get-regexp vim-prompts` lists where it is made.
" No file is read for being in some place; every one is named (docs/config.md).
"
"   vim-prompts.personas    a directory of personas; every value, a later one
"                           winning on a name
"   vim-prompts.rules       a file of rules for every ask; every value, in order
"   vim-prompts.repository  the file that describes this repository; only from
"                           its own config (local, worktree or -c), never shared
"   vim-prompts.requireRepository  a repository must name its file to be asked
"
" An empty personas or rules value drops those before it. Paths are relative
" to the work tree's root, outside a repository the working directory.

let s:keys = ['personas', 'rules', 'repository', 'requirerepository']
" The scopes that are one repository's own
let s:own = ['local', 'worktree', 'command']

" Where an ask from the buffer is made: its repository's work tree, else the
" working directory's, else the working directory. {dir, repo}
function! prompts#config#place(bufnr) abort
  for l:gitdir in [FugitiveGitDir(a:bufnr), FugitiveExtractGitDir(getcwd())]
    let l:tree = empty(l:gitdir) ? '' : FugitiveWorkTree(l:gitdir)
    if !empty(l:tree)
      return {'dir': l:tree, 'repo': 1}
    endif
  endfor
  return {'dir': getcwd(), 'repo': 0}
endfunction

" The file a setting came from, for messages: `global ~/.gitconfig`
function! s:origin(scope, origin) abort
  let l:file = substitute(a:origin, '^file:', '', '')
  return a:scope . (l:file ==# a:origin ? '' : ' ' . fnamemodify(l:file, ':~'))
endfunction

function! s:path(value, place) abort
  let l:path = expand(a:value)
  return l:path =~# '^/' ? l:path : a:place.dir . '/' . l:path
endfunction

" A path as the prompt shows it: from the work tree's root inside it
function! prompts#config#show(path, place) abort
  return a:place.repo && stridx(a:path, a:place.dir . '/') == 0
        \ ? strpart(a:path, len(a:place.dir) + 1) : fnamemodify(a:path, ':~')
endfunction

" What applies to an ask from the buffer: {place, personas: [{dir, origin}],
" rules: [{file, origin}], repository: {file, origin} or {}, required: the
" origin of requireRepository or '', errors}
function! prompts#config#get(bufnr) abort
  let l:place = prompts#config#place(a:bufnr)
  let l:config = {'place': l:place, 'personas': [], 'rules': [],
        \ 'repository': {}, 'required': '', 'errors': []}
  let l:lines = systemlist('git -C ' . shellescape(l:place.dir)
        \ . ' config --show-scope --show-origin --get-regexp ' . shellescape('^vim-prompts\.'))
  " 1: nothing set
  if v:shell_error > 1
    call add(l:config.errors, 'git config: ' . join(l:lines))
    return l:config
  endif
  for l:line in v:shell_error ? [] : l:lines
    let l:m = matchlist(l:line, '^\(\w\+\)\t\(.\{-}\)\tvim-prompts\.\(\S\+\)\(\%( .*\)\=\)$')
    if empty(l:m)
      continue
    endif
    let [l:scope, l:key, l:value] = [l:m[1], l:m[3], l:m[4][1:]]
    let l:origin = s:origin(l:scope, l:m[2])
    let l:where = 'vim-prompts.' . l:key . ' (' . l:origin . ')'
    if index(s:keys, l:key) < 0
      call add(l:config.errors, l:where . ': unknown key'
            \ . (l:key ==# 'dir' ? '; name the directory as vim-prompts.personas and the file as vim-prompts.repository' : ''))
    elseif l:key ==# 'requirerepository'
      " `requireRepository` alone is true, as in git
      let l:on = empty(l:m[4]) || l:value =~? '^\%(true\|yes\|on\|1\)$'
      if !l:on && l:value !~? '^\%(false\|no\|off\|0\|\)$'
        call add(l:config.errors, l:where . ': true or false, not ' . l:value)
      endif
      let l:config.required = l:on ? l:origin : ''
    elseif l:key ==# 'repository'
      if index(s:own, l:scope) < 0
        call add(l:config.errors, l:where . ': describes one repository, so set it in that'
              \ . ' repository: git config vim-prompts.repository <file>')
      elseif empty(l:value)
        let l:config.repository = {}
      elseif !filereadable(s:path(l:value, l:place))
        call add(l:config.errors, l:where . ': no file ' . l:value)
      else
        let l:config.repository = {'file': s:path(l:value, l:place), 'origin': l:origin}
      endif
    elseif empty(l:value)
      let l:config[l:key] = []
    else
      let l:path = s:path(l:value, l:place)
      let l:field = l:key ==# 'personas' ? 'dir' : 'file'
      if l:key ==# 'personas' ? !isdirectory(l:path) : !filereadable(l:path)
        call add(l:config.errors, l:where . ': no ' . (l:key ==# 'personas' ? 'directory ' : 'file ') . l:value)
        continue
      endif
      " Named again, it moves to where it is named last
      call filter(l:config[l:key], {_, v -> v[l:field] !=# l:path})
      call add(l:config[l:key], {l:field : l:path, 'origin': l:origin})
    endif
  endfor
  return l:config
endfunction

" What the repository lacks for an ask, '' when nothing
function! prompts#config#missing(config) abort
  if !a:config.place.repo || empty(a:config.required) || !empty(a:config.repository)
    return ''
  endif
  return 'this repository names no file describing it, which ' . a:config.required
        \ . ' requires: git config vim-prompts.repository <file>'
endfunction

" The rules and the repository's description, for {repository}: general to
" specific, the later winning where they differ
function! prompts#config#text(config) abort
  let l:blocks = []
  for [l:heading, l:file] in map(copy(a:config.rules), '["Rules", v:val.file]')
        \ + (empty(a:config.repository) ? [] : [['About this repository', a:config.repository.file]])
    let l:text = trim(join(readfile(l:file), "\n"))
    if !empty(l:text)
      call add(l:blocks, l:heading . ' (' . prompts#config#show(l:file, a:config.place) . "):\n\n" . l:text)
    endif
  endfor
  if len(l:blocks) > 1
    call insert(l:blocks, 'What follows goes from the most general to the most specific:'
          \ . ' where two parts differ, follow the later one.')
  endif
  return join(l:blocks, "\n\n")
endfunction
