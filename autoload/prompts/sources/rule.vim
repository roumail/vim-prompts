" #rule:name: docs/sources/rule.md
function! prompts#sources#rule#info() abort
  return {'needs': 'a rules file in vim-prompts.library: #rule:<Tab>', 'arg': 'required',
        \ 'instruction': 1}
endfunction

" The rules themselves, as {rules} has them: a few lines the agent must
" follow. Only for {rule}: otherwise they go in {rules}, last
function! prompts#sources#rule#context(request, arg) abort
  let l:config = prompts#config#get(a:request.bufnr)
  let l:rule = get(prompts#config#library(l:config), substitute(a:arg, '\.md$', '', ''), {})
  if empty(l:rule)
    return ''
  endif
  let l:text = trim(join(readfile(l:rule.file), "\n"))
  return empty(l:text) ? '' : 'Rules for this task ('
        \ . prompts#config#show(l:rule.file, l:config.place) . "):\n\n" . l:text
endfunction

function! prompts#sources#rule#complete(lead) abort
  return filter(sort(keys(prompts#config#library(prompts#config#get(bufnr())))),
        \ 'stridx(v:val, a:lead) == 0')
endfunction
