# Référence technique

Détails complets du projet : architecture, scripts, tests, CI et versions. Pour une première session, voir [prise-en-main.md](prise-en-main.md).

## Sommaire

- [Arborescence](#arborescence)
- [Pipeline](#pipeline)
- [Le plugin](#le-plugin)
- [Commandes et options des scripts](#commandes-et-options-des-scripts)
- [Environnement embarqué](#environnement-embarqué)
- [Tests fonctionnels](#tests-fonctionnels)
- [Snapshots : ce qui entre dans un test](#snapshots--ce-qui-entre-dans-un-test)
- [Écritures et réseau](#écritures-et-réseau)
- [Vérifier une image](#vérifier-une-image)
- [Lancer Vim](#lancer-vim)
- [Intégration continue](#intégration-continue)
- [Versions et publication](#versions-et-publication)
- [Limites de validation](#limites-de-validation)

## Arborescence

```text
vim-hf-stt/
├── plugin/vim_hf_stt.vim      # commande :VimHfSttHello (chargée au démarrage)
├── autoload/vim_hf_stt.vim    # fonctions (chargées à la demande), version 0.1.0
├── tests/run.vim              # suite fonctionnelle commune aux deux parcours
├── tests/test-harness.sh      # régressions positives et négatives du harnais
├── .vimrc                     # configuration embarquée dans l’image
├── Dockerfile                 # Debian 12, vim-nox, Python3, git, curl, appuser
├── build.sh                   # build → verify → test
├── verify.sh                  # diagnostic de l’image (sans réseau)
├── test.sh                    # tests du plugin (local + installed)
├── release.sh                 # contrôle d’un tag existant, sans publication
├── run.sh                     # lancement interactif avec montages
├── install-plugins.sh         # vim-plug + PlugInstall au build
├── entrypoint.sh              # exec /usr/bin/vim "$@"
├── .github/workflows/ci.yml   # CI GitHub Actions
└── docs/                      # guides Markdown (hors snapshot de test)
```

## Pipeline

```text
build.sh
 ├── docker build --no-cache         (Dockerfile : paquets, scripts, .vimrc,
 │    │                               install-plugins.sh → vim-plug + PlugInstall)
 ├── verify.sh                       (image : fichiers, hash du vimrc, chargement, Python)
 └── test.sh --mode all
      ├── local    : snapshot → pack/test/start → vimrc embarqué → tests/run.vim
      └── installed: snapshot → dépôt Git file:// → PlugInstall → HOME isolé → tests/run.vim
```

## Le plugin

| Élément | Détail |
|---|---|
| Commande | `:VimHfSttHello [texte]` — affiche `Bonjour !` ou `Bonjour, <texte> !`. |
| Fonctions | `vim_hf_stt#hello(texte)`, `vim_hf_stt#version()` → `0.1.0`. |
| Chargement | `plugin/` au démarrage, `autoload/` à la demande. |
| Dépendances | Vim classique uniquement : ni Python, ni réseau, ni shell. |
| Garde | `g:loaded_vim_hf_stt` rend un second sourçage inoffensif. |

## Commandes et options des scripts

Tous les scripts se lancent depuis n’importe quel dossier (chemins calculés depuis le script), sauf `run.sh` qui monte **le dossier courant** comme espace de travail.

| Script | Usage | Options |
|---|---|---|
| `build.sh` | `./build.sh [options docker build]` | Tous les arguments sont transmis à `docker build` (ex. `--build-arg VIM_PLUG_REF=<commit>`). Pas d’option `--help` propre. |
| `run.sh` | `./run.sh [--local-plugin DIR] [--] [args Vim]` | `--local-plugin` monte un plugin en lecture seule ; `--` termine les options du lanceur ; `--help` affiche son aide, `-- --help` celle de Vim. |
| `verify.sh` | `./verify.sh [--image IMG] [--vimrc F] [--local-plugin DIR]` | `--vimrc` change la référence comparée (sans la charger) ; `--local-plugin` ajoute un plugin au diagnostic. |
| `test.sh` | `./test.sh [--mode M] [--image IMG] [--expected-version V] [--snapshot-ref C]` | `--mode` : `local`, `installed`, `all` (défaut) ; `--snapshot-ref` : archive un commit exact au lieu du worktree. |
| `tests/test-harness.sh` | `bash tests/test-harness.sh [--image IMG]` | Régressions du harnais sur fixtures temporaires. |
| `release.sh` | `./release.sh --check vX.Y.Z [--image IMG]` | Valide un tag existant sur HEAD ; ne crée ni commit, ni tag, ni publication. |

## Environnement embarqué

| Composant | Détail |
|---|---|
| Base | Debian 12, utilisateur `appuser` (UID 1000). |
| Vim | `vim-nox` (support Python3, sans X), Python 3, pip, venv, git, curl. |
| vim-plug | Téléchargé au build ; révision épinglable via `--build-arg VIM_PLUG_REF=<commit>`. |
| Plugins tiers | `vim-plug`, `visual-split.vim`, `vim-quickui`, `indentpython.vim`, `python-syntax`. |
| Configuration | `.vimrc` du dépôt copié dans `/home/appuser/.vimrc` ; c’est la référence de `verify.sh`. |

Reconstruisez (`./build.sh`) après toute modification du `Dockerfile`, du `.vimrc` ou des scripts d’installation. Le `.vimrc` fournit syntax highlighting, numérotation, indentation à 2 espaces, `clipboard=unnamedplus`, thème `evening` — aucun menu QuickUI personnalisé, et le presse-papiers hôte n’est pas garanti dans le conteneur.

## Tests fonctionnels

`test.sh` exécute **les mêmes assertions** (`tests/run.vim`) dans deux parcours :

| Mode | Mécanisme | Ce qui est prouvé |
|---|---|---|
| `local` | Snapshot monté en `pack/test/start/vim-hf-stt` (paquets natifs Vim) | Intégration avec le vimrc embarqué et le véritable entrypoint. |
| `installed` | Snapshot → dépôt Git temporaire → `PlugInstall` via `file:///tmp/repository` | Véritable clone vim-plug : `.git`, origine, commit et contenu vérifiés, puis Vim relancé avec un `HOME` isolé. |

Assertions couvertes : vimrc attendu sourcé (`$MYVIMRC`), vim-plug actif, commande présente au démarrage, autoload différé, origine exacte des scripts sourcés, salutations (espaces, accents, apostrophes, caractères spéciaux), arguments traités comme du texte, version, second sourçage, absence de modification du tampon et des options. Une erreur, un dépassement de 60 s ou une sortie avant la sentinelle font échouer le test.

## Snapshots : ce qui entre dans un test

| Mode | Source | Contenu |
|---|---|---|
| Défaut (worktree) | `git ls-files --cached --others --exclude-standard` | Fichiers suivis **et nouveaux non ignorés**, sous `plugin/`, `autoload/`, `README.md`, `LICENSE`, `tests/run.vim` uniquement. Modifications non commitées incluses. |
| `--snapshot-ref C` | `git archive` du commit | Fichiers suivis du commit exact ; aucune modification locale ni fichier ignoré. |

Seule l’archive tar est montée en lecture seule : jamais `.git`, ni fichiers personnels, ni socket Docker. Dans le conteneur, les sources sont extraites dans `/tmp/source` puis rendues non inscriptibles. Les guides de `docs/` ne font pas partie du snapshot fonctionnel.

> ⚠️ **N’ajoutez pas de secrets dans les chemins distribuables** (`plugin/`, `autoload/`, `README.md`, `LICENSE`, `tests/run.vim`) : ils entrent dans le snapshot de test.

## Écritures et réseau

| Script | Réseau | Écritures |
|---|---|---|
| `build.sh` | Requis (apt, vim-plug, plugins) | Image Docker locale. |
| `run.sh` | Réseau **hôte** | Dossier courant monté en écriture ; plugin local en lecture seule ; reste jetable (`--rm`). |
| `verify.sh` | **Aucun** (`--network=none`) | `/tmp` tmpfs 32 Mio ; racine en lecture seule ; plugin éventuel en lecture seule. |
| `test.sh` | **Aucun** | `/tmp` tmpfs 128 Mio ; archive en lecture seule. |
| `tests/test-harness.sh` | Aucun | Fixtures temporaires sous `mktemp -d`, supprimées en sortie. |
| `release.sh` | Aucun (hors appels à verify/test) | Lecture seule du dépôt ; aucune mutation Git. |

## Vérifier une image

`verify.sh` contrôle, dans un conteneur durci : présence/lecture/contenu de `.vimrc` et `plug.vim`, égalité SHA256 entre le vimrc embarqué et la référence, fichiers et chargement de chaque plugin déclaré, scripts effectivement sourcés, et un essai de syntaxe/indentation Python.

Limites : « non vide » ne signifie pas « correct » ; un plugin local monté via `--local-plugin` mais non chargé produit un **avertissement**, pas un échec ; les fonctions non exécutées ne sont pas validées. C’est un diagnostic de l’environnement — le contrat fonctionnel du plugin relève de `test.sh`.

## Lancer Vim

`run.sh` transmet les arguments à `exec /usr/bin/vim "$@"` : l’entrypoint est un simple passthrough, sans installateur ni réparation au démarrage. `--local-plugin` utilise le **chargement natif des paquets**, pas vim-plug : `:PlugInstall` ne le gère pas. TTY alloué seulement si entrée/sortie sont des terminaux ; contrôle non interactif possible :

```bash
./run.sh -N -n -es -u /home/appuser/.vimrc -i NONE -c 'qa!'
```

## Intégration continue

`.github/workflows/ci.yml` — déclencheurs : pull requests, pushes de branches et de tags `v*`, exécution manuelle.

| Étape | Action |
|---|---|
| Checkout | `actions/checkout` v4.2.2 épinglé au SHA, historique complet + tags, sans persistance des identifiants. |
| Scripts | `bash -n` + `shellcheck` sur `*.sh` et `tests/*.sh`. |
| Build | `./build.sh` (image + verify + test). |
| Régressions | `bash tests/test-harness.sh`. |
| Tag | `release.sh --check "$RELEASE_TAG"` (tags uniquement). |

Runner `ubuntu-24.04`, permissions `contents: read`, timeout 45 min, aucun secret ni publication. **La présence du workflow ne prouve pas une exécution distante réussie** : celle-ci se confirme après un push autorisé.

## Versions et publication

`release.sh --check vX.Y.Z` exige : tag stable existant (sans zéro initial) pointant exactement sur `HEAD`, checkout propre (ni modifications suivies ni fichiers non suivis non ignorés — les ignorés sont exclus de l’archive), fichiers requis suivis et non vides, puis `verify.sh` + `test.sh --snapshot-ref` avec `--expected-version` égal au tag sans `v`.

Procédure manuelle du mainteneur :

1. Mettre à jour la version du plugin et la documentation ; lancer `./build.sh` et `bash tests/test-harness.sh`.
2. Commiter les changements validés ; obtenir un checkout propre.
3. Créer le tag `vX.Y.Z` sur ce commit, puis `./release.sh --check vX.Y.Z`.
4. Après succès, pousser commit et tag **explicitement** ; vérifier la CI ; une release GitHub reste une action manuelle.
5. Tester alors l’installation depuis le vrai dépôt distant (`{ 'tag': 'vX.Y.Z' }` n’est utilisable qu’une fois le tag publié).

## Limites de validation

- Socle prouvé : **Vim 9 / Debian 12** dans l’image fournie — pas de garantie multi-OS ni Neovim.
- `file://` couvre le vrai clonage Git + `PlugInstall`, **pas** le DNS ni les droits du dépôt GitHub futur.
- `--no-cache` force la reconstruction, pas la reproductibilité : Debian, paquets et plugins tiers ne sont pas tous épinglés (`VIM_PLUG_REF` n’épingle que vim-plug).
- Les tests valident les scénarios exécutés ; les fonctions non appelées et les interactions GUI ne sont pas couvertes.
- Le commit de fixture affiché par `test.sh` est un snapshot de test, pas le SHA d’une release.

---

Retour au [README](../README.md) · Premier essai : [prise-en-main.md](prise-en-main.md)
