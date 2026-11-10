" Headless tests, from the repository's root:
"   vim -Nu NONE -i NONE -Es -S test/run.vim
" Prints one line per test and exits non-zero when one fails; TEST=<pattern>
" in the environment runs the tests whose names match.
"
" HOME is a copy of examples/briefing/home, with its repository made as the
" example's README says, on a branch with a change. The plugins come from
" $PLUGINS (default: the directory this one is in), else vim-plug's copies.
set nocompatible hidden noswapfile
let s:root = expand('<sfile>:p:h:h')
let s:plugins = empty($PLUGINS) ? fnamemodify(s:root, ':h') : $PLUGINS
function! s:plugin(name) abort
  let l:dir = s:plugins . '/' . a:name
  return isdirectory(l:dir) ? l:dir : expand('~/.vim/plugged/') . a:name
endfunction
let s:paths = [s:root] + map(['vim-fugitive', 'vim-dispatch', 'vim-place', 'vim-lists',
      \ 'fugitive-extras', 'vim-review', 'vim-draft'], 's:plugin(v:val)')
for s:path in reverse(copy(s:paths))
  execute 'set runtimepath^=' . fnameescape(s:path)
endfor
for s:path in s:paths
  for s:file in glob(s:path . '/plugin/*.vim', 1, 1)
    execute 'source' fnameescape(s:file)
  endfor
endfor

let s:tmp = resolve(tempname())
let $HOME = s:tmp . '/home'
let $XDG_CONFIG_HOME = ''
let $GIT_CONFIG_NOSYSTEM = '1'
call mkdir(s:tmp, 'p')
call system('cp -R ' . shellescape(s:root . '/examples/briefing/home') . ' ' . shellescape($HOME))
let s:app = $HOME . '/work/app'
function! s:git(...) abort
  let l:out = system('git -C ' . shellescape(s:app) . ' -c user.name=t -c user.email=t@t '
        \ . join(map(copy(a:000), 'shellescape(v:val)')))
  if v:shell_error
    throw 'git ' . join(a:000) . ': ' . l:out
  endif
  return l:out
endfunction
call mkdir(s:app, 'p')
call s:git('init', '-q', '-b', 'main')
call writefile(readfile(s:root . '/examples/briefing/app.gitconfig'), s:app . '/.git/config', 'a')
call writefile(['def add(a, b):', '    return a + b'], s:app . '/app.py')
call s:git('add', '.')
call s:git('commit', '-q', '-m', 'init')
call s:git('checkout', '-q', '-b', 'feature')
call writefile(['def add(a, b):', '    return a - b'], s:app . '/app.py')
call s:git('commit', '-qam', 'subtract')
call mkdir(s:tmp . '/plain', 'p')
call writefile(['notes'], s:tmp . '/plain/notes.txt')
" Where vim-place keeps files outside a repository
let $XDG_STATE_HOME = s:tmp . '/saves'

" An agent that is always there, so :AiPreview shows its command line
let g:prompts_agent_table = {'fake': {'cmd': ['true'], 'prompt': [], 'dir': '--add-dir',
      \ 'modes': {'ask': [], 'plan': [], 'agent': [], 'auto': []}}}
let g:prompts_agent = 'fake'
let s:out = []

function! s:reset() abort
  silent! only!
  silent! %bwipeout!
  execute 'cd' fnameescape(s:app)
  execute 'edit' fnameescape(s:app . '/app.py')
  messages clear
endfunction

" :AiPreview {args}: the prompt it shows, the command line it would run,
" and the errors, as {prompt, line, errors}
function! s:preview(args, ...) abort
  let l:range = get(a:, 1, '')
  messages clear
  silent! bwipeout ai-preview://
  let l:from = bufnr()
  execute l:range . 'AiPreview ' . a:args
  let l:errors = filter(split(execute('messages'), "\n"), 'v:val =~# "^vim-prompts: "')
  let l:result = {'prompt': '', 'line': '', 'errors': map(l:errors, 'v:val[13:]')}
  if bufname() ==# 'ai-preview://'
    let l:result.prompt = join(getline(1, '$'), "\n")
    let l:result.line = &l:statusline
    wincmd p
  endif
  return l:result
endfunction

