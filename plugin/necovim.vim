"=============================================================================
" FILE: necovim.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" License: MIT license
"=============================================================================

augroup necovim
  autocmd!
  autocmd BufWritePost,FileType vim call necovim#helper#make_cache()

  " Register source for NCM
  autocmd User CmSetup call cm#register_source({
        \ 'name': 'vim',
        \ 'abbreviation': 'vim',
        \ 'priority': 9,
        \ 'scoping': 1,
        \ 'scopes': ['vim'],
        \ 'cm_refresh': 'cm#sources#necovim#refresh',
        \ 'cm_refresh_patterns': ['\w\+\.$'],
        \ })
augroup END

let g:loaded_necovim = 1
