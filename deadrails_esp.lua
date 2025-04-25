--[[
    SkyX Hub - Dead Rails ESP Module
    Part of the SkyX modular system
    
    Features:
    - Player ESP with customizable options
    - Item ESP for weapons and collectibles
    - Distance display
    - Health indicators
    - Team color support
]]

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- ESP Configuration
local ESPConfig = {
    Enabled = false,
    ShowNames = true,
    ShowDistance = true,
    ShowHealth = true,
    ShowTeamColor = true,
    ShowBox = true,
    ShowWeapon = true,
    ItemESP = false,
    MaxDistance = 2000,
    FontSize = 14,
    TextOutline = true,
    BoxThickness = 1,
    TextColor = Color3.fromRGB(255, 255, 255),
    BoxColor = Color3.fromRGB(255, 255, 255),
    EnemyColor = Color3.fromRGB(255, 0, 0),
    TeamColor = Color3.fromRGB(0, 255, 0),
    ItemColor = Color3.fromRGB(100, 100, 255)
}

-- ESP objects container
local ESPObjects = {}
local ItemESPObjects = {}

-- Module table
local ESP = {}

-- Helper function for rainbow color effect
local function rainbow(speed)
    local time = tick() * (speed or 1)
    return Color3.fromHSV((time % 5) / 5, 1, 1)
end

-- Create ESP for a player
local function CreatePlayerESP(player)
    if player == LocalPlayer then return end
    if ESPObjects[player] then return end
    
    ESPObjects[player] = {}
    
    -- Create Name ESP
    local nameESP = Drawing.new("Text")
    nameESP.Text = player.Name
    nameESP.Size = ESPConfig.FontSize
    nameESP.Color = ESPConfig.TextColor
    nameESP.Center = true
    nameESP.Outline = ESPConfig.TextOutline
    nameESP.OutlineColor = Color3.fromRGB(0, 0, 0)
    nameESP.Visible = ESPConfig.Enabled and ESPConfig.ShowNames
    ESPObjects[player].Name = nameESP
    
    -- Create Box ESP
    local boxESP = Drawing.new("Square")
    boxESP.Thickness = ESPConfig.BoxThickness
    boxESP.Color = ESPConfig.BoxColor
    boxESP.Filled = false
    boxESP.Transparency = 1
    boxESP.Visible = ESPConfig.Enabled and ESPConfig.ShowBox
    ESPObjects[player].Box = boxESP
    
    -- Create Health ESP
    local healthESP = Drawing.new("Text")
    healthESP.Text = "100 HP"
    healthESP.Size = ESPConfig.FontSize - 2
    healthESP.Color = Color3.fromRGB(0, 255, 0)
    healthESP.Center = true
    healthESP.Outline = ESPConfig.TextOutline
    healthESP.OutlineColor = Color3.fromRGB(0, 0, 0)
    healthESP.Visible = ESPConfig.Enabled and ESPConfig.ShowHealth
    ESPObjects[player].Health = healthESP
    
    -- Create Weapon ESP
    local weaponESP = Drawing.new("Text")
    weaponESP.Text = "Weapon: Unknown"
    weaponESP.Size = ESPConfig.FontSize - 2
    weaponESP.Color = ESPConfig.TextColor
    weaponESP.Center = true
    weaponESP.Outline = ESPConfig.TextOutline
    weaponESP.OutlineColor = Color3.fromRGB(0, 0, 0)
    weaponESP.Visible = ESPConfig.Enabled and ESPConfig.ShowWeapon
    ESPObjects[player].Weapon = weaponESP
end

-- Remove ESP for a player
local function RemovePlayerESP(player)
    if not ESPObjects[player] then return end
    
    for _, object in pairs(ESPObjects[player]) do
        if object and typeof(object) == "userdata" and object.Remove then
            object:Remove()
        end
    end
    
    ESPObjects[player] = nil
end

-- Create ESP for an item in the world
local function CreateItemESP(item, itemType, color)
    if ItemESPObjects[item] then return end
    
    ItemESPObjects[item] = {}
    
    -- Create Name ESP
    local nameESP = Drawing.new("Text")
    nameESP.Text = itemType or "Item"
    nameESP.Size = ESPConfig.FontSize - 2
    nameESP.Color = color or ESPConfig.ItemColor
    nameESP.Center = true
    nameESP.Outline = ESPConfig.TextOutline
    nameESP.OutlineColor = Color3.fromRGB(0, 0, 0)
    nameESP.Visible = ESPConfig.Enabled and ESPConfig.ItemESP
    ItemESPObjects[item].Name = nameESP
    
    -- Distance ESP
    local distanceESP = Drawing.new("Text")
    distanceESP.Text = "0m"
    distanceESP.Size = ESPConfig.FontSize - 4
    distanceESP.Color = color or ESPConfig.ItemColor
    distanceESP.Center = true
    distanceESP.Outline = ESPConfig.TextOutline
    distanceESP.OutlineColor = Color3.fromRGB(0, 0, 0)
    distanceESP.Visible = ESPConfig.Enabled and ESPConfig.ItemESP and ESPConfig.ShowDistance
    ItemESPObjects[item].Distance = distanceESP
