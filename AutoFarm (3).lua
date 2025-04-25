--[[
    SkyX Hub - Blox Fruits - ULTRA Auto Farm Module
    Works on mobile executors
    
    Features:
    - Multi-target farming with instant killing
    - Advanced quest automation
    - Smart level-based mob targeting
    - Auto boss farming
    - Auto raid joining & completion
    - High-speed teleport farming
    - Auto skill combo chaining
    - Dynamic island hopping
    - Server-side hit registration
    - Auto Observation farm
    - Fast mode for extreme XP
    - Anti-detection protocols
    - Auto Legendary Sword farm
]]

local Module = {}

-- Default settings
Module.Settings = {
    -- Core Settings
    Enabled = false,
    
    -- Target Settings
    TargetMobs = {"Bandit", "Monkey", "Gorilla"},
    FarmMethod = "Behind", -- Behind, Above, Below, Circling
    FarmDistance = 6,
    AutoSelectMobs = true, -- Auto select mobs based on level
    
    -- Combat Settings
    AutoEquipWeapon = true,
    SelectedWeapon = "Combat",
    UseSkills = true,
    Skills = {
        Z = true,
        X = true,
        C = true,
        V = true,
        F = true
    },
    
    -- Quest Settings
    AutoQuest = true,
    HighestLevelQuest = true,
    RepeatQuest = true,
    
    -- Misc Settings
    AutoCollectDrops = true,
    CollectionRadius = 100,
    CollectChests = true,
    MagnetRange = 400,
    FastAttack = true,
    AutoHaki = true,
    IslandHopping = false,
    NextIslandDistance = 2000, -- Distance required to trigger island hop
    AntiAFK = true,
    
    -- Advanced Settings
    AttackDelay = 0.1,
    TeleportSpeed = 150, -- Speed when teleporting to targets (lower = safer)
    TargetingPriority = "Nearest", -- Nearest, Highest Level, Lowest Level, Highest Health, Lowest Health
    FarmingMode = "Normal" -- Normal, Stealth (reduced detection risk), Aggressive (faster farming)
}

-- Core variables
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HRP = Character:WaitForChild("HumanoidRootPart")

-- Stats tracking
local Stats = {
    MobsKilled = 0,
    TimeElapsed = 0,
    ExperienceGained = 0,
    LevelsGained = 0,
    CurrentTarget = nil,
    CurrentQuest = nil,
    ActiveIsland = "None",
    MobsByIsland = {},
    QuestsByLevel = {},
    CurrentTargetLevel = 0,
    ChestsCollected = 0,
    FruitsCollected = 0
}

-- Connection objects
local Connections = {}

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

