local _, ns = ...

local channel = ns:AddModule("channel")

-- Relay
local channelFrame = CreateFrame("Frame")
channelFrame:SetScript("OnEvent", function(_handler, event, ...)
        channel:HandleEvent(event, ...)
end)

local eventHandlers = {}
local singleEventHandlers = {}

function channel:RegisterEvent(event, handler)
    assert(event and handler, "channel:RegisterEvent requires both event and handler to be provided")

    if not eventHandlers[event] then
        eventHandlers[event] = {}
    end

    pcall(function() channelFrame:RegisterEvent(event, handler) end) -- Do not raise when its a custom event, that the game does not know

    table.insert(eventHandlers[event], handler)
end

function channel:RegisterSingleEvent(event, handler)
    assert(event and handler, "channel:RegisterEvent requires both event and handler to be provided")

    if not singleEventHandlers[event] then
        singleEventHandlers[event] = {}
    end

    pcall(function() channelFrame:RegisterEvent(event, handler) end) -- Do not raise when its a custom event, that the game does not know

    table.insert(singleEventHandlers[event], handler)
end

function channel:HandleEvent(event, ...)
    assert(event, "channel:HandleEvent requires event name to be passed")

    if eventHandlers[event] then
        for _, eventHandler in pairs(eventHandlers[event]) do
            eventHandler(...)
        end
    end

    if singleEventHandlers[event] then
        for _, eventHandler in pairs(singleEventHandlers[event]) do
            eventHandler(...)
        end

        singleEventHandlers[event] = nil
    end
end

function channel:SendEvent(event, ...)
    channel:HandleEvent(event, ...)
end