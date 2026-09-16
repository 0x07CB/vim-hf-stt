scriptencoding utf-8

function! s:scripts() abort
  return map(getscriptinfo(), 'resolve(fnamemodify(v:val.name, ":p"))')
endfunction

try
  call assert_equal('', v:errmsg, 'aucune erreur au démarrage')
  call assert_equal($TEST_VIMRC, $MYVIMRC, 'vimrc attendu choisi automatiquement')
  call assert_true(index(s:scripts(), $TEST_VIMRC) >= 0, 'vimrc attendu effectivement sourcé')
  call assert_equal(2, exists(':PlugInstall'), 'vim-plug chargé')
  if $TEST_MODE ==# 'installed'
    call assert_equal(['vim-hf-stt'], keys(get(g:, 'plugs', {})), 'seul le plugin testé est déclaré')
  endif
  call assert_equal(2, exists(':VimHfSttHello'), 'commande chargée au démarrage')
  let s:root = substitute(resolve(fnamemodify($TEST_PLUGIN_DIR, ':p')), '/\+$', '', '')
  let s:plugin = s:root . '/plugin/vim_hf_stt.vim'
  let s:autoload = s:root . '/autoload/vim_hf_stt.vim'
  call assert_equal([s:plugin], filter(s:scripts(), 'v:val =~# "/plugin/vim_hf_stt\.vim$"'), 'origine du plugin')
  call assert_equal([], filter(s:scripts(), 'v:val =~# "/autoload/vim_hf_stt\.vim$"'), 'autoload différé')
  let s:before = [getline(1, '$'), getpos('.'), &modified, &number, &expandtab, &shiftwidth, &runtimepath, &packpath]
  call assert_equal('Bonjour !', trim(execute('VimHfSttHello')))
  call assert_equal('Bonjour !', vim_hf_stt#hello(''))
  for s:name in ['Ada', 'Ada Lovelace', "Élodie d'Avignon", 'x | let g:vim_hf_stt_injected = 1', 'a"b\c']
    call assert_equal('Bonjour, ' . s:name . ' !', vim_hf_stt#hello(s:name))
    call assert_equal('Bonjour, ' . s:name . ' !', trim(execute('VimHfSttHello ' . s:name)))
  endfor
  call assert_false(exists('g:vim_hf_stt_injected'), 'arguments traités comme du texte')
  call assert_match('^\%(0\|[1-9][0-9]*\)\.\%(0\|[1-9][0-9]*\)\.\%(0\|[1-9][0-9]*\)$', vim_hf_stt#version())
  if !empty($TEST_EXPECTED_VERSION)
    call assert_equal($TEST_EXPECTED_VERSION, vim_hf_stt#version(), 'version attendue')
  endif
  call assert_equal([s:autoload], filter(s:scripts(), 'v:val =~# "/autoload/vim_hf_stt\.vim$"'), 'origine de l’autoload')
  execute 'source ' . fnameescape(s:plugin)
  call assert_equal('Bonjour, Ada !', trim(execute('VimHfSttHello Ada')), 'second sourçage inoffensif')
  call assert_equal(s:before, [getline(1, '$'), getpos('.'), &modified, &number, &expandtab, &shiftwidth, &runtimepath, &packpath], 'aucun changement du buffer ou des options')
  call assert_equal('', v:errmsg, 'aucune erreur pendant les tests')
catch
  call add(v:errors, v:exception . ' (' . v:throwpoint . ')')
endtry

if !empty(v:errors)
  call writefile(v:errors, $TEST_REPORT)
  cquit 1
endif
call writefile(['OK : commande, fonctions, autoload, origine et absence d’effets indésirables.'], $TEST_REPORT)
call writefile(['complete'], $TEST_COMPLETE)
qa!
