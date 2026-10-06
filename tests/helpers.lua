-- Utilitaires de test : charge les modules dans un espace FSB isolé.
local print = print
local H = {}

function H.load(files)
    local FSB = {}
    for _, f in ipairs(files) do assert(loadfile("ForeverStuffBook/" .. f .. ".lua"))("FSB", FSB) end
    return FSB
end

function H.counter()
    local c = { total = 0, fails = 0 }
    function c.check(name, cond)
        c.total = c.total + 1
        if not cond then c.fails = c.fails + 1; print("ECHEC: " .. name) end
    end
    function c.finish(label)
        print(("%s : %d/%d tests OK"):format(label, c.total - c.fails, c.total))
        os.exit(c.fails == 0 and 0 or 1)
    end
    return c
end

return H
