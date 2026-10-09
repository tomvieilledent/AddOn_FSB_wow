local _, FSB = ...

-- Verdicts. Les scores restent internes ; seuls le type de verdict et des détails sortent.
local Verdict = {}
FSB.Verdict = Verdict

-- Seuils configurables (FSB.db.thresholds, surchargeables champ par champ) :
--  upgradeRel  : gain minimal relatif au score de l'objet remplacé (0.03 = +3 %)
--  upgradeAbs  : gain minimal absolu (évite les "upgrades" négligeables sur emplacement vide)
--  otherMargin : en groupe, un autre joueur doit gagner au moins cette part de la valeur de
--                l'objet de PLUS que moi pour déclencher "MEILLEUR POUR UN AUTRE" (0.25 = 25 points
--                de pourcentage de la valeur de l'objet). Évite le verdict pour une petite différence.
--  lootPenalty : équité en donjon. Le seuil d'un autre membre varie de lootPenalty (8 points) par objet d'équipement
--                d'écart avec moi (déjà reçus dans l'instance), borné entre minBar et maxBar. Un joueur déjà servi doit
--                justifier un plus gros upgrade, sans être exclu ; si c'est moi le plus servi, le seuil baisse.
Verdict.DEFAULT_THRESHOLDS = { upgradeRel = 0.03, upgradeAbs = 1, otherMargin = 0.25, lootPenalty = 0.08,
    minBar = 0.05, maxBar = 0.60 }

local function Threshold(name)
    local custom = FSB.db and FSB.db.thresholds
    return (custom and custom[name]) or Verdict.DEFAULT_THRESHOLDS[name]
end

function Verdict.IsUpgrade(delta, replacedScore)
    if not delta then return false end
    return delta >= Threshold("upgradeAbs") and delta >= Threshold("upgradeRel") * math.max(replacedScore or 0, 0)
end

-- Gain d'un profil pour l'objet. Retourne { upgrade = bool, fraction = gain/valeur de l'objet, slot = n }.
local function Gain(ctx, equipped, profile, canDualWield, adjust)
    local delta, slot, replaced = FSB.Optimizer.Evaluate(
        ctx.equipLoc, ctx.stats, equipped, profile.weights, canDualWield, adjust)
    local newScore = FSB.ScoreEngine.Score(ctx.stats, profile.weights)
    -- Cas limite : le gain est proche du seuil d'upgrade (entre 50 % et 150 % du minimum requis).
    local close = false
    if delta then
        local need = math.max(Threshold("upgradeAbs"), Threshold("upgradeRel") * math.max(replaced or 0, 0))
        close = delta >= need * 0.5 and delta < need * 1.5
    end
    return {
        close = close,
        upgrade = Verdict.IsUpgrade(delta, replaced),
        fraction = (delta and newScore > 0) and delta / newScore or 0,
        slot = slot,
    }
end

-- ctx : { equipLoc, stats, equipped, canDualWield, profiles, active, adjustFor(profile) -> adjust(slot) }
-- Retourne { kind = "EQUIP" | "OFFSPEC" | "SELL", profile = nom (OFFSPEC), slot, fraction }.
function Verdict.Solo(ctx)
    local function adjust(profile) return ctx.adjustFor and ctx.adjustFor(profile) or nil end
    local mine = Gain(ctx, ctx.equipped, ctx.active, ctx.canDualWield, adjust(ctx.active))
    if mine.upgrade then return { kind = "EQUIP", slot = mine.slot, fraction = mine.fraction, close = mine.close } end

    for _, profile in ipairs(ctx.profiles) do
        if profile ~= ctx.active then
            local g = Gain(ctx, ctx.equipped, profile, ctx.canDualWield, adjust(profile))
            if g.upgrade then return { kind = "OFFSPEC", profile = profile.name } end
        end
    end
    return { kind = "SELL", close = mine.close }
end

-- Objet « fait pour » un membre : il porte un bonus d'école que le profil de ce membre valorise et pas
-- le mien (ex. dégâts Givre pour un mage Givre alors que je soigne).
local function SchoolFit(stats, myWeights, theirWeights)
    for _, key in ipairs(FSB.Stats.SCHOOL_KEYS) do
        if (stats[key] or 0) > 0 and (theirWeights[key] or 0) > 0 and (myWeights[key] or 0) <= 0 then return true end
    end
    return false
end

-- Mode groupe : mêmes règles personnelles, plus la comparaison avec les membres connus.
-- ctx.members : { { name, weights, equipped } } (uniquement des données certaines).
-- Retourne { kind = "TAKE" | "BETTER_OTHER" | "OFFSPEC" | "CUPI", profile, others = {noms} }.
function Verdict.Group(ctx)
    local solo = Verdict.Solo(ctx)
    if solo.kind == "OFFSPEC" then return solo end
    if solo.kind == "SELL" then return { kind = "CUPI" } end

    local fair = not (FSB.db and FSB.db.lootFairness == false)
    local penalty = fair and Threshold("lootPenalty") or 0
    local better, served = {}, {}
    for _, m in ipairs(ctx.members or {}) do
        local g = Gain(ctx, m.equipped, { weights = m.weights }, false, nil)
        local fit = SchoolFit(ctx.stats, ctx.active.weights, m.weights)
        local diff = (m.loot or 0) - (ctx.myLoot or 0)
        local margin = Threshold("otherMargin")
        local bar = margin + penalty * diff
        if bar > Threshold("maxBar") then bar = math.max(Threshold("maxBar"), margin) end -- le malus n'excède pas le plafond
        if bar < Threshold("minBar") then bar = math.min(Threshold("minBar"), margin) end
        -- Bonus d'école : suffit d'un upgrade, sauf si le joueur a déjà été plus servi que moi.
        local need = fit and ((diff > 0 and penalty * diff) or -1) or bar
        if g.upgrade and g.fraction >= solo.fraction + need then
            better[#better + 1] = m.name
            if (m.loot or 0) > 0 then served[#served + 1] = ("%s (%d)"):format(m.name, m.loot) end
        end
    end
    if #better > 0 then return { kind = "BETTER_OTHER", others = better, served = served, slot = solo.slot } end
    return { kind = "TAKE", slot = solo.slot }
end
