" Where the agent's comments are kept, as vim-draft says: in the work tree's
" own git dir. '' outside a repository, as their paths are the repository's
function! prompts#comments#dir(bufnr) abort
  return roumail_draft#place(a:bufnr).repo
        \ ? roumail_draft#dir('vim-prompts/comments', {'bufnr': a:bufnr, 'worktree': 1}) : ''
endfunction

function! s:files(dir) abort
  return empty(a:dir) ? []
        \ : sort(map(glob(a:dir . '/*.txt', 1, 1), 'fnamemodify(v:val, ":t")'),
        \   {a, b -> getftime(a:dir . '/' . b) - getftime(a:dir . '/' . a)})
endfunction

function! prompts#comments#complete(lead, cmdline, pos) abort
  if a:lead =~# '[/~.]'
    return getcompletion(a:lead, 'file')
  endif
  return filter(s:files(prompts#comments#dir(bufnr())), 'stridx(v:val, a:lead) == 0')
endfunction

function! s:file(file) abort
  let l:dir = prompts#comments#dir(bufnr())
  let l:files = s:files(l:dir)
  if empty(a:file)
    if empty(l:files)
      call prompts#error('no comments from the agent here: ask with #agent_comments')
      return ''
    endif
    let l:file = l:dir . '/' . l:files[0]
  else
    let l:file = index(l:files, a:file) >= 0 ? l:dir . '/' . a:file : fnamemodify(expand(a:file), ':p')
  endif
  if !filereadable(l:file)
    call prompts#error('no file ' . fnamemodify(l:file, ':~'))
    return ''
  endif
  return l:file
endfunction

" Lines start-end of file, from its buffer when loaded: unsaved edits count
function! prompts#comments#lines(file, start, end) abort
  let l:info = filter(getbufinfo({'bufloaded': 1}), 'fnamemodify(v:val.name, ":p") ==# a:file')
  return !empty(l:info) ? getbufline(l:info[0].bufnr, a:start, a:end)
        \ : filereadable(a:file) ? readfile(a:file, '', a:end)[a:start - 1 :] : []
endfunction

function! prompts#comments#review(file) abort
  let l:file = s:file(a:file)
  if !empty(l:file)
    call fugitive_extras#comments#load(l:file)
  endif
endfunction

" The comments in file as quickfix items under root, and how many lines
" weren't in the format
function! s:parse(file, root) abort
  let l:read = review#read(a:file)
  let l:items = []
  for l:c in l:read.comments
    let l:range = l:c.start . (l:c.end > l:c.start ? '-' . l:c.end : '')
    let l:item = {'filename': a:root . '/' . l:c.path, 'lnum': l:c.start, 'text': l:c.body,
          \ 'user_data': {'path': l:c.path, 'range': l:range, 'n': len(l:items) + 1}}
    if l:c.end > l:c.start
      let l:item.end_lnum = l:c.end
    endif
    call add(l:items, l:item)
  endfor
  return [l:items, l:read.skipped]
endfunction

function! prompts#comments#load(file, ...) abort
  let l:all = get(a:, 1, 0)
  let l:file = s:file(a:file)
  if empty(l:file)
    return
  endif
  let l:root = roumail_draft#place(bufnr()).dir
  let [l:items, l:skipped] = s:parse(l:file, l:root)
  let l:done = s:done(l:file)
  let l:hidden = l:all ? 0 : len(filter(copy(l:items), 'has_key(l:done, v:val.user_data.n)'))
  if !l:all
    call filter(l:items, '!has_key(l:done, v:val.user_data.n)')
  endif
  " A list of its own: fugitive-extras' Review list holds my comments, and
  " :colder goes back to it. Its context says it is, for :AiReply and the
  " keys in its window, and which comments it shows, to tell what dd removed
  call setqflist([], ' ', {'title': 'Agent comments: ' . fnamemodify(l:file, ':t'), 'items': l:items,
        \ 'context': {'prompts_comments': l:file, 'root': l:root, 'shown': s:shown(l:items)}})
  copen
  redraw
  echo 'Agent comments: ' . len(l:items)
        \ . (l:hidden ? ', ' . l:hidden . ' done left out (:' . prompts#namespace() . 'Comments! shows them)' : '')
        \ . (l:skipped ? ', ' . l:skipped . ' line(s) not in the format, left out' : '')
endfunction

" The comments done in a file, by their place in it, kept beside their
" threads
function! s:done_file(file) abort
  return fnamemodify(a:file, ':r') . '/done'
endfunction

function! s:done(file) abort
  let l:done = {}
  for l:n in filereadable(s:done_file(a:file)) ? readfile(s:done_file(a:file)) : []
    let l:done[l:n] = 1
  endfor
  return l:done
endfunction

function! s:shown(items) abort
  return map(filter(copy(a:items), 'type(get(v:val, "user_data")) == v:t_dict && has_key(v:val.user_data, "n")'),
        \ 'v:val.user_data.n')
endfunction

" User QfToolsChanged: in the agent's list, what dd removed since the list
" was last seen is done, and what u put back isn't. By difference, so a list
" shown with ! takes back nothing it didn't change
function! prompts#comments#sync_done() abort
  if !prompts#comments#in_list()
    return
  endif
  let l:list = s:list()
  let l:before = get(l:list, 'shown', [])
  let l:now = s:shown(getqflist({'items': 1}).items)
  let l:done = s:done(l:list.prompts_comments)
  for l:n in l:before
    if index(l:now, l:n) < 0
      let l:done[l:n] = 1
    endif
  endfor
  for l:n in l:now
    if index(l:before, l:n) < 0
      silent! call remove(l:done, l:n)
    endif
  endfor
  call mkdir(fnamemodify(s:done_file(l:list.prompts_comments), ':h'), 'p')
  call writefile(sort(keys(l:done), 'N'), s:done_file(l:list.prompts_comments))
  call setqflist([], 'r', {'context': extend(l:list, {'shown': l:now})})
endfunction

" The context of the current quickfix list when it is one of the agent's
" comments, else {}
function! s:list() abort
  let l:context = getqflist({'context': 0}).context
  return type(l:context) == v:t_dict && has_key(l:context, 'prompts_comments') ? l:context : {}
endfunction

" In the quickfix window, showing the agent's comments: for a/= to be
" vim-prompts' there and Vim's elsewhere
function! prompts#comments#in_list() abort
  return &buftype ==# 'quickfix' && !getwininfo(win_getid())[0].loclist && !empty(s:list())
endfunction

" The comment a reply is to: in a thread's buffer, its comment; in the
" quickfix window, the one under the cursor; elsewhere, the current entry of
" the agent's comments. {} with an error when there is none
function! s:target() abort
  if exists('b:prompts_thread')
    return b:prompts_thread
  endif
  let l:list = s:list()
  if empty(l:list) || &buftype ==# 'quickfix' && getwininfo(win_getid())[0].loclist
    call prompts#error('not on an agent comment: :' . prompts#namespace()
          \ . 'Comments, then go to one')
    return {}
  endif
  let l:n = &buftype ==# 'quickfix' ? line('.') : getqflist({'idx': 0}).idx
  let l:item = get(getqflist({'items': 1}).items, l:n - 1, {})
  if empty(l:item) || type(get(l:item, 'user_data')) != v:t_dict
    call prompts#error('not on an agent comment')
    return {}
  endif
  let l:where = l:item.user_data
  " Its thread is named for its place in the file, which stays when entries
  " above it are deleted from the list
  return {'thread': fnamemodify(l:list.prompts_comments, ':r') . '/' . get(l:where, 'n', l:n) . '.md',
        \ 'file': l:list.root . '/' . l:where.path,
        \ 'bufnr': l:item.bufnr, 'start': l:item.lnum, 'end': max([l:item.lnum, get(l:item, 'end_lnum', 0)]),
        \ 'label': l:where.path . ':' . l:where.range, 'text': l:item.text}
endfunction

" The thread's buffer, from its file, which starts with the comment
function! s:thread_buffer(target) abort
  let l:name = 'ai-thread://' . a:target.label . ' ' . fnamemodify(a:target.thread, ':h:t')
        \ . '#' . fnamemodify(a:target.thread, ':t:r')
  " The one of that name, if there is one
  let l:bufnr = bufadd(l:name)
  if !bufloaded(l:bufnr)
    call bufload(l:bufnr)
    call setbufvar(l:bufnr, '&buftype', 'nofile')
    call setbufvar(l:bufnr, '&bufhidden', 'hide')
    call setbufvar(l:bufnr, '&swapfile', 0)
    call setbufvar(l:bufnr, '&filetype', 'markdown')
    call setbufvar(l:bufnr, '&modifiable', 0)
    call setbufvar(l:bufnr, 'prompts_thread', a:target)
  endif
  if !filereadable(a:target.thread)
    call mkdir(fnamemodify(a:target.thread, ':h'), 'p')
    call writefile(['# ' . a:target.label, '', '## agent', ''] + split(a:target.text, "\n", 1),
          \ a:target.thread)
  endif
  " The file is the thread; the buffer only shows it
  if !getbufvar(l:bufnr, 'prompts_answering', 0)
    call s:edit(l:bufnr, {-> deletebufline(l:bufnr, 1, '$')
          \ + setbufline(l:bufnr, 1, readfile(a:target.thread))})
  endif
  return l:bufnr
endfunction

" A thread's buffer is read-only: what is in it is read back into its file,
" so only vim-prompts changes it
function! s:edit(bufnr, Change) abort
  call setbufvar(a:bufnr, '&modifiable', 1)
  try
    call a:Change()
  finally
    call setbufvar(a:bufnr, '&modifiable', 0)
  endtry
endfunction

" Shows the buffer above the current window, unless it is shown; with
" {stay}, the cursor stays where it was
function! s:show(bufnr, stay) abort
  let l:win = bufwinid(a:bufnr)
  if l:win > 0
    if !a:stay
      call win_gotoid(l:win)
    endif
    return
  endif
  execute 'aboveleft sbuffer' a:bufnr
  let &l:statusline = '%f%=%{get(b:,"prompts_answering",0)?"agent: answering":""}'
        \ . '  :' . prompts#namespace() . 'Reply  :' . prompts#namespace() . 'Reply! in a session '
  if a:stay
    wincmd p
  endif
endfunction

" = and :AiThread: the comment and what was said on it since
function! prompts#comments#thread() abort
  let l:target = s:target()
  if !empty(l:target)
    call s:show(s:thread_buffer(l:target), 0)
    normal! G
  endif
endfunction

" Text typed at the :AiReply prompt and left with <Esc>, by thread, to start
" from when replying on that comment again
let s:unsent = {}

" :AiReply[!]: sends text, or what is typed at the prompt, on the comment.
" What was typed and left with <Esc> is kept for the next :AiReply or
" :AiReplyDraft on that comment, so you can look something up and go on
function! prompts#comments#reply(session, text) abort
  let l:target = s:target()
  if empty(l:target)
    return
  endif
  let l:text = a:text
  if empty(l:text)
    let s:typed = get(s:unsent, l:target.thread, '')
    " CmdlineLeave is too late: <Esc> has emptied the line by then
    augroup prompts_reply
      autocmd!
      autocmd CmdlineChanged @ let s:typed = getcmdline()
    augroup END
    try
      let l:text = input('Reply ' . (a:session ? 'in a session, ' : '') . l:target.label . ': ',
            \ s:typed, 'customlist,prompts#comments#complete_reply')
    finally
      autocmd! prompts_reply
    endtry
    if empty(l:text) && !empty(s:typed)
      let s:unsent[l:target.thread] = s:typed
      redraw
      echo 'Reply kept: :' . prompts#namespace() . 'Reply or :' . prompts#namespace()
            \ . 'ReplyDraft on ' . l:target.label . ' goes on from it'
      return
    endif
  endif
  silent! call remove(s:unsent, l:target.thread)
  if empty(trim(l:text))
    return
  endif
  redraw
  if !s:send(a:session, l:target, trim(l:text))
    let s:unsent[l:target.thread] = trim(l:text)
    echomsg 'vim-prompts: reply kept: :' . prompts#namespace() . 'Reply on '
          \ . l:target.label . ' goes on from it'
  endif
endfunction

" :AiReplyDraft[!] (a): the reply in a draft, starting with text, else with
" what was left at the :AiReply prompt on that comment
function! prompts#comments#reply_draft(session, text) abort
  let l:target = s:target()
  if empty(l:target)
    return
  endif
  let l:text = empty(a:text) ? get(s:unsent, l:target.thread, '') : a:text
  silent! call remove(s:unsent, l:target.thread)
  call s:open_draft(a:session, l:target, empty(l:text) ? [] : split(l:text, "\n", 1))
endfunction

function! s:open_draft(session, target, lines) abort
  let l:git_dir = FugitiveGitDir(a:target.bufnr)
  call roumail_draft#open('ai-reply://' . a:target.label, a:lines,
        \ function('s:send_draft', [a:session, a:target]),
        \ {'split': 'aboveleft '
        \     . get(g:, 'prompts_reply_height', 10) . 'new',
        \  'saved': 'Reply saved: closing sends it',
        \  'empty': 'Reply empty: closing sends nothing'})
  setlocal filetype=markdown
  " Its repository, for what completes in it, as in an :AiDraft
  if !empty(l:git_dir)
    let b:git_dir = l:git_dir
  endif
  let &l:statusline = '%f%=' . (a:session ? 'to a session  ' : '')
        \ . ':w saves, closing sends, :q! drops '
endfunction

function! s:send_draft(session, target, text) abort
  " Once the draft's window is closed; if the reply can't go, the draft is
  " back with it
  call timer_start(0, {-> s:send(a:session, a:target, a:text)
        \ || s:open_draft(a:session, a:target, split(a:text, "\n", 1))})
endfunction

" At the :AiReply prompt, what completes after :Ai
function! prompts#comments#complete_reply(lead, line, pos) abort
  return prompts#complete(a:lead, 'Ai ' . a:line, a:pos + 3)
endfunction

" What goes before the reply: the comment, its lines, what was said since
function! s:before(target, session) abort
  let l:thread = readfile(a:target.thread)
  let l:ft = getbufvar(a:target.bufnr, '&filetype')
  let l:lines = prompts#comments#lines(a:target.file, a:target.start, a:target.end)
  let l:fence = match(l:lines, '^\s*```') >= 0 ? '````' : '```'
  return 'This is about a comment you made on my code, on ' . a:target.label
        \ . ". The lines it is on, as they are now:\n\n" . l:fence . l:ft . "\n"
        \ . join(l:lines, "\n") . "\n" . l:fence . "\n\n"
        \ . 'Your comment, and what we have said on it since (`## agent` is you, `## me` is me):'
        \ . "\n\n" . join(l:thread[1:], "\n") . "\n\n"
        \ . 'My reply on it follows. Answer it'
        \ . (a:session ? '' : ', on this comment only') . '; if it changes your mind about '
        \ . "the comment, say how.\n\n## me"
endfunction

" 1 once the reply is under way, 0 when it stopped at an error
function! s:send(session, target, text) abort
  let l:bufnr = s:thread_buffer(a:target)
  if getbufvar(l:bufnr, 'prompts_answering', 0)
    call prompts#error('the agent is still answering on ' . a:target.label)
    return 0
  endif
  return prompts#ask_from(!a:session, a:target.bufnr, a:target.start, s:before(a:target, a:session),
        \ a:text, function('s:sent', [a:session, a:target, l:bufnr]))
