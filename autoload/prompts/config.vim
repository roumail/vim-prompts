" The settings: docs/config.md

let s:keys = ['personas', 'rules', 'library', 'repository']
let s:own_scopes = ['local', 'worktree', 'command']

function! prompts#config#place(bufnr) abort
  for l:gitdir in [FugitiveGitDir(a:bufnr), FugitiveExtractGitDir(getcwd())]
    let l:tree = empty(l:gitdir) ? '' : FugitiveWorkTree(l:gitdir)
    if !empty(l:tree)
      return {'dir': l:tree, 'repo': 1}
    endif
  endfor
  return {'dir': getcwd(), 'repo': 0}
endfunction

function! s:origin(scope, origin) abort
  let l:file = substitute(a:origin, '^file:', '', '')
  return a:scope . (l:file ==# a:origin ? '' : ' ' . fnamemodify(l:file, ':~'))
endfunction

" `git config --global` writes to ~/.gitconfig, not to a file it includes:
" an included value is the include's, for :AiRule --global to pass over
function! s:scope(scope, origin) abort
  let l:file = fnamemodify(substitute(a:origin, '^file:', '', ''), ':p')
  let l:own = [expand('~/.gitconfig'),
        \ (empty($XDG_CONFIG_HOME) ? expand('~/.config') : $XDG_CONFIG_HOME) . '/git/config']
  return a:scope ==# 'global' && index(l:own, l:file) < 0 ? 'include' : a:scope
endfunction

function! prompts#config#path(value, place) abort
  let l:path = expand(a:value)
  return l:path =~# '^/' ? l:path : a:place.dir . '/' . l:path
endfunction

function! prompts#config#show(path, place) abort
  return a:place.repo && stridx(a:path, a:place.dir . '/') == 0
        \ ? strpart(a:path, len(a:place.dir) + 1) : fnamemodify(a:path, ':~')
endfunction

function! prompts#config#get(bufnr) abort
  let l:place = prompts#config#place(a:bufnr)
  let l:config = {'place': l:place, 'personas': [], 'rules': [], 'hidden': [],
        \ 'library': [], 'repository': {}, 'entries': [], 'errors': []}
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
    " As git stores it, and the file that sets it, for :AiUnset
    call add(l:config.entries, {'key': l:key, 'value': l:value, 'origin': l:origin,
          \ 'file': s:file(l:m[2], l:place)})
    let l:unset = '; :' . prompts#namespace() . 'Unset ' . l:key . ' removes it'
    if index(s:keys, l:key) < 0
      call add(l:config.errors, l:where . ': unknown key'
            \ . (l:key ==# 'dir' ? '; name the directory as vim-prompts.personas and the file as vim-prompts.repository' : '')
            \ . l:unset)
    elseif l:key ==# 'repository'
      if index(s:own_scopes, l:scope) < 0
        call add(l:config.errors, l:where . ': describes one repository, so set it in that'
              \ . ' repository: git config vim-prompts.repository <file>' . l:unset)
      elseif empty(l:value)
        let l:config.repository = {}
      elseif !filereadable(prompts#config#path(l:value, l:place))
        call add(l:config.errors, l:where . ': no file ' . l:value . l:unset)
      else
        let l:config.repository = {'file': prompts#config#path(l:value, l:place), 'origin': l:origin}
      endif
    elseif empty(l:value)
      let l:config[l:key] = []
      if l:key ==# 'rules'
        let l:config.hidden = []
      endif
    else
      let l:path = prompts#config#path(l:value, l:place)
      let l:field = l:key ==# 'rules' ? 'file' : 'dir'
      if l:field ==# 'dir' ? !isdirectory(l:path) : !filereadable(l:path)
        call add(l:config.errors, l:where . ': no ' . (l:field ==# 'dir' ? 'directory ' : 'file ')
              \ . l:value . l:unset)
        continue
      endif
      " Named again, it moves to where it is named last
      call filter(l:config[l:key], {_, v -> v[l:field] !=# l:path})
      if l:key ==# 'rules'
        let l:name = fnamemodify(l:path, ':t')
        call filter(l:config.hidden, {_, v -> v.file !=# l:path})
        let l:config.hidden += filter(copy(l:config.rules), {_, v -> fnamemodify(v.file, ':t') ==# l:name})
        call filter(l:config.rules, {_, v -> fnamemodify(v.file, ':t') !=# l:name})
      endif
      call add(l:config[l:key], {l:field : l:path, 'origin': l:origin,
            \ 'scope': s:scope(l:scope, l:m[2])})
    endif
  endfor
  return l:config
endfunction

" The file a value is in, '' for one given on the command line; git names
" the repository's own relative to the work tree
function! s:file(origin, place) abort
  if a:origin !~# '^file:'
    return ''
  endif
  let l:file = a:origin[5:]
  return l:file =~# '^/' ? l:file : a:place.dir . '/' . l:file
endfunction

" Removes a value from the file that sets it, as git stores it (a path as
" written, ~ and all): git config --unset only matches that text
function! prompts#config#unset(entry) abort
  if empty(a:entry.file)
    return 'set on the command line, not in a file'
  endif
  let l:out = system('git config -f ' . shellescape(a:entry.file) . ' --fixed-value --unset-all '
        \ . shellescape('vim-prompts.' . a:entry.key) . ' ' . shellescape(a:entry.value))
  return v:shell_error ? (empty(trim(l:out)) ? 'git config exited ' . v:shell_error : trim(l:out)) : ''
endfunction

" The rules files to ask for by name, #rule:<name>: every .md in the
" vim-prompts.library directories, a later one's hiding an earlier one's
function! prompts#config#library(config) abort
  let l:rules = {}
  for l:library in a:config.library
    for l:file in sort(glob(l:library.dir . '/*.md', 1, 1))
      let l:name = fnamemodify(l:file, ':t:r')
      if l:name =~# '^\S\+$'
        let l:rules[l:name] = {'file': l:file, 'origin': l:library.origin,
              \ 'hides': has_key(l:rules, l:name) ? l:rules[l:name].hides + [l:rules[l:name].file] : []}
      endif
    endfor
  endfor
  return l:rules
endfunction

" A rules file is named by its file name, which hides an earlier one's
function! prompts#config#rule_names(config) abort
  let l:names = {}
  for l:rule in a:config.rules
    let l:names[fnamemodify(l:rule.file, ':t')] = l:rule.file
  endfor
  return l:names
endfunction

" Where a new rules file for a scope goes: outside any repository, so a
" shared one never sees it
function! prompts#config#new_rules(config, scope) abort
  let l:dir = (empty($XDG_CONFIG_HOME) ? expand('~/.config') : $XDG_CONFIG_HOME) . '/vim-prompts'
  if a:scope ==# 'global'
    return l:dir . '/rules.md'
  endif
  " repo/.git, repo/.bare, repo.git
  let l:common = FugitiveCommonDir(FugitiveExtractGitDir(a:config.place.dir))
  let l:repo = l:common =~# '/\.[^/]\+$' ? fnamemodify(l:common, ':h:t')
        \ : fnamemodify(l:common, ':t:s?\.git$??')
  return l:dir . '/repos/' . l:repo
        \ . (a:scope ==# 'worktree' ? '-' . fnamemodify(a:config.place.dir, ':t') : '') . '.md'
endfunction

function! prompts#config#add_rules(config, scope, file) abort
  if !filereadable(a:file)
    call mkdir(fnamemodify(a:file, ':h'), 'p')
    call writefile([], a:file)
  endif
  let l:out = system('git -C ' . shellescape(a:config.place.dir) . ' config --' . a:scope
        \ . ' --add vim-prompts.rules ' . shellescape(fnamemodify(a:file, ':~')))
  return v:shell_error ? trim(l:out) : ''
endfunction

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
