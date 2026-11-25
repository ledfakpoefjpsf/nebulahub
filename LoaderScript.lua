
local Repo = "https://raw.githubusercontent.com/USERNAME/REPOSITORY/main/game/"

local Games = {
    [10769787444] = { Name = "Above", File = "Aboverb.lua" },
    [10769552054] = { Name = "Urban Reload", File = "urban%20reload.lua" },
    [10767494536] = { Name = "Hike For Eggs", File = "hikeforeggs" },
    [10766972131] = { Name = "Throw Food For Animals", File = "ThrowFoodForAnimals" },
    [10772281976] = { Name = "Unstable SMP FFA", File = "unstable%20smp%20ffa" },
    [7174773198] = { Name = "Vox Seas", File = "Voxseas.lua" },
}

local function Notify(message)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Nebula Hub",
            Text = message,
            Duration = 8
        })
    end)
end

local info = Games[game.GameId]

if not info then
    Notify("This game is not supported yet.")
    warn("[Nebula Hub] Unsupported Game ID: " .. tostring(game.GameId))
    return
end

local url = Repo .. info.File

local success, result = pcall(function()
    local response = game:HttpGet(url)
    assert(type(response) == "string" and #response > 0, "Empty download")

    local scriptFunction, compileError = loadstring(response)
    assert(scriptFunction, compileError or "Compilation failed")

    scriptFunction()
end)

if not success then
    Notify("Failed to load " .. info.Name)
    warn("[Nebula Hub] " .. tostring(result))
else
    Notify(info.Name .. " loaded successfully!")
end
