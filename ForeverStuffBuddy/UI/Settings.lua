local _, FSB = ...

-- Interface /fsb : fenêtre sobre (fond anthracite, filets bronze, accent or mat) avec quatre pages : Accueil, Stats
-- (temporaire), Commandes, Réglages. Construite à la première ouverture. Aucun modèle de bouton Blizzard : tout est
-- dessiné avec des textures unies, pour un rendu homogène. Toute erreur de construction est interceptée : l'interface
-- ne doit jamais casser l'analyse.
local UI = {}
FSB.UI = UI

-- Page « Stats » temporaire : passer à false une fois les poids équilibrés.
UI.SHOW_STATS_TAB = true

local WIDTH, HEIGHT = 560, 520
local WHITE = "Interface\\Buttons\\WHITE8X8"
local LOGO = "Interface\\AddOns\\ForeverStuffBook\\Media\\logo"

-- Palette : anthracite, bronze, or mat ; couleurs de verdict sobres (aucun violet).
local C = {
    bg      = { 0.055, 0.058, 0.066, 0.97 },
    header  = { 0.040, 0.042, 0.048, 1 },
    card    = { 0.095, 0.100, 0.112, 1 },
    stripe  = { 0.080, 0.084, 0.094, 1 },
    border  = { 0.30, 0.25, 0.16, 1 },
    line    = { 0.20, 0.19, 0.17, 1 },
    gold    = { 0.89, 0.74, 0.40 },
    text    = { 0.88, 0.88, 0.90 },
    dim     = { 0.60, 0.61, 0.65 },
    green   = { 0.38, 0.76, 0.46 },
    blue    = { 0.40, 0.62, 0.92 },
    amber   = { 0.93, 0.74, 0.30 },
    red     = { 0.84, 0.36, 0.33 },
}

local frame
local texts = {}       -- { widget, clé } : réécrits au changement de langue
local pages, tabs = {}, {}
local statRows = {}

---------------------------------------------------------------------------------------------
-- Briques de base
---------------------------------------------------------------------------------------------

local function Fill(tex, c, alpha)
    if tex.SetColorTexture then
        tex:SetColorTexture(c[1], c[2], c[3], alpha or c[4] or 1)
    else
        tex:SetTexture(WHITE)
        tex:SetVertexColor(c[1], c[2], c[3], alpha or c[4] or 1)
    end
end

local function Rect(parent, c, layer)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    Fill(t, c)
    return t
end

local function Background(f, c)
    local t = Rect(f, c, "BACKGROUND")
    t:SetAllPoints()
    f.bg = t
    return t
end

-- Filet de 1 px autour d'un cadre.
local function Border(f, c)
    local edges = {}
    for i = 1, 4 do edges[i] = Rect(f, c, "BORDER") end
    edges[1]:SetPoint("TOPLEFT"); edges[1]:SetPoint("TOPRIGHT"); edges[1]:SetHeight(1)
    edges[2]:SetPoint("BOTTOMLEFT"); edges[2]:SetPoint("BOTTOMRIGHT"); edges[2]:SetHeight(1)
    edges[3]:SetPoint("TOPLEFT"); edges[3]:SetPoint("BOTTOMLEFT"); edges[3]:SetWidth(1)
    edges[4]:SetPoint("TOPRIGHT"); edges[4]:SetPoint("BOTTOMRIGHT"); edges[4]:SetWidth(1)
    f.edges = edges
    return edges
end

local function SetBorderColor(f, c)
    for _, e in ipairs(f.edges or {}) do Fill(e, c) end
end