function! s:test_variant_builds_on_persona() abort
  let l:r = s:preview('/review:pr')
  call assert_equal([], l:r.errors)
  " The bundled /review, yours on it, the handbook's variant on that, and the
  " bundled variant's change
  call assert_match('I am reviewing code in Vim', l:r.prompt)
  call assert_match('Also check the error messages read well', l:r.prompt)
  call assert_match('Check that each change comes with a test', l:r.prompt)
  call assert_match('Tests run against the shared fixtures', l:r.prompt)
  call assert_match('Changes on this branch since it forked from main', l:r.prompt)
  call assert_match('- M app.py', l:r.prompt)
endfunction

function! s:test_review_has_no_changes() abort
  let l:r = s:preview('/review', '%')
  call assert_equal([], l:r.errors)
  call assert_match('Selected lines, app.py:1-2', l:r.prompt)
  call assert_notmatch('Changes on this branch', l:r.prompt)
  call assert_notmatch('Check that each change comes with a test', l:r.prompt)
  " Its comments come in its answer
  call assert_match('```vim-prompts-comments', l:r.prompt)
endfunction

function! s:test_review_needs_something() abort
  let l:r = s:preview('/review is this right')
  call assert_equal('', l:r.prompt)
  call assert_equal(['/review needs something to work on: a selection, an @file or a #source;'
        \ . ' --force sends it without'], l:r.errors)
  let l:r = s:preview('/review --force is this right')
  call assert_equal([], l:r.errors)
  call assert_match('is this right', l:r.prompt)
  " A file is something
  let l:r = s:preview('/review @app.py')
  call assert_equal([], l:r.errors)
endfunction

function! s:test_variant_needs_its_sources() abort
  call s:git('checkout', '-q', 'main')
  try
    let l:r = s:preview('/review:pr')
    call assert_equal('', l:r.prompt)
    call assert_equal(1, len(l:r.errors))
    call assert_match('^/review:pr needs a diff .*, or changes .*; --force sends it without$',
          \ get(l:r.errors, 0, ''))
  finally
    call s:git('checkout', '-q', 'feature')
  endtry
endfunction

function! s:test_typed_source_replaces_the_personas() abort
  call writefile(['def add(a, b):', '    return b - a'], s:app . '/app.py')
  call s:git('add', 'app.py')
  try
    let l:r = s:preview('/review:pr #changes:staged')
    call assert_equal([], l:r.errors)
    call assert_match('Staged changes', l:r.prompt)
    call assert_notmatch('since it forked from main', l:r.prompt)
  finally
    call s:git('reset', '-q', '--hard')
  endtry
endfunction

function! s:test_alternatives_take_the_first() abort
  " With a diff open, #diff_pairs, not the branch
  Gdiffsplit main
  let l:r = s:preview('/review:pr')
  call assert_equal([], l:r.errors)
  call assert_match('Diffs open in Vim', l:r.prompt)
  call assert_notmatch('Changes on this branch', l:r.prompt)
endfunction

function! s:persona(name, lines) abort
  let l:file = $HOME . '/.config/vim-prompts/personas/' . a:name . '.md'
  call mkdir(fnamemodify(l:file, ':h'), 'p')
  call writefile(a:lines, l:file)
  return l:file
endfunction

function! s:test_missing_persona_rule_refuses() abort
  let l:file = s:persona('strict', ['---', 'context: [here, +nope]', '---', 'Check it.'])
  try
    let l:r = s:preview('/strict')
    call assert_equal('', l:r.prompt)
    call assert_equal(['/strict: +nope has nothing: needs a rules file in'
          \ . ' vim-prompts.task-rules: +<Tab>'], l:r.errors)
    " --force is for nothing to work on, not for a missing rule
    call assert_equal(l:r.errors, s:preview('/strict --force').errors)
  finally
    call delete(l:file)
  endtry
endfunction

function! s:test_optional_persona_rule() abort
  let l:file = s:persona('lenient', ['---', 'context: [here, +nope?, "+testing?"]', '---', 'Check it.'])
  try
    let l:r = s:preview('/lenient')
    call assert_equal([], l:r.errors)
    " Sent where there is one
    call assert_match('Tests run against the shared fixtures', l:r.prompt)
    call writefile(['---', 'context: [here?]', '---', 'x'], l:file)
    call assert_match('only a rule may be missing (+name?), not here?',
          \ get(s:preview('/lenient').errors, 0, ''))
  finally
    call delete(l:file)
  endtry
