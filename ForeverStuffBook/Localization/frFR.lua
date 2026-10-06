local _, FSB = ...

-- Table de textes. Une autre langue = un autre fichier qui remplit FSB.L.
FSB.L = {
    ADDON_LOADED   = "Forever Stuff Book chargé. Tape /fsb pour l'aide.",
    ANALYSIS_TITLE = "Analyse FSB",
    PROFILE        = "Profil",
    ENABLED        = "FSB activé",
    DISABLED       = "FSB désactivé",

    VERDICT_EQUIP   = "À ÉQUIPER",
    VERDICT_OFFSPEC = "OFF-SPÉ",
    VERDICT_SELL    = "VENDRE / DÉSENCHANTER",

    HELP = {
        "/fsb on | off : active ou désactive l'analyse",
        "/fsb profils : liste les profils",
        "/fsb profil <nom> : choisit le profil actif",
        "/fsb nouveau <nom> : crée un profil (copie du profil actif)",
        "/fsb supprimer <nom> : supprime un profil",
        "/fsb poids [<stat> <valeur>] : affiche ou modifie les poids du profil actif",
        "/fsb inconnus : stats rencontrées et non reconnues",
    },
    PROFILE_ACTIVE  = "Profil actif : %s",
    PROFILE_UNKNOWN = "Profil introuvable : %s",
    PROFILE_CREATED = "Profil créé : %s",
    PROFILE_EXISTS  = "Nom invalide ou déjà utilisé : %s",
    PROFILE_DELETED = "Profil supprimé : %s",
    PROFILE_KEEP_ONE = "Impossible de supprimer ce profil.",
    WEIGHT_SET      = "%s = %s (profil %s)",
    STAT_UNKNOWN    = "Stat inconnue : %s (alias : voir /fsb poids)",
    NO_UNKNOWN      = "Aucune stat inconnue rencontrée.",
}
