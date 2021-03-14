local ns = select(2, ...) ---@type ns @The addon namespace.
---
--- @TODO
--- Normalizacja realmName dla funkcji getScore
--- Normalizacja realmName dla dropdown
--- Wyswietlanie "unknown" dla braku score
---


RED_FONT_COLOR_CODE = "|cFFFF0000"
REGIONS = {"us", "kr", "eu", "tw", "cn"}

function string:wowrepio_Split(delimiter)
    local result = { }
    local from  = 1
    local delim_from, delim_to = string.find( self, delimiter, from  )
    while delim_from do
        table.insert( result, string.sub( self, from , delim_from-1 ) )
        from  = delim_to + 1
        delim_from, delim_to = string.find( self, delimiter, from  )
    end
    table.insert( result, string.sub( self, from  ) )
    return result
end

-- Data
do
    ns.tooltipLineLocked = false
    ns.loaded = false
    ns.FACTION_TO_ID = {Alliance = 1, Horde = 2, Neutral = 3}

    function ns:GetRealmData()
        return ns.REALMS
    end

end


-- Module system
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
                return module
            end
        end
        assert(silent, "wowrep.io Module expects GetModule(id) where id is a string, and the module must exists, or the silent param must be set to avoid this throw.")
    end
end

-- DB module
do
    local db = ns:NewModule("db")

    function db:GetScore(region, realm, name)
        if not region or not realm or not name then
            return null
        end
        --print("Getting score for " .. region .. "/" .. realm .. "/" .. name)
        return ns.DATABASE[region .. "/" .. realm .. "/" .. name]
    end
end

