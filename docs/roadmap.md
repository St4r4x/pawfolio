# Pawfolio — Roadmap produit

Backlog de fonctionnalités, organisé par phase, issu des retours utilisateur sur la
v2 du design (Task 11 de `docs/superpowers/plans/2026-08-18-pawfolio-visual-design-v2.md`)
et de suggestions complémentaires. Chaque item indique l'effort estimé et les
dépendances techniques réelles (packages, API externes, migrations DB).

Légende effort : 🟢 petit (UI seule, pas de nouvelle dépendance) · 🟡 moyen (nouveau
champ/écran, pas de service externe) · 🔴 gros (nouveau package + service externe
et/ou migration DB).

---

## Phase 1 — Auth & onboarding (retours directs)

### 1.1 Écran de connexion — mise en page 🟢
Les champs Email/Mot de passe s'étirent actuellement bord à bord de l'écran. Les
regrouper dans une carte centrée (largeur max ~400px, padding, léger arrondi/ombre)
pour que l'écran respire moins vide — cohérent avec la carte des animaux déjà
introduite sur Home. Aucune nouvelle dépendance : un `Card`/`ConstrainedBox` autour
du formulaire existant.

### 1.2 Slogan / tagline 🟢
Une phrase sous le wordmark "Pawfolio", ex. *"Le carnet de santé de vos
compagnons"* ou *"Toute la santé de votre animal, au même endroit."* — à valider,
mais l'emplacement (sous le paw + wordmark, avant les champs) est déjà tout tracé
par la mise en page actuelle.

### 1.3 Mot de passe oublié 🟡
Supabase Auth expose déjà `resetPasswordForEmail` — pas de nouveau service. Un lien
sous le bouton "Se connecter" ouvre un petit écran (email seul) qui déclenche
l'envoi du mail de réinitialisation, avec le même style de validation inline que le
reste du formulaire.

### 1.4 Onboarding : inscription + premier animal 🟡
L'écran d'inscription actuel s'arrête à email/mot de passe — trop vide, et l'usager
atterrit ensuite sur un Home vide qu'il doit encore comprendre. Fusionner en un
petit flow à 2 étapes après la création du compte : *(1)* informations utilisateur
optionnelles (prénom — nouveau champ, pas encore dans le schéma `auth.users`
metadata) *(2)* création du premier animal directement (nom, espèce — les champs
existent déjà dans la sheet Home, on les réutilise ici). Réduit le temps avant la
première valeur perçue ; pas de nouvelle dépendance, juste un écran de plus dans
`go_router` et un léger ajout au schéma (`raw_user_meta_data.first_name` via
Supabase Auth, ou une table `profiles` si on veut plus tard d'autres préférences).

---

## Phase 2 — Fiche animal enrichie

### 2.1 Race et date de naissance dans le formulaire 🟢
Bonne nouvelle : `breed` et `birth_date` existent **déjà** dans le modèle `Pet` et
le schéma Supabase (`lib/models/pet.dart`, `supabase/migrations/`) — et s'affichent
déjà sur la fiche animal si présents. Le seul manque : la sheet d'ajout/édition
(`_showAddPetSheet` dans `home_screen.dart`) ne propose que Nom + Espèce. Ajouter un
champ race (texte libre ou liste par espèce) et un sélecteur de date de naissance —
même pattern que les date pickers déjà utilisés pour vaccins/traitements/RDV.
Aucune migration nécessaire.

### 2.2 Photo de l'animal 🟡
Remplacer/compléter le `PetAvatar` (icône générique par espèce) par une vraie photo
quand elle existe. Nécessite : un bucket Supabase Storage, `image_picker` (ou
`file_picker` + caméra) pour choisir/prendre la photo, un champ `photo_url` sur
`Pet`, et un fallback sur `PetAvatar` quand aucune photo n'est définie (pas de
régression pour les animaux existants).

### 2.3 Informations santé par race 🔴
Afficher les maladies/prédispositions courantes pour la race renseignée (ex. :
dysplasie de la hanche chez le Berger Allemand, problèmes respiratoires chez les
races brachycéphales). Nécessite une source de données : pas d'API vétérinaire
canine/féline gratuite et fiable identifiée à ce jour — options réalistes : *(a)*
un jeu de données statique embarqué (races courantes + prédispositions, curé
manuellement, mis à jour rarement) pour démarrer sans dépendance externe, *(b)* une
API tierce payante (ex. Dog API croisée avec une base vétérinaire) si le besoin
grandit. Recommandation : commencer par (a) — un fichier JSON embarqué pour les
~30-50 races les plus courantes, largement suffisant pour la V1 de cette feature.

---

## Phase 3 — Écosystème vétérinaire

