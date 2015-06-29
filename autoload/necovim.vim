"=============================================================================
" FILE: necovim.vim
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

function! necovim#get_cur_text() "{{{
  let cur_text = neocomplete#get_cur_text(1)
  if &filetype == 'vimshell' && exists('*vimshell#get_secondary_prompt')
        \   && empty(b:vimshell.continuation)
    return cur_text[len(vimshell#get_secondary_prompt()) :]
  endif

  let line = line('.')
  let cnt = 0
  while cur_text =~ '^\s*\\' && line > 1 && cnt < 5
    let cur_text = getline(line - 1) .
          \ substitute(cur_text, '^\s*\\', '', '')
    let line -= 1
    let cnt += 1
  endwhile

  return split(cur_text, '\s\+|\s\+\|<bar>', 1)[-1]
endfunction"}}}
function! necovim#get_command(cur_text) "{{{
  return matchstr(a:cur_text, '\<\%(\d\+\)\?\zs\h\w*\ze!\?\|'.
        \ '\<\%([[:digit:],[:space:]$''<>]\+\)\?\zs\h\w*\ze/.*')
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