-- Utility module
do
    local util = ns:NewModule("util")
    local REALMS = ns:GetRealmData()

    function util:GetCurrentRegion()
        local regionId = GetCurrentRegion()

        return REGIONS[regionId]
    end

    function util:GetRealmSlug(realm, fallback)
        local realmSlug = REALMS[realm] or REALMS[realm:gsub("%s+", "")] -- Remove spaces in case not found
        if fallback == true then
            return realmSlug or realm
        elseif fallback then
            return realmSlug or fallback
        end
        return realmSlug
    end

    local UNIT_TOKENS = {
        mouseover = true,
        player = true,
        target = true,
        focus = true,
        pet = true,
        vehicle = true,
    }

    do
        for i = 1, 40 do
            UNIT_TOKENS["raid" .. i] = true
            UNIT_TOKENS["raidpet" .. i] = true
            UNIT_TOKENS["nameplate" .. i] = true
        end

        for i = 1, 4 do
            UNIT_TOKENS["party" .. i] = true
            UNIT_TOKENS["partypet" .. i] = true
        end

        for i = 1, 5 do
            UNIT_TOKENS["arena" .. i] = true
            UNIT_TOKENS["arenapet" .. i] = true
        end

        for i = 1, MAX_BOSS_FRAMES do
            UNIT_TOKENS["boss" .. i] = true
        end

        for k, _ in pairs(UNIT_TOKENS) do
            UNIT_TOKENS[k .. "target"] = true
        end
    end

    ---@return boolean @If the unit provided is a unit token this returns true, otherwise false
    function util:IsUnitToken(unit)
        return type(unit) == "string" and UNIT_TOKENS[unit]
    end

    ---@param arg1 string @"unit", "name", or "name-realm"
    ---@param arg2 string @"realm" or nil
    ---@return boolean, boolean, boolean @If the args used in the call makes it out to be a proper unit, arg1 is true and only then is arg2 true if unit exists and arg3 is true if unit is a player.
    function util:IsUnit(arg1, arg2)
        if not arg2 and type(arg1) == "string" and arg1:find("-", nil, true) then
            arg2 = true
        end
        local isUnit = not arg2 or util:IsUnitToken(arg1)
        return isUnit, isUnit and UnitExists(arg1), isUnit and UnitIsPlayer(arg1)
    end

    ---@param playerLink string @The player link can be any valid clickable chat link for messaging
    ---@return string, string @Returns the name and realm, or nil for both if invalid
    function util:GetNameRealmFromPlayerLink(playerLink)
        local linkString, linkText = LinkUtil.SplitLink(playerLink)
        local linkType, linkData = ExtractLinkData(linkString)
        if linkType == "player" then
            return util:GetNameRealm(linkData)
        elseif linkType == "BNplayer" then
            local _, bnetIDAccount = strsplit(":", linkData)
            if bnetIDAccount then
                bnetIDAccount = tonumber(bnetIDAccount)
            end
            if bnetIDAccount then
                local fullName, _, level = util:GetNameRealmForBNetFriend(bnetIDAccount)
                local name, realm = util:GetNameRealm(fullName)
                return name, realm, level
            end
        end
    end

    ---@param bnetIDAccount number @BNet Account ID
    ---@param getAllChars boolean @true = table, false = character as varargs
    ---@return any @Returns either a table with all characters, or the specific character varargs with name, faction and level.
    function util:GetNameRealmForBNetFriend(bnetIDAccount, getAllChars)
        local index = BNGetFriendIndex(bnetIDAccount)
        if not index then
            return
        end
        local collection = {}
        local collectionIndex = 0
        for i = 1, C_BattleNet.GetFriendNumGameAccounts(index), 1 do
            local accountInfo = C_BattleNet.GetFriendGameAccountInfo(index, i)
            if accountInfo and accountInfo.clientProgram == BNET_CLIENT_WOW and (not accountInfo.wowProjectID or accountInfo.wowProjectID ~= WOW_PROJECT_CLASSIC) then
                if accountInfo.realmName then
                    accountInfo.characterName = accountInfo.characterName .. "-" .. accountInfo.realmName:gsub("%s+", "")
                end
                collectionIndex = collectionIndex + 1
                collection[collectionIndex] = {accountInfo.characterName, ns.FACTION_TO_ID[accountInfo.factionName], tonumber(accountInfo.characterLevel)}
            end
        end
        if not getAllChars then
            for i = 1, collectionIndex do
                local profile = collection[collectionIndex]
                local name, faction, level = profile[1], profile[2], profile[3]
                return name, faction, level
            end
            return
        end
        return collection
    end


    ---@param arg1 string @"unit", "name", or "name-realm"
    ---@param arg2 string @"realm" or nil
    ---@return string, string, string @name, realm, unit
    function util:GetNameRealm(arg1, arg2)
        local unit, name, realm
        local _, unitExists, unitIsPlayer = util:IsUnit(arg1, arg2)
        if unitExists then
            unit = arg1
            if unitIsPlayer then
                name, realm = UnitName(arg1)
                realm = realm and realm ~= "" and realm or GetNormalizedRealmName()
            end
            return name, realm, unit
        end
        if type(arg1) == "string" then
            if arg1:find("-", nil, true) then
                name, realm = ("-"):wowrepio_Split(arg1)
            else
                name = arg1 -- assume this is the name
            end
            if not realm or realm == "" then
                if type(arg2) == "string" and arg2 ~= "" then
                    realm = arg2
                else
                    realm = GetNormalizedRealmName() -- assume they are on our realm
                end
            end
        end
        return name, realm, unit
    end


    ---@param object Widget @Any interface widget object that supports the methods GetScript.
    ---@param handler string @The script handler like OnEnter, OnClick, etc.
    ---@return boolean|nil @If successfully executed returns true, otherwise false if nothing has been called. nil if the widget had no handler to execute.
    function util:ExecuteWidgetHandler(object, handler, ...)
        if type(object) ~= "table" or type(object.GetScript) ~= "function" then
            return false
        end
        local func = object:GetScript(handler)
        if type(func) ~= "function" then
            return
        end
        if not pcall(func, object, ...) then
            return false
        end
        return true
    end

    ---@param object Widget @Any interface widget object that supports the methods GetOwner.
    ---@param owner Widget @Any interface widget object.
    ---@param anchor string @`ANCHOR_TOPLEFT`, `ANCHOR_NONE`, `ANCHOR_CURSOR`, etc.
    ---@param offsetX number @Optional offset X for some of the anchors.
    ---@param offsetY number @Optional offset Y for some of the anchors.
    ---@return boolean, boolean, boolean @If owner was set arg1 is true. If owner was updated arg2 is true. Otherwise both will be set to face to indicate we did not update the Owner of the widget. If the owner is set to the preferred owner arg3 is true.
    function util:SetOwnerSafely(object, owner, anchor, offsetX, offsetY)
        if type(object) ~= "table" or type(object.GetOwner) ~= "function" then
            return
        end
        local currentOwner = object:GetOwner()
        if not currentOwner then
            object:SetOwner(owner, anchor, offsetX, offsetY)
            return true, false, true
        end
        offsetX, offsetY = offsetX or 0, offsetY or 0
        local currentAnchor, currentOffsetX, currentOffsetY = object:GetAnchorType()
        currentOffsetX, currentOffsetY = currentOffsetX or 0, currentOffsetY or 0
        if currentAnchor ~= anchor or (currentOffsetX ~= offsetX and abs(currentOffsetX - offsetX) > 0.01) or (currentOffsetY ~= offsetY and abs(currentOffsetY - offsetY) > 0.01) then
            object:SetOwner(owner, anchor, offsetX, offsetY)
            return true, true, true
        end
        return false, true, currentOwner == owner
    end

    local function colorShade(hexColor, perc)
        local r = tonumber(hexColor:sub(1,2), 16)
        local g = tonumber(hexColor:sub(3,4), 16)
        local b = tonumber(hexColor:sub(5,6), 16)


        r = r * (perc/100);
        g = g * (perc/100);
        b = b * (perc/100);

        if r > 255 then
            r = 255
        end

        if r<0 then
            r = 0
        end

        if g > 255 then
            g = 255
        end
        if g<0 then
            g = 0
        end

        if b > 255 then
            b = 255
        end

        if b<0 then
            b = 0
        end

        local rr = string.format("%x", math.floor(r))
        local gg = string.format("%x", math.floor(g))
        local bb = string.format("%x", math.floor(b))

        if string.len(rr) == 1 then
            rr = "0" .. rr
        end

        if string.len(gg) == 1 then
            gg = "0" .. gg
        end

        if string.len(bb) == 1 then
            bb = "0" .. bb
        end

        return rr .. gg .. bb
    end

    function util:getColorFor(value)
        local perc
        local colorBase
        local k

        if value >= 3 then
            colorBase = "109110"
            k = value - 3
            perc = (100+(100-(k*50)))*((5/(k+1)))
        else
            colorBase = "911010"
            k = value
            perc = (100+((k-1)*50*k/0.9))*(k/1)
        end


        return "|c00" .. colorShade(colorBase, perc)
    end

    function util:AddLines(tt,text)
        tt = tt.."|n"..text;

        return tt;
    end

    function util:wowrepioString(offset, score)
        local text = NORMAL_FONT_COLOR_CODE .. "WowRep.io Score |r"

        if not offset then
            offset = 2
        end

        if not score then
            return text .. "|c007F7F7Fnot rated|r"
        end

        text = text .. util:getColorFor(score.average) .. tostring(score.average) .. "|n"
        for k, v in pairs(score.factors) do
            for i=1,offset+1 do
                text = text.." "
            end

            text = text .. NORMAL_FONT_COLOR_CODE .. string.upper(string.sub(k, 1,1)) .. string.sub(k, 2, -1) .. "|r" .. ": ".. util:getColorFor(v) .. v .. "|r" .. "|n"
        end

        return text
    end