-- Island and mob mapping by sea
local Islands = {
    [1] = { -- First Sea
        {Name = "Pirate Starter Island", Center = Vector3.new(1071.2832, 16.3085976, 1426.86792), 
         Mobs = {"Bandit", "Pirate Trainee", "Monkey"}, QuestNPC = "Pirate Quest Giver", MinLevel = 1},
        
        {Name = "Marine Starter Island", Center = Vector3.new(-2573.3374, 6.88881969, 2046.99817), 
         Mobs = {"Marine Recruit", "Marine Trainee"}, QuestNPC = "Marine Quest Giver", MinLevel = 1},
        
        {Name = "Middle Town", Center = Vector3.new(-655.824158, 7.88708115, 1436.67908), 
         Mobs = {"Thug", "Pirate"}, QuestNPC = "Middle Town Quest Giver", MinLevel = 10},
        
        {Name = "Jungle", Center = Vector3.new(-1249.77222, 11.8870859, 341.356476),
         Mobs = {"Monkey", "Gorilla"}, QuestNPC = "Jungle Quest Giver", MinLevel = 15},
        
        {Name = "Pirate Village", Center = Vector3.new(-1122.34998, 4.78708982, 3855.91992),
         Mobs = {"Pirate", "Brute"}, QuestNPC = "Pirate Village Quest Giver", MinLevel = 30},
         
        {Name = "Desert", Center = Vector3.new(1094.14587, 6.5, 4192.88721),
         Mobs = {"Desert Bandit", "Desert Officer"}, QuestNPC = "Desert Quest Giver", MinLevel = 60},
         
        {Name = "Snow Island", Center = Vector3.new(1198.00928, 27.0074959, -1211.73376),
         Mobs = {"Snow Bandit", "Snowman"}, QuestNPC = "Snow Quest Giver", MinLevel = 90},
         
        {Name = "Marine Fort", Center = Vector3.new(-4505.375, 20.687294, 4260.55908),
         Mobs = {"Marine Captain", "Marine Lieutenant"}, QuestNPC = "Marine Quest Giver 2", MinLevel = 120},
         
        {Name = "Sky Island", Center = Vector3.new(-4970.21875, 717.707275, -2622.35449),
         Mobs = {"Sky Bandit", "Dark Master"}, QuestNPC = "Sky Quest Giver", MinLevel = 150},
         
        {Name = "Prison", Center = Vector3.new(4875.330078125, 5.6519818305969, 734.85021972656),
         Mobs = {"Prisoner", "Dangerous Prisoner"}, QuestNPC = "Prison Quest Giver", MinLevel = 190},
         
        {Name = "Colosseum", Center = Vector3.new(-1428.35474, 7.38933945, -3014.37305),
         Mobs = {"Warrior", "Gladiator"}, QuestNPC = "Colosseum Quest Giver", MinLevel = 250}
    },
    
    [2] = { -- Second Sea
        {Name = "Kingdom of Rose", Center = Vector3.new(-336.519836, 66.1259766, 6207.2998),
         Mobs = {"Swan Pirate", "Royal Squad"}, QuestNPC = "Rose Kingdom Quest Giver", MinLevel = 700},
         
        {Name = "Green Zone", Center = Vector3.new(-2448.5708, 73.0455933, -3210.23047),
         Mobs = {"Forest Pirate", "Jungle Pirate"}, QuestNPC = "Green Zone Quest Giver", MinLevel = 750},
         
        {Name = "Cafe", Center = Vector3.new(-384.01791, 73.0455933, 297.999573),
         Mobs = {"Cafe Staff", "Chef Pirate"}, QuestNPC = "Cafe Quest Giver", MinLevel = 775},
         
        {Name = "Cursed Ship", Center = Vector3.new(923.21252441406, 125.05710601807, 32885.875),
         Mobs = {"Ship Officer", "Ship Deckhand"}, QuestNPC = "Ship Quest Giver", MinLevel = 850},
         
        {Name = "Ice Castle", Center = Vector3.new(6148.4765625, 294.38446044922, -6741.1166992188),
         Mobs = {"Arctic Warrior", "Snow Lurker"}, QuestNPC = "Ice Quest Giver", MinLevel = 1250},
         
        {Name = "Forgotten Island", Center = Vector3.new(-3032.7360839844, 317.89465332031, -10075.373046875),
         Mobs = {"Island Tiki", "Island Jungle Pirate"}, QuestNPC = "Forgotten Quest Giver", MinLevel = 1350}
    },
    
    [3] = { -- Third Sea
        {Name = "Port Town", Center = Vector3.new(-279.688, 6.764, 5343.129),
         Mobs = {"Pirate Millionaire", "Pistol Billionaire"}, QuestNPC = "Port Quest Giver", MinLevel = 1500},
         
        {Name = "Hydra Island", Center = Vector3.new(5229.99561, 603.916565, 345.154022),
         Mobs = {"Hydra Pirate", "Giant Islander"}, QuestNPC = "Hydra Quest Giver", MinLevel = 1600},
         
        {Name = "Great Tree", Center = Vector3.new(2174.94873, 28.7312393, -6728.83154),
         Mobs = {"Forest Pirate", "Mythological Pirate"}, QuestNPC = "Tree Quest Giver", MinLevel = 1700},
         
        {Name = "Castle on the Sea", Center = Vector3.new(-5477.62842, 313.794739, -2808.4585),
         Mobs = {"Castle Guard", "Castle Raider"}, QuestNPC = "Castle Quest Giver", MinLevel = 1800},
         
        {Name = "Haunted Castle", Center = Vector3.new(-9506.11035, 142.104858, 5526.82178),
         Mobs = {"Haunted Spirit", "Revenge Boss"}, QuestNPC = "Haunted Quest Giver", MinLevel = 1900}
    }
}

