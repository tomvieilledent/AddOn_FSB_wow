# Tests à faire en jeu (WoW Forever 1.60.1)

Ces tests ne peuvent pas être faits hors du client. Cocher au fur et à mesure et me renvoyer les **échecs** avec le
message d'erreur Lua exact (activer les erreurs : `/console scriptErrors 1`).

**Installation** : copier `ForeverStuffBuddy/` dans `Interface\AddOns\`, redémarrer le client (ou `/reload`).
Si l'addon n'apparaît pas dans la liste, vérifier qu'il charge via le fichier `ForeverStuffBuddy_Camelot.toc`.

Légende : ✅ attendu · 🔎 information à me rapporter

---

## 0. Chargement
- [ ] L'addon est listé dans « Addons » et chargé sans erreur Lua.
- [ ] Message `FSB: Forever Stuff Buddy chargé…` au login.
- [ ] `/fsb` ouvre une fenêtre (voir §7). Si erreur : `FSB: UI : <message>` → me le renvoyer.
- [ ] `/fsb aide` liste les commandes.

## 1. Tooltip et filtres
- [ ] Survoler un objet **équipable vert/bleu/violet/orange** (sac, banque, équipement, lien dans le chat, fenêtre de
      loot) → ✅ un verdict coloré + « Profil : … » + « Analyse FSB » en bas du tooltip. Noter où ça **ne** marche pas.
- [ ] Objet **gris/blanc** équipable → ✅ aucune ligne FSB.
- [ ] Potion, composant, gemme, objet de quête → ✅ aucune ligne FSB.
- [ ] Chemise, tabard, sac → ✅ aucune ligne FSB.
- [ ] Le tooltip ne s'allonge pas en double (une seule fois les lignes FSB) quand on repasse sur l'objet.
- [ ] `/fsb off` → plus de lignes ; `/fsb on` → elles reviennent.

## 2. Stats (clés de l'API) — important
- [ ] Après avoir survolé ~10 objets variés (armes, armures, bijoux, anneaux) : `/fsb inconnus`.
      🔎 **Me copier la liste** (clés `ITEM_MOD_*` non reconnues, p. ex. maîtrise, hâte, etc.).
- [ ] Un objet avec des stats évidentes (ex. +Endurance, +Intelligence) : le verdict change quand on modifie le
      poids correspondant (`/fsb poids int 0` puis `/fsb poids int 100`, survoler à nouveau).

## 3. Verdicts solo (hors donjon/raid)
- [ ] Objet clairement meilleur que le porté → **À ÉQUIPER** (vert).
- [ ] Objet clairement moins bon → pas « À ÉQUIPER ».
- [ ] Objet utile à un autre profil (ex. bon pour « Dégâts physiques » alors que le profil actif est « Soigneur »)
      → **OFF-SPÉ — Dégâts physiques**.
- [ ] Objet sans intérêt → **VENDRE / DÉSENCHANTER** (rouge).
- [ ] **Anneaux** : porter 2 anneaux, survoler un 3e meilleur que le plus faible seulement → À ÉQUIPER ; moins bon
      que les deux → pas À ÉQUIPER.
- [ ] **Bijoux** : même test.
- [ ] **Armes** : porter une 1M + main gauche, survoler une 2M (très forte puis très faible) ; porter une 2M et
      survoler une 1M ; porter une 2M et survoler un bouclier (aucun verdict « équiper » attendu).
- [ ] Classe sans double maniement : une arme 1M main gauche ne doit pas être proposée (🔎 noter si c'est le cas).
- [ ] Changer un équipement puis re-survoler un objet du même type → verdict mis à jour (invalidation du cache).
- [ ] Le tooltip s'affiche instantanément (pas de lag perceptible) au deuxième survol.
- [ ] Verdict avec un objet jamais vu (données non chargées) : aucun crash ; il apparaît au survol suivant.
- [ ] 🔎 Un objet que ma classe **ne peut pas porter** (ex. plaque pour un mage) : noter le verdict affiché
      (limite connue : pas de vérification de classe).

## 4. Spécialisation
- [ ] `/fsb etat` → 🔎 noter la ligne `Spé : <id>` (nombre = détectée ; `?` = non détectée).
- [ ] Si détectée : le profil actif correspond à la spé (Soigneur / Tank / Dégâts magiques / Dégâts physiques) et la
      mention `(auto)` s'affiche.
- [ ] Changer de spécialisation en jeu (si possible) → le profil suit automatiquement.
- [ ] `/fsb profil Tank` puis `/fsb etat` → `(manuel)` ; `/fsb auto` → retour au profil de la spé.
- [ ] `/fsb spe` → fenêtre « Quelle est ta spécialisation ? » avec **Auto** + une ligne par spé de ta classe
      (🔎 noter si les noms/nombres sont corrects). Choisir une spé → le profil change ; choisir « Auto » → retour.
- [ ] Si la spé n'est **pas** détectée à la connexion : la fenêtre de choix s'ouvre toute seule (une seule fois).
- [ ] `/fsb specprofil <nom d'un profil>` associe la spé actuelle à ce profil.

