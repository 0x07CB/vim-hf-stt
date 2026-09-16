#!/bin/bash
set -euo pipefail

usage() {
  printf '%s\n' \
    'Usage: ./test.sh [--image IMAGE] [--mode local|installed|all]' \
    '                 [--expected-version X.Y.Z] [--snapshot-ref COMMIT]' \
    'Teste un snapshot des sources, sans rebuild ni réseau.' \
    '--snapshot-ref : utilise exclusivement les fichiers du commit indiqué.'
}

fail() { printf 'ERREUR : %s\n' "$*" >&2; exit 1; }
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
image=vim-plug:vim-hf-stt
mode=all
expected_version=
snapshot_ref=
while (($#)); do
  case "$1" in
    --image|--mode|--expected-version|--snapshot-ref)
      if (($# < 2)) || [[ -z $2 || $2 == -* ]]; then
        printf 'ERREUR : valeur manquante pour %s\n' "$1" >&2
        exit 2
      fi
      case "$1" in
        --image) image=$2 ;;
        --mode) mode=$2 ;;
        --expected-version) expected_version=$2 ;;
        --snapshot-ref) snapshot_ref=$2 ;;
      esac
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done
case "$mode" in local|installed|all) ;; *) usage >&2; exit 2 ;; esac
if [[ -n $expected_version && ! $expected_version =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
  printf 'ERREUR : version attendue invalide.\n' >&2
  exit 2
fi
for command in docker git tar realpath; do
  command -v "$command" >/dev/null || fail "commande introuvable : $command"
done
image_id=$(docker image inspect --format '{{.Id}}' "$image") || fail "image inaccessible : $image"
[[ $image_id =~ ^sha256:[a-f0-9]{64}$ ]] || fail 'identifiant Docker invalide'
[[ $(git -C "$script_dir" rev-parse --show-toplevel) == "$script_dir" ]] || fail 'le script doit être à la racine de son dépôt Git'
work_dir=$(mktemp -d)
trap 'rm -f -- "$work_dir/snapshot.tar" "$work_dir/files"; rmdir -- "$work_dir"' EXIT
[[ $work_dir != *,* ]] || fail 'le chemin temporaire ne doit pas contenir de virgule'
paths=(plugin autoload README.md LICENSE tests/run.vim)
if [[ -n $snapshot_ref ]]; then
  snapshot_commit=$(git -C "$script_dir" rev-parse --verify --end-of-options "$snapshot_ref^{commit}") || fail 'référence Git invalide'
  git -C "$script_dir" ls-tree -r --format='%(objectmode)' "$snapshot_commit" -- "${paths[@]}" > "$work_dir/files"
  while IFS= read -r file_mode; do
    case "$file_mode" in
      100644|100755) ;;
      *) fail 'le snapshot doit contenir uniquement des fichiers réguliers, sans liens ni sous-modules' ;;
    esac
  done < "$work_dir/files"
  git -C "$script_dir" archive --format=tar "$snapshot_commit" -- "${paths[@]}" > "$work_dir/snapshot.tar"
  printf 'Sources suivies du commit : %s\n' "$snapshot_commit"
else
  git -C "$script_dir" ls-files -z --cached --others --exclude-standard --deduplicate -- "${paths[@]}" > "$work_dir/files"
  while IFS= read -r -d '' file; do
    [[ -f $script_dir/$file && -r $script_dir/$file && ! -L $script_dir/$file ]] || fail "source absente, illisible ou non régulière : $file"
    [[ $(realpath -- "$script_dir/$file") == "$script_dir/$file" ]] || fail "lien symbolique interdit dans les sources : $file"
  done < "$work_dir/files"
  tar -C "$script_dir" --create --file "$work_dir/snapshot.tar" --no-recursion --null --verbatim-files-from --files-from "$work_dir/files"
  printf 'Sources de travail : fichiers suivis et nouveaux fichiers non ignorés.\n'
fi
chmod 644 "$work_dir/snapshot.tar"
modes=("$mode")
if [[ $mode == all ]]; then modes=(local installed); fi
for current_mode in "${modes[@]}"; do
  printf '\n=== Tests %s (%s) ===\n' "$current_mode" "$image_id"
  docker run --rm -i --pull=never --read-only --network=none \
    --user appuser --cap-drop=ALL --security-opt=no-new-privileges \
    --tmpfs /tmp:rw,nosuid,nodev,size=128m \
    --mount "type=bind,src=$work_dir/snapshot.tar,dst=/snapshot.tar,readonly" \
    --env "TEST_MODE=$current_mode" --env "TEST_EXPECTED_VERSION=$expected_version" \
    --entrypoint /bin/bash "$image_id" -s <<'CONTAINER'
