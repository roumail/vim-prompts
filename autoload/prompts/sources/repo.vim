" #repo:owner/name: a GitHub repository for the agent to read with gh
function! prompts#sources#repo#info() abort
  return {'needs': 'a GitHub repository: #repo:owner/name', 'arg': 'required'}
endfunction

function! prompts#sources#repo#context(request, arg) abort
  let l:repo = substitute(a:arg, '^\%(https\=://\)\=github\.com/\|\.git$\|/$', '', 'g')
  if l:repo !~# '^[[:alnum:]_.-]\+/[[:alnum:]_.-]\+$'
    return ''
  endif
  return 'GitHub repository `' . l:repo . '` (https://github.com/' . l:repo . '). '
        \ . 'Read what you need with `gh repo view ' . l:repo . '`, `gh api repos/'
        \ . l:repo . '/contents/<path>` or `gh search code --repo ' . l:repo
        \ . ' <terms>`, or shallow-clone it into a temporary directory. Only read it.'
endfunction
