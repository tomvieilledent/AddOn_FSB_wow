# UNVERIFIED — registre des incertitudes

Existence des API confirmée le 2026-10-07 (voir TECHNICAL_TRUTH). Reste à confirmer : retours, clés, couleurs, valeurs « secrètes ».
Tout est à confirmer via `/fsb sonde` (voir `docs/SONDE.md`) puis déplacé dans `TECHNICAL_TRUTH.md`.
Next action : API SPECIALIST pour chaque ligne, après récupération de la sortie de la sonde.

| Élément | Utilisé par | Question | Impact si faux |
|---|---|---|---|
| `C_Item.GetItemStats` + clés `ITEM_MOD_*` | Compat | Existe ? Quelles clés ? | Tous les verdicts faux |
| `C_Item.GetItemInfo` (16e retour = setID) | Compat | Position du setID ? | Sets inactifs |
| `C_Item.GetItemInfoInstant` (4e retour = equipLoc) | Utils | Idem | Aucun verdict |
| `C_Item.GetItemQualityByID` | Utils | Accepte un lien ? | Aucun verdict |
| `C_TooltipInfo.GetHyperlink` (retour : lignes, couleurs) | Compat (sets, utilisabilité) | Format des lignes et couleurs ? | Sets « partiels », filtre inactif |
| `ITEM_SET_BONUS_GRAY` | Compat | Format de la ligne | Paliers illisibles |
| `TooltipDataProcessor.AddTooltipPostCall`, `tooltip:GetItem` | Tooltip | Fonctionne sur Forever ? | Aucun affichage |
| `C_SpecializationInfo.*`, `GetSpecializationInfoForSpecID/ClassID` | Spec | Existence, signatures (retour 6 = stat principale ?) | Choix manuel seul |
| `C_SpecializationInfo.GetInspectSpecialization` | Inspector | Spé des autres lisible ? | Pas de comparaison de groupe |
| `NotifyInspect`, `CanInspect`, `INSPECT_READY`, `GetInventoryItemLink(unit)` | Inspector | Autorisés, valeurs « secrètes » ? | Pas de comparaison de groupe |
| `C_Map.GetBestMapForUnit`, `UnitIsVisible` | Inspector | Existence | Filtre d'instance dégradé |
| `CanDualWield` | Compat | Existence | Suppose oui |
| `UICheckButtonTemplate` : `.text` ou `.Text` | UI | Nom du champ | `/fsb` en erreur |
| Suffixe `_Camelot.toc` | TOC | Utile à Forever ? | TOC superflu |
| Classe/armure/arme équipables par le personnage | (absent) | Quelle API ? | Verdicts erronés |
