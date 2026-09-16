# vim-plug:vim-hf-stt

Ce projet Docker installe une image Debian 12 minimale avec Vim (version avec support Python3) et Python3 via apt, puis teste si le plugin Vim fonctionne correctement.

## Objectif

L'objectif de ce projet est de fournir un environnement Vim prêt à l'emploi, incluant la gestion des plugins via [vim-plug](https://github.com/junegunn/vim-plug), dans un conteneur Docker. Cela permet de tester rapidement des configurations Vim ou des plugins, sans impacter votre système principal.

## Fonctionnalités

- Basé sur Debian 12.
- Installation de Vim avec support Python3 (`vim-nox`).
- Installation de Python3, pip et venv.
- Ajout de l'utilisateur `appuser` (UID 1000) pour éviter d'utiliser root.
- Installation automatique de [vim-plug](https://github.com/junegunn/vim-plug).
- Installation automatique et contrôlée des plugins définis dans `.vimrc` pendant le build.
- Lancement direct de Vim, sans installation ni réparation automatique au démarrage.
- Arrêt du build avec diagnostic si l’installation échoue ou si un plugin existant est incomplet ; aucun dossier existant n’est supprimé automatiquement.
- Lancement de Vim à l'ouverture du conteneur.

## Utilisation

1. **Construire l'image Docker** :
   ```bash
   docker build -t vim-plug:vim-hf-stt .
   ```

2. **Lancer le conteneur** :
   ```bash
   docker run -it --rm vim-plug:vim-hf-stt
   ```

Vim se lance automatiquement avec la configuration et les plugins définis dans `.vimrc`.

## Personnalisation

- Modifiez le fichier `.vimrc` du dépôt pour ajouter ou retirer des plugins, puis lancez `./build.sh` avant de relancer Vim. La reconstruction est systématiquement complète (`--no-cache`), donc chaque build repart de zéro.
- Vous pouvez ajouter d'autres dépendances ou outils dans le `Dockerfile` si nécessaire.
- Le `.vimrc` du dépôt est la source de référence, copiée dans `/home/appuser/.vimrc` au build. Le lanceur ne monte ni votre configuration Vim personnelle ni un dossier `~/.vim` persistant.
- Les modifications faites avec `:edit $MYVIMRC`, `:PlugInstall` ou `:PlugUpdate` dans le conteneur sont temporaires et disparaissent à sa fermeture. Pour les conserver, reportez les changements souhaités dans le dépôt et reconstruisez l’image. Les fichiers du dossier de travail monté restent, eux, persistants.
- vim-plug gère les plugins sans changer automatiquement l’interface. Les améliorations Python s’appliquent aux tampons Python ; aucun menu QuickUI personnalisé n’est défini par défaut.

## Configuration Vim fournie

Le fichier `.vimrc` inclus dans ce projet propose une configuration par défaut à la fois moderne et pratique :

- **Syntax highlighting** et numérotation des lignes activées.
- Indentation intelligente avec espaces (2 espaces par tabulation).
- Recherche améliorée (incrémentale, insensible à la casse, surlignage des résultats).
- Complétion de la ligne de commande améliorée.
- Prise en charge du presse-papiers système (`set clipboard=unnamedplus`).
- Support de la souris dans tous les modes.
- Désactivation des alertes sonores.
- Raccourci `<leader>ev` pour éditer rapidement la configuration Vim.
- Rechargement automatique du `.vimrc` après modification.
- Thème de couleurs sombre (`evening` par défaut, possibilité d’en ajouter d’autres).
- Plugins installés automatiquement via [vim-plug](https://github.com/junegunn/vim-plug) :
  - `junegunn/vim-plug` (gestionnaire de plugins)
  - `wellle/visual-split.vim` (gestion visuelle des splits)
  - `skywind3000/vim-quickui` (UI rapide)
  - `vim-scripts/indentpython.vim` et `hdima/python-syntax` (améliorations pour Python)

Vous pouvez bien sûr adapter ce fichier `.vimrc` selon vos besoins.

## Pourquoi utiliser ce projet ?

- Tester rapidement des plugins Vim dans un environnement isolé.
- Disposer d’un Vim prêt à l’emploi, reproductible et portable.
- Éviter de polluer votre machine principale avec des essais de configuration.

## Script de construction automatisée

Pour simplifier la construction de l’image Docker, un script `build.sh` est fourni à la racine du projet. Ce script exécute la commande de build avec les bons paramètres :

```bash
./build.sh
```

Ce script :
- Construit l’image Docker en utilisant le dossier du script comme contexte, quel que soit le dossier courant du terminal.
- Reconstruit toujours sans cache (`--no-cache` est appliqué en permanence) et accepte des options supplémentaires transmises à `docker build`, par exemple `./build.sh --build-arg VIM_PLUG_REF=<commit>`.
- Attribue le tag `vim-plug:vim-hf-stt` à l’image générée.
- Lance ensuite `verify.sh` et renvoie un code non nul si la construction ou les contrôles échouent.

Le Dockerfile utilise `DEBIAN_FRONTEND=noninteractive` pour APT. L’installateur de build `install-plugins.sh` télécharge vim-plug si son fichier est absent ou vide, puis installe les plugins manquants avec `PlugInstall --sync`. Il vérifie les dépôts Git et les scripts `.vim` non vides. Les échecs de téléchargement, les erreurs Vim et une sortie prématurée bloquent la suite.

La révision de vim-plug téléchargée peut être épinglée au build via l’argument `VIM_PLUG_REF` (branche, tag ou commit ; `master` par défaut) :

```bash
./build.sh --build-arg VIM_PLUG_REF=<commit>
```

Le téléchargement du gestionnaire utilise un fichier temporaire, un délai de connexion de 10 secondes, un délai de 60 secondes par tentative et deux nouvelles tentatives au maximum, avec une fenêtre de reprise de 120 secondes. L’étape Vim est limitée à 180 secondes, avec arrêt forcé après 5 secondes supplémentaires si nécessaire. Les confirmations Git au terminal sont désactivées.

> **Remarque** : Docker doit être installé et accessible à votre utilisateur. Le script ne lance pas `sudo`.

Vous pouvez ensuite lancer le conteneur comme indiqué dans la section **Utilisation**.

## Vérifier une image déjà construite

Le script indépendant `verify.sh` teste l’image existante, sans rebuild, installation ni accès réseau :

```bash
./verify.sh
./verify.sh --image vim-plug:vim-hf-stt
```

Les contrôles portent d’abord sur les fichiers :

- Le `.vimrc` et `autoload/plug.vim` embarqués doivent exister, être lisibles et non vides.
- Chaque dossier de plugin déclaré doit exister et contenir des scripts `.vim` lisibles et non vides.
- Les fichiers effectivement sourcés par Vim sont également contrôlés.
- Le chargement du `.vimrc`, du gestionnaire et des plugins actuels est testé, avec un essai de coloration et d’indentation Python.

Le rapport affiche l’identifiant de l’image, les chemins et les empreintes SHA256 des vimrc de référence et embarqué, ainsi que `$MYVIMRC` observé dans Vim. La référence est par défaut le `.vimrc` voisin de `verify.sh`, quel que soit le dossier courant. Une différence fait échouer la vérification et invite à reconstruire l’image.

Pour comparer avec une autre référence :

```bash
./verify.sh --vimrc /chemin/vers/config.vim
```

Cette option compare le contenu sans charger ni monter le fichier de référence dans le conteneur. Le test passe par l’entrypoint réel, sans `-u`, et vérifie que Vim choisit automatiquement `/home/appuser/.vimrc`. Les révisions des plugins ne sont pas comparées.

« Non vide » signifie une taille supérieure à zéro octet, pas un contenu nécessairement correct. Les erreurs que Vim signale pendant les scénarios exécutés font échouer le contrôle, mais les fonctions et scripts non exécutés ne sont pas validés. Le gestionnaire vim-plug est chargé depuis `~/.vim/autoload/plug.vim` ; sa copie dans `~/.vim/plugged/vim-plug` peut donc ne charger aucun script.

Pour inclure le plugin local utilisé par `run.sh` :

```bash
./verify.sh --local-plugin "$HOME/.config/vim-with-vimplug/plugins/vim-ollama"
```

Le dossier doit exister, être lisible et non vide, et contenir des scripts `.vim` lisibles et non vides. Il est monté en lecture seule sous le nom de son dossier dans `pack/test/start/`. Si aucun script local n’est sourcé dans le scénario, le rapport avertit que seule la présence de contenu a été contrôlée ; ce n’est pas un échec si les fichiers sont présents et non vides. Un dossier vide ou un script vide provoque un échec. Aucun appel à Ollama n’est effectué.

Le conteneur de diagnostic est temporaire, sans réseau, avec un système de fichiers en lecture seule et un `/tmp` en mémoire pour les diagnostics. La commande Vim est limitée à 60 secondes. Le code de sortie est `0` si tous les contrôles passent et non nul sinon ; les journaux Vim sont affichés en cas d’échec.

Cette vérification valide l’installation et les scénarios de chargement testés, pas toutes les fonctionnalités interactives ni toutes les fonctions autoload des plugins. Elle ne remplace pas un test de bout en bout d’Ollama.

Pour vérifier le script lui-même :

```bash
bash -n verify.sh
shellcheck verify.sh
```

## Script de lancement automatisé

Pour faciliter le lancement du conteneur Docker avec la bonne configuration utilisateur et le montage de plugins externes, un script `run.sh` est fourni à la racine du projet.

Ce script :
- Lance le conteneur Docker avec l’image `vim-plug:vim-hf-stt`.
- Monte automatiquement le dossier courant du terminal dans le conteneur, ce qui permet d’éditer et de sauvegarder directement les fichiers de ce dossier sur votre machine hôte.
- Ne monte aucun plugin local par défaut. L’option `--local-plugin DOSSIER`, placée avant les arguments Vim, monte explicitement les sources d’un plugin en lecture seule dans `/home/appuser/.vim/pack/test/start/<nom-du-dossier>`.
- Ne crée, ne supprime et ne remplit aucun dossier de plugin. Si le dossier demandé est absent, totalement vide, illisible ou impossible à parcourir, le lancement échoue. Un dossier non vide ne garantit pas un plugin fonctionnel : utilisez aussi `verify.sh --local-plugin DOSSIER`.
- Affiche son aide avec `--help`. Utilisez `--` pour terminer les options du lanceur, notamment `./run.sh -- --help` pour obtenir l’aide de Vim.
- Utilise uniquement l’image déjà construite, sans téléchargement automatique d’image, et échoue clairement si elle est absente ou inaccessible.
- Vérifie les chemins des montages et refuse les virgules, incompatibles avec cette syntaxe de montage.
- Alloue un terminal uniquement si l’entrée et la sortie sont des terminaux ; permet aussi les commandes Vim non interactives.
- Exécute Vim sous l’utilisateur non-root `appuser` pour plus de sécurité.
- Utilise le réseau hôte pour faciliter certains usages avancés.

L’entrypoint exécute directement Vim avec vos arguments, sans installateur ni contrôle préalable des plugins. L’installation se fait au build ; lancez `./verify.sh` pour diagnostiquer une image existante. Les arguments Vim tels que `-u NONE` ou `-u /chemin/config` sont transmis sans imposer le `.vimrc` embarqué.

Le plugin local utilise le chargement natif des paquets Vim, pas vim-plug : `:PlugInstall` ne le télécharge pas. Fournissez son véritable dossier source, contenant par exemple `plugin/*.vim` ou `autoload/*.vim`. Les modifications des sources sur l’hôte sont visibles dans le conteneur, mais le montage en lecture seule empêche le conteneur de les modifier.

```bash
./run.sh --local-plugin /chemin/vers/vim-ollama monfichier.py
```

Aucun stockage persistant de configuration ou de plugins n’est ajouté implicitement. Avec `--rm`, les changements internes au conteneur disparaissent à sa fermeture.

Pour un contrôle non interactif du lanceur :

```bash
./run.sh -N -n -es -u /home/appuser/.vimrc -i NONE -c 'qa!'
bash -n build.sh run.sh install-plugins.sh entrypoint.sh verify.sh
shellcheck build.sh run.sh install-plugins.sh entrypoint.sh verify.sh
```

Exemple d’utilisation :
```bash
cd /chemin/vers/mon/projet
./run.sh
```

Vous pouvez également passer des arguments supplémentaires à Vim via ce script, par exemple :
```bash
./run.sh monfichier.py
```

> **Remarque** : Le script suppose que votre utilisateur a accès à Docker sans `sudo` (faites partie du groupe `docker`).

## Licence

Ce projet est open source, sous licence MIT.
