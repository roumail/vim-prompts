" vim-prompts: ask an AI agent CLI (Claude Code, Copilot CLI) as one of its
" personas, in the CLIs' own grammar: `:Ai /review #comments @notes.md why`.
" The persona's template, rendered with the query, the context asked for
" (the change, the diffs open, files, the selection, vim-review review
" comments) and the rules and repository description git config names
" (vim-prompts.rules, vim-prompts.repository; vim-prompts.library for
" #rule:<name>), is the agent's first prompt. Commands and <Plug> mappings only;
" no keys are bound here. Requires tpope/vim-fugitive,
" tpope/vim-dispatch (the agent runs with :Start), roumail/git-extras and
" roumail/vim-review.
" The agent CLI (install, auth, model) is yours to set up; this only checks
" that it is executable.
if exists('g:loaded_prompts')
  finish
endif
let g:loaded_prompts = 1

" Required plugins are checked by their plugin file on 'runtimepath', so
" the commands are defined now, before any -c command (`vim -es -c AiRules`
" runs before VimEnter), whichever of them loads after this one. Without
" them nothing below is defined.
function! s:init() abort
  let l:missing = filter({
        \ 'tpope/vim-fugitive': ['g:loaded_fugitive', 'fugitive'],
        \ 'tpope/vim-dispatch': ['g:loaded_dispatch', 'dispatch'],
        \ 'roumail/git-extras': ['g:loaded_git_extras', 'git_extras'],
        \ 'roumail/vim-review': ['g:loaded_review', 'review'],
        \ }, '!exists(v:val[0]) && empty(globpath(&runtimepath, "plugin/" . v:val[1] . ".vim"))')
  if !empty(l:missing)
    echohl WarningMsg
    echomsg 'vim-prompts: not loaded, requires ' . join(sort(keys(l:missing)), ', ')
    echohl None
    return
  endif

  let l:ns = prompts#namespace()
  " [/persona] [#source[:arg]...] [@path...] [--<mode>-mode] [--bare]
  " [query] [-- text]: ask the persona (default: `default`) with its context
  " and the sources asked for; with nothing, open the agent
  execute 'command! -bang -range -nargs=* -complete=customlist,prompts#complete '
        \ . l:ns . ' call prompts#ask(<bang>0, <range>, <line1>, <line2>, <q-args>)'
  " The same, as a draft to edit; :w sends it
  execute 'command! -bang -range -nargs=* -complete=customlist,prompts#complete '
        \ . l:ns . 'Draft call prompts#draft(<bang>0, <range>, <line1>, <line2>, <q-args>)'
  " What applies here: rules, repository, personas; ! reloads the sources
  execute 'command! -bang ' . l:ns . 'Personas call prompts#list(<bang>0)'
  " The rules files that apply here, where each is set, those hidden, and
  " those to ask for with #rule
  execute 'command! ' . l:ns . 'Rules call prompts#rules()'
  " Open a rules file that applies here, or a new one for a scope
  execute 'command! -range -nargs=* -complete=customlist,prompts#rule_complete '
        \ . l:ns . 'Rule call prompts#rule(<range>, <line1>, <line2>, <q-args>)'
  " The agent's comments on lines (#comments_file) in a quickfix list
  execute 'command! -nargs=? -complete=customlist,prompts#comments#complete '
        \ . l:ns . 'Comments call prompts#comments#load(<q-args>)'
  " Remove a value from the file that sets it
  execute 'command! -nargs=+ -complete=customlist,prompts#unset_complete '
        \ . l:ns . 'Unset call prompts#unset(<q-args>)'
  call prompts#source#load()

  " The visual ones leave :'<,'>Ai on the command line to finish
  execute 'nnoremap <Plug>(prompts-ask) :<C-u>' . l:ns . '<Space>'
  execute 'xnoremap <Plug>(prompts-ask) :' . l:ns . '<Space>'
  execute 'nnoremap <Plug>(prompts-draft) :<C-u>' . l:ns . 'Draft<Space>'
  execute 'xnoremap <Plug>(prompts-draft) :' . l:ns . 'Draft<Space>'
  execute 'nnoremap <Plug>(prompts-rule) :<C-u>' . l:ns . 'Rule<Space>'
  execute 'xnoremap <Plug>(prompts-rule) :' . l:ns . 'Rule<Space>'
endfunction

call s:init()
