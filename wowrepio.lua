local _, ns = ...

local ldb = LibStub("LibDataBroker-1.1")
local icon = LibStub("LibDBIcon-1.0")

local wowrepio = ns:AddModule("wowrepio")
local payload = ns:GetModule("payload")

function wowrepio:OnReady()
    print("Thank you for using " .. NORMAL_FONT_COLOR_CODE .. "wowrep.io! " .. RED_FONT_COLOR_CODE .. "<3")

    local ldbData = ldb:NewDataObject("wowrepio", {
        type="data source",
        text="wowrepio",
        icon = "Interface\\AddOns\\wowrepio\\wowrepio_Icon",
        OnClick = function() payload:Show() end,
        OnTooltipShow = function(tt) 
            tt:AddLine("wowrep.io")
        end,
    })

    icon:Register("wowrepio", ldbData, {hide=false})
end
