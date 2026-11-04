" The settings: docs/config.md

let s:keys = ['personas', 'rules', 'task-rules', 'repository']

function! prompts#config#home() abort
  return empty($XDG_CONFIG_HOME) ? expand('~/.config') : $XDG_CONFIG_HOME
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
  let l:place = roumail_draft#place(a:bufnr)
  let l:config = {'place': l:place, 'personas': [], 'rules': [], 'hidden': [],
        \ 'task-rules': [], 'repository': {}, 'entries': [], 'errors': []}
  let l:lines = systemlist('git -C ' . shellescape(l:place.dir)
        \ . ' config --show-scope --show-origin --get-regexp ' . shellescape('^vim-prompts\.'))
  " 1: nothing set
  if v:shell_error > 1
    call add(l:config.errors, 'git config: ' . join(l:lines))
    return l:config
  endif
  let l:repository = []
  for l:line in v:shell_error ? [] : l:lines
    let l:m = matchlist(l:line, '^\(\w\+\)\t\(.\{-}\)\tvim-prompts\.\(\S\+\)\(\%( .*\)\=\)$')
    if empty(l:m)
      continue
    endif
    let [l:scope, l:key, l:value] = [l:m[1], l:m[3], l:m[4][1:]]
    let l:file = substitute(l:m[2], '^file:', '', '')
    let l:origin = l:scope . (l:file ==# l:m[2] ? '' : ' ' . fnamemodify(l:file, ':~'))
    let l:where = 'vim-prompts.' . l:key . ' (' . l:origin . ')'
    " As git stores it, and the file that sets it, for :AiUnset: '' for a value
    " given on the command line; git names the repository's own relative to
    " the work tree
    call add(l:config.entries, {'key': l:key, 'value': l:value, 'origin': l:origin,
          \ 'file': l:file ==# l:m[2] ? '' : l:file =~# '^/' ? l:file : l:place.dir . '/' . l:file})
    let l:unset = '; :' . prompts#namespace() . 'Unset ' . l:key . ' removes it'
    if index(s:keys, l:key) < 0
      call add(l:config.errors, l:where . ': unknown key' . l:unset)
    elseif l:key ==# 'repository'
      call add(l:repository, {'value': l:value, 'origin': l:origin, 'where': l:where})
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
      " `git config --global` writes to ~/.gitconfig, not to a file it includes:
      " an included value is the include's, for :AiRule --global to pass over
      call add(l:config[l:key], {l:field : l:path, 'origin': l:origin,
            \ 'scope': l:scope ==# 'global' && index([expand('~/.gitconfig'), prompts#config#home() . '/git/config'],
            \   fnamemodify(l:file, ':p')) < 0 ? 'include' : l:scope})
    endif
  endfor
  " One file describes the repository, set wherever suits (its own config,
  " or a file included for its folder alone): two are a mistake to fix, not
  " a choice to make
  if len(l:repository) > 1
    call add(l:config.errors, 'vim-prompts.repository is set ' . len(l:repository)
          \ . ' times here, once is allowed: '
          \ . join(map(copy(l:repository), {_, r -> (empty(r.value) ? '""' : r.value) . ' (' . r.origin . ')'}), ', ')
          \ . '; :' . prompts#namespace() . 'Unset repository <Tab> removes one')
  elseif !empty(l:repository) && !empty(l:repository[0].value)
    let l:file = prompts#config#path(l:repository[0].value, l:place)
    if !filereadable(l:file)
      call add(l:config.errors, l:repository[0].where . ': no file ' . l:repository[0].value
            \ . '; :' . prompts#namespace() . 'Unset repository removes it')
    else
      let l:config.repository = {'file': l:file, 'origin': l:repository[0].origin}
    endif
  endif
  return l:config
endfunction

function! prompts#config#task_rules(config) abort
  let l:rules = {}
  for l:dir in a:config['task-rules']
    for l:file in sort(glob(l:dir.dir . '/*.md', 1, 1))
      let l:name = fnamemodify(l:file, ':t:r')
      if l:name =~# '^\S\+$'
        let l:rules[l:name] = {'file': l:file, 'origin': l:dir.origin,
              \ 'hides': has_key(l:rules, l:name)
              \   ? l:rules[l:name].hides + [{'file': l:rules[l:name].file, 'origin': l:rules[l:name].origin}] : []}
      endif
    endfor
  endfor
  return l:rules
endfunction

function! prompts#config#rule_names(config) abort
  let l:names = {}
  for l:rule in a:config.rules
    let l:names[fnamemodify(l:rule.file, ':t')] = l:rule.file
  endfor
  return l:names
endfunction

function! prompts#config#text(config, names = [], bare = 0) abort
  let l:blocks = []
  let l:task_rules = prompts#config#task_rules(a:config)
  for [l:heading, l:file] in (a:bare ? [] : map(copy(a:config.rules), '["Rules", v:val.file]')
        \ + (empty(a:config.repository) ? [] : [['About this repository', a:config.repository.file]]))
        \ + map(filter(uniq(map(copy(a:names), {_, n -> substitute(n, '\.md$', '', '')})),
        \   'has_key(l:task_rules, v:val)'), '["Rules for this task", l:task_rules[v:val].file]')
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
