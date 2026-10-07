-- Ressources graphiques : luajit tests/assets.lua
package.path = "tests/?.lua;" .. package.path
local H = require("helpers")
local T = H.counter(); local check = T.check

local f = assert(io.open("ForeverStuffBook/Media/logo.tga", "rb"))
local header = f:read(18); local size = f:seek("end"); f:close()
local colorType, w, h, bpp = header:byte(3), header:byte(13) + header:byte(14) * 256, header:byte(15) + header:byte(16) * 256, header:byte(17)
local function pow2(n) return n > 0 and (n & (n - 1)) == 0 end
check("logo TGA non compressé 32 bits", colorType == 2 and bpp == 32)
check("logo TGA : dimensions puissances de 2", w == h and pow2(w) and w <= 512)
check("logo TGA : taille cohérente", size == 18 + w * h * 4 or size >= 18 + w * h * 4)

local function read(p) local h = assert(io.open(p)); local s = h:read("a"); h:close(); return s end
for _, toc in ipairs({ "ForeverStuffBook/ForeverStuffBook.toc", "ForeverStuffBook/ForeverStuffBook_Camelot.toc" }) do
    check(toc .. " : icône d'addon", read(toc):find("IconTexture: Interface\\AddOns\\ForeverStuffBook\\Media\\logo", 1, true))
end
check("la page d'accueil pointe sur le même fichier", read("ForeverStuffBook/UI/Settings.lua"):find("AddOns\\\\ForeverStuffBook\\\\Media\\\\logo", 1, true))
local png = assert(io.open("assets/logo.png", "rb")); local sig = png:read(8); png:close()
check("logo PNG pour CurseForge", sig == "\137PNG\r\n\26\n")
T.finish("ressources")
