--[[
    SkyX Hub - Dead Rails Teleport Module
    Part of the SkyX modular system
    
    Features:
    - Safety teleport with anti-detection
    - Location teleport system
    - Player teleport
    - Nearest enemy teleport
    - Weapon teleport
]]

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")

-- Teleport Configuration
local TeleportConfig = {
    SafeTeleport = true, -- Use safe teleport method
    TweenTeleport = true, -- Use tweening for visual smoothness
    TeleportSpeed = 250, -- How fast to tween (studs per second)
    MaxInstantDistance = 50, -- Maximum distance for instant teleport
    UseHeightOffset = true, -- Add height when teleporting
    HeightOffset = 2, -- Height offset in studs
    RetryAttempts = 3, -- Number of attempts for failed teleports
    SmoothLanding = true, -- Enable smoother landing after teleport
    AnimateTeleport = true, -- Play teleport animation
    MapLocations = {} -- Will be populated with map-specific locations
}

-- Module table
local Teleport = {}

-- Helper function for detecting current map
local function GetCurrentMap()
    -- Try to find map name
    local mapName = "Unknown"
    
    -- Common locations for map info in Dead Rails
    local mapModule = ReplicatedStorage:FindFirstChild("MapModule")
    if mapModule and mapModule:FindFirstChild("CurrentMap") then
        mapName = mapModule.CurrentMap.Value
    end
    
    return mapName
end

-- Detect map locations and populate MapLocations table
local function DetectMapLocations()
    local mapName = GetCurrentMap()
    local locations = {}
    
    -- Find spawn locations
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("SpawnLocation") or 
          (obj:IsA("BasePart") and obj.Name:lower():find("spawn")) then
            table.insert(locations, {
                Name = "Spawn Point " .. #locations + 1,
                Position = obj.Position,
                Type = "Spawn"
            })
        end
    end
    
    -- Find teleport parts or destinations
    for _, obj in pairs(workspace:GetDescendants()) do
        if (obj:IsA("BasePart") and 
            (obj.Name:lower():find("teleport") or 
             obj.Name:lower():find("destination"))) then
            table.insert(locations, {
                Name = obj.Name,
                Position = obj.Position,
                Type = "Teleport"
            })
        end
    end
    
    -- Find important areas by name
    local importantKeywords = {
        "lobby", "shop", "armory", "weapon", "gun", "safezone", "safe", 
        "bunker", "base", "headquarters", "hq", "center", "arena"
    }
    
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local objName = obj.Name:lower()
            for _, keyword in pairs(importantKeywords) do
                if objName:find(keyword) then
                    local position
                    if obj:IsA("BasePart") then
                        position = obj.Position
                    elseif obj:IsA("Model") and obj.PrimaryPart then
                        position = obj.PrimaryPart.Position
                    elseif obj:IsA("Model") then
                        local part = obj:FindFirstChildWhichIsA("BasePart")
                        if part then
                            position = part.Position
                        end
                    end
                    
                    if position then
                        table.insert(locations, {
                            Name = obj.Name,
                            Position = position,
                            Type = "Area"
                        })
                    end
                    break
                end
            end
        end
    end
    
    -- Map-specific locations
    if mapName:lower():find("city") then
        -- City map typically has buildings and streets
        table.insert(locations, {
            Name = "City Center",
            Position = Vector3.new(0, 50, 0), -- Approx center, adjust as needed
            Type = "Landmark"
        })
    elseif mapName:lower():find("desert") then
        -- Desert map typically has oasis or outposts
        table.insert(locations, {
            Name = "Desert Outpost",
            Position = Vector3.new(200, 50, 200), -- Approx position, adjust as needed
            Type = "Landmark"
        })
    end
    
    -- Add the locations to config
    TeleportConfig.MapLocations = locations
    return locations
end