end

-- Render
do
    local render = ns:NewModule("render")
    local util = ns:GetModule("util")

    function render:Score(tooltip, score)
        if not tooltip then
            print(NORMAL_FONT_COLOR_CODE .. "[WowRep.io] " .. RED_FONT_COLOR_CODE .. "Error|r: " .. "could not render profile (tooltip is non-existing)")
            return
        end

        tooltip:AddLine(util:wowrepioString(0, score))
        tooltip:Show() -- Ensure tooltip is properly resized
    end
end

-- Both LFG AND on-screen hover / on frame hover
-- LFG Tooltip
do
    local lfgTooltip = ns:NewModule("lfgTooltip")
    local util = ns:GetModule("util")
    local db = ns:GetModule("db")
    local render = ns:GetModule("render")
    local currentResult = {}
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

    function lfgTooltip_OnEnter(self)
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
            local fullNameAvailable, fullName = lfgTooltip:GetFullName(self, self:GetParent().applicantID, self.memberIdx)
            if fullNameAvailable then
                --print("fullName: " .. fullName)
                local name, realm = util:GetNameRealm(fullName)
                render:Score(GameTooltip, db:GetScore(util:GetCurrentRegion(), util:GetRealmSlug(realm, true), name))
            else
                --print("fullName not available: " .. tostring(currentResult))
            end
        end
    end

    function lfgTooltip_OnLeave(self)
        GameTooltip:Hide()
    end

    function lfgTooltip:OnLoad()
        -- lfg applicants - BY wowrep.io
        for i=1, 14 do
            local button = _G["LFGListApplicationViewerScrollFrameButton" .. i]
            button:HookScript("OnEnter", lfgTooltip_OnEnter)
            button:HookScript("OnLeave", lfgTooltip_OnLeave)
        end

        -- allow lookup by all team members - BY wowrep.io
        do
            local f = _G.LFGListFrame.ApplicationViewer.UnempoweredCover
            f:EnableMouse(false)
            f:EnableMouseWheel(false)
            f:SetToplevel(false)
        end
    end
