"=============================================================================
" FILE: vim.vim
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

" Global options definition. "{{{
let g:necovim#complete_functions =
      \ get(g:, 'necovim#complete_functions', {})
"}}}

let s:source = {
      \ 'name' : 'vim',
      \ 'kind' : 'manual',
      \ 'filetypes' : { 'vim' : 1, 'vimconsole' : 1, },
      \ 'mark' : '[vim]',
      \ 'is_volatile' : 1,
      \ 'rank' : 300,
      \ 'hooks' : {},
      \}

function! s:source.hooks.on_init(context) "{{{
  " Initialize.

  autocmd neocomplete FileType *
        \ call necovim#helper#on_filetype()

  " Initialize check.
  call necovim#helper#on_filetype()
endfunction"}}}

function! s:source.get_complete_position(context) "{{{
  let cur_text = necovim#get_cur_text()

  if cur_text =~ '^\s*"'
    " Comment.
    return -1
  endif

  let pattern = '\.\%(\h\w*\)\?$\|' .
        \ neocomplete#get_keyword_pattern_end('vim', self.name)

  let [complete_pos, complete_str] =
        \ neocomplete#helper#match_word(a:context.input, pattern)
  if complete_pos < 0
    " Use args pattern.
    let [complete_pos, complete_str] =
          \ neocomplete#helper#match_word(a:context.input, '\S\+$')
  endif

  return complete_pos
endfunction"}}}

function! s:source.gather_candidates(context) "{{{
  let cur_text = necovim#get_cur_text()

  if cur_text =~ '\h\w*\.\%(\h\w*\)\?$'
    " Dictionary.
    let complete_str = matchstr(cur_text, '.\%(\h\w*\)\?$')
    return necovim#helper#var_dictionary(
          \ cur_text, complete_str)
  elseif a:context.complete_str =~# '^&\%([gl]:\)\?'
    " Options.
    let prefix = matchstr(a:context.complete_str, '^&\%([gl]:\)\?')
    let list = deepcopy(
          \ necovim#helper#option(
          \   cur_text, a:context.complete_str))
    for keyword in list
      let keyword.word =
            \ prefix . keyword.word
    endfor
  elseif a:context.complete_str =~? '^\c<sid>'
    " SID functions.
    let prefix = matchstr(a:context.complete_str, '^\c<sid>')
    let complete_str = substitute(
          \ a:context.complete_str, '^\c<sid>', 's:', '')
    let list = deepcopy(
          \ necovim#helper#function(
          \     cur_text, complete_str))
    for keyword in list
      let keyword.word = prefix . keyword.word[2:]
      let keyword.abbr = prefix .
            \ get(keyword, 'abbr', keyword.word)[2:]
    endfor
  elseif cur_text =~# '\<has([''"]\w*$'
    " Features.
    let list = necovim#helper#feature(
          \ cur_text, a:context.complete_str)
  elseif cur_text =~# '\<expand([''"][<>[:alnum:]]*$'
    " Expand.
    let list = necovim#helper#expand(
          \ cur_text, a:context.complete_str)
  elseif a:context.complete_str =~ '^\$'
    " Environment.
    let list = necovim#helper#environment(
          \ cur_text, a:context.complete_str)
  elseif cur_text =~ '^[[:digit:],[:space:][:tab:]$''<>]*!\s*\f\+$'
    " Shell commands.
    let list = necovim#helper#shellcmd(
          \ cur_text, a:context.complete_str)
  else
    " Commands.
    let list = necovim#helper#command(
          \ cur_text, a:context.complete_str)
  endif

  return list
endfunction"}}}

function! neocomplete#sources#vim#define() "{{{
  return s:source
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
