local ns = select(2, ...) ---@type ns @The addon namespace.

-- module.lua (ns)
-- dependencies: none
do

    ---@type Module<string, Module>
    local modules = {}
    local moduleIndex = 0

    ---@class Module
    -- private properties for internal use only
    ---@field private id string @Required and unique string to identify the module.
    ---@field private index number @Automatically assigned a number based on the creation order.
    ---@field private loaded boolean @Flag indicates if the module is loaded.
    ---@field private enabled boolean @Flag indicates if the module is enabled.
    ---@field private dependencies string[] @List over dependencies before we can Load the module.
    -- private functions that should never be called
    ---@field private SetLoaded function @Internal function should not be called manually.
    ---@field private Load function @Internal function should not be called manually.
    ---@field private SetEnabled function @Internal function should not be called manually.
    -- protected functions that can be called but should never be overridden
    ---@field protected IsLoaded function @Internal function, can be called but do not override.
    ---@field protected IsEnabled function @Internal function, can be called but do not override.
    ---@field protected Enable function @Internal function, can be called but do not override.
    ---@field protected Disable function @Internal function, can be called but do not override.
    ---@field protected SetDependencies function @Internal function, can be called but do not override.
    ---@field protected HasDependencies function @Internal function, can be called but do not override.
    ---@field protected GetDependencies function @Internal function, can be called but do not override. Returns a table using the same order as the dependencies table. Returns the modules or nil depending if they are available or not.
    -- public functions that can be overridden
    ---@field public CanLoad function @If it returns true the module will be loaded, otherwise postponed for later. Override to define your modules load criteria that have to be met before loading.
    ---@field public OnLoad function @Once the module loads this function is executed. Use this to setup further logic for your module. The args provided are the module references as described in the dependencies table.
    ---@field public OnEnable function @This function is executed when the module is set to enabled state. Use this to setup and prepare.
    ---@field public OnDisable function @This function is executed when the module is set to disabled state. Use this for cleanup purposes.

    ---@type Module
    local module = {}

    ---@return nil
    function module:SetLoaded(state)
        self.loaded = state
    end

    ---@return boolean
    function module:Load()
        if not self:CanLoad() then
            return false
        end
        self:SetLoaded(true)
        self:OnLoad(unpack(self:GetDependencies()))
        return true
    end

    ---@return nil
    function module:SetEnabled(state)
        self.enabled = state
    end

    ---@return boolean
    function module:IsLoaded()
        return self.loaded
    end

    ---@return boolean
    function module:IsEnabled()
        return self.enabled
    end

    ---@return boolean
    function module:Enable()
        if self:IsEnabled() then
            return false
        end
        self:SetEnabled(true)
        self:OnEnable()
        return true
    end

    ---@return boolean
    function module:Disable()
        if not self:IsEnabled() then
            return false
        end
        self:SetEnabled(false)
        self:OnDisable()
        return true
    end

    ---@return nil
    function module:SetDependencies(dependencies)
        self.dependencies = dependencies
    end

    ---@return boolean
    function module:HasDependencies()
        if type(self.dependencies) == "string" then
            local m = modules[self.dependencies]
            return m and m:IsLoaded()
        end
        if type(self.dependencies) == "table" then
            for _, id in ipairs(self.dependencies) do
                local m = modules[id]
                if not m or not m:IsLoaded() then
                    return false
                end
            end
        end
        return true
    end

    ---@return Module[]
    function module:GetDependencies()
        local temp = {}
        local index = 0
        if type(self.dependencies) == "string" then
            index = index + 1
            temp[index] = modules[self.dependencies]
        end
        if type(self.dependencies) == "table" then
            for _, id in ipairs(self.dependencies) do
                index = index + 1
                temp[index] = modules[id]
            end
        end
        return temp
    end

    ---@return boolean
    function module:CanLoad()
        return not self:IsLoaded()
    end

    ---@vararg Module
    ---@return nil
    function module:OnLoad(...)
        self:Enable()
    end

    ---@return nil
    function module:OnEnable()
    end

    ---@return nil
    function module:OnDisable()
    end

    ---@param id string @Unique module ID reference.
    ---@param data Module @Optional table with properties to copy into the newly created module.
    function ns:NewModule(id, data)
        assert(type(id) == "string", "wowrep.io Module expects NewModule(id[, data]) where id is a string, data is optional table.")
        assert(not modules[id], "wowrep.io Module expects NewModule(id[, data]) where id is a string, that is unique and not already taken.")
        ---@type Module
        local m = {}
        for k, v in pairs(module) do
            m[k] = v
        end
        moduleIndex = moduleIndex + 1
        m.index = moduleIndex
        m.id = id
        m:SetLoaded(false)
        m:SetEnabled(false)
        m:SetDependencies()
        if type(data) == "table" then
            for k, v in pairs(data) do
                m[k] = v
            end
        end
        modules[id] = m
        return m
    end

    ---@param a Module
    ---@param b Module
    local function SortModules(a, b)
        return a.index < b.index
    end

    ---@return Module[]
    function ns:GetModules()
        local ordered = {}
        local index = 0
        for _, module in pairs(modules) do
            index = index + 1
            ordered[index] = module
        end
        table.sort(ordered, SortModules)
        return ordered
    end

    ---@param id string @Unique module ID reference.
    ---@param silent boolean @Ommit to throw if module doesn't exists.
    function ns:GetModule(id, silent)
        assert(type(id) == "string", "wowrep.io Module expects GetModule(id) where id is a string.")
        for _, module in pairs(modules) do
            if module.id == id then
                if not module:IsLoaded() and module:CanLoad() then
                    module:Load()
                end
                return module
            end
        end
        assert(silent, "wowrep.io Module expects GetModule(id) where id is a string, and the module must exists, or the silent param must be set to avoid this throw.")
    end
