local _, ns = ...

local friendTooltip = ns:AddModule("friendTooltip")
local util = ns:GetModule("util")
local db = ns:GetModule("db")

local inspectedFriend = {}
local _FRIENDS_LIST_REALM = FRIENDS_LIST_REALM.."|r(.+)"
local CHARACTER_NAME_REGEX = "(.+), (%d+) (.+) (.+)"

local function friendTooltip_SetLine(line, anchor, text, yOffset)
    if ns.tooltipLineLocked then
        return
    end

    if not text then
        return
    end

    local characterName = text:match(CHARACTER_NAME_REGEX)
    if characterName then
        inspectedFriend.name = characterName

        return
    end

    local realmName = text:match(_FRIENDS_LIST_REALM)
    if realmName then
        inspectedFriend.realmName = realmName

        ns.tooltipLineLocked = true
        FriendsFrameTooltip_SetLine(line, anchor, util:AddLines(text, util:wowrepioString(2, db:GetScore(util:GetCurrentRegion(), util:GetRealmSlug(inspectedFriend.realmName), inspectedFriend.name))), yOffset)
        ns.tooltipLineLocked = false
        return
    end
end

function friendTooltip:OnReady()
    hooksecurefunc("FriendsFrameTooltip_SetLine", friendTooltip_SetLine)
end
