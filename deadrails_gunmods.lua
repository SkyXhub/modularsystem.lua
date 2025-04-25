--[[
    SkyX Hub - Dead Rails Gun Mods Module
    Part of the SkyX modular system
    
    Features:
    - No recoil, no spread
    - Rapid fire, auto fire
    - Infinite ammo
    - Instant reload
    - Weapon unlock
]]

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Gun Mods Configuration
local GunModsConfig = {
    NoRecoil = false,
    NoSpread = false,
    RapidFire = false,
    InstantReload = false,
    InfiniteAmmo = false,
    AutoFire = false,
    FireRateMultiplier = 5, -- For rapid fire
    MaxAmmoValue = 9999 -- For infinite ammo
}

-- Original values storage
local OriginalValues = {}

-- Module table
local GunMods = {}

-- Helper function to find game's gun system
local function FindGunSystem()
    -- Try to find gun modules in standard Dead Rails locations
    local gunSystem = {}
    
    -- Check player GUI
    if LocalPlayer.PlayerGui:FindFirstChild("GunSystem") then
        gunSystem.GUI = LocalPlayer.PlayerGui.GunSystem
    end
    
    -- Check replicated storage
    local weaponSystem = ReplicatedStorage:FindFirstChild("WeaponSystem") or 
                         ReplicatedStorage:FindFirstChild("GunSystem") or
                         ReplicatedStorage:FindFirstChild("Weapons")
    
    if weaponSystem then
        gunSystem.ReplicatedModule = weaponSystem
    end
    
    -- Find weapon stats module
    local statsModule = ReplicatedStorage:FindFirstChild("WeaponStats") or
                        ReplicatedStorage:FindFirstChild("GunStats")
    
    if statsModule then
        gunSystem.StatsModule = statsModule
    end
    
    return gunSystem
end

-- Hook weapon modules to modify values
local function HookWeaponModules()
    -- Find all weapon modules
    local gunSystem = FindGunSystem()
    
    if not gunSystem or (not gunSystem.GUI and not gunSystem.ReplicatedModule) then
        warn("SkyX GunMods: Couldn't find gun system. Some features may not work properly.")
        return false
    end
    
    -- Try to require modules if available
    local success, gunModule
    
    if gunSystem.GUI then
        success, gunModule = pcall(function()
            return require(gunSystem.GUI.GunSystem)
        end)
    end
    
    if not success and gunSystem.ReplicatedModule then
        success, gunModule = pcall(function()
            return require(gunSystem.ReplicatedModule)
        end)
    end
    
    if success and gunModule then
        -- Store original functions before we modify them
        OriginalValues.GunModule = gunModule
        
        -- Optional: Hook global weapon unlock function if it exists
        if gunModule.UnlockAll then
            OriginalValues.UnlockAll = gunModule.UnlockAll
        end
    end
    
    return true
end