end

-- in-game tooltip
do
    local tooltip = ns:NewModule("ingameTooltip")
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
                --self:AddLine(util:wowrepioString(2))
                --util:SetOwnerSafely(GameTooltip, UIParent, "ANCHOR_TOPLEFT", 0, 0)
                render:Score(GameTooltip, db:GetScore(util:GetCurrentRegion(), util:GetRealmSlug(realm, true), name))
            end
        end
    end

    function tooltip:OnLoad()
        GameTooltip:HookScript("OnTooltipSetUnit", OnTooltipSetUnit)
    end

end

-- Friend Tooltip
do
    local friendTooltip = ns:NewModule("friendTooltip")
    local util = ns:GetModule("util")
    local db = ns:GetModule("db")
    local inspectedFriend = {}
    local _FRIENDS_LIST_REALM = FRIENDS_LIST_REALM.."|r(.+)"
    local CHARACTER_NAME_REGEX = "(.+), (%d+) (.+) (.+)"

    local function friendTooltip_SetLine(line, anchor, text, yOffset)
        if ns.tooltipLineLocked then
            return
        end

        if not text then
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

            ns.tooltipLineLocked = true
            FriendsFrameTooltip_SetLine(line, anchor, util:AddLines(text, util:wowrepioString(2, db:GetScore(util:GetCurrentRegion(), util:GetRealmSlug(inspectedFriend.realmName), inspectedFriend.name))), yOffset)
            ns.tooltipLineLocked = false
            return
        end
    end

    function friendTooltip:OnLoad()
        hooksecurefunc("FriendsFrameTooltip_SetLine", friendTooltip_SetLine)
    end
end

