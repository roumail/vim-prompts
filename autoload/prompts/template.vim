" A template is a persona's text with slots: {query}, {selection}, {context}
" for the context of the request's sources, and {<source>} to place one of
" them elsewhere. Rendering it for a request gives the prompt. Nothing asked
" for is dropped: without {query} the query goes last, and without
" {context} or {selection} those go just before the query.

function! prompts#template#render(template, request) abort
  let l:prompt = join(a:template, "\n")
  let l:heading = stridx(l:prompt, '{query}') < 0 && !empty(a:request.query)
  if stridx(l:prompt, '{query}') < 0
    let l:prompt .= "\n\n{query}"
  endif
  for l:slot in ['{selection}', '{context}']
    if stridx(l:prompt, l:slot) < 0
      let l:prompt = substitute(l:prompt, '{query}', l:slot . "\n\n{query}", '')
    endif
  endfor
  " Slots of sources not asked for stay empty; the request's sources go in
  " their own slot, else in {context}
  let l:values = {}
  let l:context = []
  for l:name in prompts#source#names()
    let l:text = index(a:request.sources, l:name) < 0 ? ''
          \ : prompts#source#context(l:name, a:request)
    if stridx(l:prompt, '{' . l:name . '}') >= 0
      let l:values[l:name] = l:text
    elseif !empty(l:text)
      call add(l:context, [index(a:request.sources, l:name), l:text])
    endif
  endfor
  let l:values.context = join(map(sort(l:context, {a, b -> a[0] - b[0]}), 'v:val[1]'), "\n\n")
  let l:values.selection = prompts#source#selection(a:request)
  let l:values.query = (l:heading ? "Additional request from the user:\n" : '')
        \ . a:request.query
  " One pass, so text from the context is never taken for a slot
  let l:prompt = substitute(l:prompt, '{\(' . join(keys(l:values), '\|') . '\)}',
        \ {m -> l:values[m[1]]}, 'g')
  " No runs of blank lines left by empty slots, no blank ends
  return trim(substitute(l:prompt, '\n\s*\n\%(\s*\n\)\+', "\n\n", 'g'))
endfunction