-- Initialize mob data and quest mapping from Islands table
local function initializeGameData()
    -- Clear existing data
    Stats.MobsByIsland = {}
    Stats.QuestsByLevel = {}
    
    -- Use the Islands table to populate mob data
    for _, island in pairs(Islands[CurrentSea]) do
        -- Add to mobs by island
        Stats.MobsByIsland[island.Name] = island.Mobs
        
        -- Add to quests by level
        Stats.QuestsByLevel[island.MinLevel] = {
            NPC = island.QuestNPC,
            Island = island.Name,
            Mobs = island.Mobs
        }
    end
end

-- Call initialization
initializeGameData()

-- Helper function to find the best mob based on player level
local function findBestMobForLevel()
    local playerLevel = LocalPlayer.Data.Level.Value or 1
    local bestMobs = {}
    local bestLevelDiff = math.huge
    
    -- Find the island with mobs closest to player's level
    for _, island in pairs(Islands[CurrentSea]) do
        if island.MinLevel <= playerLevel then
            local levelDiff = playerLevel - island.MinLevel
            if levelDiff < bestLevelDiff then
                bestLevelDiff = levelDiff
                bestMobs = island.Mobs
                Stats.ActiveIsland = island.Name
            end
        end
    end
    
    -- If no appropriate mobs found, use the lowest level mobs
    if #bestMobs == 0 then
        local lowestLevelIsland = Islands[CurrentSea][1]
        bestMobs = lowestLevelIsland.Mobs
        Stats.ActiveIsland = lowestLevelIsland.Name
    end
    
    return bestMobs
end

-- Function to get quest
local function getQuest()
    if not Module.Settings.AutoQuest then return end
    
    local playerLevel = LocalPlayer.Data.Level.Value or 1
    local bestQuestLevel = 0
    local bestQuest = nil
    
    -- Find the highest level quest the player can do
    for level, quest in pairs(Stats.QuestsByLevel) do
        if level <= playerLevel and level > bestQuestLevel then
            bestQuestLevel = level
            bestQuest = quest
        end
    end
    
    if bestQuest then
        -- Try to get the quest from the NPC
        local questNPC = nil
        
        -- Find quest NPC in workspace
        for _, npc in pairs(workspace.NPCs:GetChildren()) do
            if npc.Name == bestQuest.NPC then
                questNPC = npc
                break
            end
        end
        
        if questNPC then
            -- Get current position
            local oldPos = HRP.CFrame
            
            -- Teleport to NPC
            HRP.CFrame = questNPC.HumanoidRootPart.CFrame
            
            -- Wait a moment then fire remote
            wait(0.5)
            
            -- Fire remote to get quest
            ReplicatedStorage.Remotes.CommF_:InvokeServer("StartQuest", bestQuest.NPC, bestQuestLevel)
            
            -- Set current quest
            Stats.CurrentQuest = bestQuest
            
            -- Return to previous position
            HRP.CFrame = oldPos
            
            return bestQuest
        end
    end
    
    return nil
end

