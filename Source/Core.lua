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
local signalModule = require("TaskSignal.lua")

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
        returnValuePointerList[returnValueKey] = { Call = call, RemoteID = remoteID }
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
    local returnEntry = returnValuePointerList[returnValueKey]
    local callEntry = returnEntry.call
    local remoteID = returnEntry.RemoteID

    callEntry.ReturnValue = returnValue
    callEntry.ReturnCount = returnCount
    returnValuePointerList[returnValueKey] = nil

    return callEntry, remoteID
end 

do -- initialize

    interface.setupSignals(signalModule)
    backend.setupSignals(signalModule)

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
        local call = remoteInfo and remoteInfo.Calls[callIndex]
        if call then
            return pseudocodeGenerator.generateCode(remoteInfo.Remote, call)
        else
            return false
        end
    end)
    interface.EventPipe:ListenToEvent('generatePseudoCallStack', function(remoteID: string, callIndex: number)
        return pseudocodeGenerator.generateCallStack(callList[remoteID].Calls[callIndex].CallStack)
    end)
    interface.EventPipe:ListenToEvent('generatePseudoReturnValue', function(remoteID: string, callIndex: number)
        return pseudocodeGenerator.generateReturnValue(callList[remoteID].Calls[callIndex].ReturnValue)
    end)
    interface.EventPipe:ListenToEvent('getCallingScriptPath', function(remoteID: string, callIndex: number)
        local remoteInfo = callList[remoteID]
        local call = remoteInfo and remoteInfo.Calls[callIndex]
        if call and call.CallingScript then
            return pseudocodeGenerator.getInstancePath(call.CallingScript)
        else
            return false
        end
    end)
    interface.EventPipe:ListenToEvent('decompileCallingScript', function(remoteID: string, callIndex: number)
        local remoteInfo = callList[remoteID]
        local call = remoteInfo and remoteInfo.Calls[callIndex]
        if call and call.CallingScript then
            return decompile(call.CallingScript)
        else
            return false
        end
    end)
    interface.EventPipe:ListenToEvent('getRemotePath', function(remoteID: string)
        local remoteInfo = callList[remoteID]
        if remoteInfo then
            return pseudocodeGenerator.getInstancePath(remoteInfo.Remote)
        else
            return false
        end
    end)
    interface.EventPipe:ListenToEvent('repeatCall', function(remoteID: string, callIndex: number, amount: number)
        local remoteInfo = callList[remoteID]
        local remote = remoteInfo.Remote
        local call = remoteInfo.Calls[callIndex]

        amount = amount or 1
        
        if remote.ClassName == "RemoteEvent" then
            local fireServer = remote.FireServer
            for _ = 1, amount do
                fireServer(remote, unpack(call.Args, 1, call.ArgCount))
            end
        else
            local invokeServer = remote.InvokeServer
            for _ = 1, amount do
                task_spawn(function()
                    invokeServer(remote, unpack(call.Args, 1, call.ArgCount))
                end)
            end
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
        interface.EventPipe:Fire('onNewCall', remoteID, call)
    end)
    backend.EventPipe:ListenToEvent('onReturnValueUpdated', function(returnData, returnCount: number, returnKey: string) 
        local call, remoteID = updateReturnValue(returnKey, returnData, returnCount)
        interface.EventPipe:Fire('onReturnValueUpdated', remoteID, call)
    end)

    settingsModule.loadSettings()
    interface.initiateModule(remoteList, blockedList, ignoredList, settingsModule.Settings)
    pseudocodeGenerator.initiateModule(settingsModule.Settings)
    backend.initiateModule(blockedList, ignoredList, settingsModule.Settings.CallStackSizeLimit)
end
