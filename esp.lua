
-- Module container
local ESPModule = {}

-- Define UI colors for easy reference
local Colors = {
    Murderer = Color3.fromRGB(255, 0, 0),    -- Red
    Sheriff = Color3.fromRGB(0, 100, 255),   -- Blue
    Innocent = Color3.fromRGB(0, 255, 100),  -- Green
    Unknown = Color3.fromRGB(255, 255, 255), -- White
}

-- Settings
ESPModule.Settings = {
    Enabled = false,
    ShowDistance = true,
    ShowRole = true,
    Rainbow = false,
    CustomColors = Colors,
    Transparency = 0.5
}

-- Player ESP handles
ESPModule.PlayerESPHandles = {}
ESPModule.ESPLabels = {}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Create rainbow color generator
local function GetRainbowColor()
    local tick = tick() % 5 / 5
    local hue = tick * 360
    
    local r, g, b
    local h = hue / 60
    local i = math.floor(h)
    local f = h - i
    local p = 0
    local q = 1 - f
    local t = f
    
    if i == 0 then r, g, b = 1, t, p
    elseif i == 1 then r, g, b = q, 1, p
    elseif i == 2 then r, g, b = p, 1, t
    elseif i == 3 then r, g, b = p, q, 1
    elseif i == 4 then r, g, b = t, p, 1
    elseif i == 5 then r, g, b = 1, p, q
    end
    
    return Color3.fromRGB(r * 255, g * 255, b * 255)
end

-- Function to get MM2 values (roles)
function ESPModule.GetRoles()
    local MM2 = {}
    MM2.Roles = {}
    MM2.Players = {}
    
    -- Get all players
    for _, Player in pairs(game.Players:GetPlayers()) do
        if Player ~= game.Players.LocalPlayer then
            table.insert(MM2.Players, Player)
        end
    end
    
    -- Attempt to find MM2 roles
    for _, Player in pairs(game.Players:GetPlayers()) do
        local Backpack = Player:FindFirstChild("Backpack")
        if Backpack then
            -- Check for knife
            if Backpack:FindFirstChild("Knife") then
                MM2.Roles.Murderer = Player
            end
            -- Check for gun
            if Backpack:FindFirstChild("Gun") or Backpack:FindFirstChild("Revolver") then
                MM2.Roles.Sheriff = Player
            end
        end
        
        -- Also check equipped items
        local Character = Player.Character
        if Character then
            if Character:FindFirstChild("Knife") then
                MM2.Roles.Murderer = Player
            end
            if Character:FindFirstChild("Gun") or Character:FindFirstChild("Revolver") then
                MM2.Roles.Sheriff = Player
            end
        end
    end
    
    return MM2
end

-- Smart Role Prediction System
ESPModule.RolePrediction = {
    Enabled = true,
    PredictedRoles = {},
    LastPrediction = 0,
    Confidence = {}
}

