"=============================================================================
" FILE: helper.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
"=============================================================================

let s:save_cpo = &cpo
set cpo&vim

if !exists('s:internal_candidates_list')
  let s:internal_candidates_list = {}
  let s:global_candidates_list = {
        \ 'dictionary_variables' : {}, 'runtimepath' : &runtimepath }
  let s:script_candidates_list = {}
  let s:local_candidates_list = {}
endif

let s:dictionary_path =
      \ substitute(fnamemodify(expand('<sfile>'), ':h'), '\\', '/', 'g')

function! necovim#helper#make_cache() abort "{{{
  if &filetype !=# 'vim'
    return
  endif

  let s:script_candidates_list[bufnr('%')] =
        \ s:get_script_candidates(bufnr('%'))
endfunction"}}}

function! necovim#helper#get_command_completion(command_name, cur_text, complete_str) abort "{{{
  let completion_name =
        \ necovim#helper#get_completion_name(a:command_name)
  if completion_name == ''
    " Not found.
    return []
  endif

  let args = (completion_name ==# 'custom' ||
        \     completion_name ==# 'customlist')?
        \ [a:command_name, a:cur_text, a:complete_str] :
        \ [a:cur_text, a:complete_str]
  return call('necovim#helper#'
        \ .completion_name, args)
endfunction"}}}
function! necovim#helper#get_completion_name(command_name) abort "{{{
  if !has_key(s:internal_candidates_list, 'command_completions')
    let s:internal_candidates_list.command_completions =
          \ s:make_cache_completion_from_dict('command_completions')
  endif
  if s:check_global_candidates('command_completions')
    let s:global_candidates_list.commands = s:get_cmdlist()
  endif

  if has_key(s:internal_candidates_list.command_completions, a:command_name)
        \&& exists('*necovim#helper#'
        \ .s:internal_candidates_list.command_completions[a:command_name])
    return s:internal_candidates_list.command_completions[a:command_name]
  elseif has_key(s:global_candidates_list.command_completions, a:command_name)
        \&& exists('*necovim#helper#'
        \ .s:global_candidates_list.command_completions[a:command_name])
    return s:global_candidates_list.command_completions[a:command_name]
  else
    return ''
  endif
endfunction"}}}

function! necovim#helper#autocmd_args(cur_text, complete_str) abort "{{{
  let args = s:split_args(a:cur_text, a:complete_str)
  if len(args) < 2
    return []
  endif

  " Make cache.
  if s:check_global_candidates('augroups')
    let s:global_candidates_list.augroups = s:get_augrouplist()
  endif
  if !has_key(s:internal_candidates_list, 'autocmds')
    let s:internal_candidates_list.autocmds = s:make_cache_autocmds()
  endif

  let list = []
  if len(args) == 2
    let list += copy(s:global_candidates_list.augroups) +
          \ copy(s:internal_candidates_list.autocmds)
  elseif len(args) == 3
    if args[1] ==# 'FileType'
      " Filetype completion.
      let list +=
            \ necovim#helper#filetype(
            \   a:cur_text, a:complete_str)
    endif

    let list += s:internal_candidates_list.autocmds
  elseif len(args) == 4
    if args[2] ==# 'FileType'
      " Filetype completion.
      let list += necovim#helper#filetype(
            \ a:cur_text, a:complete_str)
    endif

    let list += necovim#helper#command(
          \ args[3], a:complete_str)
    let list += s:make_completion_list(['nested'])
  else
    let command = args[3] =~ '^*' ?
          \ join(args[4:]) : join(args[3:])
    let list += necovim#helper#command(
          \ command, a:complete_str)
    let list += s:make_completion_list(['nested'])
  endif

  return list
endfunction"}}}
function! necovim#helper#augroup(cur_text, complete_str) abort "{{{
  " Make cache.
  if s:check_global_candidates('augroups')
    let s:global_candidates_list.augroups = s:get_augrouplist()
  endif

  return copy(s:global_candidates_list.augroups)
endfunction"}}}
function! necovim#helper#buffer(cur_text, complete_str) abort "{{{
  return []
endfunction"}}}
function! necovim#helper#colorscheme_args(cur_text, complete_str) abort "{{{
  return s:make_completion_list(map(split(
        \ globpath(&runtimepath, 'colors/*.vim'), '\n'),
        \ 'fnamemodify(v:val, ":t:r")'))
