" The agents and their modes: docs/agent.md
"
" Claude's fullscreen renderer doesn't start in a Vim terminal (blank
" window), so vim_terminal picks the classic one. Copilot has no flag for
" manual or assisted approval in a session, so ask and auto start it as its
" config (defaultPermissionMode) says.
let s:agents = {
      \ 'claude': {'cmd': ['claude'], 'prompt': [], 'oneoff': ['-p'], 'dir': '--add-dir',
      \   'vim_terminal': ['--settings', '{"tui":"default"}'],
      \   'modes': {'ask': ['--permission-mode', 'default'],
      \     'plan': ['--permission-mode', 'plan'],
      \     'agent': ['--permission-mode', 'acceptEdits'],
      \     'auto': ['--permission-mode', 'auto']}},
      \ 'copilot': {'cmd': ['copilot'], 'prompt': ['-i'], 'oneoff': ['-p'], 'dir': '--add-dir',
      \   'modes': {'ask': [], 'plan': ['--plan'], 'agent': ['--allow-tool=write'],
      \     'auto': []}},
      \ }

function! s:table() abort
  return extend(copy(s:agents), get(g:, 'prompts_agent_table', {}))
endfunction

function! s:installed(name) abort
  let l:agent = get(s:table(), a:name, {})
  return !empty(l:agent) && executable(l:agent.cmd[0])
endfunction

" Counts asks so no two :Start commands are the same
let s:asked = 0

" With {oneoff}, the arguments to answer once and exit, and no terminal's
function! prompts#agent#command(meta, dirs, ...) abort
  let l:oneoff = get(a:, 1, 0)
  let l:table = s:table()
  let l:name = get(g:, 'prompts_agent', '')
  let l:wanted = get(a:meta, 'agent', '')
  if !empty(l:name)
    if !has_key(l:table, l:name)
      call prompts#error('unknown agent ' . l:name . ' (g:prompts_agent_table)')
      return []
    elseif !s:installed(l:name)
      call prompts#error(l:table[l:name].cmd[0] . ' is not executable')
      return []
    endif
  elseif !empty(l:wanted) && s:installed(l:wanted)
    let l:name = l:wanted
  else
    let l:agents = get(g:, 'prompts_agents', ['claude', 'copilot'])
    let l:name = get(filter(copy(l:agents), 's:installed(v:val)'), 0, '')
    if empty(l:name)
      call prompts#error('no agent CLI found (' . join(l:agents, ', ')
            \ . '); install one or set g:prompts_agent')
      return []
    elseif !empty(l:wanted)
      echomsg 'vim-prompts: ' . l:wanted . ' is not installed, using ' . l:name
    endif
  endif
  let l:agent = l:table[l:name]
  let l:mode = get(a:meta, 'mode', '')
  let l:mode = empty(l:mode) ? get(g:, 'prompts_mode', 'ask') : l:mode
  let l:modes = get(l:agent, 'modes', {})
  if !has_key(l:modes, l:mode)
    echomsg 'vim-prompts: ' . l:name . ' has no ' . l:mode
          \ . ' mode (g:prompts_agent_table), starting it as is'
  endif
  " After the prompt: claude's --add-dir takes several
  let l:after = []
  for l:dir in a:dirs
    let l:after += empty(get(l:agent, 'dir', '')) ? [] : [l:agent.dir, l:dir]
  endfor
  let l:args = get(a:meta, 'args', [])
  let l:args = type(l:args) == v:t_dict ? get(l:args, l:name, []) : l:args
  " Whether :Start runs in a Vim terminal rather than tmux or screen, as
  " vim-dispatch decides, comes first
  return [l:name, l:agent.cmd + (!l:oneoff && empty($STY) && (get(g:, 'dispatch_no_tmux_start', 0)
        \ || empty($TMUX) && empty(get(g:, 'tmux_session', ''))) ? get(l:agent, 'vim_terminal', []) : [])
        \ + get(l:modes, l:mode, []) + (type(l:args) == v:t_list ? copy(l:args) : [l:args])
        \ + (l:oneoff ? get(l:agent, 'oneoff', ['-p']) : l:agent.prompt), l:after]
endfunction

" Without a prompt, its option goes too
function! s:argv(name, argv, prompt) abort
  return empty(a:prompt) ? a:argv[: -1 - len(s:table()[a:name].prompt)] : a:argv
endfunction

" The command line an ask would run, <prompt> standing for the prompt's
" text; '' without an agent
function! prompts#agent#line(meta, dirs, oneoff, prompt) abort
  let l:command = prompts#agent#command(a:meta, a:dirs, a:oneoff)
  if empty(l:command)
    return ''
  endif
  let [l:name, l:argv, l:after] = l:command
  return join(s:argv(l:name, l:argv, a:prompt ? 'x' : '') + (a:prompt ? ['<prompt>'] : []) + l:after)
endfunction

function! prompts#agent#launch(prompt, meta, dirs) abort
  let l:command = prompts#agent#command(a:meta, a:dirs)
  if empty(l:command)
    return 0
  endif
  let [l:name, l:argv, l:after] = l:command
  let l:argv = s:argv(l:name, l:argv, a:prompt)
  let l:cmd = s:shell(l:argv, a:prompt, l:after)
  let l:tree = FugitiveWorkTree()
  " Modifiers place a Vim terminal (your :Start strategy may use tmux
  " instead): an agent's TUI wants the room of a tab
  execute get(g:, 'prompts_start_mods', 'tab') . ' Start -wait=error -title=' . l:name
        \ . ' -dir=' . fnameescape(empty(l:tree) ? getcwd() : l:tree) . ' ' . l:cmd
  if &buftype ==# 'terminal'
    " Started from a callback (a file picker's), the terminal is left in
    " Terminal-Normal mode, where its window stays blank: once the callback
    " is done, go to Terminal-Job mode so the agent shows and takes the keys
    call timer_start(0, function('s:job_mode', [bufnr()]))
  endif
  return 1