## 5. Sets
- [ ] Avoir une pièce d'un set équipée, survoler une autre pièce du même set : le tooltip peut afficher
      « Bonus de set gagné : N palier(s) (non chiffré dans le verdict) ». 🔎 Dire si c'est cohérent avec le tooltip
      natif du jeu (lignes « (2) Set : … »).
- [ ] Remplacer une pièce de set par un objet hors set (ex. anneau/bijou fort) → « Bonus de set perdu » si un palier
      était actif.
- [ ] Si la ligne « Analyse partielle : paliers de set non lisibles » apparaît à tort → me copier le texte exact des
      lignes de bonus de set du tooltip natif (format `(2) Set : …` ?).
- [ ] `/fsb set 200` : un palier gagné doit faire pencher vers « À ÉQUIPER » ; `/fsb set 0` : plus d'effet sur le verdict.

## 6. Mode groupe / scan (nécessite un groupe, idéalement 2-5 joueurs)
Prérequis : **donjon ou raid ET en groupe**. `/fsb etat` donne `Mode : GROUPE|SOLO | membres à scanner : N | membres comparables : M`.
- [ ] Monde ouvert, en groupe → `Mode : SOLO` ; les verdicts sont À ÉQUIPER / OFF-SPÉ / VENDRE (pas CUPI, pas 🟡).
- [ ] Entrer dans un donjon en groupe → `Mode : GROUPE` ; verdicts À PRENDRE / MEILLEUR POUR UN AUTRE / OFF-SPÉ / CUPI.
- [ ] Instance **en solo** → `Mode : SOLO`.
- [ ] Champ de bataille / arène → `Mode : SOLO`.
- [ ] Raid → `Mode : GROUPE`.
- [ ] Sans rien faire, approcher chaque coéquipier (≈ 28 m) : `membres à scanner` baisse ; `membres comparables` monte.
      🔎 **Noter** : distance réelle d'inspection, délai de scan, et si la **spécialisation des autres** est bien lue
      (si `membres comparables` reste à 0 malgré des membres scannés → spé illisible : me le dire).
- [ ] Un membre resté **hors de l'instance** n'est jamais inspecté (pas d'erreur, pas de message).
- [ ] Un membre qui **quitte** le groupe : `/fsb etat` → il disparaît des comparables.
- [ ] Groupe dissous → tout est remis à zéro.
- [ ] Pas d'inspection pendant un combat ; reprise après.
- [ ] Ouvrir **manuellement** la fenêtre d'inspection d'un joueur : FSB ne doit pas la perturber.
- [ ] 🔎 **Valeurs « secrètes »** : en combat/instance, aucune erreur Lua du type « secret value ».
- [ ] Survoler un objet très bon pour un autre membre (ex. objet de soin alors qu'un soigneur du groupe est sans
      pièce dans l'emplacement) → **MEILLEUR POUR UN AUTRE** + « Plus utile à : <nom> ».
- [ ] Une petite différence entre moi et un autre membre ne doit **pas** donner ce verdict.
- [ ] Ligne grise « N membre(s) pas encore analysé(s) » tant que des membres ne sont pas scannés.
- [ ] Performance : pas de baisse de FPS en raid 10/25/40 ; `/fsb etat` répond instantanément.

## 7. Interface `/fsb`
- [ ] La fenêtre s'affiche correctement (texte lisible, pas de chevauchement) et se ferme avec Échap / la croix.
- [ ] Cases « Analyse activée » et « Profil automatique » fonctionnent.
- [ ] Boutons de profils : un clic active le profil (marqué `*`).
- [ ] Créer un profil (nom + « Créer »), le supprimer (« Supprimer » : jamais le dernier).
- [ ] Modifier un poids dans la grille (Entrée valide) → vérifié par `/fsb poids` et le verdict.
- [ ] Seuils : modifier « Upgrade min. », « Marge « autre » », « Valeur palier de set » → effet sur les verdicts.
- [ ] Les réglages persistent après `/reload`.
- [ ] 🔎 Capture d'écran de la fenêtre si l'aspect est mauvais.

## 8. Compatibilité
- [ ] Aucune erreur Lua au login, au changement de zone, en combat, en changeant d'équipement.
- [ ] Autres addons actifs (sacs, tooltips) : les lignes FSB s'affichent aussi dans leurs tooltips d'objets.
- [ ] Banque, fenêtre de loot (survol de l'objet), lien d'objet dans le chat : verdict présent.
- [ ] 🔎 Version exacte du client (`/dump (select(4, GetBuildInfo()))`) si ≠ 16001.

---

### Renseignements à me renvoyer (même si tout marche)
1. Sortie de `/fsb inconnus`.
2. Ligne `/fsb etat` en solo et en groupe.
3. Spé des autres lisible ? (oui/non), distance/délai d'inspection.
4. Format des lignes de set dans le tooltip natif.
5. Toute erreur Lua (texte complet).