-- Apply gun modifications to a specific weapon
local function ApplyGunMods(tool)
    if not tool then return end
    
    -- Find gun configuration
    local gunConfig
    if tool:FindFirstChild("GunConfig") then
        gunConfig = tool.GunConfig
    elseif tool:FindFirstChild("Config") then
        gunConfig = tool.Config
    elseif tool:FindFirstChild("Settings") then
        gunConfig = tool.Settings
    end
    
    if not gunConfig then return end
    
    -- Store original values if not already stored
    if not OriginalValues[tool] then
        OriginalValues[tool] = {}
        
        -- Store original gun values
        for _, child in pairs(gunConfig:GetChildren()) do
            if child:IsA("ValueBase") then
                OriginalValues[tool][child.Name] = child.Value
            end
        end
    end
    
    -- Apply modifications based on settings
    -- No Recoil
    if GunModsConfig.NoRecoil then
        for _, child in pairs(gunConfig:GetChildren()) do
            if child.Name:lower():find("recoil") then
                child.Value = 0
            end
        end
    end
    
    -- No Spread
    if GunModsConfig.NoSpread then
        for _, child in pairs(gunConfig:GetChildren()) do
            if child.Name:lower():find("spread") or child.Name:lower():find("accuracy") then
                if typeof(child.Value) == "number" then
                    child.Value = 0
                end
            end
        end
    end
    
    -- Rapid Fire
    if GunModsConfig.RapidFire then
        for _, child in pairs(gunConfig:GetChildren()) do
            if child.Name:lower():find("firerate") or child.Name:lower():find("fire_rate") then
                if typeof(child.Value) == "number" and child.Value > 0 then
                    child.Value = child.Value / GunModsConfig.FireRateMultiplier
                end
            end
        end
    end
    
    -- Instant Reload
    if GunModsConfig.InstantReload then
        for _, child in pairs(gunConfig:GetChildren()) do
            if child.Name:lower():find("reload") then
                if typeof(child.Value) == "number" and child.Value > 0 then
                    child.Value = 0.01
                end
            end
        end
    end
    
    -- Infinite Ammo
    if GunModsConfig.InfiniteAmmo then
        for _, child in pairs(tool:GetDescendants()) do
            if child.Name == "Ammo" or child.Name == "MaxAmmo" or child.Name == "StoredAmmo" then
                if typeof(child.Value) == "number" then
                    child.Value = GunModsConfig.MaxAmmoValue
                end
            end
        end
    end
    
    -- Auto Fire
    if GunModsConfig.AutoFire and not tool.AutoFire then
        -- Create flag to indicate auto fire is enabled
        local autoFireFlag = Instance.new("BoolValue")
        autoFireFlag.Name = "AutoFire"
        autoFireFlag.Value = true
        autoFireFlag.Parent = tool
        
        -- Hook fire functions if possible
        if tool:FindFirstChild("Activate") and typeof(tool.Activate) == "function" and not OriginalValues[tool].ActivateHooked then
            OriginalValues[tool].ActivateFunction = tool.Activate
            OriginalValues[tool].ActivateHooked = true
            
            -- Replace with auto-fire function
            tool.Activate = function()
                if tool.AutoFire and tool.Equipped then
                    -- Start auto-fire loop
                    spawn(function()
                        while tool.AutoFire and tool.Equipped do
                            OriginalValues[tool].ActivateFunction()
                            wait(0.05) -- Fire rate limit
                        end
                    end)
                else
                    -- Normal activation
                    OriginalValues[tool].ActivateFunction()
                end
            end
        end
    end
end

-- Monitor equipped weapons to apply mods in real time
local function MonitorEquippedWeapons()
    -- Monitor character for tool changes
    RunService.Heartbeat:Connect(function()
        if not LocalPlayer.Character then return end
        
        local tool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
        if tool then
            ApplyGunMods(tool)
        end
    end)
    
    -- Monitor character adding to handle respawning
    LocalPlayer.CharacterAdded:Connect(function(character)
        character.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                -- Wait a bit for tool to fully initialize
                wait(0.5)
                ApplyGunMods(child)
            end
        end)
    end)
    
    if LocalPlayer.Character then
        LocalPlayer.Character.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                -- Wait a bit for tool to fully initialize
                wait(0.5)
                ApplyGunMods(child)
            end
        end)
    end
end

