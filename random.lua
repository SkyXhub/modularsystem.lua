local scripts = {
    [13772394625] = "https://raw.githubusercontent.com/SkyXhub/Main.games/main/bladeball.lua",
    [286090429] = "https://raw.githubusercontent.com/SkyXhub/Main.games/main/Arsenal.lua",
    [142823291] = "https://raw.githubusercontent.com/SkyXhub/Main.games/main/MurderMystery2.lua",
    [6284583030] = "https://raw.githubusercontent.com/SkyXhub/Main.games/main/petsimx.lua",
    [9872472334] = "https://raw.githubusercontent.com/SkyXhub/Main.games/main/evade.lua",
    [703124385] = "https://raw.githubusercontent.com/SkyXhub/Main.games/main/FleeTheFacility.lua",
    [189707] = "https://raw.githubusercontent.com/SkyXhub/Main.games/main/NaturalDisaster.lua"
}

local function loadGameScript()
    local gameId = game.PlaceId
    local scriptUrl = scripts[gameId]

    if scriptUrl then
        local response = game:HttpGet(scriptUrl)
        loadstring(response)()
        print("Loaded script for " .. game:GetService("MarketplaceService"):GetProductInfo(gameId).Name)
    else
        print("No script available for this game.")
    end
end

loadGameScript()
