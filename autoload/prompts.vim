" vim-prompts: ask an agent CLI as one of its personas, in the CLIs' own
" grammar: `:Ai /review #comments @notes.md why is this here`.
"
" - query: what the user types, around the /persona, #sources and @files
" - request: the query plus where it was asked: buffer, line, range or
"   selection (taken before any window opens), the repository context, and
"   the context sources
" - context source: what Vim shows, or where the agent should look, as text
"   (prompts/source.vim); #name[:arg] asks for one on top of the persona's,
"   @path for files
" - persona: a template plus its default sources and how the agent runs for
"   it (prompts/persona.vim); /name picks one, else `default`
" - prompt: the persona's template rendered with the request and its context
"   (prompts/template.vim). It starts the agent (prompts/agent.vim), or opens
"   as a draft to edit first.

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
" Grammar: [/persona] [#source[:arg]...] [@path...] [--<mode>-mode] [query]
" [-- text]. The persona is the first word; #sources, @paths and the mode the
" agent starts in (ask, plan, agent, auto) may be anywhere before `--`, after
" which everything is query as typed. An argument or path with spaces is
" quoted: #stackoverflow:"vim term_start cwd", @"~/My Notes/a.md".

" @path -> {files, pick: dirs to pick in}; {} with the error given
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

" {persona, given, files, pick, mode, query}; {} with the error given
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
  let l:parsed = {'persona': 'default', 'given': [], 'files': [], 'pick': [], 'mode': '', 'query': []}
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

" The repo's .vim-prompts/repository.md: what the repository is, for every
" ask in it
function! s:repository(bufnr) abort
  let l:tree = FugitiveWorkTree(a:bufnr)
  if empty(l:tree)
    let l:tree = FugitiveWorkTree(FugitiveExtractGitDir(getcwd()))
  endif
  let l:file = l:tree . '/.vim-prompts/repository.md'
  if empty(l:tree) || !filereadable(l:file)
    return ''
  endif
  let l:text = trim(join(readfile(l:file), "\n"))
  return empty(l:text) ? ''
        \ : "About this repository (.vim-prompts/repository.md):\n\n" . l:text
endfunction

" Context is filled in by the sources as they are asked for
function! s:request(range, line1, line2, query, sources) abort
  let l:request = {'query': a:query, 'sources': a:sources, 'dirs': [],
        \ 'bufnr': bufnr(), 'line': a:range ? a:line1 : line('.'),
        \ 'range': a:range, 'line1': a:line1, 'line2': a:line2,
        \ 'selection': [], 'charwise': 0, 'context': {},
        \ 'repository': s:repository(bufnr())}
  if !a:range
    return l:request
  endif
  let l:mode = visualmode()
  if l:mode !=# 'V' && !empty(l:mode)
        \ && a:line1 == line("'<") && a:line2 == line("'>")
    let l:request.selection = getregion(getpos("'<"), getpos("'>"), {'type': l:mode})
    let l:request.charwise = 1
  else
    let l:request.selection = getline(a:line1, a:line2)
  endif
  return l:request
endfunction

" Adds the @files: one `files` source, and the directories outside the work
" tree for the agent to be allowed in
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

" What is missing for the request, '' when nothing: each #source asked for
" must have context, and a persona with sources needs context from one of
" the request's (its own, those added, the files) or a selection
function! s:missing(persona, request, given) abort
  for l:source in a:given
    if empty(prompts#source#context(l:source, a:request))
      return '#' . l:source.name . ' has nothing: needs '
            \ . prompts#source#info(l:source.name).needs
    endif
  endfor
  let l:own = a:persona.meta.context
  if empty(l:own) || !empty(a:request.selection)
    return ''
  endif
  for l:source in a:request.sources
    if !empty(prompts#source#context(l:source, a:request))
      return ''
    endif
  endfor
  return '/' . a:persona.name . ' needs '
        \ . join(map(copy(l:own), 'prompts#source#info(v:val.name).needs'), ', or ')
endfunction

" Renders the prompt for the command's arguments and passes [persona,
" request, prompt] to Then, once the files are picked when @ asks for that.
" Errors are given instead; ! skips the check for context.
function! s:prompt(bang, range, line1, line2, args, Then) abort
  let l:parsed = s:parse(a:args)
  if empty(l:parsed)
    return
  endif
  let l:persona = prompts#persona#get(l:parsed.persona)
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
  let l:request = s:request(a:range, a:line1, a:line2, l:parsed.query, l:sources)
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

" :[range]Ai[!] [/persona] [#source...] [@path...] [--<mode>-mode] [query]
" [-- text]. With nothing (or only a mode), opens the agent bare, or
" focuses the bare session already running.
function! prompts#ask(bang, range, line1, line2, args) abort
  if trim(a:args) =~# '^\%(--\%(ask\|plan\|agent\|auto\)-mode\)\=$' && !a:range
    call prompts#agent#launch('', {'mode': matchstr(trim(a:args), '\a\+', 2)}, [])
    return
  endif
  call s:prompt(a:bang, a:range, a:line1, a:line2, a:args, function('s:ask'))
endfunction

" Without a query, the default persona sends the context for the agent to
" take in, and you ask in the session; other personas have their own task
function! s:ask(persona, request, prompt) abort
  let l:prompt = a:prompt
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

function! s:send_draft() abort
  let l:prompt = trim(join(getline(1, '$'), "\n"))
  if empty(l:prompt)
    call s:error('the draft is empty')
    return
  endif
  " Left open: :wq sends and closes, :w sends again after more edits
  setlocal nomodified
  call prompts#agent#launch(l:prompt, b:prompts_draft.meta, b:prompts_draft.request.dirs)
endfunction

" /personas first; #sources, @files and the mode anywhere before --
function! prompts#complete(lead, cmdline, pos) abort
  if a:cmdline[: a:pos - 1] =~# '\s--\s'
    return []
  elseif a:lead =~# '^#\h\w*:'
    " A source's argument, from its complete() when it has one
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
    return filter(['--agent-mode', '--ask-mode', '--auto-mode', '--plan-mode'], 'stridx(v:val, a:lead) == 0')
  elseif a:lead =~# '^/' && a:cmdline[: a:pos - 1] =~# '^\S*\s\+\S*$'
    return filter(map(prompts#persona#names(), '"/" . v:val'),
          \ 'stridx(v:val, a:lead) == 0')
  endif
  return []
endfunction

" :AiPersonas[!]: each persona, its context, where it comes from, and what it
" needs that isn't here. With !, reload the persona and source files first.
function! prompts#list(reload) abort
  if a:reload
    call prompts#persona#load()
  endif
  for l:name in prompts#persona#names()
    let l:persona = prompts#persona#get(l:name)
    if empty(l:persona)
      continue
    endif
    let l:own = l:persona.meta.context
    let l:request = s:request(0, line('.'), line('.'), '', copy(l:own))
    echohl Identifier
    echo printf('%-16s', '/' . l:name)
    echohl None
    echon printf('%-28s %-8s %s',
          \ join(map(copy(l:own), '"#" . v:val.name . (empty(v:val.arg) ? "" : ":" . v:val.arg)')),
          \ l:persona.source, fnamemodify(l:persona.file, ':~'))
    let l:missing = s:missing(l:persona, l:request, [])
    if !empty(l:missing)
      echohl Comment
      echo repeat(' ', 16) . l:missing
      echohl None
    endif
  endfor
endfunction
