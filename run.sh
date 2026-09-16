#!/bin/bash
set -euo pipefail

PLUGIN_DIR=
HOST_DIR="$(pwd -P)" # <-- Dossier courant du terminal
USERNAME=appuser
IMAGE_NAME=debian-vim:vim-plug

while (($#)); do
  case "$1" in
    --local-plugin)
      if (($# < 2)) || [[ -z $2 || $2 == -* ]]; then
        printf 'ERREUR : --local-plugin attend un dossier existant.\n' >&2
        exit 2
      fi
      PLUGIN_DIR=$2
      shift 2
      ;;
    --help)
      printf '%s\n' \
        'Usage: ./run.sh [--local-plugin DOSSIER] [--] [arguments Vim...]' \
        'Sans --local-plugin, seuls les plugins embarqués sont disponibles.' \
        'Les options du lanceur doivent précéder les arguments Vim.' \
        "Utilisez ./run.sh -- --help pour afficher l'aide de Vim."
      exit 0
      ;;
    --) shift; break ;;
    *) break ;;
  esac
done

MOUNT_ARGS=()
# Vérifie le dossier du plugin uniquement lorsqu'il est demandé
if [[ -n $PLUGIN_DIR ]]; then
  if [[ ! -d $PLUGIN_DIR || ! -r $PLUGIN_DIR || ! -x $PLUGIN_DIR ]]; then
    printf 'ERREUR : dossier du plugin absent, illisible ou inaccessible : %s\n' "$PLUGIN_DIR" >&2
    exit 1
  fi
  if (unset GLOBIGNORE; shopt -s nullglob dotglob; entries=("$PLUGIN_DIR"/*); ((${#entries[@]} == 0))); then
    printf 'ERREUR : dossier du plugin vide : %s. Fournissez les sources du plugin ou omettez --local-plugin.\n' "$PLUGIN_DIR" >&2
    exit 1
  fi
  PLUGIN_DIR="$(cd -- "$PLUGIN_DIR" && pwd -P)"
  plugin_name=$(basename -- "$PLUGIN_DIR")
  if [[ $plugin_name == *[[:space:],]* ]]; then
    printf 'ERREUR : le nom du dossier du plugin ne doit contenir ni espace ni virgule : %s\n' "$plugin_name" >&2
    exit 2
  fi
  MOUNT_ARGS=(--mount "type=bind,src=$PLUGIN_DIR,dst=/home/$USERNAME/.vim/pack/test/start/$plugin_name,readonly")
fi

# Vérifie le dossier courant sans le créer
if [[ ! -d $HOST_DIR || ! -r $HOST_DIR || ! -x $HOST_DIR ]]; then
  printf 'ERREUR : dossier de travail absent, illisible ou inaccessible : %s\n' "$HOST_DIR" >&2
  exit 1
fi

if [[ $PLUGIN_DIR == *,* || $HOST_DIR == *,* ]]; then
  printf 'ERREUR : les chemins des montages Docker ne doivent pas contenir de virgule.\n' >&2
  exit 2
fi

if ! command -v docker >/dev/null; then
  printf 'ERREUR : Docker est introuvable.\n' >&2
  exit 1
fi

if ! docker image inspect "$IMAGE_NAME" >/dev/null; then
  printf 'ERREUR : image locale %s introuvable ou inaccessible. Vérifiez Docker et construisez cette image avec build.sh.\n' "$IMAGE_NAME" >&2
  exit 1
fi

TTY_ARGS=()
if [[ -t 0 && -t 1 ]]; then
  TTY_ARGS=(-t)
fi

exec docker run -i "${TTY_ARGS[@]}" --rm --pull=never --network=host \
  "${MOUNT_ARGS[@]}" \
  --mount "type=bind,src=$HOST_DIR,dst=/home/$USERNAME/work" \
  -u "$USERNAME" \
  -w "/home/$USERNAME/work" \
  "$IMAGE_NAME" "$@"
