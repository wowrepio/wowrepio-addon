local wowrepio = CreateFrame("Frame")
wowrepio:RegisterEvent("ADDON_LOADED")
wowrepio:RegisterEvent("PLAYER_LOGIN")
wowrepio:RegisterEvent("PLAYER_LOGOUT")
wowrepio:RegisterEvent("PLAYER_ENTERING_WORLD")

-- very nice addon from Phanx :) Thanks...
local inspectedFriend = {};
local CHARACTER_NAME_REGEX = "(.+), (%d+) (.+) (.+)"
local _FRIENDS_LIST_REALM = FRIENDS_LIST_REALM.."|r(.+)"
local tooltipLineLocked = false

print("========================================================================================================================================================================================================================================================================================================================================================================================================================================================================================================================================================================s");

local function getColorFor(value)
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

    for _, range in ipairs(ranges) do
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
    local text = NORMAL_FONT_COLOR_CODE.."WowRep.io Score " .. getColorFor(score.average) .. tostring(score.average) .. "|r|n"
    for k, v in pairs(score.factors) do
        for i=1,offset+1 do
            text = text.." "
        end

        text = text .. NORMAL_FONT_COLOR_CODE .. k .. "|r" .. ": ".. getColorFor(v) .. v .. "|r" .. "|n"
    end

    return text
end

-- normal on-screen tooltip
GameTooltip:HookScript("OnTooltipSetUnit", function(self, ...)
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
end)

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
