local addonName, ns = ...

local ldb = LibStub("LibDataBroker-1.1")
local icon = LibStub("LibDBIcon-1.0")
local config = ns:AddModule("config")
local payload = ns:GetModule("payload")
local frame

local defaultConfig = {
    emitMessageAfterDungeon = false,

    MinimapButtonSettings = { hide = false },
}

SLASH_WOWREPIO1 = "/wowrepio"
SLASH_WOWREPIO2 = "/wowrep"
SLASH_WOWREPIO3 = "/repio"
SlashCmdList["WOWREPIO"] = function(msg)
    -- print("msg: " .. msg)
    if msg == "payload" then
        payload:Show()
    else
        for i=1,3 do -- One very smart lady told me that its buggy and it indeed is buggy, this is why we call it a few times!
            config:OpenConfig()
        end
    end
end

local function Setup()
    if not wowrepioConfig then
        wowrepioConfig = defaultConfig
    end

    if not wowrepioConfig.MinimapButtonSettings then
        wowrepioConfig.MinimapButtonSettings = { hide = false }
    end

    frame = CreateFrame("Frame", nil, InterfaceOptionsFramePanelContainer)
    frame.name = addonName

    frame.title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", 16, -16)
    frame.title:SetText("wowrep.io") -- we can pretty print here with dot between 'wowrep' and 'io' :)

    frame.printOutAfterFinishedDungeon = CreateFrame("CheckButton", "wowrepioOption1", frame, "InterfaceOptionsCheckButtonTemplate")
    frame.printOutAfterFinishedDungeon.label = _G[frame.printOutAfterFinishedDungeon:GetName() .. "Text"]
    frame.printOutAfterFinishedDungeon.label:SetText("Pitch after dungeon")
    frame.printOutAfterFinishedDungeon:SetScript("OnClick", function(self)
        wowrepioConfig.emitMessageAfterDungeon = self:GetChecked()

        if wowrepioConfig.emitMessageAfterDungeon then
            PlaySound(856)
        else
            PlaySound(857)
        end
    end)
    frame.printOutAfterFinishedDungeon.tooltipRequirement = "wowrep.io will print out a message after finished dungeon"
    frame.printOutAfterFinishedDungeon:SetChecked(wowrepioConfig.emitMessageAfterDungeon)
    frame.printOutAfterFinishedDungeon:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", -2, -16)

    local ldbData = ldb:NewDataObject("wowrepio", {
        type="data source",
        text="wowrepio",
        icon = "Interface\\AddOns\\wowrepio\\wowrepio_Icon",
        OnClick = function() payload:Show() end,
        OnTooltipShow = function(tt) 
            tt:AddLine("wowrep.io")
        end,
    })

    icon:Register("wowrepio", ldbData, wowrepioConfig.MinimapButtonSettings)

    InterfaceOptions_AddCategory(frame)
end

function config:IsEnabled(option)
    return wowrepioConfig[option]
end

function config:OpenConfig()
    InterfaceOptionsFrame_OpenToCategory(addonName)
end

function config:OnReady()
    Setup()
end