endfunction

function! s:test_persona_rule_is_sent() abort
  " The handbook's /tests names +testing, which the handbook has
  let l:r = s:preview('/tests')
  call assert_equal([], l:r.errors)
  call assert_match('Tests run against the shared fixtures', l:r.prompt)
endfunction

function! s:test_bad_alternatives() abort
  let l:file = s:persona('bad', ['---', 'context: [[+testing, here]]', '---', 'x'])
  try
    call assert_match('+testing is always sent, not one of \[alternatives\]',
          \ get(s:preview('/bad').errors, 0, ''))
    call writefile(['---', 'context: [[[here]]]', '---', 'x'], l:file)
    call assert_match('one level of \[alternatives\]', get(s:preview('/bad').errors, 0, ''))
    call writefile(['---', 'input: maybe', '---', 'x'], l:file)
    call assert_match('input: required or optional', get(s:preview('/bad').errors, 0, ''))
    call writefile(['---', 'answer: later', '---', 'x'], l:file)
    call assert_match('answer: oneoff or session', get(s:preview('/bad').errors, 0, ''))
  finally
    call delete(l:file)
  endtry
endfunction

function! s:test_variant_without_persona() abort
  let l:dir = $HOME . '/.config/vim-prompts/personas/lonely'
  call mkdir(l:dir, 'p')
  call writefile(['{base}', 'x'], l:dir . '/one.md')
  try
    call assert_match('{base}, but no /lonely below it', get(s:preview('/lonely:one').errors, 0, ''))
    call writefile(['Stand alone.'], l:dir . '/one.md')
    call assert_match('Stand alone.', s:preview('/lonely:one').prompt)
    call assert_match('no persona /lonely ', get(s:preview('/lonely').errors, 0, ''))
  finally
    call delete(l:dir, 'rf')
  endtry
endfunction

function! s:test_bad_variant_name() abort
  let l:dir = $HOME . '/.config/vim-prompts/personas/review'
  call mkdir(l:dir, 'p')
  call writefile(['x'], l:dir . '/no.good.md')
  try
    let l:errors = prompts#persona#errors(prompts#config#get(bufnr()))
    call assert_equal(1, len(l:errors))
    call assert_match('no.good.md: name must be letters, digits, - and _', get(l:errors, 0, ''))
  finally
    call delete(l:dir, 'rf')
  endtry
endfunction

function! s:test_personas_list() abort
  AiPersonas
  let l:lines = getline(1, '$')
  let l:pr = filter(copy(l:lines), 'v:val =~# "^  /review:pr "')
  call assert_equal(1, len(l:pr))
  " The handbook's, on the bundled one, on yours, on the bundled /review
  call assert_match('handbook/personas/review/pr\.md .*#agent_comments \[#diff_pairs #changes\]'
        \ . ' +testing  on {base} \S*/personas/review/pr\.md  on {base} \~/\.config/'
        \ . 'vim-prompts/personas/review\.md  on {base} \S*/personas/review\.md$', get(l:pr, 0, ''))
  let l:file = s:persona('strict', ['---', 'context: [+nope, +gone?]', '---', 'x'])
  try
    AiPersonas!
    call assert_match('/strict .*+nope +gone?  /strict: +nope has nothing',
          \ get(filter(getline(1, '$'), 'v:val =~# "^  /strict "'), 0, ''))
  finally
    call delete(l:file)
  endtry
endfunction

