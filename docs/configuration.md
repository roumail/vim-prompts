# Configuration

Personas, repository context and new `#sources` are in
[personas](personas.md).

## Mappings

No keys are bound. The `<Plug>` mappings type the command for you to finish
(`:'<,'>Ai ` from visual mode):

```vim
nmap <leader>aa <Plug>(prompts-ask)
xmap <leader>aa <Plug>(prompts-ask)
nmap <leader>ad <Plug>(prompts-draft)
xmap <leader>ad <Plug>(prompts-draft)
```

## Command prefix

```vim
let g:prompts_namespace = 'Ai'     " :Ai, :AiDraft, :AiPersonas
```

## File picker

A bare `@`, or `@dir/`, calls `g:prompts_file_picker` with the directory and a
callback, which it calls with the absolute paths picked (at once, or later, as
fzf does). [fzf-utils](https://github.com/roumail/fzf-utils) has one, using
the same fd listing as `:FdFiles`:

```vim
let g:prompts_file_picker = 'fzf_utils#fd#files#pick'
```

## The agent

```vim
let g:prompts_agents = ['claude', 'copilot'] " the first installed one is used
let g:prompts_agent = ''                     " force one
let g:prompts_max_arg = 100000               " longer prompts: the agent is told to read the file
let g:prompts_start_mods = 'tab'             " where a Vim terminal opens: 'tab', 'vertical', '' (a split)
```

They start as `claude [args] <prompt> [--add-dir dir...]` and
`copilot [args] -i <prompt> [--add-dir dir...]`. Add or change one with
`g:prompts_agent_table`:

```vim
let g:prompts_agent_table = {'mycli': {'cmd': ['mycli', '--tui'], 'prompt': ['--prompt'], 'dir': '--allow'}}
```
