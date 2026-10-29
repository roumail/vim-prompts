function! prompts#namespace() abort
  let l:ns = get(g:, 'prompts_namespace', 'Ai')
  return toupper(l:ns[0]) . l:ns[1:]
endfunction

function! s:error(msg) abort
  echohl ErrorMsg
  echomsg 'vim-prompts: ' . a:msg
  echohl None
endfunction

" ---------------------------------------------------------------------------
" Grammar (docs/usage.md)

function! s:files(path) abort
  if empty(a:path)
    let l:tree = FugitiveWorkTree()
    return {'files': [], 'pick': [empty(l:tree) ? getcwd() : l:tree]}
  endif
  let l:path = expand(escape(a:path, '*?[]'))
  if isdirectory(l:path)
    return {'files': [], 'pick': [fnamemodify(l:path, ':p:h')]}
  endif
  " glob() expands ~ and $VARS too
  let l:files = filter(glob(a:path, 1, 1), 'filereadable(v:val)')
  if empty(l:files)
    call s:error('@' . a:path . ': no such file')
    return {}
  endif
  return {'files': map(l:files, 'fnamemodify(v:val, ":p")'), 'pick': []}
endfunction

function! s:parse(args) abort
  let [l:_, l:start, l:end] = matchstrpos(a:args, '\%(^\|\s\)--\%(\s\|$\)')
  let l:head = l:start < 0 ? a:args : strpart(a:args, 0, l:start)
  let l:words = []
  let l:pos = 0
  while 1
    let [l:word, l:s, l:pos] = matchstrpos(l:head, '[#@]\%(\h\w*:\)\="[^"]*"\|\S\+', l:pos)
    if l:s < 0
      break
    endif
    call add(l:words, l:word)
  endwhile
  let l:parsed = {'persona': 'default', 'given': [], 'files': [], 'pick': [], 'mode': '',
        \ 'bare': 0, 'query': []}
  if get(l:words, 0, '') =~# '^/\a[[:alnum:]_-]*$'
    let l:parsed.persona = remove(l:words, 0)[1:]
  endif
  for l:word in l:words
    let l:word = substitute(l:word, '^\([#@]\%(\h\w*:\)\=\)"\(.*\)"$', '\1\2', '')
    if l:word =~# '^#\h'
      let l:source = prompts#source#parse(l:word[1:])
      if has_key(l:source, 'error')
        call s:error(l:source.error . '; text after -- is taken as is')
        return {}
      endif
      call add(l:parsed.given, l:source)
    elseif l:word =~# '^@'
      let l:found = s:files(l:word[1:])
      if empty(l:found)
        return {}
      endif
      let l:parsed.files += l:found.files
      let l:parsed.pick += l:found.pick
    elseif l:word =~# '^--\%(ask\|plan\|agent\|auto\)-mode$'
      let l:parsed.mode = matchstr(l:word, '\a\+', 2)
    elseif l:word ==# '--bare'
      let l:parsed.bare = 1
    else
      call add(l:parsed.query, l:word)
    endif
  endfor
  if len(l:parsed.pick) > 1
    call s:error('one @ to pick files with, per ask')
    return {}
  endif
  if l:start >= 0
    call add(l:parsed.query, trim(a:args[l:end :]))
  endif
  let l:parsed.query = trim(join(l:parsed.query))
  return l:parsed
endfunction

" ---------------------------------------------------------------------------
" The request