-- callback.lua
-- dependencies: module
do

    ---@class CallbackModule : Module
    local callback = ns:NewModule("Callback") ---@type CallbackModule

    local callbacks = {}
    local callbackOnce = {}

    local handler = CreateFrame("Frame")

    handler:SetScript("OnEvent", function(handler, event, ...)
        if event == "COMBAT_LOG_EVENT_UNFILTERED" or event == "COMBAT_LOG_EVENT" then
            callback:SendEvent(event, CombatLogGetCurrentEventInfo())
        else
            callback:SendEvent(event, ...)
        end
    end)

    ---@param callbackFunc function
    function callback:RegisterEvent(callbackFunc, ...)
        assert(type(callbackFunc) == "function", "Raider.IO Callback expects RegisterEvent(callback[, ...events])")
        local events = {...}
        for _, event in ipairs(events) do
            if not callbacks[event] then
                callbacks[event] = {}
            end
            table.insert(callbacks[event], callbackFunc)
            pcall(handler.RegisterEvent, handler, event)
        end
    end

    ---@param callbackFunc function
    ---@param event string
    function callback:RegisterUnitEvent(callbackFunc, event, ...)
        assert(type(callbackFunc) == "function" and type(event) == "string", "Raider.IO Callback expects RegisterUnitEvent(callback, event, ...units)")
        if not callbacks[event] then
            callbacks[event] = {}
        end
        table.insert(callbacks[event], callbackFunc)
        handler:RegisterUnitEvent(event, ...)
    end

    function callback:UnregisterEvent(callbackFunc, ...)
        assert(type(callbackFunc) == "function", "Raider.IO Callback expects UnregisterEvent(callback, ...events)")
        local events = {...}
        callbackOnce[callbackFunc] = nil
        for _, event in ipairs(events) do
            local eventCallbacks = callbacks[event]
            for i = #eventCallbacks, 1, -1 do
                local eventCallback = eventCallbacks[i]
                if eventCallback == callbackFunc then
                    table.remove(eventCallbacks, i)
                end
            end
            if not eventCallbacks[1] then
                pcall(handler.UnregisterEvent, handler, event)
            end
        end
    end

    ---@param callbackFunc function
    function callback:UnregisterCallback(callbackFunc)
        assert(type(callbackFunc) == "function", "Raider.IO Callback expects UnregisterCallback(callback)")
        for event, _ in pairs(callbacks) do
            self:UnregisterEvent(callbackFunc, event)
        end
    end

    ---@param event string
    function callback:SendEvent(event, ...)
        assert(type(event) == "string", "Raider.IO Callback expects SendEvent(event[, ...args])")
        local eventCallbacks = callbacks[event]
        if not eventCallbacks then
            return
        end
        -- execute in correct sequence but note if any are to be removed later
        local remove
        for i = 1, #eventCallbacks do
            local callbackFunc = eventCallbacks[i]
            callbackFunc(event, ...)
            if callbackOnce[callbackFunc] then
                callbackOnce[callbackFunc] = nil
                if not remove then
                    remove = {}
                end
                table.insert(remove, i)
            end
        end
        -- if we have callbacks to remove iterate backwards and remove those indices
        if remove then
            for i = #remove, 1, -1 do
                table.remove(eventCallbacks, remove[i])
            end
        end
    end

    ---@param callbackFunc function
    function callback:RegisterEventOnce(callbackFunc, ...)
        assert(type(callbackFunc) == "function", "Raider.IO Callback expects RegisterEventOnce(callback[, ...events])")
        callbackOnce[callbackFunc] = true
        callback:RegisterEvent(callbackFunc, ...)
    end

end

-- loader.lua (internal)
-- dependencies: module, callback, config, util, provider
do

    local callback = ns:GetModule("Callback") ---@type CallbackModule

    local loadingAgainSoon
    local LoadModules

    function LoadModules()
        local modules = ns:GetModules()
        local numLoaded = 0
        local numPending = 0
        for _, module in ipairs(modules) do
            if not module:IsLoaded() and module:CanLoad() then
                if module:HasDependencies() then
                    numLoaded = numLoaded + 1
                    module:Load()
                else
                    numPending = numPending + 1
                end
            end
        end
        if not loadingAgainSoon and numLoaded > 0 and numPending > 0 then
            loadingAgainSoon = true
            C_Timer.After(1, function()
                loadingAgainSoon = false
                LoadModules()
            end)
        end
    end

    local function OnPlayerLogin()
        callback:SendEvent("WOWREPIO_PLAYER_LOGIN")
        LoadModules()
    end

    local function OnAddOnLoaded(_, name)
        if name == addonName then
            config.SavedVariablesLoaded = true
        end
        LoadModules()
        if name == addonName then
            if not IsLoggedIn() then
                callback:RegisterEventOnce(OnPlayerLogin, "PLAYER_LOGIN")
            else
                OnPlayerLogin()
            end
        end
    end

    callback:RegisterEvent(OnAddOnLoaded, "ADDON_LOADED")
end

