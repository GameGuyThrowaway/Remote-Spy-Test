local PseudocodeGenerator = {}

local str_sub = string.sub
local str_gsub = string.gsub
local str_rep = string.rep
local str_match = string.match
local str_format = string.format
local str_split = string.split
local str_lower = string.lower
local table_insert = table.insert
local get_debug_id = game.GetDebugId
local set_thread_identity = syn.set_thread_identity
local get_thread_identity= syn.get_thread_identity

local Settings, InlineSettings, CallStackSettings -- Table of current user settings
local tableToString, getInstancePath -- localize function


local Players = cloneref(game:GetService("Players"))
local gameId, workspaceId, clientId, clientUserId = get_debug_id(game), get_debug_id(workspace), Players.LocalPlayer and get_debug_id(Players.LocalPlayer), Players.LocalPlayer and Players.LocalPlayer.UserId
local inf, neginf = 1/0, -1/0
local watermarkString = "--Pseudocode Generated by wavespy\n\n"

local asciiFilteredCharacters = {
    ["\""] = "\\\"",
    ["\\"] = "\\\\",
    ["\a"] = "\\a",
    ["\b"] = "\\b",
    ["\t"] = "\\t",
    ["\n"] = "\\n",
    ["\v"] = "\\v",
    ["\f"] = "\\f",
    ["\r"] = "\\r"
}