local function Translate(text, widget)
    if text ~= "" and FSB.L[text] ~= nil then
        texts[#texts + 1] = { widget = widget, key = text }
        return FSB.L[text]
    end
    return text
end

-- Texte : clé de FSB.L (traduite et mémorisée) ou texte brut. Police inexistante : repli sur une police sûre.
local function Text(parent, text, x, y, font, color, width, justify)
    local ok, fs = pcall(parent.CreateFontString, parent, nil, "OVERLAY", font or "GameFontHighlightSmall")
    if not ok or not fs then fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") end
    if x then fs:SetPoint("TOPLEFT", x, y) end
    local c = color or C.text
    fs:SetTextColor(c[1], c[2], c[3])
    fs:SetJustifyH(justify or "LEFT")
    if width then
        fs:SetWidth(width)
        if fs.SetJustifyV then fs:SetJustifyV("TOP") end
    end
    fs:SetText(Translate(text, fs))
    return fs
end

local function Divider(parent, x, y, width)
    local t = Rect(parent, C.line, "ARTWORK")
    t:SetPoint("TOPLEFT", x, y); t:SetSize(width, 1)
    return t
end

local function Section(parent, key, y, width)
    Text(parent, key, 0, y, "GameFontNormal", C.gold)
    Divider(parent, 0, y - 20, width)
end

-- Bouton plat. active/inactive gérés par SetActive ; survol : filet doré.
local function FlatButton(parent, key, w, h, onClick, opts)
    opts = opts or {}
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)
    Background(b, opts.flat and C.header or C.card)
    Border(b, opts.flat and C.header or C.line)
    local label = Text(b, key, 0, 0, opts.font or "GameFontHighlight", C.text, w, "CENTER")
    label:ClearAllPoints(); label:SetPoint("CENTER", 0, 0)
    b.label = label
    b.active = false
    local function paint(hover)
        if b.active then
            Fill(b.bg, C.card); SetBorderColor(b, C.gold)
            label:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
        else
            Fill(b.bg, hover and C.card or (opts.flat and C.header or C.card))
            SetBorderColor(b, hover and C.border or (opts.flat and C.header or C.line))
            label:SetTextColor(C.text[1], C.text[2], C.text[3])
        end
    end
    b.Paint = paint
    function b:SetActive(on) self.active = on and true or false; paint(false) end
    b:SetScript("OnEnter", function() paint(true) end)
    b:SetScript("OnLeave", function() paint(false) end)
    b:SetScript("OnClick", onClick)
    paint(false)
    return b
end

-- Case à cocher dessinée : carré filet + coche or.
local function Checkbox(parent, key, x, y, get, set)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(260, 22); b:SetPoint("TOPLEFT", x, y)
    local box = CreateFrame("Frame", nil, b)
    box:SetSize(16, 16); box:SetPoint("LEFT", 0, 0)
    Background(box, C.header); Border(box, C.border)
    local tick = Rect(box, C.gold, "ARTWORK")
    tick:SetPoint("TOPLEFT", 4, -4); tick:SetPoint("BOTTOMRIGHT", -4, 4)
    local label = Text(b, key, 26, -4, "GameFontHighlight", C.text)
    b.Refresh = function() if get() then tick:Show() else tick:Hide() end end
    b:SetScript("OnClick", function() set(not get()); b.Refresh() end)
    b:SetScript("OnEnter", function() SetBorderColor(box, C.gold) end)
    b:SetScript("OnLeave", function() SetBorderColor(box, C.border) end)
    return b
end

-- Fenêtre de base commune (principale, rôle, texte).
local function NewPanel(name, w, h)
    local f = CreateFrame("Frame", name, UIParent)
    f:SetSize(w, h); f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    Background(f, C.bg); Border(f, C.border)
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    tinsert(UISpecialFrames, name) -- se ferme avec Échap
    return f
end

local function CloseButton(f)
    local b = CreateFrame("Button", nil, f)
    b:SetSize(26, 26); b:SetPoint("TOPRIGHT", -8, -8)
    local x = Text(b, "X", 0, 0, "GameFontNormal", C.dim, 26, "CENTER")
    x:ClearAllPoints(); x:SetPoint("CENTER")
    b:SetScript("OnEnter", function() x:SetTextColor(C.gold[1], C.gold[2], C.gold[3]) end)
    b:SetScript("OnLeave", function() x:SetTextColor(C.dim[1], C.dim[2], C.dim[3]) end)
    b:SetScript("OnClick", function() f:Hide() end)
    return b
end

---------------------------------------------------------------------------------------------
-- Pages
---------------------------------------------------------------------------------------------

local PAGE_W = WIDTH - 40

-- Carte de verdict : liseré coloré à gauche, titre, description.
local function VerdictCard(parent, x, y, w, accent, titleKey, descKey)
    local card = CreateFrame("Frame", nil, parent)
    card:SetSize(w, 62); card:SetPoint("TOPLEFT", x, y)
    Background(card, C.card)
    local bar = Rect(card, accent, "ARTWORK")
    bar:SetPoint("TOPLEFT"); bar:SetPoint("BOTTOMLEFT"); bar:SetWidth(3)
    Text(card, titleKey, 14, -10, "GameFontNormal", accent, w - 24)
    Text(card, descKey, 14, -30, "GameFontHighlightSmall", C.dim, w - 24)
    return card
end

