function! prompts#namespace() abort
  let l:ns = get(g:, 'prompts_namespace', 'Ai')
  return toupper(l:ns[0]) . l:ns[1:]
endfunction

" Whether the plugin with the autoload file autoload/{name}.vim is installed:
" the sources and commands that use one check for it first
function! prompts#installed(name) abort
  return !empty(globpath(&runtimepath, 'autoload/' . a:name . '.vim', 1))
endfunction

" The same, saying what needs the plugin when it isn't installed
function! prompts#requires(what, plugin, name) abort
  if prompts#installed(a:name)
    return 1
  endif
  call prompts#error(a:what . ' needs ' . a:plugin . ', which is not installed')
  return 0
endfunction

function! prompts#error(msg) abort
  echohl ErrorMsg
  echomsg 'vim-prompts: ' . a:msg
  echohl None
endfunction

" /persona, or /persona:variant, first in an ask
let s:persona_word = '^/\a[[:alnum:]_-]*\%(:\a[[:alnum:]_-]*\)\=$'

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

function! s:instruction(source) abort
  return !has_key(a:source, 'any') && get(prompts#source#info(a:source.name), 'instruction', 0)
endfunction

function! s:needs(source) abort
  return join(map(copy(get(a:source, 'any', [a:source])),
        \ 'prompts#source#info(v:val.name).needs'), ', or ')
endfunction

function! s:show(source) abort
  return has_key(a:source, 'any') ? '[' . join(map(copy(a:source.any), 's:show(v:val)')) . ']'
        \ : '#' . a:source.name . (empty(a:source.arg) ? '' : ':' . a:source.arg)
        \   . (get(a:source, 'optional', 0) ? '?' : '')
endfunction

" Why an ask can't go, '' when it can. {force}: a persona with nothing to
" work on goes anyway
function! s:missing(persona, request, given, force) abort
  for l:source in a:given
    if empty(prompts#source#context(l:source, a:request))
      return s:show(l:source) . ' has nothing: needs '
            \ . prompts#source#info(l:source.name).needs
    endif
  endfor
  " The persona's instructions (a rule, where to write) are part of it: one
  " that has nothing is a mistake to fix, as a #rule: you typed is, unless
  " the persona says it may be missing (rule:name?)
  for l:source in filter(copy(a:persona.meta.context),
        \ 's:instruction(v:val) && !get(v:val, "optional", 0)')
    if empty(prompts#source#context(l:source, a:request))
      return '/' . a:persona.name . ': ' . s:show(l:source) . ' has nothing: needs '
            \ . prompts#source#info(l:source.name).needs
    endif
  endfor
  " Instructions aren't something to work on, so they don't count
  let l:own = filter(copy(a:persona.meta.context), '!s:instruction(v:val)')
  if a:force || !empty(a:request.selection)
        \ || empty(l:own) && get(a:persona.meta, 'input', '') !=# 'required'
    return ''
  endif
  for l:source in a:request.sources
    if !s:instruction(l:source) && !empty(prompts#source#context(l:source, a:request))
      return ''
    endif
  endfor
  return '/' . a:persona.name . ' needs '
        \ . (empty(l:own) ? 'something to work on: a selection, an @file or a #source'
        \   : join(map(copy(l:own), 's:needs(v:val)'), ', or '))
        \ . '; --force sends it without'
endfunction

" The persona's sources, then those typed. A typed one whose argument says
" which of it (#changes:staged) takes the place of the persona's of its
" name, or of the [alternatives] it is in
function! s:sources(own, given) abort
  let l:sources = deepcopy(a:own)
  let l:replaced = {}
  for l:source in a:given
    let l:at = -1
    if prompts#source#info(l:source.name).arg ==# 'optional'
      for l:i in range(len(a:own))
        if !has_key(l:replaced, l:i) && index(map(copy(get(a:own[l:i], 'any', [a:own[l:i]])),
              \ 'v:val.name'), l:source.name) >= 0
          let l:at = l:i
          break
        endif
      endfor
    endif
    if l:at >= 0
      let l:sources[l:at] = l:source
      let l:replaced[l:at] = 1
    elseif index(l:sources, l:source) < 0
      call add(l:sources, l:source)
    endif
  endfor
  return l:sources
endfunction

" Each of the persona's [alternatives] becomes the first of them that has
" something, or goes
function! s:choose(request) abort
  let l:sources = []
  for l:source in a:request.sources
    if has_key(l:source, 'any')
      let l:sources += filter(copy(l:source.any),
            \ '!empty(prompts#source#context(v:val, a:request))')[:0]
    else
      call add(l:sources, l:source)
    endif
  endfor
  let a:request.sources = l:sources
  return a:request
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
        \ 'bare': 0, 'force': 0, 'query': ''}
  let l:taken = []
  if get(get(l:words, 0, []), 0, '') =~# s:persona_word
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
    elseif l:word ==# '--force'
      let l:parsed.force = 1
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
  let l:request = s:choose(s:request(a:from, l:parsed.query,
        \ s:sources(l:persona.meta.context, l:parsed.given), l:config))
  " Before any source is read: #agent_comments asks differently in a one-off
  let l:request.oneoff = s:oneoff(a:from, l:persona)
  let l:sources = l:request.sources
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
  let l:missing = s:missing(a:persona, a:request, a:parsed.given, a:parsed.force)
  if !empty(l:missing)
    call prompts#error(l:missing)
    return 0
  endif
  call a:Then(a:persona, a:request, prompts#template#render(a:persona.template, a:request))
  return 1
endfunction

" Whether an ask goes as a one-off: a reply says; from :Ai, the persona's
" answer: (a session, unless it says oneoff), and ! the other way
function! s:oneoff(from, persona) abort
  return has_key(a:from, 'oneoff') ? a:from.oneoff
        \ : get(a:from, 'bang', 0) != (get(a:persona.meta, 'answer', '') ==# 'oneoff')
endfunction

" Arguments with which :Ai sends nothing: it opens the agent, or the last
" one-off
function! s:opens_only(range, args) abort
  return !a:range && a:args =~# '^\%(\s*--\%(\%(ask\|plan\|agent\|auto\)-mode\|bare\|force\)\)*\s*$'
endfunction

" With !, the other way from the persona's answer: a one-off, where the agent
" answers once into a buffer, rather than a session, or the other way round
function! prompts#ask(bang, range, line1, line2, args) abort
  if s:opens_only(a:range, a:args)
    if a:bang
      call prompts#agent#oneoff_last()
    else
      call prompts#agent#launch('', {'mode': matchstr(a:args, '--\zs\a\+\ze-mode')}, [])
    endif
    return
  endif
  call s:prompt(extend(s:from(a:range, a:line1, a:line2), {'bang': a:bang}), a:args,
        \ function('s:ask'))
endfunction

" What an ask sends, as [1, text]: '' opens the agent bare; [0, ''] when it
" can't go
function! s:sent(oneoff, persona, request, prompt) abort
  if a:oneoff
    " There is no session to ask the question in afterwards
    if empty(trim(a:prompt)) || a:persona.name ==# 'default' && empty(a:request.query)
      call prompts#error('a one-off needs a question or a persona')
      return [0, '']
    endif
    return [1, a:prompt]
  endif
  " Nothing rendered (`:Ai /default --bare`): the agent opens bare
  if empty(trim(a:prompt))
    return [1, '']
  endif
  " Without a query, the default persona sends the context for the agent to
  " take in, and you ask in the session; other personas have their own task
  if a:persona.name ==# 'default' && empty(a:request.query)
    return [1, a:prompt . "\n\nRead this, then wait for my question."]
  endif
  return [1, a:prompt]
endfunction

function! s:ask(persona, request, prompt) abort
  let [l:ok, l:prompt] = s:sent(a:request.oneoff, a:persona, a:request, a:prompt)
  if !l:ok
    return
  endif
  if a:request.oneoff
    call prompts#agent#oneoff(l:prompt, a:persona.meta, a:request.dirs,
          \ {'comments': get(a:request, 'comments', '')})
  else
    call prompts#agent#launch(l:prompt, a:persona.meta, a:request.dirs)
  endif
endfunction

" An ask made from elsewhere, as a reply to the agent's comment is: from
" line {line} of buffer {bufnr}, {before} going before its query, its text
" taken as a draft's is. Then(persona, request, prompt) gets what :Ai would
" send. 1 once it is under way, 0 when it stopped at an error
function! prompts#ask_from(oneoff, bufnr, line, before, text, Then) abort
  let l:from = extend(s:from(0, a:line, a:line), {'bufnr': a:bufnr, 'line': a:line,
        \ 'before': a:before, 'oneoff': a:oneoff})
  let [l:first, l:rest] = matchlist(a:text, '^\([^\n]*\)\n\=\(\_.*\)$')[1:2]
  return s:prompt(l:from, l:first, function('s:sent_then', [a:oneoff, a:Then]), l:rest)
endfunction

function! s:sent_then(oneoff, Then, persona, request, prompt) abort
  let [l:ok, l:prompt] = s:sent(a:oneoff, a:persona, a:request, a:prompt)
  if l:ok
    call a:Then(a:persona, a:request, l:prompt)
  endif
endfunction

" What :Ai with the same arguments would send, in a buffer that sends nothing
function! prompts#preview(bang, range, line1, line2, args) abort
  if s:opens_only(a:range, a:args)
    echomsg 'vim-prompts: :' . prompts#namespace() . (a:bang ? '!' : '')
          \ . ' with these sends nothing: it ' . (a:bang ? 'goes back to the last one-off' : 'opens the agent')
    return
  endif
  call s:prompt(extend(s:from(a:range, a:line1, a:line2), {'bang': a:bang}), a:args,
        \ function('s:preview'))
endfunction

" One preview buffer, refilled by the next :AiPreview while it is shown
let s:preview = -1

function! s:preview(persona, request, prompt) abort
  let [l:ok, l:prompt] = s:sent(a:request.oneoff, a:persona, a:request, a:prompt)
  if !l:ok
    return
  endif
  let l:line = prompts#agent#line(a:persona.meta, a:request.dirs, a:request.oneoff, !empty(l:prompt))
  if bufwinnr(s:preview) > 0
    execute bufwinnr(s:preview) . 'wincmd w'
  else
    botright vnew
    setlocal buftype=nofile bufhidden=wipe noswapfile filetype=markdown
    silent file ai-preview://
    let s:preview = bufnr()
  endif
  setlocal modifiable noreadonly
  silent %delete _
  call setline(1, empty(l:prompt) ? [] : split(l:prompt, "\n", 1))
  setlocal nomodifiable readonly nomodified
  normal! gg
  let &l:statusline = '%f  /' . a:persona.name . ' would run: '
        \ . substitute(empty(l:line) ? '(no agent)' : l:line, '%', '%%', 'g')
        \ . (empty(l:prompt) ? '%=nothing sent: the agent opens bare ' : '%=nothing is sent from here ')
endfunction

function! prompts#draft(bang, range, line1, line2, args) abort
  if !prompts#requires(':' . prompts#namespace() . 'Draft', 'vim-draft', 'roumail_draft')
    return
  endif
  call s:open_draft(extend(s:from(a:range, a:line1, a:line2), {'bang': a:bang}),
        \ empty(a:args) ? [''] : [a:args, ''])
endfunction

" The draft holds the ask as :Ai takes it, and is read when it is sent
function! s:open_draft(from, lines) abort
  let l:git_dir = FugitiveGitDir(a:from.bufnr)
  call roumail_draft#open('ai-draft://ask', a:lines, function('s:send_draft', [a:from]),
        \ {'split': 'botright vnew', 'saved': 'Draft saved: closing sends it',
        \  'empty': 'Draft empty: closing sends nothing'})
  setlocal filetype=markdown
  " Its repository, for what completes in it (#rule:, #diff_pairs:, /personas)
  if !empty(l:git_dir)
    let b:git_dir = l:git_dir
  endif
  let &l:statusline = '%f%=:w saves, closing sends, :q! drops '
endfunction

function! s:send_draft(from, text) abort
  " Once the draft's window is closed, so the agent's tab isn't the window
  " :wq goes on to close
  " Only its first line is read for a persona, #sources, @files and flags,
  " so a pasted @decorator, #comment or --flag further down stays text
  let [l:first, l:rest] = matchlist(a:text, '^\([^\n]*\)\n\=\(\_.*\)$')[1:2]
  call timer_start(0, {-> s:prompt(a:from, l:first, function('s:ask'), l:rest)
        \ || s:open_draft(a:from, split(a:text, "\n", 1))})
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
    " A source whose argument is optional twice when it completes one: #changes
    " alone, and #changes: to go on to its arguments, as #rule: does
    let l:names = []
    for l:name in filter(prompts#source#names(), 'v:val !=# "files"')
      let l:arg = prompts#source#info(l:name).arg
      let l:names += l:arg ==# 'required' ? ['#' . l:name . ':']
            \ : l:arg ==# 'optional' && exists('*prompts#sources#' . l:name . '#complete')
            \ ? ['#' . l:name, '#' . l:name . ':'] : ['#' . l:name]
    endfor
    return filter(l:names, 'stridx(v:val, a:lead) == 0')
  elseif a:lead =~# '^@'
    return map(getcompletion(a:lead[1:], 'file'), '"@" . v:val')
  elseif a:lead =~# '^-'
    return filter(['--agent-mode', '--ask-mode', '--auto-mode', '--bare', '--force', '--plan-mode'], 'stridx(v:val, a:lead) == 0')
  elseif a:lead =~# '^/' && a:cmdline[: a:pos - 1] =~# '^\S*\s\+\S*$'
    " A persona with variants twice, as #changes completes: /review, and
    " /review: to go on to /review:pr
    let l:names = prompts#persona#names(prompts#config#get(bufnr()))
    if a:lead !~# ':'
      let l:names = uniq(sort(map(l:names, 'substitute(v:val, ":.*", ":", "")')
            \ + filter(copy(l:names), 'v:val !~# ":"')))
    endif
    return filter(map(l:names, '"/" . v:val'), 'stridx(v:val, a:lead) == 0')
  endif
  return []
endfunction

" Every word an ask can take but @files, as it completes: for an insert-mode
" picker in a draft
function! prompts#tokens() abort
  let l:tokens = map(prompts#persona#names(prompts#config#get(bufnr())), '"/" . v:val')
  for l:token in prompts#complete('#', '', 0)
    " Not every recent hash: #commits has its own picker
    " Arguments once, for name: (an optional one's bare name has none)
    let l:args = l:token ==# '#commits:' || l:token !~# ':$' ? []
          \ : prompts#complete(l:token, '', 0)
    let l:tokens += (l:token =~# ':$' && !empty(l:args) ? [] : [l:token]) + l:args
  endfor
  return l:tokens + prompts#complete('-', '', 0)
endfunction

" For an insert-mode fzf.vim picker: several at once, with <Tab>. The word
" before the cursor completes as it would after :Ai (#rule: to its rules, @ to
" files); a word that completes to nothing filters every token instead
function! prompts#fzf() abort
  return {'source': function('s:fzf_source'), 'prefix': '\S*$',
        \ 'options': function('s:fzf_options'),
        \ 'reducer': {lines -> join(lines)}}
endfunction

function! s:fzf_matches(word) abort
  " #commits: has its own picker
  if empty(a:word) || a:word =~# '^#commits:'
    return []
  endif
  let l:cmdline = 'Ai ' . getline('.')[: col('.') - 2]
  return prompts#complete(a:word, l:cmdline, len(l:cmdline))
endfunction

function! s:fzf_source(word) abort
  let l:matches = s:fzf_matches(a:word)
  return empty(l:matches) ? prompts#tokens() : l:matches
endfunction

function! s:fzf_options(word) abort
  " One match is inserted at once, as <Tab> does after :Ai
  return ['--multi', '--prompt', 'Ai> ']
        \ + (!empty(s:fzf_matches(a:word)) ? ['--select-1']
        \  : !empty(a:word) ? ['--query', a:word] : [])
endfunction

" :AiPersonas: what a persona needs is judged from where you were when it
" opened, not from the list
function! prompts#list(reload) abort
  if a:reload
    call prompts#source#load()
  endif
  call s:open_list('Personas', function('s:personas'),
        \ {'prompts_from': s:from(0, line('.'), line('.'))})
endfunction

function! s:personas() abort
  let l:config = prompts#config#get(b:prompts_bufnr)
  let b:prompts_errors = map(l:config.errors + prompts#persona#errors(l:config), '"error: " . v:val')
  let l:items = []
  for l:name in prompts#persona#names(l:config)
    let l:persona = prompts#persona#get(l:name, l:config)
    if empty(l:persona)
      continue
    endif
    let l:own = l:persona.meta.context
    call add(l:items, s:item('', '/' . l:name, l:persona.file, fnamemodify(l:persona.file, ':~'),
          \ join(filter([l:persona.source,
          \   join(map(copy(l:own), 's:show(v:val)')),
          \   join(map(copy(l:persona.bases), '"on {base} " . fnamemodify(v:val, ":~")'), '  '),
          \   s:missing(l:persona, s:choose(s:request(b:prompts_from, '', deepcopy(l:own), l:config)), [], 0)],
          \ '!empty(v:val)'), '  ')))
    for l:hidden in prompts#persona#hidden(l:persona, l:config)
      call add(l:items, s:item('', '/' . l:name, l:hidden.file, fnamemodify(l:hidden.file, ':~'),
            \ l:hidden.source . '  hidden by ' . fnamemodify(l:persona.file, ':~')))
    endfor
  endfor
  return l:items
endfunction

" :AiRules: in the order they are sent, each hidden one under the one that
" hides it
function! prompts#rules() abort
  call s:open_list('Rules', function('s:rules'), {})
endfunction

function! s:rules() abort
  let l:config = prompts#config#get(b:prompts_bufnr)
  let b:prompts_errors = map(copy(l:config.errors), '"error: " . v:val')
  let l:place = l:config.place
  let l:items = []
  for l:rule in l:config.rules
    let l:name = fnamemodify(l:rule.file, ':t')
    call add(l:items, s:item('rules', l:name, l:rule.file, prompts#config#show(l:rule.file, l:place), l:rule.origin))
    for l:hidden in filter(copy(l:config.hidden), {_, h -> fnamemodify(h.file, ':t') ==# l:name})
      call add(l:items, s:item('rules', l:name, l:hidden.file, prompts#config#show(l:hidden.file, l:place),
            \ l:hidden.origin . '  hidden by ' . prompts#config#show(l:rule.file, l:place)))
    endfor
  endfor
  if !empty(l:config.repository)
    call add(l:items, s:item('repository', 'repository', l:config.repository.file,
          \ prompts#config#show(l:config.repository.file, l:place), l:config.repository.origin))
  endif
  let l:task_rules = prompts#config#task_rules(l:config)
  for l:name in sort(keys(l:task_rules))
    let l:rule = l:task_rules[l:name]
    call add(l:items, s:item('task rules, sent when asked for', '#rule:' . l:name, l:rule.file,
          \ prompts#config#show(l:rule.file, l:place), l:rule.origin))
    for l:hidden in l:rule.hides
      call add(l:items, s:item('task rules, sent when asked for', '#rule:' . l:name, l:hidden.file,
            \ prompts#config#show(l:hidden.file, l:place),
            \ l:hidden.origin . '  hidden by ' . prompts#config#show(l:rule.file, l:place)))
    endfor
  endfor
  return l:items
endfunction

function! s:item(group, name, file, path, about) abort
  return {'group': a:group, 'name': a:name, 'file': a:file, 'path': a:path, 'about': a:about}
endfunction

function! s:open_list(title, Fetch, vars) abort
  call roumail_lists#open('ai-' . tolower(a:title) . '://' . fnamemodify(roumail_place#get(bufnr()).dir, ':t'), {
        \ 'fetch': a:Fetch,
        \ 'heading': {items -> [a:title . ' (' . len(items) . ')'] + b:prompts_errors},
        \ 'rows': function('s:list_rows'), 'id': {i -> i.group . i.file},
        \ 'match': {i -> i.name . ' ' . i.path},
        \ 'keys': [{'key': '<CR>', 'hint': 'open', 'call': function('s:list_open')}]},
        \ extend({'prompts_bufnr': bufnr()}, a:vars))
  syntax match Comment /^.*  hidden by .*$/
  syntax match ErrorMsg /^error: .*$/
endfunction

" Under a group's row when the group changes, so a filter's best-first order
" may show a group twice
function! s:list_rows(items) abort
  let l:name = max(map(copy(a:items), 'strdisplaywidth(v:val.name)'))
  let l:path = max(map(copy(a:items), 'strdisplaywidth(v:val.path)'))
  let l:rows = []
  let l:group = ''
  for l:item in a:items
    if l:item.group !=# l:group
      let l:group = l:item.group
      call add(l:rows, {'lines': [l:group]})
    endif
    call add(l:rows, {'item': l:item, 'lines': [printf('  %-*S  %-*S  %s',
          \ l:name, l:item.name, l:path, l:item.path, l:item.about)]})
  endfor
  return l:rows
endfunction

function! s:list_open() abort
  let l:item = roumail_lists#item()
  if !empty(l:item)
    wincmd p
    execute 'edit' fnameescape(l:item.file)
  endif
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
