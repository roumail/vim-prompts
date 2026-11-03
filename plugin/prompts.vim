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
" A reply on the agent's comment under the cursor (or the current one of
" :AiComments), answered as a one-off into the comment's thread; ! sends it
" to a session instead
execute 'command! -bang -nargs=* -complete=customlist,prompts#complete '
      \ . s:ns . 'Reply call prompts#comments#reply(<bang>0, <q-args>)'
" The same, in a draft: :w saves it, closing sends it
execute 'command! -bang -nargs=* -complete=customlist,prompts#complete '
      \ . s:ns . 'ReplyDraft call prompts#comments#reply_draft(<bang>0, <q-args>)'
" That comment and what was said on it since
execute 'command! ' . s:ns . 'Thread call prompts#comments#thread()'
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

" They leave :AiReply on the command line to finish, as vim-review's
" <Plug>(review-comment) does :Comment; -session ones send to a session (!)
execute 'nnoremap <Plug>(prompts-reply) :<C-u>' . s:ns . 'Reply<Space>'
execute 'nnoremap <Plug>(prompts-reply-draft) <Cmd>' . s:ns . 'ReplyDraft<CR>'
execute 'nnoremap <Plug>(prompts-reply-session) :<C-u>' . s:ns . 'Reply!<Space>'
execute 'nnoremap <Plug>(prompts-reply-draft-session) <Cmd>' . s:ns . 'ReplyDraft!<CR>'

" In the window of :AiComments' list, = shows the thread of the comment under
" the cursor; in other lists it is Vim's
augroup prompts
  autocmd!
  autocmd FileType qf nnoremap <buffer><silent><expr> =
        \ prompts#comments#in_list() ? '<Cmd>call prompts#comments#thread()<CR>' : '='
augroup END