### 3.1 Carte des vétérinaires à proximité 🔴
Nécessite : géolocalisation (`geolocator`), une source de données de cliniques
vétérinaires (Google Places API — payant au-delà d'un quota, ou Overpass API sur
OpenStreetMap — gratuit mais couverture variable selon la région), et un widget
carte (`google_maps_flutter` si Google Places, `flutter_map` + tuiles OSM si
Overpass). Recommandation : démarrer avec OSM/Overpass + `flutter_map` pour éviter
une dépendance à une clé API payante dès la V1, quitte à migrer vers Google Places
plus tard si la couverture des données OSM déçoit dans les zones cibles.

### 3.2 Vétérinaires favoris 🟡
Une fois 3.1 en place : table `favorite_vets` (Supabase) liée à l'utilisateur,
bouton favori sur chaque résultat de la carte/liste, et une section "Mes
vétérinaires" accessible depuis Profil ou un nouvel onglet. Peut aussi précéder
3.1 sous une forme simplifiée : un vétérinaire favori saisi manuellement (nom,
téléphone, adresse) sans carte — un jalon intermédiaire raisonnable si 3.1 prend
du retard.

---

## Phase 4 — Suivi des médicaments

### 4.1 Scanner de code-barres pour ajouter un médicament 🔴
Nécessite `mobile_scanner` (ou équivalent) pour la lecture caméra du code-barres —
partie simple et fiable. La partie incertaine : **pré-remplir automatiquement le
nom du médicament** à partir du code scanné demande une base de données de
produits ; il n'existe pas de base publique fiable et gratuite dédiée aux
médicaments vétérinaires (contrairement à l'alimentaire avec Open Food Facts).
Périmètre réaliste pour une V1 : le scan capture le code-barres et pré-remplit un
champ "référence" libre dans la sheet d'ajout de traitement existante — l'usager
complète le nom manuellement la première fois. Une correspondance code→nom
mémorisée localement (par utilisateur) pourrait accélérer les scans suivants du
même produit, sans dépendre d'un service externe.

---

## Suggestions complémentaires

Idées qui prolongent naturellement l'app, à prioriser selon l'usage réel :

- **Partage multi-utilisateurs** 🔴 — inviter un autre membre du foyer (conjoint,
  pet-sitter) à voir/gérer les animaux d'un même compte. Nécessite un modèle de
  permissions (table de partage + RLS Supabase) — jalon architectural, pas un
  petit ajout.
- **Export PDF du carnet de santé** 🟡 — utile avant un rendez-vous vétérinaire ou
  un changement de vétérinaire ; génère un résumé imprimable (vaccins,
  traitements, poids, visites) à partir des données déjà en base.
- **Objectif de poids par race** 🟡 — plage de poids idéale par race/âge, alerte
  visuelle sur le graphique de poids (Task 6) si l'animal sort de la plage.
  S'appuie sur le même jeu de données que 2.3.
- **Export/sauvegarde des données** 🟢 — export CSV/JSON de l'historique complet,
  utile pour la portabilité et la tranquillité d'esprit (pas de verrouillage chez
  un seul fournisseur).
- **Mode hors-ligne basique** 🔴 — mise en cache locale + file d'attente de
  synchronisation pour ajouter une pesée ou un traitement sans connexion (utile en
  salle d'attente vétérinaire, souvent mal couverte). Chantier technique
  significatif (conflict resolution avec Supabase) — à envisager seulement si les
  retours utilisateurs le réclament vraiment.
- **QR code d'urgence** 🟡 — un QR code par animal (à imprimer sur une médaille ou
  un collier) pointant vers une fiche minimale publique (nom, race, contact
  propriétaire, allergies) — utile en cas de perte de l'animal.
- **Accessibilité** 🟢 — labels `Semantics` sur les icônes/illustrations,
  vérification du texte dynamique (Dynamic Type / échelle de police système), déjà
  en partie couvert par le respect de `disableAnimations` (Task 10).

---

## Suggestion d'ordonnancement

1. **Phase 1** (auth/onboarding) — tout en 🟢/🟡, aucune dépendance externe, impact
   direct sur la première impression.
2. **Phase 2.1** (race/date de naissance dans le formulaire) — quasi gratuit,
   complète un champ déjà modélisé.
3. **Phase 2.2** (photo) puis **Export PDF/CSV** — dépendances contenues
   (Supabase Storage, pas de service tiers).
4. **Phase 4.1** (scanner, périmètre réduit) — dépendance package uniquement, pas
   de service externe si on accepte la saisie manuelle du nom au premier scan.
5. **Phase 2.3** (santé par race) — dataset statique, pas de service externe.
6. **Phase 3** (carte vétérinaires + favoris) — le plus gros chantier
   d'intégration (géoloc + données de lieux) ; à traiter en dernier ou en parallèle
   si le temps/l'envie le permettent, indépendamment du reste.