end

-- Remove ESP for an item
local function RemoveItemESP(item)
    if not ItemESPObjects[item] then return end
    
    for _, object in pairs(ItemESPObjects[item]) do
        if object and typeof(object) == "userdata" and object.Remove then
            object:Remove()
        end
    end
    
    ItemESPObjects[item] = nil
end

-- Update ESP for all players
local function UpdateESP()
    for player, objects in pairs(ESPObjects) do
        if not player or not player.Parent or not player:IsDescendantOf(Players) then
            RemovePlayerESP(player)
            continue
        end
        
        local character = player.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") or not character:FindFirstChild("Humanoid") then
            -- Hide ESP if character is not available
            for _, object in pairs(objects) do
                if object and object.Visible ~= nil then
                    object.Visible = false
                end
            end
            continue
        end
        
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        local humanoid = character:FindFirstChild("Humanoid")
        
        if humanoid.Health <= 0 then
            -- Hide ESP if player is dead
            for _, object in pairs(objects) do
                if object and object.Visible ~= nil then
                    object.Visible = false
                end
            end
            continue
        end
        
        -- Get screen position
        local vector, onScreen = Camera:WorldToViewportPoint(humanoidRootPart.Position)
        
        if not onScreen or vector.Z < 0 then
            -- Hide ESP if off screen
            for _, object in pairs(objects) do
                if object and object.Visible ~= nil then
                    object.Visible = false
                end
            end
            continue
        end
        
        -- Calculate distance
        local distance = (Camera.CFrame.Position - humanoidRootPart.Position).Magnitude
        
        -- Check max distance
        if distance > ESPConfig.MaxDistance then
            for _, object in pairs(objects) do
                if object and object.Visible ~= nil then
                    object.Visible = false
                end
            end
            continue
        end
        
        local distanceText = math.floor(distance) .. "m"
        
        -- Get player team color
        local teamColor = player.TeamColor or BrickColor.new("White")
        local espColor = ESPConfig.TextColor
        
        if ESPConfig.ShowTeamColor then
            if player.Team == LocalPlayer.Team then
                espColor = ESPConfig.TeamColor
            else
                espColor = ESPConfig.EnemyColor
            end
        end
        
        -- Get player weapon
        local weaponText = "Weapon: Unknown"
        local currentTool = character:FindFirstChildOfClass("Tool")
        if currentTool then
            weaponText = "Weapon: " .. currentTool.Name
        end
        
        -- Update Name ESP
        if objects.Name then
            objects.Name.Position = Vector2.new(vector.X, vector.Y - 40)
            objects.Name.Text = player.Name .. (ESPConfig.ShowDistance and " (" .. distanceText .. ")" or "")
            objects.Name.Color = espColor
            objects.Name.Visible = ESPConfig.Enabled and ESPConfig.ShowNames
        end
        
        -- Update Box ESP
        if objects.Box then
            -- Calculate box size based on distance
            local size = 50000 / distance
            local boxSize = Vector2.new(size / 3, size * 1.5)
            objects.Box.Position = Vector2.new(vector.X - boxSize.X / 2, vector.Y - boxSize.Y / 2)
            objects.Box.Size = boxSize
            objects.Box.Color = espColor
            objects.Box.Visible = ESPConfig.Enabled and ESPConfig.ShowBox
        end
        
        -- Update Health ESP
        if objects.Health then
            objects.Health.Position = Vector2.new(vector.X, vector.Y - 25)
            objects.Health.Text = math.floor(humanoid.Health) .. " HP"
            
            -- Color based on health percentage
            local healthPercent = humanoid.Health / humanoid.MaxHealth
            local healthColor = Color3.fromRGB(
                255 * (1 - healthPercent),
                255 * healthPercent,
                0
            )
            
            objects.Health.Color = healthColor
            objects.Health.Visible = ESPConfig.Enabled and ESPConfig.ShowHealth
        end
        
        -- Update Weapon ESP
        if objects.Weapon then
            objects.Weapon.Position = Vector2.new(vector.X, vector.Y - 10)
            objects.Weapon.Text = weaponText
            objects.Weapon.Visible = ESPConfig.Enabled and ESPConfig.ShowWeapon
        end
    end
    
    -- Update item ESP
    for item, objects in pairs(ItemESPObjects) do
        if not item or not item.Parent then
            RemoveItemESP(item)
            continue
        end
        
        local position
        if item:IsA("BasePart") then
            position = item.Position
        elseif item:IsA("Model") and item.PrimaryPart then
            position = item.PrimaryPart.Position
        elseif item:IsA("Model") and item:FindFirstChildOfClass("BasePart") then
            position = item:FindFirstChildOfClass("BasePart").Position
        else
            continue
        end
        
        -- Get screen position
        local vector, onScreen = Camera:WorldToViewportPoint(position)
        
        if not onScreen or vector.Z < 0 then
            -- Hide ESP if off screen
            for _, object in pairs(objects) do
                if object and object.Visible ~= nil then
                    object.Visible = false
                end
            end
            continue
        end
        
        -- Calculate distance
        local distance = (Camera.CFrame.Position - position).Magnitude
        
        -- Check max distance
        if distance > ESPConfig.MaxDistance then
            for _, object in pairs(objects) do
                if object and object.Visible ~= nil then
                    object.Visible = false
                end
            end
            continue
        end
        
        local distanceText = math.floor(distance) .. "m"
        
        -- Update Name ESP
        if objects.Name then
            objects.Name.Position = Vector2.new(vector.X, vector.Y - 20)
            objects.Name.Visible = ESPConfig.Enabled and ESPConfig.ItemESP
        end
        
        -- Update Distance ESP
        if objects.Distance then
            objects.Distance.Position = Vector2.new(vector.X, vector.Y - 5)
            objects.Distance.Text = distanceText
            objects.Distance.Visible = ESPConfig.Enabled and ESPConfig.ItemESP and ESPConfig.ShowDistance
        end
    end
