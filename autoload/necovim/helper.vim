"=============================================================================
" FILE: helper.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" License: MIT license
"=============================================================================

if !exists('s:internal_candidates_list')
  let s:internal_candidates_list = {}
  let s:global_candidates_list = {
        \ 'dictionary_variables' : {}, 'runtimepath' : &runtimepath }
  let s:script_candidates_list = {}
  let s:local_candidates_list = {}
endif

let s:dictionary_path =
      \ substitute(fnamemodify(expand('<sfile>'), ':h'), '\\', '/', 'g')

function! necovim#helper#make_cache() abort
  if &filetype !=# 'vim'
    return
  endif

  let s:script_candidates_list[bufnr('%')] =
        \ s:get_script_candidates(bufnr('%'))
endfunction

function! necovim#helper#augroup(cur_text, complete_str) abort
  " Make cache.
  if s:check_global_candidates('augroups')
    let s:global_candidates_list.augroups = s:get_augrouplist()
  endif

  return copy(s:global_candidates_list.augroups)
endfunction
function! necovim#helper#command(cur_text, complete_str) abort
  if a:complete_str ==# ''
    " Disable for huge candidates
    return []
  endif

  if a:cur_text ==# '' ||
        \ a:cur_text =~# '^[[:digit:],[:space:][:tab:]$''<>]*\h\w*$'
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

    " Expression.
    " Note: In command line window, expression completion should be disabled.
    let list = bufname('%') ==# '[Command Line]' ? [] :
          \ necovim#helper#expression(a:cur_text, a:complete_str)

    try
      let list += s:make_completion_list(
            \ getcompletion(a:cur_text, 'cmdline'))
    catch
      " Ignore getcompletion() error
    endtry
  endif

  " Filter by complete_str to reduce candidates
  let prefix = a:complete_str[:1]
  return filter(s:uniq_by(list, 'v:val.word'),
        \ { _, val -> stridx(val.word, prefix) == 0})
endfunction
function! necovim#helper#environment(cur_text, complete_str) abort
  " Make cache.
  if s:check_global_candidates('environments')
    let s:global_candidates_list.environments = s:get_envlist()
  endif

  return copy(s:global_candidates_list.environments)
endfunction
function! necovim#helper#expand(cur_text, complete_str) abort
  return s:make_completion_list([
        \ '<cfile>', '<afile>', '<abuf>', '<amatch>',
        \ '<sfile>', '<cword>', '<cWORD>', '<client>'
        \ ])
endfunction
function! necovim#helper#expression(cur_text, complete_str) abort
  return necovim#helper#function(a:cur_text, a:complete_str)
        \+ necovim#helper#var(a:cur_text, a:complete_str)
endfunction
function! necovim#helper#feature(cur_text, complete_str) abort
  if !has_key(s:internal_candidates_list, 'features')
    let s:internal_candidates_list.features = s:make_cache_features()
  endif
  return copy(s:internal_candidates_list.features)
endfunction
function! necovim#helper#filetype(cur_text, complete_str) abort
  if !has_key(s:internal_candidates_list, 'filetypes')
    let s:internal_candidates_list.filetypes =
          \ s:make_completion_list(map(
          \ split(globpath(&runtimepath, 'syntax/*.vim'), '\n') +
          \ split(globpath(&runtimepath, 'indent/*.vim'), '\n') +
          \ split(globpath(&runtimepath, 'ftplugin/*.vim'), '\n')
          \ , { _, val -> matchstr(
          \    fnamemodify(val, ':t:r'), '^[[:alnum:]-]*')}))
  endif

  return copy(s:internal_candidates_list.filetypes)
