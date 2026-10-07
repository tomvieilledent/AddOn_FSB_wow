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
