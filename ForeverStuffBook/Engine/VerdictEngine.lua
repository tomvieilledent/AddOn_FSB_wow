local _, FSB = ...

-- Verdict solo. Les scores restent internes ; seul le type de verdict sort.
local Verdict = {}
FSB.Verdict = Verdict

-- Seuils configurables (FSB.db.thresholds si présent) :
--  upgradeRel : gain minimal relatif au score de l'objet remplacé (0.03 = +3 %)
--  upgradeAbs : gain minimal absolu (évite les "upgrades" négligeables sur emplacement vide)
Verdict.DEFAULT_THRESHOLDS = { upgradeRel = 0.03, upgradeAbs = 1 }

local function Thresholds()
    return (FSB.db and FSB.db.thresholds) or Verdict.DEFAULT_THRESHOLDS
end

function Verdict.IsUpgrade(delta, replacedScore)
    if not delta then return false end
    local t = Thresholds()
    return delta >= t.upgradeAbs and delta >= t.upgradeRel * math.max(replacedScore or 0, 0)
end

-- ctx : { equipLoc, stats, equipped, canDualWield, profiles, active }
-- Retourne { kind = "EQUIP" | "OFFSPEC" | "SELL", profile = nom (OFFSPEC) }.
function Verdict.Solo(ctx)
    local Evaluate = FSB.Optimizer.Evaluate
    local delta, _, replaced = Evaluate(ctx.equipLoc, ctx.stats, ctx.equipped, ctx.active.weights, ctx.canDualWield)
    if Verdict.IsUpgrade(delta, replaced) then return { kind = "EQUIP" } end

    for _, profile in ipairs(ctx.profiles) do
        if profile ~= ctx.active then
            local d, _, r = Evaluate(ctx.equipLoc, ctx.stats, ctx.equipped, profile.weights, ctx.canDualWield)
            if Verdict.IsUpgrade(d, r) then return { kind = "OFFSPEC", profile = profile.name } end
        end
    end
    return { kind = "SELL" }
end
