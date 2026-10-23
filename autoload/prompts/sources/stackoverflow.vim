" #stackoverflow[:terms]: have the agent search Stack Overflow, for the terms
" or for the query
function! prompts#sources#stackoverflow#info() abort
  return {'needs': 'search terms: #stackoverflow:"terms"', 'arg': 'optional'}
endfunction

function! prompts#sources#stackoverflow#context(request, arg) abort
  return 'Search Stack Overflow for '
        \ . (empty(a:arg) ? 'answers to my question' : '`' . a:arg . '`')
        \ . '. Use the answers that fit (accepted, well voted and recent ones '
        \ . 'first), say where they disagree, and link the ones you used.'
endfunction
