#!/bin/bash
set -euo pipefail

usage() {
  printf '%s\n' \
    'Usage: ./release.sh --check vX.Y.Z [--image IMAGE]' \
    'Valide un tag stable existant sur HEAD, sans publication ni modification Git.' \
    'Image par défaut : vim-plug:vim-hf-stt'
}

fail() {
  printf 'ERREUR : %s\n' "$*" >&2
  exit 1
}

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
tag=
image=vim-plug:vim-hf-stt
image_set=0
while (($#)); do
  case "$1" in
    --check|--image)
      if (($# < 2)) || [[ -z $2 || $2 == -* ]]; then
        printf 'ERREUR : valeur manquante pour %s\n' "$1" >&2
        exit 2
      fi
      case "$1" in
        --check)
          [[ -z $tag ]] || { printf 'ERREUR : --check répété.\n' >&2; exit 2; }
          tag=$2
          ;;
        --image)
          ((image_set == 0)) || { printf 'ERREUR : --image répété.\n' >&2; exit 2; }
          image=$2
          image_set=1
          ;;
      esac
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'ERREUR : option inconnue : %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ ! $tag =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
  printf 'ERREUR : --check exige un tag stable vX.Y.Z sans zéro initial.\n' >&2
  exit 2
fi
command -v git >/dev/null || fail 'Git est introuvable.'
export GIT_OPTIONAL_LOCKS=0
if ! repo_root=$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null); then
  fail 'Le dossier du script ne se trouve pas dans un dépôt Git.'
fi
repo_root=$(cd -- "$repo_root" && pwd -P)
[[ $repo_root == "$script_dir" ]] || fail 'release.sh doit se trouver à la racine du dépôt Git.'
if ! commit=$(git -C "$script_dir" rev-parse --verify 'HEAD^{commit}' 2>/dev/null); then
  fail 'HEAD ne désigne pas un commit.'
fi
if ! tag_commit=$(git -C "$script_dir" rev-parse --verify "refs/tags/$tag^{commit}" 2>/dev/null); then
  fail "Tag absent ou ne désignant pas un commit : $tag"
fi
[[ $tag_commit == "$commit" ]] || fail "Le tag $tag ne pointe pas sur HEAD ($commit)."
if ! status=$(git -C "$script_dir" status --porcelain=v1 --untracked-files=all --ignore-submodules=none); then
  fail "Impossible de vérifier l'état du dépôt."
fi
if [[ -n $status ]]; then
  printf '%s\n' "$status" >&2
  fail 'Le dépôt doit être propre, y compris les fichiers non suivis non ignorés.'
fi

required_files=(
  plugin/vim_hf_stt.vim autoload/vim_hf_stt.vim tests/run.vim
  README.md LICENSE .vimrc Dockerfile .dockerignore
  build.sh entrypoint.sh install-plugins.sh run.sh verify.sh test.sh release.sh
  tests/test-harness.sh .github/workflows/ci.yml
)
for file in "${required_files[@]}"; do
  if ! entry=$(git -C "$script_dir" ls-tree "$commit" -- "$file"); then
    fail "Impossible de contrôler le fichier suivi : $file"
  fi
  [[ $entry == '100644 blob '* || $entry == '100755 blob '* ]] || fail "Fichier régulier absent du commit $commit : $file"
  if ! size=$(git -C "$script_dir" cat-file -s "$commit:$file"); then
    fail "Impossible de lire le fichier du commit : $file"
  fi
  ((size > 0)) || fail "Fichier vide dans le commit : $file"
  [[ -f $script_dir/$file && ! -L $script_dir/$file && -r $script_dir/$file && -s $script_dir/$file ]] || fail "Fichier de travail absent, vide ou non régulier : $file"
done

command -v docker >/dev/null || fail 'Docker est introuvable.'
if ! image_id=$(docker image inspect --format '{{.Id}}' "$image" 2>/dev/null); then
  fail "Image locale introuvable ou inaccessible : $image. Construisez-la avec build.sh."
fi
[[ $image_id =~ ^sha256:[0-9a-f]{64}$ ]] || fail "Identifiant Docker invalide pour l'image : $image"
printf '=== Contrôle de release sans publication ===\nTag : %s\nCommit : %s\nImage : %s\nIdentifiant : %s\n' "$tag" "$commit" "$image" "$image_id"
if ! bash "$script_dir/verify.sh" --image "$image_id"; then
  fail "Échec de la vérification de l'image pour $tag ($commit)."
fi
if ! bash "$script_dir/test.sh" --image "$image_id" --mode all --expected-version "${tag#v}" --snapshot-ref "$commit"; then
  fail "Échec des tests de release pour $tag ($commit)."
fi
printf 'OK : tag %s validé sur le commit %s. Aucune publication effectuée.\n' "$tag" "$commit"