function ESPModule.PredictRoles()
    if not ESPModule.RolePrediction.Enabled then return end
    
    -- Don't predict too often
    local now = tick()
    if now - ESPModule.RolePrediction.LastPrediction < 5 then return end
    ESPModule.RolePrediction.LastPrediction = now
    
    -- Clear old predictions
    ESPModule.RolePrediction.PredictedRoles = {}
    ESPModule.RolePrediction.Confidence = {}
    
    -- Get known roles
    local MM2 = ESPModule.GetRoles()
    local knownMurderer = MM2.Roles.Murderer
    local knownSheriff = MM2.Roles.Sheriff
    
    -- Player behavior analysis for prediction
    for _, Player in pairs(Players:GetPlayers()) do
        if Player ~= LocalPlayer then
            -- Skip players with already known roles
            if (knownMurderer and Player == knownMurderer) or (knownSheriff and Player == knownSheriff) then
                continue
            end
            
            local confidence = 0
            local Character = Player.Character
            
            if Character then
                -- Check player movement patterns
                local Humanoid = Character:FindFirstChild("Humanoid")
                if Humanoid then
                    -- Fast movement could indicate murderer
                    if Humanoid.WalkSpeed > 18 then
                        confidence = confidence + 0.1
                    end
                end
                
                -- Check if player is following others closely (murderer behavior)
                for _, OtherPlayer in pairs(Players:GetPlayers()) do
                    if OtherPlayer ~= Player and OtherPlayer ~= LocalPlayer then
                        local OtherCharacter = OtherPlayer.Character
                        if OtherCharacter and OtherCharacter:FindFirstChild("HumanoidRootPart") and Character:FindFirstChild("HumanoidRootPart") then
                            local distance = (OtherCharacter.HumanoidRootPart.Position - Character.HumanoidRootPart.Position).Magnitude
                            if distance < 10 then
                                confidence = confidence + 0.15
                            end
                        end
                    end
                end
                
                -- Check if player is avoiding others (sheriff behavior)
                local avoidingCount = 0
                for _, OtherPlayer in pairs(Players:GetPlayers()) do
                    if OtherPlayer ~= Player and OtherPlayer ~= LocalPlayer then
                        local OtherCharacter = OtherPlayer.Character
                        if OtherCharacter and OtherCharacter:FindFirstChild("HumanoidRootPart") and Character:FindFirstChild("HumanoidRootPart") then
                            local distance = (OtherCharacter.HumanoidRootPart.Position - Character.HumanoidRootPart.Position).Magnitude
                            if distance > 25 then
                                avoidingCount = avoidingCount + 1
                            end
                        end
                    end
                end
                
                if avoidingCount > #Players:GetPlayers() / 2 then
                    -- Likely sheriff if avoiding many players
                    ESPModule.RolePrediction.PredictedRoles[Player.Name] = "Sheriff"
                    ESPModule.RolePrediction.Confidence[Player.Name] = 0.6
                else if confidence > 0.2 then
                    -- Potential murderer
                    ESPModule.RolePrediction.PredictedRoles[Player.Name] = "Murderer"
                    ESPModule.RolePrediction.Confidence[Player.Name] = confidence
                end
                end
            end
        end
    end
    
    return ESPModule.RolePrediction
end

