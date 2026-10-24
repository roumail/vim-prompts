" Personas: markdown files whose body is a template and whose frontmatter
" names the persona's default context sources and how the agent runs for it
" (docs/personas.md). The name is the file name, asked for as /name; `default` is
" the persona :Ai asks without one. The most specific wins: this plugin's
" personas/, then every other personas/ on 'runtimepath' (~/.vim/personas, or
" a plugin that ships personas), then the repo's .vim-prompts/personas/. Two
" of the same name at one level are an error.

let s:bundled = expand('<sfile>:p:h:h:h') . '/personas'
" name -> {name, file, source}
let s:personas = {}
let s:keys = ['context', 'agent', 'args', 'mode']

function! s:error(msg) abort
  echohl ErrorMsg
  echomsg 'vim-prompts: ' . a:msg
  echohl None
endfunction

" ---------------------------------------------------------------------------
" Frontmatter: `key: value` lines between `---` lines. Values are scalars,
" flow lists [a, b] and flow maps {claude: [a, b]}.

" [value, rest of the text]
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

" {meta, template}; throws on bad frontmatter
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
  if index(['', 'ask', 'plan', 'agent'], get(l:meta, 'mode', '')) < 0
    throw 'mode: ask, plan or agent'
  endif
  " `name` or `name:arg` -> {name, arg}
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
" Loading

function! s:dirs() abort
  let l:dirs = [['bundled', s:bundled]]
  for l:dir in globpath(&runtimepath, 'personas', 1, 1)
    if resolve(l:dir) !=# resolve(s:bundled)
      call add(l:dirs, ['pack', l:dir])
    endif
  endfor
  let l:tree = FugitiveWorkTree(FugitiveExtractGitDir(getcwd()))
  if !empty(l:tree)
    call add(l:dirs, ['repo', l:tree . '/.vim-prompts/personas'])
  endif
  return l:dirs
endfunction

function! prompts#persona#load() abort
  call prompts#source#load()
  let s:personas = {}
  for [l:source, l:dir] in s:dirs()
    for l:file in sort(glob(l:dir . '/*.md', 1, 1))
      call s:add(l:source, l:file)
    endfor
  endfor
endfunction

function! s:add(source, file) abort
  let l:name = fnamemodify(a:file, ':t:r')
  let l:where = fnamemodify(a:file, ':~')
  if l:name !~# '^\a[[:alnum:]_-]*$'
    call s:error(l:where . ': name must be letters, digits, - and _')
    return
  endif
  try
    call s:read(a:file)
  catch
    call s:error(l:where . ': ' . v:exception)
    return
  endtry
  let l:old = get(s:personas, l:name, {})
  if !empty(l:old) && l:old.source ==# a:source
    call s:error(l:where . ': duplicate of ' . fnamemodify(l:old.file, ':~'))
    return
  endif
  let s:personas[l:name] = {'name': l:name, 'file': a:file, 'source': a:source}
endfunction

" ---------------------------------------------------------------------------

function! prompts#persona#names() abort
  return sort(keys(s:personas))
endfunction

" The persona {name, file, source, meta, template}, read again so edits apply
" without reloading; {} with the error given when there is none
function! prompts#persona#get(name) abort
  let l:p = get(s:personas, a:name, {})
  if empty(l:p)
    call s:error('no persona /' . a:name . ' (:' . prompts#namespace() . 'Personas!)')
    return {}
  endif
  try
    return extend(copy(l:p), s:read(l:p.file))
  catch
    call s:error(fnamemodify(l:p.file, ':~') . ': ' . v:exception)
    return {}
  endtry
endfunction
