# Freetify Musique

*Dev by AbdouTP*

Application musicale iOS native (SwiftUI + AVFoundation), **lecture 100 % hors connexion** : tu importes ou télécharges tes musiques, elles sont copiées dans l'app, et tout fonctionne en mode avion. Seul l'onglet Découvrir se connecte à Internet, uniquement pour chercher et télécharger.

- Bundle ID : `com.abdoutp.freetifymusique` — version `1.0.0` (build `1`) — iOS 17+, iPhone, portrait
- Couleurs : violet `#8B35F5`, violet foncé `#171324`, vert `#A7F36B`, fond `#100D18`

> ⚠️ Ce code a été écrit sans Mac ni Xcode : il a été vérifié syntaxiquement mais **pas compilé**. La première compilation sur Codemagic est le vrai test. Si elle échoue, copie-moi les lignes `error:` du log et je corrige.

---

## Structure

```
project.yml                 XcodeGen (génère FreetifyMusique.xcodeproj)
codemagic.yaml              2 workflows : sans signature / signé
scripts/pick_simulator.py   choisit un simulateur pour les tests (Codemagic)
Config/                     Info.plist généré par XcodeGen (ne pas éditer)
Resources/Assets.xcassets   icône, logo, couleurs
Sources/
  App/        FreetifyApp, RootView (onglets, import, alertes)
  Theme/      couleurs et styles
  Models/     Track, Playlist, Album/Artist dérivés
  Services/   LibraryStore (JSON), ImportService, MetadataReader, PlayQueue,
              PlayerService (AVPlayer + écran verrouillé), Recommender, SearchService
  Views/      Home, Library, Detail, Player, Search, Settings, Components
Tests/        tests unitaires (file d'attente, recherche, bibliothèque, import…)
```

## Fonctionnalités

- **Accueil** : écoutés récemment, playlists favorites, albums, « Pour vous » (calculé uniquement depuis ta bibliothèque et ton historique), accès rapides.
- **Bibliothèque** : musiques (tri), albums, artistes, playlists, favoris, historique.
- **Import** : sélecteur de fichiers iOS (multi-sélection), MP3 / M4A / AAC / WAV / AIFF / FLAC. Copie dans `Application Support/Freetify/Music`, métadonnées (titre, artiste, album, pochette) lues par AVFoundation, repli sur le nom de fichier (« Artiste - Titre »). Doublons détectés par empreinte SHA-256. Le fichier d'origine n'est plus jamais utilisé.
- **Lecteur** : lecture/pause, suivant/précédent, barre de progression, ±15 s, aléatoire, répétition (off / tout / une), file d'attente (lire ensuite, ajouter, réordonner, retirer, vider), pochette, mini-lecteur, lecture en arrière-plan, écran verrouillé et Centre de contrôle, interruptions (appels…) et débranchement des écouteurs.
- **Playlists** : créer, renommer, supprimer, ajouter/retirer/réordonner, pochette choisie dans tes photos (sans permission) ou mosaïque automatique, favoris.
- **Recherche** instantanée (titres, artistes, albums, playlists), insensible à la casse et aux accents.
- **Réglages** : stockage utilisé, compteurs, gestion/suppression (sélection multiple, tout supprimer, réinitialiser), effacer l'historique, thème sombre (toujours actif).

- **Découvrir** : recherche et téléchargement de musique **libre et légale** (Jamendo, licences Creative Commons) avec ajout automatique à la bibliothèque. C'est la seule page qui utilise Internet ; une fois téléchargés, les titres se lisent hors connexion et s'ajoutent aux playlists comme les autres.
- **Catalogue Apple Music (MusicKit)** : dans Découvrir → « Apple Music » : classements réels, recherche de titres / artistes / albums avec suggestions et pochettes, pages album et artiste, lecture par `ApplicationMusicPlayer` (pause, suivant/précédent, aléatoire, répétition, progression, durée). **Un abonnement Apple Music est obligatoire pour écouter** : sans lui, l'app l'affiche et ne lit rien. Un seul lecteur joue à la fois (Apple Music ou bibliothèque locale) ; la bibliothèque locale n'est jamais modifiée.
- **Import de playlists Apple Music** (Réglages ou Bibliothèque → Playlists) : lit tes playlists de l'app Musique et les recrée dans Freetify.

