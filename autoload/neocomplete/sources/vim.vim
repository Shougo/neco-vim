"=============================================================================
" FILE: vim.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" License: MIT license
"=============================================================================

let s:source = {
      \ 'name' : 'vim',
      \ 'kind' : 'manual',
      \ 'filetypes' : { 'vim' : 1, 'vimconsole' : 1, },
      \ 'mark' : '[vim]',
      \ 'is_volatile' : 1,
      \ 'rank' : 300,
      \ 'input_pattern' : '\.\w*',
      \}

function! s:source.get_complete_position(context) abort
  return necovim#get_complete_position(a:context.input)
endfunction

function! s:source.gather_candidates(context) abort
  return necovim#gather_candidates(a:context.input, a:context.complete_str)
endfunction

function! neocomplete#sources#vim#define() abort
  return s:source
endfunction
