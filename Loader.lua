local loader = "https://raw.githubusercontent.com/GameGuyThrowaway/Synapse-V2-Remotespy/main/Loader.lua"

local mainSourceFolder = "https://raw.githubusercontent.com/GameGuyThrowaway/Synapse-V2-Remotespy/main/Source/"

local loadedModules = {}
local function require(moduleName)
    local module = loadedModules[moduleName]
    if module then
        return module
    else
        local newModule = loadstring(game:HttpGetAsync(mainSourceFolder .. moduleName), moduleName)()
        loadedModules[moduleName] = newModule
        return newModule
    end
end

loadstring(game:HttpGetAsync(loader))(require) -- load core, passing require function
