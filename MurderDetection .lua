
-- Module container
local MurderDetectionModule = {}

-- Dependencies (these will be imported when loading modules from GitHub)
-- If you're loading this module independently, you need to handle ESP properly
local ESPModule

-- Settings
MurderDetectionModule.Settings = {
    Enabled = false,
    AutoKill = false,
    SafeDistance = 15,        -- Distance to maintain from murderer
    WarningDistance = 25,     -- Distance to show warning at
    KillDistance = 8,         -- Distance to automatically kill murderer if they get this close
    MurdererFound = false,
    MurdererPlayer = nil,
    MurdererWarningUI = nil,
    KillCooldown = 5,         -- Seconds between auto-kill attempts
    LastKillAttempt = 0,
    MovementPrediction = true -- Predict murderer's movement for better avoidance
}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

-- Function to get MM2 values (roles)
function MurderDetectionModule.GetRoles()
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

-- Create on-screen warning for when murderer is close
function MurderDetectionModule.CreateMurdererWarning()
    -- Remove existing warning if any
    if MurderDetectionModule.Settings.MurdererWarningUI and MurderDetectionModule.Settings.MurdererWarningUI.Parent then
        MurderDetectionModule.Settings.MurdererWarningUI:Destroy()
    end
    
    -- Create warning UI
    local WarningUI = Instance.new("ScreenGui")
    WarningUI.Name = "MurdererWarning"
    WarningUI.ResetOnSpawn = false
    WarningUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- Handle executor security models
    if syn then
        syn.protect_gui(WarningUI)
        WarningUI.Parent = game.CoreGui
    else
        WarningUI.Parent = gethui() or game.CoreGui
    end
    
    -- Create warning frame
    local WarningFrame = Instance.new("Frame")
    WarningFrame.Name = "WarningFrame"
    WarningFrame.Size = UDim2.new(0, 300, 0, 60)
    WarningFrame.Position = UDim2.new(0.5, -150, 0, 50)
    WarningFrame.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
    WarningFrame.BackgroundTransparency = 0.3
    WarningFrame.BorderSizePixel = 0
    WarningFrame.Visible = false
    WarningFrame.Parent = WarningUI
    
    -- Add corner
    local WarningCorner = Instance.new("UICorner")
    WarningCorner.CornerRadius = UDim.new(0, 8)
    WarningCorner.Parent = WarningFrame
    
    -- Add stroke
    local WarningStroke = Instance.new("UIStroke")
    WarningStroke.Color = Color3.fromRGB(255, 0, 0)
    WarningStroke.Thickness = 2
    WarningStroke.Parent = WarningFrame
    
    -- Add text
    local WarningText = Instance.new("TextLabel")
    WarningText.Name = "WarningText"
    WarningText.Size = UDim2.new(1, 0, 1, 0)
    WarningText.BackgroundTransparency = 1
    WarningText.Font = Enum.Font.GothamBold
    WarningText.TextSize = 18
    WarningText.TextColor3 = Color3.fromRGB(255, 255, 255)
    WarningText.Text = "⚠️ MURDERER NEARBY ⚠️"
    WarningText.Parent = WarningFrame
    
    -- Add distance text
    local DistanceText = Instance.new("TextLabel")
    DistanceText.Name = "DistanceText"
    DistanceText.Size = UDim2.new(1, 0, 0, 20)
    DistanceText.Position = UDim2.new(0, 0, 1, -20)
    DistanceText.BackgroundTransparency = 1
    DistanceText.Font = Enum.Font.GothamSemibold
    DistanceText.TextSize = 14
    DistanceText.TextColor3 = Color3.fromRGB(255, 255, 255)
    DistanceText.Text = "Distance: 0m"
    DistanceText.Parent = WarningFrame
    
    -- Create pulse animation
    local function AnimateWarning()
        while WarningFrame and WarningFrame.Parent do
            -- Pulse effect
            TweenService:Create(WarningFrame, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                BackgroundTransparency = 0.1
            }):Play()
            
            TweenService:Create(WarningStroke, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                Transparency = 0
            }):Play()
            
            wait(0.5)
            
            TweenService:Create(WarningFrame, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                BackgroundTransparency = 0.3
            }):Play()
            
            TweenService:Create(WarningStroke, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                Transparency = 0.5
            }):Play()
            
            wait(0.5)
        end
    end
    
    -- Start animation in separate thread
    task.spawn(AnimateWarning)
    
    MurderDetectionModule.Settings.MurdererWarningUI = WarningUI
    return WarningUI
end