endfunction

" Where prompts are written: vim-draft says, in a linked work tree's own git
" dir, which git removes with the work tree, as the prompts are of no use
" after it (fugitive-extras' comment saves, which outlive work trees and
" branches, go in the common one). Outside a repository, vim-draft's save
" directory, not tempname(): Vim deletes that on exit, and the agent may read
" a long prompt after Vim exits.
function! s:prompts_dir() abort
  return roumail_draft#dir('vim-prompts/prompts', {'worktree': 1})
endfunction

" Keeps the newest g:prompts_keep (50) prompts in dir: their names start
" with the time, so sorted they are oldest first
function! s:prune(dir) abort
  let l:keep = max([1, get(g:, 'prompts_keep', 50)])
  for l:file in sort(glob(a:dir . '/*.md', 1, 1))[: -l:keep - 1]
    call delete(l:file)
  endfor
endfunction

" The agent's command line, its prompt read from a file
function! s:shell(argv, prompt, after) abort
  let l:cmd = join(map(copy(a:argv), 'shellescape(v:val)'))
  if !empty(a:prompt)
    let s:asked += 1
    let l:dir = s:prompts_dir()
    let l:file = printf('%s/%s-%04d.md', l:dir, strftime('%Y%m%d-%H%M%S'), s:asked)
    call mkdir(l:dir, 'p')
    " A leading - would be taken for an option of the agent
    call writefile(split((a:prompt =~# '^-' ? ' ' : '') . a:prompt, "\n", 1), l:file)
    call s:prune(l:dir)
    " From a file, so its length doesn't matter to tmux
    let l:cmd .= strlen(a:prompt) <= get(g:, 'prompts_max_arg', 100000)
          \ ? ' "$(cat ' . shellescape(l:file) . ')"'
          \ : ' ' . shellescape('My request and its context are in ' . l:file
          \ . '. Read it first, then follow it.')
  endif
  return l:cmd . join([''] + map(copy(a:after), 'shellescape(v:val)'))
endfunction

" The last one-off's buffer, for :Ai! alone
let s:oneoff = -1

" The agent answers once, in the background, into a scratch buffer; with
" {opts}, into opts.bufnr, and opts.done(status) is called once all of the
" answer is in
function! prompts#agent#oneoff(prompt, meta, dirs, ...) abort
  let l:opts = get(a:, 1, {})
  let l:command = prompts#agent#command(a:meta, a:dirs, 1)
  if empty(l:command)
    return 0
  endif
  let [l:name, l:argv, l:after] = l:command
  let l:cmd = s:shell(l:argv, a:prompt, l:after)
  let l:tree = FugitiveWorkTree()
  if has_key(l:opts, 'bufnr')
    let l:bufnr = l:opts.bufnr
  else
    execute get(g:, 'prompts_oneoff_mods', 'botright') . ' new'
    setlocal buftype=nofile bufhidden=hide noswapfile filetype=markdown
    execute 'silent file' fnameescape('ai-oneoff://' . s:asked)
    let b:prompts_oneoff = l:name . ': answering'
    setlocal statusline=%f%=%{get(b:,'prompts_oneoff','')}\ 
    let s:oneoff = bufnr()
    let l:bufnr = s:oneoff
  endif
  " Output can still come in after the job exits: done waits for both
  let l:state = {'bufnr': l:bufnr, 'name': l:name, 'Done': get(l:opts, 'done', v:null),
        \ 'status': v:null, 'closed': 0}
  call job_start([&shell, &shellcmdflag, l:cmd], {
        \ 'cwd': empty(l:tree) ? getcwd() : l:tree,
        \ 'in_io': 'null', 'out_io': 'buffer', 'out_buf': l:bufnr, 'out_msg': 0,
        \ 'out_modifiable': getbufvar(l:bufnr, '&modifiable'),
        \ 'err_io': 'out', 'exit_cb': function('s:oneoff_exit', [l:state]),
        \ 'close_cb': function('s:oneoff_close', [l:state])})
  if !has_key(l:opts, 'bufnr')
    wincmd p
  endif
  return 1
endfunction

function! s:oneoff_exit(state, job, status) abort
  let a:state.status = a:status
  call s:oneoff_done(a:state)
endfunction

function! s:oneoff_close(state, channel) abort
  let a:state.closed = 1
  call s:oneoff_done(a:state)
endfunction

function! s:oneoff_done(state) abort
  if a:state.status is v:null || !a:state.closed
    return
  endif
  if a:state.Done isnot v:null
    call a:state.Done(a:state.status)
    return
  endif
  call setbufvar(a:state.bufnr, 'prompts_oneoff', a:state.name
        \ . (a:state.status ? ': failed (' . a:state.status . ')' : ': done'))
  redrawstatus!
endfunction

function! prompts#agent#oneoff_last() abort
  if !bufexists(s:oneoff)
    call prompts#error('no one-off yet: :Ai! <question>')
  elseif bufwinnr(s:oneoff) > 0
    execute bufwinnr(s:oneoff) . 'wincmd w'
  else
    execute get(g:, 'prompts_oneoff_mods', 'botright') . ' sbuffer ' . s:oneoff
  endif
endfunction

function! s:job_mode(bufnr, timer) abort
  if bufnr() == a:bufnr && term_getstatus(a:bufnr) =~# '\<normal\>'
    call feedkeys('i', 'n')
  endif
endfunction
