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
- [ ] Onglet **Détection** de `/fsb` : la liste des poids correspond au profil attendu (classe, spé, mode).
- [ ] 🔎 Un objet de lanceur avec +toucher/+critique **des sorts** : la clé apparaît-elle dans `/fsb inconnus` ?

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
- [ ] Un objet que ma classe **ne peut pas porter** (ex. plaque pour un mage, plaque pour un guerrier < 40)
      → inutilisable (« Non utilisable par ton personnage »). 🔎 Noter tout objet portable écarté à tort.
- [ ] Arme d'un type autorisé pour ma classe mais **compétence pas encore apprise** → verdict normal + ligne
      « Compétence à apprendre chez un maître d'armes : … ». 🔎 Si elle reste inutilisable : `/fsb debug` en la survolant.

## 4. Spécialisation et mode (onglet Détection de `/fsb`)
- [ ] La **spé analysée** = l'arbre où j'ai le plus de points (ex. démoniste Démonologie, mage Givre) ; les points de
      chaque arbre sont affichés. Aucune question de rôle n'est posée.
- [ ] Dépenser des points dans un autre arbre jusqu'à le dépasser → la spé et le profil suivent (sans `/reload`).
- [ ] Sous le niveau 10 : « Aucune (pas de spé sous le niveau 10) », profil « Leveling 1–9 » ; en donjon :
      « Donjons bas niveau ».
- [ ] Niveaux 10–59 : mode « Leveling 10–59 » ; niveau 60 : « PvE 60 ».
- [ ] `/fsbpvp` puis `/fsbpve` (ou les boutons PvE/PvP de l'accueil) → le mode et le profil changent ; le choix est
      conservé après `/reload`.
- [ ] Rôle affiché conforme (ex. « DPS · Mixte · CAC » pour un chaman Amélioration).
- [ ] Lieu : Extérieur / Donjon / Raid / Champ de bataille.
- [ ] **Druide farouche uniquement** : une fenêtre demande Ours ou Félin ; les boutons Ours/Félin apparaissent dans
      l'onglet Détection ; `/fsb ours` et `/fsb felin` fonctionnent. Aucune autre classe ne voit cette question.

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
- [ ] Onglets Accueil (avec PvE/PvP), Détection, Commandes, Réglages : aucun texte qui déborde.
- [ ] Réglages : « Analyse activée », « Icônes », « Détails », « Équité du loot », langue FR/EN.
- [ ] Les réglages persistent après `/reload`.
- [ ] 🔎 Capture d'écran de la fenêtre si l'aspect est mauvais.

## 9. Armes et sacs
- [ ] Bâton porté, main gauche (orbe, bouclier) dans le sac, survoler une arme de main droite : si l'ensemble est
      meilleur → À ÉQUIPER + « À équiper avec, en main gauche : … (dans ton sac) » + « Remplace : [bâton] ».
- [ ] Même chose en survolant la main gauche avec une arme de main droite dans le sac.
- [ ] Classe ambidextre : une arme portée peut être proposée « (change de main) ».
- [ ] Classe sans ambidextrie : jamais d'arme proposée en main gauche.
- [ ] Ranger/retirer une arme du sac → le verdict se met à jour au survol suivant.
- [ ] Survoler une arme déjà portée : pas de « À ÉQUIPER ».

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
