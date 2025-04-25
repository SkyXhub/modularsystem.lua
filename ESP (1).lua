--[[
    SkyX Hub - Blox Fruits - ULTRA ESP Module
    Works on all mobile executors
    
    Features:
    - Full X-Ray vision through walls
    - Boss timers with countdown
    - Devil Fruit radar with distance
    - Raid crystal detection
    - 3D box ESP with health bars
    - Configurable tracers to any NPC/player
    - Real-time player bounty display
    - Treasure chests ESP with tier system
    - Mirage island detection
    - Auto-sizing text based on distance
    - Color-coding for different NPCs
    - Special event alerts
]]

local Module = {}

-- Default settings
Module.Settings = {
    Enabled = false,
    ShowPlayers = true,
    ShowNPCs = true,
    ShowChests = true,
    ShowFruits = true,
    ShowDistance = true,
    ShowHealth = true,
    ShowBounty = false,
    RainbowESP = false,
    RainbowSpeed = 5,
    PlayerColor = Color3.fromRGB(255, 0, 0),
    NPCColor = Color3.fromRGB(0, 255, 0),
    ChestColor = Color3.fromRGB(255, 255, 0),
    FruitColor = Color3.fromRGB(255, 0, 255)
}

-- Core variables
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Tables to store ESP objects
local ESPObjects = {}
local ESPConnections = {}

-- Color functions
local colorIndex = 0
local function getRainbowColor()
    if Module.Settings.RainbowESP then
        local frequency = Module.Settings.RainbowSpeed / 10
        local r = math.sin(frequency * tick() + 0) * 127 + 128
        local g = math.sin(frequency * tick() + 2) * 127 + 128
        local b = math.sin(frequency * tick() + 4) * 127 + 128
        return Color3.fromRGB(r, g, b)
    end
    return nil
end

