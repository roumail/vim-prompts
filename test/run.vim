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
      \ 'fugitive-extras'], 's:plugin(v:val)')
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
let g:roumail_place_dir = s:tmp . '/saves'

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
  " Its comments go to a file
  call assert_match('vim-prompts/comments/', l:r.prompt)
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
  let l:file = s:persona('strict', ['---', 'context: [file, "rule:nope"]', '---', 'Check it.'])
  try
    let l:r = s:preview('/strict')
    call assert_equal('', l:r.prompt)
    call assert_equal(['/strict: #rule:nope has nothing: needs a rules file in'
          \ . ' vim-prompts.task-rules: #rule:<Tab>'], l:r.errors)
    " --force is for nothing to work on, not for a missing rule
    call assert_equal(l:r.errors, s:preview('/strict --force').errors)
  finally
    call delete(l:file)
  endtry
endfunction

function! s:test_optional_persona_rule() abort
  let l:file = s:persona('lenient', ['---', 'context: [file, "rule:nope?", "rule:testing?"]', '---', 'Check it.'])
  try
    let l:r = s:preview('/lenient')
    call assert_equal([], l:r.errors)
    " Sent where there is one
    call assert_match('Tests run against the shared fixtures', l:r.prompt)
    call writefile(['---', 'context: [file?]', '---', 'x'], l:file)
    call assert_match('only a rule may be missing (rule:name?), not file?',
          \ get(s:preview('/lenient').errors, 0, ''))
  finally
    call delete(l:file)
  endtry
endfunction

function! s:test_persona_rule_is_sent() abort
  " The handbook's /tests names rule:testing, which the handbook has
  let l:r = s:preview('/tests')
  call assert_equal([], l:r.errors)
  call assert_match('Tests run against the shared fixtures', l:r.prompt)
endfunction

function! s:test_bad_alternatives() abort
  let l:file = s:persona('bad', ['---', 'context: [["rule:testing", file]]', '---', 'x'])
  try
    call assert_match('is always sent, not one of \[alternatives\]',
          \ get(s:preview('/bad').errors, 0, ''))
    call writefile(['---', 'context: [[[file]]]', '---', 'x'], l:file)
    call assert_match('one level of \[alternatives\]', get(s:preview('/bad').errors, 0, ''))
    call writefile(['---', 'input: maybe', '---', 'x'], l:file)
    call assert_match('input: required or optional', get(s:preview('/bad').errors, 0, ''))
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
        \ . ' #rule:testing  on {base} \S*/personas/review/pr\.md  on {base} \~/\.config/'
        \ . 'vim-prompts/personas/review\.md  on {base} \S*/personas/review\.md$', get(l:pr, 0, ''))
  let l:file = s:persona('strict', ['---', 'context: ["rule:nope", "rule:gone?"]', '---', 'x'])
  try
    AiPersonas!
    call assert_match('/strict .*#rule:nope #rule:gone?  /strict: #rule:nope has nothing',
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
  let l:dir = g:roumail_place_dir . '/plain-' . sha256(s:tmp . '/plain')[:7] . '/vim-prompts/comments'
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
