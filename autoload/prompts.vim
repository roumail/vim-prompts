function! prompts#namespace() abort
  let l:ns = get(g:, 'prompts_namespace', 'Ai')
  return toupper(l:ns[0]) . l:ns[1:]
endfunction

function! prompts#error(msg) abort
  echohl ErrorMsg
  echomsg 'vim-prompts: ' . a:msg
  echohl None
endfunction

function! s:config(bufnr) abort
  let l:config = prompts#config#get(a:bufnr)
  call map(copy(l:config.errors), 'prompts#error(v:val)')
  return empty(l:config.errors) ? l:config : {}
endfunction

function! s:key_and_rest(args) abort
  return matchlist(a:args, '^\s*\(\S*\)\s*\(.\{-}\)\s*$')[1:2]
endfunction

" Where an ask comes from, taken when it is made: a draft is sent later
function! s:from(range, line1, line2) abort
  let l:from = {'bufnr': bufnr(), 'line': a:range ? a:line1 : line('.'),
        \ 'range': a:range, 'line1': a:line1, 'line2': a:line2,
        \ 'selection': [], 'charwise': 0}
  return a:range ? extend(l:from, s:selection(a:line1, a:line2)) : l:from
endfunction

function! s:request(from, query, sources, config) abort
  return extend({'query': a:query, 'sources': a:sources, 'dirs': [], 'context': {},
        \ 'rules': prompts#config#text(a:config)}, a:from)
endfunction

function! s:selection(line1, line2) abort
  let l:mode = visualmode()
  if l:mode !=# 'V' && !empty(l:mode)
        \ && a:line1 == line("'<") && a:line2 == line("'>")
    return {'selection': getregion(getpos("'<"), getpos("'>"), {'type': l:mode}), 'charwise': 1}
  endif
  return {'selection': getline(a:line1, a:line2), 'charwise': 0}
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

" 1 once the ask is under way, 0 when it stopped at an error. A draft's
" lines after its first come as {rest}, and are taken as written
function! s:prompt(from, args, Then, ...) abort
  let l:rest = get(a:, 1, '')
  let [l:_, l:start, l:end] = matchstrpos(a:args, '\%(^\|\_s\)--\%(\_s\|$\)')
  let l:head = l:start < 0 ? a:args : strpart(a:args, 0, l:start)
  let l:words = []
  let l:pos = 0
  while 1
    let [l:word, l:s, l:pos] = matchstrpos(l:head, '[#@]\%(\h\w*:\)\="[^"]*"\|[^[:space:]]\+', l:pos)
    if l:s < 0
      break
    endif
    call add(l:words, [l:word, l:s, l:pos])
  endwhile
  let l:parsed = {'persona': 'default', 'given': [], 'files': [], 'pick': [], 'mode': '',
        \ 'bare': 0, 'query': ''}
  let l:taken = []
  if get(get(l:words, 0, []), 0, '') =~# '^/\a[[:alnum:]_-]*$'
    let l:parsed.persona = l:words[0][0][1:]
    call add(l:taken, remove(l:words, 0))
  endif
  for [l:word, l:s, l:e] in l:words
    call add(l:taken, [l:word, l:s, l:e])
    let l:word = substitute(l:word, '^\([#@]\%(\h\w*:\)\=\)"\(.*\)"$', '\1\2', '')
    if l:word =~# '^#\h'
      let l:source = prompts#source#parse(l:word[1:])
      if has_key(l:source, 'error')
        call prompts#error(l:source.error . '; text after -- is taken as is')
        return 0
      endif
      call add(l:parsed.given, l:source)
    elseif l:word =~# '^@'
      let l:path = l:word[1:]
      let l:dir = expand(escape(l:path, '*?[]'))
      if empty(l:path)
        let l:tree = FugitiveWorkTree(a:from.bufnr)
        call add(l:parsed.pick, empty(l:tree) ? getcwd() : l:tree)
      elseif isdirectory(l:dir)
        call add(l:parsed.pick, fnamemodify(l:dir, ':p:h'))
      else
        " glob() expands ~ and $VARS too
        let l:files = filter(glob(l:path, 1, 1), 'filereadable(v:val)')
        if empty(l:files)
          call prompts#error('@' . l:path . ': no such file; text after -- is taken as is')
          return 0
        endif
        let l:parsed.files += map(l:files, 'fnamemodify(v:val, ":p")')
      endif
    elseif l:word =~# '^--\%(ask\|plan\|agent\|auto\)-mode$'
      let l:parsed.mode = matchstr(l:word, '\a\+', 2)
    elseif l:word ==# '--bare'
      let l:parsed.bare = 1
    else
      call remove(l:taken, -1)
    endif
  endfor
  if len(l:parsed.pick) > 1
    call prompts#error('one @ to pick files with, per ask')
    return 0
  endif
  " The query as written, its lines kept (a draft's), less what was taken
  " out and the blanks that followed it
  let l:pos = 0
  for [l:_, l:s, l:e] in l:taken
    let l:parsed.query .= strpart(l:head, l:pos, l:s - l:pos)
    let l:pos = matchend(l:head, '[ \t]*', l:e)
  endfor
  let l:parsed.query = trim(substitute(join(map(split(l:parsed.query . strpart(l:head, l:pos), "\n", 1),
        \ 'trim(v:val, "", 2)'), "\n"), '\n\{3,}', "\n\n", 'g'))
  if l:start >= 0
    let l:parsed.query = trim(l:parsed.query . ' ' . trim(a:args[l:end :]))
  endif
  " Its trailing blanks go, and its blank lines at the top when nothing
  " comes before them; its indentation stays
  let l:rest = trim(l:rest, '', 2)
  if empty(l:parsed.query)
    let l:parsed.query = substitute(l:rest, '^\%(\s*\n\)*', '', '')
  elseif !empty(trim(l:rest))
    let l:parsed.query .= "\n" . l:rest
  endif
  let l:config = s:config(a:from.bufnr)
  if empty(l:config)
    return 0
  endif
  let l:persona = prompts#persona#get(l:parsed.persona, l:config)
  if empty(l:persona)
    return 0
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
  let l:request = s:request(a:from, l:parsed.query, l:sources, l:config)
  " #rule's text goes last in {rules}, so the persona and the query still
  " come after it; a persona with {rule} places it itself
  if stridx(join(l:persona.template, "\n"), '{rule}') < 0
    let l:request.rules = prompts#config#text(l:config,
          \ map(filter(copy(l:sources), 'v:val.name ==# "rule"'), 'v:val.arg'), l:parsed.bare)
  elseif l:parsed.bare
    let l:request.rules = ''
  endif
  let l:Finish = {files -> s:finish(l:persona, l:request, l:parsed,
        \ l:parsed.files + files, a:Then)}
  if empty(l:parsed.pick)
    return l:Finish([])
  elseif empty(get(g:, 'prompts_file_picker', ''))
    call prompts#error('@ without a file needs g:prompts_file_picker (docs/sources/files.md)')
    return 0
  endif
  " The picker may call back at once, or later (fzf runs in a terminal)
  call call(g:prompts_file_picker, [l:parsed.pick[0], l:Finish])
  return 1
endfunction

function! s:finish(persona, request, parsed, files, Then) abort
  if !empty(a:files)
    call add(a:request.sources, {'name': 'files', 'arg': join(uniq(copy(a:files)), "\n")})
    let l:tree = FugitiveWorkTree(a:request.bufnr)
    for l:file in a:files
      if empty(l:tree) || stridx(l:file, l:tree . '/') != 0
        call add(a:request.dirs, fnamemodify(l:file, ':h'))
      endif
    endfor
    call uniq(sort(a:request.dirs))
  endif
  let l:missing = s:missing(a:persona, a:request, a:parsed.given)
  if !empty(l:missing)
    call prompts#error(l:missing)
    return 0
  endif
  call a:Then(a:persona, a:request, prompts#template#render(a:persona.template, a:request))
  return 1
endfunction

" With !, a one-off: the agent answers once, into a buffer
function! prompts#ask(oneoff, range, line1, line2, args) abort
  if a:args =~# '^\%(\s*--\%(\%(ask\|plan\|agent\|auto\)-mode\|bare\)\)*\s*$' && !a:range
    if a:oneoff
      call prompts#agent#oneoff_last()
    else
      call prompts#agent#launch('', {'mode': matchstr(a:args, '--\zs\a\+\ze-mode')}, [])
    endif
    return
  endif
  call s:prompt(s:from(a:range, a:line1, a:line2), a:args, function('s:ask', [a:oneoff]))
endfunction

function! s:ask(oneoff, persona, request, prompt) abort
  let l:prompt = a:prompt
  if a:oneoff
    " There is no session to ask the question in afterwards
    if empty(trim(l:prompt)) || a:persona.name ==# 'default' && empty(a:request.query)
      call prompts#error('a one-off needs a question or a persona')
      return
    endif
    call prompts#agent#oneoff(l:prompt, a:persona.meta, a:request.dirs)
    return
  endif
  " Nothing rendered (`:Ai /default --bare`): the agent opens bare
  if empty(trim(l:prompt))
    call prompts#agent#launch('', a:persona.meta, a:request.dirs)
    return
  endif
  " Without a query, the default persona sends the context for the agent to
  " take in, and you ask in the session; other personas have their own task
  if a:persona.name ==# 'default' && empty(a:request.query)
    let l:prompt .= "\n\nRead this, then wait for my question."
  endif
  call prompts#agent#launch(l:prompt, a:persona.meta, a:request.dirs)
endfunction

function! prompts#draft(oneoff, range, line1, line2, args) abort
  call s:open_draft(a:oneoff, s:from(a:range, a:line1, a:line2), empty(a:args) ? [''] : [a:args, ''])
endfunction

" The draft holds the ask as :Ai takes it, and is read when it is sent
function! s:open_draft(oneoff, from, lines) abort
  let l:git_dir = FugitiveGitDir(a:from.bufnr)
  call roumail_draft#open('ai-draft://ask', a:lines, function('s:send_draft', [a:oneoff, a:from]),
        \ {'split': 'botright vnew', 'saved': 'Draft saved: closing sends it',
        \  'empty': 'Draft empty: closing sends nothing'})
  setlocal filetype=markdown
  " Its repository, for what completes in it (#rule:, #diff_pairs:, /personas)
  if !empty(l:git_dir)
    let b:git_dir = l:git_dir
  endif
  normal! G$
  let &l:statusline = '%f%=:w saves, closing sends, :q! drops '
endfunction

function! s:send_draft(oneoff, from, text) abort
  " Once the draft's window is closed, so the agent's tab isn't the window
  " :wq goes on to close
  " Only its first line is read for a persona, #sources, @files and flags,
  " so a pasted @decorator, #comment or --flag further down stays text
  let [l:first, l:rest] = matchlist(a:text, '^\([^\n]*\)\n\=\(\_.*\)$')[1:2]
  call timer_start(0, {-> s:prompt(a:from, l:first, function('s:ask', [a:oneoff]), l:rest)
        \ || s:open_draft(a:oneoff, a:from, split(a:text, "\n", 1))})
endfunction

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
    return filter(map(filter(prompts#source#names(), 'v:val !=# "files"'), {_, n -> '#' . n
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

" Every word an ask can take but @files, as it completes: for an insert-mode
" picker in a draft
function! prompts#tokens() abort
  let l:tokens = prompts#complete('/', 'Ai /', 4)
  for l:token in prompts#complete('#', '', 0)
    " Not every recent hash: #commits has its own picker
    let l:args = l:token ==# '#commits:' ? []
          \ : prompts#complete(substitute(l:token, ':\=$', ':', ''), '', 0)
    let l:tokens += (l:token =~# ':$' && !empty(l:args) ? [] : [l:token]) + l:args
  endfor
  return l:tokens + prompts#complete('-', '', 0)
endfunction

" For an insert-mode fzf.vim picker: several at once, with <Tab>
function! prompts#fzf() abort
  return {'source': prompts#tokens(), 'prefix': '\S*$',
        \ 'options': ['--multi', '--prompt', 'Ai> '],
        \ 'reducer': {lines -> join(lines)}}
endfunction

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
    let l:missing = s:missing(l:persona, s:request(s:from(0, line('.'), line('.')), '', copy(l:own), l:config), [])
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

function! prompts#rules() abort
  let l:config = prompts#config#get(bufnr())
  call s:list_errors(l:config.errors)
  let l:place = l:config.place
  for l:rule in l:config.rules
    call s:entry('Identifier', fnamemodify(l:rule.file, ':t'),
          \ [prompts#config#show(l:rule.file, l:place), 'loaded', 'from vim-prompts.rules, ' . l:rule.origin])
  endfor
  if !empty(l:config.repository)
    call s:entry('Identifier', 'repository',
          \ [prompts#config#show(l:config.repository.file, l:place), 'loaded',
          \  'from vim-prompts.repository, ' . l:config.repository.origin])
  endif
  let l:names = prompts#config#rule_names(l:config)
  for l:rule in l:config.hidden
    let l:name = fnamemodify(l:rule.file, ':t')
    call s:entry('Comment', l:name,
          \ [prompts#config#show(l:rule.file, l:place), 'hidden by ' . prompts#config#show(l:names[l:name], l:place),
          \  'from vim-prompts.rules, ' . l:rule.origin])
  endfor
  " Sent only when asked for
  let l:task_rules = prompts#config#task_rules(l:config)
  for l:name in sort(keys(l:task_rules))
    let l:rule = l:task_rules[l:name]
    call s:entry('Identifier', '#rule:' . l:name,
          \ [prompts#config#show(l:rule.file, l:place), 'loaded', 'from vim-prompts.task-rules, ' . l:rule.origin])
    for l:hidden in l:rule.hides
      call s:entry('Comment', '#rule:' . l:name,
            \ [prompts#config#show(l:hidden.file, l:place), 'hidden by ' . prompts#config#show(l:rule.file, l:place),
            \  'from vim-prompts.task-rules, ' . l:hidden.origin])
    endfor
  endfor
endfunction

function! s:list_errors(errors) abort
  echohl ErrorMsg
  for l:error in a:errors
    echo l:error
  endfor
  echohl None
endfunction

function! s:entry(group, name, lines) abort
  " Each line on a line of its own: paths are too long for columns
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

function! prompts#rule(range, line1, line2, args) abort
  let [l:target, l:text] = s:key_and_rest(a:args)
  let l:config = s:config(bufnr())
  if empty(l:config)
    return
  endif
  let l:names = prompts#config#rule_names(l:config)
  if l:target =~# '^--\%(global\|local\|worktree\)$'
    let l:scope = l:target[2:]
    let l:file = get(filter(copy(l:config.hidden) + copy(l:config.rules), 'v:val.scope ==# l:scope'),
          \ -1, {'file': ''}).file
    if empty(l:file)
      if l:scope !=# 'global' && !l:config.place.repo
        call prompts#error('--' . l:scope . ': not in a repository')
        return
      endif
      " Outside any repository, so a shared one never sees it
      let l:dir = prompts#config#home() . '/vim-prompts'
      if l:scope ==# 'global'
        let l:default = l:dir . '/rules.md'
      else
        " repo/.git, repo/.bare, repo.git
        let l:common = FugitiveCommonDir(FugitiveExtractGitDir(l:config.place.dir))
        let l:default = l:dir . '/repos/' . (l:common =~# '/\.[^/]\+$' ? fnamemodify(l:common, ':h:t')
              \ : fnamemodify(l:common, ':t:s?\.git$??'))
              \ . (l:scope ==# 'worktree' ? '-' . fnamemodify(l:config.place.dir, ':t') : '') . '.md'
      endif
      let l:file = input('New ' . l:scope . ' rules file: ', fnamemodify(l:default, ':~'), 'file')
      redraw
      if empty(trim(l:file))
        return
      endif
      let l:file = fnamemodify(expand(trim(l:file)), ':p')
      if !filereadable(l:file)
        call mkdir(fnamemodify(l:file, ':h'), 'p')
        call writefile([], l:file)
      endif
      let l:out = system('git -C ' . shellescape(l:config.place.dir) . ' config --' . l:scope
            \ . ' --add vim-prompts.rules ' . shellescape(fnamemodify(l:file, ':~')))
      if v:shell_error
        call prompts#error('git config --' . l:scope . ': ' . trim(l:out))
        return
      endif
      echomsg 'vim-prompts: vim-prompts.rules ' . fnamemodify(l:file, ':~') . ' (' . l:scope . ')'
    endif
  elseif has_key(l:names, l:target)
    let l:file = l:names[l:target]
  else
    call prompts#error((empty(l:target) ? '' : l:target . ': not a rules file here; ')
          \ . 'name one (<Tab>), or --global, --local or --worktree')
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

function! prompts#rule_complete(lead, cmdline, pos) abort
  if a:cmdline[: a:pos - 1] !~# '^\S*\s\+\S*$'
    return []
  endif
  let l:config = prompts#config#get(bufnr())
  return filter(sort(keys(prompts#config#rule_names(l:config)))
        \ + ['--global'] + (l:config.place.repo ? ['--local', '--worktree'] : []),
        \ 'stridx(v:val, a:lead) == 0')
endfunction

function! prompts#unset(args) abort
  let [l:key, l:value] = s:key_and_rest(a:args)
  let l:config = prompts#config#get(bufnr())
  let l:entries = filter(copy(l:config.entries), 'v:val.key ==# l:key')
  if empty(l:entries)
    call prompts#error('vim-prompts.' . l:key . ' is not set here')
    return
  endif
  if empty(l:value)
    if len(uniq(sort(map(copy(l:entries), 'v:val.value')))) > 1
      call prompts#error('vim-prompts.' . l:key . ' has several values: name one (<Tab>)')
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
      call prompts#error('vim-prompts.' . l:key . ' ' . l:value . ': not set here')
      return
    endif
  endif
  let l:entry = l:entries[-1]
  if empty(l:entry.file)
    call prompts#error('vim-prompts.' . l:key . ' (' . l:entry.origin . '): set on the command line, not in a file')
    return
  endif
  " As git stores it (a path as written, ~ and all): --unset only matches that text
  let l:out = system('git config -f ' . shellescape(l:entry.file) . ' --fixed-value --unset-all '
        \ . shellescape('vim-prompts.' . l:entry.key) . ' ' . shellescape(l:entry.value))
  if v:shell_error
    call prompts#error('vim-prompts.' . l:key . ' (' . l:entry.origin . '): '
          \ . (empty(trim(l:out)) ? 'git config exited ' . v:shell_error : trim(l:out)))
    return
  endif
  echomsg 'vim-prompts: unset vim-prompts.' . l:key . ' '
        \ . (empty(l:entry.value) ? '""' : l:entry.value) . ' (' . l:entry.origin . ')'
endfunction

function! s:value_path(value, config) abort
  " So ~/x and /home/me/x are the same
  return empty(a:value) ? '' : fnamemodify(prompts#config#path(a:value, a:config.place), ':p')
endfunction

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
