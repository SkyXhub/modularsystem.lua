--[[
    SkyX MM2 Teleport Module
    One-Click Teleports with Anti-Detection

    Include this module in your scripts by using:
    loadstring(game:HttpGet("https://raw.githubusercontent.com/SkyXhub/SkyX-hub/main/SkyX_MM2_Modules/SkyX_Teleport_Module.lua"))()
]]

-- Module container
local TeleportModule = {}

-- Dependencies
local MurderDetectionModule

-- Settings
TeleportModule.Settings = {
    Enabled = true,
    SafeMode = true,     -- Use safer teleport methods to avoid detection
    Locations = {},      -- Will be populated with found locations
    CustomLocations = {
        Lobby = Vector3.new(0, 0, 0), -- Will be updated with discovered positions
        Map = Vector3.new(0, 0, 0),
        Sheriff = Vector3.new(0, 0, 0),
        GunDrop = Vector3.new(0, 0, 0),
        Hiding = Vector3.new(0, 0, 0)
    },
    TeleportInProgress = false,
    AntiDetection = {
        Enabled = true,
        RandomizeMovement = true,
        GradualTeleport = true
    }
}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Find all possible teleport locations in the game
function TeleportModule.DiscoverLocations()
    -- Clear old locations
    TeleportModule.Settings.Locations = {}
    
    -- Update custom locations based on findings
    local Map = workspace:FindFirstChild("Map") or workspace:FindFirstChild("Level")
    local Lobby = workspace:FindFirstChild("Lobby")
    
    -- Search for locations in workspace
    for _, Object in pairs(workspace:GetDescendants()) do
        -- Find lobby
        if Object.Name == "Lobby" or Object.Name == "SpawnLocation" or Object.Name:lower():find("spawn") then
            if Object:IsA("BasePart") then
                table.insert(TeleportModule.Settings.Locations, {
                    Name = "Lobby",
                    Position = Object.Position,
                    Object = Object
                })
                TeleportModule.Settings.CustomLocations.Lobby = Object.Position
            elseif Object:IsA("Model") and Object.PrimaryPart then
                table.insert(TeleportModule.Settings.Locations, {
                    Name = "Lobby",
                    Position = Object.PrimaryPart.Position,
                    Object = Object.PrimaryPart
                })
                TeleportModule.Settings.CustomLocations.Lobby = Object.PrimaryPart.Position
            end
        end
        
        -- Find map spawns
        if Map and (Object:IsA("SpawnLocation") or Object.Name:lower():find("spawn")) then
            if Object:IsA("BasePart") then
                table.insert(TeleportModule.Settings.Locations, {
                    Name = "Map",
                    Position = Object.Position,
                    Object = Object
                })
                TeleportModule.Settings.CustomLocations.Map = Object.Position
            end
        end
        
        -- Find item spawns for gun, sheriff, etc.
        if Object.Name:lower():find("gun") or Object.Name:lower():find("sheriff") then
            if Object:IsA("BasePart") then
                table.insert(TeleportModule.Settings.Locations, {
                    Name = "Sheriff Spawn",
                    Position = Object.Position,
                    Object = Object
                })
                TeleportModule.Settings.CustomLocations.Sheriff = Object.Position
            elseif Object:IsA("Model") and Object:FindFirstChildOfClass("BasePart") then
                local Part = Object:FindFirstChildOfClass("BasePart")
                table.insert(TeleportModule.Settings.Locations, {
                    Name = "Sheriff Spawn",
                    Position = Part.Position,
                    Object = Part
                })
                TeleportModule.Settings.CustomLocations.Sheriff = Part.Position
            end
        end
        
        -- Find hiding spots (usually small enclosed areas)
        if Object.Name:lower():find("hide") or Object.Name:lower():find("hiding") or Object.Name:lower():find("secret") then
            if Object:IsA("BasePart") then
                table.insert(TeleportModule.Settings.Locations, {
                    Name = "Hiding Spot",
                    Position = Object.Position,
                    Object = Object
                })
                TeleportModule.Settings.CustomLocations.Hiding = Object.Position
            elseif Object:IsA("Model") and Object:FindFirstChildOfClass("BasePart") then
                local Part = Object:FindFirstChildOfClass("BasePart")
                table.insert(TeleportModule.Settings.Locations, {
                    Name = "Hiding Spot",
                    Position = Part.Position,
                    Object = Part
                })
                TeleportModule.Settings.CustomLocations.Hiding = Part.Position
            end
        end
    end
    
    -- Set default Map location if not found yet
    if Map then
        local MapPart
        if Map:IsA("BasePart") then
            MapPart = Map
        elseif Map.PrimaryPart then
            MapPart = Map.PrimaryPart
        else
            MapPart = Map:FindFirstChildOfClass("BasePart")
        end
        
        if MapPart and TeleportModule.Settings.CustomLocations.Map == Vector3.new(0, 0, 0) then
            TeleportModule.Settings.CustomLocations.Map = MapPart.Position
        end
    end
    
    -- Set default Lobby location if not found yet
    if Lobby then
        local LobbyPart
        if Lobby:IsA("BasePart") then
            LobbyPart = Lobby
        elseif Lobby.PrimaryPart then
            LobbyPart = Lobby.PrimaryPart
        else
            LobbyPart = Lobby:FindFirstChildOfClass("BasePart")
        end
        
        if LobbyPart and TeleportModule.Settings.CustomLocations.Lobby == Vector3.new(0, 0, 0) then
            TeleportModule.Settings.CustomLocations.Lobby = LobbyPart.Position
        end
    end
    
    return TeleportModule.Settings.Locations