function! s:request(range, line1, line2, query, sources, config) abort
  let l:request = {'query': a:query, 'sources': a:sources, 'dirs': [],
        \ 'bufnr': bufnr(), 'line': a:range ? a:line1 : line('.'),
        \ 'range': a:range, 'line1': a:line1, 'line2': a:line2,
        \ 'selection': [], 'charwise': 0, 'context': {},
        \ 'rules': prompts#config#text(a:config)}
  return a:range ? extend(l:request, s:selection(a:line1, a:line2)) : l:request
endfunction

function! s:selection(line1, line2) abort
  let l:mode = visualmode()
  if l:mode !=# 'V' && !empty(l:mode)
        \ && a:line1 == line("'<") && a:line2 == line("'>")
    return {'selection': getregion(getpos("'<"), getpos("'>"), {'type': l:mode}), 'charwise': 1}
  endif
  return {'selection': getline(a:line1, a:line2), 'charwise': 0}
endfunction

function! s:add_files(request, files) abort
  if empty(a:files)
    return
  endif
  call add(a:request.sources, {'name': 'files', 'arg': join(uniq(copy(a:files)), "\n")})
  let l:tree = FugitiveWorkTree(a:request.bufnr)
  for l:file in a:files
    if empty(l:tree) || stridx(l:file, l:tree . '/') != 0
      call add(a:request.dirs, fnamemodify(l:file, ':h'))
    endif
  endfor
  call uniq(sort(a:request.dirs))
endfunction

function! s:missing(persona, request, given) abort
  for l:source in a:given
    if empty(prompts#source#context(l:source, a:request))
      return '#' . l:source.name . ' has nothing: needs '
            \ . prompts#source#info(l:source.name).needs
    endif
  endfor
  " Instructions (how to work: a rule, where to write) aren't something to
  " work on, so they don't count
  let l:own = filter(copy(a:persona.meta.context),
        \ '!get(prompts#source#info(v:val.name), "instruction", 0)')
  if empty(l:own) || !empty(a:request.selection)
    return ''
  endif
  for l:source in a:request.sources
    if !get(prompts#source#info(l:source.name), 'instruction', 0)
          \ && !empty(prompts#source#context(l:source, a:request))
      return ''
    endif
  endfor
  return '/' . a:persona.name . ' needs '
        \ . join(map(copy(l:own), 'prompts#source#info(v:val.name).needs'), ', or ')
endfunction

function! s:prompt(bang, range, line1, line2, args, Then) abort
  let l:parsed = s:parse(a:args)
  if empty(l:parsed)
    return
  endif
  let l:config = prompts#config#get(bufnr())
  if !empty(l:config.errors)
    call map(l:config.errors, 's:error(v:val)')
    return
  endif
  let l:persona = prompts#persona#get(l:parsed.persona, l:config)
  if empty(l:persona)
    return
  endif
  if !empty(l:parsed.mode)
    let l:persona.meta.mode = l:parsed.mode
  endif
  let l:sources = copy(l:persona.meta.context)
  for l:source in l:parsed.given
    if index(l:sources, l:source) < 0
      call add(l:sources, l:source)
    endif
  endfor
  let l:request = s:request(a:range, a:line1, a:line2, l:parsed.query, l:sources, l:config)
  " #rule's text goes last in {rules}, so the persona and the query still
  " come after it; a persona with {rule} places it itself
  if stridx(join(l:persona.template, "\n"), '{rule}') < 0
    let l:names = map(filter(copy(l:sources), 'v:val.name ==# "rule"'), 'v:val.arg')
    let l:request.rules = prompts#config#text(l:config, l:names, l:parsed.bare)
  elseif l:parsed.bare
    let l:request.rules = ''
  endif
  let l:Finish = {files -> s:finish(a:bang, l:persona, l:request, l:parsed,
        \ l:parsed.files + files, a:Then)}
  if empty(l:parsed.pick)
    call l:Finish([])
  elseif empty(get(g:, 'prompts_file_picker', ''))
    call s:error('@ without a file needs g:prompts_file_picker (docs/sources/files.md)')
  else
    " The picker may call back at once, or later (fzf runs in a terminal)
    call call(g:prompts_file_picker, [l:parsed.pick[0], l:Finish])
  endif
endfunction

function! s:finish(bang, persona, request, parsed, files, Then) abort
  call s:add_files(a:request, a:files)
  if !a:bang
    let l:missing = s:missing(a:persona, a:request, a:parsed.given)
    if !empty(l:missing)
      call s:error(l:missing . ' (! asks anyway)')
      return
    endif
  endif
  call a:Then(a:persona, a:request, prompts#template#render(a:persona.template, a:request))
endfunction

" ---------------------------------------------------------------------------
" Commands

" :[range]Ai[!] [/persona] [#source...] [@path...] [--<mode>-mode] [--bare]
" [query] [-- text]. With nothing (or only a mode, or --bare), opens the
" agent bare, or focuses the bare session already running.
function! prompts#ask(bang, range, line1, line2, args) abort
  if a:args =~# '^\%(\s*--\%(\%(ask\|plan\|agent\|auto\)-mode\|bare\)\)*\s*$' && !a:range
    call prompts#agent#launch('', {'mode': matchstr(a:args, '--\zs\a\+\ze-mode')}, [])
    return
  endif
  call s:prompt(a:bang, a:range, a:line1, a:line2, a:args, function('s:ask'))
endfunction

" Without a query, the default persona sends the context for the agent to
" take in, and you ask in the session; other personas have their own task
function! s:ask(persona, request, prompt) abort
  let l:prompt = a:prompt
  " Nothing rendered (`:Ai /default --bare`): the agent opens bare
  if empty(trim(l:prompt))
    call prompts#agent#launch('', a:persona.meta, a:request.dirs)
    return
  endif
  if a:persona.name ==# 'default' && empty(a:request.query)
    let l:prompt .= "\n\nRead this, then wait for my question."
  endif
  call prompts#agent#launch(l:prompt, a:persona.meta, a:request.dirs)
endfunction

" :[range]AiDraft[!] ...: the same prompt in a buffer to edit; :w sends it
" and leaves it open, :wq sends it and closes it, :q! drops it
function! prompts#draft(bang, range, line1, line2, args) abort
  call s:prompt(a:bang, a:range, a:line1, a:line2, a:args, function('s:open_draft'))
endfunction

function! s:open_draft(persona, request, prompt) abort
  let l:command = prompts#agent#command(a:persona.meta, a:request.dirs)
  botright vnew
  setlocal buftype=acwrite bufhidden=wipe noswapfile filetype=markdown
  execute 'silent file' fnameescape('ai-draft://' . a:persona.name . '/' . bufnr())
  call setline(1, split(a:prompt, "\n", 1))
  call s:fold_rules(a:prompt, a:request.rules)
  if empty(a:request.query)
    " Room for the query, last
    call append('$', ['', ''])
  endif
  normal! G
  setlocal nomodified
  let b:prompts_draft = {'meta': a:persona.meta, 'request': a:request}
  let &l:statusline = '%f  ' . (empty(l:command) ? '(no agent)'
        \ : substitute(join(l:command[1] + ['<this>'] + l:command[2]), '%', '%%', 'g'))
        \ . '%=:w sends, :wq sends and closes, :q! drops '
  augroup prompts_draft
    autocmd! * <buffer>
    autocmd BufWriteCmd <buffer> call s:send_draft()
  augroup END
endfunction

" The rules, the same in every draft, folded so the query stands out; they
" are sent all the same
function! s:fold_rules(prompt, rules) abort
  " As prompts#template#render() leaves them: no runs of blank lines
  let l:rules = trim(substitute(a:rules, '\n\s*\n\%(\s*\n\)\+', "\n\n", 'g'))
  let l:start = empty(l:rules) ? -1 : stridx(a:prompt, l:rules)
  if l:start < 0
    return
  endif
  let l:first = count(strpart(a:prompt, 0, l:start), "\n") + 1
  setlocal foldmethod=manual foldenable foldminlines=0
  let &l:foldtext = '"+-- " . (v:foldend - v:foldstart + 1) . " lines of rules, sent with the draft (zo shows them) "'
  execute l:first . ',' . (l:first + count(l:rules, "\n")) . 'fold'
endfunction

function! s:send_draft() abort
  let l:prompt = trim(join(getline(1, '$'), "\n"))
  if empty(l:prompt)
    call s:error('the draft is empty')
    return
  endif
  " Left open: :wq sends and closes, :w sends again after more edits
  setlocal nomodified
  " Once the write is done: the agent's tab would otherwise be the window
  " :wq goes on to close (and :wq wipes the draft, b: with it)
  let l:draft = b:prompts_draft
  call timer_start(0, {-> prompts#agent#launch(l:prompt, l:draft.meta,
        \ l:draft.request.dirs)})
endfunction

" /personas first; #sources, @files and the mode anywhere before --
function! prompts#complete(lead, cmdline, pos) abort
  if a:cmdline[: a:pos - 1] =~# '\s--\s'
    return []
  elseif a:lead =~# '^#\h\w*:'
    let [l:name, l:arg] = matchlist(a:lead, '^#\(\h\w*\):\(.*\)')[1:2]
    return prompts#source#exists(l:name) && exists('*prompts#sources#' . l:name . '#complete')
          \ ? map(call('prompts#sources#' . l:name . '#complete', [l:arg]),
          \   {_, a -> '#' . l:name . ':' . a})
          \ : []
  elseif a:lead =~# '^#'
    let l:names = filter(prompts#source#names(), 'v:val !=# "files"')
    return filter(map(l:names, {_, n -> '#' . n
          \ . (prompts#source#info(n).arg ==# 'required' ? ':' : '')}),
          \ 'stridx(v:val, a:lead) == 0')
  elseif a:lead =~# '^@'
    return map(getcompletion(a:lead[1:], 'file'), '"@" . v:val')
  elseif a:lead =~# '^-'
    return filter(['--agent-mode', '--ask-mode', '--auto-mode', '--bare', '--plan-mode'], 'stridx(v:val, a:lead) == 0')
  elseif a:lead =~# '^/' && a:cmdline[: a:pos - 1] =~# '^\S*\s\+\S*$'
    return filter(map(prompts#persona#names(prompts#config#get(bufnr())), '"/" . v:val'),
          \ 'stridx(v:val, a:lead) == 0')
  endif
  return []
endfunction

" :AiPersonas[!]: the personas that apply here, the context each asks for
" and where it comes from. With !, reload the source files first.
function! prompts#list(reload) abort
  if a:reload
    call prompts#source#load()
  endif
  let l:config = prompts#config#get(bufnr())
  call s:list_errors(l:config.errors + prompts#persona#errors(l:config))
  for l:name in prompts#persona#names(l:config)
    let l:persona = prompts#persona#get(l:name, l:config)
    if empty(l:persona)
      continue
    endif
    let l:own = l:persona.meta.context
    let l:request = s:request(0, line('.'), line('.'), '', copy(l:own), l:config)
    let l:missing = s:missing(l:persona, l:request, [])
    call s:entry('Identifier', '/' . l:name,
          \ [fnamemodify(l:persona.file, ':~'), 'loaded', s:persona_source(l:persona)]
          \ + (empty(l:own) ? [] : [join(map(copy(l:own), '"#" . v:val.name . (empty(v:val.arg) ? "" : ":" . v:val.arg)'))])
          \ + map(copy(l:persona.bases), '"on {base} " . fnamemodify(v:val, ":~")')
          \ + (empty(l:missing) ? [] : [l:missing]))
    for l:hidden in prompts#persona#hidden(l:persona, l:config)
      call s:entry('Comment', '/' . l:name,
            \ [fnamemodify(l:hidden.file, ':~'), 'hidden by ' . fnamemodify(l:persona.file, ':~'),
            \  s:persona_source(l:hidden)])
    endfor
  endfor
endfunction

function! s:persona_source(persona) abort
  return a:persona.source ==# 'bundled' ? 'from vim-prompts, bundled' : 'from vim-prompts.personas, ' . a:persona.source
endfunction

" :AiRules: the rules files that apply here, in the order they are sent,
" those a later one of their name hides, and those #rule asks for
function! prompts#rules() abort
  let l:config = prompts#config#get(bufnr())
  call s:list_errors(l:config.errors)
  call s:list_rules(l:config)
endfunction

function! s:list_errors(errors) abort
  echohl ErrorMsg
  for l:error in a:errors
    echo l:error
  endfor
  echohl None
endfunction

function! s:list_rules(config) abort
  let l:place = a:config.place
  for l:rule in a:config.rules
    call s:entry('Identifier', fnamemodify(l:rule.file, ':t'),
          \ [prompts#config#show(l:rule.file, l:place), 'loaded', 'from vim-prompts.rules, ' . l:rule.origin])
  endfor
  if !empty(a:config.repository)
    call s:entry('Identifier', 'repository',
          \ [prompts#config#show(a:config.repository.file, l:place), 'loaded',
          \  'from vim-prompts.repository, ' . a:config.repository.origin])
  endif
  let l:names = prompts#config#rule_names(a:config)
  for l:rule in a:config.hidden
    let l:name = fnamemodify(l:rule.file, ':t')
    call s:entry('Comment', l:name,
          \ [prompts#config#show(l:rule.file, l:place), 'hidden by ' . prompts#config#show(l:names[l:name], l:place),
          \  'from vim-prompts.rules, ' . l:rule.origin])
  endfor
  " Sent only when asked for
  let l:library = prompts#config#library(a:config)
  for l:name in sort(keys(l:library))
    let l:rule = l:library[l:name]
    call s:entry('Identifier', '#rule:' . l:name,
          \ [prompts#config#show(l:rule.file, l:place), 'loaded', 'from vim-prompts.library, ' . l:rule.origin])
    for l:hidden in l:rule.hides
      call s:entry('Comment', '#rule:' . l:name,
            \ [prompts#config#show(l:hidden.file, l:place), 'hidden by ' . prompts#config#show(l:rule.file, l:place),
            \  'from vim-prompts.library, ' . l:hidden.origin])
    endfor
  endfor
endfunction

" A name, then each of its lines on a line of its own: paths too long for
" columns. A hidden one is dimmed throughout.
function! s:entry(group, name, lines) abort
  execute 'echohl' a:group
  echo a:name
  if a:group !=# 'Comment'
    echohl None
  endif
  for l:line in a:lines
    echo '  ' . l:line
  endfor
  echohl None
endfunction

" :[range]AiRule {file|--global|--local|--worktree} [text]: open a rules file
" that applies here, the text and the selection appended. A scope with none
" gets a new one, named in its git config.
function! prompts#rule(range, line1, line2, args) abort
  let [l:target, l:text] = matchlist(a:args, '^\s*\(\S*\)\s*\(.\{-}\)\s*$')[1:2]
  let l:config = prompts#config#get(bufnr())
  if !empty(l:config.errors)
    call map(l:config.errors, 's:error(v:val)')
    return
  endif
  let l:names = prompts#config#rule_names(l:config)
  if l:target =~# '^--\%(global\|local\|worktree\)$'
    let l:scope = l:target[2:]
    let l:file = get(filter(copy(l:config.hidden) + copy(l:config.rules), 'v:val.scope ==# l:scope'),
          \ -1, {'file': ''}).file
    if empty(l:file)
      let l:file = s:new_rules(l:config, l:scope)
    endif
  elseif has_key(l:names, l:target)
    let l:file = l:names[l:target]
  else
    call s:error((empty(l:target) ? '' : l:target . ': not a rules file here; ')
          \ . 'name one (<Tab>), or --global, --local or --worktree')
    return
  endif
  if empty(l:file)
    return
  endif
  let l:lines = (empty(l:text) ? [] : [l:text])
        \ + (a:range ? s:selection(a:line1, a:line2).selection : [])
  let l:win = bufwinid(l:file)
  if l:win > 0
    call win_gotoid(l:win)
  else
    execute 'botright vsplit' fnameescape(l:file)
  endif
  if !empty(l:lines)
    if line('$') == 1 && empty(getline(1))
      call setline(1, l:lines)
    else
      call append('$', l:lines)
    endif
  endif
  normal! G
endfunction

function! s:new_rules(config, scope) abort
  if a:scope !=# 'global' && !a:config.place.repo
    call s:error('--' . a:scope . ': not in a repository')
    return ''
  endif
  let l:file = input('New ' . a:scope . ' rules file: ',
        \ fnamemodify(prompts#config#new_rules(a:config, a:scope), ':~'), 'file')
  redraw
  if empty(trim(l:file))
    return ''
  endif
  let l:file = fnamemodify(expand(trim(l:file)), ':p')
  let l:error = prompts#config#add_rules(a:config, a:scope, l:file)
  if !empty(l:error)
    call s:error('git config --' . a:scope . ': ' . l:error)
    return ''
  endif
  echomsg 'vim-prompts: vim-prompts.rules ' . fnamemodify(l:file, ':~') . ' (' . a:scope . ')'
  return l:file
endfunction

" The rules files that apply here, and the scopes
function! prompts#rule_complete(lead, cmdline, pos) abort
  if a:cmdline[: a:pos - 1] !~# '^\S*\s\+\S*$'
    return []
  endif
  let l:config = prompts#config#get(bufnr())
  return filter(sort(keys(prompts#config#rule_names(l:config)))
        \ + ['--global'] + (l:config.place.repo ? ['--local', '--worktree'] : []),
        \ 'stridx(v:val, a:lead) == 0')
endfunction

" :AiUnset {key} [value]: remove a value from the file that sets it. Without
" a value, the key's only one; of several the same, the last, which applies.
" "" is the empty value.
function! prompts#unset(args) abort
  let [l:key, l:value] = matchlist(a:args, '^\s*\(\S*\)\s*\(.\{-}\)\s*$')[1:2]
  let l:config = prompts#config#get(bufnr())
  let l:entries = filter(copy(l:config.entries), 'v:val.key ==# l:key')
  if empty(l:entries)
    call s:error('vim-prompts.' . l:key . ' is not set here')
    return
  endif
  if empty(l:value)
    if len(uniq(sort(map(copy(l:entries), 'v:val.value')))) > 1
      call s:error('vim-prompts.' . l:key . ' has several values: name one (<Tab>)')
      return
    endif
  else
    let l:value = l:value ==# '""' ? '' : l:value
    let l:path = s:value_path(l:value, l:config)
    " A rules file also by its file name, as :AiRules shows it
    call filter(l:entries, {_, e -> e.value ==# l:value
          \ || !empty(l:path) && s:value_path(e.value, l:config) ==# l:path
          \ || l:key ==# 'rules' && l:value !~# '/' && fnamemodify(e.value, ':t') ==# l:value})
    if empty(l:entries)
      call s:error('vim-prompts.' . l:key . ' ' . l:value . ': not set here')
      return
    endif
  endif
  let l:entry = l:entries[-1]
  let l:error = prompts#config#unset(l:entry)
  if !empty(l:error)
    call s:error('vim-prompts.' . l:key . ' (' . l:entry.origin . '): ' . l:error)
    return
  endif
  echomsg 'vim-prompts: unset vim-prompts.' . l:key . ' '
        \ . (empty(l:entry.value) ? '""' : l:entry.value) . ' (' . l:entry.origin . ')'
endfunction

" A value as the path it names, so ~/x and /home/me/x are the same
function! s:value_path(value, config) abort
  return empty(a:value) ? '' : fnamemodify(prompts#config#path(a:value, a:config.place), ':p')
endfunction

" The keys set here, then their values as set
function! prompts#unset_complete(lead, cmdline, pos) abort
  let l:before = a:cmdline[: a:pos - 1]
  let l:entries = prompts#config#get(bufnr()).entries
  if l:before =~# '^\S*\s\+\S*$'
    return filter(uniq(sort(map(l:entries, 'v:val.key'))), 'stridx(v:val, a:lead) == 0')
  endif
  let l:key = matchstr(l:before, '^\S*\s\+\zs\S\+')
  return filter(uniq(sort(map(filter(l:entries, 'v:val.key ==# l:key'),
        \ 'empty(v:val.value) ? ''""'' : v:val.value'))), 'stridx(v:val, a:lead) == 0')
endfunction
