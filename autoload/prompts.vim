" vim-prompts: ask an agent CLI as one of its personas, the way Copilot Chat
" is asked: `:Ai @review #comments why is this here`.
"
" - query: what the user types, after the @persona and #sources
" - request: the query plus where it was asked: buffer, line, range or
"   selection (taken before any window opens), and the context sources
" - context source: something Vim shows, as text (prompts/source.vim);
"   #name asks for one, on top of the persona's defaults
" - persona: a template plus its default sources and how the agent runs for
"   it (prompts/persona.vim); @name picks one, else `default`
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

" {persona, given, query} from `[@persona] [#source...] [query] [-- text]`;
" #sources may be anywhere before `--`, after which everything is query as
" typed. {} with the error given on an unknown name.
function! s:parse(args) abort
  let [l:head, l:start, l:end] = matchstrpos(a:args, '\%(^\|\s\)--\%(\s\|$\)')
  let l:words = split(l:start < 0 ? a:args : strpart(a:args, 0, l:start))
  let l:parsed = {'persona': 'default', 'given': [], 'query': []}
  if get(l:words, 0, '') =~# '^@.'
    let l:parsed.persona = remove(l:words, 0)[1:]
  endif
  for l:word in l:words
    if l:word =~# '^#\h\w*$'
      if !prompts#source#exists(l:word[1:])
        call s:error('no context source ' . l:word . ' (#'
              \ . join(prompts#source#names(), ', #') . '); text after -- is taken as is')
        return {}
      endif
      call add(l:parsed.given, l:word[1:])
    else
      call add(l:parsed.query, l:word)
    endif
  endfor
  if l:start >= 0
    call add(l:parsed.query, trim(a:args[l:end :]))
  endif
  let l:parsed.query = trim(join(l:parsed.query))
  return l:parsed
endfunction

" The request; context is filled in by the sources as they are asked for
function! s:request(range, line1, line2, query, sources) abort
  let l:request = {'query': a:query, 'sources': a:sources,
        \ 'bufnr': bufnr(), 'line': a:range ? a:line1 : line('.'),
        \ 'range': a:range, 'line1': a:line1, 'line2': a:line2,
        \ 'selection': [], 'charwise': 0, 'context': {}}
  " In a :G diff --name-only buffer the range picks files, not text
  if !a:range || prompts#source#is_file_list(bufnr())
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

" What is missing for the request, '' when nothing: each #source asked for
" must have context, and so must one of the persona's (the selection counts)
function! s:missing(persona, request, given) abort
  for l:name in a:given
    if empty(prompts#source#context(l:name, a:request))
      return '#' . l:name . ' has nothing: needs ' . prompts#source#needs(l:name)
    endif
  endfor
  if empty(a:request.sources) || !empty(a:request.selection)
    return ''
  endif
  for l:name in a:request.sources
    if !empty(prompts#source#context(l:name, a:request))
      return ''
    endif
  endfor
  return '@' . a:persona.name . ' needs '
        \ . join(map(copy(a:request.sources), 'prompts#source#needs(v:val)'), ', or ')
endfunction

" [persona, request, prompt] for the command's arguments, or [] with the
" error given. ! skips the check for context.
function! s:prompt(bang, range, line1, line2, args) abort
  let l:parsed = s:parse(a:args)
  if empty(l:parsed)
    return []
  endif
  let l:persona = prompts#persona#get(l:parsed.persona)
  if empty(l:persona)
    return []
  endif
  let l:sources = copy(l:persona.meta.context)
  call extend(l:sources, filter(copy(l:parsed.given), 'index(l:sources, v:val) < 0'))
  let l:request = s:request(a:range, a:line1, a:line2, l:parsed.query, l:sources)
  if !a:bang
    let l:missing = s:missing(l:persona, l:request, l:parsed.given)
    if !empty(l:missing)
      call s:error(l:missing . ' (! asks anyway)')
      return []
    endif
  endif
  return [l:persona, l:request, prompts#template#render(l:persona.template, l:request)]
endfunction

" Starts the agent; the persona may then clear the comments it was given
function! s:send(prompt, meta, sources) abort
  if prompts#agent#launch(a:prompt, a:meta) && get(a:meta, 'consume_comments', 0)
        \ && index(a:sources, 'comments') >= 0
    call git_extras#comments#clear()
  endif
endfunction

" :[range]Ai[!] [@persona] [#source...] [query] [-- text]. With nothing, opens the
" agent bare, or focuses the bare session already running.
function! prompts#ask(bang, range, line1, line2, args) abort
  if empty(trim(a:args)) && !a:range
    call prompts#agent#launch('', {})
    return
  endif
  let l:prompt = s:prompt(a:bang, a:range, a:line1, a:line2, a:args)
  if !empty(l:prompt)
    call s:send(l:prompt[2], l:prompt[0].meta, l:prompt[1].sources)
  endif
endfunction

" :[range]AiDraft[!] ...: the same prompt in a buffer to edit; :w sends it
" (:wq and close), :q! drops it
function! prompts#draft(bang, range, line1, line2, args) abort
  let l:prompt = s:prompt(a:bang, a:range, a:line1, a:line2, a:args)
  if empty(l:prompt)
    return
  endif
  let [l:persona, l:request, l:text] = l:prompt
  let l:command = prompts#agent#command(l:persona.meta)
  botright vnew
  setlocal buftype=acwrite bufhidden=wipe noswapfile filetype=markdown
  execute 'silent file' fnameescape('ai-draft://' . l:persona.name . '/' . bufnr())
  call setline(1, split(l:text, "\n", 1))
  if empty(l:request.query)
    " Room for the query, last
    call append('$', ['', ''])
  endif
  normal! G
  setlocal nomodified
  let b:prompts_draft = {'meta': l:persona.meta, 'sources': l:request.sources}
  let &l:statusline = '%f  ' . (empty(l:command) ? '(no agent)'
        \ : substitute(join(l:command[1]), '%', '%%', 'g') . ' <this>')
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
  call s:send(l:prompt, b:prompts_draft.meta, b:prompts_draft.sources)
endfunction

" @personas first, #sources anywhere before --
function! prompts#complete(lead, cmdline, pos) abort
  if a:cmdline[: a:pos - 1] =~# '\s--\s'
    return []
  elseif a:lead =~# '^#'
    return map(prompts#source#names(), '"#" . v:val')
          \ ->filter('stridx(v:val, a:lead) == 0')
  elseif a:lead =~# '^@' && a:cmdline[: a:pos - 1] =~# '^\S*\s\+\S*$'
    return map(prompts#persona#names(), '"@" . v:val')
          \ ->filter('stridx(v:val, a:lead) == 0')
  endif
  return []
endfunction

" :AiPersonas[!]: each persona, where it comes from, its default sources,
" and what it needs that isn't here. With !, reload the persona files first.
function! prompts#list(reload) abort
  if a:reload
    call prompts#persona#load()
  endif
  for l:name in prompts#persona#names()
    let l:persona = prompts#persona#get(l:name)
    if empty(l:persona)
      continue
    endif
    let l:sources = l:persona.meta.context
    let l:request = s:request(0, line('.'), line('.'), '', l:sources)
    echohl Identifier
    echo printf('%-16s', '@' . l:name)
    echohl None
    echon printf('%-28s %-8s %s', join(map(copy(l:sources), '"#" . v:val')),
          \ l:persona.source, fnamemodify(l:persona.file, ':~'))
    let l:missing = s:missing(l:persona, l:request, [])
    if !empty(l:missing)
      echohl Comment
      echo repeat(' ', 16) . l:missing
      echohl None
    endif
  endfor
endfunction