end

-- Safe teleport function with anti-detection measures
function TeleportModule.SafeTeleport(destination)
    if TeleportModule.Settings.TeleportInProgress then return end
    TeleportModule.Settings.TeleportInProgress = true
    
    local Character = LocalPlayer.Character
    if not Character or not Character:FindFirstChild("HumanoidRootPart") or not Character:FindFirstChild("Humanoid") then
        TeleportModule.Settings.TeleportInProgress = false
        return false, "Character not found"
    end
    
    local HRP = Character.HumanoidRootPart
    local Humanoid = Character.Humanoid
    
    -- Store original position and state
    local startPos = HRP.Position
    local originalWalkSpeed = Humanoid.WalkSpeed
    
    -- Apply anti-detection measures
    if TeleportModule.Settings.SafeMode and TeleportModule.Settings.AntiDetection.Enabled then
        -- Safer approach: Gradually move instead of instant teleport
        task.spawn(function()
            -- Path distance calculation
            local distance = (destination - startPos).Magnitude
            local steps = math.min(10, math.max(3, math.floor(distance / 20)))
            local delay = 0.05
            
            -- Temporarily increase movement speed for smoother teleport
            Humanoid.WalkSpeed = math.min(50, Humanoid.WalkSpeed * 2)
            
            -- Move in stages to avoid detection
            for i = 1, steps do
                local progress = i / steps
                local targetPos = startPos:Lerp(destination, progress)
                
                -- Add small random offset to avoid perfect straight-line detection
                if TeleportModule.Settings.AntiDetection.RandomizeMovement and i < steps then
                    local offset = Vector3.new(
                        math.random(-200, 200) / 100,
                        0,
                        math.random(-200, 200) / 100
                    )
                    targetPos = targetPos + offset
                end
                
                -- Update position
                HRP.CFrame = CFrame.new(targetPos) * HRP.CFrame.Rotation
                
                -- Short delay between movements
                task.wait(delay)
            end
            
            -- Final position adjustment
            HRP.CFrame = CFrame.new(destination + Vector3.new(0, 3, 0)) * HRP.CFrame.Rotation
            
            -- Restore original speed
            Humanoid.WalkSpeed = originalWalkSpeed
            
            -- Allow next teleport
            TeleportModule.Settings.TeleportInProgress = false
        end)
    else
        -- Direct teleport if not using anti-detection
        HRP.CFrame = CFrame.new(destination + Vector3.new(0, 3, 0))
        TeleportModule.Settings.TeleportInProgress = false
    end
    
    return true, "Teleport successful"
end