-- USED FOR /groster, NOT GUILD WINDOW
-- guildtooltip.lua
-- dependencies: module, config, util, render
do
    ---@class GuildTooltipModule : Module
    local tooltip = ns:NewModule("GuildTooltip") ---@type GuildTooltipModule
    local util = ns:GetModule("util")
    local render = ns:GetModule("render")
    local db = ns:GetModule("db")

    local function OnEnter(self)
        if not self.guildIndex then
            return
        end
        local fullName, _, _, level = GetGuildRosterInfo(self.guildIndex)
        if not fullName then
            return
        end
        local ownerSet, ownerExisted, ownerSetSame = util:SetOwnerSafely(GameTooltip, self, "ANCHOR_TOPLEFT", 0, 0)

        local name, realm = util:GetNameRealm(fullName)
        if not realm then
            name = fullName
            realm = GetRealmName()
        end
        render:Score(GameTooltip, db:GetScore(REGIONS[GetCurrentRegion()], util:GetRealmSlug(realm), name))

        --if render:ShowProfile(GameTooltip, fullName, ns.PLAYER_FACTION, render.Preset.UnitSmartPadding(ownerExisted)) then
        --    return
        --end
        if ownerSet and not ownerExisted and ownerSetSame then
            GameTooltip:Hide()
        end
    end

    local function OnLeave(self)
        if not self.guildIndex then
            return
        end
        GameTooltip:Hide()
    end

    local function OnScroll()
        GameTooltip:Hide()
        util:ExecuteWidgetHandler(GetMouseFocus(), "OnEnter")
    end

    function tooltip:CanLoad()
        return _G.GuildFrame
    end

    function tooltip:OnLoad()
        self:Enable()
        for i = 1, #GuildRosterContainer.buttons do
            local button = GuildRosterContainer.buttons[i]
            button:HookScript("OnEnter", OnEnter)
            button:HookScript("OnLeave", OnLeave)
        end
        hooksecurefunc(GuildRosterContainer, "update", OnScroll)
    end

end

