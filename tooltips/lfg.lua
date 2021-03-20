local _, ns = ...

local lfgTooltip = ns:AddModule("lfgTooltip")
local util = ns:GetModule("util")
local db = ns:GetModule("db")
local render = ns:GetModule("render")
local hooked = {};

local function HookApplicantButtons(buttons)
    for _, button in pairs(buttons) do
        if not hooked[button] then
            hooked[button] = true
            button:HookScript("OnEnter", lfgTooltip_OnEnter)
            button:HookScript("OnLeave", lfgTooltip_OnLeave)
        end
    end
end

function lfgTooltip:GetFullName(parent, applicantID, memberIdx)
    local fullName = C_LFGList.GetApplicantMemberInfo(applicantID, memberIdx)
    if not fullName then
        return false
    end

    return true, fullName
end

local function lfgTooltip_GroupEntry(tooltip, resultID)
    local entry = C_LFGList.GetSearchResultInfo(resultID)
    local name, realm = util:GetNameRealm(entry.leaderName)

    render:Score(tooltip, db:GetScore(ns.REGIONS[GetCurrentRegion()], util:GetRealmSlug(realm), name))
end


function lfgTooltip_OnEnter(self)
    local entry = C_LFGList.GetActiveEntryInfo()

    if not entry or not entry.activityID then
        return
    end

    if self.applicantID and self.Members then
        HookApplicantButtons(self.Members)
    elseif self.memberIdx then
        local fullNameAvailable, fullName = lfgTooltip:GetFullName(self, self:GetParent().applicantID, self.memberIdx)
        if fullNameAvailable then
            local name, realm, _ = util:GetNameRealm(fullName)
            render:Score(GameTooltip, db:GetScore(util:GetCurrentRegion(), util:GetRealmSlug(realm, true), name))
        end
    end
end

function lfgTooltip_OnLeave(self)
    GameTooltip:Hide()
end

function lfgTooltip:OnReady()
    -- Leader or team member looking at applicants
    for i=1, 14 do
        local button = _G["LFGListApplicationViewerScrollFrameButton" .. i]
        button:HookScript("OnEnter", lfgTooltip_OnEnter)
        button:HookScript("OnLeave", lfgTooltip_OnLeave)
    end

    do
        local f = _G.LFGListFrame.ApplicationViewer.UnempoweredCover
        f:EnableMouse(false)
        f:EnableMouseWheel(false)
        f:SetToplevel(false)
    end

    -- Applicant browsing groups
    hooksecurefunc("LFGListUtil_SetSearchEntryTooltip", lfgTooltip_GroupEntry)
    for i = 1, 10 do
        local button = _G["LFGListSearchPanelScrollFrameButton" .. i]
        button:HookScript("OnLeave", lfgTooltip_OnLeave)
    end
end