-- Unlock all guns function
function GunMods.UnlockAllGuns()
    local gunSystem = FindGunSystem()
    local success = false
    
    -- Try method 1: Direct module call
    if OriginalValues.GunModule and OriginalValues.GunModule.UnlockAll then
        pcall(function()
            OriginalValues.GunModule.UnlockAll()
            success = true
        end)
    end
    
    -- Try method 2: Check GUI module
    if not success and LocalPlayer.PlayerGui:FindFirstChild("GunSystem") then
        pcall(function()
            local gunModule = require(LocalPlayer.PlayerGui.GunSystem.GunSystem)
            if gunModule and gunModule.UnlockAll then
                gunModule.UnlockAll()
                success = true
            end
        end)
    end
    
    -- Try method 3: Manual unlock through RemoteEvents
    if not success then
        for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA("RemoteEvent") and 
               (obj.Name:lower():find("unlock") or obj.Name:lower():find("purchase")) then
                pcall(function()
                    obj:FireServer()
                    success = true
                end)
            end
        end
    end
    
    -- Try method 4: Find and modify weapon stats directly
    if not success and gunSystem.StatsModule then
        pcall(function()
            for _, obj in pairs(gunSystem.StatsModule:GetDescendants()) do
                if obj:IsA("BoolValue") and obj.Name:lower():find("unlock") then
                    obj.Value = true
                    success = true
                elseif obj:IsA("IntValue") and obj.Name:lower():find("level") then
                    obj.Value = 0
                    success = true
                end
            end
        end)
    end
    
    return success
end

-- Max ammo for current weapon
function GunMods.MaxAmmoCurrentWeapon()
    if not LocalPlayer.Character then return false end
    
    local tool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
    if not tool then return false end
    
    for _, child in pairs(tool:GetDescendants()) do
        if child.Name == "Ammo" or child.Name == "MaxAmmo" or child.Name == "StoredAmmo" then
            if typeof(child.Value) == "number" then
                child.Value = GunModsConfig.MaxAmmoValue
            end
        end
    end
    
    return true
end

-- Initialize gun mods
function GunMods.Initialize()
    HookWeaponModules()
    MonitorEquippedWeapons()
    return true
end

-- Stop gun mods and restore original values
function GunMods.Stop()
    -- Restore all original values
    for tool, values in pairs(OriginalValues) do
        if tool ~= "GunModule" and typeof(tool) == "Instance" and tool:IsA("Tool") then
            -- Find gun configuration
            local gunConfig
            if tool:FindFirstChild("GunConfig") then
                gunConfig = tool.GunConfig
            elseif tool:FindFirstChild("Config") then
                gunConfig = tool.Config
            elseif tool:FindFirstChild("Settings") then
                gunConfig = tool.Settings
            end
            
            if gunConfig then
                -- Restore original values
                for name, value in pairs(values) do
                    if name ~= "ActivateFunction" and name ~= "ActivateHooked" then
                        local child = gunConfig:FindFirstChild(name)
                        if child and child:IsA("ValueBase") then
                            child.Value = value
                        end
                    end
                end
            end
            
            -- Remove auto fire flag if it exists
            local autoFireFlag = tool:FindFirstChild("AutoFire")
            if autoFireFlag then
                autoFireFlag:Destroy()
            end
            
            -- Restore activate function if it was hooked
            if values.ActivateHooked and values.ActivateFunction then
                tool.Activate = values.ActivateFunction
            end
        end
    end
    
    -- Clear original values
    OriginalValues = {}
    
    -- Reset current gun mods config
    GunModsConfig.NoRecoil = false
    GunModsConfig.NoSpread = false
    GunModsConfig.RapidFire = false
    GunModsConfig.InstantReload = false
    GunModsConfig.InfiniteAmmo = false
    GunModsConfig.AutoFire = false
end

-- Configuration functions
function GunMods.SetNoRecoil(value)
    GunModsConfig.NoRecoil = value
end

function GunMods.SetNoSpread(value)
    GunModsConfig.NoSpread = value
end

function GunMods.SetRapidFire(value)
    GunModsConfig.RapidFire = value
end

function GunMods.SetInstantReload(value)
    GunModsConfig.InstantReload = value
end

function GunMods.SetInfiniteAmmo(value)
    GunModsConfig.InfiniteAmmo = value
end

function GunMods.SetAutoFire(value)
    GunModsConfig.AutoFire = value
end

function GunMods.SetFireRateMultiplier(value)
    GunModsConfig.FireRateMultiplier = value
end

function GunMods.SetMaxAmmoValue(value)
    GunModsConfig.MaxAmmoValue = value
end

-- Return the module
return GunMods