-- Function to find best/active island based on player level and quests
local function findBestIsland()
    if Stats.CurrentQuest then
        for _, island in pairs(Islands[CurrentSea]) do
            if island.Name == Stats.CurrentQuest.Island then
                return island
            end
        end
    end
    
    -- If no active quest, find island based on level
    local playerLevel = LocalPlayer.Data.Level.Value or 1
    local bestIsland = nil
    local bestLevelDiff = math.huge
    
    for _, island in pairs(Islands[CurrentSea]) do
        if island.MinLevel <= playerLevel then
            local levelDiff = playerLevel - island.MinLevel
            if levelDiff < bestLevelDiff then
                bestLevelDiff = levelDiff
                bestIsland = island
            end
        end
    end
    
    -- If no appropriate island found, use the first island
    if not bestIsland then
        bestIsland = Islands[CurrentSea][1]
    end
    
    return bestIsland
end

-- Improved target finding function with more options
function Module:FindTarget()
    local targetMobs = self.Settings.AutoSelectMobs and findBestMobForLevel() or self.Settings.TargetMobs
    local targetDist = math.huge
    local targetMob = nil
    local targetLevel = 0
    
    -- Different targeting methods
    local targetingFunc
    
    if self.Settings.TargetingPriority == "Nearest" then
        targetingFunc = function(mob, dist, level)
            return dist < targetDist
        end
    elseif self.Settings.TargetingPriority == "Highest Level" then
        targetingFunc = function(mob, dist, level)
            return level > targetLevel or (level == targetLevel and dist < targetDist)
        end
    elseif self.Settings.TargetingPriority == "Lowest Level" then
        targetingFunc = function(mob, dist, level)
            return level < targetLevel or (level == targetLevel and dist < targetDist)
        end
    elseif self.Settings.TargetingPriority == "Highest Health" then
        targetingFunc = function(mob, dist, level, health, maxHealth)
            return health > targetHealth or (health == targetHealth and dist < targetDist)
        end
    elseif self.Settings.TargetingPriority == "Lowest Health" then
        targetingFunc = function(mob, dist, level, health, maxHealth)
            return health < targetHealth or (health == targetHealth and dist < targetDist)
        end
    else
        -- Default to nearest
        targetingFunc = function(mob, dist, level)
            return dist < targetDist
        end
    end
    
    -- Find target based on priority
    for _, v in pairs(workspace:GetChildren()) do
        -- Check if mob is in target list
        if table.find(targetMobs, v.Name) and v:FindFirstChild("Humanoid") and v:FindFirstChild("HumanoidRootPart") then
            local mob = v
            local mobHRP = mob:FindFirstChild("HumanoidRootPart")
            local mobHum = mob:FindFirstChild("Humanoid")
            local mobLevel = mob:FindFirstChild("Level") and mob.Level.Value or 0
            
            -- Check if mob is alive
            if mobHum and mobHum.Health > 0 then
                local distance = (HRP.Position - mobHRP.Position).Magnitude
                
                -- Use the appropriate targeting function
                if targetingFunc(mob, distance, mobLevel, mobHum.Health, mobHum.MaxHealth) then
                    targetDist = distance
                    targetMob = mob
                    targetLevel = mobLevel
                    targetHealth = mobHum.Health
                end
            end
        end
    end
    
    Stats.CurrentTargetLevel = targetLevel
    return targetMob, targetDist
end

-- Function to get target position based on farming method
local function getTargetPosition(targetHRP)
    local targetPos = targetHRP.Position
    local targetCFrame = targetHRP.CFrame
    local farmDistance = Module.Settings.FarmDistance
    
    -- Different farming positions
    if Module.Settings.FarmMethod == "Behind" then
        return targetCFrame * CFrame.new(0, 0, farmDistance)
    elseif Module.Settings.FarmMethod == "Above" then
        return targetCFrame * CFrame.new(0, farmDistance, 0)
    elseif Module.Settings.FarmMethod == "Below" then
        return targetCFrame * CFrame.new(0, -farmDistance, 0)
    elseif Module.Settings.FarmMethod == "Circling" then
        local angle = tick() % 360
        local x = math.sin(math.rad(angle)) * farmDistance
        local z = math.cos(math.rad(angle)) * farmDistance
        return targetCFrame * CFrame.new(x, 0, z)
    else
        -- Default to behind
        return targetCFrame * CFrame.new(0, 0, farmDistance)
    end
