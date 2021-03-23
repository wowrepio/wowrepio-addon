local _, ns = ...

local partyTracker = ns:AddModule("partyTracker")
local channel = ns:GetModule("channel")
local util = ns:GetModule("util")

local lastTick
local partyStack = {} -- { name = { name=..., joined=..., lastSeenAt=... }}

local GRACE_PERIOD = 10 * 60

local function OnCharacterJoined(name, data)
    print("Character " .. name .. " (class: " .. data.class ..", race: " .. data.race .. ") joined party at " .. data.joined)
end

local function OnCharacterLeft(name, data)
    print("Character " .. name .. " (class: " .. data.class ..", race: " .. data.race .. ") left party at " .. lastTick .. ", and was in the party for " .. lastTick - data.joined .. "s")
end

local function updateParty()
    local partyUpdated = false
    local prefix
    lastTick = time()

    if IsInRaid() then
        prefix = "raid"
    else
        prefix = "party"
    end
    
    -- Ensure existence of partyStack entity
    for i=1, GetNumGroupMembers() do
        local fullName, realm, unitExists = util:GetNameRealm(prefix .. i)

        if fullName ~= prefix .. i and unitExists then -- If the user identifier cannot be fetched then we just omit (usually it happens when its us in the party)
            local entryKey = util:GetCurrentRegion() .. "/" .. util:GetRealmSlug(realm) .. "/" .. fullName

            if partyStack[entryKey] ~= nil then -- Party member exists
                partyStack[entryKey].lastSeenAt = lastTick
            else
                local _, race = UnitRace(fullName)
                local _, class, _ = UnitClass(fullName)

                partyStack[entryKey] = {
                    joined=lastTick, lastSeenAt=lastTick, 
                    emittedLeftEvent=false, emitedJoinEvent=false,
                    race=race, class=class,
                }
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

function partyTracker:OnReady()
    channel:RegisterEvent("GROUP_ROSTER_UPDATE", updateParty)
    channel:RegisterEvent("WOWREPIO_READY", updateParty)

    channel:RegisterEvent("WOWREPIO_PARTYSTACK_CHARACTER_LEFT", OnCharacterLeft)
    channel:RegisterEvent("WOWREPIO_PARTYSTACK_CHARACTER_JOINED", OnCharacterJoined)
end