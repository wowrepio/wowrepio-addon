local _, ns = ...

local PLAYER_LOGIN_EVENT = "PLAYER_LOGIN"
local ADDON_LOADED_EVENT = "ADDON_LOADED"

local currentId = 1
local modules = {}
local moduleTemplate = {loaded = false}

function ns:AddModule(moduleName)
    if modules[moduleName] then
        print("Warning: overwriting module " .. moduleName)
    end

    local module = { id = currentId }
    for k, v in pairs(moduleTemplate) do
        module[k] = v
    end

    modules[moduleName] = module
    currentId = currentId + 1

    return modules[moduleName]
end

function ns:GetModule(moduleName)
    for k, module in pairs(modules) do
        if k == moduleName then
            return module
        end
    end
end

function moduleTemplate:Initialize()
    if self.loaded then
        return
    end

    if self:IsReady() then
        self:OnReady()
        self.loaded = true
    end
end
function moduleTemplate:IsReady() return true; end
function moduleTemplate:OnReady() end

local function moduleCompare(a, b)
    return a.id < b.id
end

function ns:IndexModules()
    table.sort(modules, moduleCompare)

    return modules
end

local function InitializeAddon()
    for moduleName, module in pairs(ns:IndexModules()) do
        module:Initialize()

        -- Some frames or ui elements are available after some time, so try again
        C_Timer.After(1, function()
            module:Initialize()
        end)
    end
end

local smfModuleFrame = CreateFrame("Frame")
smfModuleFrame:RegisterEvent(PLAYER_LOGIN_EVENT)
smfModuleFrame:RegisterEvent(ADDON_LOADED_EVENT)

smfModuleFrame:SetScript("OnEvent", function(self, eventName)
    if eventName == PLAYER_LOGIN_EVENT or eventName == ADDON_LOADED_EVENT then
        InitializeAddon()
    end
end)
