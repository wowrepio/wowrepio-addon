local _, ns = ...

local PARTY_GROUP_TYPE = 0
local RAID_GROUP_TYPE = 1

local payload = ns:AddModule("payload")
local util = ns:GetModule("util")

function payload:GetCurrentDate()
    return date("%H%M%d%m%Y")
end

function payload:GetReportingPlayer()
    return util:GetNameRealm("player")
end

function payload:GetPartyType()
    if util:IsInPartyGroup() or util:IsInInstanceGroup() then
        return PARTY_GROUP_TYPE
    elseif IsInRaid() then
        return RAID_GROUP_TYPE
    end

    return -1
end

function payload:OnReady() 
    print("Date: " .. payload:GetCurrentDate())
    print("Party type: " .. tostring(payload:GetPartyType()))
    print("Reporting player: " .. payload:GetReportingPlayer())
end
