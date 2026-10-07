local _, FSB = ...

-- Rôles que chaque classe peut tenir, sous forme de noms de profils par défaut. Connaissance du jeu
-- (UNVERIFIED sur Forever) utilisée uniquement pour PROPOSER un choix quand plusieurs rôles sont
-- possibles ; jamais pour deviner la spé d'un joueur.
local Classes = {}
FSB.Classes = Classes

local HEAL, MAGIC, PHYS, TANK = "Soigneur", "Dégâts magiques", "Dégâts physiques", "Tank"

Classes.ROLES = {
    WARRIOR = { TANK, PHYS }, PALADIN = { HEAL, TANK, PHYS }, HUNTER = { PHYS }, ROGUE = { PHYS },
    PRIEST = { HEAL, MAGIC }, SHAMAN = { HEAL, MAGIC, PHYS }, MAGE = { MAGIC }, WARLOCK = { MAGIC },
    DRUID = { HEAL, TANK, PHYS, MAGIC }, DEATHKNIGHT = { TANK, PHYS }, MONK = { HEAL, TANK, PHYS },
    DEMONHUNTER = { TANK, PHYS }, EVOKER = { HEAL, MAGIC },
}

-- Rôles par spécialisation (id -> liste de noms de profils), à remplir d'après /fsb specs.
-- Une spé listée ici n'est jamais « ambiguë » si elle n'a qu'un rôle.
Classes.BY_SPEC = {}

-- Rôles possibles selon l'arbre de talents le plus investi (index d'onglet dans l'ordre Classic).
-- Connaissance du jeu, UNVERIFIED sur Forever : sert à proposer des choix, jamais à deviner.
local MAGIC = "Dégâts magiques"
local SH, FI, FR, AR = "Dégâts Ombre", "Dégâts Feu", "Dégâts Givre", "Dégâts Arcanes"
Classes.TREES = {
    WARRIOR = { { PHYS }, { PHYS }, { TANK } },
    PALADIN = { { HEAL }, { TANK }, { PHYS } },
    HUNTER = { { PHYS }, { PHYS }, { PHYS } },
    ROGUE = { { PHYS }, { PHYS }, { PHYS } },
    PRIEST = { { HEAL, "Dégâts Sacré" }, { HEAL, "Dégâts Sacré" }, { SH } },
    SHAMAN = { { MAGIC }, { PHYS }, { HEAL } },
    MAGE = { { AR }, { FI }, { FR } },
    WARLOCK = { { SH }, { MAGIC }, { FI } },
    DRUID = { { MAGIC }, { TANK, PHYS }, { HEAL } },
}
