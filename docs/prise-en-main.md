# Prise en main

Ce guide vous fait réussir votre **première session** : construire l’environnement, ouvrir Vim, exécuter la commande de démonstration et repartir proprement.

> **À savoir avant de commencer** — malgré son nom, ce projet ne fait pas encore de reconnaissance vocale. Il contient un **plugin de démonstration** (`:VimHfSttHello`) et un **environnement Docker** pour le développer et le tester.

## Sommaire

- [Comprendre les pièces](#comprendre-les-pièces)
- [1. Prérequis](#1-prérequis)
- [2. Vérifier votre poste](#2-vérifier-votre-poste)
- [3. Construire l’environnement](#3-construire-lenvironnement)
- [4. Ouvrir Vim avec le plugin](#4-ouvrir-vim-avec-le-plugin)
- [5. Essayer la commande](#5-essayer-la-commande)
- [6. Quitter Vim](#6-quitter-vim)
- [7. Modifier le plugin et réessayer](#7-modifier-le-plugin-et-réessayer)
- [8. (Facultatif) Relancer les tests sans rebuild](#8-facultatif-relancer-les-tests-sans-rebuild)
- [9. (Facultatif) Installer le plugin hors Docker](#9-facultatif-installer-le-plugin-hors-docker)
- [Dépannage](#dépannage)

## Comprendre les pièces

| Élément | Rôle | Analogie |
|---|---|---|
| **Dépôt** | Le dossier du projet sur votre machine. | Vos sources. |
| **Image Docker** | Un environnement Vim figé, construit par `./build.sh`. | Une machine virtuelle minimale. |
| **Conteneur** | Une exécution temporaire de cette image, lancée par `./run.sh`. | La machine allumée, puis éteinte. |
| **Plugin** | Les fichiers `plugin/` et `autoload/` à la racine du dépôt. | La fonctionnalité distribuée. |

Le plugin fonctionne **sans Docker** dans n’importe quel Vim avec vim-plug ; Docker n’est ici qu’un banc d’essai reproductible.

## 1. Prérequis

Ce parcours a été vérifié sous **Linux** (Bash). Il vous faut :

- un **checkout Git** de ce projet ;
- **Docker** accessible à votre utilisateur (sans `sudo`, groupe `docker`) ;
- **Git**, `tar`, `realpath` (GNU coreutils) ;
- le **réseau** pour le premier build (paquets Debian, vim-plug, plugins) ;
- éventuellement **ShellCheck**, seulement pour l’analyse statique des scripts.

## 2. Vérifier votre poste

Depuis un terminal, à la **racine du dépôt** :

```bash
pwd                  # vous êtes dans le dossier du projet
command -v docker    # chemin de Docker
command -v git       # chemin de Git
docker info >/dev/null && echo "Docker accessible"
```

Si `docker info` échoue, réglez d’abord l’accès Docker pour votre utilisateur — aucune commande du projet ne lance `sudo`.

## 3. Construire l’environnement

```bash
./build.sh
```

Le script enchaîne trois étapes :

1. **Construction** complète de l’image (sans cache) — le premier build télécharge les paquets, c’est normal si c’est long.
2. **Vérification** de l’image (`verify.sh`) : configuration, vim-plug et plugins embarqués.
3. **Tests du plugin** (`test.sh`) : chargement local puis installation réelle par vim-plug.

Succès attendu en fin de sortie :

```text
SUCCÈS : tests fonctionnels local terminés.
SUCCÈS : tests fonctionnels installed terminés.
```

## 4. Ouvrir Vim avec le plugin

Toujours à la racine du dépôt :

```bash
./run.sh --local-plugin "$PWD"
```

`$PWD` désigne le dossier courant : le plugin est monté **en lecture seule** comme paquet natif Vim, et le dossier courant est aussi monté **en écriture** comme dossier de travail.

> `./run.sh` seul ouvre l’environnement **sans** ce plugin — utile pour tester un autre plugin ou une configuration.

## 5. Essayer la commande

Vim démarre en mode normal. Tapez `:` (la ligne de commande apparaît en bas), puis :

```vim
:VimHfSttHello
```

Résultat attendu :

```text
Bonjour !
```

Puis avec un texte libre (espaces et accents acceptés) :

```vim
:VimHfSttHello Ada Lovelace
```

```text
Bonjour, Ada Lovelace !
```

La commande ne lance aucun shell et ne modifie pas le tampon.

## 6. Quitter Vim

| Geste | Action |
|---|---|
| `Échap` | Revenir au mode normal. |
| `:q` puis `Entrée` | Quitter (refusé s’il reste des modifications non enregistrées). |
| `:q!` puis `Entrée` | Quitter **en abandonnant** les modifications non enregistrées. |

## 7. Modifier le plugin et réessayer

1. Éditez `plugin/vim_hf_stt.vim` ou `autoload/vim_hf_stt.vim` **sur votre machine** (pas dans le conteneur).
2. Relancez `./run.sh --local-plugin "$PWD"` — le montage reflète vos fichiers ; **redémarrer Vim suffit**, sans rebuild.
3. Un rebuild avec `./build.sh` n’est requis que si vous touchez à l’environnement (`.vimrc`, `Dockerfile`, scripts).

Ce qui persiste à la fermeture du conteneur :

| Élément | Persiste ? |
|---|---|
| Fichiers du dossier courant (monté en écriture) | ✅ Oui, sur l’hôte. |
| Sources du plugin (montées en lecture seule) | ✅ Oui — modifiées uniquement depuis l’hôte. |
| Modifications internes du conteneur (`~/.vim`, plugins installés à la main) | ❌ Non — le conteneur est jeté (`--rm`). |

> **Astuce** : pour travailler dans un autre dossier, conservez le chemin du projet — par exemple `PROJET=$PWD` à la racine, puis après `cd /autre/projet`, lancez `"$PROJET/run.sh" --local-plugin "$PROJET"`.

## 8. (Facultatif) Relancer les tests sans rebuild

```bash
./test.sh
```

Deux parcours sont exécutés sur un snapshot de vos sources : chargement **local** (paquet natif) puis **installed** (vrai clone Git + `PlugInstall` dans un Vim isolé). Voir [reference.md](reference.md#tests-fonctionnels) pour les options.

## 9. (Facultatif) Installer le plugin hors Docker

Dans votre propre Vim, avec vim-plug :

```vim
Plug 'VOTRE_COMPTE/vim-hf-stt'
```

**`VOTRE_COMPTE` est un placeholder** à remplacer par le propriétaire réel du dépôt publié — aucune adresse publique n’est garantie par cette documentation. Puis `:PlugInstall`, redémarrez Vim, testez `:VimHfSttHello`.

## Dépannage

| Symptôme | Cause probable | Action |
|---|---|---|
| `ERREUR : Docker est introuvable.` | Docker absent ou pas dans le `PATH`. | Installez Docker et reconnectez-vous. |
| `docker info` échoue / permission refusée | Utilisateur hors du groupe `docker`. | Ajoutez votre utilisateur au groupe, reconnectez-vous. |
| `image locale ... introuvable` | L’image n’a jamais été construite. | Lancez `./build.sh`. |
| `Not an editor command: VimHfSttHello` | Plugin non monté. | Relancez avec `./run.sh --local-plugin "$PWD"`. |
| `dossier du plugin absent ...` | `--local-plugin` pointe ailleurs que la racine. | Vérifiez le chemin (il doit contenir `plugin/` et `autoload/`). |
| `chemins des montages ... ne doivent pas contenir de virgule` | Chemin avec `,`. | Renommez ou déplacez le dossier. |
| Le `.vimrc` embarqué diffère du fichier de référence | `.vimrc` modifié sans rebuild. | Lancez `./build.sh`, ou `--vimrc` de `verify.sh` pour comparer une autre référence. |
| Impossible d’écrire dans les sources du plugin | Montage en lecture seule — normal. | Éditez les fichiers **sur l’hôte**. |
| Permission refusée dans le dossier de travail | Fichiers appartenant à un autre UID (le conteneur écrit en `appuser`, UID 1000). | Vérifiez les permissions du dossier hôte. |
| `test.sh --snapshot-ref HEAD` échoue | Fichiers récents non encore commités. | Le snapshot `HEAD` ne contient que les fichiers commités ; testez sans `--snapshot-ref`. |
| Vim ne répond plus dans un terminal exotique | Le lanceur détecte le TTY automatiquement. | Préférez un terminal standard ; pour du non interactif, voyez `run.sh --help`. |

---

Retour au [README](../README.md) · Détails techniques : [reference.md](reference.md)