endfunction

function! s:sent(session, target, bufnr, persona, request, prompt) abort
  let l:me = ['', '## me' . (a:session ? ' (in a session, which has the answer)' : ''), '']
        \ + split(a:request.query, "\n", 1)
  if a:session
    if prompts#agent#launch(a:prompt, a:persona.meta, a:request.dirs)
      call writefile(l:me, a:target.thread, 'a')
    endif
    return
  endif
  " The answer goes below what is appended here: the job's output is only
  " read once this function returns
  let l:answer = {}
  if !prompts#agent#oneoff(a:prompt, a:persona.meta, a:request.dirs,
        \ {'bufnr': a:bufnr, 'done': function('s:answered', [a:target, a:bufnr, l:answer])})
    return
  endif
  call writefile(l:me, a:target.thread, 'a')
  call s:edit(a:bufnr, {-> appendbufline(a:bufnr, '$', l:me + ['', '## agent'])})
  " The answer's first line, wherever it is in the buffer
  let l:answer.line = len(getbufline(a:bufnr, 1, '$')) + 1
  call setbufvar(a:bufnr, 'prompts_answering', 1)
  call s:show(a:bufnr, 1)
  redrawstatus!
  echo 'Asked on ' . a:target.label . ': the answer comes in above'
endfunction