endfunction
function! necovim#helper#function(cur_text, complete_str) abort
  " Make cache.
  if s:check_global_candidates('functions')
    let s:global_candidates_list.functions = s:get_functionlist()
  endif
  if !has_key(s:internal_candidates_list, 'functions')
    let s:internal_candidates_list.functions = s:make_cache_functions()
    if has('nvim')
      let s:internal_candidates_list.functions +=
            \ s:make_cache_functions_nvim()
    endif
  endif

  let script_functions = values(s:get_cached_script_candidates().functions)
  if a:complete_str =~# '^s:'
    let list = script_functions
  elseif a:complete_str =~# '^\a:'
    let list = deepcopy(script_functions)
    for keyword in list
      let keyword.word = '<SID>' . keyword.word[2:]
      let keyword.abbr = '<SID>' . keyword.abbr[2:]
    endfor
  else
    let list = copy(s:internal_candidates_list.functions)
          \ + copy(s:global_candidates_list.functions)
          \ + script_functions
    for functions in map(values(s:script_candidates_list),
          \ { _, val -> val.functions})
      let list += values(filter(copy(functions),
            \ { _, val -> val.word[:1] !=# 's:'}))
    endfor
  endif

  return list
endfunction
function! necovim#helper#let(cur_text, complete_str) abort
  if a:cur_text !~# '='
    return necovim#helper#var(a:cur_text, a:complete_str)
  elseif a:cur_text =~# '\<let\s\+&\%([lg]:\)\?filetype\s*=\s*'
    " FileType.
    return necovim#helper#filetype(a:cur_text, a:complete_str)
  else
    return necovim#helper#expression(a:cur_text, a:complete_str)
  endif
endfunction
function! necovim#helper#option(cur_text, complete_str) abort
  " Make cache.
  if !has_key(s:internal_candidates_list, 'options')
    let s:internal_candidates_list.options = s:make_cache_options()
  endif

  if a:cur_text =~# '\<set\%[local]\s\+\%(filetype\|ft\)='
    return necovim#helper#filetype(a:cur_text, a:complete_str)
  else
    return copy(s:internal_candidates_list.options)
  endif
endfunction
function! necovim#helper#var_dictionary(cur_text, complete_str) abort
  let var_name = matchstr(a:cur_text,
        \'\%(\a:\)\?\h\w*\ze\.\%(\h\w*\%(()\?\)\?\)\?$')
  let list = []
  if a:cur_text =~# '[btwg]:\h\w*\.\%(\h\w*\%(()\?\)\?\)\?$'
    let list = get(
          \ s:global_candidates_list.dictionary_variables, var_name, [])
  elseif a:cur_text =~# 's:\h\w*\.\%(\h\w*\%(()\?\)\?\)\?$'
    let list = values(get(
          \ s:get_cached_script_candidates().dictionary_variables,
          \ var_name, {}))
  endif

  return list
endfunction
function! necovim#helper#var(cur_text, complete_str) abort
  " Make cache.
  if s:check_global_candidates('variables')
    let s:global_candidates_list.variables =
          \ s:get_variablelist(g:, 'g:') + s:get_variablelist(v:, 'v:')
          \ + s:make_completion_list(['v:val'])
  endif

  if a:complete_str =~# '^[swtb]:'
    let list = values(s:get_cached_script_candidates().variables)
    if a:complete_str !~# '^s:'
      let prefix = matchstr(a:complete_str, '^[swtb]:')
      let list += s:get_variablelist(eval(prefix), prefix)
    endif
  elseif a:complete_str =~# '^[vg]:'
    let list = copy(s:global_candidates_list.variables)
  else
    let list = s:get_local_variables()
  endif

  return list
endfunction

function! s:get_local_variables() abort
  " Get local variable list.

  let keyword_dict = {}
  " Search function.
  let line_num = line('.') - 1
  let end_line = max([line('.') - 100, 1])
  while line_num >= end_line
    let line = getline(line_num)
    if line =~# '\<endf\%[unction]\>'
      break
    elseif line =~# '\<fu\%[nction]!\?\s\+'
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

    if line =~# '\<\%(let\|const\|for\)\s\+'
      if line =~# '\<\%(let\|const\|for\)\s\+s:'
            \ && has_key(get(s:script_candidates_list,
            \                bufnr('%'), {}), 'variables')
        let candidates_list = s:script_candidates_list[bufnr('%')].variables
      else
        let candidates_list = keyword_dict
      endif

      call s:analyze_variable_line(line, candidates_list)
    endif

    let line_num += 1
  endwhile

  return values(keyword_dict)
endfunction

function! s:get_cached_script_candidates() abort
  return has_key(s:script_candidates_list, bufnr('%')) ?
        \ s:script_candidates_list[bufnr('%')] : {
        \   'functions' : {}, 'variables' : {},
        \   'function_prototypes' : {}, 'dictionary_variables' : {} }
endfunction
function! s:get_script_candidates(bufnumber) abort
  " Get script candidate list.

  let function_dict = {}
  let variable_dict = {}
  let dictionary_variable_dict = {}
  let function_prototypes = {}
  let var_pattern = '\a:[[:alnum:]_:]*\.\h\w*\%(()\?\)\?'

  for line in getbufline(a:bufnumber, 1, '$')
    if line =~# '\<fu\%[nction]!\?\s\+'
      call s:analyze_function_line(
            \ line, function_dict, function_prototypes)
    elseif line =~# '\<let\s\+'
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

  return {
        \ 'functions' : function_dict,
        \ 'variables' : variable_dict,
        \ 'function_prototypes' : function_prototypes,
        \ 'dictionary_variables' : dictionary_variable_dict,
        \ }
endfunction

function! s:make_cache_options() abort
  let options = map(filter(split(execute('set all'), '\s\{2,}\|\n')[1:],
        \ { _, val -> !empty(val) && val =~# '^\h\w*=\?' }),
        \ { _, val -> substitute(val, '^no\|=\zs.*$', '', '') })
  for option in copy(options)
    if option[-1:] !=# '='
      call add(options, 'no'.option)
    endif
  endfor

  return map(filter(options, { _, val -> val =~# '^\h\w*=\?' }),
        \ { _, val -> {
        \     'word': substitute(val, '=$', '', ''), 'kind' : 'o',
        \   }
        \ })
endfunction
function! s:make_cache_features() abort
  let helpfile = expand(findfile('doc/eval.txt', &runtimepath))

  if !filereadable(helpfile)
    return []
  endif

  let features = []
  let lines = readfile(helpfile)
  let start = match(lines, 'acl')
  let end = match(lines, has('nvim') ? '^wsl' : '^x11')
  for l in lines[start : end]
    let _ = matchlist(l, '^\(\k\+\)\t\+\(.\+\)$')
    if !empty(_)
      call add(features, {
            \ 'word' : _[1],
            \ 'info' : _[2],
            \ })
    endif
  endfor

  call add(features, {
        \ 'word' : 'patch',
        \ 'menu' : '; Included patches Ex: patch123',
        \ })
  call add(features, {
        \ 'word' : 'patch-',
        \ 'menu' : '; Version and patches Ex: patch-7.4.237'
        \ })

  return features
endfunction
function! s:make_cache_functions() abort
  let helpfile = expand(findfile('doc/builtin.txt', &runtimepath))
  if !filereadable(helpfile)
    return []
  endif

  let lines = readfile(helpfile)
  let functions = []
  let start = match(lines, '^abs')
  let end = match(lines, '^abs', start, 2)
  if end <= 0
    " NOTE: In neovim 0.10+, |builtin-function-list| is removed.  Too bad.
    let end = match(lines, '^xor', start)
  endif
  for i in range(end - 1, start, -1)
    let func = matchstr(lines[i], '^\s*\zs\w\+(.\{-})')
    if func !=# ''
      call insert(functions, {
            \ 'word' : substitute(func, '(\zs.\+)', '', ''),
            \ 'abbr' : substitute(func, '(\zs\s\+', '', ''),
            \ 'info' : substitute(lines[i], '\t', ' ', 'g'),
            \ })
    endif
  endfor

  return functions
endfunction
function! s:make_cache_functions_nvim() abort
  let helpfile = expand(findfile('doc/api.txt', &runtimepath))
  if !filereadable(helpfile)
    return []
  endif

  let lines = readfile(helpfile)
  let functions = []
  let start = match(lines, '^nvim__get_hl_defs')
  let end = match(lines, '^nvim_ui_try_resize_grid')
  for i in range(end, start, -1)
    let func = matchstr(lines[i], '^\s*\zs\w\+(.\{-})')
    if func !=# ''
      call insert(functions, {
            \ 'word' : substitute(func, '(\zs.\+)', '', ''),
            \ 'abbr' : substitute(func, '(\zs\s\+', '', ''),
            \ 'info' : substitute(lines[i], '\t', ' ', 'g'),
            \ })
    endif
  endfor

  return functions
endfunction
function! s:make_cache_commands() abort
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
    let _ = matchlist(desc, '^|:\(.\{-}\)|\s\+\S\+\s\+\(.*\)$')
    if !empty(_)
      call add(commands, {
            \ 'word' : _[1], 'kind' : 'c',
            \ 'info': _[2],
            \ })
    endif
  endfor

  return commands
endfunction

function! s:get_cmdlist() abort
  let list = exists('*nvim_get_commands') ?
        \ keys(nvim_get_commands({'builtin': v:false})) :
        \ getcompletion('', 'command')
  return s:make_completion_list(list)
endfunction
function! s:get_variablelist(dict, prefix) abort
  let kind_dict =
        \ ['0', '""', '()', '[]', '{}', '.', 'b', 'no', 'j', 'ch']

  let list = []
  for [key, Val] in items(a:dict)
    let kind = '?'
    silent! let kind = kind_dict[type(Val)]
    call add(list, {
          \ 'word' : a:prefix . key,
          \ 'kind' : kind,
          \ })
  endfor
  return list
endfunction
function! s:get_functionlist() abort
  let keyword_dict = {}
  let function_prototypes = {}
  for line in split(execute('function'), '\n')
    let line = line[9:]
    if line =~# '^<SNR>'
      continue
    endif
    let orig_line = line

    let word = matchstr(line, '\h[[:alnum:]_:#.]*()\?')
    if word !=# ''
      let keyword_dict[word] = {
            \ 'word' : word, 'abbr' : line,
            \}

      let function_prototypes[word] = orig_line[len(word):]
    endif
  endfor

  let s:global_candidates_list.function_prototypes = function_prototypes

  return values(keyword_dict)
endfunction
function! s:get_augrouplist() abort
  return s:make_completion_list(getcompletion('', 'augroup'))
endfunction
function! s:get_mappinglist() abort
  let keyword_list = []
  for line in split(execute('map'), '\n')
    let map = matchstr(line, '^\a*\s*\zs\S\+')
    if map !~# '^<' || map =~# '^<SNR>'
      continue
    endif
    call add(keyword_list, { 'word' : map })
  endfor
  return keyword_list
endfunction
function! s:get_envlist() abort
  let keyword_list = []
  for line in split(system('set'), '\n')
    let word = '$' . toupper(matchstr(line, '^\h\w*'))
    call add(keyword_list, { 'word' : word, 'kind' : 'e' })
  endfor
  return keyword_list
endfunction

function! s:make_completion_list(list) abort
  return map(copy(a:list), { _, val -> val !=# '' && val[-1:] ==# '/' ?
        \  { 'word': val[:-2], 'abbr': val } : { 'word': val }
        \ })
endfunction
function! s:analyze_function_line(line, keyword_dict, prototype) abort
  " Get script function.
  let line = substitute(matchstr(a:line,
        \ '\<fu\%[nction]!\?\s\+\zs.*)'), '".*$', '', '')
  let orig_line = line
  let word = matchstr(line, '^\h[[:alnum:]_:#.]*()\?')
  if word !=# '' && !has_key(a:keyword_dict, word)
    let a:keyword_dict[word] = {
          \ 'word' : word, 'abbr' : line, 'kind' : 'f'
          \}
    let a:prototype[word] = orig_line[len(word):]
  endif
endfunction
function! s:analyze_variable_line(line, keyword_dict) abort
  if a:line =~# '\<\%(let\|const\|for\)\s\+\a[[:alnum:]_:]*'
    " let var = pattern.
    let word = matchstr(a:line,
          \ '\<\%(let\|const\|for\)\s\+\zs\a[[:alnum:]_:]*')
    let expression = matchstr(a:line,
          \ '\<\%(let\|const\)\s\+\a[[:alnum:]_:]*\s*=\s*\zs.*$')
    if !has_key(a:keyword_dict, word)
      let a:keyword_dict[word] = {
            \ 'word' : word,
            \ 'kind' : s:get_variable_type(expression)
            \}
    elseif expression !=# '' && a:keyword_dict[word].kind ==# ''
      " Update kind.
      let a:keyword_dict[word].kind = s:get_variable_type(expression)
    endif
  elseif a:line =~# '\<\%(let\|const\|for\)\s\+\[.\{-}\]'
    " let [var1, var2] = pattern.
    let words = split(matchstr(a:line,
          \'\<\%(let\|const\|for\)\s\+\[\zs.\{-}\ze\]'), '[,[:space:]]\+')
    let expressions = split(matchstr(a:line,
          \ '\<\%(let\|const\)\s\+\[.\{-}\]\s*=\s*\[\zs.\{-}\ze\]$'),
          \ '[,[:space:];]\+')

    let i = 0
    while i < len(words)
      let expression = get(expressions, i, '')
      let word = words[i]

      if !has_key(a:keyword_dict, word) 
        let a:keyword_dict[word] = {
              \ 'word' : word,
              \ 'kind' : s:get_variable_type(expression)
              \}
      elseif expression !=# '' && a:keyword_dict[word].kind ==# ''
        " Update kind.
        let a:keyword_dict[word].kind = s:get_variable_type(expression)
      endif

      let i += 1
    endwhile
  elseif a:line =~# '\<fu\%[nction]!\?\s\+'
    " Get function arguments.
    for arg in split(matchstr(a:line, '^[^(]*(\zs[^)]*'), '\s*,\s*')
      let word = 'a:' . (arg ==# '...' ?  '000' : matchstr(arg, '\w\+'))
      let a:keyword_dict[word] = {
            \ 'word' : word,
            \ 'kind' : (arg ==# '...' ?  '[]' : '')
            \}

    endfor
    if a:line =~# '\.\.\.)'
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
endfunction
function! s:analyze_dictionary_variable_line(line, keyword_dict, var_name) abort
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
  elseif kind !=# '' && a:keyword_dict[word].kind ==# ''
    " Update kind.
    let a:keyword_dict[word].kind = kind
  endif
endfunction

" Initialize return types.
function! s:set_dictionary_helper(variable, keys, value) abort
  for key in split(a:keys, ',')
    let a:variable[key] = a:value
  endfor
endfunction
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

function! s:get_variable_type(expression) abort
  " Analyze variable type.
  if a:expression =~# '^\%(\s*+\)\?\s*\d\+\.\d\+'
    return '.'
  elseif a:expression =~# '^\%(\s*+\)\?\s*\d\+'
    return '0'
  elseif a:expression =~# '^\%(\s*\.\)\?\s*["'']'
    return '""'
  elseif a:expression =~# '\<function('
    return '()'
  elseif a:expression =~# '^\%(\s*+\)\?\s*\['
    return '[]'
  elseif a:expression =~# '^\s*{\|^\.\h[[:alnum:]_:]*'
    return '{}'
  elseif a:expression =~# '\<\h\w*('
    " Function.
    let func_name = matchstr(a:expression, '\<\zs\h\w*\ze(')
    return get(s:function_return_types, func_name, '')
  else
    return ''
  endif
endfunction

function! s:set_dictionary_helper(variable, keys, pattern) abort
  for key in split(a:keys, '\s*,\s*')
    if !has_key(a:variable, key)
      let a:variable[key] = a:pattern
    endif
  endfor
endfunction

function! s:check_global_candidates(key) abort
  if s:global_candidates_list.runtimepath !=# &runtimepath
    let s:global_candidates_list.runtimepath = &runtimepath
    return 1
  endif

  return !has_key(s:global_candidates_list, a:key)
endfunction

" Removes duplicates from a list.
function! s:uniq(list) abort
  return s:uniq_by(a:list, 'v:val')
endfunction

" Removes duplicates from a list.
function! s:uniq_by(list, f) abort
  let list = map(copy(a:list), printf('[v:val, %s]', a:f))
  let i = 0
  let seen = {}
  while i < len(list)
    let key = string(list[i][1])
    if has_key(seen, key)
      call remove(list, i)
    else
      let seen[key] = 1
      let i += 1
    endif
  endwhile
  return map(list, { _, val -> val[0]})
endfunction
