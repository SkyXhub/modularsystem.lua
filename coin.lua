--[[
    SkyX MM2 Coin Collector Module
    Advanced Auto Coin Collector with Prioritization

    Include this module in your scripts by using:
    loadstring(game:HttpGet("https://raw.githubusercontent.com/SkyXhub/SkyX-hub/main/SkyX_MM2_Modules/SkyX_CoinCollector_Module.lua"))()
]]

-- Module container
local CollectorModule = {}

-- Settings
CollectorModule.Settings = {
    AutoCollectEnabled = false,
    AutoCollectCooldown = 0.5, -- Interval between collection attempts
    CollectionRadius = 12,     -- Distance to collect coins automatically
    PrioritizeNearby = true,   -- Collect closest coins first
    ESP = {
        Enabled = false,
        Color = Color3.fromRGB(255, 215, 0),
        Transparency = 0.5,
        Handles = {}
    },
    Stats = {
        CoinsCollected = 0,
        LastCollection = 0
    }
}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Advanced coin finder function
function CollectorModule.FindCoins()
    local coins = {}
    
    -- Look for coins in workspace with advanced detection
    for _, Object in pairs(workspace:GetDescendants()) do
        if (Object.Name == "Coin" or Object.Name == "CoinContainer" or 
            Object.Name:lower():find("coin") or Object.Name:lower():find("collect")) and 
            (Object:IsA("BasePart") or Object:IsA("Model")) then
            
            -- Get coin position
            local position
            if Object:IsA("BasePart") then
                position = Object.Position
            elseif Object:IsA("Model") and Object.PrimaryPart then
                position = Object.PrimaryPart.Position
            elseif Object:IsA("Model") then
                for _, part in pairs(Object:GetDescendants()) do
                    if part:IsA("BasePart") then
                        position = part.Position
                        break
                    end
                end
            end
            
            if position then
                table.insert(coins, {
                    Object = Object,
                    Position = position,
                    Distance = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and 
                              (LocalPlayer.Character.HumanoidRootPart.Position - position).Magnitude or 1000
                })
            end
        end
    end
    
    -- Sort by distance if prioritizing nearby coins
    if CollectorModule.Settings.PrioritizeNearby then
        table.sort(coins, function(a, b)
            return a.Distance < b.Distance
        end)
    end
    
    return coins
end

-- Enhanced Coin ESP function with distance display
function CollectorModule.UpdateCoinESP()
    -- Clean up old coin ESP
    for _, handle in pairs(CollectorModule.Settings.ESP.Handles) do
        if handle and handle.Parent then
            handle:Destroy()
        end
    end
    CollectorModule.Settings.ESP.Handles = {}
    
    if not CollectorModule.Settings.ESP.Enabled then return end
    
    -- Find all coins
    local coins = CollectorModule.FindCoins()
    
    -- Add ESP to coins
    for _, coinData in pairs(coins) do
        local Object = coinData.Object
        
        -- Create ESP highlight
        local Highlight = Instance.new("Highlight")
        Highlight.Name = "SkyXCoinESP_" .. Object:GetFullName()
        
        -- Apply colors
        Highlight.FillColor = CollectorModule.Settings.ESP.Color
        Highlight.OutlineColor = CollectorModule.Settings.ESP.Color
        Highlight.FillTransparency = CollectorModule.Settings.ESP.Transparency
        Highlight.OutlineTransparency = 0
        Highlight.Parent = Object
        
        -- Add distance label for coins
        if coinData.Distance <= 50 then -- Only show distance for nearby coins
            local BillboardGui = Instance.new("BillboardGui")
            BillboardGui.Name = "SkyXCoinDistance"
            BillboardGui.AlwaysOnTop = true
            BillboardGui.Size = UDim2.new(0, 100, 0, 30)
            BillboardGui.StudsOffset = Vector3.new(0, 2, 0)
            
            -- Find part to attach to
            local attachPart
            if Object:IsA("BasePart") then
                attachPart = Object
            elseif Object:IsA("Model") and Object.PrimaryPart then
                attachPart = Object.PrimaryPart
            else
                for _, part in pairs(Object:GetDescendants()) do
                    if part:IsA("BasePart") then
                        attachPart = part
                        break
                    end
                end
            end
            
            if attachPart then
                BillboardGui.Adornee = attachPart
                BillboardGui.Parent = attachPart
                
                -- Create text label
                local TextLabel = Instance.new("TextLabel")
                TextLabel.BackgroundTransparency = 1
                TextLabel.Size = UDim2.new(1, 0, 1, 0)
                TextLabel.Font = Enum.Font.GothamBold
                TextLabel.TextSize = 12
                TextLabel.TextColor3 = CollectorModule.Settings.ESP.Color
                TextLabel.TextStrokeTransparency = 0.5
                TextLabel.Text = math.floor(coinData.Distance) .. "m"
                TextLabel.Parent = BillboardGui
                
                -- Save for cleanup
                table.insert(CollectorModule.Settings.ESP.Handles, BillboardGui)
            end
        end
        
        -- Save highlight for cleanup
        table.insert(CollectorModule.Settings.ESP.Handles, Highlight)
    end
