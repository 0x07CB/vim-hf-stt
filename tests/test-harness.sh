#!/bin/bash
set -euo pipefail

usage() { printf 'Usage: bash tests/test-harness.sh [--image IMAGE]\n'; }
fail() { printf 'ÉCHEC du harnais : %s\n' "$*" >&2; exit 1; }
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
image=vim-plug:vim-hf-stt
while (($#)); do
  case "$1" in
    --image)
      if (($# < 2)) || [[ -z $2 || $2 == -* ]]; then usage >&2; exit 2; fi
      image=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done
for command in bash git docker tar realpath mktemp cp find sort xargs sha256sum grep sed tr; do
  command -v "$command" >/dev/null || fail "commande introuvable : $command"
done
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
unset GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_TERMINAL_PROMPT=0 GIT_OPTIONAL_LOCKS=0
work_dir=$(mktemp -d)
trap 'rm -rf -- "$work_dir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
sources=(
  plugin/vim_hf_stt.vim autoload/vim_hf_stt.vim tests/run.vim
  README.md LICENSE .vimrc Dockerfile .dockerignore
  build.sh entrypoint.sh install-plugins.sh run.sh verify.sh test.sh release.sh
  tests/test-harness.sh .github/workflows/ci.yml
)
source_digest() { (cd -- "$script_dir"; sha256sum -- "${sources[@]}" | sha256sum); }
source_before=$(source_digest)
mkdir -p "$work_dir/base" "$work_dir/elsewhere"
for file in "${sources[@]}"; do
  [[ -s $script_dir/$file && ! -L $script_dir/$file ]] || fail "source requise absente ou non régulière : $file"
  (cd -- "$script_dir"; cp --parents -- "$file" "$work_dir/base/")
done
printf '/plugin/harness-ignored.vim\n' > "$work_dir/base/.gitignore"
git -C "$work_dir/base" init -q --initial-branch=main --template=
git -C "$work_dir/base" add -- .
git -C "$work_dir/base" -c user.name='Harness fixture' -c user.email='fixture@example.invalid' \
  -c commit.gpgsign=false commit -qm 'Temporary harness fixture'
version=$(sed -n "s/^  return '\([0-9][0-9.]*\)'$/\1/p" "$work_dir/base/autoload/vim_hf_stt.vim")
[[ $version =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || fail 'version du plugin indéterminée'
tag=v$version
wrong_version=999.0.0
if [[ $version == "$wrong_version" ]]; then wrong_version=999.0.1; fi
git -C "$work_dir/base" -c tag.gpgsign=false tag "$tag"
fixture_number=0
case_number=0
new_fixture() {
  fixture_number=$((fixture_number + 1))
  fixture=$work_dir/fixture-$fixture_number
  cp -a -- "$work_dir/base" "$fixture"
}
fixture_digest() {
  (
    cd -- "$fixture"
    find . -path ./.git -prune -o -type f -print0 | sort -z | xargs -0 sha256sum
    git status --porcelain=v1 --untracked-files=all
    git show-ref
    sha256sum .git/config .git/index
  ) | sha256sum
}
require_log() {
  if ! grep -Fq -- "$1" "$work_dir/output"; then
    cat "$work_dir/output" >&2
    fail "diagnostic absent : $1"
  fi
}
run_case() {
  local expectation=$1 diagnostic=$2 label=$3 before after status=0
  shift 3
  case_number=$((case_number + 1))
  printf '\n[%s] %s\n' "$case_number" "$label"
  before=$(fixture_digest)
  (cd -- "$work_dir/elsewhere"; "$@") > "$work_dir/output" 2>&1 || status=$?
  after=$(fixture_digest)
  [[ $before == "$after" ]] || fail "$label a modifié les sources ou les références de la fixture"
  if [[ $expectation == success ]]; then
    if ((status != 0)); then cat "$work_dir/output" >&2; fail "$label : code $status"; fi
  else
    if ((status == 0)); then cat "$work_dir/output" >&2; fail "$label a réussi au lieu d'échouer"; fi
    if [[ $expectation == cli && $status != 2 ]]; then
      cat "$work_dir/output" >&2; fail "$label : code $status au lieu de 2"
    fi
  fi
  require_log "$diagnostic"
  printf 'OK : %s (code %s)\n' "$label" "$status"
}
prepend_test() {
  printf '%s\n' "$1" > "$work_dir/run.vim"
  cat "$fixture/tests/run.vim" >> "$work_dir/run.vim"
  cp -- "$work_dir/run.vim" "$fixture/tests/run.vim"
}
new_fixture
for script in test release; do
  run_case success "Usage: ./$script.sh" "$script : aide" bash "$fixture/$script.sh" --help
  run_case cli "Usage: ./$script.sh" "$script : option inconnue" bash "$fixture/$script.sh" --unknown
  run_case cli 'valeur manquante pour --image' "$script : image sans valeur" bash "$fixture/$script.sh" --image
  run_case cli 'valeur manquante pour --image' "$script : option utilisée comme valeur" bash "$fixture/$script.sh" --image --help
done
for option in --mode --expected-version --snapshot-ref; do
  run_case cli "valeur manquante pour $option" "test : $option sans valeur" bash "$fixture/test.sh" "$option"
done
run_case cli 'Usage: ./test.sh' 'test : mode invalide' bash "$fixture/test.sh" --mode invalid
run_case cli 'version attendue invalide' 'test : version invalide' bash "$fixture/test.sh" --expected-version 01.2.3
run_case cli 'valeur manquante pour --check' 'release : tag sans valeur' bash "$fixture/release.sh" --check
for invalid_tag in '' not-a-tag v1.2.3-rc1 v01.2.3 v1.02.3 v1.2.03; do
  args=()
  if [[ -n $invalid_tag ]]; then args=(--check "$invalid_tag"); fi
  run_case cli 'exige un tag stable vX.Y.Z sans zéro initial' "release : tag invalide '$invalid_tag'" \
    bash "$fixture/release.sh" "${args[@]}"
done
run_case cli '--check répété' 'release : tag répété' bash "$fixture/release.sh" --check "$tag" --check "$tag"
run_case cli '--image répété' 'release : image répétée' bash "$fixture/release.sh" --check "$tag" --image "$image" --image "$image"
run_case failure 'Tag absent ou ne désignant pas un commit' 'release : tag inexistant' \
  bash "$fixture/release.sh" --check "v$wrong_version" --image "$image"
image_id=$(docker image inspect --format '{{.Id}}' "$image") || fail "image inaccessible : $image ; lancer build.sh avant ce harnais"
[[ $image_id =~ ^sha256:[a-f0-9]{64}$ ]] || fail 'identifiant Docker invalide'
missing_image="vim-hf-stt-harness-missing:$(basename -- "$work_dir" | tr '[:upper:]' '[:lower:]')"
if docker image inspect "$missing_image" >/dev/null 2>&1; then fail 'image de test supposée absente déjà présente'; fi
run_case failure 'image inaccessible' 'test : image absente' bash "$fixture/test.sh" --image "$missing_image"
run_case failure 'Image locale introuvable ou inaccessible' 'release : image absente' \
  bash "$fixture/release.sh" --check "$tag" --image "$missing_image"
run_case failure 'référence Git invalide' 'test : snapshot inexistant' \
  bash "$fixture/test.sh" --image "$image_id" --snapshot-ref refs/heads/harness-absent
run_case success 'SUCCÈS : tests fonctionnels installed terminés.' 'tests réels local et installé depuis un autre dossier' \
  bash "$fixture/test.sh" --image "$image_id" --mode all --expected-version "$version"
require_log 'SUCCÈS : tests fonctionnels local terminés.'
require_log 'clone vim-plug du snapshot temporaire'
for mode in local installed; do
  new_fixture
  rm -- "$fixture/plugin/vim_hf_stt.vim"
  run_case failure 'source absente, illisible ou non régulière : plugin/vim_hf_stt.vim' "$mode : fichier suivi absent" \
    bash "$fixture/test.sh" --image "$image_id" --mode "$mode"
  git -C "$fixture" rm -q -- plugin/vim_hf_stt.vim
  run_case failure 'fichier distribuable absent, vide ou non régulier : plugin/vim_hf_stt.vim' "$mode : plugin absent du snapshot" \
    bash "$fixture/test.sh" --image "$image_id" --mode "$mode"
  new_fixture
  printf 'let g:loaded_vim_hf_stt = 1\n' > "$fixture/plugin/vim_hf_stt.vim"
  run_case failure 'commande chargée au démarrage' "$mode : commande absente" \
    bash "$fixture/test.sh" --image "$image_id" --mode "$mode"
  new_fixture
  prepend_test "call assert_equal(1, 2, 'HARNESS_FALSE_ASSERT')"
  run_case failure 'HARNESS_FALSE_ASSERT' "$mode : assertion fausse" bash "$fixture/test.sh" --image "$image_id" --mode "$mode"
  new_fixture
  prepend_test "let \$MYVIMRC = ''"
  run_case failure 'vimrc attendu choisi automatiquement' "$mode : configuration non chargée" \
    bash "$fixture/test.sh" --image "$image_id" --mode "$mode"
  new_fixture
  prepend_test 'qa!'
  run_case failure 'Vim a quitté sans terminer les tests.' "$mode : sortie prématurée" \
    bash "$fixture/test.sh" --image "$image_id" --mode "$mode"
  new_fixture
  run_case failure 'version attendue' "$mode : version différente" \
    bash "$fixture/test.sh" --image "$image_id" --mode "$mode" --expected-version "$wrong_version"
  printf "call assert_report('HARNESS_UNTRACKED_PLUGIN')\n" > "$fixture/plugin/harness-new.vim"
  run_case failure 'HARNESS_UNTRACKED_PLUGIN' "$mode : nouveau fichier non ignoré inclus" \
    bash "$fixture/test.sh" --image "$image_id" --mode "$mode"
done
new_fixture
run_case failure 'installation ou contrôle des plugins interrompu' 'installateur réel : clone file:// impossible' \
  docker run --rm -i --pull=never --read-only --network=none --user appuser \
  --cap-drop=ALL --security-opt=no-new-privileges --tmpfs /tmp:rw,nosuid,nodev,size=128m \
  --entrypoint /bin/bash "$image_id" -s <<'CONTAINER'
set -euo pipefail
export GIT_TERMINAL_PROMPT=0 GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null LC_ALL=C.UTF-8
image_home=$HOME
export HOME=/tmp/harness-home
mkdir -p "$HOME/.vim/autoload"
cp -- "$image_home/.vim/autoload/plug.vim" "$HOME/.vim/autoload/plug.vim"
[[ ! -e /tmp/harness-absent-repository && ! -e $HOME/.vim/plugged ]]
cat > "$HOME/.vimrc" <<'VIMRC'
set nocompatible
call plug#begin('~/.vim/plugged')
Plug 'file:///tmp/harness-absent-repository', { 'as': 'harness-missing' }
call plug#end()
VIMRC
exec /usr/local/bin/install-vim-plugins
CONTAINER
require_log 'harness-missing'
require_log 'does not appear to be a git repository'
new_fixture
git -C "$fixture" -c user.name='Harness fixture' -c user.email='fixture@example.invalid' \
  -c commit.gpgsign=false commit --allow-empty -qm 'Different temporary HEAD'
run_case failure 'ne pointe pas sur HEAD' 'release : tag sur un autre commit' \
  bash "$fixture/release.sh" --check "$tag" --image "$image_id"
new_fixture
printf '\nHARNESS_DIRTY\n' >> "$fixture/README.md"
run_case failure 'Le dépôt doit être propre' 'release : fichier suivi modifié' \
  bash "$fixture/release.sh" --check "$tag" --image "$image_id"
git -C "$fixture" add -- README.md
run_case failure 'Le dépôt doit être propre' 'release : modification indexée' \
  bash "$fixture/release.sh" --check "$tag" --image "$image_id"
new_fixture
printf 'untracked\n' > "$fixture/harness-untracked"
run_case failure 'Le dépôt doit être propre' 'release : fichier non suivi' \
  bash "$fixture/release.sh" --check "$tag" --image "$image_id"
new_fixture
git -C "$fixture" -c tag.gpgsign=false tag "v$wrong_version"
run_case failure 'version attendue' 'release : version différente du tag' \
  bash "$fixture/release.sh" --check "v$wrong_version" --image "$image_id"
require_log 'Échec des tests de release'
new_fixture
printf "call assert_report('HARNESS_IGNORED_POISON')\n" > "$fixture/plugin/harness-ignored.vim"
git -C "$fixture" check-ignore -q -- plugin/harness-ignored.vim
run_case success "OK : tag $tag validé sur le commit" 'release réelle : snapshot archivé excluant le plugin ignoré' \
  bash "$fixture/release.sh" --check "$tag" --image "$image_id"
require_log "Sources suivies du commit : $(git -C "$fixture" rev-parse HEAD)"
require_log 'SUCCÈS : tests fonctionnels local terminés.'
require_log 'SUCCÈS : tests fonctionnels installed terminés.'
require_log 'clone vim-plug du snapshot temporaire'
require_log 'Aucune publication effectuée.'
git -C "$fixture" add -f -- plugin/harness-ignored.vim
run_case failure 'HARNESS_IGNORED_POISON' 'témoin : le plugin poison échoue dès son inclusion' \
  bash "$fixture/test.sh" --image "$image_id" --mode local
[[ $(source_digest) == "$source_before" ]] || fail 'les fichiers du dépôt original ont changé'
printf '\nSUCCÈS : %s scénarios du harnais ; dépôt original inchangé.\n' "$case_number"
