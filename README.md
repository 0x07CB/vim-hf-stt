# vim-hf-stt

Un **plugin Vim de démonstration**, installable via [vim-plug](https://github.com/junegunn/vim-plug) depuis la racine de ce dépôt, accompagné d’un **environnement Docker** complet pour le développer, le tester et préparer ses versions.

> **État réel** : le plugin est un squelette en Vimscript (version `0.1.0` prévue, non publiée). Il n’implémente **pas encore** de reconnaissance vocale, de modèle ni d’appel réseau, malgré le nom du projet. Docker et Python n’appartiennent qu’à l’environnement de développement : **le plugin lui-même n’en a pas besoin**.

## 🚀 Démarrage rapide

Depuis la racine d’un checkout Git du projet, avec Docker accessible :

```bash
./build.sh                      # construit l’image, vérifie et teste tout
./run.sh --local-plugin "$PWD"  # ouvre Vim avec le plugin local chargé
```

Dans Vim, en mode normal :

```vim
:VimHfSttHello
:VimHfSttHello Ada Lovelace
```

Résultats attendus : `Bonjour !` puis `Bonjour, Ada Lovelace !`. Quittez avec `:q`.

**Premier essai pas à pas ?** Suivez [docs/prise-en-main.md](docs/prise-en-main.md).

## 🧩 Installer le plugin dans votre Vim (sans Docker)

Avec vim-plug déjà installé, déclarez le dépôt entre `plug#begin()` et `plug#end()` :

```vim
Plug 'VOTRE_COMPTE/vim-hf-stt'
```

**`VOTRE_COMPTE` est un placeholder** : remplacez-le par le propriétaire du dépôt réellement accessible. Puis exécutez `:PlugInstall` et redémarrez Vim. Les dossiers `plugin/` et `autoload/` sont à la racine du dépôt.

### Commandes et fonctions du plugin

| Élément | Effet |
|---|---|
| `:VimHfSttHello` | Affiche `Bonjour !`. |
| `:VimHfSttHello Ada Lovelace` | Affiche `Bonjour, Ada Lovelace !` (espaces et accents acceptés). |
| `vim_hf_stt#hello(texte)` | Renvoie la même salutation. |
| `vim_hf_stt#version()` | Renvoie la version du plugin (`0.1.0`). |

La commande ne lance aucun shell et ne modifie pas le tampon. Aucun raccourci ni configuration personnelle n’est imposé.

## 🐳 L’environnement Docker en bref

L’image `vim-plug:vim-hf-stt` embarque Debian 12, Vim avec support Python3 (`vim-nox`), vim-plug et quelques plugins tiers, sous l’utilisateur non-root `appuser`. Elle sert à **développer et tester** le plugin sans toucher votre configuration.

| Besoin | Commande |
|---|---|
| Construire + vérifier + tester | `./build.sh` |
| Ouvrir Vim avec le plugin local | `./run.sh --local-plugin "$PWD"` |
| Ouvrir l’environnement seul | `./run.sh` |
| Retester sans rebuild | `./test.sh` |
| Diagnostiquer l’image | `./verify.sh` |
| Régressions du harnais | `bash tests/test-harness.sh` |
| Contrôler une version taguée | `./release.sh --check vX.Y.Z` |

Points clés :

- **Modifier le code du plugin** (`plugin/`, `autoload/`) : éditez sur l’hôte, **redémarrez Vim** — pas besoin de rebuild.
- **Modifier l’environnement** (`.vimrc`, `Dockerfile`) : **reconstruisez** avec `./build.sh`.
- Le dossier courant est monté **en écriture** dans le conteneur ; le plugin local est monté **en lecture seule** ; le reste du conteneur disparaît à sa fermeture.

## 📚 Documentation

| Document | Pour qui ? |
|---|---|
| [docs/prise-en-main.md](docs/prise-en-main.md) | Première session : prérequis, étapes guidées, dépannage. |
| [docs/reference.md](docs/reference.md) | Architecture, options des scripts, tests, CI et versions. |

## ⚖️ Limites connues

- Socle vérifié : **Vim sous Debian 12** uniquement (pas de garantie multi-OS ni Neovim).
- Le test d’installation utilise un clone Git `file://` local : il ne prouve pas l’accessibilité du futur dépôt distant.
- `build.sh` reconstruit sans cache, sans épingler toutes les versions tierces : deux builds ne sont pas garantis identiques.
- La CI (GitHub Actions) est configurée mais son exécution distante reste à confirmer après un push.

## Licence

Ce projet est open source, sous licence [MIT](LICENSE).
