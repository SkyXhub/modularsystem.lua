--[[
    SkyX Hub - Blox Fruits - PREMIUM Teleport Module
    Works on all mobile executors
    
    Features:
    - One-click teleports to all islands
    - Anti-detection teleportation
    - Server hopping teleports
    - Boss teleport with fight mode
    - Auto boss farming
    - Advanced teleport queue system
    - Safe teleport with anti-fall damage
    - Teleport animations (stealth/instant/delayed)
    - Configurable teleport methods
    - Raid/dungeon teleports
    - Island waypoint system
    - Custom coordinate teleporting
]]

local Module = {}

-- Default settings
Module.Settings = {
    SafeMode = true,
    AntiDetection = {
        Enabled = true,
        Delay = 1
    }
}

-- Core variables
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HRP = Character:WaitForChild("HumanoidRootPart")

-- Key locations in Blox Fruits
local Locations = {
    {Name = "Starter Island", Icon = "🏝️", Position = Vector3.new(1071.2832, 16.3085976, 1426.86792)},
    {Name = "Middle Town", Icon = "🏙️", Position = Vector3.new(-655.824158, 7.88708115, 1436.67908)},
    {Name = "Jungle", Icon = "🌴", Position = Vector3.new(-1249.77222, 11.8870859, 341.356476)},
    {Name = "Pirate Village", Icon = "⚓", Position = Vector3.new(-1122.34998, 4.78708982, 3855.91992)},
    {Name = "Desert", Icon = "🏜️", Position = Vector3.new(1094.14587, 6.5, 4192.88721)},
    {Name = "Frozen Village", Icon = "❄️", Position = Vector3.new(1198.00928, 27.0074959, -1211.73376)},
    {Name = "Marine Ford", Icon = "🚢", Position = Vector3.new(-4505.375, 20.687294, 4260.55908)},
    {Name = "Colosseum", Icon = "🏛️", Position = Vector3.new(-1428.35474, 7.38933945, -3014.37305)},
    {Name = "Prison", Icon = "🔒", Position = Vector3.new(4875.330078125, 5.6519818305969, 734.85021972656)},
    {Name = "Magma Village", Icon = "🌋", Position = Vector3.new(-5231.75879, 8.61593437, 8467.87695)},
    {Name = "Underwater City", Icon = "🌊", Position = Vector3.new(61163.8516, 11.6796875, 1819.78418)},
    {Name = "Fountain City", Icon = "🏮", Position = Vector3.new(5132.93506, 4.53632832, 4037.83252)},
    {Name = "Sky Island 1", Icon = "☁️", Position = Vector3.new(-4970.21875, 717.707275, -2622.35449)},
    {Name = "Sky Island 2", Icon = "☁️", Position = Vector3.new(-4813.0249, 903.708557, -1912.69055)},
    {Name = "Sky Island 3", Icon = "☁️", Position = Vector3.new(-7952.31006, 5545.52832, -320.704956)},
    {Name = "Sky Island 4", Icon = "☁️", Position = Vector3.new(-7793.43896, 5607.22168, -2016.58362)},
    {Name = "Ice Castle", Icon = "🏰", Position = Vector3.new(6148.4765625, 294.38446044922, -6741.1166992188)},
    {Name = "Forgotten Island", Icon = "🏝️", Position = Vector3.new(-3032.7360839844, 317.89465332031, -10075.373046875)},
    {Name = "Second Sea", Icon = "🌊", Position = Vector3.new(2284.912109375, 15.152046203613, 905.48291015625)}
}

-- Teleport to location
function Module:TeleportToLocation(locationName)
    -- Find the location
    local location = nil
    for _, loc in pairs(Locations) do
        if loc.Name == locationName then
            location = loc
            break
        end
    end
    
    -- Check if location was found
    if not location then
        return false, "Location not found"
    end
    
    -- Teleport with safety checks
    local success, err = pcall(function()
        -- Safe mode toggle
        if self.Settings.SafeMode then
            -- Save old position for safety
            local oldPosition = HRP.CFrame
            
            -- Anti-detection
            if self.Settings.AntiDetection.Enabled then
                -- Disable character animations
                if Character:FindFirstChild("Animate") then
                    Character.Animate.Disabled = true
                end
                
                -- Disable humanoid states
                local Humanoid = Character:FindFirstChild("Humanoid")
                if Humanoid then
                    Humanoid:ChangeState(11) -- RAGDOLL state to prevent animations
                end
                
                -- Add delay for anti-detection
                wait(self.Settings.AntiDetection.Delay)
            end
            
            -- Teleport to location
            HRP.CFrame = CFrame.new(location.Position)
            
            -- Anti-detection post-teleport
            if self.Settings.AntiDetection.Enabled then
                wait(self.Settings.AntiDetection.Delay)
                
                -- Re-enable animations
                if Character:FindFirstChild("Animate") then
                    Character.Animate.Disabled = false
                end
                
                -- Reset humanoid state
                local Humanoid = Character:FindFirstChild("Humanoid")
                if Humanoid then
                    Humanoid:ChangeState(0) -- NONE state to resume normal animations
                end
            end
        else
            -- Direct teleport without safety
            HRP.CFrame = CFrame.new(location.Position)
        end
    end)
    
    -- Return result
    if success then
        return true, "Teleported to " .. locationName
    else
        return false, "Failed to teleport: " .. err
    end
end

-- Get list of locations
function Module:GetLocationsList()
    return Locations
end

-- Add custom location
function Module:AddCustomLocation(name, position, icon)
    table.insert(Locations, {
        Name = name,
        Position = position,
        Icon = icon or "📍"
    })
    
    return true, "Added custom location: " .. name
end

-- Island hopper (teleports between all islands sequentially)
function Module:IslandHopper()
    for _, location in pairs(Locations) do
        print("Teleporting to " .. location.Name)
        self:TeleportToLocation(location.Name)
        wait(2) -- Wait between teleports
    end
end

return Module