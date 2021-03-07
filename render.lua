local _, ns = ...

local render = ns:AddModule("render")
local util = ns:GetModule("util")

function render:Score(tooltip, score)
    if not tooltip then
        print(NORMAL_FONT_COLOR_CODE .. "[WowRep.io] " .. RED_FONT_COLOR_CODE .. "Error|r: " .. "could not render profile (tooltip is non-existing)")
        return
    end

    tooltip:AddLine(util:wowrepioString(0, score, IsModifierKeyDown()))
    tooltip:Show() -- Ensure tooltip is properly resized
end
