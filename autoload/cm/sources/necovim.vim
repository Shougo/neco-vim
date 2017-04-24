"=============================================================================
" FILE: necovim.vim (NCM source)
" AUTHOR:  Karl Yngve Lervåg <karl.yngve@gmail.com>
" License: MIT license
"=============================================================================

function! cm#sources#necovim#refresh(opt, ctx)
  let startcol = necovim#get_complete_position(a:ctx.typed)
  let base = strpart(a:ctx.typed, startcol)
  let cnd = necovim#gather_candidates(a:ctx.typed, base)
  call cm#complete(a:opt.name, a:ctx, startcol+1, cnd)
endfunction
