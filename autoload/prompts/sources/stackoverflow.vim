" #stackoverflow[:terms]: docs/sources/stackoverflow.md
function! prompts#sources#stackoverflow#info() abort
  return {'needs': 'search terms: #stackoverflow:"terms"', 'arg': 'optional'}
endfunction

function! prompts#sources#stackoverflow#context(request, arg) abort
  let l:arg = trim(a:arg)
  let l:tags = l:arg =~# '^\%(\[[^][]\+\]\s*\)\+$'
  return 'Search Stack Overflow for '
        \ . (empty(l:arg) ? 'answers to my question'
        \   : l:tags ? 'answers to my question, in ' . l:arg . ' (tags)' : '`' . l:arg . '`')
        \ . '. Use the answers that fit (accepted, well voted and recent ones '
        \ . 'first), say where they disagree, and link the ones you used.'
endfunction
