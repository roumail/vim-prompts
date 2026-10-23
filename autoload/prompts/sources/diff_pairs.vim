" #diff_pairs: every tab's diff, its sides left to right
function! prompts#sources#diff_pairs#info() abort
  return {'needs': 'a diff (:DiffThis, :BranchDiff)', 'arg': 'none'}
endfunction

function! prompts#sources#diff_pairs#context(request, arg) abort
  let l:diffs = []
  for l:tab in gettabinfo()
    let l:sides = []
    for l:winid in l:tab.windows
      if getwinvar(l:winid, '&diff') && prompts#source#is_file(winbufnr(l:winid))
        call add(l:sides, prompts#source#side(winbufnr(l:winid)))
      endif
    endfor
    if len(l:sides) > 1
      call add(l:diffs, '- ' . join(l:sides, ' vs '))
    endif
  endfor
  return empty(l:diffs) ? ''
        \ : "Diffs open in Vim, one per tab:\n" . join(l:diffs, "\n")
        \ . "\nRead a side that is not the work tree with `git show <object>`."
endfunction
