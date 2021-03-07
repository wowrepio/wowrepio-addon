local _, ns = ...

local wowrepio = ns:AddModule("wowrepio")
local wowrepioFrame = CreateFrame("Frame")

function wowrepio:OnReady()
    print("Thank you for using " .. NORMAL_FONT_COLOR_CODE .. "wowrep.io! " .. RED_FONT_COLOR_CODE .. "<3")

    wowrepioFrame:RegisterEvent("CHALLENGE_MODE_START")
    wowrepioFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
end

wowrepioFrame:SetScript("OnEvent", function(self, event_name)
    if event_name == "CHALLENGE_MODE_START" then
        --print("Dungeon started")
    end

    if event_name == "CHALLENGE_MODE_COMPLETED" then
        --print("Dungeon finished")
    end
end)