Permissions demandées : **accès à Apple Music / médiathèque**, uniquement quand tu ouvres l'import de playlists ou le catalogue Apple Music. Le mode d'arrière-plan « Audio » est aussi déclaré.

## Découvrir : clé Jamendo (gratuite)

1. Crée un compte sur <https://developer.jamendo.com>, puis une application pour obtenir un **Client ID**.
2. Dans l'app, onglet **Découvrir**, colle le Client ID. Il reste uniquement sur ton iPhone (pas dans le dépôt).

Pourquoi pas YouTube ? Télécharger des vidéos ou de l'audio YouTube est interdit par ses conditions d'utilisation et par le droit d'auteur ; l'API officielle ne fournit d'ailleurs que de la recherche et des métadonnées, pas les fichiers. Jamendo propose à la place des centaines de milliers de titres téléchargeables légalement. Chaque titre garde sa licence (affichée dans la liste) : beaucoup sont « NC » (usage non commercial), donc pour un usage personnel uniquement.

## Import de playlists Apple Music : ce qui est possible

Apple protège (DRM) les morceaux d'un abonnement Apple Music : leur fichier audio n'est pas accessible aux apps, et il n'existe aucun moyen légitime de les copier. Freetify fait donc ceci :

1. Morceau déjà présent dans Freetify (même titre, même artiste, durée proche) : repris dans la playlist.
2. Morceau présent sur l'iPhone **sans protection** (acheté sur iTunes, ou ajouté depuis un ordinateur) : copié dans Freetify (converti en M4A), puis ajouté à la playlist.
3. Morceau en streaming ou protégé : **non importable** ; il est listé dans le rapport de fin d'import, sans être copié.

Astuce : importe d'abord tes fichiers audio dans Freetify, puis lance l'import des playlists : les titres correspondants seront retrouvés automatiquement.
Pour que tes playlists apparaissent, « Synchroniser la bibliothèque » doit être activé dans Réglages → Musique.

## Apple Music (MusicKit) : prérequis importants

