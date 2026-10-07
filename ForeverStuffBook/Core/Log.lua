local _, FSB = ...

-- Journal des hésitations : cas où FSB n'est pas sûr (analyse impossible, stats inconnues, verdict limite,
-- spé illisible...) ou que l'utilisateur signale. Stocké dans FSB.db.log (SavedVariables), borné,
-- dédoublonné par raison + objet. Exportable en texte (/fsb log) pour la mise à jour hebdomadaire.
local Log = {}
FSB.Log = Log

local MAX_ENTRIES = 300

local function Now()
    local clock = GetServerTime or time or (os and os.time)
    return clock and clock() or 0
end

local function Stamp(t)
    local fmt = date or (os and os.date)
    return fmt and fmt("%Y-%m-%d %H:%M", t) or tostring(t)
end

local function Store()
    if not FSB.db then return nil end
    FSB.db.log = FSB.db.log or {}
    return FSB.db.log
end

function Log.IsEnabled() return not (FSB.db and FSB.db.logDisabled) end

-- reason : code court ; data : { link, detail, verdict, global }. global = une seule entrée par raison.
function Log.Add(reason, data)
    local store = Store()
    if not store or not Log.IsEnabled() then return end
    data = data or {}
    local key = data.global and reason or (reason .. "|" .. tostring(data.link))
    for _, e in ipairs(store) do
        if e.key == key then
            e.count = e.count + 1; e.last = Now()
            if data.global then e.link = data.link end
            return
        end
    end
    store[#store + 1] = {
        key = key, reason = reason, link = data.link, detail = data.detail, verdict = data.verdict,
        mode = FSB.Context and FSB.Context.IsGroupMode() and "GROUPE" or "SOLO",
        profile = FSB.db.activeProfile, spec = FSB.Spec and FSB.Spec.Current and FSB.Spec.Current() or nil,
        first = Now(), last = Now(), count = 1,
    }
    if #store > MAX_ENTRIES then table.remove(store, 1) end
end

function Log.Count() return FSB.db and FSB.db.log and #FSB.db.log or 0 end

function Log.Clear() if FSB.db then FSB.db.log = {} end end

-- Texte exportable, une ligne par entrée.
function Log.Report()
    local lines = {}
    local build = FSB.build or ""
    lines[1] = ("FSB log | %s | %d entrée(s)"):format(build, Log.Count())
    for _, e in ipairs((FSB.db and FSB.db.log) or {}) do
        lines[#lines + 1] = ("%s | %s | x%d | %s | %s | profil=%s | spé=%s | verdict=%s | %s"):format(
            Stamp(e.last), e.reason, e.count, e.mode,
            tostring(e.link), tostring(e.profile), tostring(e.spec), tostring(e.verdict), tostring(e.detail or ""))
    end
    return table.concat(lines, "\n")
end