local makeUserdataConstructor = {
    Axes = function(original: Axes): Axes
        local constructor: string = "Axes.new("
        if original.X and not original.Left and not original.Right then
            constructor ..= "Enum.Axis.X, "
        elseif original.Left then
            constructor ..= "Enum.NormalId.Left, "
        end
        if original.Right then
            constructor ..= "Enum.NormalId.Right, "
        end

        if original.Y and not original.Top and not original.Bottom then
            constructor ..= "Enum.Axis.Y, "
        elseif original.Top then
            constructor ..= "Enum.NormalId.Top, "
        end
        if original.Bottom then
            constructor ..= "Enum.NormalId.Bottom, "
        end

        if original.Z and not original.Front and not original.Back then
            constructor ..= "Enum.Axis.Z, "
        elseif original.Front then
            constructor ..= "Enum.NormalId.Front, "
        end
        if original.Back then
            constructor ..= "Enum.NormalId.Back, "
        end

        return (constructor ~= "Axes.new(" and str_sub(constructor, 0, -3) or constructor) .. ")"
    end,
    BrickColor = function(original: BrickColor): string
        return "BrickColor.new(\"" .. original.Name .. "\")"
    end,
    CatalogSearchParams = function(original: CatalogSearchParams): string
        return str_format("(function() local clone: CatalogSearchParams = CatalogSearchParams.new() clone.AssetTypes = %s clone.BundleTimes = %s clone.CategoryFilter = %s clone.MaxPrice = %s clone.MinPrice = %s clone.SearchKeyword = %s clone.SortType = %s return clone end)()", tostring(original.AssetTypes), tostring(original.BundleTypes), tostring(original.CategoryFilter), original.MaxPrice, original.MinPrice, original.SearchKeyword, tostring(original.SortType))
    end,
    CFrame = function(original: CFrame): string
        return "CFrame.new(" .. tostring(original) .. ")"
    end,
    Color3 = function(original: Color3): string
        return "Color3.new(" .. tostring(original) .. ")"
    end,
    ColorSequence = function(original: ColorSequence): string
        return "ColorSequence.new(" .. tableToString(original.Keypoints, false) ..")"
    end,
    ColorSequenceKeypoint = function(original: ColorSequenceKeypoint): string
        return "ColorSequenceKeypoint.new(" .. original.Time .. ", Color3.new(" .. tostring(original.Value) .. "))"
    end,
    DateTime = function(original: DateTime): string
        return "DateTime.fromUnixTimestamp(" .. tostring(original.UnixTimestamp) .. ")"
    end,
    DockWidgetPluginGuiInfo = function(original: DockWidgetPluginGuiInfo): string
        local arguments = str_split(tostring(original), " ")
        local dockState: string = str_sub(arguments[1], 18, -1)
        local initialEnabled: boolean = tonumber(str_sub(arguments[2], 16, -1)) ~= 0
        local initialShouldOverride: boolean = tonumber(str_sub(arguments[3], 38, -1)) ~= 0
        local floatX: number = tonumber(str_sub(arguments[4], 15, -1)) 
        local floatY: number = tonumber(str_sub(arguments[5], 15, -1))
        local minWidth: number = tonumber(str_sub(arguments[6], 10, -1))
        local minHeight: number = tonumber(str_sub(arguments[7], 11, -1))
        -- can't read the properties so i have to tostring first :(
            
        return str_format("DockWidgetPluginGuiInfo.new(%s, %s, %s, %s, %s, %s, %s)", "Enum.InitialDockState." .. dockState, tostring(initialEnabled), tostring(initialShouldOverride), tostring(floatX), tostring(floatY), tostring(minWidth), tostring(minHeight))
    end,
    Enum = function(original: Enum): string
        return "Enum." .. tostring(original)
    end,
    EnumItem = function(original: EnumItem): string
        return tostring(original)
    end,
    Enums = function(original: Enums): string
        return "Enum"
    end,
    Faces = function(original: Faces): string
        local constructor = "Faces.new("
        if original.Top then
            constructor ..= "Enum.NormalId.Top"
        end
        if original.Bottom then
            constructor ..= "Enum.NormalId.Bottom"
        end
        if original.Left then
            constructor ..= "Enum.NormalId.Left"
        end
        if original.Right then
            constructor ..= "Enum.NormalId.Right"
        end
        if original.Back then
            constructor ..= "Enum.NormalId.Back"
        end
        if original.Front then
            constructor ..= "Enum.NormalId.Front"
        end

        return (constructor ~= "Faces.new(" and str_sub(constructor, 0, -3) or constructor) .. ")"
    end,
    FloatCurveKey = function(original: FloatCurveKey): string
        return "FloatCurveKey.new(" .. tostring(original.Time) .. ", " .. tostring(original.Value) .. ", "  .. tostring(original.Interpolation) .. ")"
    end,
    Font = function(original: Font): string
        return str_format("(function() local clone: Font = Font.new(%s, %s, %s) clone.Bold = %s return clone end)()", '"' .. original.Family .. '"', tostring(original.Weight), tostring(original.Style), tostring(original.Bold))
    end,
    Instance = function(original: Instance): string
        return getInstancePath(original)
    end,
    NumberRange = function(original: NumberRange): string
        return "NumberRange.new(" .. tostring(original.Min) .. ", " .. tostring(original.Max) .. ")"
    end,
    NumberSequence = function(original: NumberSequence): string
        return "NumberSequence.new(" .. tableToString(original.Keypoints, false) .. ")"
    end,
    NumberSequenceKeypoint = function(original: NumberSequenceKeypoint): string
        return "NumberSequenceKeypoint.new(" .. tostring(original.Time) .. ", " .. tostring(original.Value) .. ", " .. tostring(original.Envelope) .. ")"
    end,
    OverlapParams = function(original: OverlapParams): OverlapParams
        return str_format("(function(): OverlapParams local clone: OverlapParams = OverlapParams.new() clone.CollisionGroup = %s clone.FilterDescendantInstances = %s clone.FilterType = %s clone.MaxParts = %s return clone end)()", original.CollisionGroup, tableToString(original.FilterDescendantsInstances, false, Settings.InstanceTrackerMode), tostring(original.FilterType), tostring(original.MaxParts))
    end,
    PathWaypoint = function(original: PathWaypoint): string
        return "PathWaypoint.new(Vector3.new(" .. tostring(original.Position) .. "), " .. tostring(original.Action) .. ")"
    end,
    PhysicalProperties = function(original: PhysicalProperties): string
        return "PhysicalProperties.new(" .. tostring(original) .. ")"
    end,
    Random = function(original: Random): string
        return "Random.new()" -- detectable cause of seed change
    end,
    Ray = function(original: Ray): string
        return "Ray.new(Vector3.new(" .. tostring(original.Origin) .. "), Vector3.new(" .. tostring(original.Direction) .. "))"
    end,
    RaycastParams = function(original: RaycastParams): string
        return str_format("(function(): RaycastParams local clone: RaycastParams = RaycastParams.new() clone.CollisionGroup = %s clone.FilterDescendantsInstances = %s clone.FilterType = %s clone.FilterWater = %s return clone end)()", original.CollisionGroup, tableToString(original.FilterDescendantsInstances, false, Settings.InstanceTrackerMode), tostring(original.FilterType), tostring(original.IgnoreWater))
    end,
    RaycastResult = function(original: RaycastResult): string
        return str_format("(function(): RaycastParams local params: RaycastParams = RaycastParams.new() params.IgnoreWater = %s params.FilterType = %s params.FilterDescendantsInstances = %s local startPos: Vector3 = %s return workspace:Raycast(startPos, CFrame.lookAt(startPos, %s).LookVector*math.ceil(%s), params) end)()", tostring(original.Material.Name ~= "Water"), tostring(Enum.RaycastFilterType.Whitelist), tableToString(original.Instance, false, Settings.InstanceTrackerMode), "Vector3.new(" .. original.Position+(original.Distance*original.Normal) .. ")", "Vector3.new(" .. original.Position .. ")", "Vector3.new(" .. original.Distance .. ")")
    end,
    RBXScriptConnection = function(original: RBXScriptConnection): string
        return "nil --[[ RBXScriptConnection is Unsupported ]]"
    end,
    RBXScriptSignal = function(original: RBXScriptSignal): string
        return "nil --[[ RBXScriptSignal is Unsupported ]]"
    end,
    Rect = function(original: Rect): string
        return "Rect.new(Vector2.new(" .. tostring(original.Min) .. "), Vector2.new(" .. tostring(original.Max) .. "))"
    end,
    Region3 = function(original: Region3): string
        local center = original.CFrame.Position

        return "Region3.new(Vector3.new(" .. tostring(center-original.Size/2) .. "), Vector3.new(" .. tostring(center+original.Size/2) .. "))"
    end,
    Region3int16 = function(original: Region3int16): string
        return "Region3int16.new(Vector3int16.new(" .. tostring(original.Min) .. "), Vector3int16.new(" .. tostring(original.Max) .. "))"
    end,
    RotationCurveKey = function(original: RotationCurveKey): RotationCurveKey
        return "RotationCurveKey.new(" .. tostring(original.Time) .. ", CFrame.new(" .. tostring(original.Value) .. "), " .. tostring(original.Interpolation) .. ")"
    end,
    TweenInfo = function(original: TweenInfo): string
        return "TweenInfo.new(" .. tostring(original.Time) .. ", " .. tostring(original.EasingStyle) .. ", " .. tostring(original.EasingDirection) .. ", " .. tostring(original.RepeatCount) .. ", " .. tostring(original.Reverses) .. ", " .. tostring(original.DelayTime) .. ")"
    end,
    UDim = function(original: UDim): string
        return "UDim.new(" .. tostring(original) .. ")"
    end,
    UDim2 = function(original: UDim2): string
        return "UDim2.new(" .. tostring(original) .. ")"
    end,
    userdata = function(original): string -- no typechecking for userdatas like this (newproxy)
        return "nil --[[ " .. tostring(original) .. " is Unsupported ]]" -- newproxies can never be sent, and as such are reserved by the remotespy to be used when a type that could not be deepCloned was sent.  The tostring metamethod should've been modified to refelct the original type.
    end,
    Vector2 = function(original: Vector2): string
        return "Vector2.new(" .. tostring(original) .. ")"
    end,
    Vector2int16 = function(original: Vector2int16): string
        return "Vector2int16.new(" .. tostring(original) .. ")"
    end,
    Vector3 = function(original: Vector3): string
        return "Vector3.new(" .. tostring(original) .. ")"
    end,
    Vector3int16 = function(original: Vector3int16): string
        return "Vector3int16.new(" .. tostring(original) .. ")"
    end
}



