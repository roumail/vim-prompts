" #comments_file: docs/sources/comments_file.md
function! prompts#sources#comments_file#info() abort
  return {'needs': 'a git repository, for the file', 'arg': 'none', 'instruction': 1}
endfunction

" Counts asks, so each gets a file of its own; nothing is created
let s:asked = 0

function! prompts#sources#comments_file#context(request, arg) abort
  let l:dir = prompts#comments#dir(a:request.bufnr)
  if empty(l:dir)
    return ''
  endif
  let s:asked += 1
  return 'Besides your answer, write each comment you make on a line of code to `'
        \ . printf('%s/%s-%d.txt', l:dir, strftime('%Y%m%d-%H%M%S'), s:asked)
        \ . '` (create its directory), for me to step through in Vim. One entry per comment: '
        \ . '`path:line: text`, or `path:start-end: text` for a range, `path` relative to the '
        \ . "repository's root and the lines as they are in the working tree now. `text` starts "
        \ . "with the comment's number and kind when your answer gives them (`3. [blocking] ...`), "
        \ . 'then the comment as you wrote it; its further lines follow, each starting with a tab. '
        \ . 'Nothing else in the file: no headings, notes or blank lines. Write it once your '
        \ . 'answer is final, and end your answer with its path.'
endfunction
