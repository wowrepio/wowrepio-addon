local _, ns = ...

local partyTracker = ns:AddModule("partyTracker")
local channel = ns:GetModule("channel")
local util = ns:GetModule("util")

local lastTick = GetServerTime()
local partyStack = {} -- { name = { name=..., joined=..., lastSeenAt=... }}

local GRACE_PERIOD = 3 * 60

local function OnCharacterJoined(name, data)
    -- print("Character " .. name .. " (genderId: " .. data.genderId .. ", classId: " .. data.classId ..", raceId: " .. data.raceId .. ") joined party at " .. data.joined)
end

local function OnCharacterLeft(name, data)
    -- print("Character " .. name .. " (genderId: " .. data.genderId .. ", classId: " .. data.classId ..", raceId: " .. data.raceId .. ") left party at " .. lastTick .. ", and was in the party for " .. lastTick - data.joined .. "s")
end

local function updateParty()
    local partyUpdated = false
    local prefix
    lastTick = GetServerTime()

    if IsInRaid() then
        prefix = "raid"
    else
        prefix = "party"
    end
    
    -- Ensure existence of partyStack entity
    for i=1, GetNumGroupMembers() do
        local fullName, realm, unitExists = util:GetNameRealm(prefix .. i)
        -- print("fullName: " .. fullName)
        if fullName ~= "Unknown" and fullName ~= prefix .. i and unitExists then -- If the user identifier cannot be fetched then we just omit (usually it happens when its us in the party)
            local entryKey = util:GetCurrentRegion() .. "/" .. util:GetRealmSlug(realm) .. "/" .. fullName

            if partyStack[entryKey] ~= nil then -- Party member exists
                -- print("Member existed: " .. entryKey)
                partyStack[entryKey].lastSeenAt = lastTick

                if partyStack[entryKey].emittedLeftEvent then -- Character rejoined party
                    partyStack[entryKey].emittedJoinEvent = true
                    partyStack[entryKey].emittedLeftEvent = false

                    channel:SendEvent("WOWREPIO_PARTYSTACK_CHARACTER_JOINED", entryKey, partyStack[entryKey])
                end
            else
                -- print("Character new: " .. entryKey)

                local _, _, raceId = UnitRace(fullName)
                local _, _, classId = UnitClass(fullName)
                local genderId = util:GenderLookup(fullName)

                if raceId and classId and genderId then
                    partyStack[entryKey] = {
                        joined=lastTick, lastSeenAt=lastTick, 
                        emittedLeftEvent=false, emitedJoinEvent=false,
                        raceId=raceId, classId=classId, genderId=genderId,
                    }
                end
            end
        end
    end

    -- Emit events and clean up the partyStack entity
    for name, data in pairs(partyStack) do
        if lastTick - data.lastSeenAt > 0 and not data.emittedLeftEvent then -- Character has just left
            channel:SendEvent("WOWREPIO_PARTYSTACK_CHARACTER_LEFT", name, data)
            partyStack[name].emittedLeftEvent = true
        end

        if (lastTick - 1) <= data.joined and (lastTick+1) >= data.joined and not data.emittedJoinEvent then -- Character has just joined
            channel:SendEvent("WOWREPIO_PARTYSTACK_CHARACTER_JOINED", name, data)
            partyStack[name].emittedJoinEvent = true
        end 

        if lastTick - data.lastSeenAt > GRACE_PERIOD then -- The player was away for more than grace period 
            partyStack[name] = nil
        end
    end        
end

function partyTracker:GetData()
    updateParty()

    local d = {}
    for k, v in pairs(partyStack) do
        if lastTick - v.joined >= GRACE_PERIOD and lastTick - v.lastSeenAt <= GRACE_PERIOD then
            d[k] = v
        end
    end

    return d
end

function partyTracker:OnReady()
    channel:RegisterEvent("GROUP_ROSTER_UPDATE", updateParty)
    channel:RegisterEvent("WOWREPIO_READY", updateParty)
    channel:RegisterEvent("PLAYER_ENTERING_WORLD", updateParty)

    channel:RegisterEvent("WOWREPIO_PARTYSTACK_CHARACTER_LEFT", OnCharacterLeft)
    channel:RegisterEvent("WOWREPIO_PARTYSTACK_CHARACTER_JOINED", OnCharacterJoined)
end