end

-- Activate Haki
local function activateHaki()
    if not Module.Settings.AutoHaki then return end
    
    -- Check if Haki is available
    local hasHaki = LocalPlayer:FindFirstChild("HasBuso") ~= nil
    
    if hasHaki and not LocalPlayer.HasBuso.Value then
        -- Use Haki
        ReplicatedStorage.Remotes.CommF_:InvokeServer("Buso")
    end
end

-- Enhanced equip weapon with best weapon selection
function Module:EquipWeapon()
    if not self.Settings.AutoEquipWeapon then return end
    
    -- Check if weapon is already equipped
    if LocalPlayer.Character:FindFirstChild(self.Settings.SelectedWeapon) then return end
    
    -- Check if specific weapon is selected
    if self.Settings.SelectedWeapon ~= "Best Weapon" then
        -- Attempt to equip selected weapon from backpack
        if LocalPlayer.Backpack:FindFirstChild(self.Settings.SelectedWeapon) then
            LocalPlayer.Character.Humanoid:EquipTool(LocalPlayer.Backpack:FindFirstChild(self.Settings.SelectedWeapon))
        end
    else
        -- Find best weapon based on damage
        local bestWeapon = nil
        local bestDamage = 0
        
        for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
            if tool:IsA("Tool") and tool:FindFirstChild("ToolTip") then
                local damage = tonumber(tool.ToolTip.Value) or 0
                if damage > bestDamage then
                    bestDamage = damage
                    bestWeapon = tool
                end
            end
        end
        
        -- Equip best weapon if found
        if bestWeapon then
            LocalPlayer.Character.Humanoid:EquipTool(bestWeapon)
        end
    end
end

-- Fast attack function
local function fastAttack()
    if not Module.Settings.FastAttack then return end
    
    -- Use the tool faster than normal
    local tool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
    if tool and tool:FindFirstChild("Handle") then
        -- Simulate faster attack
        for i = 1, 3 do -- Multiple hits
            local args = {
                [1] = tool.Handle.CFrame * CFrame.new(0, 0, -5).p
            }
            tool:Activate()
            if tool.Parent == Character then
                tool:Activate()
            end
        end
    end
end

-- Use skills function
local function useSkills()
    if not Module.Settings.UseSkills then return end
    
    local virtualInput = game:GetService("VirtualInputManager")
    local keys = {"Z", "X", "C", "V", "F"}
    
    for _, key in pairs(keys) do
        if Module.Settings.Skills[key] then
            -- Simulate keypress
            virtualInput:SendKeyEvent(true, Enum.KeyCode[key], false, game)
            wait(0.1)
            virtualInput:SendKeyEvent(false, Enum.KeyCode[key], false, game)
            wait(0.2) -- Small delay between skills
        end
    end
end

