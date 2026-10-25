" The agents and their modes: docs/agent.md
"
" Claude's fullscreen renderer doesn't start in a Vim terminal (blank
" window), so vim_terminal picks the classic one. Copilot has no flag for
" manual or assisted approval in a session, so ask and auto start it as its
" config (defaultPermissionMode) says.
let s:agents = {
      \ 'claude': {'cmd': ['claude'], 'prompt': [], 'dir': '--add-dir',
      \   'vim_terminal': ['--settings', '{"tui":"default"}'],
      \   'modes': {'ask': ['--permission-mode', 'default'],
      \     'plan': ['--permission-mode', 'plan'],
      \     'agent': ['--permission-mode', 'acceptEdits'],
      \     'auto': ['--permission-mode', 'auto']}},
      \ 'copilot': {'cmd': ['copilot'], 'prompt': ['-i'], 'dir': '--add-dir',
      \   'modes': {'ask': [], 'plan': ['--plan'], 'agent': ['--allow-tool=write'],
      \     'auto': []}},
      \ }

" Whether :Start runs in a Vim terminal rather than tmux or screen, as
" vim-dispatch decides
function! s:vim_terminal() abort
  return empty($STY) && (get(g:, 'dispatch_no_tmux_start', 0)
        \ || empty($TMUX) && empty(get(g:, 'tmux_session', '')))
endfunction

function! s:error(msg) abort
  echohl ErrorMsg
  echomsg 'vim-prompts: ' . a:msg
  echohl None
endfunction

function! s:table() abort
  return extend(copy(s:agents), get(g:, 'prompts_agent_table', {}))
endfunction

function! s:installed(name) abort
  let l:agent = get(s:table(), a:name, {})
  return !empty(l:agent) && executable(l:agent.cmd[0])
endfunction

function! s:pick(meta, forced) abort
  if !empty(a:forced)
    if !has_key(s:table(), a:forced)
      call s:error('unknown agent ' . a:forced . ' (g:prompts_agent_table)')
      return ''
    elseif !s:installed(a:forced)
      call s:error(s:table()[a:forced].cmd[0] . ' is not executable')
      return ''
    endif
    return a:forced
  endif
  let l:wanted = get(a:meta, 'agent', '')
  if !empty(l:wanted) && s:installed(l:wanted)
    return l:wanted
  endif
  let l:agents = get(g:, 'prompts_agents', ['claude', 'copilot'])
  for l:name in l:agents
    if s:installed(l:name)
      if !empty(l:wanted)
        echomsg 'vim-prompts: ' . l:wanted . ' is not installed, using ' . l:name
      endif
      return l:name
    endif
  endfor
  call s:error('no agent CLI found (' . join(l:agents, ', ')
        \ . '); install one or set g:prompts_agent')
  return ''
endfunction

function! s:args(meta, name) abort
  let l:args = get(a:meta, 'args', [])
  let l:args = type(l:args) == v:t_dict ? get(l:args, a:name, []) : l:args
  return type(l:args) == v:t_list ? copy(l:args) : [l:args]
endfunction

" Counts asks so no two :Start commands are the same
let s:asked = 0
function! s:prompt_file(prompt) abort
  let s:asked += 1
  let l:dir = FugitiveGitDir()
  let l:file = empty(l:dir) ? tempname() . '.md'
        \ : printf('%s/vim-prompts/prompts/%s-%d.md', l:dir, strftime('%Y%m%d-%H%M%S'), s:asked)
  call mkdir(fnamemodify(l:file, ':h'), 'p')
  " A leading - would be taken for an option of the agent
  call writefile(split((a:prompt =~# '^-' ? ' ' : '') . a:prompt, "\n", 1), l:file)
  return l:file
endfunction

function! s:mode(meta) abort
  let l:mode = get(a:meta, 'mode', '')
  return empty(l:mode) ? get(g:, 'prompts_mode', 'ask') : l:mode
endfunction

function! prompts#agent#command(meta, dirs) abort
  let l:name = s:pick(a:meta, get(g:, 'prompts_agent', ''))
  if empty(l:name)
    return []
  endif
  let l:agent = s:table()[l:name]
  let l:mode = s:mode(a:meta)
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
  let l:before = l:agent.cmd + (s:vim_terminal() ? get(l:agent, 'vim_terminal', []) : [])
        \ + get(l:modes, l:mode, [])
  return [l:name, l:before + s:args(a:meta, l:name) + l:agent.prompt, l:after]
endfunction

function! prompts#agent#launch(prompt, meta, dirs) abort
  let l:command = prompts#agent#command(a:meta, a:dirs)
  if empty(l:command)
    return 0
  endif
  let [l:name, l:argv, l:after] = l:command
  if empty(a:prompt)
    let l:argv = l:argv[: -1 - len(s:table()[l:name].prompt)]
  endif
  let l:cmd = join(map(l:argv, 'shellescape(v:val)'))
  if !empty(a:prompt)
    let l:file = s:prompt_file(a:prompt)
    " From a file, so its length doesn't matter to tmux
    let l:cmd .= strlen(a:prompt) <= get(g:, 'prompts_max_arg', 100000)
          \ ? ' "$(cat ' . shellescape(l:file) . ')"'
          \ : ' ' . shellescape('My request and its context are in ' . l:file
          \ . '. Read it first, then follow it.')
  endif
  let l:cmd .= join([''] + map(l:after, 'shellescape(v:val)'))
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

function! s:job_mode(bufnr, timer) abort
  if bufnr() == a:bufnr && term_getstatus(a:bufnr) =~# '\<normal\>'
    call feedkeys('i', 'n')
  endif
endfunction
