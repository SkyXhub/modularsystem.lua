--[[
    SkyX Hub - Blox Fruits - Items Collection Module
    Works on mobile executors
    
    Features:
    - Auto collect all types of items across all seas
    - Support for special events items
    - Auto farm materials and resources
    - Auto open chests and get rewards
]]

local Module = {}

-- Default settings
Module.Settings = {
    -- Core Settings
    Enabled = false,
    
    -- Collection Settings
    CollectionRadius = 150,
    TeleportSpeed = 200,
    
    -- Item Types
    CollectChests = true,
    CollectFruits = true,
    CollectFlowers = true,
    CollectGems = true,
    CollectMaterials = true,
    CollectEventItems = true,
    
    -- Sea-Specific Settings
    FirstSea = {
        Enabled = true,
        Items = {
            "Chests",
            "Bandit Chests",
            "Pirate Chests",
            "Desert Chests",
            "Snow Chests",
            "Prison Chests"
        }
    },
    
    SecondSea = {
        Enabled = true,
        Items = {
            "Kingdom Chests",
            "Cafe Ingredients",
            "Ship Artifacts",
            "Ice Fragments",
            "Ancient Scrolls"
        }
    },
    
    ThirdSea = {
        Enabled = true,
        Items = {
            "Port Treasures",
            "Hydra Scales",
            "Dragon Scales",
            "Mystic Droplets",
            "Ancient Stones",
            "Rainbow Essence"
        }
    },
    
    -- Advanced Settings
    AutoStoreItems = true,
    RefreshRate = 0.5, -- How often to check for new items
    SafeMode = true, -- Use safer teleporting
    SeaHopping = false, -- Hop between seas to collect items (can be risky)
    Notifications = true
}

-- Core variables
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HRP = Character:WaitForChild("HumanoidRootPart")

-- Connection objects
local Connections = {}

-- Stats tracking
local Stats = {
    ChestsCollected = 0,
    FruitsCollected = 0,
    FlowersCollected = 0,
    GemsCollected = 0,
    MaterialsCollected = 0,
    EventItemsCollected = 0,
    TotalItemsCollected = 0,
    ItemsByType = {},
    LastItemCollected = "",
    TimeElapsed = 0
}

-- Sea check
local function getCurrentSea()
    local placeId = game.PlaceId
    if placeId == 2753915549 then
        return 1 -- First Sea
    elseif placeId == 4442272183 then
        return 2 -- Second Sea
    elseif placeId == 7449423635 then
        return 3 -- Third Sea
    end
    return 1 -- Default
end

local CurrentSea = getCurrentSea()

