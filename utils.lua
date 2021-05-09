local _, ns = ...
local type = type
local table_insert = table.insert
local string_find = string.find
local string_sub = string.sub
local string_upper = string.upper
local string_format = string.format
local string_len = string.len
local assert = assert
local pcall = pcall
local tonumber = tonumber
local tostring = tostring
local pairs = pairs
local math_floor = math.floor
-- global (api) functions defined by wow
local strsplit = strsplit
local C_BattleNet = C_BattleNet
local UnitIsPlayer = UnitIsPlayer
local UnitExists = UnitExists
local abs = abs
local ExtractLinkData = ExtractLinkData
local UnitSex = UnitSex
local format = format
local GetNumGroupMembers = GetNumGroupMembers
local GetCurrentRegion = GetCurrentRegion
local GetNormalizedRealmName = GetNormalizedRealmName
local LinkUtil = LinkUtil
local UnitName = UnitName
local BNGetFriendIndex = BNGetFriendIndex
-- global constants defined by wow
local NORMAL_FONT_COLOR_CODE = NORMAL_FONT_COLOR_CODE
local BNET_CLIENT_WOW = BNET_CLIENT_WOW
local WOW_PROJECT_CLASSIC = WOW_PROJECT_CLASSIC
local MAX_BOSS_FRAMES = MAX_BOSS_FRAMES

function string:wowrepio_Split(delimiter)
    local result = { }
    local from  = 1
    local delim_from, delim_to = string_find( self, delimiter, from  )
    while delim_from do
        table_insert( result, string_sub( self, from , delim_from-1 ) )
        from  = delim_to + 1
        delim_from, delim_to = string_find( self, delimiter, from  )
    end
    table_insert( result, string_sub( self, from  ) )
    return result
end

local util = ns:AddModule("util")
local realms = ns.REALMS;

function util:GenderLookup(unitName)
    local g = UnitSex(unitName)
    local sexToIdLookupTable = {3, 0, 1}
    
    return sexToIdLookupTable[g]
end

function util:WowrepioLink(region, realm, name)
    assert(region and realm and name, "util:WowrepioLink needs region, realm and name to be provided")

    return format("https://wowrep.io/characters/%s/%s/%s", region, realm, name)
end

function util:IsInPartyGroup()
    return GetNumGroupMembers(LE_PARTY_CATEGORY_HOME) > 0
end

function util:IsInInstanceGroup()
    return GetNumGroupMembers(LE_PARTY_CATEGORY_INSTANCE) > 0
end

function util:GetCurrentRegion()
    local regionId = GetCurrentRegion()

    return ns.REGIONS[regionId]
end

function util:GetRealmSlug(realm)
    assert(realm, "util:GetRealmSlug requires a realm to be passed")
    
    local realmSlug = realms[realm] or realms[realm:gsub("%s+", "")]
    return realmSlug or realm
end

local unitIdentifiers = {
    ["mouseover"] = true,
    ["player"] = true,
    ["target"] = true,
    ["focus"] = true,
    ["pet"] = true,
    ["vehicle"] = true,
}

do
    for i=1,40 do
        unitIdentifiers["raid" .. i] = true
        unitIdentifiers["raidpet" .. i] = true
        unitIdentifiers["nameplate" .. i] = true
    end

    for i=1,4 do
        unitIdentifiers["party" .. i] = true
        unitIdentifiers["partypet" .. i] = true
    end

    for i=1,5 do
        unitIdentifiers["arena" .. i] = true
        unitIdentifiers["arenapet" .. i] = true
    end

    for i=1, MAX_BOSS_FRAMES do
        unitIdentifiers["boss" .. i] = true
    end

    for k,_ in pairs(unitIdentifiers) do
        unitIdentifiers[k .. "target"] = true
    end
end

-- Can be called with isUnit("raid14"), IsUnit("party1"))
function util:IsUnit(identifier)
    if identifier:find("-", nil, true) then
        return false, false
    end

    -- if it exists in unitIdentifiers, it's a valid unit name (like party1 or raid20)
    if not unitIdentifiers[identifier] then
        return false, false
    end

    return UnitExists(identifier), UnitIsPlayer(identifier)
end

function util:GetNameRealm(characterOrUnitName, fallBackRealmName)
    if type(characterOrUnitName) ~= "string" then
        return
    end

    local characterName, characterRealm
    local unitExists, unitIsPlayer = util:IsUnit(characterOrUnitName)
    -- examples when arg1 is something like raid14 or party2
    if unitExists then
        if unitIsPlayer then
            characterName, characterRealm = UnitName(characterOrUnitName)
            characterRealm = characterRealm ~= "" and characterRealm or GetNormalizedRealmName()
        end

        return characterName, characterRealm
    end

    if characterOrUnitName:find("-", nil, true) then
        local nameTable = characterOrUnitName:wowrepio_Split("-")
        characterName = nameTable[1]
        characterRealm = nameTable[2]
    else
        characterName = characterOrUnitName -- assume this is the name
    end

    if not characterRealm or characterRealm == "" then
        if type(fallBackRealmName) == "string" and fallBackRealmName ~= "" then
            characterRealm = fallBackRealmName
        else
            characterRealm = GetNormalizedRealmName() -- assume they are on our realm
        end
    end

    return characterName, characterRealm
