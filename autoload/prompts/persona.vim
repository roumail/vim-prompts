" Personas: docs/personas.md

let s:bundled = expand('<sfile>:p:h:h:h') . '/personas'
let s:keys = ['context', 'agent', 'args', 'mode', 'input', 'answer']
let s:name = '^\a[[:alnum:]_-]*$'

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

" A persona's name, or a variant's (name:variant), from its file: <dir>/name.md,
" <dir>/name/variant.md; '' when it isn't one
function! s:file_name(dir, file) abort
  let l:parts = split(a:file[len(a:dir) + 1 : -4], '/')
  return len(l:parts) <= 2 && empty(filter(copy(l:parts), 'v:val !~# s:name'))
        \ ? join(l:parts, ':') : ''
endfunction

function! s:files(dir) abort
  return sort(glob(a:dir . '/*.md', 1, 1) + glob(a:dir . '/*/*.md', 1, 1))
endfunction

function! s:stacks(config) abort
  let l:stacks = {}
  for [l:source, l:dir] in [['bundled', s:bundled]]
        \ + map(copy(a:config.personas), '[v:val.origin, v:val.dir]')
    for l:file in s:files(l:dir)
      let l:name = s:file_name(l:dir, l:file)
      if !empty(l:name)
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
    for l:file in s:files(l:dir)
      if empty(s:file_name(l:dir, l:file))
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
  let l:lines = readfile(a:stack[a:i].file)
  let l:meta = {'context': []}
  let l:template = l:lines
  if get(l:lines, 0, '') =~# '^---\s*$'
    let l:end = match(l:lines, '^---\s*$', 1)
    if l:end < 0
      throw 'frontmatter not closed with ---'
    endif
    let l:meta = {}
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
    elseif index(['', 'required', 'optional'], get(l:meta, 'input', '')) < 0
      throw 'input: required or optional'
    elseif index(['', 'oneoff', 'session'], get(l:meta, 'answer', '')) < 0
      throw 'answer: oneoff or session'
    endif
    let l:context = get(l:meta, 'context', [])
    let l:meta.context = []
    for l:item in type(l:context) == v:t_list ? l:context : [l:context]
      " [a, b]: the first of them that has something
      let l:any = []
      for l:text in type(l:item) == v:t_list ? l:item : [l:item]
        if type(l:text) != v:t_string
          throw 'context: one level of [alternatives], of sources'
        endif
        " +name?: a rule this persona goes without where there is none
        let l:bare = substitute(l:text, '?$', '', '')
        let l:source = l:bare =~# '^+' ? prompts#source#rule(l:bare[1:]) : prompts#source#parse(l:bare)
        if has_key(l:source, 'error')
          throw 'context: ' . l:source.error
        elseif type(l:item) == v:t_list && get(prompts#source#info(l:source.name), 'instruction', 0)
          throw 'context: ' . l:bare . ' is always sent, not one of [alternatives]'
        elseif l:text =~# '?$'
          if l:source.name !=# 'rule' || type(l:item) == v:t_list
            throw 'context: only a rule may be missing (+name?), not ' . l:text
          endif
          let l:source.optional = 1
        endif
        call add(l:any, l:source)
      endfor
      if empty(l:any)
        throw 'context: [] names no source'
      endif
      call add(l:meta.context, type(l:item) == v:t_list ? {'any': l:any} : l:any[0])
    endfor
    let l:template = l:lines[l:end + 1 :]
  endif
  let l:p = extend(copy(a:stack[a:i]), {'meta': l:meta, 'template': l:template})
  let l:p.bases = []
  let l:text = join(l:p.template, "\n")
  if stridx(l:text, '{base}') < 0
    return l:p
  elseif a:i == 0
    throw '{base}, but no /' . matchstr(l:p.name, '^[^:]*') . ' below it'
  endif
  let l:base = s:resolve(a:stack, a:i - 1)
  " The persona on top places {query}, and any slot it names itself: each
  " is filled once
  let l:slots = ['query']
  call substitute(l:text, '{\(\h\w*\)}', '\=add(l:slots, submatch(1))', 'g')
  let l:pattern = '{\%(' . join(filter(l:slots, 'v:val !=# "base"'), '\|') . '\)}'
  let l:p.template = split(substitute(l:text, '{base}',
        \ {-> join(map(copy(l:base.template), {_, l -> substitute(l, l:pattern, '', 'g')}), "\n")}, 'g'), "\n", 1)
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

function! prompts#persona#hidden(persona, config) abort
  return filter(get(s:stacks(a:config), a:persona.name, [])[:-2],
        \ {_, p -> index(a:persona.bases, p.file) < 0})
endfunction

function! prompts#persona#get(name, config) abort
  " Read again on each ask, so edits apply at once. A variant's files are
  " above its persona's, for its {base}
  let l:stacks = s:stacks(a:config)
  let l:stack = get(l:stacks, a:name, [])
  if !empty(l:stack) && a:name =~# ':'
    let l:stack = get(l:stacks, matchstr(a:name, '^[^:]*'), []) + l:stack
  endif
  if empty(l:stack)
    call prompts#error('no persona /' . a:name . ' (:' . prompts#namespace() . 'Personas)')
    return {}
  endif
  try
    return s:resolve(l:stack, len(l:stack) - 1)
  catch
    call prompts#error(fnamemodify(l:stack[-1].file, ':~') . ': ' . v:exception)
    return {}
  endtry
endfunction
