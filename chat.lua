local _, ns = ...

local chat = ns:AddModule("chat")
local channel = ns:GetModule("channel")
local config = ns:GetModule("config")
local util = ns:GetModule("util")

local function OnDungeonFinished()
    if not config:IsEnabled("emitMessageAfterDungeon") or not (util:IsInPartyGroup() or util:IsInInstanceGroup()) then
        return
    end

    local chatChannel
    if util:IsInInstanceGroup() then
        chatChannel = "instance"
    elseif util:IsInPartyGroup() then
        chatChannel = "party"
    end

    print("[wowrep.io] If you would like to disable auto pitching, change it in settings using /wowrepio (chat channel selected: " .. chatChannel .. ")")
    SendChatMessage("[wowrep.io] Thanks for the run! Please review me with wowrep.io!", chatChannel)
end

function chat:OnReady()
    channel:RegisterEvent("CHALLENGE_MODE_COMPLETED", OnDungeonFinished)
end