-- communitytooltip.lua
-- dependencies: module, config, util, render
do

    ---@class CommunityTooltipModule : Module
    local tooltip = ns:NewModule("CommunityTooltip") ---@type CommunityTooltipModule
    local util = ns:GetModule("util")
    local db = ns:GetModule("db")
    local render = ns:GetModule("render")

    local hooked = {}
    local completed

    local function OnEnter(self)
        local clubType
        local nameAndRealm
        local level
        local faction = ns.PLAYER_FACTION
        if type(self.GetMemberInfo) == "function" then
            local info = self:GetMemberInfo()
            clubType = info.clubType
            nameAndRealm = info.name
            level = info.level
        elseif type(self.cardInfo) == "table" then
            nameAndRealm = util:GetNameRealm(self.cardInfo.guildLeader)
        else
            return
        end
        --if type(self.GetLastPosterGUID) == "function" then
        --    local playerGUID = self:GetLastPosterGUID()
        --    if playerGUID then
        --        local _, _, _, race = GetPlayerInfoByGUID(playerGUID)
        --        if race then
        --            faction = util:GetFactionFromRace(race, faction)
        --        end
        --    end
        --end
        if (clubType and clubType ~= Enum.ClubType.Guild and clubType ~= Enum.ClubType.Character) or not nameAndRealm then
            return
        end
        local ownerSet, ownerExisted, ownerSetSame = util:SetOwnerSafely(GameTooltip, self, "ANCHOR_LEFT", 0, 0)
        local name, realm = util:GetNameRealm(nameAndRealm)
        if not realm then
            realm = GetRealmName()
            name = nameAndRealm
        end
        render:Score(GameTooltip, db:GetScore(REGIONS[GetCurrentRegion()], util:GetRealmSlug(realm), name))
        --if render:ShowProfile(GameTooltip, nameAndRealm, faction, render.Preset.UnitSmartPadding(ownerExisted)) then
        --    return
        --end
        if ownerSet and not ownerExisted and ownerSetSame then
            GameTooltip:Hide()
        end
    end

    local function OnLeave(self)
        GameTooltip:Hide()
    end

    local function SmartHookButtons(buttons)
        if not buttons then
            return
        end
        local numButtons = 0
        for _, button in pairs(buttons) do
            numButtons = numButtons + 1
            if not hooked[button] then
                hooked[button] = true
                button:HookScript("OnEnter", OnEnter)
                button:HookScript("OnLeave", OnLeave)
                if type(button.OnEnter) == "function" then hooksecurefunc(button, "OnEnter", OnEnter) end
                if type(button.OnLeave) == "function" then hooksecurefunc(button, "OnLeave", OnLeave) end
            end
        end
        return numButtons > 0
    end

    local function OnRefreshApplyHooks()
        if completed then
            return
        end
        SmartHookButtons(_G.CommunitiesFrame.MemberList.ListScrollFrame.buttons)
        SmartHookButtons(_G.ClubFinderGuildFinderFrame.CommunityCards.ListScrollFrame.buttons)
        SmartHookButtons(_G.ClubFinderGuildFinderFrame.PendingCommunityCards.ListScrollFrame.buttons)
        SmartHookButtons(_G.ClubFinderGuildFinderFrame.GuildCards.Cards)
        SmartHookButtons(_G.ClubFinderGuildFinderFrame.PendingGuildCards.Cards)
        SmartHookButtons(_G.ClubFinderCommunityAndGuildFinderFrame.CommunityCards.ListScrollFrame.buttons)
        SmartHookButtons(_G.ClubFinderCommunityAndGuildFinderFrame.PendingCommunityCards.ListScrollFrame.buttons)
        SmartHookButtons(_G.ClubFinderCommunityAndGuildFinderFrame.GuildCards.Cards)
        SmartHookButtons(_G.ClubFinderCommunityAndGuildFinderFrame.PendingGuildCards.Cards)
        return true
    end

    local function OnScroll()
        GameTooltip:Hide()
        util:ExecuteWidgetHandler(GetMouseFocus(), "OnEnter")
    end

    function tooltip:CanLoad()
        return _G.CommunitiesFrame and _G.ClubFinderGuildFinderFrame and _G.ClubFinderCommunityAndGuildFinderFrame
    end

    function tooltip:OnLoad()
        self:Enable()
        hooksecurefunc(_G.CommunitiesFrame.MemberList, "RefreshLayout", OnRefreshApplyHooks)
        hooksecurefunc(_G.CommunitiesFrame.MemberList, "Update", OnScroll)
        hooksecurefunc(_G.ClubFinderGuildFinderFrame.CommunityCards, "RefreshLayout", OnRefreshApplyHooks)
        hooksecurefunc(_G.ClubFinderGuildFinderFrame.CommunityCards.ListScrollFrame, "update", OnScroll)
        hooksecurefunc(_G.ClubFinderGuildFinderFrame.PendingCommunityCards, "RefreshLayout", OnRefreshApplyHooks)
        hooksecurefunc(_G.ClubFinderGuildFinderFrame.PendingCommunityCards.ListScrollFrame, "update", OnScroll)
        hooksecurefunc(_G.ClubFinderGuildFinderFrame.GuildCards, "RefreshLayout", OnRefreshApplyHooks)
        hooksecurefunc(_G.ClubFinderGuildFinderFrame.PendingGuildCards, "RefreshLayout", OnRefreshApplyHooks)
        hooksecurefunc(_G.ClubFinderCommunityAndGuildFinderFrame.CommunityCards, "RefreshLayout", OnRefreshApplyHooks)
        hooksecurefunc(_G.ClubFinderCommunityAndGuildFinderFrame.CommunityCards.ListScrollFrame, "update", OnScroll)
        hooksecurefunc(_G.ClubFinderCommunityAndGuildFinderFrame.PendingCommunityCards, "RefreshLayout", OnRefreshApplyHooks)
        hooksecurefunc(_G.ClubFinderCommunityAndGuildFinderFrame.PendingCommunityCards.ListScrollFrame, "update", OnScroll)
        hooksecurefunc(_G.ClubFinderCommunityAndGuildFinderFrame.GuildCards, "RefreshLayout", OnRefreshApplyHooks)
        hooksecurefunc(_G.ClubFinderCommunityAndGuildFinderFrame.PendingGuildCards, "RefreshLayout", OnRefreshApplyHooks)
    end

end


