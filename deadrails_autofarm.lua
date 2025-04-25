--[[
    SkyX Hub - Dead Rails Auto Farm Module
    Part of the SkyX modular system
    
    Features:
    - Auto Bone Farm
    - Auto End
    - Auto Weapon Collector
    - Advanced Detection Avoidance
]]

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")

-- Auto Farm Configuration
local FarmConfig = {
    AutoBone = false,
    AutoEnd = false,
    AutoWeapons = false,
    FarmDelay = 0.5, -- Delay between teleports
    FarmDistance = 20, -- Maximum distance to detect items
    CollectionNames = { -- Names of items to collect
        "bone", "collect", "pickup", "coin", "gem", "cash", "money"
    },
    EndZoneNames = { -- Names of end zones
        "end", "finish", "goal", "exit", "trigger", "complete"
    },
    WeaponNames = { -- Names for weapons
        "weapon", "gun", "pickup", "rifle", "pistol", "shotgun"
    },
    SafeTeleport = true, -- Use anti-detection system
    RandomizeOrder = true, -- Randomize collection order
    AvoidRepetition = true, -- Avoid teleporting to the same spot repeatedly
    VisualFeedback = true, -- Show visual feedback when teleporting
    DebugOutput = false -- Show debug messages
}

-- Module table
local AutoFarm = {}

-- Track farm state
local FarmState = {
    LastBoneCollected = tick(),
    LastEndTeleport = tick(),
    LastWeaponCollected = tick(),
    CollectedItems = {}, -- Track which items were already collected
    FailedAttempts = 0,
    CurrentTarget = nil,
    IsFarming = false,
    FarmLoopActive = false
}

-- Reset farm state
local function ResetFarmState()
    FarmState.CollectedItems = {}
    FarmState.FailedAttempts = 0
    FarmState.CurrentTarget = nil
    FarmState.LastBoneCollected = tick()
    FarmState.LastEndTeleport = tick()
    FarmState.LastWeaponCollected = tick()
end

-- Debug print
local function DebugPrint(...)
    if FarmConfig.DebugOutput then
        print("SkyX AutoFarm:", ...)
    end
end

-- Find end zones
local function FindEndZones()
    local endZones = {}
    
    -- Search for common end trigger names
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.CanTouch ~= false then
            local objName = obj.Name:lower()
            for _, keyword in pairs(FarmConfig.EndZoneNames) do
                if objName:find(keyword) then
                    table.insert(endZones, obj)
                    break
                end
            end
        end
    end
    
    -- Also check for parts with specific properties that might be end zones
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Transparency > 0.8 and obj.CanCollide == false then
            if not table.find(endZones, obj) then
                table.insert(endZones, obj)
            end
        end
    end
    
    return endZones
end

-- Find collectible items
local function FindCollectibles()
    local collectibles = {}
    
    -- Search for collectibles
    for _, obj in pairs(Workspace:GetDescendants()) do
        if (obj:IsA("BasePart") or obj:IsA("Model")) and not FarmState.CollectedItems[obj] then
            local objName = obj.Name:lower()
            for _, keyword in pairs(FarmConfig.CollectionNames) do
                if objName:find(keyword) then
                    table.insert(collectibles, obj)
                    break
                end
            end
        end
    end
    
    -- Randomize order if enabled
    if FarmConfig.RandomizeOrder and #collectibles > 1 then
        -- Fisher-Yates shuffle
        for i = #collectibles, 2, -1 do
            local j = math.random(i)
            collectibles[i], collectibles[j] = collectibles[j], collectibles[i]
        end
    end
    
    return collectibles
end

-- Find weapons
local function FindWeapons()
    local weapons = {}
    
    -- Search for weapons
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChild("Pickup") and not FarmState.CollectedItems[obj] then
            table.insert(weapons, obj)
        end
    end
    
    -- Add other weapon-like objects
    for _, obj in pairs(Workspace:GetDescendants()) do
        if (obj:IsA("BasePart") or obj:IsA("Model")) and not FarmState.CollectedItems[obj] and not table.find(weapons, obj) then
            local objName = obj.Name:lower()
            for _, keyword in pairs(FarmConfig.WeaponNames) do
                if objName:find(keyword) then
                    table.insert(weapons, obj)
                    break
                end
            end
        end
    end
    
    -- Randomize order if enabled
    if FarmConfig.RandomizeOrder and #weapons > 1 then
        -- Fisher-Yates shuffle
        for i = #weapons, 2, -1 do
            local j = math.random(i)
            weapons[i], weapons[j] = weapons[j], weapons[i]
        end
    end
    
    return weapons
end

-- Get position from object
local function GetObjectPosition(obj)
    if obj:IsA("BasePart") then
        return obj.Position
    elseif obj:IsA("Model") then
        if obj.PrimaryPart then
            return obj.PrimaryPart.Position
        else
            local part = obj:FindFirstChildWhichIsA("BasePart")
            if part then
                return part.Position
            end
        end
    end
    
    return nil
