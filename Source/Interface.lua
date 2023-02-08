local interfaceModule = {}

local EventPipe

function interfaceModule.setupSignals(TaskSignal)
    assert(not EventPipe, "Signals Already Setup")
    
    EventPipe = TaskSignal.new({
        -- incoming data
        'onNewCall',
        'onReturnValueUpdated',

        -- outgoing data
        'onRemoteBlocked', 
        'onRemoteIgnored',
        'onCallStackLimitChanged', 

        -- core requests
        'generatePseudocode',
        'generatePseudoCallStack',
        'generatePseudoReturnValue',
        'getCallingScriptPath',
        'decompileCallingScript',
        'getRemotePath',
        'repeatCall',
        'clearRemoteCalls'
    })

    do -- initialize incoming requests
        EventPipe:ListenToEvent('onNewCall', function(remoteID: string, call)
            rconsolewarn("New Call: " .. remoteID .. " | " .. call.ArgCount)
        end)

        EventPipe:ListenToEvent('onReturnValueUpdated', function(remoteID: string, call)
            rconsolewarn("New ReturnValue: " .. remoteID .. " | " .. call.ReturnCount)
        end)
    end

    interfaceModule.EventPipe = EventPipe
end

return interfaceModule