function! s:test_complete_variants() abort
  call assert_equal(['/review', '/review:'], prompts#complete('/rev', 'Ai /rev', 7))
  call assert_equal(['/review:pr'], prompts#complete('/review:', 'Ai /review:', 11))
  call assert_equal(['--force'], prompts#complete('--f', 'Ai --f', 6))
  call assert_true(index(prompts#tokens(), '/review:pr') >= 0)
endfunction

function! s:test_agent_comments_outside_a_repository() abort
  execute 'cd' fnameescape(s:tmp . '/plain')
  execute 'edit' fnameescape(s:tmp . '/plain/notes.txt')
  let l:r = s:preview('#agent_comments', '%')
  call assert_equal([], l:r.errors)
  let l:dir = $XDG_STATE_HOME . '/plain-' . sha256(s:tmp . '/plain')[:7] . '/vim-prompts/comments'
  call assert_match('write each comment .* to `' . l:dir . '/', l:r.prompt)
  call assert_match('relative to `' . s:tmp . '/plain`', l:r.prompt)
  " The agent may write there
  call assert_match('--add-dir ' . l:dir, l:r.line)
  " Comments written there are read back from there
  call writefile(['notes.txt:1: 1. [nit] say more'], l:dir . '/20260101-000000-1.txt')
  call assert_equal(['20260101-000000-1.txt'], prompts#comments#complete('', '', 0))
endfunction

function! s:test_agent_comments_in_a_repository() abort
  let l:r = s:preview('#agent_comments', '%')
  call assert_match('to `' . s:app . '/.git/vim-prompts/comments/', l:r.prompt)
  call assert_notmatch('--add-dir', l:r.line)
endfunction

function! s:test_review_is_a_oneoff() abort
  " /review answers into a buffer, its comments in the answer
  let l:r = s:preview('/review', '%')
  call assert_equal([], l:r.errors)
  call assert_match(' -p <prompt>', l:r.line)
  call assert_match('```vim-prompts-comments', l:r.prompt)
  call assert_notmatch('write each comment', l:r.prompt)
  " A variant too, building on it
  call assert_match(' -p <prompt>', s:preview('/review:pr').line)
endfunction

function! s:test_bang_is_the_other_way() abort
  messages clear
  silent! bwipeout ai-preview://
  %AiPreview! /review
  call assert_notmatch(' -p ', &l:statusline)
  call assert_match('write each comment .* to `' . s:app . '/.git/vim-prompts/comments/',
        \ join(getline(1, '$'), "\n"))
  wincmd p
  " Without answer:, a session, and ! a one-off
  call assert_notmatch(' -p ', s:preview('#agent_comments', '%').line)
  %AiPreview! #agent_comments is this right
  call assert_match(' -p <prompt>', &l:statusline)
  call assert_match('```vim-prompts-comments', join(getline(1, '$'), "\n"))
endfunction

function! s:test_oneoff_runs_in_auto() abort
  let g:prompts_agent_table.modal = {'cmd': ['true'], 'prompt': ['-i'],
        \ 'modes': {'ask': ['--ask'], 'auto': ['--auto']}, 'oneoff_modes': {'auto': ['--yes']}}
  let g:prompts_agent = 'modal'
  try
    " A session asks; a one-off has no one to ask, and its own args win
    call assert_match('true --ask -i <prompt>', s:preview('-- hi').line)
    silent! bwipeout ai-preview://
    AiPreview! -- hi
    call assert_match('true --yes -p <prompt>', &l:statusline)
    wincmd p
    silent! bwipeout ai-preview://
    AiPreview! --ask-mode -- hi
    call assert_match('true --ask -p <prompt>', &l:statusline)
    wincmd p
  finally
    call remove(g:prompts_agent_table, 'modal')
    let g:prompts_agent = 'fake'
  endtry
endfunction

" Copilot's one-off auto, as g:prompts_copilot_approval says
function! s:copilot_oneoff() abort
  silent! bwipeout ai-preview://
  AiPreview! -- hi
  let l:line = &l:statusline
  wincmd p
  return l:line
endfunction

function! s:test_copilot_oneoff_approval() abort
  let l:bin = s:tmp . '/bin'
  call mkdir(l:bin, 'p')
  call writefile(['#!/bin/sh'], l:bin . '/copilot')
  call setfperm(l:bin . '/copilot', 'rwxr-xr-x')
  let l:path = $PATH
  let $PATH = l:bin . ':' . $PATH
  let g:prompts_agent = 'copilot'
  try
    call assert_match('copilot --experimental --assisted-approval --allow-all-tools -p <prompt>',
          \ s:copilot_oneoff())
    let g:prompts_copilot_approval = 'all'
    call assert_match('copilot --allow-all-tools -p <prompt>', s:copilot_oneoff())
    let g:prompts_copilot_approval = 'yolo'
    messages clear
    call assert_match('copilot --experimental --assisted-approval --allow-all-tools -p <prompt>',
          \ s:copilot_oneoff())
    call assert_match('vim-prompts: g:prompts_copilot_approval is assisted or all, not yolo',
          \ execute('messages'))
    " A session is as its config says
    call assert_match('copilot -i <prompt>', s:preview('-- hi').line)
  finally
    unlet! g:prompts_copilot_approval
    let $PATH = l:path
    let g:prompts_agent = 'fake'
  endtry
endfunction

function! s:test_oneoff_saves_its_comments() abort
  let l:answer = 'It subtracts.\n```vim-prompts-comments\napp.py:2: 1. [blocking] minus\n'
        \ . '\tshould be plus\napp.py:1-2: 2. [nit] name it\n```\n'
  let g:prompts_agent_table.answers = {'cmd': ['sh', '-c', 'printf ''' . l:answer . '''', 'sh'],
        \ 'oneoff': [], 'prompt': [], 'modes': {'ask': []}}
  let g:prompts_agent = 'answers'
  try
    %Ai /review
    let l:bufnr = bufnr('ai-oneoff://*')
    call assert_true(l:bufnr > 0)
    for l:i in range(100)
      if getbufvar(l:bufnr, 'prompts_oneoff') !~# 'answering'
        break
      endif
      sleep 20m
    endfor
    call assert_equal('answers: done, 2 comments for :AiComments', getbufvar(l:bufnr, 'prompts_oneoff'))
    let l:lines = getbufline(l:bufnr, 1, '$')
    call assert_equal(1, len(filter(copy(l:lines), 'v:val =~# "^It subtracts"')))
    call assert_equal([], filter(copy(l:lines), 'v:val =~# "```"'))
    let l:note = filter(copy(l:lines), 'v:val =~# "^(2 comments saved to "')
    call assert_equal(1, len(l:note))
    let l:file = expand(matchstr(get(l:note, 0, ''), 'saved to \zs\S\+\ze:'))
    call assert_equal(['app.py:2: 1. [blocking] minus', "\tshould be plus",
          \ 'app.py:1-2: 2. [nit] name it'], readfile(l:file))
    AiComments
    call assert_equal([], filter(split(execute('messages'), "\n"), 'v:val =~# "^vim-prompts: "'))
    call assert_equal(2, len(getqflist()))
    call assert_equal(2, get(getqflist(), 0, {'lnum': 0}).lnum)
  finally
    call remove(g:prompts_agent_table, 'answers')
    let g:prompts_agent = 'fake'
  endtry
endfunction

function! s:test_rule_is_plus() abort
  let l:r = s:preview('/review +testing', '%')
  call assert_equal([], l:r.errors)
  call assert_match('Tests run against the shared fixtures', l:r.prompt)
  " Not as a source
  call assert_equal(['a rule is +name, not #rule: +testing; text after -- is taken as is'],
        \ s:preview('/review #rule:testing', '%').errors)
  call assert_equal(['+nope has nothing: needs a rules file in vim-prompts.task-rules: +<Tab>'],
        \ s:preview('/review +nope', '%').errors)
  " + before anything but a letter is text
  call assert_match('+1 on this', s:preview('+1 on this', '%').prompt)
  " Completion: + to the rules, # without them
  call assert_equal(['+test-setup', '+testing'], prompts#complete('+te', 'Ai +te', 6))
  call assert_equal([], filter(prompts#complete('#', 'Ai #', 4), 'v:val =~# "rule"'))
  call assert_true(index(prompts#tokens(), '+testing') >= 0)
endfunction

function! s:test_here_not_file() abort
  call assert_match('Current file: `app.py`, line \d', s:preview('#here x').prompt)
  call assert_equal(['the file and line you ask from is #here, not #file; files are @path;'
        \ . ' text after -- is taken as is'], s:preview('#file x').errors)
  " Not from a listing
  enew
  setlocal buftype=nofile
  call assert_equal(['#here has nothing: needs a file to ask from, not a listing or a scratch buffer'],
        \ s:preview('#here x').errors)
endfunction

function! s:test_draft_asks_from_where_it_is_sent() abort
  " Opened from a listing, sent once you have opened a file in its window
  enew
  setlocal buftype=nofile
  AiDraft! #here what is this
  call assert_equal('ai-draft://ask', bufname())
  wincmd p
  execute 'edit' fnameescape(s:app . '/app.py')
  wincmd p
  messages clear
  wq
  sleep 50m
  call assert_equal([], filter(split(execute('messages'), "\n"), 'v:val =~# "^vim-prompts: "'))
  call assert_true(bufnr('ai-oneoff://*') > 0, 'the one-off went')
endfunction

function! s:test_sources_list() abort
  AiSources
  let l:lines = getline(1, '$')
  if !empty($SHOW)
    call extend(s:out, l:lines)
  endif
  call assert_match('^Sources (12)', l:lines[0])
  " What to work on, then how
  let l:what = index(l:lines, 'what to work on')
  let l:how = index(l:lines, 'how to work on it')
  call assert_true(l:what > 0 && l:how > l:what, string(l:lines))
  let l:after = l:lines[l:how + 1 :]
  call assert_equal(2, len(l:after))
  call assert_match('^  #agent_comments ', get(l:after, 0, ''))
  call assert_match('^  +name .*+testing .*(:AiRules)$', get(l:after, 1, ''))
  " Judged from app.py on a branch with a change
  call assert_match('^  #changes\[:arg\] .*  has something here$',
        \ get(filter(copy(l:lines), 'v:val =~# "^  #changes"'), 0, ''))
  call assert_match('^  #quickfix .*  nothing here: needs a quickfix list',
        \ get(filter(copy(l:lines), 'v:val =~# "^  #quickfix"'), 0, ''))
  call assert_match('^  @path ', get(filter(copy(l:lines), 'v:val =~# "^  @path"'), 0, ''))
  call assert_match('^  #url:arg .*  a link: ', get(filter(copy(l:lines), 'v:val =~# "^  #url"'), 0, ''))
  " A copy on 'runtimepath' before the bundled one hides it (its functions
  " only from the next Vim: the bundled file is loaded already)
  let l:dir = s:tmp . '/mine'
  call mkdir(l:dir . '/autoload/prompts/sources', 'p')
  call writefile(readfile(s:root . '/autoload/prompts/sources/quickfix.vim'),
        \ l:dir . '/autoload/prompts/sources/quickfix.vim')
  execute 'set runtimepath^=' . fnameescape(l:dir)
  try
    normal r
    let l:qf = filter(getline(1, '$'), 'v:val =~# "^  #quickfix"')
    call assert_equal(2, len(l:qf))
    call assert_match('^  #quickfix \+\S*/mine/autoload/prompts/sources/quickfix\.vim ', get(l:qf, 0, ''))
    call assert_match('/vim-prompts/autoload/prompts/sources/quickfix\.vim \+hidden by \S*/mine/',
          \ get(l:qf, 1, ''))
  finally
    execute 'set runtimepath-=' . fnameescape(l:dir)
    call delete(l:dir, 'rf')
    call prompts#source#load()
  endtry
endfunction

let s:prefix = expand('<SID>') . 'test_'
let s:names = []
for s:line in split(execute('function'), "\n")
  if stridx(s:line, 'function ' . s:prefix) == 0
    call add(s:names, matchstr(s:line, '^function \zs[^(]\+'))
  endif
endfor
for s:name in sort(s:names)
  let s:label = matchstr(s:name, 'test_\zs\w\+')
  if !empty($TEST) && s:label !~# $TEST
    continue
  endif
  let v:errors = []
  call s:reset()
  try
    call call(s:name, [])
  catch
    call add(v:errors, v:throwpoint . ': ' . v:exception)
  endtry
  call add(s:out, (empty(v:errors) ? 'ok   ' : 'FAIL ') . s:label)
  call extend(s:out, map(copy(v:errors), '"     " . v:val'))
endfor
call delete(s:tmp, 'rf')
call writefile(s:out, '/dev/stdout')
execute (empty(filter(copy(s:out), 'v:val =~# "^FAIL"')) ? 'qall!' : 'cquit!')