-- Item databases by sea
local ItemDatabases = {
    [1] = { -- First Sea
        Chests = {
            {Name = "Bandit Chest", Center = Vector3.new(1041.5232, 17.0635643, 1323.89246)},
            {Name = "Pirate Chest", Center = Vector3.new(-1181.12793, 4.75208712, 3855.93896)},
            {Name = "Desert Chest", Center = Vector3.new(1101.18628, 5.61915398, 4040.12012)},
            {Name = "Snow Chest", Center = Vector3.new(1200.09009, 27.7812462, -1199.61694)},
            {Name = "Prison Chest", Center = Vector3.new(4857.50049, 5.6777916, 747.506348)}
        },
        
        Flowers = {
            {Name = "Red Flower", Center = Vector3.new(-1197.98389, 11.8870859, 186.111099)},
            {Name = "Blue Flower", Center = Vector3.new(-960.05957, 21.5636292, -79.8459778)},
            {Name = "Yellow Flower", Center = Vector3.new(-1366.95532, 11.8870859, 116.612297)}
        },
        
        Materials = {
            {Name = "Leather", Center = Vector3.new(-1245.4104, 6.78370619, 47.9050217)},
            {Name = "Iron Ore", Center = Vector3.new(-689.813477, 7.8469944, 1533.51196)},
            {Name = "Wood", Center = Vector3.new(-690.33783, 15.1608324, 1582.75391)}
        }
    },
    
    [2] = { -- Second Sea
        Chests = {
            {Name = "Kingdom Chest", Center = Vector3.new(-218.395493, 66.5628738, 5014.82373)},
            {Name = "Green Zone Chest", Center = Vector3.new(-2291.0332, 42.8426094, -2585.95166)},
            {Name = "Hot Island Chest", Center = Vector3.new(-5913.09961, 49.6545944, -5111.15234)},
            {Name = "Cursed Ship Chest", Center = Vector3.new(923.21252441406, 125.05710601807, 32885.875)},
            {Name = "Forgotten Chest", Center = Vector3.new(-3052.19385, 238.881958, -10148.6943)}
        },
        
        Materials = {
            {Name = "Mystic Droplet", Center = Vector3.new(-3499.58423, 253.25615, -9449.6748)},
            {Name = "Dragon Scale", Center = Vector3.new(5621.14746, 603.425049, -236.337143)},
            {Name = "Fish Tail", Center = Vector3.new(-67.9356842, 55.8159714, 4324.53564)},
            {Name = "Magma Ore", Center = Vector3.new(-5281.3374, 10.9788561, 8518.29492)}
        },
        
        EventItems = {
            {Name = "Shark Tooth", Center = Vector3.new(-42.3548355, 85.5863342, 5328.64307)},
            {Name = "Ghost Fire", Center = Vector3.new(-9516.99316, 172.104858, 6078.4165)}
        }
    },
    
    [3] = { -- Third Sea
        Chests = {
            {Name = "Port Chest", Center = Vector3.new(-448.966034, 6.697146, 5525.66064)},
            {Name = "Hydra Island Chest", Center = Vector3.new(5221.90771, 602.738953, 75.8590698)},
            {Name = "Great Tree Chest", Center = Vector3.new(2372.5874, 25.9278584, -6854.7959)},
            {Name = "Castle Chest", Center = Vector3.new(-5075.50244, 316.233765, -3156.39233)},
            {Name = "Haunted Castle Chest", Center = Vector3.new(-9530.61328, 142.104858, 5528.52734)}
        },
        
        Materials = {
            {Name = "Rainbow Essence", Center = Vector3.new(-11704.2871, 331.748993, -8653.8877)},
            {Name = "Mystic Scales", Center = Vector3.new(5310.61035, 602.584351, 186.974533)},
            {Name = "Ancient Wood", Center = Vector3.new(2204.77148, 28.7944012, -6574.69336)},
            {Name = "Fire Essence", Center = Vector3.new(-5583.62939, 313.60907, -2816.99829)},
            {Name = "Spirit Ember", Center = Vector3.new(-9549.0957, 172.104858, 6032.63086)}
        },
        
        EventItems = {
            {Name = "Soul Fragment", Center = Vector3.new(-8944.81152, 142.104858, 6057.55518)},
            {Name = "Cursed Bone", Center = Vector3.new(-9504.59863, 172.104858, 6166.58496)},
            {Name = "Ancient Scroll", Center = Vector3.new(-11414.5381, 613.9646, -9119.83594)}
        }
    }
}

-- Get current item database based on sea
local function getCurrentItemDatabase()
    return ItemDatabases[CurrentSea]
end

-- Function to check if a workspace object is a collectible item
local function isCollectibleItem(obj)
    -- Item names/patterns to look for
    local itemPatterns = {
        Chest = {"Chest", "Treasure", "Box", "Crate"},
        Fruit = {"Fruit", "-Fruit", "DevilFruit"},
        Flower = {"Flower", "Petal", "Blossom"},
        Gem = {"Gem", "Diamond", "Ruby", "Emerald", "Sapphire"},
        Material = {"Material", "Ore", "Wood", "Leather", "Scale", "Essence", "Fragment", 
                    "Droplet", "Fire", "Soul", "Bone", "Scroll", "Tail", "Tooth"},
        EventItem = {"Event", "Holiday", "Special", "Ticket", "Token"}
    }
    
    -- Check if object has necessarry parts
    if not (obj:FindFirstChild("Handle") or obj:FindFirstChild("Hitbox") or obj:FindFirstChild("Mesh") or 
            obj:FindFirstChild("Main")) then
        return false, nil
    end
    
    -- Check name against patterns
    for itemType, patterns in pairs(itemPatterns) do
        for _, pattern in pairs(patterns) do
            if obj.Name:find(pattern) then
                return true, itemType
            end
        end
    end
    
    return false, nil
end

-- Function to get the main part of an item for teleporting
local function getItemPart(item)
    -- Try to find the main part for teleporting
    return item:FindFirstChild("Handle") or 
           item:FindFirstChild("Hitbox") or 
           item:FindFirstChild("Mesh") or 
           item:FindFirstChild("Main") or
           item:FindFirstChildWhichIsA("BasePart")
