local _, ns = ...

local tooltip = ns:AddModule("gametooltip")
local db = ns:GetModule("db")
local render = ns:GetModule("render")
local util = ns:GetModule("util")

local function OnTooltipSetUnit(self, ...)
    local name, unit, guid, realm = self:GetUnit();
    if not unit then
        local mf = GetMouseFocus();
        if mf and mf.unit then
            unit = mf.unit;
        end
    end
    if unit and UnitIsPlayer(unit) then
        guid = UnitGUID(unit);
        name, realm = UnitName(unit);

        if not realm then
            realm = GetRealmName()
        end

        if guid then
            render:Score(GameTooltip, db:GetScore(util:GetCurrentRegion(), util:GetRealmSlug(realm), name))
        end
    end
end

function tooltip:OnReady()
    GameTooltip:HookScript("OnTooltipSetUnit", OnTooltipSetUnit)
end
