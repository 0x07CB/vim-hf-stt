function! vim_hf_stt#hello(name) abort
  return empty(a:name) ? 'Bonjour !' : 'Bonjour, ' . a:name . ' !'
endfunction

function! vim_hf_stt#version() abort
  return '0.1.0'
endfunction
