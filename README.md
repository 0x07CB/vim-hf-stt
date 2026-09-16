# vim-hf-stt

Ce dépôt contient un **plugin Vim de démonstration**, installable depuis sa racine, et un **environnement Docker de développement et de validation**. La version du code est `0.1.0` ; **`v0.1.0` est prévue, pas publiée**.

Le plugin est écrit en Vimscript classique : aucune reconnaissance vocale, aucun modèle, appel réseau ou service externe. Son utilisation ne nécessite ni Docker ni Python ; ces outils appartiennent uniquement à l’environnement de développement.

## Installer et utiliser le plugin

Avec [vim-plug](https://github.com/junegunn/vim-plug) déjà installé, ajoutez cette déclaration entre vos appels existants à `plug#begin()` et `plug#end()` :

```vim
Plug 'VOTRE_COMPTE/vim-hf-stt'
```

**`VOTRE_COMPTE` est un placeholder à remplacer** par le propriétaire réel du dépôt accessible. Cette adresse n’annonce pas un dépôt public disponible. Exécutez `:PlugInstall`, puis redémarrez Vim. Les dossiers `plugin/` et `autoload/` sont directement à la racine du dépôt ; ne déclarez pas un sous-dossier.

- `:VimHfSttHello` affiche `Bonjour !`.
- `:VimHfSttHello Ada Lovelace` affiche `Bonjour, Ada Lovelace !` : le texte est facultatif, les espaces et accents sont acceptés.
- `vim_hf_stt#hello(texte)` renvoie la même salutation.
- `vim_hf_stt#version()` renvoie `0.1.0`.

La commande ne lance aucun shell et ne modifie pas le tampon. Aucun raccourci ni configuration personnelle n’est imposé ; les fonctions sont chargées à la demande par autoload.

Le socle actuellement pris en charge et testé est **Vim sous Debian 12** via l’image fournie. Il n’y a pas de validation multi-OS ou Neovim. Le test d’installation utilise un vrai clone Git `file://`, pas GitHub : il ne valide ni l’accessibilité du futur dépôt distant, ni son DNS ou ses permissions.

## Environnement Docker

L’image `vim-plug:vim-hf-stt` fournit un Vim prêt à l’emploi pour tester des configurations et des plugins sans modifier votre configuration personnelle. Le plugin de ce dépôt n’y est pas installé implicitement : utilisez le montage local décrit plus bas.

### Fonctionnalités

- Basé sur Debian 12.
- Installation de Vim avec support Python3 (`vim-nox`).
- Installation de Python3, pip et venv.
- Ajout de l'utilisateur `appuser` (UID 1000) pour éviter d'utiliser root.
- Installation automatique de [vim-plug](https://github.com/junegunn/vim-plug).
- Installation automatique et contrôlée des plugins définis dans `.vimrc` pendant le build.
- Lancement direct de Vim, sans installation ni réparation automatique au démarrage.
- Arrêt du build avec diagnostic si l’installation échoue ou si un plugin existant est incomplet ; aucun dossier existant n’est supprimé automatiquement.
- Lancement de Vim à l'ouverture du conteneur.

### Démarrage depuis la racine du dépôt

Docker doit être accessible à votre utilisateur ; le premier build nécessite le réseau. Pour construire l’image et exécuter les vérifications et tests :

```bash
./build.sh
```

Pour développer le plugin sans reconstruire l’image après chaque modification :

```bash
./run.sh --local-plugin "$PWD"
```

Vim utilise le `.vimrc` embarqué et charge le plugin local comme paquet natif. Le montage des sources est vivant et en lecture seule ; **redémarrez Vim pour recharger les modifications**, sans rebuild. Le dossier courant est aussi monté séparément comme dossier de travail inscriptible : le lanceur interactif n’offre pas le même isolement que `test.sh`.

Pour ouvrir seulement l’environnement embarqué, sans ce plugin, lancez `./run.sh`. Un simple `docker build -t vim-plug:vim-hf-stt .` construit aussi l’image, mais n’exécute pas les vérifications et tests ajoutés par `build.sh`.

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
- Disposer d’un environnement Vim prêt à l’emploi et isolé, sans promettre des versions tierces exactement reproductibles.
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
- Lance ensuite `verify.sh`, puis `test.sh --mode all` sur cette image ; toute erreur de construction, de vérification ou de test produit un code non nul.

Le Dockerfile utilise `DEBIAN_FRONTEND=noninteractive` pour APT. L’installateur de build `install-plugins.sh` télécharge vim-plug si son fichier est absent ou vide, puis installe les plugins manquants avec `PlugInstall --sync`. Il vérifie les dépôts Git et les scripts `.vim` non vides. Les échecs de téléchargement, les erreurs Vim et une sortie prématurée bloquent la suite.

La révision de vim-plug téléchargée peut être épinglée au build via l’argument `VIM_PLUG_REF` (branche, tag ou commit ; `master` par défaut) :

```bash
./build.sh --build-arg VIM_PLUG_REF=<commit>
```

Le téléchargement du gestionnaire utilise un fichier temporaire, un délai de connexion de 10 secondes, un délai de 60 secondes par tentative et deux nouvelles tentatives au maximum, avec une fenêtre de reprise de 120 secondes. L’étape Vim est limitée à 180 secondes, avec arrêt forcé après 5 secondes supplémentaires si nécessaire. Les confirmations Git au terminal sont désactivées.

> **Remarque** : Docker doit être installé et accessible à votre utilisateur. Le script ne lance pas `sudo`.

Debian, les paquets et les plugins tiers ne sont pas tous épinglés à des révisions exactes. Même avec `VIM_PLUG_REF`, deux builds ne sont pas garantis identiques.

## Tester le plugin sans rebuild

Depuis un checkout Git, avec une image locale déjà construite, `test.sh` accepte :

```text
./test.sh [--mode local|installed|all] [--image IMAGE] [--expected-version X.Y.Z] [--snapshot-ref COMMIT]
```

```bash
./test.sh --mode local
./test.sh --mode installed
./test.sh --mode all --image vim-plug:vim-hf-stt --expected-version 0.1.0
./test.sh --mode all --snapshot-ref HEAD
```

Le mode par défaut est `all`, l’image par défaut `vim-plug:vim-hf-stt`. Les chemins sont calculés depuis le script, indépendamment du dossier courant. Docker, Git, tar et realpath sont nécessaires sur l’hôte. Aucune reconstruction ni récupération d’image n’est effectuée.

### Snapshot et isolement

Sans `--snapshot-ref`, le script sélectionne avec `git ls-files --cached --others --exclude-standard --deduplicate` les fichiers suivis et les nouveaux fichiers non ignorés, uniquement sous `plugin/`, `autoload/`, `README.md`, `LICENSE` et `tests/run.vim`. Il archive leur contenu de travail actuel, y compris les modifications non commitées. Les liens symboliques sont refusés. **N’ajoutez pas de secrets dans ces chemins distribuables.**

Avec `--snapshot-ref COMMIT`, `git archive` exporte exclusivement les fichiers suivis de ce commit dans les mêmes chemins : aucune modification locale ni fichier ignoré non suivi n’est incorporé.

Seule l’archive tar temporaire est montée en lecture seule, jamais le `.git` hôte, les fichiers personnels, les identifiants ou le socket Docker. Chaque mode utilise un conteneur temporaire non-root, l’image résolue par identifiant, sans réseau, avec racine en lecture seule, capacités supprimées et `no-new-privileges`. L’archive est extraite dans `/tmp/source`, puis les sources sont rendues non inscriptibles par `chmod -R a-w`. Les écritures restent dans un `/tmp` en mémoire limité à 128 Mio.

### Deux parcours, les mêmes assertions

- **`local`** : charge le snapshot via `/tmp/native/pack/test/start/vim-hf-stt`, avec le mécanisme natif des paquets, le `.vimrc` embarqué et le véritable entrypoint. Contrairement à `run.sh`, ce n’est pas un montage vivant du dépôt entier.
- **`installed`** : copie uniquement les chemins distribuables dans un dépôt Git temporaire créé dans le conteneur. Un nouveau `HOME` contient vim-plug et un vimrc minimal déclarant une URI `file://`. L’installateur embarqué exécute un véritable clone Git via vim-plug, puis vérifie `.git`, l’origine, le commit et le contenu. Vim redémarre avec ce `HOME`, sans paquet natif du projet ni ajout des sources au `runtimepath`. Le commit de fixture affiché n’est pas le SHA d’une release ; avec une version attendue, un tag temporaire teste aussi la sélection par tag.

Les deux parcours exécutent `tests/run.vim` : commande chargée au démarrage, salutations avec texte spécial, fonctions et version, autoload différé, origine exacte des scripts, second sourçage inoffensif et absence de changements du tampon ou des options principales. `--expected-version` impose en plus l’égalité de la version. Une assertion, une exception, une erreur Vim, un dépassement du délai de 60 secondes ou une sortie avant la sentinelle font échouer le test avec diagnostic.

Le harnais vérifie aussi les échecs attendus sur des fixtures temporaires : plugin absent, assertion fausse, sortie prématurée, échec d’installation, options ou image invalides, tags absents ou incohérents, mauvaise version et checkout modifié, ainsi qu’une release valide. Il ne crée pas de tag dans le dépôt réel :

```bash
bash tests/test-harness.sh
```

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

`verify.sh` reste un diagnostic générique : il valide l’environnement et les scénarios de chargement testés, pas toutes les fonctionnalités interactives ni toutes les fonctions autoload des plugins. Pour le contrat fonctionnel de **vim-hf-stt**, utilisez `test.sh` ; pour un plugin externe tel qu’Ollama, un test de bout en bout distinct reste nécessaire.

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

Le plugin local utilise le chargement natif des paquets Vim, pas vim-plug : `:PlugInstall` ne le télécharge pas. Fournissez son véritable dossier source, contenant par exemple `plugin/*.vim` ou `autoload/*.vim`. Les modifications des sources sur l’hôte sont visibles dans le conteneur ; le montage du plugin est en lecture seule, mais le montage séparé du dossier de travail reste inscriptible. Redémarrez Vim pour recharger le code modifié.

```bash
./run.sh --local-plugin /chemin/vers/vim-ollama monfichier.py
```

Aucun stockage persistant de configuration ou de plugins n’est ajouté implicitement. Avec `--rm`, les changements internes au conteneur disparaissent à sa fermeture.

Pour un contrôle non interactif du lanceur :

```bash
./run.sh -N -n -es -u /home/appuser/.vimrc -i NONE -c 'qa!'
(set -e; for script in ./*.sh tests/*.sh; do bash -n "$script"; done)
shellcheck ./*.sh tests/*.sh
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

## Préparer une version manuellement

`release.sh` contrôle un **tag stable existant** au format `vX.Y.Z`, sans zéro initial. Exemple pour la version prévue, uniquement une fois son tag créé par le mainteneur :

```bash
./release.sh --check v0.1.0
./release.sh --check v0.1.0 --image vim-plug:vim-hf-stt
```

Le tag doit pointer exactement sur `HEAD` et le checkout doit être propre : aucune modification suivie ni fichier non suivi non ignoré. Les fichiers ignorés non suivis ne rendent pas le checkout sale et sont exclus de l’archive. Les fichiers requis, dont le plugin, les tests et `LICENSE`, doivent être suivis, réguliers et non vides.

Le contrôle lance `verify.sh`, puis les deux modes de `test.sh` avec `--expected-version X.Y.Z` et `--snapshot-ref` sur le commit validé. La version renvoyée par le plugin doit correspondre au tag sans `v`. Le résultat identifie le tag et le SHA validés, distincts du commit temporaire de fixture.

Procédure du mainteneur, à effectuer explicitement :

1. Mettre à jour la version du plugin et la documentation, puis lancer `./build.sh` et `bash tests/test-harness.sh`.
2. Relire et commiter les changements validés ; obtenir un checkout propre.
3. Créer manuellement le tag `vX.Y.Z` sur ce commit, puis lancer `./release.sh --check vX.Y.Z`.
4. Après succès, décider explicitement de pousser le commit et le tag vers le dépôt distant ; vérifier la CI de branche et de tag. Une éventuelle release GitHub reste une action manuelle séparée.
5. Vérifier alors l’installation depuis le vrai dépôt distant. Une déclaration vim-plug avec `{ 'tag': 'vX.Y.Z' }` n’est utilisable qu’après mise à disposition effective de ce tag.

**Le script ne crée aucun commit ni tag dans votre dépôt, ne pousse rien et ne publie rien** : ni release GitHub, ni image Docker, ni paquet. Aucun tag `v0.1.0` publié n’est présumé par ces exemples.

## Intégration continue

`.github/workflows/ci.yml` s’exécute sur les pull requests, les pushes de branches et de tags `v*`, ainsi que manuellement. Sur `ubuntu-24.04`, il contrôle la syntaxe Bash et ShellCheck, lance `build.sh` puis les régressions du harnais ; un tag déclenche aussi `release.sh --check`.

La CI utilise l’action officielle `actions/checkout` v4.2.2 épinglée au SHA `11bd71901bbe5b1630ceea73d27597364c9af683`, avec historique complet, tags et sans persistance des identifiants. Les permissions sont limitées à `contents: read` et le job à 45 minutes. Aucun secret de publication, droit d’écriture ou téléversement de release n’est prévu. La présence du workflow ne prouve pas une exécution distante réussie : celle-ci reste à confirmer après un push autorisé sur GitHub.

## Licence

Ce projet est open source, sous licence MIT.
