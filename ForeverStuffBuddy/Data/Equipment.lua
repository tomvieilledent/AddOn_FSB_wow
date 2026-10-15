local _, FSB = ...

-- Équipement utilisable par classe : référence Classic / Vanilla (UNVERIFIED sur Forever, le serveur a pu changer
-- certaines règles). Garde-fou en plus des lignes rouges du tooltip : sert quand le tooltip est illisible, pour
-- écarter un objet qu'une classe ne peut jamais porter, et pour les autres membres du groupe (tooltip inconnu).
-- Les compétences d'armes à apprendre chez un maître d'armes ne sont pas suivies : seul le tooltip le sait.
local Equipment = {}
FSB.Equipment = Equipment

-- Sous-classes d'armure (Enum.ItemArmorSubclass) et d'arme (Enum.ItemWeaponSubclass).
local CLOTH, LEATHER, MAIL, PLATE, SHIELD = 1, 2, 3, 4, 6
local AXE1, AXE2, BOW, GUN, MACE1, MACE2, POLEARM, SWORD1, SWORD2 = 0, 1, 2, 3, 4, 5, 6, 7, 8
local STAFF, FIST, GENERIC, DAGGER, THROWN, CROSSBOW, WAND, FISHING = 10, 13, 14, 15, 16, 18, 19, 20
local CLASS_ARMOR, CLASS_WEAPON = 4, 2

-- Armures : sous-classe -> niveau minimal (absent = jamais).
Equipment.ARMOR = {
    WARRIOR = { [CLOTH] = 1, [LEATHER] = 1, [MAIL] = 1, [PLATE] = 40, [SHIELD] = 1 },
    PALADIN = { [CLOTH] = 1, [LEATHER] = 1, [MAIL] = 1, [PLATE] = 40, [SHIELD] = 1 },
    HUNTER  = { [CLOTH] = 1, [LEATHER] = 1, [MAIL] = 40 },
    ROGUE   = { [CLOTH] = 1, [LEATHER] = 1 },
    PRIEST  = { [CLOTH] = 1 },
    MAGE    = { [CLOTH] = 1 },
    WARLOCK = { [CLOTH] = 1 },
    DRUID   = { [CLOTH] = 1, [LEATHER] = 1 },
    SHAMAN  = { [CLOTH] = 1, [LEATHER] = 1, [MAIL] = 40, [SHIELD] = 1 },
}

local function Set(list) local t = {}; for _, v in ipairs(list) do t[v] = true end; return t end

-- Armes (main droite, deux mains, distance). Le chaman a les haches/masses 2M (talent).
Equipment.WEAPONS = {
    WARRIOR = Set({ AXE1, MACE1, SWORD1, DAGGER, FIST, AXE2, MACE2, SWORD2, STAFF, POLEARM, BOW, GUN, CROSSBOW, THROWN }),
    PALADIN = Set({ AXE1, MACE1, SWORD1, AXE2, MACE2, SWORD2, POLEARM }),
    HUNTER  = Set({ AXE1, SWORD1, DAGGER, FIST, AXE2, SWORD2, STAFF, POLEARM, BOW, GUN, CROSSBOW }),
    ROGUE   = Set({ AXE1, MACE1, SWORD1, DAGGER, FIST, BOW, GUN, CROSSBOW, THROWN }),
    PRIEST  = Set({ MACE1, DAGGER, STAFF, WAND }),
    MAGE    = Set({ SWORD1, DAGGER, STAFF, WAND }),
    WARLOCK = Set({ SWORD1, DAGGER, STAFF, WAND }),
    DRUID   = Set({ MACE1, DAGGER, FIST, MACE2, STAFF }),
    SHAMAN  = Set({ AXE1, MACE1, DAGGER, FIST, STAFF, AXE2, MACE2 }),
}
local ANY_WEAPON = Set({ GENERIC, FISHING })

-- Arme en main gauche (ambidextrie). Pour le joueur, l'API CanDualWield fait foi ; ceci sert aux autres membres.
Equipment.DUAL_WIELD = { WARRIOR = true, HUNTER = true, ROGUE = true }

-- Objets dont le type n'est pas soumis à la règle d'armure (tout le monde les porte).
local NO_ARMOR_RULE = { INVTYPE_CLOAK = true, INVTYPE_FINGER = true, INVTYPE_NECK = true, INVTYPE_TRINKET = true,
    INVTYPE_HOLDABLE = true, INVTYPE_RELIC = true, INVTYPE_BODY = true, INVTYPE_TABARD = true }

-- false = la classe ne peut pas porter l'objet ; true = autorisé ; nil = aucune règle (classe ou type inconnus).
-- canDualWield : nil = valeur de la table DUAL_WIELD.
function Equipment.CanUse(classFile, level, itemClassID, subClassID, equipLoc, canDualWield)
    if not classFile or not itemClassID or not subClassID then return nil end
    level = level or 1
    if itemClassID == CLASS_ARMOR then
        local rules = Equipment.ARMOR[classFile]
        if not rules or NO_ARMOR_RULE[equipLoc] or subClassID == 0 or subClassID > SHIELD then return nil end
        local minLevel = rules[subClassID]
        return minLevel ~= nil and level >= minLevel
    end
    if itemClassID == CLASS_WEAPON then
        local rules = Equipment.WEAPONS[classFile]
        if not rules then return nil end
        if ANY_WEAPON[subClassID] then return true end
        if not rules[subClassID] then return false end
        if equipLoc == "INVTYPE_WEAPONOFFHAND" then
            if canDualWield == nil then canDualWield = Equipment.DUAL_WIELD[classFile] == true end
            return canDualWield
        end
        return true
    end
    return nil
end
