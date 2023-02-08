local mainSourceFolder = "https://raw.githubusercontent.com/GameGuyThrowaway/Remote-Spy-Test/main/Source/"
local coreModule = mainSourceFolder .. "Core.lua"

local loadedModules = {} -- used for caching loaded modules so that a module can be required twice and the same table will return both times
local function require(moduleName)
    local module = loadedModules[moduleName]
    if module then
        return module
    else
        local str = game:HttpGetAsync(mainSourceFolder .. moduleName)
        assert(str, "MODULE NOT FOUND")

        local func, err = loadstring(str, moduleName)
        assert(func, err)
        
        local newModule = func()
        loadedModules[moduleName] = newModule
        return newModule
    end
end

loadstring(game:HttpGetAsync(coreModule), "Core.lua")(require) -- load core, passing require function