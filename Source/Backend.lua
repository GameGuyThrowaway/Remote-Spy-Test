local Backend = {}

local task_spawn = task.spawn

local blockedList, ignoredList -- initialize variables, later to be used to point to the real tables

local function addCall(args, argCount: number, remote: Instance, remoteID: string, returnValueKey: string, callingScript: Instance, callStack)
    rconsolewarn("NEW CALL: " .. remote:GetFullName() .. " : " .. argCount .. " | " .. returnValueKey)
    -- send to core module here, or make addCall be in core module
end
local function updateReturnValue(returnValue, returnCount: number, returnValueKey: string)
    rconsolewarn("RETVAL: " .. returnCount .. " | " .. returnValueKey)
end

local metadata -- this is used to store metadata while the args are still being sent, due to a BindableEvent limitation, I need to split metadata from args

local mainChannelID: string
local mainChannel: SynSignal
mainChannelID, mainChannel = syn.create_comm_channel()

local argChannelID: string
local argChannel: SynSignal
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
    if callType == "addCall" then
        addCall({...}, select("#", ...), unpack(metadata, 2, #metadata))
    elseif callType == "updateReturnValue" then
        updateReturnValue({...}, select("#", ...), unpack(metadata, 2, #metadata))
    else
        error("FATAL ERROR2, REPORT IMMEDIATELY")
    end
    metadata = nil
end)

local hookCode = [[
if not _G.remoteSpyHookedState then
    local t = tick()
    _G.remoteSpyHookedState = true
    
    local task_spawn = task.spawn
    local coroutine_running = coroutine.running
    local coroutine_resume = coroutine.resume
    local coroutine_yield = coroutine.yield
    local table_insert = table.insert
    local get_debug_id = game.GetDebugId
    local get_thread_identity = syn.get_thread_identity
    local set_thread_identity = syn.set_thread_identity
    local valid_level = debug.validlevel
    
    local startingData = string.split(... , "|")
    
    local argChannelID: string = startingData[1]
    local mainChannelID: string = startingData[2]
    local channelKey: string = startingData[3]

    local mainChannel: SynSignal = syn.get_comm_channel(mainChannelID)
    local argChannel: SynSignal = syn.get_comm_channel(argChannelID)

    local isRemoteBlocked: boolean = false
    local isRemoteIgnored: boolean = false
    local callStackLimit: number = tonumber(startingData[4])

    local callCount: number = 0

    local commands = {
        checkBlocked = function(data)
            isRemoteBlocked = data
        end,
        checkIgnored = function(data)
            isRemoteIgnored = data
        end,
        updateCallStackLimit = function(data)
            callStackLimit = data
        end
    }

    mainChannel:Connect(function(sendingKey: string, receivingKey: string, callType: string, data: any)
        if receivingKey == channelKey or receivingKey == "-1" then -- -1 is the key for sending to everyone
            local command = commands[callType]
            if command then
                command(data)
            end
        end
    end)

    local function desanitizeData(deSanitizePaths) -- this function returns the orginal dangerous values, ensuring the creator doesn't know what happened
        for parentTable, data in next, deSanitizePaths do
            for _, mod in next, data.mods do
                rawset(parentTable, mod[2], nil)
                rawset(parentTable, mod[1], mod[3])
            end

            if data.readOnly then setreadonly(parentTable, true) end
        end
    end

    local function partiallySanitizeData(data, deSanitizePaths) -- this is used to cloneref all instances, only to be run on return values
        local first: boolean = false
        if not deSanitizePaths then
            deSanitizePaths = {}
            first = true
        end

        for i,v in next, data do
            local valueType = typeof(v)

            if valueType == "Instance" then
                local dataReadOnly: boolean = isreadonly(data)
                if dataReadOnly then setreadonly(data, false) end

                rawset(data, i, cloneref(v))

                if not deSanitizePaths[data] then
                    deSanitizePaths[data] = {
                        mods = { { i, i, v } },
                        readOnly = dataReadOnly
                    }
                else
                    table_insert(deSanitizePaths[data].mods, { i, i, v })
                end
            elseif valueType == "table" then
                partiallySanitizeData(data, deSanitizePaths)
            end
        end

        if first then
            return deSanitizePaths
        end
    end

    local dataTypes = {
        table = "Table",
        userdata = "void"
    }

    local function sanitizeData(data, depth: number, deSanitizePaths) -- this replaces unsafe indices, checks for cyclics, or stack overflow attemps, and clonerefs all instances
        if depth > 298 then return false end

        local originalDepth: number = depth
        local depthIncreased: boolean = false

        local first: boolean = false
        if not deSanitizePaths then
            deSanitizePaths = {}
            first = true
        end

        for i, v in next, data do
            if not depthIncreased then
                depthIncreased = true
                originalDepth += 1
                depth += 1
            end

            local valueType: string = typeof(v)
            if valueType == "table" then
                sanitizeData(v, originalDepth, deSanitizePaths)
            elseif valueType == "Instance" then -- this is variation added after the fact.  Originally I just added this sanitzation for clearing out unsafe indices, but now it's going to be modified to do more.
                
                local dataReadOnly: boolean = isreadonly(data)
                if dataReadOnly then setreadonly(data, false) end

                rawset(data, i, cloneref(v))

                if not deSanitizePaths[data] then
                    deSanitizePaths[data] = {
                        mods = { { i, i, v } },
                        readOnly = dataReadOnly
                    }
                else
                    table_insert(deSanitizePaths[data].mods, { i, i, v })
                end
            elseif valueType == "thread" or valueType == "function" then -- threads and functions can't be sent

                local dataReadOnly: boolean = isreadonly(data)
                if dataReadOnly then setreadonly(data, false) end

                rawset(data, i, nil)

                if not deSanitizePaths[data] then
                    deSanitizePaths[data] = {
                        mods = { { i, i, v } },
                        readOnly = dataReadOnly
                    }
                else
                    table_insert(deSanitizePaths[data].mods, { i, i, v })
                end
            end

            local indexType = typeof(i)
            if indexType == "thread" then return false end -- threads are illegal, can't be sent as indices
            local indexTypeSub = dataTypes[indexType]
            if indexType then
                local oldMt = getrawmetatable(i)
                if oldMt then
                    local wasReadOnly: boolean = isreadonly(oldMt)
                    if wasReadOnly then setreadonly(oldMt, false) end
                    local oldToString = rawget(oldMt, "__tostring")

                    if type(oldToString) == "function" then
                        rawset(oldMt, "__tostring", nil)
                        local newIndex: string = "<" .. indexType .. "> (" .. tostring(i) .. ")"

                        local dataReadOnly: boolean = isreadonly(data)
                        if dataReadOnly then setreadonly(data, false) end

                        rawset(data, newIndex, v)
                        rawset(data, i, nil)
                        if not deSanitizePaths[data] then
                            deSanitizePaths[data] = {
                                mods = { { i, newIndex, v } },
                                readOnly = dataReadOnly
                            }
                        else
                            table_insert(deSanitizePaths[data].mods, { i, newIndex, v })
                        end
                        rawset(oldMt, "__tostring", oldToString)
                    end

                    if wasReadOnly then setreadonly(oldMt, true) end
                end
            end
        end
        
        if first then
            return deSanitizePaths
        end
    end

    local function createCallStack(offset) -- offset is always 2 in this code, 1 for the hook, 1 because we don't need to log the C function call
        local newCallStack = {}

        offset += 1 -- +1 to account for this function

        for stackIndex = 0, callStackLimit do
            local realStackIndex = stackIndex + offset

            if not valid_level(realStackIndex) then 
                break 
            end

            local funcInfo = getinfo(realStackIndex)
            if funcInfo.func then
                local tempScript = rawget(getfenv(funcInfo.func), "script")

                local varArg = false -- converting is_vararg from 1/0 to true/false
                if funcInfo.is_vararg == 1 then varArg = true end

                newCallStack[stackIndex] = {
                    Script = typeof(tempScript) == "Instance" and cloneref(tempScript),
                    Type = funcInfo.what,
                    LineNumber = getinfo(funcInfo.func).currentline,
                    FunctionName = funcInfo.name,
                    ParameterCount = funcInfo.numparams,
                    IsVarArg = varArg,
                    UpvalueCount = funcInfo.nups
                }
            end
        end

        return newCallStack
    end

    local function processReturnValue(...)
        return {...}, select("#", ...)
    end  

    local oldFireServer
    oldFireServer = hookfunction(Instance.new("RemoteEvent").FireServer, newcclosure(function(remote: RemoteEvent, ...)

        if not checkparallel() then
            local argSize = select("#", ...)
            if typeof(remote) == "Instance" and remote.ClassName == "RemoteEvent" and argSize < 7996 then
                local oldLevel = get_thread_identity()
                set_thread_identity(3)
                local cloneRemote = cloneref(remote)
                local remoteID = get_debug_id(cloneRemote)
                set_thread_identity(oldLevel)

                mainChannel:Fire(channelKey, 0, "checkIgnored", remoteID)
                mainChannel:Fire(channelKey, 0, "checkBlocked", remoteID)

                if not isRemoteIgnored then
                    data = {...}
                    local deSanitizePaths = sanitizeData(data, -1)
                    if deSanitizePaths then
                        local scr = getcallingscript()
                        mainChannel:Fire(channelKey, 0, "sendMetadata", "addCall", cloneRemote, remoteID, nil, scr and cloneref(scr), createCallStack(2))
                        argChannel:Fire(unpack(data, 1, argSize))
                        desanitizeData(deSanitizePaths)
                    end
                end

                if isRemoteBlocked then
                    return
                end
            end
        end

        return oldFireServer(remote, ...)
    end))

    local oldInvokeServer
    oldInvokeServer = hookfunction(Instance.new("RemoteFunction").InvokeServer, newcclosure(function(remote: RemoteFunction, ...)

        if not checkparallel() then
            local argSize = select("#", ...)
            if typeof(remote) == "Instance" and remote.ClassName == "RemoteFunction" and argSize < 7996 then
                local oldLevel = get_thread_identity()
                set_thread_identity(3)
                local cloneRemote = cloneref(remote)
                local remoteID = get_debug_id(cloneRemote)
                set_thread_identity(oldLevel)

                mainChannel:Fire(channelKey, 0, "checkIgnored", remoteID)
                mainChannel:Fire(channelKey, 0, "checkBlocked", remoteID)

                if not isRemoteIgnored then
                    callCount += 1
                    local returnKey = channelKey.."|"..callCount

                    data = {...}
                    local deSanitizePaths = sanitizeData(data, -1)
                    if deSanitizePaths then
                        local scr = getcallingscript()
                        mainChannel:Fire(channelKey, 0, "sendMetadata", "addCall", cloneRemote, remoteID, returnKey, scr and cloneref(scr), createCallStack(2))
                        argChannel:Fire(unpack(data, 1, argSize))
                        desanitizeData(deSanitizePaths)

                        if isRemoteBlocked then
                            return
                        else
                            local thread = coroutine_running()
                            
                            task_spawn(function(...)
                                local returnData, returnDataSize = processReturnValue(oldInvokeServer(remote, ...))
                                local desanitizeReturnData = partiallySanitizeData(returnData)
                                mainChannel:Fire(channelKey, 0, "sendMetadata", "updateReturnValue", returnKey)
                                argChannel:Fire(unpack(returnData, 1, returnDataSize))
                                desanitizeData(desanitizeReturnData)
                                coroutine_resume(thread, unpack(returnData, 1, returnDataSize))
                            end, ...)

                            return coroutine_yield()
                        end
                    else
                        if isRemoteBlocked then
                            return
                        end
                    end
                else
                    if isRemoteBlocked then
                        return
                    end
                end
            end
        end

        return oldInvokeServer(remote, ...)
    end))

    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(remote: Instance, ...)

        if not checkparallel() then
            local argSize = select("#", ...)
            if typeof(remote) == "Instance" and argSize < 7996 then
                local namecallMethod: string = tostring(getnamecallmethod())
                local className: string = remote.ClassName

                if className == "RemoteEvent" and (namecallMethod == "FireServer" or namecallMethod == "fireServer") then
                    local oldLevel = get_thread_identity()
                    set_thread_identity(3)
                    local cloneRemote = cloneref(remote)
                    local remoteID = get_debug_id(cloneRemote)
                    set_thread_identity(oldLevel)
                    
                    mainChannel:Fire(channelKey, 0, "checkIgnored", remoteID)
                    mainChannel:Fire(channelKey, 0, "checkBlocked", remoteID)

                    if not isRemoteIgnored then
                        local data = {...}
                        local deSanitizePaths = sanitizeData(data, -1)
                        
                        if deSanitizePaths then
                            local scr = getcallingscript()
                            mainChannel:Fire(channelKey, 0, "sendMetadata", "addCall", cloneRemote, remoteID, nil, scr and cloneref(scr), createCallStack(2))
                            argChannel:Fire(unpack(data, 1, argSize))
                            desanitizeData(deSanitizePaths)
                        end
                    end
                    
                    if isRemoteBlocked then
                        return
                    end
                elseif className == "RemoteFunction" and (namecallMethod == "InvokeServer" or namecallMethod == "invokeServer") then
                    local oldLevel = get_thread_identity()
                    set_thread_identity(3)
                    local cloneRemote = cloneref(remote)
                    local remoteID = get_debug_id(cloneRemote)
                    set_thread_identity(oldLevel)

                    mainChannel:Fire(channelKey, 0, "checkIgnored", remoteID)
                    mainChannel:Fire(channelKey, 0, "checkBlocked", remoteID)

                    if not isRemoteIgnored then
                        callCount += 1
                        local returnKey = channelKey.."|"..callCount

                        local data = {...}
                        local deSanitizePaths = sanitizeData(data, -1)
                        if deSanitizePaths then
                            local scr = getcallingscript()
                            mainChannel:Fire(channelKey, 0, "sendMetadata", "addCall", cloneRemote, remoteID, returnKey, scr and cloneref(scr), createCallStack(2))
                            argChannel:Fire(unpack(data, 1, argSize))
                            desanitizeData(deSanitizePaths)
                    
                            if isRemoteBlocked then
                                return
                            else
                                local thread = coroutine_running()
                                
                                task_spawn(function(...)
                                    setnamecallmethod(namecallMethod)
                                    local returnData, returnDataSize: number = processReturnValue(oldInvokeServer(remote, ...))
                                    local desanitizeReturnData = partiallySanitizeData(returnData)
                                    mainChannel:Fire(channelKey, 0, "sendMetadata", "updateReturnValue", returnKey)
                                    argChannel:Fire(unpack(returnData, 1, returnDataSize))
                                    desanitizeData(desanitizeReturnData)
                                    coroutine_resume(thread, unpack(returnData, 1, returnDataSize))
                                end, ...)

                                return coroutine_yield()
                            end
                        else
                            if isRemoteBlocked then
                                return
                            end
                        end
                    else
                        if isRemoteBlocked then
                            return
                        end
                    end
                end
                
                setnamecallmethod(namecallMethod)
                return oldNamecall(remote, ...)
            end
        end
        
        return oldNamecall(remote, ...)
    end))
end
]]

local currentChannelNumber = 0 -- use this to make "channelKeys" aka a unique identifier for each channel, 0 != "0"
local function handleActor(actor: Actor)
    currentChannelNumber += 1
    syn.run_on_actor(actor, hookCode, argChannelID .. "|" .. mainChannelID .. "|" .. currentChannelNumber.. "|" .. CallStackLimit)
end

function Backend.initiateModule(BlockedList, IgnoredList, CallStackLimit)
    ignoredList = IgnoredList
    blockedList = BlockedList

    syn.on_actor_created:Connect(handleActor)

    loadstring(hookCode)(argChannelID .. "|" .. mainChannelID .. "|" .. currentChannelNumber .. "|" .. CallStackLimit) -- load the global state (channel 0)
    for _, v in next, getactors() do
        handleActor(v)
    end
end

function Backend.sendCommand(command: string, ...)
    mainChannel:Fire("0", "-1", command, ...)
end

Backend.initiateModule({}, {}, 10)

return Backend
