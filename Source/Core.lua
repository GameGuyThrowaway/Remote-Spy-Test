--[[
    -- I suggest turning on line wrapping to read my massive single line comments
    -- I should probably add more sanity checks for basic stuff, but I figure most of this stuff should be impossible to break in real world conditions, so the only way it would fail the sanity check is if I wrote the code wrong, in which case might as well error
    
    -- Incoming data should be completely safe because it was passed through a bindable (SynSignal)
    -- Need to rewrite Backend.lua partiallySanitizeData to be a full data sanitation (cloneref instances, cyclic check, stack overflow check, convert illegal indices)
]]

local require = ...
local interface = require("Interface.lua")
local backend = require("Backend.lua")
local pseudocodeGenerator = require("PseudocodeGenerator.lua")
local settingsModule = require("Settings.lua")

local task_spawn = task.spawn
local clear_table = table.clear
local table_foreach = table.foreach

local blockedList = {} -- list of blocked remotes
local ignoredList = {} -- list of ignored remotes
local remoteList = {} -- list of every single remote instance in the game
local callList = {} -- list of calls
local returnValuePointerList = {} -- hashmap used that points a update key to a table

local function logCall(remote: Instance, remoteID: string, returnValueKey: string, callingScript: Instance, callStack, args, argCount: number)
    local call = {
        Args = args,
        ArgCount = argCount,
        CallingScript = callingScript,
        CallStack = callStack
    }
    local listEntry = callList[remoteID]

    if returnValueKey then
        returnValuePointerList[returnValueKey] = call
    end

    if not listEntry then
        callList[remoteID] = {
            DestroyedConnection = remote.Destroying:Connect(function()
                callList[remoteID].DestroyedConnection:Disconnect()
                callList[remoteID].Destroyed = true
            end),
            Destroyed = false,
            ID = remoteID,
            Remote = remote,
            Calls = { call }
        }
    else
        table.insert(listEntry.Calls, call)
    end

    return call
end

local function updateReturnValue(returnValueKey: string, returnValue, returnCount: number)
    local callEntry = returnValuePointerList[returnValueKey]

    callEntry.ReturnValue = returnValue
    callEntry.ReturnCount = returnCount
    returnValuePointerList[returnValueKey] = nil
    return callEntry
end 

do -- initialize

    -- send data to modules (could swap this out with just a function call because it isn't object oriented) 
    interface.EventPipe:ListenToEvent('onGetRemoteList', function() 
        return remoteList
    end)
    interface.EventPipe:ListenToEvent('onGetBlockedList', function() 
        return blockedList
    end)
    interface.EventPipe:ListenToEvent('onGetIgnoredList', function() 
        return ignoredList
    end)
    interface.EventPipe:ListenToEvent('onGetSettings', function() 
        return settingsModule.Settings
    end)

    -- block event, unnecessary if it gets the list passed directly
    interface.EventPipe:ListenToEvent('onRemoteBlocked', function(remoteID: string, status: boolean) 
        blockedList[remoteID] = status
    end)

    -- ignore event, unnecessary if it gets the list passed directly
    interface.EventPipe:ListenToEvent('onRemoteIgnored', function(remoteID: string, status: boolean) 
        ignoredList[remoteID] = status
    end)

    -- special case for updating callstack limit (needs to be sent to all lua states)
    interface.EventPipe:ListenToEvent('onCallStackLimitChanged', function(newLimit: number)
        backend.sendCommand("updateCallStackLimit", newLimit)
    end)

    -- interface requests
    interface.EventPipe:ListenToEvent('generatePseudocode', function(remoteID: string, callIndex: number) 
        local remoteInfo = callList[remoteID]
        return pseudocodeGenerator.generatePseudocode(remoteInfo.Remote, remoteInfo.Calls[callIndex])
    end)
    interface.EventPipe:ListenToEvent('generatePseudoCallStack', function(remoteID: string, callIndex: number)
        return pseudocodeGenerator.generatePseudoCallStack(callList[remoteID].Calls[callIndex].CallStack)
    end)
    interface.EventPipe:ListenToEvent('repeatCall', function(remoteID: string, callIndex: number)
        local remoteInfo = callList[remoteID]
        local remote = remoteInfo.Remote
        local call = remoteInfo.Calls[callIndex]
        
        if remote.ClassName == "RemoteEvent" then
            remote:FireServer(unpack(call.Args, 1, call.ArgCount))
        else
            task_spawn(function()
                remote:InvokeServer(unpack(call.Args, 1, call.ArgCount))
            end)
        end
    end)
    interface.EventPipe:ListenToEvent('clearRemoteCalls', function(remoteID: string)
        local remoteInfo = callList[remoteID]
        if remoteInfo.Destroyed then
            callList[remoteID] = nil
        else
            clear_table(remoteInfo.Calls) -- clear actual calls, not remote data though
        end
    end)
    interface.EventPipe:ListenToEvent('clearAllCalls', function()
        table_foreach(callList, function(call)
            call.DestroyedConnection:Disconnect()
        end)
        clear_table(callList)
    end)

    -- backend events 
    backend.EventPipe:ListenToEvent('onRemoteCall', function(args, argCount: number, remote: Instance, remoteID: string, returnValueKey: string, callingScript: Instance, callStack) 
        local call = logCall(remote, remoteID, returnValueKey, callingScript, callStack, args, argCount)
        interface.EventPipe:Fire('onNewCall', call)
    end)
    backend.EventPipe:ListenToEvent('onReturnValueUpdated', function(returnData, returnCount:number, returnKey: string) 
        local call = updateReturnValue(returnKey, returnData, returnCount)
        interface.EventPipe:Fire('onReturnValueUpdated', call)
    end)

    settingsModule.loadSettings()
    pseudocodeGenerator.initiateModule(settingsModule)
    backend.initiateModule(blockedList, ignoredList, settingsModule.Settings.CallStackSizeLimit)
end