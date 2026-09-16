#!/bin/bash
set -euo pipefail

usage() {
  printf '%s\n' \
    'Usage: ./verify.sh [--image IMAGE] [--vimrc FICHIER] [--local-plugin DOSSIER]' \
    '' \
    'Vérifie la présence, le contenu non vide et le chargement des fichiers Vim.' \
    'Image par défaut : vim-plug:vim-hf-stt' \
    '--vimrc : référence à comparer, par défaut le .vimrc voisin de ce script.' \
    '--local-plugin : monte un plugin en lecture seule sous le nom de son dossier.' \
    "Exemple : ./verify.sh --local-plugin \"\$HOME/.config/vim-with-vimplug/plugins/vim-ollama\"" \
    'Code de sortie : 0 si les contrôles passent, non nul sinon.'
}

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
image=vim-plug:vim-hf-stt
reference_vimrc=$script_dir/.vimrc
plugin_dir=
plugin_name=
while (($#)); do
  case "$1" in
    --image|--local-plugin|--vimrc)
      if (($# < 2)) || [[ -z $2 || $2 == -* ]]; then
        printf 'ERREUR : valeur manquante pour %s\n' "$1" >&2
        exit 2
      fi
      case "$1" in
        --image) image=$2 ;;
        --local-plugin) plugin_dir=$2 ;;
        --vimrc) reference_vimrc=$2 ;;
      esac
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'ERREUR : option inconnue : %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ ! -f $reference_vimrc || ! -r $reference_vimrc || ! -s $reference_vimrc ]]; then
  printf 'ERREUR : vimrc de référence absent, illisible ou vide : %s\n' "$reference_vimrc" >&2
  exit 1
fi
reference_hash=$(sha256sum < "$reference_vimrc")
reference_hash=${reference_hash%% *}