end

-- Create notification
local function createNotification(title, text, duration)
    if not Module.Settings.Notifications then return end
    
    -- Create notification UI
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "ItemNotification"
    
    -- Handle different exploit protection models
    if syn then
        syn.protect_gui(ScreenGui)
        ScreenGui.Parent = game.CoreGui
    else
        ScreenGui.Parent = gethui and gethui() or game.CoreGui
    end
    
    -- Create frame
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(0, 250, 0, 80)
    Frame.Position = UDim2.new(1, -260, 0.75, 0)
    Frame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    Frame.BorderSizePixel = 0
    Frame.Parent = ScreenGui
    
    -- Create corner
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 6)
    Corner.Parent = Frame
    
    -- Create title
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 25)
    Title.BackgroundTransparency = 1
    Title.Text = title
    Title.TextColor3 = Color3.fromRGB(255, 200, 0)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 16
    Title.Parent = Frame
    
    -- Create text
    local Text = Instance.new("TextLabel")
    Text.Size = UDim2.new(1, 0, 0, 55)
    Text.Position = UDim2.new(0, 0, 0, 25)
    Text.BackgroundTransparency = 1
    Text.Text = text
    Text.TextColor3 = Color3.fromRGB(255, 255, 255)
    Text.Font = Enum.Font.Gotham
    Text.TextSize = 14
    Text.Parent = Frame
    
    -- Animation
    Frame.Position = UDim2.new(1, 20, 0.75, 0)
    local Tween = TweenService:Create(Frame, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Position = UDim2.new(1, -260, 0.75, 0)})
    Tween:Play()
    
    -- Auto destroy
    game:GetService("Debris"):AddItem(ScreenGui, duration or 3)
end

-- Safe teleport function with tweening
local function safeTeleport(position)
    if Module.Settings.SafeMode and (HRP.Position - position).Magnitude > 50 then
        -- Create a tween for smooth movement
        local tweenInfo = TweenInfo.new(
            (HRP.Position - position).Magnitude / Module.Settings.TeleportSpeed,
            Enum.EasingStyle.Linear,
            Enum.EasingDirection.Out
        )
        
        local tween = TweenService:Create(HRP, tweenInfo, {CFrame = CFrame.new(position)})
        tween:Play()
        
        -- Wait for tween to complete
        tween.Completed:Wait()
    else
        -- Direct teleport
        HRP.CFrame = CFrame.new(position)
        wait(0.1) -- Small wait to ensure collection
    end
end

-- Function to collect a specific item
local function collectItem(item)
    local itemPart = getItemPart(item)
    
    if not itemPart then return false end
    
    -- Save current position
    local oldPosition = HRP.CFrame
    
    -- Teleport to item
    safeTeleport(itemPart.Position)
    
    -- Wait for collection
    wait(0.2)
    
    -- Return to old position
    HRP.CFrame = oldPosition
    
    -- Return success
    return true
end

-- Function to scan for items in an area
local function scanForItemsInArea(areaCenter, radius)
    local items = {}
    
    -- Check all workspace objects
    for _, obj in pairs(workspace:GetChildren()) do
        local isItem, itemType = isCollectibleItem(obj)
        
        if isItem then
            local itemPart = getItemPart(obj)
            
            if itemPart and (itemPart.Position - areaCenter).Magnitude <= radius then
                table.insert(items, {
                    Object = obj,
                    Type = itemType,
                    Position = itemPart.Position,
                    Distance = (itemPart.Position - HRP.Position).Magnitude
                })
            end
        end
    end
    
    -- Sort items by distance
    table.sort(items, function(a, b)
        return a.Distance < b.Distance
    end)
    
    return items
end

