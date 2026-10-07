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
Verdict.DEFAULT_THRESHOLDS = { upgradeRel = 0.03, upgradeAbs = 1, otherMargin = 0.25 }

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
    return {
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
    if mine.upgrade then return { kind = "EQUIP", slot = mine.slot, fraction = mine.fraction } end

    for _, profile in ipairs(ctx.profiles) do
        if profile ~= ctx.active then
            local g = Gain(ctx, ctx.equipped, profile, ctx.canDualWield, adjust(profile))
            if g.upgrade then return { kind = "OFFSPEC", profile = profile.name } end
        end
    end
    return { kind = "SELL" }
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

    local better = {}
    for _, m in ipairs(ctx.members or {}) do
        local g = Gain(ctx, m.equipped, { weights = m.weights }, false, nil)
        local fit = SchoolFit(ctx.stats, ctx.active.weights, m.weights)
        if g.upgrade and (fit or g.fraction >= solo.fraction + Threshold("otherMargin")) then
            better[#better + 1] = m.name
        end
    end
    if #better > 0 then return { kind = "BETTER_OTHER", others = better, slot = solo.slot } end
    return { kind = "TAKE", slot = solo.slot }
end
