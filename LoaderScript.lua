local Repo = "https://raw.githubusercontent.com/ledfakpoefjpsf/nebulahub/main/game/"

local Games = {
    [10769787444] = {Name = "Above", File = "Aboverb.lua"},
    [10769552054] = {Name = "Urban Reload", File = "urban%20reload.lua"},
    [10767494536] = {Name = "Hike For Eggs", File = "hikeforeggs"},
    [10766972131] = {Name = "Throw Food For Animals", File = "ThrowFoodForAnimals"},
    [10772281976] = {Name = "Unstable SMP FFA", File = "unstable%20smp%20ffa"},
    [7174773198] = {Name = "Vox Seas", File = "Voxseas.lua"}
}

local gameInfo = Games[game.GameId]

if not gameInfo then
    warn("[Nebula Hub] This game is not supported.")
    return
end

local url = Repo .. gameInfo.File

print("[Nebula Hub] Loading " .. gameInfo.Name)
print("[Nebula Hub] URL: " .. url)

local success, source = pcall(function()
    return game:HttpGet(url)
end)

if not success then
    warn("[Nebula Hub] Download failed: " .. tostring(source))
    return
end

if not source or #source < 10 then
    warn("[Nebula Hub] Downloaded file is empty.")
    return
end

local scriptFunction, compileError = loadstring(source)

if not scriptFunction then
    warn("[Nebula Hub] Compile error: " .. tostring(compileError))
    return
end

local ran, runtimeError = pcall(scriptFunction)

if not ran then
    warn("[Nebula Hub] Runtime error: " .. tostring(runtimeError))
end
