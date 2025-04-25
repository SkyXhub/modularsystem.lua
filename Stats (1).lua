--[[
    SkyX Hub - Blox Fruits - Stats Module
    Works on mobile executors
]]

local Module = {}

-- Default settings
Module.Settings = {
    AutoStatPoints = false,
    StatPriority = "Melee", -- Melee, Defense, Sword, Gun, Fruit
    MinimumStatsGoal = {
        Melee = 1000,
        Defense = 1000,
        Sword = 1000,
        Gun = 1000,
        DevilFruit = 1000
    }
}

-- Core variables
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Connection objects
local Connections = {}

-- Convert Blox Fruits stat names to user-friendly names
local StatNameMapping = {
    ["Melee"] = "Melee",
    ["Defense"] = "Defense",
    ["Sword"] = "Sword",
    ["Gun"] = "Gun",
    ["Demon Fruit"] = "DevilFruit",
    ["BloxFruit"] = "DevilFruit",
    ["Devil Fruit"] = "DevilFruit"
}

-- Convert back for remote calls
local RemoteStatNameMapping = {
    ["Melee"] = "Melee",
    ["Defense"] = "Defense",
    ["Sword"] = "Sword",
    ["Gun"] = "Gun",
    ["DevilFruit"] = "Demon Fruit"
}

-- Function to get player's current stats
function Module:GetPlayerStats()
    local stats = {
        Level = 0,
        Beli = 0,
        Fragments = 0,
        Stats = {
            Melee = 0,
            Defense = 0,
            Sword = 0,
            Gun = 0,
            DevilFruit = 0
        },
        UnassignedPoints = 0
    }
    
    -- Try to get stats from player data
    local success, err = pcall(function()
        -- Get level and currencies
        if LocalPlayer:FindFirstChild("Data") then
            if LocalPlayer.Data:FindFirstChild("Level") then
                stats.Level = LocalPlayer.Data.Level.Value
            end
            
            if LocalPlayer.Data:FindFirstChild("Beli") then
                stats.Beli = LocalPlayer.Data.Beli.Value
            end
            
            if LocalPlayer.Data:FindFirstChild("Fragments") then
                stats.Fragments = LocalPlayer.Data.Fragments.Value
            end
        end
        
        -- Get stat points
        if LocalPlayer:FindFirstChild("Points") then
            stats.UnassignedPoints = LocalPlayer.Points.Value
        end
        
        -- Get allocated stats
        for statName, userStatName in pairs(StatNameMapping) do
            local statValue = 0
            
            -- Try different paths to find stats
            if LocalPlayer:FindFirstChild("Stats") and LocalPlayer.Stats:FindFirstChild(statName) then
                statValue = LocalPlayer.Stats[statName].Value
            elseif LocalPlayer:FindFirstChild(statName .. "Stats") then
                statValue = LocalPlayer[statName .. "Stats"].Value
            elseif LocalPlayer:FindFirstChild(statName) then
                statValue = LocalPlayer[statName].Value
            end
            
            stats.Stats[userStatName] = statValue
        end
    end)
    
    -- Return stats (even if partially populated)
    return stats
end

-- Function to determine which stat to upgrade
function Module:DetermineStatToUpgrade(currentStats)
    -- Follow priority until minimum goal is reached
    local priorityList = {}
    
    -- If priority is specified, add it first
    if Module.Settings.StatPriority ~= "" then
        table.insert(priorityList, Module.Settings.StatPriority)
    end
    
    -- Add other stats to list
    for statName, _ in pairs(currentStats.Stats) do
        if statName ~= Module.Settings.StatPriority then
            table.insert(priorityList, statName)
        end
    end
    
    -- Check if minimum goals have been reached
    for _, statName in ipairs(priorityList) do
        local currentValue = currentStats.Stats[statName]
        local goalValue = Module.Settings.MinimumStatsGoal[statName]
        
        if currentValue < goalValue then
            return statName
        end
    end
    
    -- If all minimum goals reached, return priority stat
    return Module.Settings.StatPriority
end

-- Function to upgrade a stat
function Module:UpgradeStat(statName)
    local remoteStatName = RemoteStatNameMapping[statName] or statName
    local success, result = pcall(function()
        -- Find the appropriate remote for upgrading stats
        local statsRemote = nil
        
        -- Search for the remote in common locations
        if ReplicatedStorage:FindFirstChild("Remotes") then
            statsRemote = ReplicatedStorage.Remotes:FindFirstChild("CommF_") or
                         ReplicatedStorage.Remotes:FindFirstChild("StatsRemote")
        end
        
        if not statsRemote and ReplicatedStorage:FindFirstChild("CommF_") then
            statsRemote = ReplicatedStorage:FindFirstChild("CommF_")
        end
        
        if statsRemote then
            -- Call the remote to upgrade stat
            return statsRemote:InvokeServer("AddPoint", remoteStatName, 1)
        else
            return false, "Stats remote not found"
        end
    end)
    
    return success and result or false
end

-- Auto stats upgrade loop
function Module:StartAutoStats()
    if self.StatsLoopRunning then return end
    self.StatsLoopRunning = true
    
    -- Create the loop
    spawn(function()
        while wait(1) do
            if not Module.Settings.AutoStatPoints or not self.StatsLoopRunning then break end
            
            -- Get current stats
            local currentStats = self:GetPlayerStats()
            
            -- Check if there are points to spend
            if currentStats.UnassignedPoints > 0 then
                -- Determine which stat to upgrade
                local statToUpgrade = self:DetermineStatToUpgrade(currentStats)
                
                -- Upgrade the stat
                local success = self:UpgradeStat(statToUpgrade)
                
                if success then
                    print("Upgraded " .. statToUpgrade .. " stat")
                else
                    print("Failed to upgrade " .. statToUpgrade .. " stat")
                    wait(5) -- Wait longer on failure to prevent spam
                end
            end
        end
    end)
end

-- Stop auto stats upgrade
function Module:StopAutoStats()
    self.StatsLoopRunning = false
end

-- Start module
function Module:Start()
    if self.Started then return end
    self.Started = true
    
    print("Stats module starting...")
    
    -- Start auto stats if enabled
    if Module.Settings.AutoStatPoints then
        self:StartAutoStats()
    end
    
    -- Add settings change listener
    table.insert(Connections, RunService.Heartbeat:Connect(function()
        -- Start or stop auto stats based on current setting
        if Module.Settings.AutoStatPoints and not self.StatsLoopRunning then
            self:StartAutoStats()
        elseif not Module.Settings.AutoStatPoints and self.StatsLoopRunning then
            self:StopAutoStats()
        end
    end))
    
    print("Stats module started")
end

-- Stop module
function Module:Stop()
    self.Started = false
    
    -- Stop auto stats
    self:StopAutoStats()
    
    -- Disconnect all connections
    for _, connection in pairs(Connections) do
        if connection then
            connection:Disconnect()
        end
    end
    
    -- Clear connections table
    table.clear(Connections)
    
    print("Stats module stopped")
end

return Module