local function purifyString(str: string, quotes: boolean)
    str = str_gsub(str, "[\"\\\0-\31\127-\255]", asciiFilteredCharacters)
    --[[
        This gsub can be broken down into multiple steps.
        It filters quotations (\") and backslashes "\\" to be replaced,
        Then it filters characters 0-31, and 127-255, replacing them all with their escape sequences
    ]]
    if quotes then
        return "\"" .. str .. "\""
    else
        return str
    end
end

local function getUserdataConstructor(userdata: any): string
    local userdataType = typeof(userdata)
    local constructorCreator = makeUserdataConstructor[userdataType]

    if constructorCreator then
        return constructorCreator(userdata)
    else
        return "nil --[[ " .. userdataType .. " is Unsupported ]]"
    end
end

tableToString = function(data: any, convertIndices: boolean, format: boolean, root: any, indents: number)
    local dataType = type(data)
    format = (format == nil) or format

    if dataType == "userdata" or dataType == "vector" then
        if typeof(data) == "Instance" then
            return getInstancePath(data)
        else
            return getUserdataConstructor(data)
        end
    elseif dataType == "string" then
        return purifyString(data, true)
    elseif dataType == "table" then
        indents = indents or 1
        root = root or data

        local head = format and '{\n' or '{ '
        local indent = str_rep('\t', indents)
        local consecutiveIndices = (#data ~= 0)
        local elementCount = 0

        if format then
            if consecutiveIndices then
                for i,v in next, data do
                    elementCount += 1
                    if type(i) ~= "number" then continue end

                    if i ~= elementCount then
                        for _ = 1, (i-elementCount) do
                            head ..= (indent .. "nil,\n")
                        end
                        elementCount = i
                    end
                    head ..= str_format("%s%s,\n", indent, tableToString(v, true, root, indents + 1))
                end
            else
                for i,v in next, data do
                    head ..= str_format("%s[%s] = %s,\n", indent, tableToString(i, true, root, indents + 1), tableToString(v, true, root, indents + 1))
                end
            end
        else
            if consecutiveIndices then
                for i,v in next, data do
                    elementCount += 1
                    if type(i) ~= "number" then continue end

                    if i ~= elementCount then
                        for _ = 1, (i-elementCount) do
                            head ..= "nil, "
                        end
                        elementCount = i
                    end
                    head ..= (tableToString(v, false, root, indents + 1) .. ", ")
                end
            else
                for i,v in next, data do
                    head ..= str_format("[%s] = %s, ", tableToString(i, false, root, indents + 1), tableToString(v, false, root, indents + 1))
                end
            end
        end
        
        if format then
            return #head > 2 and str_format("%s\n%s", str_sub(head, 1, -3), str_rep('\t', indents - 1) .. '}') or "{}"
        else
            return #head > 2 and (str_sub(head, 1, -3) .. ' }') or "{}"
        end
    elseif dataType == "number" then
        local dataStr = tostring(data)
        if not str_match(dataStr, "%d") then
            if data == inf then
                return "(1/0)"
            elseif data == neginf then
                return "(-1/0)"
            elseif dataStr == "nan" then
                return "(0/0)"
            else
                return ("tonumber(\"" .. dataStr .. "\")")
            end
        else
            return dataStr
        end
    else
        return tostring(data)
    end
end

local function isInstanceParentedToNil(instance: Instance)
    local ID = get_debug_id(instance)

    for _,v in next, getnilinstances() do
        if get_debug_id(v) == ID then
            return true
        end
    end

    return false
end

local function customToString(data: any)
    local dataType = type(data)
    if dataType == "string" then
        return purifyString(data, true), 0
    elseif dataType == "userdata" then
        return getUserdataConstructor(data)
    elseif dataType == "table" then
        return tableToString(data, false, false), 0
    elseif dataType == "number" or dataType == "boolean" then
        return tostring(data), 0
    else -- handles threads and functions
        return "(nil) --[[ " .. tostring(data) .. " ]]"
    end
end

local function getInstancePath(instance: Instance)
    local old = get_thread_identity()
    set_thread_identity(3)
    local id = get_debug_id(instance) -- cloneref moment
    set_thread_identity(old)

    local name = instance.Name
    local head = (#str_gsub(name, "[%a_]", "") > 0 and ("[" .. purifyString(name, true) .. "]")) or (#name > 0 and '.' .. name) or "['']"

    if not instance.Parent and id ~= gameId then
        return "(nil)" .. head .. (isInstanceParentedToNil(instance) and " --[[ INSTANCE PARENTED TO NIL ]]" or " --[[ INSTANCE DELETED ]]")
    else
        if id == gameId then
            return "game"
        elseif id == workspaceId then
            return "workspace"
        elseif id == clientId then
            return 'game:GetService("Players").LocalPlayer'
        else
            local plr = Players:GetPlayerFromCharacter(instance)
            if plr then
                if plr.UserId == clientUserId then
                    return 'game:GetService("Players").LocalPlayer.Character'
                else
                    if tonumber(str_sub(plr.Name, 1, 1)) then
                        return 'game:GetService("Players")["'..plr.Name..'"]".Character'
                    else
                        return 'game:GetService("Players").'..plr.Name..'.Character'
                    end
                end
            end
            local _success, result = pcall(game.GetService, game, instance.ClassName)

            if _success and result then
                return 'game:GetService("' .. instance.ClassName .. '")'
            end
        end
    end

    return (getInstancePath(instance.Parent) .. head)
end



function PseudocodeGenerator.initiateModule(settings)
    Settings = settings
    InlineSettings = Settings.PseudocodeInlining
    CallStackSettings = Settings.CallStackOptions

    for Index = 0, 255 do
        if (Index < 32 or Index > 126) then -- only non printable ascii characters
            local character = string.char(Index)
            if not asciiFilteredCharacters[character] then
                asciiFilteredCharacters[character] = "\\" .. Index
            end
        end
    end

    if not clientId then
        task.spawn(function()
            while not clientId do
                clientId = get_debug_id(Players.LocalPlayer)
                clientUserId = Players.LocalPlayer.UserId
                task.wait()
            end
        end)
    end
end

PseudocodeGenerator.getInstancePath = getInstancePath

function PseudocodeGenerator.generateCode(remote: Instance, call)
    local watermark = Settings.PseudocodeWatermark and watermarkString or ""

    local pathStr = getInstancePath(remote)
    local remType = remote.ClassName
    local argCount = #call.Args
    local nilCount = call.ArgCount - argCount
    local retValCount = call.ReturnValue and #call.ReturnValue or -1

    if call.ArgCount == 0 or (argCount == 0 and not Settings.PseudocodeHiddenNils) then
        local pseudocode = ""
        if InlineSettings.Remote then
            pseudocode = ("local remote" .. (Settings.PseudocodeLuaUTypes and (": " .. remType) or "") .. " = " .. pathStr .. "\n")
            if remType == "RemoteEvent" then
                pseudocode ..= "remote:FireServer()"
            elseif retValCount > 0 then
                pseudocode ..= "local "
                for i = 1, retValCount do
                    pseudocode ..= ("returnValue" .. i .. ", ")
                end
                pseudocode = (str_sub(pseudocode, 1, -3) .. " = remote:InvokeServer()")
            else
                pseudocode ..= "remote:InvokeServer()"
            end
        else
            if remType == "RemoteEvent" then
                pseudocode = (pathStr .. ":FireServer()")
            elseif retValCount > 0 then
                pseudocode = "local "
                for i = 1, retValCount do
                    pseudocode ..= ("returnValue" .. i .. ", ")
                end
                pseudocode = (str_sub(pseudocode, 1, -3) .. " = " .. pathStr .. ":InvokeServer()")
            else
                pseudocode = (pathStr .. ":InvokeServer()")
            end
        end

        return watermark .. pseudocode
    else
        local argCalls = {}
        local argCallCount = {}

        local pseudocode = ""

        local atLeastOneInline = false

        for i = 1, argCount do
            local arg = call.Args[i]
            local primTyp = type(arg)
            if primTyp == "vector" then primTyp = "userdata" end
            local tempTyp = typeof(arg)
            local typ = (str_gsub(tempTyp, "^%u", str_lower))

            argCallCount[typ] = argCallCount[typ] and argCallCount[typ] + 1 or 1

            local varName = typ .. tostring(argCallCount[typ])

            if primTyp == "nil" then
                table_insert(argCalls, { primTyp, "nil, ", "" })
                continue
            end
            
            local varPrefix = ""
            if primTyp ~= "table" and Settings.PseudocodeLuaUTypes then
                varPrefix = "local " .. varName .. ": ".. tempTyp .." = "
            else
                varPrefix = "local " .. varName .." = "
            end
            local varConstructor = ""

            if primTyp == "userdata" then -- roblox should just get rid of vector already
                if typeof(arg) == "Instance" then
                    varConstructor = getInstancePath(arg)
                else
                    varConstructor = getUserdataConstructor(arg)
                end
            elseif primTyp == "table" then
                varConstructor = tableToString(arg, Settings.PseudocodeFormatTables)
            elseif primTyp == "string" then
                varConstructor = purifyString(arg, true)
            elseif primTyp == "number" then
                local dataStr = tostring(arg)
                if not str_match(dataStr, "%d") then
                    if arg == inf then
                        varConstructor = "(1/0)"
                    elseif arg == neginf then
                        varConstructor = "(-1/0)"
                    elseif dataStr == "nan" then
                        varConstructor = "(0/0)"
                    else
                        varConstructor = ("tonumber(\"" .. dataStr .. "\")")
                    end
                else
                    varConstructor = dataStr
                end
            else
                varConstructor = tostring(arg)
            end

            table_insert(argCalls, { primTyp, varConstructor, varName })

            if InlineSettings[primTyp] then
                pseudocode ..= (varPrefix .. (varConstructor .. "\n"))
                atLeastOneInline = true
            end
        end

        if Settings.PsuedocodeHiddenNils and InlineSettings.HiddenNils then 
            for i = 1, nilCount do
                pseudocode ..= "local hiddenNil" .. tostring(i) .. " = nil\n"
                atLeastOneInline = true
            end
        end

        if atLeastOneInline then
            pseudocode ..= "\n"
        end

        if InlineSettings.Remote then
            pseudocode ..= ("local remote" .. (Settings.PseudocodeLuaUTypes and (": " .. remType) or "") .. " = " .. pathStr .. "\n")
            if remType == "RemoteEvent" then
                pseudocode ..= "remote:FireServer("
            elseif retValCount > 0 then
                pseudocode ..= "local "
                for i = 1, retValCount do
                    pseudocode ..= ("returnValue" .. i .. ", ")
                end
                pseudocode = (str_sub(pseudocode, 1, -3) .. " = remote:InvokeServer(")
            else
                pseudocode ..= "remote:InvokeServer("
            end
        else
            if remType == "RemoteEvent" then
                pseudocode ..= (pathStr .. ":FireServer(")
            elseif retValCount > 0 then
                pseudocode = "local "
                for i = 1, retValCount do
                    pseudocode ..= ("returnValue" .. i .. ", ")
                end
                pseudocode = (str_sub(pseudocode, 1, -3) .. " = " .. pathStr .. ":InvokeServer(")
            else
                pseudocode ..= (pathStr .. ":InvokeServer(")
            end
        end

        for _,v in next, argCalls do
            if InlineSettings[v[1]] then
                pseudocode ..= (v[3] .. ", ")
            else
                pseudocode ..= (v[2] .. ", ")
            end
        end

        if Settings.PsuedocodeHiddenNils then
            if InlineSettings.HiddenNils then
                for i = 1, nilCount do
                    pseudocode ..= ("hiddenNil" .. tostring(i) .. ", ")
                end
            else
                for _ = 1, nilCount do
                    pseudocode ..= "nil, "
                end
            end
        end

        return watermark .. (str_sub(pseudocode, -2, -2) == "," and str_sub(pseudocode, 1, -3) or pseudocode) .. ")" -- sub gets rid of the last ", "
    end
end

function PseudocodeGenerator.generateCallStack(callStack)
    local callStackString = ""
    if Settings.PseudocodeWatermark then
        callStackString ..= watermarkString
    end

    callStackString ..= "local CallStack = {"
    for callIndex, call in next, callStack do
        callStackString ..= "\n\t[" .. callIndex .. "] = {"

        for dataType, data in next, call do
            if dataType == "FunctionName" and CallStackSettings[dataType] then
                local functionName = purifyString(data, true)
                if #functionName == 2 then -- 2 because purifyString adds quotes, so size 2 means just quotes, nothing else
                    callStackString ..= "\n\t\t[\"FunctionName\"] = " .. functionName .. ", --[[ ANONYMOUS FUNCTION ]]"
                else
                    callStackString ..= "\n\t\t[\"FunctionName\"] = " .. functionName .. ","
                end
            elseif CallStackSettings[dataType] then
                callStackString ..= "\n\t\t[\"" .. dataType .. "\"] = " .. customToString(data) .. ","
            end
        end

        callStackString = str_sub(callStackString, 1, -2) .. "\n\t},"
    end
    
    return (str_sub(callStackString, 1, -2) .. "\n}") -- get rid of the last "," and replace with \n}
end

function PseudocodeGenerator.generateReturnValue(returnValue)
    local watermark = Settings.PseudocodeWatermark and watermarkString or ""

    return watermark .. "local pseudoReturnValue = " .. tableToString(returnValue, false, true)
end

--[[
PseudocodeGenerator.initiateModule({
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
})

local str = PseudocodeGenerator.generatePseudoCallStack(_G.test)
setclipboard(str)
]]

return PseudocodeGenerator