end

function util:ExecuteWidgetHandler(object, handler, ...)
    if type(object) ~= "table" or type(object.GetScript) ~= "function" then
        return false
    end
    local func = object:GetScript(handler)
    if type(func) ~= "function" then
        return
    end
    if not pcall(func, object, ...) then
        return false
    end
    return true
end

function util:ClaimOwnership(object, owner, anchor, offsetX, offsetY)
    if not anchor then
        anchor = "ANCHOR_TOPLEFT"
    end

    if not offsetX then
        offsetX = 0
    end

    if not offsetY then
        offsetY = 0
    end

    if type(object) ~= "table" or type(object.GetOwner) ~= "function" then
        return
    end
    local currentOwner = object:GetOwner()
    if not currentOwner then
        object:SetOwner(owner, anchor, offsetX, offsetY)
        return true, false, true
    end
    offsetX, offsetY = offsetX or 0, offsetY or 0
    local currentAnchor, currentOffsetX, currentOffsetY = object:GetAnchorType()
    currentOffsetX, currentOffsetY = currentOffsetX or 0, currentOffsetY or 0
    if currentAnchor ~= anchor or (currentOffsetX ~= offsetX and abs(currentOffsetX - offsetX) > 0.01) or (currentOffsetY ~= offsetY and abs(currentOffsetY - offsetY) > 0.01) then
        object:SetOwner(owner, anchor, offsetX, offsetY)
        return true, true, true
    end
    return false, true, currentOwner == owner
end

local function colorShade(hexColor, perc)
    local r = tonumber(hexColor:sub(1,2), 16)
    local g = tonumber(hexColor:sub(3,4), 16)
    local b = tonumber(hexColor:sub(5,6), 16)


    r = r * (perc/100);
    g = g * (perc/100);
    b = b * (perc/100);

    if r > 255 then
        r = 255
    end

    if r<0 then
        r = 0
    end

    if g > 255 then
        g = 255
    end
    if g<0 then
        g = 0
    end

    if b > 255 then
        b = 255
    end

    if b<0 then
        b = 0
    end

    local rr = string_format("%x", math_floor(r))
    local gg = string_format("%x", math_floor(g))
    local bb = string_format("%x", math_floor(b))

    if string_len(rr) == 1 then
        rr = "0" .. rr
    end

    if string_len(gg) == 1 then
        gg = "0" .. gg
    end

    if string_len(bb) == 1 then
        bb = "0" .. bb
    end

    return rr .. gg .. bb
end

function util:GetNameRealmFromPlayerLink(playerLink)
    local linkString = LinkUtil.SplitLink(playerLink)
    local linkType, linkData = ExtractLinkData(linkString)
    if linkType == "player" then
        return util:GetNameRealm(linkData)
    elseif linkType == "BNplayer" then
        local _, bnetIDAccount = strsplit(":", linkData)
        if bnetIDAccount then
            bnetIDAccount = tonumber(bnetIDAccount)
        end
        if bnetIDAccount then
            local fullName, _  = util:GetNameRealmForBnetFriend(bnetIDAccount)
            local name, realm = util:GetNameRealm(fullName)
            return name, realm
        end
    end
end

function util:getColorFor(value)
    local perc
    local colorBase
    local k

    if value >= 3 then
        colorBase = "109110"
        k = value - 3
        perc = (100+(100-(k*50)))*((5/(k+1)))
    else
        colorBase = "911010"
        k = value
        perc = (100+((k-1)*50*k/0.9))*(k/1)
    end


    return "|c00" .. colorShade(colorBase, perc)
end

function util:GetNameRealmForBNetFriend(bnetIDAccount)
    local index = BNGetFriendIndex(bnetIDAccount)
    if not index then
        return
    end

    for i = 1, C_BattleNet.GetFriendNumGameAccounts(index), 1 do
        local info = C_BattleNet.GetFriendGameAccountInfo(index, i)
        if info and info.clientProgram == BNET_CLIENT_WOW and (not info.wowProjectID or info.wowProjectID ~= WOW_PROJECT_CLASSIC) then
            if info.realmName then
                info.characterName = info.characterName .. "-" .. info.realmName:gsub("%s+", "")
            end
            return info.characterName
        end
    end
end

function util:AddLines(tt,text)
    tt = tt.."|n"..text;

    return tt;
end

function util:wowrepioString(offset, score, beLong)
    local text = NORMAL_FONT_COLOR_CODE .. "WowRep.io Score |r"

    if not offset then
        offset = 2
    end

    if not score then
        return text .. "|c007F7F7Fnot rated|r"
    end

    text = text .. util:getColorFor(score.average) .. tostring(score.average) .. "|n"
    if beLong then
        for k, v in pairs(score.factors) do
            for i=1,offset+1 do
                text = text.." "
            end

            text = text .. NORMAL_FONT_COLOR_CODE .. string_upper(string_sub(k, 1,1)) .. string_sub(k, 2, -1) .. "|r" .. ": ".. util:getColorFor(v) .. v .. "|r" .. "|n"
        end
    end

    return text
end
