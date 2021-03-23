local _, ns = ...

local tooltip = ns:AddModule("communityTooltip")
local util = ns:GetModule("util")
local db = ns:GetModule("db")
local render = ns:GetModule("render")

local hooked = {}

local function CanGetIdentifierFor(arg1, arg2)
    return not ((arg1 and arg1.clubType and arg1.clubType ~= Enum.ClubType.Guild and arg1.clubType ~= Enum.ClubType.Character) or not arg2)
end

local function OnEnter(self)
    local nameAndRealm
    local info

    if type(self.GetMemberInfo) == "function" then
        info = self:GetMemberInfo()
        nameAndRealm = info.name
    elseif type(self.cardInfo) == "table" then
        nameAndRealm = util:GetNameRealm(self.cardInfo.guildLeader)
    else
        return
    end

    if not CanGetIdentifierFor(info, nameAndRealm) then
        return
    end

    local ownerSet, ownerExisted, ownerSetSame = util:ClaimOwnership(GameTooltip, self, "ANCHOR_LEFT", 0, 0)
    local name, realm = util:GetNameRealm(nameAndRealm)
    if not realm then
        realm = GetRealmName()
        name = nameAndRealm
    end
    render:Score(GameTooltip, db:GetScore(ns.REGIONS[GetCurrentRegion()], util:GetRealmSlug(realm), name))

    if ownerSet and not ownerExisted and ownerSetSame then
        GameTooltip:Hide()
    end
end

local function OnLeave(_)
    GameTooltip:Hide()
end

local function OnRefreshApplyHooks()
    local hookables = {
        _G.CommunitiesFrame.MemberList.ListScrollFrame.buttons,
        _G.ClubFinderGuildFinderFrame.CommunityCards.ListScrollFrame.buttons,
        _G.ClubFinderGuildFinderFrame.PendingCommunityCards.ListScrollFrame.buttons,
        _G.ClubFinderGuildFinderFrame.GuildCards.Cards,
        _G.ClubFinderGuildFinderFrame.PendingGuildCards.Cards,
        _G.ClubFinderCommunityAndGuildFinderFrame.CommunityCards.ListScrollFrame.buttons,
        _G.ClubFinderCommunityAndGuildFinderFrame.PendingCommunityCards.ListScrollFrame.buttons,
        _G.ClubFinderCommunityAndGuildFinderFrame.GuildCards.Cards,
        _G.ClubFinderCommunityAndGuildFinderFrame.PendingGuildCards.Cards,
    }

    for _, buttons in pairs(hookables) do
        if buttons then
            local numButtons = 0
            for _, button in pairs(buttons) do
                numButtons = numButtons + 1
                if not hooked[button] then
                    hooked[button] = true
                    button:HookScript("OnEnter", OnEnter)
                    button:HookScript("OnLeave", OnLeave)
                    if type(button.OnEnter) == "function" then hooksecurefunc(button, "OnEnter", OnEnter) end
                    if type(button.OnLeave) == "function" then hooksecurefunc(button, "OnLeave", OnLeave) end
                end
            end
        end
    end

    return true
end

local function OnScroll()
    GameTooltip:Hide()
    util:ExecuteWidgetHandler(GetMouseFocus(), "OnEnter")
end

function tooltip:IsReady()
    return _G.CommunitiesFrame and _G.ClubFinderGuildFinderFrame and _G.ClubFinderCommunityAndGuildFinderFrame
end

local function Hook()
    local hookables = {
        { frame = _G.CommunitiesFrame.MemberList, callbacks = { ["RefreshLayout"] = OnRefreshApplyHooks, ["Update"] = OnScroll } },
        { frame = _G.ClubFinderGuildFinderFrame.CommunityCards, callbacks = { ["RefreshLayout"] = OnRefreshApplyHooks } },
        { frame = _G.ClubFinderGuildFinderFrame.CommunityCards.ListScrollFrame, callbacks = { ["update"] = OnScroll } },
        { frame = _G.ClubFinderGuildFinderFrame.PendingCommunityCards, callbacks = { ["RefreshLayout"] = OnRefreshApplyHooks } },
        { frame = _G.ClubFinderGuildFinderFrame.PendingCommunityCards.ListScrollFrame, callbacks = { ["update"] = OnScroll } },
        { frame = _G.ClubFinderGuildFinderFrame.GuildCards, callbacks = { ["RefreshLayout"] = OnRefreshApplyHooks } },
        { frame = _G.ClubFinderGuildFinderFrame.PendingGuildCards, callbacks = { ["RefreshLayout"] = OnRefreshApplyHooks } },
        { frame = _G.ClubFinderCommunityAndGuildFinderFrame.CommunityCards, callbacks = { ["RefreshLayout"] = OnRefreshApplyHooks } },
        { frame = _G.ClubFinderCommunityAndGuildFinderFrame.CommunityCards.ListScrollFrame, callbacks = { ["update"] = OnScroll } },
        { frame = _G.ClubFinderCommunityAndGuildFinderFrame.PendingCommunityCards, callbacks = { ["RefreshLayout"] = OnRefreshApplyHooks } },
        { frame = _G.ClubFinderCommunityAndGuildFinderFrame.PendingCommunityCards.ListScrollFrame, callbacks = { ["update"] = OnScroll } },
        { frame = _G.ClubFinderCommunityAndGuildFinderFrame.GuildCards, callbacks = { ["RefreshLayout"] = OnRefreshApplyHooks } },
        { frame = _G.ClubFinderCommunityAndGuildFinderFrame.PendingGuildCards, callbacks = { ["RefreshLayout"] = OnRefreshApplyHooks } },
    }

    for _, frameObj in pairs(hookables) do
        for eventName, callbackFunc in pairs(frameObj.callbacks) do
            hooksecurefunc(frameObj.frame, eventName, callbackFunc)
        end
    end
end

function tooltip:OnReady()
    Hook()
end