end

-- Scan for items to ESP
local function ScanForItems()
    if not ESPConfig.ItemESP then return end
    
    -- Clear existing item ESPs
    for item, _ in pairs(ItemESPObjects) do
        RemoveItemESP(item)
    end
    
    -- Scan for weapons
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChild("Pickup") then
            local itemType = "Weapon"
            CreateItemESP(obj, itemType, Color3.fromRGB(100, 150, 255))
        end
    end
    
    -- Scan for collectibles
    for _, obj in pairs(workspace:GetDescendants()) do
        if (obj:IsA("BasePart") or obj:IsA("Model")) and 
            (obj.Name:lower():find("bone") or 
             obj.Name:lower():find("collect") or 
             obj.Name:lower():find("pickup") or
             obj.Name:lower():find("coin") or
             obj.Name:lower():find("gem")) then
            local itemType = "Collectible"
            CreateItemESP(obj, itemType, Color3.fromRGB(255, 215, 0))
        end
    end
end

-- Initialize ESP
function ESP.Initialize()
    -- Create ESP for existing players
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            CreatePlayerESP(player)
        end
    end
    
    -- Connect player events
    Players.PlayerAdded:Connect(function(player)
        CreatePlayerESP(player)
    end)
    
    Players.PlayerRemoving:Connect(function(player)
        RemovePlayerESP(player)
    end)
    
    -- Scan for items
    ScanForItems()
    
    -- Update ESP every frame
    RunService:BindToRenderStep("SkyX_ESP_Update", 200, UpdateESP)
    
    -- Periodically scan for new items
    spawn(function()
        while true do
            wait(5) -- Scan every 5 seconds
            if ESPConfig.ItemESP then
                ScanForItems()
            end
        end
    end)
    
    return true
end

-- Stop ESP
function ESP.Stop()
    RunService:UnbindFromRenderStep("SkyX_ESP_Update")
    
    -- Remove all ESPs
    for player, _ in pairs(ESPObjects) do
        RemovePlayerESP(player)
    end
    
    for item, _ in pairs(ItemESPObjects) do
        RemoveItemESP(item)
    end
end

-- Configuration functions
function ESP.SetEnabled(value)
    ESPConfig.Enabled = value
end

function ESP.SetShowNames(value)
    ESPConfig.ShowNames = value
end

function ESP.SetShowDistance(value)
    ESPConfig.ShowDistance = value
end

function ESP.SetShowHealth(value)
    ESPConfig.ShowHealth = value
end

function ESP.SetShowBox(value)
    ESPConfig.ShowBox = value
end

function ESP.SetShowWeapon(value)
    ESPConfig.ShowWeapon = value
end

function ESP.SetTeamColor(value)
    ESPConfig.ShowTeamColor = value
end

function ESP.SetItemESP(value)
    ESPConfig.ItemESP = value
    if value then
        ScanForItems()
    end
end

function ESP.SetMaxDistance(value)
    ESPConfig.MaxDistance = value
end

-- Return the module
return ESP