-- Teleport to a specific location by name
function TeleportModule.TeleportToLocation(locationName)
    if TeleportModule.Settings.TeleportInProgress then
        return false, "Teleport already in progress"
    end
    
    local destination
    
    -- Get destination based on selection
    if locationName == "Lobby" then
        if TeleportModule.Settings.CustomLocations.Lobby ~= Vector3.new(0, 0, 0) then
            destination = TeleportModule.Settings.CustomLocations.Lobby
        else
            -- Find lobby spawn
            local Spawns = workspace:FindFirstChild("Lobby") or workspace:FindFirstChild("SpawnLocation")
            if Spawns then
                if Spawns:IsA("BasePart") then
                    destination = Spawns.Position
                elseif Spawns.PrimaryPart then
                    destination = Spawns.PrimaryPart.Position
                end
            end
        end
    elseif locationName == "Map" then
        if TeleportModule.Settings.CustomLocations.Map ~= Vector3.new(0, 0, 0) then
            destination = TeleportModule.Settings.CustomLocations.Map
        else
            -- Find map spawns
            local Map = workspace:FindFirstChild("Map") or workspace:FindFirstChild("Level")
            
            if Map then
                local SpawnPoints = {}
                
                -- Find spawn points in map
                for _, Part in pairs(Map:GetDescendants()) do
                    if Part:IsA("SpawnLocation") or Part.Name:lower():find("spawn") then
                        table.insert(SpawnPoints, Part)
                    end
                end
                
                -- If no spawn points found, just use the first part in the map
                if #SpawnPoints == 0 then
                    for _, Part in pairs(Map:GetDescendants()) do
                        if Part:IsA("BasePart") then
                            table.insert(SpawnPoints, Part)
                            break
                        end
                    end
                end
                
                -- Use first spawn point
                if #SpawnPoints > 0 then
                    destination = SpawnPoints[1].Position
                end
            end
        end
    elseif locationName == "Sheriff Spawn" then
        if TeleportModule.Settings.CustomLocations.Sheriff ~= Vector3.new(0, 0, 0) then
            destination = TeleportModule.Settings.CustomLocations.Sheriff
        else
            -- Find gun/sheriff location
            for _, Object in pairs(workspace:GetDescendants()) do
                if Object.Name:lower():find("gun") or Object.Name:lower():find("sheriff") then
                    if Object:IsA("BasePart") then
                        destination = Object.Position
                        break
                    elseif Object:IsA("Model") and Object:FindFirstChildOfClass("BasePart") then
                        destination = Object:FindFirstChildOfClass("BasePart").Position
                        break
                    end
                end
            end
        end
    elseif locationName == "Hiding Spot" then
        if TeleportModule.Settings.CustomLocations.Hiding ~= Vector3.new(0, 0, 0) then
            destination = TeleportModule.Settings.CustomLocations.Hiding
        else
            -- Find hiding spot
            for _, Object in pairs(workspace:GetDescendants()) do
                if Object.Name:lower():find("hide") or Object.Name:lower():find("hiding") or Object.Name:lower():find("secret") then
                    if Object:IsA("BasePart") then
                        destination = Object.Position
                        break
                    elseif Object:IsA("Model") and Object:FindFirstChildOfClass("BasePart") then
                        destination = Object:FindFirstChildOfClass("BasePart").Position
                        break
                    end
                end
            end
        end
    elseif locationName == "Behind Murderer" then
        -- Find murderer
        local murderer
        
        -- Try to get from MurderDetection module first
        if MurderDetectionModule and MurderDetectionModule.Settings.MurdererFound then
            murderer = MurderDetectionModule.Settings.MurdererPlayer
        end
        
        -- If not found through module, try to get from MM2 values
        if not murderer then
            for _, Player in pairs(Players:GetPlayers()) do
                local Backpack = Player:FindFirstChild("Backpack")
                if Backpack and Backpack:FindFirstChild("Knife") then
                    murderer = Player
                    break
                end
                
                local Character = Player.Character
                if Character and Character:FindFirstChild("Knife") then
                    murderer = Player
                    break
                end
            end
        end
        
        -- If murderer found, teleport behind them
        if murderer and murderer.Character and murderer.Character:FindFirstChild("HumanoidRootPart") then
            local HRP = murderer.Character.HumanoidRootPart
            
            -- Get position behind murderer
            local LookVector = HRP.CFrame.LookVector
            destination = HRP.Position - (LookVector * 5) -- 5 studs behind
        else
            return false, "Murderer not found"
        end
    elseif locationName == "To Sheriff" then
        -- Find sheriff
        local sheriff
        
        -- Try to find player with gun
        for _, Player in pairs(Players:GetPlayers()) do
            local Character = Player.Character
            if Character then
                if Character:FindFirstChild("Gun") or Character:FindFirstChild("Revolver") then
                    sheriff = Player
                    break
                end
            end
            
            local Backpack = Player:FindFirstChild("Backpack")
            if Backpack then
                if Backpack:FindFirstChild("Gun") or Backpack:FindFirstChild("Revolver") then
                    sheriff = Player
                    break
                end
            end
        end
        
        -- If sheriff found, teleport to them
        if sheriff and sheriff.Character and sheriff.Character:FindFirstChild("HumanoidRootPart") then
            destination = sheriff.Character.HumanoidRootPart.Position
        else
            return false, "Sheriff not found"
        end
    elseif locationName == "To Random Player" then
        -- Get list of players
        local playerList = {}
        for _, Player in pairs(Players:GetPlayers()) do
            if Player ~= LocalPlayer and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
                table.insert(playerList, Player)
            end
        end
        
        -- Select random player
        if #playerList > 0 then
            local randomPlayer = playerList[math.random(1, #playerList)]
            destination = randomPlayer.Character.HumanoidRootPart.Position
        else
            return false, "No players found"
        end
    end
    
    -- Perform teleport if destination found
    if destination then
        -- Use safe teleport method
        return TeleportModule.SafeTeleport(destination)
    else
        return false, "Location not found"
    end
end

-- Start teleport system
function TeleportModule.Start()
    -- Discover locations initially
    TeleportModule.DiscoverLocations()
    
    -- Set up hook for rediscovering locations when game state changes
    TeleportModule.WorkspaceConnection = workspace.DescendantAdded:Connect(function()
        -- Wait a bit for new objects to initialize
        delay(1, function()
            TeleportModule.DiscoverLocations()
        end)
    end)
    
    -- Return success message
    return "SkyX Teleport Module started successfully"
end

-- Stop teleport system
function TeleportModule.Stop()
    -- Disconnect workspace connection
    if TeleportModule.WorkspaceConnection then
        TeleportModule.WorkspaceConnection:Disconnect()
        TeleportModule.WorkspaceConnection = nil
    end
    
    -- Return success message
    return "SkyX Teleport Module stopped successfully"
end

-- Set dependency
function TeleportModule.SetMurderDetectionModule(module)
    MurderDetectionModule = module
    return true
end

-- Get locations list for UI
function TeleportModule.GetLocationsList()
    -- Return list of available locations
    local locations = {}
    
    -- Standard locations
    table.insert(locations, { Name = "Lobby", Icon = "🏠", Description = "Spawn Area" })
    table.insert(locations, { Name = "Map", Icon = "🗺️", Description = "Current Game Map" })
    
    -- Only add locations that are actually found
    if TeleportModule.Settings.CustomLocations.Sheriff ~= Vector3.new(0, 0, 0) then
        table.insert(locations, { Name = "Sheriff Spawn", Icon = "🔫", Description = "Gun Spawn Area" })
    end
    
    if TeleportModule.Settings.CustomLocations.Hiding ~= Vector3.new(0, 0, 0) then
        table.insert(locations, { Name = "Hiding Spot", Icon = "🚪", Description = "Safe Hiding Location" })
    end
    
    -- Special locations that don't need to be discovered
    table.insert(locations, { Name = "Behind Murderer", Icon = "🔪", Description = "Teleport Behind Murderer" })
    table.insert(locations, { Name = "To Sheriff", Icon = "👮", Description = "Teleport To Sheriff" })
    table.insert(locations, { Name = "To Random Player", Icon = "👥", Description = "Random Player Location" })
    
    return locations
end

-- Initialize (does not start teleport system automatically)
local function Initialize()
    print("SkyX Teleport Module initialized")
    return TeleportModule
end

return Initialize()