endfunction"}}}
function! necovim#helper#command(cur_text, complete_str) abort "{{{
  if a:cur_text == '' ||
        \ a:cur_text =~ '^[[:digit:],[:space:][:tab:]$''<>]*\h\w*$'
    " Commands.

    " Make cache.
    if s:check_global_candidates('commands')
      let s:global_candidates_list.commands = s:get_cmdlist()
    endif
    if !has_key(s:internal_candidates_list, 'commands')
      let s:internal_candidates_list.commands = s:make_cache_commands()
    endif

    let list = copy(s:internal_candidates_list.commands)
          \ + copy(s:global_candidates_list.commands)
  else
    " Commands args.
    let command = necovim#get_command(a:cur_text)
    let completion_name =
          \ necovim#helper#get_completion_name(command)

    " Prevent infinite loop.
    let cur_text = completion_name ==# 'command' ?
          \ a:cur_text[len(command):] : a:cur_text

    let list = necovim#helper#get_command_completion(
          \ command, cur_text, a:complete_str)

    if a:cur_text =~
          \'[[(,{]\|`=[^`]*$'
      " Expression.
      let list += necovim#helper#expression(
            \ a:cur_text, a:complete_str)
    endif
  endif

  return list
endfunction"}}}
function! necovim#helper#command_args(cur_text, complete_str) abort "{{{
  " Make cache.
  if !has_key(s:internal_candidates_list, 'command_args')
    let s:internal_candidates_list.command_args =
          \ s:make_completion_list(
          \   readfile(s:dictionary_path . '/command_args.dict'))
    let s:internal_candidates_list.command_replaces =
          \ s:make_completion_list(
        \ ['<line1>', '<line2>', '<count>', '<bang>',
        \  '<reg>', '<args>', '<lt>', '<q-args>', '<f-args>'])
  endif

  return s:internal_candidates_list.command_args +
        \ s:internal_candidates_list.command_replaces
