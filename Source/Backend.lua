local backendModule = {}

local task_spawn = task.spawn

local blockedList, ignoredList, callStackLimit, hookCode -- initialize variables, later to be used to point to the real values
local metadata -- this is used to store metadata while the args are still being sent, due to a BindableEvent limitation, I need to split metadata from args
local EventPipe

local mainChannelID: string
local argChannelID: string
local mainChannel: SynSignal
local argChannel: SynSignal

mainChannelID, mainChannel = syn.create_comm_channel()
argChannelID, argChannel = syn.create_comm_channel()

local commands = {
    sendMetadata = function(sendingKey, ...)
        metadata = {...}
    end,
    checkBlocked = function(sendingKey, remoteID)
        mainChannel:Fire(0, sendingKey, "checkBlocked", blockedList[remoteID])
    end,
    checkIgnored = function(sendingKey, remoteID)
        mainChannel:Fire(0, sendingKey, "checkIgnored", ignoredList[remoteID])
    end
}

mainChannel:Connect(function(sendingKey: string, receivingKey: number, callType: string, ...)
    if receivingKey == 0 then -- make sure the server is meant to receive this
        task_spawn(commands[callType], sendingKey, ...) -- no point wasting anymore of the hook's time, all data is secured
    end
end)

argChannel:Connect(function(...)
    assert(metadata, "FATAL ERROR, REPORT IMMEDIATELY")
    local callType = metadata[1]

    task_spawn(function(...)
        EventPipe:Fire(callType, {...}, select("#", ...), unpack(metadata, 2, #metadata))
    end, ...)

    metadata = nil
end)

local currentChannelNumber = 0 -- use this to make "channelKeys" aka a unique identifier for each channel, 0 != "0"
local function handleActor(actor: Actor)
    currentChannelNumber += 1
    syn.run_on_actor(actor, hookCode, argChannelID .. "|" .. mainChannelID .. "|" .. currentChannelNumber.. "|" .. callStackLimit)
end

function backendModule.initiateModule(BlockedList, IgnoredList, CallStackLimit, HookCode)
    ignoredList = IgnoredList
    blockedList = BlockedList
    callStackLimit = CallStackLimit
    hookCode = HookCode

    syn.on_actor_created:Connect(handleActor)

    loadstring(hookCode)(argChannelID .. "|" .. mainChannelID .. "|" .. currentChannelNumber .. "|" .. callStackLimit) -- load the global state (channel 0)
    for _, v in next, getactors() do
        handleActor(v)
    end
end

function backendModule.setupSignals(TaskSignal)
    assert(not EventPipe, "Signals Already Setup")
    EventPipe = TaskSignal.new({
        "onRemoteCall",
        "onReturnValueUpdated",
        "updateCallStackLimit"
    })

    EventPipe:ListenToEvent("updateCallStackLimit", function(newLimit: number)
        callStackLimit = newLimit
        mainChannel:Fire("0", "-1", "updateCallStackLimit", newLimit)
    end)
    
    backendModule.EventPipe = EventPipe
end

return backendModule