" Once the agent is done: its answer goes in the thread's file
function! s:answered(target, bufnr, at, status) abort
  call setbufvar(a:bufnr, 'prompts_answering', 0)
  let l:answer = getbufline(a:bufnr, a:at.line, '$')
  while !empty(l:answer) && l:answer[-1] =~# '^\s*$'
    call remove(l:answer, -1)
  endwhile
  " Blank between the heading and the answer, as in the file
  call s:edit(a:bufnr, {-> appendbufline(a:bufnr, a:at.line - 1, '')})
  if a:status
    call add(l:answer, '(the agent failed: ' . a:status . ')')
    call s:edit(a:bufnr, {-> appendbufline(a:bufnr, '$', l:answer[-1])})
  endif
  call writefile(['', '## agent', ''] + l:answer, a:target.thread, 'a')
  redrawstatus!
  echo a:status ? 'The agent failed on ' . a:target.label
        \ : 'Answered on ' . a:target.label . ': = shows the thread'
endfunction

" :AiCommentsList: the reviews here, newest first, one a line: when, how many
" comments, done and threads, and the files they are on. <CR> opens one as
" :AiComments, dd clears it as :AiCommentsClear
function! prompts#comments#list() abort
  let l:dir = prompts#comments#dir(bufnr())
  if empty(l:dir)
    call prompts#error('no comments from the agent outside a repository')
    return
  endif
  call roumail_lists#open('ai-comments://' . fnamemodify(roumail_draft#place(bufnr()).dir, ':t'), {
        \ 'fetch': function('s:list_fetch'),
        \ 'heading': {reviews -> ['Agent reviews (' . len(reviews) . ')']},
        \ 'rows': function('s:list_rows'), 'id': {r -> r.name},
        \ 'match': {r -> r.name . ' ' . join(r.paths)},
        \ 'keys': [{'key': '<CR>', 'hint': 'open', 'call': function('s:list_open')},
        \          {'key': 'dd', 'hint': 'clear', 'call': function('s:list_clear')}]},
        \ {'prompts_comments_dir': l:dir})