end

-- Teleport to object safely
local function TeleportToObject(obj, heightOffset)
    if not obj or not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return false
    end
    
    local position = GetObjectPosition(obj)
    if not position then
        return false
    end
    
    -- Add height offset
    if heightOffset then
        position = position + Vector3.new(0, heightOffset, 0)
    end
    
    -- Teleport using AntiDetect system if enabled
    if FarmConfig.SafeTeleport and _G.SafeFarmTeleport then
        _G.SafeFarmTeleport(position)
        return true
    else
        -- Standard teleport
        LocalPlayer.Character:SetPrimaryPartCFrame(CFrame.new(position))
        return true
    end
end

-- Mark item as collected
local function MarkAsCollected(obj)
    FarmState.CollectedItems[obj] = tick()
    
    -- Clean up collected items older than 30 seconds
    for item, time in pairs(FarmState.CollectedItems) do
        if tick() - time > 30 then
            FarmState.CollectedItems[item] = nil
        end
    end
end

-- Visual feedback function
local function ShowVisualFeedback(obj, feedbackType)
    if not FarmConfig.VisualFeedback then return end
    
    local position = GetObjectPosition(obj)
    if not position then return end
    
    local color
    if feedbackType == "bone" then
        color = Color3.fromRGB(255, 215, 0) -- Gold
    elseif feedbackType == "end" then
        color = Color3.fromRGB(0, 255, 0) -- Green
    elseif feedbackType == "weapon" then
        color = Color3.fromRGB(0, 128, 255) -- Blue
    else
        color = Color3.fromRGB(255, 255, 255) -- White
    end
    
    -- Create visual effect
    local part = Instance.new("Part")
    part.Size = Vector3.new(0.5, 0.5, 0.5)
    part.Position = position
    part.Anchored = true
    part.CanCollide = false
    part.Color = color
    part.Material = Enum.Material.Neon
    part.Shape = Enum.PartType.Ball
    part.Transparency = 0.3
    part.Parent = Workspace
    
    -- Animate and remove
    spawn(function()
        for i = 1, 10 do
            part.Size = part.Size + Vector3.new(0.2, 0.2, 0.2)
            part.Transparency = part.Transparency + 0.07
            wait(0.03)
        end
        part:Destroy()
    end)
end

-- Auto bone farm function
local function DoBoneFarm()
    if not FarmConfig.AutoBone then return end
    
    -- Check if we should wait
    if tick() - FarmState.LastBoneCollected < FarmConfig.FarmDelay then return end
    
    -- Find collectibles
    local collectibles = FindCollectibles()
    
    if #collectibles == 0 then
        DebugPrint("No collectibles found")
        FarmState.FailedAttempts = FarmState.FailedAttempts + 1
        
        -- If no collectibles found several times, clear collected history
        if FarmState.FailedAttempts > 5 then
            FarmState.CollectedItems = {}
            FarmState.FailedAttempts = 0
        end
        
        return
    end
    
    -- Get nearest collectible
    local nearestDist = math.huge
    local nearestObj = nil
    
    for _, obj in pairs(collectibles) do
        local pos = GetObjectPosition(obj)
        if pos then
            local dist = (LocalPlayer.Character.HumanoidRootPart.Position - pos).Magnitude
            if dist < nearestDist and dist < FarmConfig.FarmDistance then
                nearestDist = dist
                nearestObj = obj
            end
        end
    end
    
    -- If no nearby collectibles, try one from the list
    if not nearestObj and #collectibles > 0 then
        nearestObj = collectibles[1]
    end
    
    if nearestObj then
        FarmState.CurrentTarget = nearestObj
        
        DebugPrint("Teleporting to collectible:", nearestObj.Name)
        TeleportToObject(nearestObj, 3) -- Teleport above item
        ShowVisualFeedback(nearestObj, "bone")
        
        -- Mark as collected
        MarkAsCollected(nearestObj)
        FarmState.LastBoneCollected = tick()
        FarmState.FailedAttempts = 0
    end
end

-- Auto end function
local function DoEndFarm()
    if not FarmConfig.AutoEnd then return end
    
    -- Check if we should wait
    if tick() - FarmState.LastEndTeleport < FarmConfig.FarmDelay * 2 then return end
    
    -- Find end zones
    local endZones = FindEndZones()
    
    if #endZones == 0 then
        DebugPrint("No end zones found")
        return
    end
    
    -- Get nearest end zone
    local nearestDist = math.huge
    local nearestZone = nil
    
    for _, zone in pairs(endZones) do
        local dist = (LocalPlayer.Character.HumanoidRootPart.Position - zone.Position).Magnitude
        if dist < nearestDist then
            nearestDist = dist
            nearestZone = zone
        end
    end
    
    if nearestZone then
        FarmState.CurrentTarget = nearestZone
        
        DebugPrint("Teleporting to end zone:", nearestZone.Name)
        TeleportToObject(nearestZone, 2) -- Teleport slightly above
        ShowVisualFeedback(nearestZone, "end")
        
        FarmState.LastEndTeleport = tick()
    end