-- Auto-kill function to eliminate murderer
function MurderDetectionModule.KillMurderer(murderer)
    -- Check cooldown
    local now = tick()
    if now - MurderDetectionModule.Settings.LastKillAttempt < MurderDetectionModule.Settings.KillCooldown then
        return false -- On cooldown
    end
    
    MurderDetectionModule.Settings.LastKillAttempt = now
    
    -- Safety checks
    if not murderer or not murderer.Character or not murderer.Character:FindFirstChild("HumanoidRootPart") then
        return false
    end
    
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return false
    end
    
    -- Get MM2 values
    local MM2 = MurderDetectionModule.GetRoles()
    
    -- Check if we are sheriff or have a gun
    local hasGun = false
    local gun
    
    if MM2.Roles.Sheriff and MM2.Roles.Sheriff == LocalPlayer then
        hasGun = true
    end
    
    -- Check inventory for gun
    if not hasGun then
        local Backpack = LocalPlayer:FindFirstChild("Backpack")
        if Backpack then
            gun = Backpack:FindFirstChild("Gun") or Backpack:FindFirstChild("Revolver")
            
            if gun then
                hasGun = true
                
                -- Equip gun
                LocalPlayer.Character.Humanoid:EquipTool(gun)
                task.wait(0.1) -- Wait for equip
            end
        end
        
        -- Check if gun is already equipped
        if not gun and LocalPlayer.Character then
            gun = LocalPlayer.Character:FindFirstChild("Gun") or LocalPlayer.Character:FindFirstChild("Revolver")
            if gun then
                hasGun = true
            end
        end
    end
    
    if not hasGun then
        return false -- Can't kill without gun
    end
    
    -- Try to kill methods:
    
    -- Method 1: Find and fire click detector
    if gun then
        for _, desc in pairs(gun:GetDescendants()) do
            if desc:IsA("ClickDetector") then
                pcall(function()
                    fireclickdetector(desc)
                end)
            end
        end
    end
    
    -- Method 2: Use mouse methods
    pcall(function()
        -- Set mouse target to murderer
        LocalPlayer:GetMouse().Target = murderer.Character.HumanoidRootPart
        
        -- Simulate clicks
        game:GetService("VirtualInputManager"):SendMouseButtonEvent(0, 0, 0, true, game, 1)
        task.wait(0.1)
        game:GetService("VirtualInputManager"):SendMouseButtonEvent(0, 0, 0, false, game, 1)
    end)
    
    -- Method 3: Try known remote events
    for _, descendant in pairs(game:GetDescendants()) do
        if (descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction")) and
           (descendant.Name:lower():find("shoot") or descendant.Name:lower():find("fire") or
            descendant.Name:lower():find("gun") or descendant.Name:lower():find("attack")) then
            
            pcall(function()
                if descendant:IsA("RemoteEvent") then
                    descendant:FireServer(murderer.Character.HumanoidRootPart)
                elseif descendant:IsA("RemoteFunction") then
                    descendant:InvokeServer(murderer.Character.HumanoidRootPart)
                end
            end)
        end
    end
    
    return true -- Attempted kill
end

-- Smart Murder detection function
function MurderDetectionModule.UpdateMurderDetection()
    if not MurderDetectionModule.Settings.Enabled then
        -- Hide warning if disabled
        if MurderDetectionModule.Settings.MurdererWarningUI and MurderDetectionModule.Settings.MurdererWarningUI.Parent then
            MurderDetectionModule.Settings.MurdererWarningUI.WarningFrame.Visible = false
        end
        return
    end
    
    -- Reset info if we don't have character
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        MurderDetectionModule.Settings.MurdererFound = false
        MurderDetectionModule.Settings.MurdererPlayer = nil
        
        -- Hide warning
        if MurderDetectionModule.Settings.MurdererWarningUI and MurderDetectionModule.Settings.MurdererWarningUI.Parent then
            MurderDetectionModule.Settings.MurdererWarningUI.WarningFrame.Visible = false
        end
        return
    end
    
    -- Get MM2 values
    local MM2 = MurderDetectionModule.GetRoles()
    
    -- Check if murderer is known
    if MM2.Roles.Murderer then
        -- Murderer found through normal detection
        MurderDetectionModule.Settings.MurdererFound = true
        MurderDetectionModule.Settings.MurdererPlayer = MM2.Roles.Murderer
    elseif ESPModule and ESPModule.RolePrediction and ESPModule.RolePrediction.PredictedRoles then
        -- Try to use ESP's role prediction if available
        for playerName, role in pairs(ESPModule.RolePrediction.PredictedRoles) do
            if role == "Murderer" then
                -- Find player by name
                for _, player in pairs(Players:GetPlayers()) do
                    if player.Name == playerName then
                        MurderDetectionModule.Settings.MurdererFound = true
                        MurderDetectionModule.Settings.MurdererPlayer = player
                        break
                    end
                end
            end
        end
    else
        -- No murderer found yet
        MurderDetectionModule.Settings.MurdererFound = false
        MurderDetectionModule.Settings.MurdererPlayer = nil
        
        -- Hide warning
        if MurderDetectionModule.Settings.MurdererWarningUI and MurderDetectionModule.Settings.MurdererWarningUI.Parent then
            MurderDetectionModule.Settings.MurdererWarningUI.WarningFrame.Visible = false
        end
    end
    
    -- If murderer found, check distance and update UI
    if MurderDetectionModule.Settings.MurdererFound and MurderDetectionModule.Settings.MurdererPlayer then
        -- Make sure murderer has character
        if MurderDetectionModule.Settings.MurdererPlayer.Character and MurderDetectionModule.Settings.MurdererPlayer.Character:FindFirstChild("HumanoidRootPart") then
            -- Calculate distance
            local distance = (LocalPlayer.Character.HumanoidRootPart.Position - MurderDetectionModule.Settings.MurdererPlayer.Character.HumanoidRootPart.Position).Magnitude
            
            -- Show warning if murderer is too close
            if distance < MurderDetectionModule.Settings.WarningDistance then
                -- Create warning UI if it doesn't exist
                if not MurderDetectionModule.Settings.MurdererWarningUI or not MurderDetectionModule.Settings.MurdererWarningUI.Parent then
                    MurderDetectionModule.Settings.MurdererWarningUI = MurderDetectionModule.CreateMurdererWarning()
                end
                
                -- Show and update warning
                MurderDetectionModule.Settings.MurdererWarningUI.WarningFrame.Visible = true
                MurderDetectionModule.Settings.MurdererWarningUI.WarningFrame.DistanceText.Text = "Distance: " .. math.floor(distance) .. "m"
                
                -- Set warning color based on distance
                if distance < MurderDetectionModule.Settings.SafeDistance then
                    -- Red pulsing for immediate danger
                    MurderDetectionModule.Settings.MurdererWarningUI.WarningFrame.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
                    MurderDetectionModule.Settings.MurdererWarningUI.WarningFrame.UIStroke.Color = Color3.fromRGB(255, 0, 0)
                    MurderDetectionModule.Settings.MurdererWarningUI.WarningFrame.WarningText.Text = "⚠️ DANGER! MURDERER VERY CLOSE! ⚠️"
                else
                    -- Yellow for warning
                    MurderDetectionModule.Settings.MurdererWarningUI.WarningFrame.BackgroundColor3 = Color3.fromRGB(200, 150, 0)
                    MurderDetectionModule.Settings.MurdererWarningUI.WarningFrame.UIStroke.Color = Color3.fromRGB(255, 200, 0)
                    MurderDetectionModule.Settings.MurdererWarningUI.WarningFrame.WarningText.Text = "⚠️ MURDERER NEARBY ⚠️"
                end
                
                -- Auto kill if enabled and murderer is very close
                if MurderDetectionModule.Settings.AutoKill and distance < MurderDetectionModule.Settings.KillDistance then
                    local killed = MurderDetectionModule.KillMurderer(MurderDetectionModule.Settings.MurdererPlayer)
                    
                    -- Update warning text if kill was attempted
                    if killed then
                        MurderDetectionModule.Settings.MurdererWarningUI.WarningFrame.WarningText.Text = "🔫 ATTEMPTING TO KILL MURDERER 🔫"
                    end
                end
            else
                -- Hide warning if murderer is far away
                if MurderDetectionModule.Settings.MurdererWarningUI and MurderDetectionModule.Settings.MurdererWarningUI.Parent then
                    MurderDetectionModule.Settings.MurdererWarningUI.WarningFrame.Visible = false
                end
            end
        else
            -- Hide warning if murderer has no character
            if MurderDetectionModule.Settings.MurdererWarningUI and MurderDetectionModule.Settings.MurdererWarningUI.Parent then
                MurderDetectionModule.Settings.MurdererWarningUI.WarningFrame.Visible = false
            end
        end
    end
end

-- Start detection
function MurderDetectionModule.Start()
    -- Create warning UI
    if not MurderDetectionModule.Settings.MurdererWarningUI then
        MurderDetectionModule.Settings.MurdererWarningUI = MurderDetectionModule.CreateMurdererWarning()
    end
    
    -- Create update connection
    MurderDetectionModule.UpdateConnection = RunService.Heartbeat:Connect(function()
        MurderDetectionModule.UpdateMurderDetection()
    end)
    
    -- Return success message
    return "SkyX Murder Detection Module started successfully"
end

-- Stop detection
function MurderDetectionModule.Stop()
    -- Disconnect update connection
    if MurderDetectionModule.UpdateConnection then
        MurderDetectionModule.UpdateConnection:Disconnect()
        MurderDetectionModule.UpdateConnection = nil
    end
    
    -- Clean up warning UI
    if MurderDetectionModule.Settings.MurdererWarningUI and MurderDetectionModule.Settings.MurdererWarningUI.Parent then
        MurderDetectionModule.Settings.MurdererWarningUI:Destroy()
        MurderDetectionModule.Settings.MurdererWarningUI = nil
    end
    
    -- Return success message
    return "SkyX Murder Detection Module stopped successfully"
end

-- Set dependency
function MurderDetectionModule.SetESPModule(espModule)
    ESPModule = espModule
    return true
end

-- Get murderer info
function MurderDetectionModule.GetMurdererInfo()
    return {
        MurdererFound = MurderDetectionModule.Settings.MurdererFound,
        MurdererName = MurderDetectionModule.Settings.MurdererPlayer and MurderDetectionModule.Settings.MurdererPlayer.Name or "Unknown",
        AutoKillEnabled = MurderDetectionModule.Settings.AutoKill
    }
end

-- Initialize (does not start detection automatically)
local function Initialize()
    print("SkyX Murder Detection Module initialized")
    return MurderDetectionModule
end

return Initialize()