MusicKit génère automatiquement son jeton développeur, **mais seulement si le service « MusicKit » est activé sur l'App ID** `com.abdoutp.freetifymusique` (developer.apple.com → Certificates, Identifiers & Profiles → Identifiers → App Services → MusicKit) et si l'app est signée avec cet identifiant. Cela demande un **compte Apple Developer payant**. Avec un compte gratuit + Sideloadly/AltStore (identifiant modifié, service non activé), la recherche et la lecture du catalogue échouent : l'app l'indique clairement, et tout le reste (bibliothèque, import, Musique libre) fonctionne. Source : [Apple, génération automatique du jeton](https://developer.apple.com/documentation/musickit/using-automatic-token-generation-for-apple-music-api).

## Limites connues

- Les albums sont regroupés par *titre d'album + artiste* ; les compilations dont l'artiste varie par piste sont éclatées. Sans album, les titres sont regroupés par artiste (« Album inconnu »).
- Pas de numéro de piste : l'ordre dans un album suit l'ordre d'import.
- FLAC : lu si iOS décode le fichier ; les tags FLAC ne sont pas toujours lus (repli sur le nom de fichier). Un fichier illisible est refusé à l'import avec un message.
- Si tu réinstalles l'app (et non « rafraîchir »), le conteneur est effacé : il faut réimporter. C'est une règle d'iOS.
- Le thème clair n'existe pas (thème sombre uniquement).

## Logo

Le logo est la note de musique violette néon fournie par AbdouTP. Pour le changer :

- Icône de l'app : remplace `Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` (PNG 1024×1024, **sans transparence**).
- Logo dans l'app et écran de lancement : remplace `Resources/Assets.xcassets/Logo.imageset/logo.png` (PNG transparent, ~512 px).

---

## 1. Mettre le projet dans ton dépôt (depuis Windows)

1. Décompresse le ZIP dans ton dossier local du dépôt `freetifymusique`.
2. Dans un terminal : `git add .` puis `git commit -m "Freetify Musique"` puis `git push`.

## 2. Compiler sur Codemagic

1. Va sur <https://codemagic.io>, connecte-toi avec GitHub, **Add application** → choisis `AbdouTP/freetifymusique`.
2. Type de projet : choisis la configuration **codemagic.yaml** (pas le « Workflow Editor »).
3. Lance un build : **Start new build** → branche `main` → workflow **« 1 - Compilation sans signature (IPA pour AltStore) »**.
4. Attends la fin (~10 min). En cas d'échec, le log affiche un bloc `ERREURS DE COMPILATION` avec les lignes `error:`.
5. Dans **Artifacts**, télécharge `FreetifyMusique-unsigned.ipa`.

Les tests unitaires tournent dans ce workflow mais **ne bloquent pas** l'IPA ; regarde l'étape « Tests unitaires » pour voir leur résultat.

### Workflow 2 : compilation signée

Il produit un IPA déjà signé, mais il demande un certificat de développement `.p12` et un profil `.mobileprovision` qui incluent ton iPhone. **Avec un compte Apple gratuit tu ne peux pas obtenir ces fichiers depuis Windows** : utilise donc le workflow 1 + AltStore/Sideloadly. Si un jour tu as un compte payant, crée un groupe de variables `signing` dans Codemagic avec `CM_CERTIFICATE` (base64 du .p12), `CM_CERTIFICATE_PASSWORD` et `CM_PROVISIONING_PROFILE` (base64 du profil). Base64 sous Windows (PowerShell) :

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\chemin\fichier.p12"))
```

Rien de secret n'est dans le dépôt (`.gitignore` bloque `.p12`, `.mobileprovision`, etc.).

## 3. Installer l'IPA sur ton iPhone 13 Pro avec un compte Apple gratuit

Un compte gratuit ne permet pas la distribution App Store ni TestFlight. La méthode compatible est le *sideloading* : l'outil signe l'IPA **avec ton propre compte** et l'installe.

Limites d'un compte gratuit (à vérifier sur la doc de l'outil, elles évoluent) :
- l'app **expire au bout de 7 jours** : il faut la « rafraîchir » (AltStore le fait automatiquement quand ton PC est allumé, sur le même Wi-Fi) ;
- 3 apps actives maximum avec AltStore, et un nombre limité d'identifiants d'app par semaine ;
- AltStore/Sideloadly modifient légèrement l'identifiant de l'app (suffixe) : c'est normal.

### Option A : Sideloadly (la plus simple sous Windows)

1. Installe **iTunes** et **iCloud** depuis le site d'Apple (pas la version Microsoft Store), puis Sideloadly depuis <https://sideloadly.io>.
2. Branche l'iPhone en USB, appuie sur « Faire confiance ».
3. Glisse `FreetifyMusique-unsigned.ipa` dans Sideloadly, saisis ton Apple ID, clique **Start**.
4. Sur l'iPhone : **Réglages → Général → VPN et gestion de l'appareil** → fais confiance à ton profil développeur.
5. Active le **Mode développeur** si iOS le demande : **Réglages → Confidentialité et sécurité → Mode développeur** (redémarrage requis).

### Option B : AltStore

1. Installe iTunes et iCloud (versions du site d'Apple) puis **AltServer pour Windows** (<https://altstore.io>).
2. Branche l'iPhone, icône AltServer (barre des tâches) → **Install AltStore** → ton iPhone.
3. Mode développeur + confiance dans le profil (comme ci-dessus).
4. Envoie l'IPA sur l'iPhone (AirDrop impossible depuis Windows : mets-le dans iCloud Drive ou envoie-le par un moyen de ton choix), ouvre-le avec AltStore → **My Apps → +** → sélectionne l'IPA.

Je n'ai pas pu vérifier ici la compatibilité de ces outils avec iOS 26 ; regarde les notes de version sur leurs sites avant d'installer.

### Utiliser l'app

1. Ouvre Freetify Musique → **Importer des musiques** → choisis tes fichiers (Fichiers, iCloud Drive, etc.).
2. Une fois importés, tu peux activer le mode avion : tout fonctionne.