end

-- Auto weapon collection function
local function DoWeaponFarm()
    if not FarmConfig.AutoWeapons then return end
    
    -- Check if we should wait
    if tick() - FarmState.LastWeaponCollected < FarmConfig.FarmDelay then return end
    
    -- Find weapons
    local weapons = FindWeapons()
    
    if #weapons == 0 then
        DebugPrint("No weapons found")
        return
    end
    
    -- Get nearest weapon
    local nearestDist = math.huge
    local nearestWeapon = nil
    
    for _, weapon in pairs(weapons) do
        local pos = GetObjectPosition(weapon)
        if pos then
            local dist = (LocalPlayer.Character.HumanoidRootPart.Position - pos).Magnitude
            if dist < nearestDist and dist < FarmConfig.FarmDistance then
                nearestDist = dist
                nearestWeapon = weapon
            end
        end
    end
    
    -- If no nearby weapons, try one from the list
    if not nearestWeapon and #weapons > 0 then
        nearestWeapon = weapons[1]
    end
    
    if nearestWeapon then
        FarmState.CurrentTarget = nearestWeapon
        
        DebugPrint("Teleporting to weapon:", nearestWeapon.Name)
        TeleportToObject(nearestWeapon, 3) -- Teleport above weapon
        ShowVisualFeedback(nearestWeapon, "weapon")
        
        -- Mark as collected
        MarkAsCollected(nearestWeapon)
        FarmState.LastWeaponCollected = tick()
    end
end

-- Main farm loop
local function FarmLoop()
    if FarmState.FarmLoopActive then return end
    FarmState.FarmLoopActive = true
    
    -- Keep track of errors
    local errorCount = 0
    
    spawn(function()
        while FarmState.IsFarming do
            local success, err = pcall(function()
                if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    DebugPrint("Waiting for character...")
                    return
                end
                
                -- Call each farming function in order
                if FarmConfig.AutoBone then
                    DoBoneFarm()
                end
                
                wait(FarmConfig.FarmDelay * 0.5) -- Small delay between operations
                
                if FarmConfig.AutoWeapons then
                    DoWeaponFarm()
                end
                
                wait(FarmConfig.FarmDelay * 0.5) -- Small delay between operations
                
                if FarmConfig.AutoEnd then
                    DoEndFarm()
                end
                
                -- Reset error count on success
                errorCount = 0
            end)
            
            if not success then
                errorCount = errorCount + 1
                warn("SkyX AutoFarm Error:", err)
                
                -- If too many errors, pause farming briefly
                if errorCount > 5 then
                    warn("Too many AutoFarm errors, pausing for 5 seconds")
                    wait(5)
                    errorCount = 0
                    ResetFarmState() -- Reset farm state
                end
            end
            
            wait(FarmConfig.FarmDelay)
        end
        
        FarmState.FarmLoopActive = false
    end)
end

-- Initialize auto farm
function AutoFarm.Initialize()
    -- Set up initial state
    ResetFarmState()
    return true
end

-- Start auto farm
function AutoFarm.StartFarming()
    if not FarmState.IsFarming then
        FarmState.IsFarming = true
        FarmLoop()
        return true
    end
    return false
end

-- Stop auto farm
function AutoFarm.StopFarming()
    FarmState.IsFarming = false
    return true
end

-- Stop module
function AutoFarm.Stop()
    AutoFarm.StopFarming()
    return true
end

-- Configuration functions
function AutoFarm.SetAutoBone(value)
    FarmConfig.AutoBone = value
    if value and not FarmState.IsFarming then
        AutoFarm.StartFarming()
    end
end

function AutoFarm.SetAutoEnd(value)
    FarmConfig.AutoEnd = value
    if value and not FarmState.IsFarming then
        AutoFarm.StartFarming()
    end
end

function AutoFarm.SetAutoWeapons(value)
    FarmConfig.AutoWeapons = value
    if value and not FarmState.IsFarming then
        AutoFarm.StartFarming()
    end
end

function AutoFarm.SetFarmDelay(value)
    FarmConfig.FarmDelay = value
end

function AutoFarm.SetFarmDistance(value)
    FarmConfig.FarmDistance = value
end

function AutoFarm.SetSafeTeleport(value)
    FarmConfig.SafeTeleport = value
end

function AutoFarm.SetRandomizeOrder(value)
    FarmConfig.RandomizeOrder = value
end

function AutoFarm.SetAvoidRepetition(value)
    FarmConfig.AvoidRepetition = value
end

function AutoFarm.SetVisualFeedback(value)
    FarmConfig.VisualFeedback = value
end

function AutoFarm.SetDebugOutput(value)
    FarmConfig.DebugOutput = value
end

-- Return the module
return AutoFarm