local _, ns = ...

local tooltip = ns:AddModule("grosterTooltip")
local util = ns:GetModule("util")
local render = ns:GetModule("render")
local db = ns:GetModule("db")

local function OnEnter(self)
    if not self.guildIndex then
        return
    end
    local fullName, _, _, _ = GetGuildRosterInfo(self.guildIndex)
    if not fullName then
        return
    end
    local ownerSet, ownerExisted, ownerSetSame = util:ClaimOwnership(GameTooltip, self)

    local name, realm, _ = util:GetNameRealm(fullName)
    if not realm then
        name = fullName
        realm = GetRealmName()
    end
    render:Score(GameTooltip, db:GetScore(ns.REGIONS[GetCurrentRegion()], util:GetRealmSlug(realm), name))

    if ownerSet and not ownerExisted and ownerSetSame then
        GameTooltip:Hide()
    end
end

local function OnLeave(self)
    if not self.guildIndex then
        return
    end
    GameTooltip:Hide()
end

local function OnScroll()
    GameTooltip:Hide()
    util:ExecuteWidgetHandler(GetMouseFocus(), "OnEnter")
end

function tooltip:IsReady()
    return _G.GuildFrame
end

function tooltip:OnReady()
    for i = 1, #GuildRosterContainer.buttons do
        local button = GuildRosterContainer.buttons[i]
        button:HookScript("OnEnter", OnEnter)
        button:HookScript("OnLeave", OnLeave)
    end
    hooksecurefunc(GuildRosterContainer, "update", OnScroll)
end
