#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

if ! command -v docker >/dev/null; then
  printf 'ERREUR : Docker est introuvable.\n' >&2
  exit 1
fi

docker build --no-cache -t vim-plug:vim-hf-stt "$@" "$SCRIPT_DIR"
bash "$SCRIPT_DIR/verify.sh" --image vim-plug:vim-hf-stt
bash "$SCRIPT_DIR/test.sh" --image vim-plug:vim-hf-stt --mode all