-- Function to scan all database areas for items
local function scanDatabaseAreas()
    local items = {}
    local itemDatabase = getCurrentItemDatabase()
    
    -- Scan through all database categories
    for category, locations in pairs(itemDatabase) do
        -- Check if category is enabled in settings
        local categoryEnabled = false
        
        if category == "Chests" and Module.Settings.CollectChests then
            categoryEnabled = true
        elseif category == "Flowers" and Module.Settings.CollectFlowers then
            categoryEnabled = true
        elseif category == "Materials" and Module.Settings.CollectMaterials then
            categoryEnabled = true
        elseif category == "EventItems" and Module.Settings.CollectEventItems then
            categoryEnabled = true
        end
        
        if categoryEnabled then
            for _, location in pairs(locations) do
                -- Scan area around location center
                local areaItems = scanForItemsInArea(location.Center, Module.Settings.CollectionRadius)
                
                -- Add to main items table
                for _, item in pairs(areaItems) do
                    table.insert(items, item)
                end
            end
        end
    end
    
    -- Sort all items by distance
    table.sort(items, function(a, b)
        return a.Distance < b.Distance
    end)
    
    return items
end

-- Function to scan around player for items
local function scanAroundPlayer()
    return scanForItemsInArea(HRP.Position, Module.Settings.CollectionRadius)
end

-- Function to update stats after collecting an item
local function updateStats(itemType, itemName)
    -- Update specific counter
    if itemType == "Chest" then
        Stats.ChestsCollected = Stats.ChestsCollected + 1
    elseif itemType == "Fruit" then
        Stats.FruitsCollected = Stats.FruitsCollected + 1
    elseif itemType == "Flower" then
        Stats.FlowersCollected = Stats.FlowersCollected + 1
    elseif itemType == "Gem" then
        Stats.GemsCollected = Stats.GemsCollected + 1
    elseif itemType == "Material" then
        Stats.MaterialsCollected = Stats.MaterialsCollected + 1
    elseif itemType == "EventItem" then
        Stats.EventItemsCollected = Stats.EventItemsCollected + 1
    end
    
    -- Update total
    Stats.TotalItemsCollected = Stats.TotalItemsCollected + 1
    
    -- Update last item
    Stats.LastItemCollected = itemName
    
    -- Update items by type
    Stats.ItemsByType[itemName] = (Stats.ItemsByType[itemName] or 0) + 1
end

-- Store items in inventory/storage function
local function storeCollectedItems()
    if not Module.Settings.AutoStoreItems then return end
    
    -- This would need implementation specific to the game
    -- For Blox Fruits, it might involve remote calls to store items
    
    -- General approach:
    pcall(function()
        local storeRemote = ReplicatedStorage.Remotes:FindFirstChild("StoreItems") or
                           ReplicatedStorage.Remotes:FindFirstChild("CommF_")
        
        if storeRemote then
            storeRemote:InvokeServer("StoreItems")
        end
    end)
end

-- Main item collection function
function Module:CollectItems()
    if not self.Settings.Enabled then return end
    
    -- First scan around player (faster collection of nearby items)
    local nearbyItems = scanAroundPlayer()
    
    for _, item in pairs(nearbyItems) do
        -- Check if item type is enabled for collection
        local canCollect = false
        
        if item.Type == "Chest" and self.Settings.CollectChests then
            canCollect = true
        elseif item.Type == "Fruit" and self.Settings.CollectFruits then
            canCollect = true
        elseif item.Type == "Flower" and self.Settings.CollectFlowers then
            canCollect = true
        elseif item.Type == "Gem" and self.Settings.CollectGems then
            canCollect = true
        elseif item.Type == "Material" and self.Settings.CollectMaterials then
            canCollect = true
        elseif item.Type == "EventItem" and self.Settings.CollectEventItems then
            canCollect = true
        end
        
        if canCollect then
            -- Try to collect the item
            local success = collectItem(item.Object)
            
            if success then
                -- Update stats
                updateStats(item.Type, item.Object.Name)
                
                -- Show notification
                createNotification("Item Collected!", "Found: " .. item.Object.Name, 2)
            end
        end
    end
    
    -- If we're in active item collection mode, also scan database areas
    if #nearbyItems == 0 then
        -- Scan database areas
        local databaseItems = scanDatabaseAreas()
        
        -- Try to collect up to 3 items (to prevent excessive teleporting)
        local itemsCollected = 0
        
        for _, item in pairs(databaseItems) do
            -- Check if item type is enabled for collection
            local canCollect = false
            
            if item.Type == "Chest" and self.Settings.CollectChests then
                canCollect = true
            elseif item.Type == "Fruit" and self.Settings.CollectFruits then
                canCollect = true
            elseif item.Type == "Flower" and self.Settings.CollectFlowers then
                canCollect = true
            elseif item.Type == "Gem" and self.Settings.CollectGems then
                canCollect = true
            elseif item.Type == "Material" and self.Settings.CollectMaterials then
                canCollect = true
            elseif item.Type == "EventItem" and self.Settings.CollectEventItems then
                canCollect = true
            end
            
            if canCollect then
                -- Try to collect the item
                local success = collectItem(item.Object)
                
                if success then
                    -- Update stats
                    updateStats(item.Type, item.Object.Name)
                    
                    -- Show notification
                    createNotification("Item Collected!", "Found: " .. item.Object.Name, 2)
                    
                    -- Increment counter
                    itemsCollected = itemsCollected + 1
                    
                    -- Limit to 3 items per scan to prevent excessive teleporting
                    if itemsCollected >= 3 then
                        break
                    end
                end
            end
        end
        
        -- If auto store is enabled and we collected items, store them
        if itemsCollected > 0 and self.Settings.AutoStoreItems then
            storeCollectedItems()
        end
    end