end

-- Advanced auto collect function
function CollectorModule.AutoCollectCoins()
    if not CollectorModule.Settings.AutoCollectEnabled then return end
    
    -- Apply cooldown
    local now = tick()
    if now - CollectorModule.Settings.Stats.LastCollection < CollectorModule.Settings.AutoCollectCooldown then
        return
    end
    CollectorModule.Settings.Stats.LastCollection = now
    
    -- Safety check for character
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return
    end
    
    -- Find all coins
    local coins = CollectorModule.FindCoins()
    
    -- Process collectibles in order (sorted by distance if prioritizing nearby)
    for _, coinData in pairs(coins) do
        if coinData.Distance <= CollectorModule.Settings.CollectionRadius then
            local Object = coinData.Object
            
            -- Approach 1: Try to fire touch events using FireTouchInterest
            if Object:IsA("BasePart") then
                pcall(function()
                    firetouchinterest(LocalPlayer.Character.HumanoidRootPart, Object, 0)
                    task.wait(0.1)
                    firetouchinterest(LocalPlayer.Character.HumanoidRootPart, Object, 1)
                    
                    -- Update statistics
                    CollectorModule.Settings.Stats.CoinsCollected = CollectorModule.Settings.Stats.CoinsCollected + 1
                end)
            elseif Object:IsA("Model") then
                -- Try to find collectible parts in the model
                for _, part in pairs(Object:GetDescendants()) do
                    if part:IsA("BasePart") then
                        pcall(function()
                            firetouchinterest(LocalPlayer.Character.HumanoidRootPart, part, 0)
                            task.wait(0.1)
                            firetouchinterest(LocalPlayer.Character.HumanoidRootPart, part, 1)
                            
                            -- Update statistics
                            CollectorModule.Settings.Stats.CoinsCollected = CollectorModule.Settings.Stats.CoinsCollected + 1
                        end)
                        break -- Only need to touch one part
                    end
                end
            end
            
            -- Approach 2: Try to invoke remote events (in case firetouchinterest doesn't work)
            -- This is a backup method for games that use remote events for collection
            for _, descendant in pairs(game:GetDescendants()) do
                if (descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction")) and
                    (descendant.Name:lower():find("collect") or descendant.Name:lower():find("coin") or 
                     descendant.Name:lower():find("pickup") or descendant.Name:lower():find("grab")) then
                    
                    -- Try to fire the remote with the coin as an argument
                    pcall(function()
                        if descendant:IsA("RemoteEvent") then
                            descendant:FireServer(Object)
                        elseif descendant:IsA("RemoteFunction") then
                            descendant:InvokeServer(Object)
                        end
                    end)
                end
            end
        end
    end
end

-- Start coin collection and ESP
function CollectorModule.Start()
    -- Create update connection
    CollectorModule.UpdateConnection = RunService.Heartbeat:Connect(function()
        -- Update ESP if enabled
        if CollectorModule.Settings.ESP.Enabled then
            CollectorModule.UpdateCoinESP()
        end
        
        -- Run auto-collect if enabled
        if CollectorModule.Settings.AutoCollectEnabled then
            CollectorModule.AutoCollectCoins()
        end
    end)
    
    -- Return success message
    return "SkyX Coin Collector Module started successfully"
end

-- Stop coin collection and ESP
function CollectorModule.Stop()
    -- Disconnect update connection
    if CollectorModule.UpdateConnection then
        CollectorModule.UpdateConnection:Disconnect()
        CollectorModule.UpdateConnection = nil
    end
    
    -- Clean up ESP
    for _, handle in pairs(CollectorModule.Settings.ESP.Handles) do
        if handle and handle.Parent then
            handle:Destroy()
        end
    end
    CollectorModule.Settings.ESP.Handles = {}
    
    -- Return success message
    return "SkyX Coin Collector Module stopped successfully"
end

-- Get coin collector stats
function CollectorModule.GetStats()
    return {
        CoinsCollected = CollectorModule.Settings.Stats.CoinsCollected,
        AutoCollectEnabled = CollectorModule.Settings.AutoCollectEnabled,
        ESPEnabled = CollectorModule.Settings.ESP.Enabled
    }
end

-- Initialize (does not start collector automatically)
local function Initialize()
    print("SkyX Coin Collector Module initialized")
    return CollectorModule
end

return Initialize()