endfunction"}}}
function! necovim#helper#custom(command_name, cur_text, complete_str) abort "{{{
  if !has_key(g:necovim#complete_functions, a:command_name)
    return []
  endif

  return s:make_completion_list(split(
        \ call(g:necovim#complete_functions[a:command_name],
        \ [a:complete_str, getline('.'), len(a:cur_text)]), '\n'))
endfunction"}}}
function! necovim#helper#customlist(command_name, cur_text, complete_str) abort "{{{
  if !has_key(g:necovim#complete_functions, a:command_name)
    return []
  endif

  " Ignore error
  try
    let result = call(g:necovim#complete_functions[a:command_name],
          \ [a:complete_str, getline('.'), len(a:cur_text)])
  catch
    let result = []
  endtry

  return s:make_completion_list(result)
endfunction"}}}
function! necovim#helper#dir(cur_text, complete_str) abort "{{{
  " Todo.
  return []
endfunction"}}}
function! necovim#helper#environment(cur_text, complete_str) abort "{{{
  " Make cache.
  if s:check_global_candidates('environments')
    let s:global_candidates_list.environments = s:get_envlist()
  endif

  return copy(s:global_candidates_list.environments)
endfunction"}}}
function! necovim#helper#event(cur_text, complete_str) abort "{{{
  return []
endfunction"}}}
function! necovim#helper#execute(cur_text, complete_str) abort "{{{
  let candidates = necovim#helper#expression(a:cur_text, a:complete_str)
  if a:cur_text =~ '["''][^"''[:space:]]*$'
    let command = matchstr(a:cur_text, '["'']\zs[^"'']*$')
    let candidates += necovim#helper#command(command, a:complete_str)
  endif

  return candidates
endfunction"}}}
function! necovim#helper#expand(cur_text, complete_str) abort "{{{
  return s:make_completion_list(
        \ ['<cfile>', '<afile>', '<abuf>', '<amatch>',
        \  '<sfile>', '<cword>', '<cWORD>', '<client>'])
endfunction"}}}
function! necovim#helper#expression(cur_text, complete_str) abort "{{{
  return necovim#helper#function(a:cur_text, a:complete_str)
        \+ necovim#helper#var(a:cur_text, a:complete_str)
endfunction"}}}
function! necovim#helper#feature(cur_text, complete_str) abort "{{{
  if !has_key(s:internal_candidates_list, 'features')
    let s:internal_candidates_list.features = s:make_cache_features()
  endif
  return copy(s:internal_candidates_list.features)
endfunction"}}}
function! necovim#helper#file(cur_text, complete_str) abort "{{{
  " Todo.
  return []
endfunction"}}}
function! necovim#helper#filetype(cur_text, complete_str) abort "{{{
  if !has_key(s:internal_candidates_list, 'filetypes')
    let s:internal_candidates_list.filetypes =
          \ s:make_completion_list(map(
          \ split(globpath(&runtimepath, 'syntax/*.vim'), '\n') +
          \ split(globpath(&runtimepath, 'indent/*.vim'), '\n') +
          \ split(globpath(&runtimepath, 'ftplugin/*.vim'), '\n')
          \ , "matchstr(fnamemodify(v:val, ':t:r'), '^[[:alnum:]-]*')"))
  endif

  return copy(s:internal_candidates_list.filetypes)
endfunction"}}}
function! necovim#helper#function(cur_text, complete_str) abort "{{{
  " Make cache.
  if s:check_global_candidates('functions')
    let s:global_candidates_list.functions = s:get_functionlist()
  endif
  if !has_key(s:internal_candidates_list, 'functions')
    let s:internal_candidates_list.functions = s:make_cache_functions()
  endif

  let script_functions = values(s:get_cached_script_candidates().functions)
  if a:complete_str =~ '^s:'
    let list = script_functions
  elseif a:complete_str =~ '^\a:'
    let list = deepcopy(script_functions)
    for keyword in list
      let keyword.word = '<SID>' . keyword.word[2:]
      let keyword.abbr = '<SID>' . keyword.abbr[2:]
    endfor
  else
    let list = copy(s:internal_candidates_list.functions)
          \ + copy(s:global_candidates_list.functions)
          \ + script_functions
    for functions in map(values(s:script_candidates_list), 'v:val.functions')
      let list += values(filter(copy(functions), 'v:val.word[:1] !=# "s:"'))
    endfor
  endif

  return list
endfunction"}}}
function! necovim#helper#help(cur_text, complete_str) abort "{{{
  return []
endfunction"}}}
function! necovim#helper#highlight(cur_text, complete_str) abort "{{{
  return []
endfunction"}}}
function! necovim#helper#let(cur_text, complete_str) abort "{{{
  if a:cur_text !~ '='
    return necovim#helper#var(a:cur_text, a:complete_str)
  elseif a:cur_text =~# '\<let\s\+&\%([lg]:\)\?filetype\s*=\s*'
    " FileType.
    return necovim#helper#filetype(a:cur_text, a:complete_str)
  else
    return necovim#helper#expression(a:cur_text, a:complete_str)
  endif
endfunction"}}}
function! necovim#helper#mapping(cur_text, complete_str) abort "{{{
  " Make cache.
  if s:check_global_candidates('mappings')
    let s:global_candidates_list.mappings = s:get_mappinglist()
  endif
  if !has_key(s:internal_candidates_list, 'mappings')
    let s:internal_candidates_list.mappings =
          \ s:make_completion_list(
          \   readfile(s:dictionary_path . '/mappings.dict'))
  endif

  let list = copy(s:internal_candidates_list.mappings) +
        \ copy(s:global_candidates_list.mappings)

  if a:cur_text =~ '<expr>'
    let list += necovim#helper#expression(a:cur_text, a:complete_str)
  elseif a:cur_text =~ ':<C-u>\?'
    let command = matchstr(a:cur_text, ':<C-u>\?\zs.*$')
    let list += necovim#helper#command(command, a:complete_str)
  endif

  return list
endfunction"}}}
function! necovim#helper#menu(cur_text, complete_str) abort "{{{
  return []
endfunction"}}}
function! necovim#helper#option(cur_text, complete_str) abort "{{{
  " Make cache.
  if !has_key(s:internal_candidates_list, 'options')
    let s:internal_candidates_list.options = s:make_cache_options()
  endif

  if a:cur_text =~ '\<set\%[local]\s\+\%(filetype\|ft\)='
    return necovim#helper#filetype(a:cur_text, a:complete_str)
  else
    return copy(s:internal_candidates_list.options)
  endif
endfunction"}}}
function! necovim#helper#shellcmd(cur_text, complete_str) abort "{{{
  return []
endfunction"}}}
function! necovim#helper#tag(cur_text, complete_str) abort "{{{
  return []
endfunction"}}}
function! necovim#helper#tag_listfiles(cur_text, complete_str) abort "{{{
  return []
endfunction"}}}
function! necovim#helper#var_dictionary(cur_text, complete_str) abort "{{{
  let var_name = matchstr(a:cur_text,
        \'\%(\a:\)\?\h\w*\ze\.\%(\h\w*\%(()\?\)\?\)\?$')
  let list = []
  if a:cur_text =~ '[btwg]:\h\w*\.\%(\h\w*\%(()\?\)\?\)\?$'
    let list = has_key(s:global_candidates_list.dictionary_variables, var_name) ?
          \ values(s:global_candidates_list.dictionary_variables[var_name]) : []
  elseif a:cur_text =~ 's:\h\w*\.\%(\h\w*\%(()\?\)\?\)\?$'
    let list = values(get(s:get_cached_script_candidates().dictionary_variables,
          \ var_name, {}))
  endif

  return list
endfunction"}}}
function! necovim#helper#var(cur_text, complete_str) abort "{{{
  " Make cache.
  if s:check_global_candidates('variables')
    let s:global_candidates_list.variables =
          \ s:get_variablelist(g:, 'g:') + s:get_variablelist(v:, 'v:')
          \ + s:make_completion_list(['v:val'])
  endif

  if a:complete_str =~ '^[swtb]:'
    let list = values(s:get_cached_script_candidates().variables)
    if a:complete_str !~ '^s:'
      let prefix = matchstr(a:complete_str, '^[swtb]:')
      let list += s:get_variablelist(eval(prefix), prefix)
    endif
  elseif a:complete_str =~ '^[vg]:'
    let list = copy(s:global_candidates_list.variables)
  else
    let list = s:get_local_variables()
  endif

  return list
endfunction"}}}

function! s:get_local_variables() abort "{{{
  " Get local variable list.

  let keyword_dict = {}
  " Search function.
  let line_num = line('.') - 1
  let end_line = (line('.') > 100) ? line('.') - 100 : 1
  while line_num >= end_line
    let line = getline(line_num)
    if line =~ '\<endf\%[unction]\>'
      break
    elseif line =~ '\<fu\%[nction]!\?\s\+'
      " Get function arguments.
      call s:analyze_variable_line(line, keyword_dict)
      break
    endif

    let line_num -= 1
  endwhile
  let line_num += 1

  let end_line = line('.') - 1
  while line_num <= end_line
    let line = getline(line_num)

    if line =~ '\<\%(let\|for\)\s\+'
      if line =~ '\<\%(let\|for\)\s\+s:' &&
            \ has_key(s:script_candidates_list, bufnr('%'))
            \ && has_key(s:script_candidates_list[bufnr('%')], 'variables')
        let candidates_list = s:script_candidates_list[bufnr('%')].variables
      else
        let candidates_list = keyword_dict
      endif

      call s:analyze_variable_line(line, candidates_list)
    endif

    let line_num += 1
  endwhile

  return values(keyword_dict)
endfunction"}}}

function! s:get_cached_script_candidates() abort "{{{
  return has_key(s:script_candidates_list, bufnr('%')) ?
        \ s:script_candidates_list[bufnr('%')] : {
        \   'functions' : {}, 'variables' : {},
        \   'function_prototypes' : {}, 'dictionary_variables' : {} }
endfunction"}}}
function! s:get_script_candidates(bufnumber) abort "{{{
  " Get script candidate list.

  let function_dict = {}
  let variable_dict = {}
  let dictionary_variable_dict = {}
  let function_prototypes = {}
  let var_pattern = '\a:[[:alnum:]_:]*\.\h\w*\%(()\?\)\?'

  for line in getbufline(a:bufnumber, 1, '$')
    if line =~ '\<fu\%[nction]!\?\s\+'
      call s:analyze_function_line(
            \ line, function_dict, function_prototypes)
    elseif line =~ '\<let\s\+'
      " Get script variable.
      call s:analyze_variable_line(line, variable_dict)
    elseif line =~ var_pattern
      while line =~ var_pattern
        let var_name = matchstr(line, '\a:[[:alnum:]_:]*\ze\.\h\w*')
        let candidates_dict = dictionary_variable_dict
        if !has_key(candidates_dict, var_name)
          let candidates_dict[var_name] = {}
        endif

        call s:analyze_dictionary_variable_line(
              \ line, candidates_dict[var_name], var_name)

        let line = line[matchend(line, var_pattern) :]
      endwhile
    endif
  endfor

  return { 'functions' : function_dict, 'variables' : variable_dict,
        \ 'function_prototypes' : function_prototypes,
        \ 'dictionary_variables' : dictionary_variable_dict }
endfunction"}}}

function! s:make_cache_completion_from_dict(dict_name) abort "{{{
  let dict_files = split(globpath(&runtimepath,
        \ 'autoload/necovim/'.a:dict_name.'.dict'), '\n')
  if empty(dict_files)
    return {}
  endif

  let keyword_dict = {}
  for line in readfile(dict_files[0])
    let word = matchstr(line, '^[[:alnum:]_\[\]]\+')
    let completion = matchstr(line[len(word):], '\h\w*')
    if completion != ''
      if word =~ '\['
        let [word_head, word_tail] = split(word, '\[')
        let word_tail = ' ' . substitute(word_tail, '\]', '', '')
      else
        let word_head = word
        let word_tail = ' '
      endif

      for i in range(len(word_tail))
        let keyword_dict[word_head . word_tail[1:i]] = completion
      endfor
    endif
  endfor

  return keyword_dict
endfunction"}}}
function! s:make_cache_prototype_from_dict(dict_name) abort "{{{
  let dict_files = split(globpath(&runtimepath,
        \ 'autoload/necovim/'.a:dict_name.'.dict'), '\n')
  if empty(dict_files)
    return {}
  endif
  if a:dict_name == 'functions'
    let pattern = '^[[:alnum:]_]\+('
  else
    let pattern = '^[[:alnum:]_\[\](]\+'
  endif

  let keyword_dict = {}
  for line in readfile(dict_files[0])
    let word = matchstr(line, pattern)
    let rest = line[len(word):]
    if word =~ '\['
      let [word_head, word_tail] = split(word, '\[')
      let word_tail = ' ' . substitute(word_tail, '\]', '', '')
    else
      let word_head = word
      let word_tail = ' '
    endif

    for i in range(len(word_tail))
      let keyword_dict[word_head . word_tail[1:i]] = rest
    endfor
  endfor

  return keyword_dict
endfunction"}}}
function! s:make_cache_options() abort "{{{
  redir => raw
  silent set all
  redir END
  let options = map(filter(split(raw, '\s\{2,}\|\n')[1:],
        \ "!empty(v:val) && v:val =~ '^\\h\\w*=\\?'"),
        \ "substitute(v:val, '^no\\|=\\zs.*$', '', '')")
  for option in copy(options)
    if option[-1:] != '='
      call add(options, 'no'.option)
    endif
  endfor

  return map(filter(options, "v:val =~ '^\\h\\w*=\\?'"), "{
        \ 'word' : substitute(v:val, '=$', '', ''), 'kind' : 'o',
        \ }")
endfunction"}}}
function! s:make_cache_features() abort "{{{
  let helpfile = expand(findfile('doc/eval.txt', &runtimepath))

  if !filereadable(helpfile)
    return []
  endif

  let features = []
  let lines = readfile(helpfile)
  let start = match(lines,
        \ ((v:version > 704 || v:version == 704 && has('patch11')) ?
        \   'acl' : '^all_builtin_terms'))
  let end = match(lines, '^x11')
  for l in lines[start : end]
    let _ = matchlist(l, '^\(\k\+\)\t\+\(.\+\)$')
    if !empty(_)
      call add(features, {
            \ 'word' : _[1],
            \ 'menu' : '; ' . _[2],
            \ })
    endif
  endfor

  call add(features, {
        \ 'word' : 'patch',
        \ 'menu' : '; Included patches Ex: patch123',
        \ })
  if has('patch-7.4.237')
    call add(features, {
          \ 'word' : 'patch-',
          \ 'menu' : '; Version and patches Ex: patch-7.4.237'
          \ })
  endif

  return features
endfunction"}}}
function! s:make_cache_functions() abort "{{{
  let helpfile = expand(findfile('doc/eval.txt', &runtimepath))
  if !filereadable(helpfile)
    return []
  endif

  let lines = readfile(helpfile)
  let functions = []
  let start = match(lines, '^abs')
  let end = match(lines, '^abs', start, 2)
  for i in range(end-1, start, -1)
    let func = matchstr(lines[i], '^\s*\zs\w\+(.\{-})')
    if func != ''
      call insert(functions, {
            \ 'word' : substitute(func, '(\zs.\+)', '', ''),
            \ 'abbr' : substitute(func, '(\zs\s\+', '', ''),
            \ })
    endif
  endfor

  return functions
endfunction"}}}
function! s:make_cache_commands() abort "{{{
  let helpfile = expand(findfile('doc/index.txt', &runtimepath))
  if !filereadable(helpfile)
    return []
  endif

  let lines = readfile(helpfile)
  let commands = []
  let start = match(lines, '^|:!|')
  let end = match(lines, '^|:\~|', start)
  for lnum in range(end, start, -1)
    let desc = substitute(lines[lnum], '^\s\+\ze', '', 'g')
    let _ = matchlist(desc, '^|:\(.\{-}\)|\s\+\S\+')
    if !empty(_)
      call add(commands, {
            \ 'word' : _[1], 'kind' : 'c',
            \ })
    endif
  endfor

  return commands
endfunction"}}}
function! s:make_cache_autocmds() abort "{{{
  let helpfile = expand(findfile('doc/autocmd.txt', &runtimepath))
  if !filereadable(helpfile)
    return []
  endif

  let lines = readfile(helpfile)
  let autocmds = []
  let start = match(lines, '^|BufNewFile|')
  let end = match(lines, '^|User|', start)
  let desc = ''
  for lnum in range(end, start, -1)
    let desc = substitute(lines[lnum], '^\s\+\ze', '', 'g') . ' ' . desc
    let _ = matchlist(desc, '^|\(.\{-}\)|\s\+\S\+')
    if !empty(_)
      call add(autocmds, { 'word' : _[1], })
      let desc = ''
    endif
  endfor

  return autocmds
endfunction"}}}

function! s:get_cmdlist() abort "{{{
  " Get command list.
  redir => redir
  silent! command
  redir END

  let keyword_list = []
  let completions = [ 'augroup', 'buffer', 'behave',
        \ 'color', 'command', 'compiler', 'cscope',
        \ 'dir', 'environment', 'event', 'expression',
        \ 'file', 'file_in_path', 'filetype', 'function',
        \ 'help', 'highlight', 'history', 'locale',
        \ 'mapping', 'menu', 'option', 'shellcmd', 'sign',
        \ 'syntax', 'tag', 'tag_listfiles',
        \ 'var', 'custom', 'customlist' ]
  let command_prototypes = {}
  let command_completions = {}
  for line in split(redir, '\n')[1:]
    let word = matchstr(line, '\u\w*')

    " Analyze prototype.
    let end = matchend(line, '\u\w*')
    let args = matchstr(line, '[[:digit:]?+*]', end)
    if args != '0'
      let prototype = matchstr(line, '\u\w*', end)
      let found = 0
      for comp in completions
        if comp == prototype
          let command_completions[word] = prototype
          let found = 1

          break
        endif
      endfor

      if !found
        let prototype = 'arg'
      endif

      if args == '*'
        let prototype = '[' . prototype . '] ...'
      elseif args == '?'
        let prototype = '[' . prototype . ']'
      elseif args == '+'
        let prototype = prototype . ' ...'
      endif

      let command_prototypes[word] = ' ' . repeat(' ', 16 - len(word)) . prototype
    else
      let command_prototypes[word] = ''
    endif
    let prototype = command_prototypes[word]

    call add(keyword_list, {
          \ 'word' : word, 'abbr' : word . prototype,
          \ 'description' : word . prototype, 'kind' : 'c'
          \})
  endfor
  let s:global_candidates_list.command_prototypes = command_prototypes
  let s:global_candidates_list.command_completions = command_completions

  return keyword_list
endfunction"}}}
function! s:get_variablelist(dict, prefix) abort "{{{
  let kind_dict =
        \ ['0', '""', '()', '[]', '{}', '.', 'b', 'no', 'j', 'ch']
  return values(map(copy(a:dict), "{
        \ 'word' : a:prefix.v:key,
        \ 'kind' : kind_dict[type(v:val)],
        \}"))
endfunction"}}}
function! s:get_functionlist() abort "{{{
  " Get function list.
  redir => redir
  silent! function
  redir END

  let keyword_dict = {}
  let function_prototypes = {}
  for line in split(redir, '\n')
    let line = line[9:]
    if line =~ '^<SNR>'
      continue
    endif
    let orig_line = line

    let word = matchstr(line, '\h[[:alnum:]_:#.]*()\?')
    if word != ''
      let keyword_dict[word] = {
            \ 'word' : word, 'abbr' : line,
            \ 'description' : line,
            \}

      let function_prototypes[word] = orig_line[len(word):]
    endif
  endfor

  let s:global_candidates_list.function_prototypes = function_prototypes

  return values(keyword_dict)
endfunction"}}}
function! s:get_augrouplist() abort "{{{
  " Get augroup list.
  redir => redir
  silent! augroup
  redir END

  let keyword_list = []
  for group in split(redir . ' END', '\s\|\n')
    call add(keyword_list, { 'word' : group })
  endfor
  return keyword_list
endfunction"}}}
function! s:get_mappinglist() abort "{{{
  " Get mapping list.
  redir => redir
  silent! map
  redir END

  let keyword_list = []
  for line in split(redir, '\n')
    let map = matchstr(line, '^\a*\s*\zs\S\+')
    if map !~ '^<' || map =~ '^<SNR>'
      continue
    endif
    call add(keyword_list, { 'word' : map })
  endfor
  return keyword_list
endfunction"}}}
function! s:get_envlist() abort "{{{
  " Get environment variable list.

  let keyword_list = []
  for line in split(system('set'), '\n')
    let word = '$' . toupper(matchstr(line, '^\h\w*'))
    call add(keyword_list, { 'word' : word, 'kind' : 'e' })
  endfor
  return keyword_list
endfunction"}}}
function! s:make_completion_list(list) abort "{{{
  return map(copy(a:list), "{ 'word' : v:val }")
endfunction"}}}
function! s:analyze_function_line(line, keyword_dict, prototype) abort "{{{
  " Get script function.
  let line = substitute(matchstr(a:line,
        \ '\<fu\%[nction]!\?\s\+\zs.*)'), '".*$', '', '')
  let orig_line = line
  let word = matchstr(line, '^\h[[:alnum:]_:#.]*()\?')
  if word != '' && !has_key(a:keyword_dict, word)
    let a:keyword_dict[word] = {
          \ 'word' : word, 'abbr' : line, 'kind' : 'f'
          \}
    let a:prototype[word] = orig_line[len(word):]
  endif
endfunction"}}}
function! s:analyze_variable_line(line, keyword_dict) abort "{{{
  if a:line =~ '\<\%(let\|for\)\s\+\a[[:alnum:]_:]*'
    " let var = pattern.
    let word = matchstr(a:line, '\<\%(let\|for\)\s\+\zs\a[[:alnum:]_:]*')
    let expression = matchstr(a:line, '\<let\s\+\a[[:alnum:]_:]*\s*=\s*\zs.*$')
    if !has_key(a:keyword_dict, word) 
      let a:keyword_dict[word] = {
            \ 'word' : word,
            \ 'kind' : s:get_variable_type(expression)
            \}
    elseif expression != '' && a:keyword_dict[word].kind == ''
      " Update kind.
      let a:keyword_dict[word].kind = s:get_variable_type(expression)
    endif
  elseif a:line =~ '\<\%(let\|for\)\s\+\[.\{-}\]'
    " let [var1, var2] = pattern.
    let words = split(matchstr(a:line,
          \'\<\%(let\|for\)\s\+\[\zs.\{-}\ze\]'), '[,[:space:]]\+')
      let expressions = split(matchstr(a:line,
            \'\<let\s\+\[.\{-}\]\s*=\s*\[\zs.\{-}\ze\]$'), '[,[:space:];]\+')

      let i = 0
      while i < len(words)
        let expression = get(expressions, i, '')
        let word = words[i]

        if !has_key(a:keyword_dict, word) 
          let a:keyword_dict[word] = {
                \ 'word' : word,
                \ 'kind' : s:get_variable_type(expression)
                \}
        elseif expression != '' && a:keyword_dict[word].kind == ''
          " Update kind.
          let a:keyword_dict[word].kind = s:get_variable_type(expression)
        endif

        let i += 1
      endwhile
    elseif a:line =~ '\<fu\%[nction]!\?\s\+'
      " Get function arguments.
      for arg in split(matchstr(a:line, '^[^(]*(\zs[^)]*'), '\s*,\s*')
        let word = 'a:' . (arg == '...' ?  '000' : arg)
        let a:keyword_dict[word] = {
              \ 'word' : word,
              \ 'kind' : (arg == '...' ?  '[]' : '')
              \}

      endfor
      if a:line =~ '\.\.\.)'
        " Extra arguments.
        for arg in range(5)
          let word = 'a:' . arg
          let a:keyword_dict[word] = {
                \ 'word' : word,
                \ 'kind' : (arg == 0 ?  '0' : '')
                \}
        endfor
      endif
    endif
endfunction"}}}
function! s:analyze_dictionary_variable_line(line, keyword_dict, var_name) abort "{{{
  let let_pattern = '\<let\s\+'.a:var_name.'\.\h\w*'
  let call_pattern = '\<call\s\+'.a:var_name.'\.\h\w*()\?'

  if a:line =~ let_pattern
    let word = matchstr(a:line, a:var_name.'\zs\.\h\w*')
    let kind = ''
  elseif a:line =~ call_pattern
    let word = matchstr(a:line, a:var_name.'\zs\.\h\w*()\?')
    let kind = '()'
  else
    let word = matchstr(a:line, a:var_name.'\zs.\h\w*\%(()\?\)\?')
    let kind = s:get_variable_type(
          \ matchstr(a:line, a:var_name.'\.\h\w*\zs.*$'))
  endif

  if !has_key(a:keyword_dict, word)
    let a:keyword_dict[word] = { 'word' : word, 'kind' : kind }
  elseif kind != '' && a:keyword_dict[word].kind == ''
    " Update kind.
    let a:keyword_dict[word].kind = kind
  endif
endfunction"}}}
function! s:split_args(cur_text, complete_str) abort "{{{
  let args = split(a:cur_text)
  if a:complete_str == ''
    call add(args, '')
  endif

  return args
endfunction"}}}

" Initialize return types. "{{{
function! s:set_dictionary_helper(variable, keys, value) abort "{{{
  for key in split(a:keys, ',')
    let a:variable[key] = a:value
  endfor
endfunction"}}}
let s:function_return_types = {}
call s:set_dictionary_helper(
      \ s:function_return_types,
      \ 'len,match,matchend',
      \ '0')
call s:set_dictionary_helper(
      \ s:function_return_types,
      \ 'input,matchstr',
      \ '""')
call s:set_dictionary_helper(
      \ s:function_return_types,
      \ 'expand,filter,sort,split',
      \ '[]')
"}}}
function! s:get_variable_type(expression) abort "{{{
  " Analyze variable type.
  if a:expression =~ '^\%(\s*+\)\?\s*\d\+\.\d\+'
    return '.'
  elseif a:expression =~ '^\%(\s*+\)\?\s*\d\+'
    return '0'
  elseif a:expression =~ '^\%(\s*\.\)\?\s*["'']'
    return '""'
  elseif a:expression =~ '\<function('
    return '()'
  elseif a:expression =~ '^\%(\s*+\)\?\s*\['
    return '[]'
  elseif a:expression =~ '^\s*{\|^\.\h[[:alnum:]_:]*'
    return '{}'
  elseif a:expression =~ '\<\h\w*('
    " Function.
    let func_name = matchstr(a:expression, '\<\zs\h\w*\ze(')
    return has_key(s:function_return_types, func_name) ? s:function_return_types[func_name] : ''
  else
    return ''
  endif
endfunction"}}}

function! s:set_dictionary_helper(variable, keys, pattern) abort "{{{
  for key in split(a:keys, '\s*,\s*')
    if !has_key(a:variable, key)
      let a:variable[key] = a:pattern
    endif
  endfor
endfunction"}}}

function! s:check_global_candidates(key) abort "{{{
  if s:global_candidates_list.runtimepath !=# &runtimepath
    let s:global_candidates_list.runtimepath = &runtimepath
    return 1
  endif

  return !has_key(s:global_candidates_list, a:key)
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