end

-- Function to toggle sea-specific settings
function Module:SetSeaEnabled(seaNumber, enabled)
    if seaNumber == 1 then
        self.Settings.FirstSea.Enabled = enabled
    elseif seaNumber == 2 then
        self.Settings.SecondSea.Enabled = enabled
    elseif seaNumber == 3 then
        self.Settings.ThirdSea.Enabled = enabled
    end
end

-- Start module
function Module:Start()
    if self.Started then return end
    self.Started = true
    
    print("Items collection module starting...")
    
    -- Reset stats
    Stats.ChestsCollected = 0
    Stats.FruitsCollected = 0
    Stats.FlowersCollected = 0
    Stats.GemsCollected = 0
    Stats.MaterialsCollected = 0
    Stats.EventItemsCollected = 0
    Stats.TotalItemsCollected = 0
    Stats.ItemsByType = {}
    Stats.LastItemCollected = ""
    
    -- Start timer
    local startTime = tick()
    
    -- Create collection loop
    table.insert(Connections, RunService.Heartbeat:Connect(function()
        -- Update time elapsed
        Stats.TimeElapsed = tick() - startTime
        
        -- Only run collection at specified refresh rate
        if tick() % self.Settings.RefreshRate <= 0.1 then
            self:CollectItems()
        end
    end))
    
    -- Add connection for when new items appear in workspace
    table.insert(Connections, workspace.ChildAdded:Connect(function(child)
        -- Check if it's a collectible item
        local isItem, itemType = isCollectibleItem(child)
        
        if isItem then
            -- Wait for the item to fully load
            wait(0.5)
            
            -- Check if this item type is enabled for collection
            local canCollect = false
            
            if itemType == "Chest" and self.Settings.CollectChests then
                canCollect = true
            elseif itemType == "Fruit" and self.Settings.CollectFruits then
                canCollect = true
            elseif itemType == "Flower" and self.Settings.CollectFlowers then
                canCollect = true
            elseif itemType == "Gem" and self.Settings.CollectGems then
                canCollect = true
            elseif itemType == "Material" and self.Settings.CollectMaterials then
                canCollect = true
            elseif itemType == "EventItem" and self.Settings.CollectEventItems then
                canCollect = true
            end
            
            if canCollect then
                -- Show notification for new item
                createNotification("New Item Spawned!", "Found: " .. child.Name, 3)
                
                -- Try to collect it if within reasonable distance
                local itemPart = getItemPart(child)
                if itemPart and (itemPart.Position - HRP.Position).Magnitude <= Module.Settings.CollectionRadius * 1.5 then
                    self:CollectItems()
                end
            end
        end
    end))
    
    -- Initial collection run
    self:CollectItems()
    
    print("Items collection module started")
end

-- Stop module
function Module:Stop()
    self.Started = false
    
    -- Disconnect all connections
    for _, connection in pairs(Connections) do
        if connection then
            connection:Disconnect()
        end
    end
    
    -- Clear connections table
    Connections = {}
    
    print("Items collection module stopped")
end

-- Get current stats
function Module:GetStats()
    return Stats
end

-- Get available item types for current sea
function Module:GetAvailableItemTypes()
    local itemTypes = {}
    local itemDatabase = getCurrentItemDatabase()
    
    for category, _ in pairs(itemDatabase) do
        table.insert(itemTypes, category)
    end
    
    return itemTypes
end

return Module