endfunction

function! s:list_fetch() abort
  let l:reviews = []
  for l:name in s:files(b:prompts_comments_dir)
    let l:file = b:prompts_comments_dir . '/' . l:name
    let l:items = s:parse(l:file, '')[0]
    let l:paths = []
    for l:item in l:items
      if index(l:paths, l:item.user_data.path) < 0
        call add(l:paths, l:item.user_data.path)
      endif
    endfor
    call add(l:reviews, {'name': l:name, 'file': l:file, 'comments': len(l:items),
          \ 'done': len(s:done(l:file)), 'paths': map(l:paths, 'fnamemodify(v:val, ":t")'),
          \ 'threads': len(glob(fnamemodify(l:file, ':r') . '/*.md', 1, 1))})
  endfor
  return l:reviews
endfunction

function! s:list_rows(reviews) abort
  if empty(s:files(b:prompts_comments_dir))
    return [{'lines': ['(no reviews here: ask with #agent_comments)']}]
  endif
  return map(copy(a:reviews), {_, r -> {'item': r, 'lines': [printf(
        \ '%-20s  %s  %2d comments  %2d done  %2d threads  %s',
        \ fnamemodify(r.name, ':r'), strftime('%Y-%m-%d %H:%M', getftime(r.file)),
        \ r.comments, r.done, r.threads, join(r.paths, ', '))]}})