set -euo pipefail
export GIT_TERMINAL_PROMPT=0 GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
export LC_ALL=C.UTF-8
mkdir -p /tmp/source
tar -xf /snapshot.tar -C /tmp/source --no-same-owner --no-same-permissions
for file in plugin/vim_hf_stt.vim autoload/vim_hf_stt.vim README.md LICENSE tests/run.vim; do
  if [[ ! -f /tmp/source/$file || ! -s /tmp/source/$file || -L /tmp/source/$file ]]; then
    printf 'ERREUR : fichier distribuable absent, vide ou non régulier : %s\n' "$file" >&2
    exit 1
  fi
done
chmod -R a-w /tmp/source
export TEST_REPORT=/tmp/test-report TEST_COMPLETE=/tmp/test-complete
vim_args=()
if [[ $TEST_MODE == local ]]; then
  mkdir -p /tmp/native/pack/test/start
  ln -s /tmp/source /tmp/native/pack/test/start/vim-hf-stt
  export TEST_PLUGIN_DIR=/tmp/source
  vim_args=(--cmd 'set packpath^=/tmp/native')
else
  mkdir -p /tmp/repository
  cp -R /tmp/source/plugin /tmp/source/autoload /tmp/source/README.md /tmp/source/LICENSE /tmp/repository/
  git -C /tmp/repository init -q --initial-branch=main
  git -C /tmp/repository add -- plugin autoload README.md LICENSE
  git -C /tmp/repository -c user.name='Vim test fixture' -c user.email='fixture@example.invalid' -c commit.gpgsign=false commit -qm 'Snapshot de test'
  export TEST_SNAPSHOT_COMMIT
  TEST_SNAPSHOT_COMMIT=$(git -C /tmp/repository rev-parse HEAD)
  image_home=$HOME
  export HOME=/tmp/home
  mkdir -p "$HOME/.vim/autoload"
  cp "$image_home/.vim/autoload/plug.vim" "$HOME/.vim/autoload/plug.vim"
  if [[ -n $TEST_EXPECTED_VERSION ]]; then
    git -C /tmp/repository -c tag.gpgsign=false tag "v$TEST_EXPECTED_VERSION"
  fi
  cat > "$HOME/.vimrc" <<'VIMRC'
set nocompatible
set encoding=utf-8
call plug#begin('~/.vim/plugged')
if empty($TEST_EXPECTED_VERSION)
  Plug 'file:///tmp/repository', { 'as': 'vim-hf-stt', 'commit': $TEST_SNAPSHOT_COMMIT }
else
  Plug 'file:///tmp/repository', { 'as': 'vim-hf-stt', 'tag': 'v' . $TEST_EXPECTED_VERSION }
endif
call plug#end()
VIMRC
  export TEST_PLUGIN_DIR=$HOME/.vim/plugged/vim-hf-stt
  [[ ! -e $TEST_PLUGIN_DIR ]]
  /usr/local/bin/install-vim-plugins
  [[ -d $TEST_PLUGIN_DIR/.git ]]
  [[ $(git -C "$TEST_PLUGIN_DIR" rev-parse HEAD) == "$TEST_SNAPSHOT_COMMIT" ]]
  [[ $(git -C "$TEST_PLUGIN_DIR" remote get-url origin) == file:///tmp/repository ]]
  [[ -z $(git -C "$TEST_PLUGIN_DIR" status --porcelain --untracked-files=all) ]]
  while IFS= read -r -d '' file; do
    cmp -- "/tmp/repository/$file" "$TEST_PLUGIN_DIR/$file"
  done < <(git -C /tmp/repository ls-files -z)
  printf 'OK : clone vim-plug du snapshot temporaire %s, origine et contenu vérifiés.\n' "$TEST_SNAPSHOT_COMMIT"
fi
export TEST_VIMRC=$HOME/.vimrc
status=0
timeout --kill-after=5s 60s /usr/local/bin/vim-entrypoint -N -n -i NONE -T dumb -V1/tmp/vim-startup.log \
  "${vim_args[@]}" -S /tmp/source/tests/run.vim < /dev/null > /tmp/vim-output.log 2>&1 || status=$?
if [[ -f $TEST_REPORT ]]; then cat "$TEST_REPORT"; fi
if [[ ! -s $TEST_COMPLETE ]]; then
  printf 'ERREUR : Vim a quitté sans terminer les tests.\n' >&2
  if ((status == 0)); then status=1; fi
fi
if ((status)); then
  cat /tmp/vim-output.log
  if [[ -f /tmp/vim-startup.log ]]; then cat /tmp/vim-startup.log; fi
  exit "$status"
fi
printf 'SUCCÈS : tests fonctionnels %s terminés.\n' "$TEST_MODE"
CONTAINER
done
