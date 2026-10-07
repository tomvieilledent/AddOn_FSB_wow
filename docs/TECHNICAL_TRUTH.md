# TECHNICAL_TRUTH — faits techniques

Statuts : VERIFIED · UNVERIFIED · CONFLICTING · IMPOSSIBLE.
Le code de production ne dépend jamais d'un fait UNVERIFIED sans repli (`pcall`, test de présence, « inconnu »).
Sources VERIFIED admises : sortie d'une commande en jeu (`/fsb sonde`), fichiers d'interface exportés du client Forever.
Sources secondaires (articles, wiki d'autres versions) = UNVERIFIED au mieux.

## Client
| Fait | Statut | Source |
|---|---|---|
| Interface 16001 | UNVERIFIED (cohérent avec l'addon WhoNeedsThis sur CurseForge) | `/fsb sonde` → `GetBuildInfo` |
| Version client 1.60.1 | UNVERIFIED | idem |
| Forever partage l'architecture UI mainline (12.1.5) | UNVERIFIED (Icy Veins, Gamewave) | export interface |
| Restrictions Midnight (« secret values ») actives | UNVERIFIED (mêmes sources) | tests en jeu en instance/combat |
| Retail ≠ Classic ≠ Forever | règle de projet | — |

## API
Aucune API n'est VERIFIED. Liste et statuts : `docs/UNVERIFIED.md`.

## Règles de conformité (VERIFIED : décisions de projet)
Addon passif : aucune action de jeu, aucune simulation d'entrée, aucune API protégée. Voir `docs/COMPLIANCE.md`.

## Limitations connues
- Pas de filtre de classe/armure/arme (écart avec le cahier des charges §3).
- Poids par défaut génériques, non sourcés.