local function BuildHome(page)
    local logo = page:CreateTexture(nil, "ARTWORK")
    logo:SetSize(116, 116); logo:SetPoint("TOPLEFT", 0, 0)
    logo:SetTexture(LOGO)

    Text(page, "HOME_TAGLINE", 134, -4, "GameFontNormalLarge", C.gold, PAGE_W - 134)
    Text(page, "HOME_DESC", 134, -32, "GameFontHighlight", C.text, PAGE_W - 134)

    local w = (PAGE_W - 12) / 2
    VerdictCard(page, 0, -132, w, C.green, "HOME_V1", "HOME_V1_DESC")
    VerdictCard(page, w + 12, -132, w, C.blue, "HOME_V2", "HOME_V2_DESC")
    VerdictCard(page, 0, -204, w, C.amber, "HOME_V3", "HOME_V3_DESC")
    VerdictCard(page, w + 12, -204, w, C.red, "HOME_V4", "HOME_V4_DESC")

    Text(page, "HOME_NOTE", 0, -284, "GameFontHighlightSmall", C.dim, PAGE_W)
    Divider(page, 0, -340, PAGE_W)
    Text(page, "HOME_CREDITS", 0, -352, "GameFontNormalSmall", C.gold, 300)
end

-- Poids indicatifs (lecture seule) du profil actif : deux colonnes, lignes alternées.
local function BuildStats(page)
    page.title = Text(page, "", 0, 0, "GameFontNormal", C.gold, PAGE_W)
    Text(page, "UI_STATS_NOTE", 0, -20, "GameFontHighlightSmall", C.dim, PAGE_W)
    local colW, rowH = (PAGE_W - 16) / 2, 21
    for i, s in ipairs(FSB.Stats.KEYS) do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        local x, y = col * (colW + 16), -46 - row * rowH
        local line = CreateFrame("Frame", nil, page)
        line:SetSize(colW, rowH); line:SetPoint("TOPLEFT", x, y)
        if row % 2 == 0 then Background(line, C.stripe) end
        local name = Text(line, FSB.Stats.Label(s.key), 8, -4, "GameFontHighlightSmall", C.text, colW - 60)
        if name.SetWordWrap then name:SetWordWrap(false) end
        local value = Text(line, "", colW - 52, -4, "GameFontNormalSmall", C.gold, 44, "RIGHT")
        statRows[#statRows + 1] = { key = s.key, name = name, value = value }
    end
    local bottom = -46 - math.ceil(#FSB.Stats.KEYS / 2) * rowH - 12
    local all = FlatButton(page, "UI_ALL_PROFILES", 220, 26, function()
        FSB.Utils.Report(FSB.Profiles.WeightLines(true))
    end)
    all:SetPoint("TOPLEFT", 0, bottom)
end

-- Liste des commandes : commande en or, description en gris.
local function BuildCommands(page)
    Section(page, "DEV_COMMANDS", 0, PAGE_W)
    page.rows = {}
    for i = 1, 18 do
        local y = -32 - (i - 1) * 19
        page.rows[i] = {
            cmd = Text(page, "", 0, y, "GameFontNormalSmall", C.gold, 190),
            desc = Text(page, "", 196, y, "GameFontHighlightSmall", C.dim, PAGE_W - 196),
        }
    end
    Text(page, "DEV_OPEN", 0, -32 - 15 * 19 - 8, "GameFontHighlightSmall", C.dim, PAGE_W)
end

local function BuildSettings(page)
    Section(page, "UI_SECTION_CHAR", 0, PAGE_W)
    local card = CreateFrame("Frame", nil, page)
    card:SetSize(PAGE_W, 54); card:SetPoint("TOPLEFT", 0, -32)
    Background(card, C.card)
    local bar = Rect(card, C.gold, "ARTWORK")
    bar:SetPoint("TOPLEFT"); bar:SetPoint("BOTTOMLEFT"); bar:SetWidth(3)
    page.status = Text(card, "", 16, -19, "GameFontHighlight", C.text, PAGE_W - 170)
    local role = FlatButton(card, "UI_PICK_ROLE", 130, 28, function() UI.ShowRolePicker(true) end)
    role:SetPoint("TOPRIGHT", -12, -13)

    Section(page, "UI_SECTION_DISPLAY", -100, PAGE_W)
    page.enabled = Checkbox(page, "UI_ENABLED", 0, -132,
        function() return FSB.db.enabled end, function(v) FSB.db.enabled = v end)
    local function display(name)
        return function() return FSB.db.display[name] ~= false end,
            function(v) FSB.db.display[name] = v end
    end
    page.icons = Checkbox(page, "UI_ICONS", 0, -158, display("icons"))
    page.details = Checkbox(page, "UI_DETAILS", 0, -184, display("details"))

    Section(page, "UI_SECTION_GROUP", -216, PAGE_W)
    page.fairness = Checkbox(page, "UI_FAIRNESS", 0, -248,
        function() return FSB.db.lootFairness ~= false end,
        function(v) FSB.db.lootFairness = v; FSB.Analyzer.InvalidateGroup() end)

    Section(page, "UI_LANGUAGE", -286, PAGE_W)
    page.langFR = FlatButton(page, "Français", 130, 28, function() FSB.SetLanguage("frFR") end)
    page.langFR:SetPoint("TOPLEFT", 0, -320)
    page.langEN = FlatButton(page, "English", 130, 28, function() FSB.SetLanguage("enUS") end)
    page.langEN:SetPoint("TOPLEFT", 138, -320)
end

---------------------------------------------------------------------------------------------
-- Rafraîchissement
---------------------------------------------------------------------------------------------

function UI.Refresh()
    if not frame then return end
    local s = pages.settings
    if s then
        s.status:SetText(FSB.Spec.Label())
        s.enabled.Refresh(); s.icons.Refresh(); s.details.Refresh(); s.fairness.Refresh()
        s.langFR:SetActive(FSB.language == "frFR"); s.langEN:SetActive(FSB.language == "enUS")
    end
    frame.version:SetText("v" .. FSB.Utils.AddonVersion(FSB.name or "ForeverStuffBook"))
    if pages.stats then
        local active = FSB.Profiles.GetActive()
        pages.stats.title:SetText(FSB.L.POIDS_TITLE:format(FSB.Profiles.DisplayName(active.name)))
        for _, row in ipairs(statRows) do
            row.name:SetText(FSB.Stats.Label(row.key))
            row.value:SetText(active.weights[row.key] and tostring(active.weights[row.key]) or "-")
        end
    end
    if pages.commands then
        local i = 0
        for _, line in ipairs(FSB.L.HELP) do
            local cmd, desc = line:match("^(/fsb[^:]-)%s*:%s*(.+)$")
            i = i + 1
            local row = pages.commands.rows[i]
            if row then
                row.cmd:SetText(cmd or line); row.desc:SetText(desc or "")
                row.cmd:Show(); row.desc:Show()
            end
        end
        for j = i + 1, #pages.commands.rows do
            pages.commands.rows[j].cmd:Hide(); pages.commands.rows[j].desc:Hide()
        end
    end
end

-- Changement de langue : tous les textes enregistrés sont réécrits.
function UI.Retranslate()
    for _, t in ipairs(texts) do t.widget:SetText(FSB.L[t.key]) end
    UI.Refresh()
end

---------------------------------------------------------------------------------------------
-- Fenêtre principale
---------------------------------------------------------------------------------------------

local function ShowPage(index)
    for i, entry in ipairs(tabs) do
        if i == index then entry.page:Show() else entry.page:Hide() end
        entry.button:SetActive(i == index)
    end
    UI.Refresh()
end

local function Build()
    frame = NewPanel("FSBSettingsFrame", WIDTH, HEIGHT)

    -- En-tête : logo, nom, accroche, version.
    local head = CreateFrame("Frame", nil, frame)
    head:SetPoint("TOPLEFT", 1, -1); head:SetPoint("TOPRIGHT", -1, -1); head:SetHeight(70)
    Background(head, C.header)
    local logo = head:CreateTexture(nil, "ARTWORK")
    logo:SetSize(48, 48); logo:SetPoint("TOPLEFT", 16, -11); logo:SetTexture(LOGO)
    Text(head, "UI_TITLE", 74, -14, "GameFontNormalLarge", C.gold, 330)
    Text(head, "HOME_TAGLINE", 74, -40, "GameFontHighlightSmall", C.dim, 330)
    frame.version = Text(head, "", WIDTH - 150, -20, "GameFontDisableSmall", C.dim, 100, "RIGHT")
    CloseButton(frame)
    Divider(frame, 1, -71, WIDTH - 2)

    -- Onglets : texte seul, soulignement or sur la page active.
    local defs = {
        { key = "UI_TAB_HOME", build = BuildHome, name = "home" },
        { key = "UI_TAB_STATS", build = BuildStats, name = "stats", temporary = true },
        { key = "UI_TAB_DEV", build = BuildCommands, name = "commands" },
        { key = "UI_TAB_GENERAL", build = BuildSettings, name = "settings" },
    }
    local x = 16
    for _, def in ipairs(defs) do
        if not def.temporary or UI.SHOW_STATS_TAB then
            local index = #tabs + 1
            local page = CreateFrame("Frame", nil, frame)
            page:SetPoint("TOPLEFT", 20, -124); page:SetPoint("BOTTOMRIGHT", -20, 16)
            def.build(page)
            pages[def.name] = page
            local button = FlatButton(frame, def.key, 104, 30, function() ShowPage(index) end, { flat = true })
            button:SetPoint("TOPLEFT", x, -76)
            tabs[index] = { page = page, button = button }
            x = x + 108
        end
    end
    Divider(frame, 1, -106, WIDTH - 2)
    ShowPage(1)
    frame:Hide()
end

function UI.Toggle()
    local ok, err = pcall(function()
        if not frame then Build() end
        if frame:IsShown() then frame:Hide() else UI.Refresh(); frame:Show() end
    end)
    if not ok then FSB.Utils.Print("UI : " .. tostring(err)) end
end

---------------------------------------------------------------------------------------------
-- Question de rôle : proposée seulement quand la spé détectée a plusieurs rôles possibles.
---------------------------------------------------------------------------------------------

local roleFrame
function UI.ShowRolePicker()
    local ok, err = pcall(function()
        local specID = FSB.Spec.Current()
        if not specID then return end
        local choices = FSB.Spec.Choices(specID)
        if #choices < 2 then return end
        local info = FSB.Spec.Info(specID)
        if not roleFrame then
            roleFrame = NewPanel("FSBRoleFrame", 330, 200)
            roleFrame:ClearAllPoints(); roleFrame:SetPoint("CENTER", 0, 140)
            roleFrame.title = Text(roleFrame, "", 20, -18, "GameFontNormalLarge", C.gold, 290)
            roleFrame.note = Text(roleFrame, "ROLE_PICK_NOTE", 20, -46, "GameFontHighlightSmall", C.dim, 290)
            CloseButton(roleFrame)
            roleFrame.buttons = {}
        end
        roleFrame:SetHeight(100 + #choices * 40)
        roleFrame.title:SetText(FSB.L.ROLE_PICK_TITLE:format((info and info.name) or "?"))
        for _, b in ipairs(roleFrame.buttons) do b:Hide() end
        for i, p in ipairs(choices) do
            local b = roleFrame.buttons[i]
            if not b then
                b = FlatButton(roleFrame, "", 290, 32, nil)
                roleFrame.buttons[i] = b
            end
            b:SetPoint("TOPLEFT", 20, -80 - (i - 1) * 40)
            b.label:SetText(FSB.Profiles.DisplayName(p.name))
            b:SetScript("OnClick", function()
                FSB.Spec.Choose(p.name)
                roleFrame:Hide()
                UI.Refresh()
            end)
            b:SetActive(FSB.db.activeProfile == p.name)
            b:Show()
        end
        roleFrame:Show()
    end)
    if not ok then FSB.Utils.Print("UI : " .. tostring(err)) end
end

---------------------------------------------------------------------------------------------
-- Fenêtre de texte à copier (journal, diagnostics, aide).
---------------------------------------------------------------------------------------------

local logFrame
function UI.ShowText(text)
    local ok, err = pcall(function()
        if not logFrame then
            logFrame = NewPanel("FSBLogFrame", 620, 420)
            Text(logFrame, "COPY_TITLE", 20, -16, "GameFontNormal", C.gold, 520)
            CloseButton(logFrame)
            Divider(logFrame, 20, -40, 580)
            local scroll = CreateFrame("ScrollFrame", "FSBLogScroll", logFrame, "UIPanelScrollFrameTemplate")
            scroll:SetPoint("TOPLEFT", 20, -52); scroll:SetPoint("BOTTOMRIGHT", -36, 16)
            local edit = CreateFrame("EditBox", nil, scroll)
            edit:SetMultiLine(true); edit:SetAutoFocus(false); edit:SetFontObject("ChatFontNormal")
            edit:SetWidth(560)
            edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            scroll:SetScrollChild(edit)
            logFrame.edit = edit
        end
        logFrame.edit:SetText(text)
        logFrame:Show()
        logFrame.edit:SetFocus(); logFrame.edit:HighlightText()
    end)
    if not ok then FSB.Utils.Print("UI : " .. tostring(err)) end
end

UI.ShowLog = UI.ShowText