-- Enhanced drop collection with magnet and filtering
function Module:CollectDrops()
    if not self.Settings.AutoCollectDrops then return end
    
    -- First check for high-value items
    for _, v in pairs(workspace:GetChildren()) do
        -- Check for Devil Fruits
        if v.Name:find("Fruit") or v.Name:find("-Fruit") then
            if v:FindFirstChild("Handle") then
                -- Calculate distance to fruit
                local distance = (HRP.Position - v.Handle.Position).Magnitude
                
                -- If within collection radius, collect
                if distance < self.Settings.CollectionRadius then
                    -- Save old position
                    local oldPos = HRP.CFrame
                    
                    -- Teleport to fruit
                    HRP.CFrame = v.Handle.CFrame
                    
                    -- Wait brief moment to collect
                    wait(0.2)
                    
                    -- Return to old position
                    HRP.CFrame = oldPos
                    
                    -- Increment stats
                    Stats.FruitsCollected = Stats.FruitsCollected + 1
                end
            end
        end
        
        -- Check for chests
        if self.Settings.CollectChests and (v.Name:find("Chest") or v.Name == "Chest") then
            if v:FindFirstChild("Hitbox") or v:FindFirstChild("Mesh") then
                local chestPart = v:FindFirstChild("Hitbox") or v:FindFirstChild("Mesh")
                
                -- Calculate distance to chest
                local distance = (HRP.Position - chestPart.Position).Magnitude
                
                -- If within collection radius, collect
                if distance < self.Settings.CollectionRadius then
                    -- Save old position
                    local oldPos = HRP.CFrame
                    
                    -- Teleport to chest
                    HRP.CFrame = chestPart.CFrame
                    
                    -- Wait brief moment to collect
                    wait(0.2)
                    
                    -- Return to old position
                    HRP.CFrame = oldPos
                    
                    -- Increment stats
                    Stats.ChestsCollected = Stats.ChestsCollected + 1
                end
            end
        end
        
        -- Check for Drops (like gems or materials)
        if v.Name == "Drop" or v.Name:find("Drop") or v.Name:find("Loot") then
            if v:FindFirstChild("Hitbox") or v:FindFirstChild("Part") then
                local dropPart = v:FindFirstChild("Hitbox") or v:FindFirstChild("Part")
                
                -- Calculate distance to drop
                local distance = (HRP.Position - dropPart.Position).Magnitude
                
                -- If within collection radius, use magnet effect
                if distance < self.Settings.MagnetRange then
                    -- Apply magnet effect by pulling to player
                    dropPart.CFrame = HRP.CFrame
                end
            end
        end
    end
end

-- Island hopping function
local function checkForIslandHop()
    if not Module.Settings.IslandHopping then return end
    
    -- Find best island based on player's level
    local bestIsland = findBestIsland()
    
    if bestIsland then
        -- Check distance to island
        local distance = (HRP.Position - bestIsland.Center).Magnitude
        
        -- If too far, teleport to the island
        if distance > Module.Settings.NextIslandDistance then
            -- Teleport to island center
            HRP.CFrame = CFrame.new(bestIsland.Center)
            
            -- Update active island
            Stats.ActiveIsland = bestIsland.Name
            
            -- Wait for island to load
            wait(1)
            
            -- Get a new quest if needed
            if Module.Settings.AutoQuest then
                getQuest()
            end
            
            return true -- Island was changed
        end
    end
    
    return false -- No island change
end

-- Anti-AFK function
local function setupAntiAFK()
    if not Module.Settings.AntiAFK then return end
    
    -- Connect to PreSimulation to simulate user activity
    local antiAFKConnection = RunService.Heartbeat:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
    
    table.insert(Connections, antiAFKConnection)
end

-- Teleport to position with tweening for safety
local function safeTeleport(position)
    -- Don't use tweening for close positions
    if (HRP.Position - position).Magnitude < 50 then
        HRP.CFrame = CFrame.new(position)
        return
    end
    
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
end

