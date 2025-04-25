--[[
    SkyX Hub - Dead Rails Aimbot Module
    Part of the SkyX modular system
    
    Features:
    - Advanced aimbot with customizable settings
    - Team check, visibility check
    - Target customization (head, torso)
    - Adjustable smoothing and FOV
    - Anti-detection measures
]]

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- Aimbot Configuration
local AimbotConfig = {
    Enabled = false,
    TargetPart = "Head", -- "Head" or "Torso"
    TeamCheck = true,
    VisibilityCheck = true,
    Smoothing = 2, -- Higher = smoother, 1 = instant
    FOV = 250, -- Field of view in pixels
    MaxDistance = 1000,
    ShowFOV = false,
    FOVColor = Color3.fromRGB(255, 255, 255),
    TriggerKey = Enum.UserInputType.MouseButton2, -- Right mouse button
    PredictionFactor = 0.165 -- How much to predict movement
}

-- Module table
local Aimbot = {}

-- Variables
local aimTarget = nil
local aiming = false
local FOVCircle

-- Create FOV circle
local function CreateFOVCircle()
    if FOVCircle then return end
    
    FOVCircle = Drawing.new("Circle")
    FOVCircle.Thickness = 1
    FOVCircle.NumSides = 60
    FOVCircle.Radius = AimbotConfig.FOV
    FOVCircle.Filled = false
    FOVCircle.Visible = false
    FOVCircle.ZIndex = 999
    FOVCircle.Transparency = 1
    FOVCircle.Color = AimbotConfig.FOVColor
end

-- Calculate angle to target
local function GetAngleDelta(p0, p1, p2)
    local v1 = (p1 - p0).Unit
    local v2 = (p2 - p0).Unit
    return math.acos(math.clamp(v1:Dot(v2), -1, 1))
end

-- Check if player can be targeted
local function IsValidTarget(player)
    if player == LocalPlayer then return false end
    if not player.Character or not player.Character:FindFirstChild(AimbotConfig.TargetPart) then return false end
    
    local humanoid = player.Character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    
    -- Team check
    if AimbotConfig.TeamCheck and player.Team == LocalPlayer.Team then return false end
    
    -- Distance check
    local targetPart = player.Character[AimbotConfig.TargetPart]
    local distance = (targetPart.Position - Camera.CFrame.Position).Magnitude
    if distance > AimbotConfig.MaxDistance then return false end
    
    -- Visibility check
    if AimbotConfig.VisibilityCheck then
        local origin = Camera.CFrame.Position
        local direction = (targetPart.Position - origin).Unit * distance
        local ray = Ray.new(origin, direction)
        local hit, _ = workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character, Camera})
        
        if hit and not hit:IsDescendantOf(player.Character) then
            return false
        end
    end
    
    -- Check if in FOV
    local screenPos, onScreen = Camera:WorldToScreenPoint(targetPart.Position)
    if not onScreen then return false end
    
    local centerScreen = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local distFromCenter = (Vector2.new(screenPos.X, screenPos.Y) - centerScreen).Magnitude
    
    return distFromCenter <= AimbotConfig.FOV
end

-- Get closest player to cursor
local function GetClosestPlayerToCursor()
    local closestPlayer = nil
    local shortestDistance = math.huge
    
    for _, player in pairs(Players:GetPlayers()) do
        if not IsValidTarget(player) then continue end
        
        local targetPart = player.Character[AimbotConfig.TargetPart]
        local screenPos, onScreen = Camera:WorldToScreenPoint(targetPart.Position)
        
        if onScreen then
            local cursorPos = Vector2.new(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
            local distance = (Vector2.new(screenPos.X, screenPos.Y) - cursorPos).Magnitude
            
            if distance < shortestDistance then
                shortestDistance = distance
                closestPlayer = player
            end
        end
    end
    
    return closestPlayer
end

-- Predict target position
local function PredictTargetPosition(targetPart)
    local velocity = targetPart.AssemblyLinearVelocity
    return targetPart.Position + (velocity * AimbotConfig.PredictionFactor)
end

-- Aim at target
local function AimAt(targetPart)
    if not targetPart then return end
    
    local position = PredictTargetPosition(targetPart)
    local aimPos = Camera:WorldToScreenPoint(position)
    
    -- Calculate aim position
    local mousePos = UserInputService:GetMouseLocation()
    local moveX = (aimPos.X - mousePos.X) / AimbotConfig.Smoothing
    local moveY = (aimPos.Y - mousePos.Y) / AimbotConfig.Smoothing
    
    -- Apply anti-detection randomness
    local randomX = math.random(-3, 3) / 10
    local randomY = math.random(-3, 3) / 10
    
    -- Use mousemoverel for smoother movement
    mousemoverel(moveX + randomX, moveY + randomY)
end

-- Update FOV circle position
local function UpdateFOVCircle()
    if not FOVCircle then return end
    
    FOVCircle.Visible = AimbotConfig.Enabled and AimbotConfig.ShowFOV
    FOVCircle.Radius = AimbotConfig.FOV
    FOVCircle.Position = UserInputService:GetMouseLocation()
    FOVCircle.Color = AimbotConfig.FOVColor
end

-- Main aimbot function
local function DoAimbot()
    if not AimbotConfig.Enabled then return end
    
    UpdateFOVCircle()
    
    -- Check if aiming key is pressed
    if not aiming then return end
    
    -- Get target
    local target = GetClosestPlayerToCursor()
    
    if target then
        local targetPart = target.Character[AimbotConfig.TargetPart]
        AimAt(targetPart)
    end
end

-- Initialize aimbot
function Aimbot.Initialize()
    -- Create FOV circle
    CreateFOVCircle()
    
    -- Connect input events
    UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == AimbotConfig.TriggerKey then
            aiming = true
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == AimbotConfig.TriggerKey then
            aiming = false
        end
    end)
    
    -- Update every frame
    RunService:BindToRenderStep("SkyX_Aimbot_Update", 199, DoAimbot)
    
    return true
end

-- Stop aimbot
function Aimbot.Stop()
    RunService:UnbindFromRenderStep("SkyX_Aimbot_Update")
    
    if FOVCircle then
        FOVCircle:Remove()
        FOVCircle = nil
    end
    
    aiming = false
end

-- Configuration functions
function Aimbot.SetEnabled(value)
    AimbotConfig.Enabled = value
end

function Aimbot.SetAimPart(value)
    if value == "Head" or value == "Torso" or value == "HumanoidRootPart" then
        AimbotConfig.TargetPart = value
    end
end

function Aimbot.SetTeamCheck(value)
    AimbotConfig.TeamCheck = value
end

function Aimbot.SetVisibilityCheck(value)
    AimbotConfig.VisibilityCheck = value
end

function Aimbot.SetSmoothing(value)
    AimbotConfig.Smoothing = value
end

function Aimbot.SetFOV(value)
    AimbotConfig.FOV = value
end

function Aimbot.SetMaxDistance(value)
    AimbotConfig.MaxDistance = value
end

function Aimbot.SetShowFOV(value)
    AimbotConfig.ShowFOV = value
end

function Aimbot.SetFOVColor(value)
    AimbotConfig.FOVColor = value
end

function Aimbot.SetTriggerKey(value)
    AimbotConfig.TriggerKey = value
end

function Aimbot.SetPredictionFactor(value)
    AimbotConfig.PredictionFactor = value
end

-- Return the module
return Aimbot