command -v docker >/dev/null || { printf 'ERREUR : Docker est introuvable.\n' >&2; exit 1; }
mount_args=()
if [[ -n $plugin_dir ]]; then
  if [[ ! -d $plugin_dir || ! -r $plugin_dir || ! -x $plugin_dir ]]; then
    printf 'ERREUR : dossier du plugin absent, illisible ou inaccessible : %s\n' "$plugin_dir" >&2
    exit 1
  fi
  if (unset GLOBIGNORE; shopt -s nullglob dotglob; entries=("$plugin_dir"/*); ((${#entries[@]} == 0))); then
    printf 'ERREUR : dossier du plugin vide : %s. Fournissez les sources du plugin ou omettez --local-plugin.\n' "$plugin_dir" >&2
    exit 1
  fi
  plugin_dir=$(cd -- "$plugin_dir" && pwd -P)
  if [[ $plugin_dir == *,* ]]; then
    printf 'ERREUR : le chemin du montage Docker ne doit pas contenir de virgule.\n' >&2
    exit 2
  fi
  plugin_name=$(basename -- "$plugin_dir")
  if [[ $plugin_name == *[[:space:],]* ]]; then
    printf 'ERREUR : le nom du dossier du plugin ne doit contenir ni espace ni virgule : %s\n' "$plugin_name" >&2
    exit 2
  fi
  mount_args=(--mount "type=bind,src=$plugin_dir,dst=/home/appuser/.vim/pack/test/start/$plugin_name,readonly")
fi

if ! image_id=$(docker image inspect --format '{{.Id}}' "$image" 2>/dev/null); then
  printf 'ERREUR : image locale %s introuvable ou inaccessible. Vérifiez Docker et construisez cette image avec build.sh.\n' "$image" >&2
  exit 1
fi
printf '=== Vérification des fichiers Vim ===\nImage : %s\nIdentifiant : %s\n' "$image" "$image_id"
printf 'Vimrc de référence : %s\nSHA256 de référence : %s\n' "$reference_vimrc" "$reference_hash"
if [[ -n $plugin_dir ]]; then printf 'Plugin local : %s\n' "$plugin_dir"; fi

if docker run --rm -i --pull=never --read-only --network=none \
  --tmpfs /tmp:rw,nosuid,nodev,size=32m \
  --cap-drop=ALL --security-opt=no-new-privileges \
  "${mount_args[@]}" --env "VERIFY_LOCAL_PLUGIN=${plugin_dir:+1}" \
  --env "VERIFY_LOCAL_PLUGIN_DIR=/home/appuser/.vim/pack/test/start/$plugin_name" \
  --env "VERIFY_VIMRC_SHA256=$reference_hash" \
  --entrypoint /bin/bash "$image_id" -s <<'CONTAINER'
set -euo pipefail
printf '\n=== Configuration et gestionnaire ===\n'
status=0
for file in "$HOME/.vimrc" "$HOME/.vim/autoload/plug.vim"; do
  if [[ ! -f $file ]]; then
    printf 'ERREUR : fichier absent ou non régulier : %s\n' "$file"
    status=1
  elif [[ ! -r $file ]]; then
    printf 'ERREUR : fichier illisible : %s\n' "$file"
    status=1
  elif [[ ! -s $file ]]; then
    printf 'ERREUR : fichier vide : %s\n' "$file"
    status=1
  else
    printf 'OK : fichier présent, lisible et non vide : %s\n' "$file"
  fi
done
if ((status)); then exit "$status"; fi

embedded_hash=$(sha256sum < "$HOME/.vimrc")
embedded_hash=${embedded_hash%% *}
printf 'Vimrc embarqué : %s\nSHA256 embarqué : %s\n' "$HOME/.vimrc" "$embedded_hash"
config_status=0
if [[ $embedded_hash == "$VERIFY_VIMRC_SHA256" ]]; then
  printf 'OK : le vimrc embarqué est identique au fichier de référence.\n'
else
  printf 'ERREUR : le vimrc embarqué diffère du fichier de référence. Reconstruisez avec build.sh ou choisissez la bonne référence avec --vimrc.\n'
  config_status=1
fi

cat > /tmp/verify.vim <<'VIM'
let s:failures = []
function! s:report(message) abort
  call writefile([a:message], '/tmp/vim-report.log', 'a')
endfunction
function! s:check(condition, message) abort
  call s:report((a:condition ? 'OK : ' : 'ERREUR : ') . a:message)
  if !a:condition
    call add(s:failures, a:message)
  endif
endfunction
function! s:file(path) abort
  call s:check(filereadable(a:path) && getfsize(a:path) > 0, 'fichier présent, lisible et non vide : ' . a:path)
endfunction
function! s:plugin_files(name, directory) abort
  call s:check(isdirectory(a:directory), 'dossier du plugin ' . a:name . ' présent : ' . a:directory)
  let files = globpath(a:directory, '**/*.vim', 0, 1)
  call s:check(!empty(files), a:name . ' contient des scripts .vim')
  for file in files
    call s:file(file)
  endfor
endfunction
function! s:loaded_under(directory) abort
  let prefix = fnamemodify(a:directory, ':p')
  return filter(getscriptinfo(), 'stridx(fnamemodify(v:val.name, ":p"), prefix) == 0')
endfunction

try
  call s:report('=== Configuration chargée ===')
  call s:report('$MYVIMRC = ' . $MYVIMRC)
  call s:check($MYVIMRC ==# expand('~/.vimrc'), 'vimrc embarqué choisi automatiquement au démarrage')
  call s:check(index(map(getscriptinfo(), 'fnamemodify(v:val.name, ":p")'), expand('~/.vimrc')) >= 0, 'vimrc embarqué sourcé par Vim')
  call s:check(index(map(getscriptinfo(), 'fnamemodify(v:val.name, ":p")'), expand('~/.vim/autoload/plug.vim')) >= 0, 'gestionnaire vim-plug sourcé par Vim')
  call s:check(exists(':PlugInstall') == 2 && !empty(get(g:, 'plugs', {})), 'vim-plug actif et liste de plugins non vide')
  call s:report('=== Fichiers des plugins embarqués ===')
  for name in sort(keys(get(g:, 'plugs', {})))
    call s:plugin_files(name, g:plugs[name].dir)
    call s:check(index(map(split(&runtimepath, ','), 'fnamemodify(v:val, ":p")'), fnamemodify(g:plugs[name].dir, ':p')) >= 0, name . ' dans le chemin de chargement')
  endfor
  if $VERIFY_LOCAL_PLUGIN ==# '1'
    call s:report('=== Fichiers du plugin local ===')
    call s:plugin_files(fnamemodify($VERIFY_LOCAL_PLUGIN_DIR, ':t'), $VERIFY_LOCAL_PLUGIN_DIR)
  endif

  call s:report('=== Essai sur un tampon Python ===')
  enew
  file verification.py
  call setline(1, ['def verification():', 'pass'])
  setfiletype python
  normal! gg=G
  call s:check(&filetype ==# 'python' && get(b:, 'current_syntax', '') ==# 'python', 'syntaxe Python activée')
  call s:check(!empty(synIDattr(synID(1, 1, 1), 'name')), 'coloration du mot-clé Python def')
  call s:check(!empty(&l:indentexpr) && indent(2) > 0, 'indentation du corps de fonction Python')

  call s:report('=== Chargement observé ===')
  " Tout plugin non paresseux doit charger des scripts dans ce scénario, sauf
  " vim-plug (chargé depuis autoload) et les plugins déclarés avec on:/for:.
  for name in sort(keys(get(g:, 'plugs', {})))
    let scripts = s:loaded_under(g:plugs[name].dir)
    let spec = g:plugs[name]
    if name ==# 'vim-plug' || has_key(spec, 'on') || has_key(spec, 'for')
      if empty(scripts)
        call s:report('INFO : ' . name . ' : contenu contrôlé, aucun script chargé depuis ce dossier dans ce scénario.')
      endif
    else
      call s:check(!empty(scripts), name . ' chargé dans le scénario testé')
    endif
  endfor
  if $VERIFY_LOCAL_PLUGIN ==# '1'
    let local_scripts = s:loaded_under($VERIFY_LOCAL_PLUGIN_DIR)
    if empty(local_scripts)
      call s:report('AVERTISSEMENT : plugin local non chargé dans ce scénario ; seuls ses fichiers ont été contrôlés.')
    else
      call s:report('OK : plugin local sourcé par Vim')
    endif
  endif
  call s:report('=== Fichiers effectivement sourcés ===')
  for script in getscriptinfo()
    if script.name !=# '/tmp/verify.vim'
      call s:file(script.name)
    endif
  endfor
catch
  call s:check(0, v:exception . ' (' . v:throwpoint . ')')
endtry
if !empty(s:failures)
  cquit 1
endif
call writefile(['complete'], '/tmp/verify-complete')
qa!
VIM

status=0
timeout 60s /usr/local/bin/vim-entrypoint -N -n -i NONE -T dumb -V1/tmp/vim-startup.log \
  -S /tmp/verify.vim < /dev/null > /tmp/vim-output.log 2>&1 || status=$?
if [[ -f /tmp/vim-report.log ]]; then cat /tmp/vim-report.log; fi
if [[ ! -f /tmp/verify-complete ]] && ((status == 0)); then
  printf 'ERREUR : Vim a quitté avant la fin des contrôles.\n'
  status=1
fi
if ((status)); then
  cat /tmp/vim-output.log
  printf '\n=== Journal Vim (échec, code %s) ===\n' "$status"
  if [[ -f /tmp/vim-startup.log ]]; then cat /tmp/vim-startup.log; fi
else
  printf 'OK : aucun échec Vim pendant le chargement et les essais.\n'
fi
if ((config_status)); then status=1; fi
exit "$status"
CONTAINER
then
  printf '\nSUCCÈS : configuration identique, contrôles de présence, de contenu non vide et essais Vim terminés.\n'
  printf 'Non vide ne signifie pas entièrement correct : les scripts non chargés et leurs fonctions ne sont pas validés.\n'
else
  status=$?
  printf '\nÉCHEC : configuration différente, fichier absent, vide, illisible ou erreur pendant les contrôles (code %s).\n' "$status" >&2
  exit "$status"
fi
