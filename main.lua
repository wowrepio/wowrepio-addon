local LibQTip = LibStub('LibQTip-1.0')
local wowrepio = CreateFrame("Frame")
wowrepio:RegisterEvent("ADDON_LOADED")

wowrepio:SetScript("OnEvent", function(self, event, ...)
    print("OnEvent: " .. event)

    wowrepio:OnLoad()
end)

local inspectedFriend = {};
local currentResult = {};
local CHARACTER_NAME_REGEX = "(.+), (%d+) (.+) (.+)"
local _FRIENDS_LIST_REALM = FRIENDS_LIST_REALM.."|r(.+)"
local tooltipLineLocked = false
local loaded = false
local tooltip = {};


print("========================================================================================================================================================================================================================================================================================================================================================================================================================================================================================================================================================================s");

local function getColorFor(value)
    print("getColorFor " .. tostring(value))
    local ranges = {
--        {item quality color id, min inclusive, max exclusive}
        {0, 0.0, 1.0},
        {1, 1.0, 2.0},
        {2, 2.0, 2.856},
        {3, 2.856, 3.57},
        {4, 3.57, 4.284},
        {5, 4.284, 4.75},
        {6, 4.75, 4.95},
        {8, 4.95, 5.01},
    }

    for i, range in ipairs(ranges) do
        local colorCodeId = range[1]
        local scoreMinInclusive = range[2]
        local scoreMaxExclusive = range[3]


        if value >= scoreMinInclusive and value < scoreMaxExclusive then
            local _, _, _, hex = GetItemQualityColor(colorCodeId)

            return "|c" .. hex
        end
    end
end

local function AddLines(tt,text)
    tt = tt.."|n"..text;

    return tt;
end

local function wowrepioString(offset)
    print("Wowrepio string enter")
    if not offset then
        offset = 2
    end

    local score = {
        factors = {
            communication = 0.0,
            teamplay = 1.5,
            skill = 3.5,
        },
        average = 4.5,
    }

    local text = NORMAL_FONT_COLOR_CODE .. "WowRep.io Score |r"
    text = text .. getColorFor(score.average) .. tostring(score.average) .. "|n"
    for k, v in pairs(score.factors) do
        for i=1,offset+1 do
            text = text.." "
        end

        text = text .. NORMAL_FONT_COLOR_CODE .. k .. "|r" .. ": ".. getColorFor(v) .. v .. "|r" .. "|n"
    end

    return text
end

function OnTooltipSetUnit(self, ...)
    print("OnTooltipSetUnit")
    local name, unit, guid, realm = self:GetUnit();
    if not unit then
        local mf = GetMouseFocus();
        if mf and mf.unit then
            unit = mf.unit;
        end
    end
    if unit and UnitIsPlayer(unit) then
        guid = UnitGUID(unit);
        name = UnitName(unit);
        if guid then
            local text = guid .. name;

            self:AddLine(wowrepioString(2))
        end
    end
end

-- Friend list tooltip
hooksecurefunc("FriendsFrameTooltip_SetLine",function(line, anchor, text, yOffset)
    if tooltipLineLocked then
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

        tooltipLineLocked = true
        FriendsFrameTooltip_SetLine(line, anchor, AddLines(text, wowrepioString(2)), yOffset)
        tooltipLineLocked = false
        return
    end
end);

local hooked = {};

local function HookApplicantButtons(buttons)
    for _, button in pairs(buttons) do
        if not hooked[button] then
            hooked[button] = true
            button:HookScript("OnEnter", OnEnter)
            button:HookScript("OnLeave", OnLeave)
        end
    end
end

local function GetFullName(parent, applicantID, memberIdx)
    local fullName = C_LFGList.GetApplicantMemberInfo(applicantID, memberIdx)
    if not fullName then
        return false
    end

    return true, fullName
end

function SetOwnerSafely(object, owner, anchor, offsetX, offsetY)
    if type(object) ~= "table" or type(object.GetOwner) ~= "function" then
        return
    end
    local currentOwner = object:GetOwner()
    if not currentOwner then
        object:SetOwner(owner, anchor, offsetX, offsetY)
        return true
    end
    offsetX, offsetY = offsetX or 0, offsetY or 0
    local currentAnchor, currentOffsetX, currentOffsetY = object:GetAnchorType()
    currentOffsetX, currentOffsetY = currentOffsetX or 0, currentOffsetY or 0
    if currentAnchor ~= anchor or (currentOffsetX ~= offsetX and abs(currentOffsetX - offsetX) > 0.01) or (currentOffsetY ~= offsetY and abs(currentOffsetY - offsetY) > 0.01) then
        object:SetOwner(owner, anchor, offsetX, offsetY)
        return true
    end
    return false, true
end

function OnEnter(self)
    local entry = C_LFGList.GetActiveEntryInfo()

    if entry then
        currentResult.activityID = entry.activityID
    end

    if not currentResult.activityID then
        return
    end

    if self.applicantID and self.Members then
        HookApplicantButtons(self.Members)
    elseif self.memberIdx then
        local fullNameAvailable, fullName = GetFullName(self, self:GetParent().applicantID, self.memberIdx)
        if fullNameAvailable then
            tooltip:AddLine(wowrepioString(0))
        else
            print("fullName not available: " .. tostring(currentResult))
        end
    end
end

function OnLeave(self)
    GameTooltip:Hide()
    print("Tooltip released and left")
end
--
function wowrepio:OnLoad()
    print("OnLoad")
    if loaded then
        print("OnLoad early returning")
        return
    end

    if LibQTip then
        print("LIBQTip present")
    else
        print("LIBQTip not present")
    end

    tooltip = GameTooltip
    tooltip:HookScript("OnTooltipSetUnit", OnTooltipSetUnit)

    print("OnLoad after, preparing hooks")

    print("Wowrepio:onLoad")

    -- lfg applicants - BY RAIDER.io
    for i=1, 14 do
        print("Hooking button " .. i)
        local button = _G["LFGListApplicationViewerScrollFrameButton" .. i]
        button:HookScript("OnEnter", OnEnter)
        button:HookScript("OnLeave", OnLeave)
    end

    -- allow lookup by all team members - BY RAIDER.IO
    do
        local f = _G.LFGListFrame.ApplicationViewer.UnempoweredCover
        f:EnableMouse(false)
        f:EnableMouseWheel(false)
        f:SetToplevel(false)
    end

    loaded = true
end

--function wowrepio:OnEvent(self, event, ...)
--    print("event: " .. tostring(event))
--end
--
--wowrepio:SetScript("OnEvent", wowrepio:OnEvent)