# AUDIT (2026-10-07)

| Module | Action | Remarque |
|---|---|---|
| Core/Core | KEEP | pas de Events/State séparés (écart de forme) |
| Core/Compat | REFACTOR | cible principale de la vérification d'API |
| Core/Context, Spec | KEEP | API de spé UNVERIFIED |
| Core/Inspector | KEEP | tient lieu de GroupAnalyzer ; API UNVERIFIED |
| Core/Probe | NEW | sonde de vérification en jeu |
| Data/Stats, Profiles | REFACTOR | clés à confirmer ; poids non sourcés ; pas de version de schéma |
| Engine/* | KEEP | Lua pur, testé |
| Tooltip | REFACTOR | dédoublonnage |
| UI/Settings | REFACTOR | `.text`/`.Text` ; réglages d'affichage absents |
| TOC `_Camelot` | UNKNOWN | doublon, suffixe non vérifié |

## Écarts avec le cahier des charges
| § | Attendu | État |
|---|---|---|
| 3 | « réellement équipable par le personnage » | ABSENT (classe/armure/arme) |
| 17 | Events, State, Classes, GroupAnalyzer, MainFrame, ProfileEditor | absents en modules séparés |
| 18 | réglages d'affichage, activation par analyse | absents |
| 16 | vendre vs désenchanter | optionnel, absent |
| 9 | iLvl en information complémentaire | non utilisé |
| 13 | verdicts groupe | conformes |
