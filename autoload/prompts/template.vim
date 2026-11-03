" Slots: docs/personas.md#template

function! prompts#template#render(template, request) abort
  let l:prompt = join(a:template, "\n")
  let l:heading = stridx(l:prompt, '{query}') < 0 && !empty(a:request.query)
  if stridx(l:prompt, '{query}') < 0
    let l:prompt .= "\n\n{query}"
  endif
  for l:slot in ['{rules}', '{context}', '{selection}']
    if stridx(l:prompt, l:slot) < 0
      let l:prompt = substitute(l:prompt, '{query}', l:slot . "\n\n{query}", '')
    endif
  endfor
  let l:slots = {}
  let l:context = []
  for l:source in a:request.sources
    let l:text = prompts#source#context(l:source, a:request)
    if stridx(l:prompt, '{' . l:source.name . '}') >= 0
      let l:slots[l:source.name] = get(l:slots, l:source.name, []) + [l:text]
    elseif l:source.name ==# 'rule'
      " Already in {rules}
    elseif !empty(l:text)
      call add(l:context, l:text)
    endif
  endfor
  " Slots of sources not asked for stay empty
  let l:values = {}
  for l:name in prompts#source#names()
    let l:values[l:name] = join(get(l:slots, l:name, []), "\n\n")
  endfor
  let l:values.context = join(l:context, "\n\n")
  let l:values.rules = a:request.rules
  " Not a source: a range is always sent
  let l:values.selection = ''
  if !empty(a:request.selection)
    let l:d = prompts#source#describe(a:request.bufnr)
    let l:where = a:request.line1
          \ . (a:request.line2 != a:request.line1 ? '-' . a:request.line2 : '')
    let l:head = (a:request.charwise ? 'Selected text, ' : 'Selected lines, ')
          \ . (empty(bufname(a:request.bufnr)) ? 'line ' . l:where : l:d.path . ':' . l:where)
    if !empty(l:d.object)
      let l:head .= ' (' . l:d.side . ' version: `git show ' . l:d.object . '`)'
    endif
    let l:fence = match(a:request.selection, '^\s*```') >= 0 ? '````' : '```'
    let l:values.selection = l:head . ":\n" . l:fence . getbufvar(a:request.bufnr, '&filetype') . "\n"
          \ . join(a:request.selection, "\n") . "\n" . l:fence
  endif
  " What an ask from elsewhere puts first (a reply: the comment it is on)
  let l:before = get(a:request, 'before', '')
  let l:values.query = (empty(l:before) ? '' : l:before . "\n\n")
        \ . (l:heading ? "Additional request from the user:\n" : '') . a:request.query
  " One pass, so text from the context is never taken for a slot
  let l:prompt = substitute(l:prompt, '{\(' . join(keys(l:values), '\|') . '\)}',
        \ {m -> l:values[m[1]]}, 'g')
  " No runs of blank lines left by empty slots, no blank ends
  return trim(substitute(l:prompt, '\n\s*\n\%(\s*\n\)\+', "\n\n", 'g'))
endfunction
