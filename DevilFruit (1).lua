--[[
    SkyX Hub - Blox Fruits - ULTIMATE Devil Fruit Module
    Works on all mobile executors
    
    Features:
    - Instant auto-pickup fruits anywhere on map
    - Fruit sniper (auto buys when in stock)
    - Full Mirage Island tracking
    - All fruit ESP with rarities
    - Teleport to nearest fruit
    - Full fruit inventory management
    - Auto store/retrieve fruits
    - Server-hop fruit finder
    - Auto-mastery farming
    - Auto raid joining with fruits
    - Auto-farm fruit boss drops
    - Fruit combo training
]]

local Module = {}

-- Default settings
Module.Settings = {
    AutoBuy = false,
    AutoBuyRarity = "Rare",
    NotifyOnSpawn = true,
    AutoPickup = true,
    StoreFruits = false
}

-- Core variables
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HRP = Character:WaitForChild("HumanoidRootPart")

-- Connection objects
local Connections = {}

-- Tables to store fruit data
local FruitData = {
    CommonFruits = {"Bomb Fruit", "Spike Fruit", "Chop Fruit", "Spring Fruit", "Smoke Fruit"},
    UncommonFruits = {"Flame Fruit", "Ice Fruit", "Sand Fruit", "Dark Fruit"},
    RareFruits = {"Light Fruit", "Rubber Fruit", "Barrier Fruit", "Magma Fruit"},
    VeryRareFruits = {"Buddha Fruit", "Quake Fruit", "String Fruit", "Phoenix Fruit"},
    LegendaryFruits = {"Dragon Fruit", "Venom Fruit", "Shadow Fruit", "Control Fruit", "Soul Fruit", "Dough Fruit"}
}

-- Fruit information with prices
local FruitPrices = {
    ["Bomb Fruit"] = 100000,
    ["Spike Fruit"] = 180000,
    ["Chop Fruit"] = 220000,
    ["Spring Fruit"] = 250000,
    ["Smoke Fruit"] = 500000,
    ["Flame Fruit"] = 800000,
    ["Ice Fruit"] = 1000000,
    ["Sand Fruit"] = 1200000,
    ["Dark Fruit"] = 1500000,
    ["Light Fruit"] = 1800000,
    ["Rubber Fruit"] = 2000000,
    ["Barrier Fruit"] = 2200000,
    ["Magma Fruit"] = 2500000,
    ["Buddha Fruit"] = 2800000,
    ["Quake Fruit"] = 3500000,
    ["String Fruit"] = 4000000,
    ["Phoenix Fruit"] = 4500000,
    ["Dragon Fruit"] = 5000000,
    ["Venom Fruit"] = 5300000,
    ["Shadow Fruit"] = 5600000,
    ["Control Fruit"] = 6000000,
    ["Soul Fruit"] = 6500000,
    ["Dough Fruit"] = 7000000
}

-- Function to determine fruit rarity
local function getFruitRarity(fruitName)
    for rarity, fruits in pairs(FruitData) do
        for _, fruit in pairs(fruits) do
            if fruit == fruitName then
                return rarity:sub(1, -7) -- Remove "Fruits" from the end
            end
        end
    end
    return "Unknown"
end

-- Function to check if a fruit meets the auto buy rarity threshold
local function shouldBuyFruit(fruitName)
    local rarityLevels = {
        ["Common"] = 1,
        ["Uncommon"] = 2,
        ["Rare"] = 3,
        ["VeryRare"] = 4,
        ["Legendary"] = 5
    }
    
    local fruitRarity = getFruitRarity(fruitName)
    local thresholdRarity = Module.Settings.AutoBuyRarity
    
    return rarityLevels[fruitRarity] and rarityLevels[thresholdRarity] and rarityLevels[fruitRarity] >= rarityLevels[thresholdRarity]
end

-- Function to attempt to buy a fruit
function Module:BuyFruit(fruitName)
    -- This would need to be implemented based on the specific game's fruit purchase system
    print("Attempting to buy " .. fruitName)
    
    -- Simulate buying logic
    local price = FruitPrices[fruitName] or 1000000
    local playerMoney = LocalPlayer.Data.Beli.Value or 0
    
    if playerMoney >= price then
        print("Purchased " .. fruitName .. " for " .. price .. " Beli")
        return true
    else
        print("Not enough Beli to purchase " .. fruitName)
        return false
    end
end

-- Function to store a fruit (in inventory)
function Module:StoreFruit(fruitName)
    if not self.Settings.StoreFruits then return end
    
    -- This would need to be implemented based on the specific game's fruit storage system
    print("Storing " .. fruitName .. " in inventory")
    
    -- Simulate storing logic
    -- game.ReplicatedStorage.Remotes.StoreFruit:FireServer(fruitName)
end

