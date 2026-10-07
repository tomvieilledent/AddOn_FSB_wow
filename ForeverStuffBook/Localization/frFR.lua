local _, FSB = ...

-- Textes par langue : une langue = un fichier qui remplit FSB.Locales[<code>]. FSB.L lit la langue active
-- (FSB.language) et retombe sur le français pour toute clé manquante.
FSB.Locales = FSB.Locales or {}
FSB.Locales.frFR = {
    ADDON_LOADED   = "Forever Stuff Book chargé. Tape /fsb pour l'aide.",
    ANALYSIS_TITLE = "FSB",
    PROFILE        = "Profil",
    SPEC           = "Rôle",
    LABEL_SPEC     = "Spé",
    LABEL_CLASS    = "Classe",
    ENABLED        = "FSB activé",
    DISABLED       = "FSB désactivé",

    VERDICT_TAKE         = "À PRENDRE",
    VERDICT_BETTER_OTHER = "MEILLEUR POUR UN AUTRE",
    VERDICT_CUPI         = "CUPI",
    UNUSABLE        = "Non utilisable par ton personnage",
    REQ_LEVEL       = "Niveau %d requis",
    BETTER_FOR      = "Plus utile à : %s",
    UNSCANNED       = "%d membre(s) pas encore analysé(s)",
    SET_GAINED      = "Bonus de set gagné : %d palier(s)",
    SET_LOST        = "Bonus de set perdu : %d palier(s)",
    SET_PARTIAL     = "Analyse partielle : paliers de set non lisibles",
    SET_UNVALUED    = "(non chiffré dans le verdict)",
    VERDICT_UNKNOWN = "ANALYSE IMPOSSIBLE",
    UNKNOWN_STATS   = "Stats non reconnues : analyse peu fiable (/fsb inconnus)",
    VERDICT_EQUIP   = "À ÉQUIPER",
    VERDICT_OFFSPEC = "OFF-SPÉ",
    VERDICT_SELL    = "VENDRE / DÉSENCHANTER",

    HELP = {
        "/fsb : ouvre la configuration",
        "/fsb on | off : active ou désactive l'analyse",
        "/fsb lang fr | en : changer la langue",
        "/fsb role : choisir le rôle joué avec la spé actuelle",
        "/fsb etat : diagnostic (mode, scan, spé)",
        "/fsb poids : poids indicatifs du profil actif (non modifiables)",
        "/fsb log [vider|off|on] : journal des hésitations (à envoyer pour la mise à jour)",
        "/fsb mauvais [texte] : signale un mauvais verdict sur le dernier objet survolé",
        "/fsb specs : liste les spécialisations de toutes les classes (diagnostic)",
        "/fsb debug : détail de l'analyse du dernier objet survolé",
        "/fsb sonde : vérifie les API en jeu (lecture seule)",
        "/fsb inconnus : stats rencontrées et non reconnues",
    },
    PROFILE_ACTIVE  = "Profil actif : %s",
    PROFILE_UNKNOWN = "Profil introuvable : %s",
    NO_UNKNOWN      = "Aucune stat inconnue rencontrée.",
    STATE           = "Mode : %s | membres à scanner : %d | membres comparables : %d",
    STATE_SPEC      = "Spé : %s | profil : %s",

    -- Interface
    UI_TITLE        = "Forever Stuff Book",
    UI_ENABLED      = "Analyse activée",
    UI_WEIGHTS      = "Poids des statistiques (fixes, indicatifs)",
    LOG_CLEARED     = "Journal vidé.",
    LOG_OFF         = "Journal des hésitations désactivé.",
    LOG_ON          = "Journal des hésitations activé.",
    LOG_NOITEM      = "Survole d'abord un objet, puis /fsb mauvais [commentaire].",
    LOG_FLAGGED     = "Noté dans le journal. Merci : /fsb log pour l'exporter.",
    LOG_COUNT       = "Journal : %d entrée(s) (/fsb log)",
    COPY_TITLE      = "Forever Stuff Book — Ctrl+A puis Ctrl+C pour copier",
    UI_ICONS        = "Icônes",
    UI_DETAILS      = "Détails",
    UI_STATUS       = "%s",
    UI_PICK_ROLE    = "Mon rôle",
    ROLE_PICK_TITLE = "Que joues-tu avec %s ?",
    ROLE_PICK_NOTE  = "Mémorisé pour cette spé (/fsb role pour changer).",
    ROLE_PICK_BTN   = "Mon rôle",

    UI_TAB_GENERAL  = "Général",
    UI_TAB_STATS    = "Stats",
    UI_LANGUAGE     = "Langue",
    UI_STATS_NOTE   = "Onglet temporaire : poids du profil actif, en attendant l'équilibrage final.",
    UI_ALL_PROFILES = "Tous les profils (copier)",
    LANG_CHANGED    = "Langue : Français",
    LANG_UNKNOWN    = "Langue inconnue : %s (fr ou en)",
    POIDS_TITLE     = "%s (poids fixes, indicatifs)",
    STATS = {
        RESISTANCE0_NAME = "Armure", ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "Dégâts par seconde (arme)",
        ITEM_MOD_STRENGTH_SHORT = "Force", ITEM_MOD_AGILITY_SHORT = "Agilité", ITEM_MOD_STAMINA_SHORT = "Endurance",
        ITEM_MOD_INTELLECT_SHORT = "Intelligence", ITEM_MOD_SPIRIT_SHORT = "Esprit",
        ITEM_MOD_ATTACK_POWER_SHORT = "Puissance d'attaque", ITEM_MOD_SPELL_POWER_SHORT = "Puissance des sorts (soins + dégâts)",
        ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "Dégâts des sorts", ITEM_MOD_SHADOW_DAMAGE_DONE_SHORT = "Dégâts Ombre",
        ITEM_MOD_FIRE_DAMAGE_DONE_SHORT = "Dégâts Feu", ITEM_MOD_FROST_DAMAGE_DONE_SHORT = "Dégâts Givre",
        ITEM_MOD_NATURE_DAMAGE_DONE_SHORT = "Dégâts Nature", ITEM_MOD_ARCANE_DAMAGE_DONE_SHORT = "Dégâts Arcanes",
        ITEM_MOD_HOLY_DAMAGE_DONE_SHORT = "Dégâts Sacré", ITEM_MOD_SPELL_HEALING_DONE_SHORT = "Soins",
        ITEM_MOD_MANA_REGENERATION_SHORT = "MP5", ITEM_MOD_CRIT_RATING_SHORT = "Critique",
        ITEM_MOD_HIT_RATING_SHORT = "Toucher", ITEM_MOD_HASTE_RATING_SHORT = "Hâte",
        ITEM_MOD_EXPERTISE_RATING_SHORT = "Expertise", ITEM_MOD_MASTERY_RATING_SHORT = "Maîtrise",
        ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "Défense", ITEM_MOD_DODGE_RATING_SHORT = "Esquive",
        ITEM_MOD_PARRY_RATING_SHORT = "Parade", ITEM_MOD_BLOCK_RATING_SHORT = "Blocage",
        ITEM_MOD_RESILIENCE_RATING_SHORT = "Résilience",
    },
    -- Noms affichés des profils (l'identifiant interne reste le nom français).
    PROFILES = {},
}

-- FSB.L : langue active, repli sur le français.
FSB.language = FSB.language or "frFR"
FSB.L = setmetatable({}, { __index = function(_, key)
    local active = FSB.Locales[FSB.language]
    local value = active and active[key]
    if value == nil then value = FSB.Locales.frFR[key] end
    return value
end })

-- Change la langue (frFR / enUS) et met l'interface à jour.
function FSB.SetLanguage(code)
    if not FSB.Locales[code] then return false end
    FSB.language = code
    if FSB.db then FSB.db.language = code end
    if FSB.UI and FSB.UI.Retranslate then FSB.UI.Retranslate() end
    return true
end
