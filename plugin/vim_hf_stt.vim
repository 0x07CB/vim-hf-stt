if exists('g:loaded_vim_hf_stt')
  finish
endif
let g:loaded_vim_hf_stt = 1

command! -nargs=* VimHfSttHello echo vim_hf_stt#hello(<q-args>)
