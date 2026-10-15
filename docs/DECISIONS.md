# DECISIONS

## Équipe d'agents réduite à 8 rôles
Date: 2026-10-07
Context: projet de ~2100 lignes.
Problem: éviter une organisation disproportionnée.
Options: 15 agents / 8 rôles / Lead seul.
Decision: 8 rôles (voir `.claude/agents/`).
Reason: séparation des vetos (API, conformité, QA, revue) sans surcoût.
Consequences: Release et documentation portés par le Lead.

## Vérité technique = sortie du client
Date: 2026-10-07
Context: aucun client Forever sur la machine de dev ; sources web secondaires.
Problem: un agent peut halluciner une API.
Options: croire les sources web / exiger une sortie en jeu.
Decision: seul VERIFIED = sortie de `/fsb sonde` ou export d'interface du client.
Reason: règle zéro hallucination.
Consequences: Phase « vérification en jeu » avant toute migration API.

## Correction d'audit : verdict 🟡
Date: 2026-10-07
Context: le cahier des charges §13 définit 🟡 comme « utile au joueur » + upgrade supérieur pour un autre.
Problem: première lecture de l'audit jugeait `Verdict.Group` incorrect.
Decision: `Verdict.Group` conforme, conservé.
Consequences: aucune réécriture.

## Pas de mode manuel, poids fixes
Date: 2026-10-07
Context: demande explicite de l'utilisateur ; Forever n'expose qu'une spé (= classe) par classe.
Decision: profil actif = rôle de la classe (question une fois si plusieurs rôles), poids non modifiables, profils rechargés du code.
Consequences: la spé réelle (arbre de talents) dépend d'une API de talents à confirmer ; autres joueurs comparés seulement si leur classe n'a qu'un rôle.
Statut : remplacée par « Spé détectée par les talents, poids par classe/arbre/mode » (2026-10-15).

## Spé détectée par les talents, poids par classe/arbre/mode
Date: 2026-10-15
Context: la lecture des arbres de talents fonctionne en jeu (C_Traits, par position) ; l'utilisateur fournit un tableau de
poids par classe, spé et mode (estimations indicatives).
Decision: un profil par classe × arbre × mode (Leveling 10–59, PvE 60, PvP) et, sous le niveau 10, un profil par classe
(Leveling 1–9, Donjons bas niveau). Spé = arbre le plus investi, sans question ; égalité → arbre déjà détecté ; aucun point →
dernier arbre connu, sinon le premier. Style PvE/PvP choisi par le joueur (pas de bascule automatique en champ de bataille).
Seule exception à « aucune question » : druide farouche, ours ou félin (une fois, modifiable).
Consequences: plus de choix de rôle manuel (anciennes données `specChoice` supprimées) ; schéma des SavedVariables = 5 ;
autres joueurs comparés avec la moyenne des arbres de leur classe pour leur rôle.

## Combinaisons d'armes avec le sac
Date: 2026-10-15
Context: comparer une arme seule ne dit pas si elle est meilleure avec une main gauche déjà possédée.
Decision: pour une arme/main gauche, meilleure combinaison des deux mains parmi le sac et les mains actuelles, comparée aux
mains actuelles ; seules les armes équipables tout de suite servent de partenaire. Uniquement pour le joueur.
Consequences: le tooltip indique l'arme à associer et ce qui est remplacé ; cache des armes invalidé à chaque changement de sac.

## Table Classic de l'équipement par classe
Date: 2026-10-15
Context: le tooltip est la seule source sur Forever, illisible parfois, et inconnu pour les autres joueurs.
Decision: `Data/Equipment.lua` (référence Classic/Vanilla, UNVERIFIED sur Forever) sert de garde-fou : un objet que la classe
ne peut jamais porter est inutilisable même sans ligne rouge ; un membre du groupe qui ne peut pas le porter est écarté. Une arme
dont seule la compétence manque (type d'arme en rouge, classe autorisée) reste analysée avec une note.
Consequences: si Forever a modifié une règle, la table peut écarter un objet portable : corriger la ligne concernée.