-- Enhanced ESP function
function ESPModule.UpdateESP()
    -- Clean up old ESP
    for _, handle in pairs(ESPModule.PlayerESPHandles) do
        if handle and handle.Parent then
            handle:Destroy()
        end
    end
    
    for _, label in pairs(ESPModule.ESPLabels) do
        if label and label.Parent then
            label:Destroy()
        end
    end
    
    ESPModule.PlayerESPHandles = {}
    ESPModule.ESPLabels = {}
    
    if not ESPModule.Settings.Enabled then return end
    
    -- Update role predictions
    ESPModule.PredictRoles()
    
    -- Get MM2 values to know roles
    local MM2 = ESPModule.GetRoles()
    
    -- Add ESP for each player
    for _, Player in pairs(game.Players:GetPlayers()) do
        if Player ~= game.Players.LocalPlayer then
            local Character = Player.Character
            if Character and Character:FindFirstChild("HumanoidRootPart") and Character:FindFirstChild("Humanoid") then
                -- Create ESP highlight
                local Highlight = Instance.new("Highlight")
                Highlight.Name = "SkyXESP_" .. Player.Name
                
                -- Determine role and color
                local Color = ESPModule.Settings.CustomColors.Unknown
                local Role = "Unknown"
                
                -- Use actual role if known
                if MM2.Roles.Murderer and MM2.Roles.Murderer == Player then
                    Color = ESPModule.Settings.CustomColors.Murderer
                    Role = "Murderer"
                elseif MM2.Roles.Sheriff and MM2.Roles.Sheriff == Player then
                    Color = ESPModule.Settings.CustomColors.Sheriff
                    Role = "Sheriff"
                else
                    -- Use predicted role if available
                    local predictedRole = ESPModule.RolePrediction.PredictedRoles[Player.Name]
                    if predictedRole then
                        if predictedRole == "Murderer" then
                            Color = Color3.fromRGB(255, 150, 150) -- Light red for predicted murderer
                            Role = "Predicted Murderer"
                        elseif predictedRole == "Sheriff" then
                            Color = Color3.fromRGB(150, 150, 255) -- Light blue for predicted sheriff
                            Role = "Predicted Sheriff"
                        end
                    else
                        Color = ESPModule.Settings.CustomColors.Innocent
                        Role = "Innocent"
                    end
                end
                
                -- Apply rainbow effect if enabled
                if ESPModule.Settings.Rainbow then
                    Color = GetRainbowColor()
                end
                
                -- Apply colors
                Highlight.FillColor = Color
                Highlight.OutlineColor = Color
                Highlight.FillTransparency = ESPModule.Settings.Transparency
                Highlight.OutlineTransparency = 0
                Highlight.Parent = Character
                
                -- Create ESP text label for distance and role
                if ESPModule.Settings.ShowDistance or ESPModule.Settings.ShowRole then
                    -- Create ESP text
                    local ESPLabel = Instance.new("BillboardGui")
                    ESPLabel.Name = "SkyXESPLabel_" .. Player.Name
                    ESPLabel.AlwaysOnTop = true
                    ESPLabel.Size = UDim2.new(0, 200, 0, 50)
                    ESPLabel.StudsOffset = Vector3.new(0, 3, 0)
                    ESPLabel.Adornee = Character.HumanoidRootPart
                    ESPLabel.Parent = Character.HumanoidRootPart
                    
                    local TextLabel = Instance.new("TextLabel")
                    TextLabel.Size = UDim2.new(1, 0, 1, 0)
                    TextLabel.BackgroundTransparency = 1
                    TextLabel.TextColor3 = Color
                    TextLabel.TextStrokeTransparency = 0.4
                    TextLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                    TextLabel.Font = Enum.Font.GothamBold
                    TextLabel.TextSize = 14
                    TextLabel.Parent = ESPLabel
                    
                    -- Update label text
                    local function UpdateLabelText()
                        local LabelText = ""
                        
                        -- Add role if enabled
                        if ESPModule.Settings.ShowRole then
                            LabelText = LabelText .. Role
                        end
                        
                        -- Add distance if enabled
                        if ESPModule.Settings.ShowDistance and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                            local distance = math.floor((LocalPlayer.Character.HumanoidRootPart.Position - Character.HumanoidRootPart.Position).Magnitude)
                            if ESPModule.Settings.ShowRole then
                                LabelText = LabelText .. " (" .. distance .. "m)"
                            else
                                LabelText = distance .. "m"
                            end
                        end
                        
                        TextLabel.Text = LabelText
                    end
                    
                    -- Initial update
                    UpdateLabelText()
                    
                    -- Update position & text every frame
                    local connection = RunService.RenderStepped:Connect(function()
                        if not ESPLabel or not ESPLabel.Parent then
                            connection:Disconnect()
                            return
                        end
                        
                        UpdateLabelText()
                        
                        -- Rainbow color update
                        if ESPModule.Settings.Rainbow then
                            local rainbowColor = GetRainbowColor()
                            TextLabel.TextColor3 = rainbowColor
                            
                            if Highlight and Highlight.Parent then
                                Highlight.FillColor = rainbowColor
                                Highlight.OutlineColor = rainbowColor
                            end
                        end
                    end)
                    
                    -- Save for cleanup
                    table.insert(ESPModule.ESPLabels, ESPLabel)
                end
                
                -- Save highlight for cleanup
                table.insert(ESPModule.PlayerESPHandles, Highlight)
            end
        end
    end
end

-- Start ESP update loop
function ESPModule.Start()
    -- Create update connection
    ESPModule.UpdateConnection = RunService.Heartbeat:Connect(function()
        if ESPModule.Settings.Enabled then
            ESPModule.UpdateESP()
        end
    end)
    
    -- Return success message
    return "SkyX ESP Module started successfully"
end

-- Stop ESP
function ESPModule.Stop()
    -- Disconnect update connection
    if ESPModule.UpdateConnection then
        ESPModule.UpdateConnection:Disconnect()
        ESPModule.UpdateConnection = nil
    end
    
    -- Clean up ESP
    for _, handle in pairs(ESPModule.PlayerESPHandles) do
        if handle and handle.Parent then
            handle:Destroy()
        end
    end
    
    for _, label in pairs(ESPModule.ESPLabels) do
        if label and label.Parent then
            label:Destroy()
        end
    end
    
    ESPModule.PlayerESPHandles = {}
    ESPModule.ESPLabels = {}
    
    -- Return success message
    return "SkyX ESP Module stopped successfully"
end

-- Initialize (does not start ESP automatically)
local function Initialize()
    print("SkyX ESP Module initialized")
    return ESPModule
end

return Initialize()
