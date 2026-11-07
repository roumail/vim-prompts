" #agent_comments: docs/sources/agent_comments.md
function! prompts#sources#agent_comments#info() abort
  return {'needs': 'a directory to write the file in', 'arg': 'none', 'instruction': 1}
endfunction

" Counts asks, so each gets a file of its own; nothing is created
let s:asked = 0

" What opens the block a one-off's comments come in
let s:fence = '```vim-prompts-comments'

function! prompts#sources#agent_comments#context(request, arg) abort
  let l:dir = prompts#comments#dir(a:request.bufnr)
  let l:place = roumail_place#get(a:request.bufnr)
  let s:asked += 1
  let l:file = printf('%s/%s-%d.txt', l:dir, strftime('%Y%m%d-%H%M%S'), s:asked)
  let l:format = 'One entry per comment: '
        \ . '`path:line: text`, or `path:start-end: text` for a range, `path` relative to `'
        \ . l:place.dir . "` and the lines as they are in the working tree now. `text` starts "
        \ . "with the comment's number and kind when your answer gives them (`3. [blocking] ...`), "
        \ . 'then the comment as you wrote it; its further lines follow, each starting with a tab. '
  " A one-off can't be let write (there is no one to ask): the comments come
  " in the answer, and vim-prompts writes the file once it is in
  if get(a:request, 'oneoff', 0)
    let a:request.comments = l:file
    return 'Besides your answer, list each comment you make on a line of code for me to step '
          \ . 'through in Vim, in a block at the very end of your answer that opens with a line '
          \ . '`' . s:fence . '` and closes with a line ```. ' . l:format
          \ . 'Nothing else in the block: no headings, notes or blank lines. Don''t write any file.'
  endif
  " Outside a repository the file is outside where the agent works: it may
  " write there
  if !l:place.repo && index(a:request.dirs, l:dir) < 0
    call add(a:request.dirs, l:dir)
  endif
  return 'Besides your answer, write each comment you make on a line of code to `' . l:file
        \ . '` (create its directory), for me to step through in Vim. ' . l:format
        \ . 'Nothing else in the file: no headings, notes or blank lines. Write it once your '
        \ . 'answer is final, and end your answer with its path.'
endfunction

" A one-off's answer, in buffer {bufnr}, done: its last block of comments
" goes to {file}, and a line saying so takes its place. How many there were,
" -1 without a block
function! prompts#sources#agent_comments#save(bufnr, file) abort
  let l:lines = getbufline(a:bufnr, 1, '$')
  let l:start = -1
  for l:i in range(len(l:lines) - 1, 0, -1)
    if l:lines[l:i] =~# '^\s*' . s:fence . '\s*$'
      let l:start = l:i
      break
    endif
  endfor
  if l:start < 0
    return -1
  endif
  " Comments' further lines start with a tab, so a closing ``` is the block's
  let l:end = match(l:lines, '^\s*```\s*$', l:start + 1)
  let l:end = l:end < 0 ? len(l:lines) : l:end
  let l:entries = filter(l:lines[l:start + 1 : l:end - 1], 'v:val !~# "^\\s*$"')
  call mkdir(fnamemodify(a:file, ':h'), 'p')
  call writefile(l:entries, a:file)
  let l:count = len(filter(copy(l:entries), 'v:val !~# "^\\t"'))
  let l:note = printf('(%d comment%s saved to %s: :%sComments)', l:count, l:count == 1 ? '' : 's',
        \ fnamemodify(a:file, ':~'), prompts#namespace())
  let l:modifiable = getbufvar(a:bufnr, '&modifiable')
  call setbufvar(a:bufnr, '&modifiable', 1)
  call deletebufline(a:bufnr, l:start + 1, min([l:end + 1, len(l:lines)]))
  call appendbufline(a:bufnr, l:start, l:note)
  call setbufvar(a:bufnr, '&modifiable', l:modifiable)
  return l:count
endfunction
