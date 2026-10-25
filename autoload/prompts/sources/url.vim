" #url:<link>: a page for the agent to read, the way that suits the site: a
" GitHub issue or pull request with gh, a Stack Exchange question or answer
" with its API, anything else fetched
function! prompts#sources#url#info() abort
  return {'needs': 'a link: #url:https://...', 'arg': 'required'}
endfunction

" The Stack Exchange API's site for a host: stackoverflow.com -> stackoverflow,
" vi.stackexchange.com -> vi; '' for other hosts
function! s:site(host) abort
  let l:host = substitute(a:host, '^www\.', '', '')
  if l:host =~# '^\%(stackoverflow\|superuser\|serverfault\|askubuntu\)\.com$'
    return matchstr(l:host, '^[^.]\+')
  endif
  return matchstr(l:host, '^\zs[[:alnum:]-]\+\ze\.stackexchange\.com$')
endfunction

function! prompts#sources#url#context(request, arg) abort
  let l:url = trim(a:arg)
  let l:m = matchlist(l:url, '^https\=://\([^/?#]\+\)\(/[^?#]*\)\=')
  if empty(l:m)
    return ''
  endif
  let [l:host, l:path] = [l:m[1], l:m[2]]
  let l:gh = matchlist(l:path, '^/\([[:alnum:]_.-]\+/[[:alnum:]_.-]\+\)/\(issues\|pull\)/\(\d\+\)')
  if l:host =~# '^\%(www\.\)\=github\.com$' && !empty(l:gh)
    let [l:repo, l:kind, l:n] = l:gh[1:3]
    if l:kind ==# 'issues'
      return 'GitHub issue ' . l:repo . '#' . l:n . ' (' . l:url . '). Read it with `gh issue view '
            \ . l:n . ' --repo ' . l:repo . ' --comments`. Only read it.'
    endif
    return 'GitHub pull request ' . l:repo . '#' . l:n . ' (' . l:url . '). Read it with `gh pr view '
          \ . l:n . ' --repo ' . l:repo . ' --comments` and `gh pr diff ' . l:n . ' --repo '
          \ . l:repo . '`. Only read it.'
  endif
  let l:site = s:site(l:host)
  let l:se = matchlist(l:path, '^/\%(\(questions\|q\)\|\(a\)\)/\(\d\+\)')
  if !empty(l:site) && !empty(l:se)
    let l:api = 'https://api.stackexchange.com/2.3/'
    if empty(l:se[2])
      return 'Stack Exchange question (' . l:url . '). Read it and its answers with `curl -s --compressed '
            \ . shellescape(l:api . 'questions/' . l:se[3] . '/answers?site=' . l:site
            \ . '&sort=votes&filter=withbody') . '` (the question itself: `questions/' . l:se[3]
            \ . '?site=' . l:site . '&filter=withbody`), or the page. Use the answers that fit'
            \ . ' (accepted, well voted and recent ones first) and say where they disagree.'
    endif
    return 'Stack Exchange answer (' . l:url . '). Read it with `curl -s --compressed '
          \ . shellescape(l:api . 'answers/' . l:se[3] . '?site=' . l:site . '&filter=withbody')
          \ . '`, or the page, and the question it answers.'
  endif
  return 'Read ' . l:url . ', and the pages it links to only as far as my request needs.'
endfunction

" The links in the registers, for #url:<Tab> after copying one
function! prompts#sources#url#complete(lead) abort
  let l:urls = []
  for l:reg in ['"', '+', '*']
    let l:text = getreg(l:reg)
    let l:start = 0
    while 1
      let [l:url, l:_, l:start] = matchstrpos(l:text, 'https\=://[^[:space:]<>"''`]\+', l:start)
      if l:start < 0
        break
      endif
      let l:url = substitute(l:url, '[).,;:]\+$', '', '')
      if stridx(l:url, a:lead) == 0 && index(l:urls, l:url) < 0
        call add(l:urls, l:url)
      endif
    endwhile
  endfor
  return l:urls
endfunction