-- Safe teleport function
local function SafeTeleport(position, useAddedHeight)
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        warn("Character or HumanoidRootPart not found")
        return false
    end
    
    local humanoidRootPart = LocalPlayer.Character.HumanoidRootPart
    local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    
    -- Add height offset if specified
    if useAddedHeight and TeleportConfig.UseHeightOffset then
        position = position + Vector3.new(0, TeleportConfig.HeightOffset, 0)
    end
    
    -- Calculate distance
    local distance = (humanoidRootPart.Position - position).Magnitude
    
    -- Use instant teleport for short distances or if tweening is disabled
    if distance <= TeleportConfig.MaxInstantDistance or not TeleportConfig.TweenTeleport then
        -- Simple CFrame teleport
        humanoidRootPart.CFrame = CFrame.new(position)
        return true
    else
        -- Tween teleport for smoother and less detectable movement
        local teleportTween = TweenService:Create(
            humanoidRootPart,
            TweenInfo.new(
                distance / TeleportConfig.TeleportSpeed,
                Enum.EasingStyle.Linear,
                Enum.EasingDirection.Out
            ),
            {CFrame = CFrame.new(position)}
        )
        
        -- Play animation if enabled
        if TeleportConfig.AnimateTeleport and humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
        
        teleportTween:Play()
        
        -- Wait for tween to complete
        teleportTween.Completed:Wait()
        
        if TeleportConfig.SmoothLanding and humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
        
        return true
    end
end

-- Get all weapons in the map
local function GetAllWeapons()
    local weapons = {}
    
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChild("Pickup") then
            table.insert(weapons, obj)
        end
    end
    
    return weapons
end

-- Get nearest enemy
local function GetNearestEnemy()
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return nil
    end
    
    local humanoidRootPart = LocalPlayer.Character.HumanoidRootPart
    local nearestPlayer = nil
    local nearestDistance = math.huge
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Team ~= LocalPlayer.Team then
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                local distance = (humanoidRootPart.Position - player.Character.HumanoidRootPart.Position).Magnitude
                if distance < nearestDistance then
                    nearestDistance = distance
                    nearestPlayer = player
                end
            end
        end
    end
    
    return nearestPlayer
end

-- Public teleport functions
-- Teleport to position
function Teleport.TeleportToPosition(position, useAddedHeight)
    return SafeTeleport(position, useAddedHeight)
end

-- Teleport to player
function Teleport.TeleportToPlayer(player)
    if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return false
    end
    
    return SafeTeleport(player.Character.HumanoidRootPart.Position, true)
end

-- Teleport to nearest enemy
function Teleport.TeleportToNearestEnemy()
    local nearestEnemy = GetNearestEnemy()
    
    if not nearestEnemy then
        warn("No enemy found")
        return false
    end
    
    return Teleport.TeleportToPlayer(nearestEnemy)
end

-- Teleport to random weapon
function Teleport.TeleportToRandomWeapon()
    local weapons = GetAllWeapons()
    
    if #weapons == 0 then
        warn("No weapons found")
        return false
    end
    
    local randomWeapon = weapons[math.random(1, #weapons)]
    
    if randomWeapon and randomWeapon:FindFirstChild("Pickup") then
        return SafeTeleport(randomWeapon.Pickup.Position, true)
    end
    
    return false
end

-- Teleport to location by name
function Teleport.TeleportToLocation(locationName)
    if #TeleportConfig.MapLocations == 0 then
        DetectMapLocations()
    end
    
    for _, location in pairs(TeleportConfig.MapLocations) do
        if location.Name:lower() == locationName:lower() then
            return SafeTeleport(location.Position, true)
        end
    end
    
    warn("Location not found: " .. locationName)
    return false
end

-- Get all map locations
function Teleport.GetAllLocations()
    if #TeleportConfig.MapLocations == 0 then
        DetectMapLocations()
    end
    
    return TeleportConfig.MapLocations
end

-- Initialize teleport module
function Teleport.Initialize()
    -- Detect map locations
    DetectMapLocations()
    return true
end

-- Stop teleport module
function Teleport.Stop()
    -- Nothing specific to clean up
    return true
end

-- Configuration functions
function Teleport.SetSafeTeleport(value)
    TeleportConfig.SafeTeleport = value
end

function Teleport.SetTweenTeleport(value)
    TeleportConfig.TweenTeleport = value
end

function Teleport.SetTeleportSpeed(value)
    TeleportConfig.TeleportSpeed = value
end

function Teleport.SetMaxInstantDistance(value)
    TeleportConfig.MaxInstantDistance = value
end

function Teleport.SetUseHeightOffset(value)
    TeleportConfig.UseHeightOffset = value
end

function Teleport.SetHeightOffset(value)
    TeleportConfig.HeightOffset = value
end

function Teleport.SetRetryAttempts(value)
    TeleportConfig.RetryAttempts = value
end

function Teleport.SetSmoothLanding(value)
    TeleportConfig.SmoothLanding = value
end

function Teleport.SetAnimateTeleport(value)
    TeleportConfig.AnimateTeleport = value
end

-- Return the module
return Teleport