-- dropdown.lua
-- dependencies: module, config, util + LibDropDownExtension
do

    ---@class DropDownModule : Module
    local dropdown = ns:NewModule("DropDown") ---@type DropDownModule
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
        WORLD_STATE_SCORE = true
    }

    -- if the dropdown is a valid type of dropdown then we mark it as acceptable to check for a unit on it
    local function IsValidDropDown(bdropdown)
        return (bdropdown == LFGListFrameDropDown or (type(bdropdown.which) == "string" and validTypes[bdropdown.which]))
    end

    -- get name and realm from dropdown or nil if it's not applicable
    local function GetNameRealmForDropDown(bdropdown)
        local unit = bdropdown.unit
        local bnetIDAccount = bdropdown.bnetIDAccount
        local menuList = bdropdown.menuList
        local quickJoinMember = bdropdown.quickJoinMember
        local quickJoinButton = bdropdown.quickJoinButton
        local clubMemberInfo = bdropdown.clubMemberInfo
        local tempName, tempRealm = bdropdown.name, bdropdown.server
        local name, realm, level
        -- unit
        if not name and UnitExists(unit) then
            if UnitIsPlayer(unit) then
                name, realm = util:GetNameRealm(unit)
                level = UnitLevel(unit)
            end
            -- if it's not a player it's pointless to check further
            return name, realm, level
        end
        -- bnet friend
        if not name and bnetIDAccount then
            local fullName, _, charLevel = util:GetNameRealmForBNetFriend(bnetIDAccount)
            if fullName then
                name, realm = util:GetNameRealm(fullName)
                level = charLevel
            end
            -- if it's a bnet friend we assume if eligible the name and realm is set, otherwise we assume it's not eligible for a url
            return name, realm, level
        end
        -- lfd
        if not name and menuList then
            for i = 1, #menuList do
                local whisperButton = menuList[i]
                if whisperButton and (whisperButton.text == _G.WHISPER_LEADER or whisperButton.text == _G.WHISPER) then
                    name, realm = util:GetNameRealm(whisperButton.arg1)
                    break
                end
            end
        end
        -- quick join
        if not name and (quickJoinMember or quickJoinButton) then
            local memberInfo = quickJoinMember or quickJoinButton.Members[1]
            if memberInfo.playerLink then
                name, realm, level = util:GetNameRealmFromPlayerLink(memberInfo.playerLink)
            end
        end
        -- dropdown by name and realm
        if not name and tempName then
            name, realm = util:GetNameRealm(tempName, tempRealm)
            if clubMemberInfo and clubMemberInfo.level and (clubMemberInfo.clubType == Enum.ClubType.Guild or clubMemberInfo.clubType == Enum.ClubType.Character) then
                level = clubMemberInfo.level
            end
        end
        -- if we don't got both we return nothing
        if not name or not realm then
            return
        end
        return name, realm, level
    end

    -- converts the name and realm into a copyable link
    local function ShowCopyDialog(name, realm)
        local url = format("https://wowrep.io/characters/%s/%s/%s?utm_source=addon", util:GetCurrentRegion(), util:GetRealmSlug(realm), name)
        if IsModifiedClick("CHATLINK") then
            local editBox = ChatFrame_OpenChat(url, DEFAULT_CHAT_FRAME)
            editBox:HighlightText()
        else
            StaticPopup_Show(copyUrlPopup.id, format("%s (%s)", name, realm), url)
        end
    end

    -- tracks the currently active dropdown name and realm for lookup
    local selectedName, selectedRealm, selectedLevel

    ---@type CustomDropDownOption[]
    local unitOptions

    ---@param options CustomDropDownOption[]
    local function OnToggle(bdropdown, event, options, level, data)
        if event == "OnShow" then
            if not IsValidDropDown(bdropdown) then
                return
            end
            selectedName, selectedRealm, selectedLevel = GetNameRealmForDropDown(bdropdown)
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

    ---@type LibDropDownExtension
    local LibDropDownExtension = LibStub and LibStub:GetLibrary("LibDropDownExtension-1.0", true)

    function dropdown:CanLoad()
        return LibDropDownExtension
    end

    function dropdown:OnLoad()
        self:Enable()
        unitOptions = {
            {
                text = "Copy WowRep.io URL",
                func = function()
                    ShowCopyDialog(selectedName, selectedRealm)
                end
            }
        }
        LibDropDownExtension:RegisterEvent("OnShow OnHide", OnToggle, 1, dropdown)
        StaticPopupDialogs[copyUrlPopup.id] = copyUrlPopup
    end
end


-- wowrepio
do
    local wowrepio = ns:NewModule("wowrepio")
    local util = ns:GetModule("util")
    local wowrepioFrame = CreateFrame("Frame")

    function wowrepio:OnLoad()
        print("Thank you for using " .. NORMAL_FONT_COLOR_CODE .. "WowRep.io! " .. RED_FONT_COLOR_CODE .. "<3")
        print("Shout out to Raider.IO for inspiration and a lot of technical help, this addon is based on their work!")

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
end
