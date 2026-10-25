" Personas: docs/personas.md

let s:bundled = expand('<sfile>:p:h:h:h') . '/personas'
let s:keys = ['context', 'agent', 'args', 'mode']
let s:name = '^\a[[:alnum:]_-]*$'

function! s:error(msg) abort
  echohl ErrorMsg
  echomsg 'vim-prompts: ' . a:msg
  echohl None
endfunction

" ---------------------------------------------------------------------------
" Frontmatter

function! s:parse_value(text) abort
  let l:s = trim(a:text, ' ', 1)
  if l:s[0] ==# '['
    let l:items = []
    let l:s = l:s[1:]
    while 1
      let l:s = trim(l:s, ' ', 1)
      if empty(l:s)
        throw 'unclosed ['
      elseif l:s[0] ==# ']'
        return [l:items, l:s[1:]]
      endif
      let [l:value, l:s] = s:parse_value(l:s)
      call add(l:items, l:value)
      let l:s = substitute(l:s, '^\s*,', '', '')
    endwhile
  elseif l:s[0] ==# '{'
    let l:map = {}
    let l:s = l:s[1:]
    while 1
      let l:s = trim(l:s, ' ', 1)
      if empty(l:s)
        throw 'unclosed {'
      elseif l:s[0] ==# '}'
        return [l:map, l:s[1:]]
      endif
      let l:m = matchlist(l:s, '^\([^:,}]\{-}\)\s*:\(.*\)$')
      if empty(l:m)
        throw 'expected key: value in {...}'
      endif
      let [l:value, l:s] = s:parse_value(l:m[2])
      let l:map[l:m[1]] = l:value
      let l:s = substitute(l:s, '^\s*,', '', '')
    endwhile
  elseif l:s[0] ==# '"' || l:s[0] ==# "'"
    let l:end = stridx(l:s, l:s[0], 1)
    if l:end < 0
      throw 'unclosed quote'
    endif
    return [l:s[1 : l:end - 1], l:s[l:end + 1 :]]
  endif
  let l:word = matchstr(l:s, '^[^,\]}]*')
  let l:value = trim(l:word)
  return [l:value ==# 'true' ? 1 : l:value ==# 'false' ? 0 : l:value,
        \ l:s[len(l:word):]]
endfunction

function! s:read(file) abort
  let l:lines = readfile(a:file)
  let l:meta = {}
  if get(l:lines, 0, '') !~# '^---\s*$'
    return {'meta': {'context': []}, 'template': l:lines}
  endif
  let l:end = match(l:lines, '^---\s*$', 1)
  if l:end < 0
    throw 'frontmatter not closed with ---'
  endif
  for l:line in l:lines[1 : l:end - 1]
    if l:line =~# '^\s*\%(#.*\)\=$'
      continue
    endif
    let l:m = matchlist(l:line, '^\(\w\+\)\s*:\s*\(.\{-}\)\s*$')
    if empty(l:m)
      throw 'expected key: value, got: ' . l:line
    elseif index(s:keys, l:m[1]) < 0
      throw 'unknown key ' . l:m[1]
    endif
    let l:meta[l:m[1]] = s:parse_value(substitute(l:m[2], '\s\+#.*$', '', ''))[0]
  endfor
  if index(['', 'ask', 'plan', 'agent', 'auto'], get(l:meta, 'mode', '')) < 0
    throw 'mode: ask, plan, agent or auto'
  endif
  let l:context = get(l:meta, 'context', [])
  let l:meta.context = []
  for l:item in type(l:context) == v:t_list ? l:context : [l:context]
    let l:source = prompts#source#parse(l:item)
    if has_key(l:source, 'error')
      throw 'context: ' . l:source.error
    endif
    call add(l:meta.context, l:source)
  endfor
  return {'meta': l:meta, 'template': l:lines[l:end + 1 :]}
endfunction

" ---------------------------------------------------------------------------
" The stack

function! s:stacks(config) abort
  let l:stacks = {}
  for [l:source, l:dir] in [['bundled', s:bundled]]
        \ + map(copy(a:config.personas), '[v:val.origin, v:val.dir]')
    for l:file in sort(glob(l:dir . '/*.md', 1, 1))
      let l:name = fnamemodify(l:file, ':t:r')
      if l:name =~# s:name
        let l:stacks[l:name] = get(l:stacks, l:name, [])
              \ + [{'name': l:name, 'file': l:file, 'source': l:source}]
      endif
    endfor
  endfor
  return l:stacks
endfunction

function! prompts#persona#errors(config) abort
  let l:errors = []
  for l:dir in map(copy(a:config.personas), 'v:val.dir')
    for l:file in glob(l:dir . '/*.md', 1, 1)
      if fnamemodify(l:file, ':t:r') !~# s:name
        call add(l:errors, fnamemodify(l:file, ':~') . ': name must be letters, digits, - and _')
      endif
    endfor
  endfor
  return l:errors
endfunction

function! prompts#persona#names(config) abort
  return sort(keys(s:stacks(a:config)))
endfunction

function! s:resolve(stack, i) abort
  let l:p = extend(copy(a:stack[a:i]), s:read(a:stack[a:i].file))
  let l:p.bases = []
  let l:text = join(l:p.template, "\n")
  if stridx(l:text, '{base}') < 0
    return l:p
  elseif a:i == 0
    throw '{base}, but no /' . l:p.name . ' below it'
  endif
  let l:base = s:resolve(a:stack, a:i - 1)
  " The persona on top places {query}
  let l:below = join(map(copy(l:base.template), {_, l -> substitute(l, '{query}', '', 'g')}), "\n")
  let l:p.template = split(substitute(l:text, '{base}', {-> l:below}, 'g'), "\n", 1)
  let l:context = copy(l:base.meta.context)
  for l:source in l:p.meta.context
    if index(l:context, l:source) < 0
      call add(l:context, l:source)
    endif
  endfor
  let l:p.meta = extend(extend(copy(l:base.meta), l:p.meta), {'context': l:context})
  let l:p.bases = [l:base.file] + l:base.bases
  return l:p
endfunction

" Read again on each ask, so edits apply at once
function! prompts#persona#get(name, config) abort
  let l:stack = get(s:stacks(a:config), a:name, [])
  if empty(l:stack)
    call s:error('no persona /' . a:name . ' (:' . prompts#namespace() . 'Personas)')
    return {}
  endif
  try
    return s:resolve(l:stack, len(l:stack) - 1)
  catch
    call s:error(fnamemodify(l:stack[-1].file, ':~') . ': ' . v:exception)
    return {}
  endtry
endfunction