endfunction

function! s:list_open() abort
  let l:review = roumail_lists#item()
  if !empty(l:review)
    wincmd p
    call prompts#comments#load(l:review.file)
  endif
endfunction

function! s:list_clear() abort
  let l:review = roumail_lists#item()
  if !empty(l:review)
    call prompts#comments#clear(l:review.file)
    call roumail_lists#refresh()
  endif
endfunction

" :AiCommentsClear [file]: deletes a review, its threads and what is done in
" it, once you say so. Without file, the one in the agent's list
function! prompts#comments#clear(file) abort
  if empty(a:file)
    let l:list = s:list()
    if empty(l:list)
      call prompts#error('which review? :' . prompts#namespace() . 'CommentsClear <Tab>, or from :'
            \ . prompts#namespace() . 'Comments')
      return
    endif
    let l:file = l:list.prompts_comments
  else
    let l:file = s:file(a:file)
    if empty(l:file)
      return
    endif
  endif
  let l:dir = fnamemodify(l:file, ':r')
  let l:threads = filter(getbufinfo(), 'type(get(v:val.variables, "prompts_thread")) == v:t_dict'
        \ . ' && stridx(v:val.variables.prompts_thread.thread, l:dir . "/") == 0')
  if !empty(filter(copy(l:threads), 'get(v:val.variables, "prompts_answering", 0)'))
    call prompts#error('the agent is still answering in a thread of ' . fnamemodify(l:file, ':t'))
    return
  endif
  let l:count = len(s:parse(l:file, '')[0])
  let l:nthreads = len(glob(l:dir . '/*.md', 1, 1))
  if confirm('Delete ' . fnamemodify(l:file, ':t') . ': ' . l:count . ' comments, '
        \ . l:nthreads . ' threads?', "&Yes\n&No", 2) != 1
    return
  endif
  for l:info in l:threads
    execute 'silent! bwipeout!' l:info.bufnr
  endfor
  call delete(l:dir, 'rf')
  call delete(l:file)
  " Its list, if shown, is of nothing now
  for l:nr in range(1, getqflist({'nr': '$'}).nr)
    let l:context = getqflist({'nr': l:nr, 'context': 0}).context
    if type(l:context) == v:t_dict && get(l:context, 'prompts_comments', '') ==# l:file
      call setqflist([], 'r', {'nr': l:nr, 'items': [], 'context': {},
            \ 'title': 'Agent comments: ' . fnamemodify(l:file, ':t') . ' (cleared)'})
    endif
  endfor
  redraw
  echo 'Cleared ' . fnamemodify(l:file, ':t')
endfunction
