" vim-prompts: ask an AI agent CLI (Claude Code, Copilot CLI) as one of its
" personas, in the CLIs' own grammar: `:Ai /review #comments @notes.md why`.
" The persona's template, rendered with the query, the context asked for
" (the change, the diffs open, files, the selection, vim-review review
" comments) and the rules and repository description git config names
" (vim-prompts.rules, vim-prompts.repository), is the agent's first prompt. Commands and <Plug> mappings only;
" no keys are bound here. Requires tpope/vim-fugitive,
" tpope/vim-dispatch (the agent runs with :Start), roumail/git-extras and
" roumail/vim-review.
" The agent CLI (install, auth, model) is yours to set up; this only checks
" that it is executable.
if exists('g:loaded_prompts')
  finish
endif
let g:loaded_prompts = 1

" Required plugins are checked once every plugin has loaded (VimEnter, or now
" when loaded later): their g:loaded_* guards tell whether they are installed.
" Without them nothing below is defined.
function! s:init() abort
  let l:missing = filter({
        \ 'tpope/vim-fugitive': 'g:loaded_fugitive',
        \ 'tpope/vim-dispatch': 'g:loaded_dispatch',
        \ 'roumail/git-extras': 'g:loaded_git_extras',
        \ 'roumail/vim-review': 'g:loaded_review',
        \ }, '!exists(v:val)')
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
  call prompts#source#load()

  " The visual ones leave :'<,'>Ai on the command line to finish
  execute 'nnoremap <Plug>(prompts-ask) :<C-u>' . l:ns . '<Space>'
  execute 'xnoremap <Plug>(prompts-ask) :' . l:ns . '<Space>'
  execute 'nnoremap <Plug>(prompts-draft) :<C-u>' . l:ns . 'Draft<Space>'
  execute 'xnoremap <Plug>(prompts-draft) :' . l:ns . 'Draft<Space>'
endfunction

if v:vim_did_enter
  call s:init()
else
  augroup prompts_init
    autocmd!
    autocmd VimEnter * ++once call s:init()
  augroup END
endif