end


local wowrepio = CreateFrame("Frame")
wowrepio:RegisterEvent("ADDON_LOADED")

wowrepio:SetScript("OnEvent", function(self, event, ...)
    print("OnEvent: " .. event)

    wowrepio:OnLoad()
end)

ns.inspectedFriend = {};
ns.tooltipLineLocked = false
local currentResult = {};
local CHARACTER_NAME_REGEX = "(.+), (%d+) (.+) (.+)"
local _FRIENDS_LIST_REALM = FRIENDS_LIST_REALM.."|r(.+)"
local loaded = false
local tooltip = {};

do
    local util = ns:NewModule("util")

    function util:getColorFor(value)
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

    function util:AddLines(tt,text)
        tt = tt.."|n"..text;

        return tt;
    end

    function util:wowrepioString(offset)
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
        text = text .. util:getColorFor(score.average) .. tostring(score.average) .. "|n"
        for k, v in pairs(score.factors) do
            for i=1,offset+1 do
                text = text.." "
            end

            text = text .. NORMAL_FONT_COLOR_CODE .. k .. "|r" .. ": ".. util:getColorFor(v) .. v .. "|r" .. "|n"
        end

        return text
    end
end

function OnTooltipSetUnit(self, ...)
    local util = ns:GetModule("util")

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

            self:AddLine(util:wowrepioString(2))
        end
    end
end

-- Friend list tooltip
--hooksecurefunc("FriendsFrameTooltip_SetLine", function(line, anchor, text, yOffset)
--    local util = ns:GetModule("util")
--
--    if tooltipLineLocked then
--        return
--    end
--
--    if not text then
--        return
--    end
--
--    local characterName = text:match(CHARACTER_NAME_REGEX)
--    if characterName then
--        inspectedFriend.name = characterName
--
--        return
--    end
--
--    local realmName = text:match(_FRIENDS_LIST_REALM)
--    if realmName then
--        inspectedFriend.realmName = realmName
--
--        tooltipLineLocked = true
--        FriendsFrameTooltip_SetLine(line, anchor, util:AddLines(text, util:wowrepioString(2)), yOffset)
--        tooltipLineLocked = false
--        return
--    end
--end);

do
    local friendTooltip = ns:NewModule("friendTooltip")
    local util = ns:GetModule("util")

    local function friendTooltip_SetLine(line, anchor, text, yOffset)
        if ns.tooltipLineLocked then
            return
        end

        if not text then
            return
        end

        local characterName = text:match(CHARACTER_NAME_REGEX)
        if characterName then
            ns.inspectedFriend.name = characterName

            return
        end

        local realmName = text:match(_FRIENDS_LIST_REALM)
        if realmName then
            ns.inspectedFriend.realmName = realmName

            ns.tooltipLineLocked = true
            FriendsFrameTooltip_SetLine(line, anchor, util:AddLines(text, util:wowrepioString(2)), yOffset)
            ns.tooltipLineLocked = false
            return
        end
    end

    function friendTooltip:OnLoad()
        print("friendTooltip:OnLoad()")
        hooksecurefunc("FriendsFrameTooltip_SetLine", friendTooltip_SetLine)
    end
end

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
    local friendTooltip = ns:GetModule("friendTooltip")

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

    -- lfg applicants - BY wowrep.io
    for i=1, 14 do
        print("Hooking button " .. i)
        local button = _G["LFGListApplicationViewerScrollFrameButton" .. i]
        button:HookScript("OnEnter", OnEnter)
        button:HookScript("OnLeave", OnLeave)
    end

    -- allow lookup by all team members - BY wowrep.io
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