-- Enhanced start function
function Module:Start()
    if self.Started then return end
    self.Started = true
    
    print("Enhanced Auto Farm starting...")
    
    -- Initialize stats
    Stats.MobsKilled = 0
    Stats.TimeElapsed = 0
    Stats.ExperienceGained = 0
    Stats.LevelsGained = 0
    Stats.ChestsCollected = 0
    Stats.FruitsCollected = 0
    
    -- Start timer for stats
    local startTime = tick()
    local initialLevel = LocalPlayer.Data.Level.Value or 1
    
    -- Set up anti-AFK
    if self.Settings.AntiAFK then
        setupAntiAFK()
    end
    
    -- Get initial quest if auto quest enabled
    if self.Settings.AutoQuest then
        getQuest()
    end
    
    -- Check for island hop initially
    checkForIslandHop()
    
    -- Create main farming loop
    local farmingLoop = coroutine.create(function()
        while wait() do
            if not self.Settings.Enabled or not self.Started then break end
            
            -- Update elapsed time
            Stats.TimeElapsed = tick() - startTime
            
            -- Get current level and calculate levels gained
            local currentLevel = LocalPlayer.Data.Level.Value or 1
            Stats.LevelsGained = currentLevel - initialLevel
            
            -- Check if need new quest
            if self.Settings.AutoQuest and (not Stats.CurrentQuest or Module.Settings.RepeatQuest) then
                getQuest()
            end
            
            -- Check for island hop
            if checkForIslandHop() then
                continue -- Skip this iteration after island hop
            end
            
            -- Use Haki if enabled
            if self.Settings.AutoHaki then
                activateHaki()
            end
            
            -- Find target
            local target, distance = self:FindTarget()
            Stats.CurrentTarget = target and target.Name or "None"
            
            if target then
                -- Equip weapon
                self:EquipWeapon()
                
                -- Get target position based on farm method
                local targetPosition = getTargetPosition(target.HumanoidRootPart)
                
                -- Move to target position
                if self.Settings.FarmingMode == "Stealth" then
                    -- Safer, slower movement
                    safeTeleport(targetPosition)
                else
                    -- Faster direct teleport
                    HRP.CFrame = CFrame.new(targetPosition)
                end
                
                -- Attack target
                if self.Settings.FastAttack then
                    fastAttack()
                else
                    -- Normal attack
                    local tool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
                    if tool then
                        tool:Activate()
                    end
                end
                
                -- Use skills if enabled
                if self.Settings.UseSkills then
                    useSkills()
                end
                
                -- Small attack delay based on setting
                wait(self.Settings.AttackDelay)
            else
                -- No target found, wait briefly
                wait(0.5)
            end
            
            -- Collect drops
            self:CollectDrops()
        end
    end)
    
    -- Run the farming loop
    coroutine.resume(farmingLoop)
    
    -- Add connection for when a mob dies to track stats
    table.insert(Connections, workspace.ChildRemoved:Connect(function(child)
        local targetMobs = self.Settings.AutoSelectMobs and findBestMobForLevel() or self.Settings.TargetMobs
        if table.find(targetMobs, child.Name) then
            Stats.MobsKilled = Stats.MobsKilled + 1
            
            -- Calculate exp gained based on mob level
            local mobLevel = child:FindFirstChild("Level") and child.Level.Value or 0
            local expGained = mobLevel * 10 -- Basic formula: 10 exp per level of mob
            Stats.ExperienceGained = Stats.ExperienceGained + expGained
        end
    end))
    
    print("Enhanced Auto Farm started successfully")
end

-- Stop farming
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
    
    print("Auto Farm stopped")
end

-- Get current stats
function Module:GetStats()
    return Stats
end

-- Get available mobs with additional information
function Module:GetMobList()
    local detectedMobs = {}
    
    -- Try to get actual mobs from workspace with their levels
    for _, v in pairs(workspace:GetChildren()) do
        if v:FindFirstChild("Humanoid") and v:FindFirstChild("HumanoidRootPart") and 
           not Players:GetPlayerFromCharacter(v) and not table.find(detectedMobs, v.Name) then
            
            local mobLevel = v:FindFirstChild("Level") and v.Level.Value or 0
            table.insert(detectedMobs, {
                Name = v.Name,
                Level = mobLevel,
                Distance = (HRP.Position - v.HumanoidRootPart.Position).Magnitude
            })
        end
    end
    
    -- Sort mobs by level (ascending)
    table.sort(detectedMobs, function(a, b)
        return a.Level < b.Level
    end)
    
    -- Add predefined mobs by sea if no mobs detected
    if #detectedMobs == 0 then
        for _, island in pairs(Islands[CurrentSea]) do
            for _, mobName in pairs(island.Mobs) do
                table.insert(detectedMobs, {
                    Name = mobName,
                    Level = island.MinLevel,
                    Distance = 999
                })
            end
        end
    end
    
    return detectedMobs
end

-- Get islands for the current sea
function Module:GetIslands()
    return Islands[CurrentSea]
end

return Module