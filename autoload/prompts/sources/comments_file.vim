" #comments_file: docs/sources/comments_file.md
function! prompts#sources#comments_file#info() abort
  return {'needs': 'a git repository, for the file', 'arg': 'none'}
endfunction

function! prompts#sources#comments_file#context(request, arg) abort
  let l:file = prompts#comments#new_file(a:request.bufnr)
  if empty(l:file)
    return ''
  endif
  return 'Besides your answer, write each comment you make on a line of code to `' . l:file
        \ . '` (create its directory), for me to step through in Vim. One entry per comment: '
        \ . '`path:line: text`, or `path:start-end: text` for a range, `path` relative to the '
        \ . "repository's root and the lines as they are in the working tree now. `text` starts "
        \ . "with the comment's number and kind when your answer gives them (`3. [blocking] ...`), "
        \ . 'then the comment as you wrote it; its further lines follow, each starting with a tab. '
        \ . 'Nothing else in the file: no headings, notes or blank lines. Write it once your '
        \ . 'answer is final, and end your answer with its path.'
endfunction
