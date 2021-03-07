local _, ns = ...

local db = ns:AddModule("db")
local hash = ns:GetModule("hash")

function db:GetScore(region, realm, name)
    if not region or not realm or not name then
        return null
    end
    return ns.DATABASE[hash:ify(region .. "/" .. realm .. "/" .. name)]
end