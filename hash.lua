local _, ns = ...

local hash = ns:AddModule("hash")

local P = 0x1F
local M = 0x3B9ACA09
--
---- https://cp-algorithms.com/string/string-hashing.html
function hash:ify(str)
    local v = 0

    local pp = 1
    for i = 1, #str do
        local c = str:sub(i,i)
        local cv = string.byte(c)

        v = (v + (cv - string.byte('a') + 1) * pp) % M
        pp = (pp * P) % M
    end

    return v
end