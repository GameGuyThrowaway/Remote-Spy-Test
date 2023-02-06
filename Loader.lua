local mainSourceFolder = "https://raw.githubusercontent.com/GameGuyThrowaway/Remotespy-Test/main/Source/"
local coreModule = mainSourceFolder .. "Core.lua"

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

loadstring(game:HttpGetAsync(coreModule))(require) -- load core, passing require function
