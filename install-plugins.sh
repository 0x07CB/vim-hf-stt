#!/bin/bash
set -euo pipefail

export GIT_TERMINAL_PROMPT=0
work_dir=$(mktemp -d)
plug_download=
trap 'rm -f -- "$work_dir/output" "$work_dir/complete" ${plug_download:+"$plug_download"}; rmdir -- "$work_dir"' EXIT
export VIM_INSTALL_COMPLETE="$work_dir/complete"

if [[ ! -s $HOME/.vim/autoload/plug.vim ]]; then
  printf 'Installation du gestionnaire vim-plug...\n' >&2
  mkdir -p "$HOME/.vim/autoload"
  plug_download=$(mktemp "$HOME/.vim/autoload/plug.vim.XXXXXX")
  curl --fail --show-error --silent --location --connect-timeout 10 --max-time 60 \
    --retry 2 --retry-max-time 120 \
    --output "$plug_download" \
    "https://raw.githubusercontent.com/junegunn/vim-plug/${VIM_PLUG_REF:-master}/plug.vim"
  [[ -s $plug_download ]] || { printf 'ERREUR : téléchargement vim-plug vide.\n' >&2; exit 1; }
  mv -- "$plug_download" "$HOME/.vim/autoload/plug.vim"
  plug_download=
fi

status=0
timeout --kill-after=5s 180s vim -N -n -es --noplugin -u "$HOME/.vimrc" -i NONE -V1 \
  -S /dev/stdin > "$work_dir/output" 2>&1 <<'VIM' || status=$?
function! s:valid_plugin(spec) abort
  if !isdirectory(a:spec.dir)
    return 0
  endif
  if has_key(a:spec, 'uri')
    if !isdirectory(a:spec.dir . '/.git') && !filereadable(a:spec.dir . '/.git')
      return 0
    endif
    call system('git -C ' . shellescape(a:spec.dir) . ' rev-parse --verify HEAD')
    if v:shell_error
      return 0
    endif
  endif
  let files = globpath(a:spec.dir, '**/*.vim', 0, 1)
  return !empty(files) && empty(filter(files, '!filereadable(v:val) || getfsize(v:val) <= 0'))
endfunction

try
  if !empty(v:errmsg)
    throw v:errmsg
  endif
  if exists(':PlugInstall') != 2 || empty(get(g:, 'plugs', {}))
    throw 'vim-plug inactif ou liste de plugins vide'
  endif
  let missing = filter(copy(g:plugs), '!isdirectory(v:val.dir)')
  if !empty(missing)
    echom 'Installation des plugins manquants : ' . join(sort(keys(missing)), ', ')
    PlugInstall --sync
    let errors = filter(getline(1, '$'), 'v:val =~# "^x "')
    if !empty(errors)
      for message in getline(1, '$')
        echom message
      endfor
      throw join(errors, '; ')
    endif
  endif
  let invalid = filter(copy(g:plugs), '!s:valid_plugin(v:val)')
  if !empty(invalid)
    throw 'Plugins absents ou incomplets (aucune suppression automatique) : ' . join(sort(keys(invalid)), ', ')
  endif
catch
  echom 'ERREUR : ' . v:exception . ' (' . v:throwpoint . ')'
  cquit 1
endtry
call writefile(['complete'], $VIM_INSTALL_COMPLETE)
qa!
VIM

if ((status != 0)) || [[ ! -s $work_dir/complete ]]; then
  cat "$work_dir/output" >&2
  printf 'ERREUR : installation ou contrôle des plugins interrompu (code %s).\n' "$status" >&2
  if ((status == 0)); then status=1; fi
  exit "$status"
fi
