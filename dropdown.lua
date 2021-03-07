local _, ns = ...

local dropdown = ns:AddModule("dropdown")
local util = ns:GetModule("util")

local copyUrlPopup = {
    id = "WOWREPIO_COPY_URL",
    text = "%s",
    button2 = CLOSE,
    hasEditBox = true,
    hasWideEditBox = true,
    editBoxWidth = 350,
    preferredIndex = 3,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnShow = function(self)
        self:SetWidth(420)
        local editBox = _G[self:GetName() .. "WideEditBox"] or _G[self:GetName() .. "EditBox"]
        editBox:SetText(self.text.text_arg2)
        editBox:SetFocus()
        editBox:HighlightText(false)
        local button = _G[self:GetName() .. "Button2"]
        button:ClearAllPoints()
        button:SetWidth(200)
        button:SetPoint("CENTER", editBox, "CENTER", 0, -30)
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    OnHide = nil,
    OnAccept = nil,
    OnCancel = nil
}

local function GetNameRealmForDropDown(bdropdown)
    local unit = bdropdown.unit
    local bnetIDAccount = bdropdown.bnetIDAccount
    local menuList = bdropdown.menuList
    local quickJoinMember = bdropdown.quickJoinMember
    local quickJoinButton = bdropdown.quickJoinButton
    local tempName, tempRealm = bdropdown.name, bdropdown.server
    local name, realm

    if not name and UnitExists(unit) then
        if UnitIsPlayer(unit) then
            name, realm = util:GetNameRealm(unit)
        end

        return name, realm
    end

    if not name and bnetIDAccount then
        local fullName, _, _ = util:GetNameRealmForBNetFriend(bnetIDAccount)
        if fullName then
            name, realm = util:GetNameRealm(fullName)
        end

        return name, realm
    end

    if not name and menuList then
        for i = 1, #menuList do
            local whisperButton = menuList[i]
            if whisperButton and (whisperButton.text == _G.WHISPER_LEADER or whisperButton.text == _G.WHISPER) then
                name, realm = util:GetNameRealm(whisperButton.arg1)
                break
            end
        end
    end

    if not name and (quickJoinMember or quickJoinButton) then
        local memberInfo = quickJoinMember or quickJoinButton.Members[1]
        if memberInfo.playerLink then
            name, realm = util:GetNameRealmFromPlayerLink(memberInfo.playerLink)
        end
    end

    if not name and tempName then
        name, realm = util:GetNameRealm(tempName, tempRealm)
    end

    if not name or not realm then
        return
    end

    return name, realm
end


local selectedName, selectedRealm
local unitOptions

local function ShouldShowOptionsFor(dd)
    local validTypes = {
        ARENAENEMY = true,
        BN_FRIEND = true,
        CHAT_ROSTER = true,
        COMMUNITIES_GUILD_MEMBER = true,
        COMMUNITIES_WOW_MEMBER = true,
        FOCUS = true,
        FRIEND = true,
        GUILD = true,
        GUILD_OFFLINE = true,
        PARTY = true,
        PLAYER = true,
        RAID = true,
        RAID_PLAYER = true,
        SELF = true,
        TARGET = true,
        WORLD_STATE_SCORE = true,
    }

    return (dd == LFGListFrameDropDown or (type(dd.which) == "string" and validTypes[dd.which] ))
end

local function OnToggle(dd, event, options)
    if event == "OnShow" then
        if not ShouldShowOptionsFor(dd) then
            return
        end

        selectedName, selectedRealm = GetNameRealmForDropDown(dd)
        if not selectedName then
            return
        end
        if not options[1] then
            for i = 1, #unitOptions do
                options[i] = unitOptions[i]
            end
            return true
        end
    elseif event == "OnHide" then
        if options[1] then
            for i = #options, 1, -1 do
                options[i] = nil
            end
            return true
        end
    end
end

local LibDropDownExtension = LibStub and LibStub:GetLibrary("LibDropDownExtension-1.0", true)

function dropdown:IsReady()
    return LibDropDownExtension
end

function dropdown:OnReady()
    unitOptions = {
        {
            text = "Copy WowRep.io URL",
            func = function()
                local url = format("https://wowrep.io/characters/%s/%s/%s?utm_source=addon", util:GetCurrentRegion(), util:GetRealmSlug(selectedRealm), selectedName)
                StaticPopup_Show(copyUrlPopup.id, format("%s (%s)", selectedName, selectedRealm), url)
            end
        }
    }
    LibDropDownExtension:RegisterEvent("OnShow OnHide", OnToggle, 1, dropdown)
    StaticPopupDialogs[copyUrlPopup.id] = copyUrlPopup
end