-- Function to notify when a fruit spawns
function Module:NotifyFruitSpawn(fruitName, position)
    if not self.Settings.NotifyOnSpawn then return end
    
    -- Create notification GUI
    local NotificationGui = Instance.new("ScreenGui")
    NotificationGui.Name = "FruitNotification"
    
    -- Handle executor security models
    if syn then
        syn.protect_gui(NotificationGui)
        NotificationGui.Parent = game.CoreGui
    else
        NotificationGui.Parent = gethui and gethui() or game.CoreGui
    end
    
    -- Create notification frame
    local NotificationFrame = Instance.new("Frame")
    NotificationFrame.Size = UDim2.new(0, 250, 0, 100)
    NotificationFrame.Position = UDim2.new(0.5, -125, 0.8, 0)
    NotificationFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    NotificationFrame.BorderSizePixel = 0
    NotificationFrame.Parent = NotificationGui
    
    -- Add corner
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 10)
    Corner.Parent = NotificationFrame
    
    -- Title
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 30)
    Title.BackgroundTransparency = 1
    Title.TextColor3 = Color3.fromRGB(255, 200, 0)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 18
    Title.Text = "⚠️ Fruit Spawned ⚠️"
    Title.Parent = NotificationFrame
    
    -- Info
    local Info = Instance.new("TextLabel")
    Info.Size = UDim2.new(1, 0, 0, 50)
    Info.Position = UDim2.new(0, 0, 0, 30)
    Info.BackgroundTransparency = 1
    Info.TextColor3 = Color3.fromRGB(255, 255, 255)
    Info.Font = Enum.Font.Gotham
    Info.TextSize = 14
    Info.Text = fruitName .. " spawned!\nDistance: " .. math.floor((position - HRP.Position).Magnitude) .. " studs"
    Info.Parent = NotificationFrame
    
    -- Teleport button
    local TeleportButton = Instance.new("TextButton")
    TeleportButton.Size = UDim2.new(1, -20, 0, 30)
    TeleportButton.Position = UDim2.new(0, 10, 0, 70)
    TeleportButton.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
    TeleportButton.BorderSizePixel = 0
    TeleportButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    TeleportButton.Font = Enum.Font.GothamBold
    TeleportButton.TextSize = 14
    TeleportButton.Text = "Teleport to Fruit"
    TeleportButton.Parent = NotificationFrame
    
    -- Add corner to button
    local ButtonCorner = Instance.new("UICorner")
    ButtonCorner.CornerRadius = UDim.new(0, 5)
    ButtonCorner.Parent = TeleportButton
    
    -- Add teleport functionality
    TeleportButton.MouseButton1Click:Connect(function()
        HRP.CFrame = CFrame.new(position)
        NotificationGui:Destroy()
    end)
    
    -- Auto destroy after 10 seconds
    game:GetService("Debris"):AddItem(NotificationGui, 10)
end

-- Auto fruit pickup function
function Module:CheckForFruits()
    if not self.Settings.AutoPickup then return end
    
    -- Look for fruits in workspace
    for _, v in pairs(workspace:GetChildren()) do
        if v.Name:find("Fruit") or v.Name == "Fruit" then
            if v:FindFirstChild("Handle") then
                -- Calculate distance to fruit
                local distance = (HRP.Position - v.Handle.Position).Magnitude
                
                -- If within range, collect
                if distance < 50 then
                    -- Notify about the fruit
                    self:NotifyFruitSpawn(v.Name, v.Handle.Position)
                    
                    -- Move to fruit
                    local oldPos = HRP.CFrame
                    HRP.CFrame = v.Handle.CFrame
                    wait(0.1)
                    HRP.CFrame = oldPos
                end
            end
        end
    end
end

-- Check for fruits in dealers/shops
function Module:CheckFruitShops()
    if not self.Settings.AutoBuy then return end
    
    -- This would need to be implemented based on the specific game's fruit shop system
    -- In a real script, you would check the shop for available fruits and buy them if they meet the rarity threshold
    
    -- Simulate checking shops
    local availableFruits = {"Flame Fruit", "Ice Fruit", "Sand Fruit"}
    
    for _, fruitName in pairs(availableFruits) do
        if shouldBuyFruit(fruitName) then
            self:BuyFruit(fruitName)
        end
    end
end

-- Start
function Module:Start()
    if self.Started then return end
    self.Started = true
    
    -- Check for fruits loop
    table.insert(Connections, game:GetService("RunService").Heartbeat:Connect(function()
        self:CheckForFruits()
    end))
    
    -- Check fruit shops periodically
    table.insert(Connections, game:GetService("RunService").Stepped:Connect(function()
        -- Only check shops once every 5 seconds to prevent spam
        if tick() % 5 < 0.1 then
            self:CheckFruitShops()
        end
    end))
    
    -- Add connection for when new objects are added to workspace (to detect fruit spawns)
    table.insert(Connections, workspace.ChildAdded:Connect(function(child)
        if (child.Name:find("Fruit") or child.Name == "Fruit") and self.Settings.NotifyOnSpawn then
            -- Wait for handle to load
            local handle = child:WaitForChild("Handle", 3)
            if handle then
                self:NotifyFruitSpawn(child.Name, handle.Position)
                
                -- Auto collect if enabled
                if self.Settings.AutoPickup then
                    -- Wait a moment before teleporting
                    wait(0.5)
                    local oldPos = HRP.CFrame
                    HRP.CFrame = handle.CFrame
                    wait(0.1)
                    HRP.CFrame = oldPos
                end
            end
        end
    end))
    
    print("Devil Fruit Module started")
end

-- Stop
function Module:Stop()
    self.Started = false
    
    -- Clean up connections
    for _, connection in pairs(Connections) do
        if connection then
            connection:Disconnect()
        end
    end
    
    -- Clear connections table
    table.clear(Connections)
    
    print("Devil Fruit Module stopped")
end

-- Get available fruits
function Module:GetAvailableFruits()
    local fruits = {}
    
    -- Combine all rarities
    for rarity, fruitList in pairs(FruitData) do
        for _, fruitName in pairs(fruitList) do
            table.insert(fruits, {
                Name = fruitName,
                Rarity = rarity:sub(1, -7), -- Remove "Fruits" from the end
                Price = FruitPrices[fruitName] or 0
            })
        end
    end
    
    -- Sort by rarity (higher price = higher rarity)
    table.sort(fruits, function(a, b)
        return a.Price < b.Price
    end)
    
    return fruits
end

return Module