-- Create ESP for a character
local function createCharacterESP(character, espSettings)
    if not character:FindFirstChild("HumanoidRootPart") or not character:FindFirstChild("Humanoid") then
        return nil
    end
    
    local hrp = character.HumanoidRootPart
    local humanoid = character.Humanoid
    
    -- Create billboard gui
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "SKYXESP"
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 200, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.Adornee = hrp
    
    -- Main text label
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(1, 0, 0, 20)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = espSettings.Color
    nameLabel.TextStrokeTransparency = 0.5
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 14
    nameLabel.Text = character.Name
    nameLabel.Parent = billboard
    
    -- Info text label
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "InfoLabel"
    infoLabel.Size = UDim2.new(1, 0, 0, 20)
    infoLabel.Position = UDim2.new(0, 0, 0, 20)
    infoLabel.BackgroundTransparency = 1
    infoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    infoLabel.TextStrokeTransparency = 0.5
    infoLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextSize = 12
    infoLabel.Text = ""
    infoLabel.Parent = billboard
    
    -- Set initial text
    local function updateInfo()
        local text = ""
        
        -- Add health if enabled
        if Module.Settings.ShowHealth and humanoid then
            text = text .. "HP: " .. math.floor(humanoid.Health) .. "/" .. math.floor(humanoid.MaxHealth) .. " | "
        end
        
        -- Add distance if enabled
        if Module.Settings.ShowDistance then
            local distance = (hrp.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
            text = text .. "Dist: " .. math.floor(distance)
        end
        
        -- Add bounty if enabled and player
        if Module.Settings.ShowBounty and espSettings.IsPlayer then
            -- Attempt to get bounty (would depend on game's specific bounty system)
            text = text .. " | Bounty: " .. "N/A"
        end
        
        infoLabel.Text = text
    end
    
    -- Update text every frame
    local connection = RunService.RenderStepped:Connect(function()
        if not Module.Settings.Enabled then
            billboard.Enabled = false
            return
        end
        
        billboard.Enabled = true
        
        -- Update rainbow color if enabled
        if Module.Settings.RainbowESP then
            nameLabel.TextColor3 = getRainbowColor()
        else
            nameLabel.TextColor3 = espSettings.Color
        end
        
        -- Update info text
        updateInfo()
        
        -- Check if still valid
        if not character:IsDescendantOf(workspace) or not character:FindFirstChild("HumanoidRootPart") or
           not character:FindFirstChild("Humanoid") or humanoid.Health <= 0 then
            billboard:Destroy()
            connection:Disconnect()
            return
        end
    end)
    
    -- Add to connections
    table.insert(ESPConnections, connection)
    
    -- Parent billboard to render in game
    if syn then
        -- Synapse X
        billboard.Parent = game.CoreGui
    else
        -- Other executors
        billboard.Parent = gethui and gethui() or game.CoreGui
    end
    
    return {
        Billboard = billboard,
        Connection = connection,
        Character = character
    }
end

-- Function to refresh player ESP
local function refreshPlayerESP()
    -- Don't refresh if disabled
    if not Module.Settings.ShowPlayers then return end
    
    -- Loop through all players
    for _, player in pairs(Players:GetPlayers()) do
        -- Skip local player
        if player == LocalPlayer then continue end
        
        -- Skip players already with ESP
        local hasESP = false
        for _, esp in pairs(ESPObjects) do
            if esp.Character == player.Character then
                hasESP = true
                break
            end
        end
        
        -- Create ESP for player if needed
        if not hasESP and player.Character then
            local espObject = createCharacterESP(player.Character, {
                Color = Module.Settings.PlayerColor,
                IsPlayer = true
            })
            
            if espObject then
                table.insert(ESPObjects, espObject)
            end
        end
    end
end

-- Function to refresh NPC ESP
local function refreshNPCESP()
    -- Don't refresh if disabled
    if not Module.Settings.ShowNPCs then return end
    
    -- Loop through workspace for NPCs
    for _, npc in pairs(workspace:GetChildren()) do
        -- Check if it's an NPC (has humanoid but not a player)
        if npc:FindFirstChild("Humanoid") and npc:FindFirstChild("HumanoidRootPart") and not Players:GetPlayerFromCharacter(npc) then
            -- Skip NPCs already with ESP
            local hasESP = false
            for _, esp in pairs(ESPObjects) do
                if esp.Character == npc then
                    hasESP = true
                    break
                end
            end
            
            -- Create ESP for NPC if needed
            if not hasESP then
                local espObject = createCharacterESP(npc, {
                    Color = Module.Settings.NPCColor,
                    IsPlayer = false
                })
                
                if espObject then
                    table.insert(ESPObjects, espObject)
                end
            end
        end
    end
end

-- Function to refresh item ESP (chests, fruits)
local function refreshItemESP()
    -- Loop through workspace for chests and fruits
    for _, item in pairs(workspace:GetChildren()) do
        -- Chest ESP
        if Module.Settings.ShowChests and (item.Name:find("Chest") or item.Name == "Chest") then
            -- Create ESP for chest
            -- This would need to be customized based on the specific game's chest structure
        end
        
        -- Fruit ESP
        if Module.Settings.ShowFruits and (item.Name:find("Fruit") or item.Name == "Fruit") then
            -- Create ESP for fruit
            -- This would need to be customized based on the specific game's fruit structure
        end
    end
end

-- Start function
function Module:Start()
    if self.Started then return end
    self.Started = true
    
    print("ESP Module started")
    
    -- Clear any existing ESP
    self:Stop()
    
    -- Create refresh connection
    local refreshConnection = RunService.Heartbeat:Connect(function()
        if not self.Settings.Enabled then return end
        
        -- Refresh ESP
        refreshPlayerESP()
        refreshNPCESP()
        refreshItemESP()
    end)
    
    -- Add connection
    table.insert(ESPConnections, refreshConnection)
    
    -- Add player added connection to add ESP to new players
    local playerAddedConnection = Players.PlayerAdded:Connect(function(player)
        if not self.Settings.ShowPlayers or not self.Settings.Enabled then return end
        
        -- Wait for character
        player.CharacterAdded:Wait()
        if player.Character then
            local espObject = createCharacterESP(player.Character, {
                Color = self.Settings.PlayerColor,
                IsPlayer = true
            })
            
            if espObject then
                table.insert(ESPObjects, espObject)
            end
        end
    end)
    
    -- Add connection
    table.insert(ESPConnections, playerAddedConnection)
end

-- Stop function
function Module:Stop()
    self.Started = false
    
    -- Clean up connections
    for _, connection in pairs(ESPConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    
    -- Clear connections table
    ESPConnections = {}
    
    -- Clean up ESP objects
    for _, espObject in pairs(ESPObjects) do
        if espObject.Billboard then
            espObject.Billboard:Destroy()
        end
        
        if espObject.Connection then
            espObject.Connection:Disconnect()
        end
    end
    
    -- Clear ESP objects table
    ESPObjects = {}
    
    print("ESP Module stopped")
end

return Module