local _, FSB = ...

-- Arbres de talents de chaque classe, dans l'ordre Classic (index = onglet de talents).
-- Sert à vérifier la lecture des talents (nombre d'arbres attendu) ; les poids sont dans Data/Weights.lua.
local Classes = {}
FSB.Classes = Classes

Classes.TREES = {
    WARRIOR = { "Armes", "Fureur", "Protection" },
    PALADIN = { "Sacré", "Protection", "Vindicte" },
    HUNTER = { "Maîtrise des bêtes", "Précision", "Survie" },
    ROGUE = { "Assassinat", "Combat", "Finesse" },
    PRIEST = { "Discipline", "Sacré", "Ombre" },
    SHAMAN = { "Élémentaire", "Amélioration", "Restauration" },
    MAGE = { "Arcanes", "Feu", "Givre" },
    WARLOCK = { "Affliction", "Démonologie", "Destruction" },
    DRUID = { "Équilibre", "Combat farouche", "Restauration" },
}
