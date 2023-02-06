local SettingsModule = {}

local httpService = cloneref(game:GetService("HttpService"))

local defaultSettings = {
    FireServer = true,
    InvokeServer = true,

    GetCallStack = false,
    CallStackSizeLimit = 10,
    MakeCallingScriptUseCallStack = false,
    CallStackOptions = {
        Script = true,
        Type = true,
        LineNumber = true,
        FunctionName = true,

        ParameterCount = false,
        IsVararg = false,
        UpvalueCount = false
    },

    PseudocodeLuaUTypes = false,
    PseudocodeWatermark = true,
    PseudocodeFormatTables = true,
    PsuedocodeHiddenNils = false,
    PseudocodeInlining = {
        boolean = false,
        number = false,
        string = false,
        table = true,
        userdata = true,

        Remote = false,
        HiddenNils = false
    }
}

SettingsModule.Settings = defaultSettings
local Settings = SettingsModule.Settings -- localize the Settings table

function SettingsModule.loadSettings()
    if not isfolder("wavespy") then
        makefolder("wavespy")
    end
    if not isfile("wavespy/Settings.json") then
        SettingsModule.saveSettings()
        return
    end

    local tempSettings = httpService:JSONDecode(readfile("wavespy/Settings.json"))
    for i,v in next, tempSettings do -- this is in case I add new settings
        if type(Settings[i]) == type(v) then
            Settings[i] = v
        end
    end
end

function SettingsModule.saveSettings()
    if not isfolder("wavespy") then
        makefolder("wavespy")
    end
    writefile("wavespy/Settings.json", httpService:JSONEncode(Settings))
end

return SettingsModule
