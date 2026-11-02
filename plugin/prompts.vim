if exists('g:loaded_prompts')
  finish
endif
let g:loaded_prompts = 1

" roumail/vim-requires is optional
try
  call roumail_requires#check('vim-prompts', {
        \ 'tpope/vim-fugitive': 'g:loaded_fugitive',
        \ 'tpope/vim-dispatch': 'g:loaded_dispatch',
        \ 'roumail/fugitive-extras': 'g:loaded_fugitive_extras',
        \ 'roumail/vim-review': 'g:loaded_review',
        \ 'roumail/vim-draft': 'g:loaded_roumail_draft',
        \ })
catch /^Vim\%((\a\+)\)\=:E117:/
endtry

let s:ns = prompts#namespace()
" [/persona] [#source[:arg]...] [@path...] [--<mode>-mode] [--bare]
" [query] [-- text]: ask the persona (default: `default`) with its context
" and the sources asked for; with nothing, open the agent
execute 'command! -bang -range -nargs=* -complete=customlist,prompts#complete '
      \ . s:ns . ' call prompts#ask(<bang>0, <range>, <line1>, <line2>, <q-args>)'
" The same, as a draft to edit; :w saves it, closing it sends it
execute 'command! -bang -range -nargs=* -complete=customlist,prompts#complete '
      \ . s:ns . 'Draft call prompts#draft(<bang>0, <range>, <line1>, <line2>, <q-args>)'
" What :Ai with the same arguments would send, shown and never sent
execute 'command! -bang -range -nargs=* -complete=customlist,prompts#complete '
      \ . s:ns . 'Preview call prompts#preview(<bang>0, <range>, <line1>, <line2>, <q-args>)'
" The personas that apply here and what each asks for; ! reloads the sources
execute 'command! -bang ' . s:ns . 'Personas call prompts#list(<bang>0)'
" The rules files that apply here, where each is set, those hidden, and
" those to ask for with #rule
execute 'command! ' . s:ns . 'Rules call prompts#rules()'
" Open a rules file that applies here, or a new one for a scope
execute 'command! -range -nargs=* -complete=customlist,prompts#rule_complete '
      \ . s:ns . 'Rule call prompts#rule(<range>, <line1>, <line2>, <q-args>)'
" The agent's comments on lines (#agent_comments) in a quickfix list
execute 'command! -nargs=? -complete=customlist,prompts#comments#complete '
      \ . s:ns . 'Comments call prompts#comments#load(<q-args>)'
" The same comments in vim-review's Review list, as :CommentsLoad
execute 'command! -nargs=? -complete=customlist,prompts#comments#complete '
      \ . s:ns . 'CommentsLoad call prompts#comments#review(<q-args>)'
" Remove a value from the file that sets it
execute 'command! -nargs=+ -complete=customlist,prompts#unset_complete '
      \ . s:ns . 'Unset call prompts#unset(<q-args>)'
call prompts#source#load()

" The visual ones leave :'<,'>Ai on the command line to finish
execute 'nnoremap <Plug>(prompts-ask) :<C-u>' . s:ns . '<Space>'
execute 'xnoremap <Plug>(prompts-ask) :' . s:ns . '<Space>'
execute 'nnoremap <Plug>(prompts-draft) :<C-u>' . s:ns . 'Draft<Space>'
execute 'xnoremap <Plug>(prompts-draft) :' . s:ns . 'Draft<Space>'
execute 'nnoremap <Plug>(prompts-rule) :<C-u>' . s:ns . 'Rule<Space>'
execute 'xnoremap <Plug>(prompts-rule) :' . s:ns . 'Rule<Space>'
