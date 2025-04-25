--[[
    SkyX Hub - Dead Rails Anti-Detection Module
    Part of the SkyX modular system
    
    Features:
    - Military-grade anti-detection system
    - Dead Rails specific anti-cheat bypass
    - Game-specific remote event protection
    - Advanced hook hiding system
    - Memory scanner protection
    - Physics & movement bypass
    - Anti-farm detection
    - Teleport spoof system
    - Anti-ban system with event sanitation
]]

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local LocalPlayer = Players.LocalPlayer

-- Anti-Detection Configuration
local AntiDetectConfig = {
    EnableTeleportSpoof = true,
    MaxSafeDistance = 50, -- Maximum safe teleport distance
    MinTeleportInterval = 0.1, -- Minimum time between teleports
    EnableRemoteSpyProtection = true,
    EnablePhysicsBypass = true,
    EnableAntiFarmDetection = true,
    EnableHookProtection = true,
    EnableDeadRailsBypass = true, -- Dead Rails specific bypass
    EnableMemoryScannerProtection = true, -- Protect from memory scanners
    EnableEnvironmentSanitization = true, -- Clean environment
    EnableAntiKick = true, -- Prevent kicks
    MaxRandomOffset = 2, -- Maximum random offset for teleport (studs)
    SafeWalkSpeed = 100, -- Maximum "safe" walkspeed
    SafeJumpPower = 200, -- Maximum "safe" jump power
    PositionUpdateDelay = 0.05 -- Delay between position updates
}

-- Module table
local AntiDetect = {}

-- Original functions storage
local OriginalFunctions = {}

-- Hook function creation (prevents detection through hooking detection)
local function CreateSecureHook(obj, methodName, hookFunction)
    -- Store original function
    if not OriginalFunctions[obj] then
        OriginalFunctions[obj] = {}
    end
    
    OriginalFunctions[obj][methodName] = obj[methodName]
    
    -- Create secure proxy function that looks identical to original
    local hookedFunction = function(...)
        return hookFunction(OriginalFunctions[obj][methodName], ...)
    end
    
    -- Apply hook using secure method
    local success, err = pcall(function()
        -- Create metatable proxy if environment allows
        local proxy = newproxy and newproxy(true) or {}
        local mt = getmetatable(proxy)
        if mt then
            mt.__call = hookedFunction
            rawset(obj, methodName, proxy)
        else
            -- Fallback to direct replacement
            obj[methodName] = hookedFunction
        end
    end)
    
    if not success then
        -- Fallback method if the proxy method fails
        obj[methodName] = hookedFunction
    end
end

-- Spoof teleport detection
local function SetupTeleportSpoof()
    local characterHooks = {}
    
    -- Hook character teleportation events
    local function hookCharacter(character)
        if not character then return end
        
        -- Wait for HumanoidRootPart
        local hrp = character:WaitForChild("HumanoidRootPart", 10)
        if not hrp then return end
        
        -- Store hook to prevent duplicate hooks
        if characterHooks[character] then return end
        characterHooks[character] = true
        
        -- Cache last position for realistic movement
        local lastValidPosition = hrp.CFrame
        local lastTeleportTime = tick()
        
        -- Create hook for :SetPrimaryPartCFrame
        if character.SetPrimaryPartCFrame and not OriginalFunctions[character] then
            CreateSecureHook(character, "SetPrimaryPartCFrame", function(original, self, targetCFrame)
                local currentTime = tick()
                local timeSinceLastTeleport = currentTime - lastTeleportTime
                
                if not AntiDetectConfig.EnableTeleportSpoof then
                    -- Pass through if spoofing is disabled
                    lastValidPosition = targetCFrame
                    lastTeleportTime = currentTime
                    return original(self, targetCFrame)
                end
                
                -- Calculate distance
                local distance = (targetCFrame.Position - lastValidPosition.Position).Magnitude
                
                -- If teleporting too far, use intermediate steps
                if distance > AntiDetectConfig.MaxSafeDistance and timeSinceLastTeleport < AntiDetectConfig.MinTeleportInterval then
                    -- Break teleport into steps to avoid detection
                    spawn(function()
                        local steps = math.ceil(distance / AntiDetectConfig.MaxSafeDistance)
                        local startPos = lastValidPosition.Position
                        local endPos = targetCFrame.Position
                        
                        for i = 1, steps do
                            local stepPosition = startPos:Lerp(endPos, i/steps)
                            local stepCFrame = CFrame.new(stepPosition, stepPosition + targetCFrame.LookVector)
                            
                            -- Call original with intermediate position
                            original(self, stepCFrame)
                            
                            -- Delay between steps based on distance
                            local stepDelay = 0.05 * (distance / AntiDetectConfig.MaxSafeDistance)
                            wait(stepDelay)
                        end
                        
                        -- Final accurate position
                        original(self, targetCFrame)
                        lastValidPosition = targetCFrame
                        lastTeleportTime = tick()
                    end)
                    
                    return
                end
                
                -- Normal teleport for safe distances
                lastValidPosition = targetCFrame
                lastTeleportTime = currentTime
                return original(self, targetCFrame)
            end)
        end
        
        -- Hook Humanoid functions to evade detection
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            local originalJumpPower = humanoid.JumpPower
            local originalWalkSpeed = humanoid.WalkSpeed
            
            -- Speed and jump changes
            CreateSecureHook(humanoid, "ChangeState", function(original, self, state)
                -- Block certain flags that might trigger anti-cheat
                if AntiDetectConfig.EnablePhysicsBypass and state == Enum.HumanoidStateType.Physics then
                    -- Prevent physics state change as it can be used for cheat detection
                    return
                end
                
                return original(self, state)
            end)
            
            -- Set up property change detectors
            humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
                -- Prevent extreme sudden changes that might flag
                if AntiDetectConfig.EnablePhysicsBypass and 
                   humanoid.WalkSpeed > AntiDetectConfig.SafeWalkSpeed and 
                   not _G.BypassedWalkSpeed then
                    humanoid.WalkSpeed = math.min(humanoid.WalkSpeed, AntiDetectConfig.SafeWalkSpeed)
                end
                
                -- Remember legitimate changes
                originalWalkSpeed = humanoid.WalkSpeed
            end)
            
            humanoid:GetPropertyChangedSignal("JumpPower"):Connect(function()
                -- Prevent extreme sudden changes that might flag
                if AntiDetectConfig.EnablePhysicsBypass and 
                   humanoid.JumpPower > AntiDetectConfig.SafeJumpPower and 
                   not _G.BypassedJumpPower then
                    humanoid.JumpPower = math.min(humanoid.JumpPower, AntiDetectConfig.SafeJumpPower)
                end
                
                -- Remember legitimate changes
                originalJumpPower = humanoid.JumpPower
            end)
        end
    end
    
    -- Hook new characters when player respawns
    LocalPlayer.CharacterAdded:Connect(hookCharacter)
    
    -- Hook current character
    if LocalPlayer.Character then
        hookCharacter(LocalPlayer.Character)
    end
end

-- Anti Remote Spy Detection
local function SetupAntiRemoteSpy()
    if not AntiDetectConfig.EnableRemoteSpyProtection then return end
    
    -- Create remote instances for hooking
    local remoteEvent = Instance.new("RemoteEvent")
    local remoteFunction = Instance.new("RemoteFunction")
    
    local fireServer = remoteEvent.FireServer
    local invokeServer = remoteFunction.InvokeServer
    
    -- Create proxies for remote firing that disallow certain detection methods
    CreateSecureHook(remoteEvent, "FireServer", function(original, self, ...)
        -- Check if this is an anti-cheat remote
        local args = {...}
        if self and self.Name and (
            self.Name:lower():find("anti") or
            self.Name:lower():find("cheat") or
            self.Name:lower():find("detect") or
            self.Name:lower():find("check")
        ) then
            -- Modify suspicious arguments
            for i, arg in pairs(args) do
                if typeof(arg) == "boolean" and arg == false then
                    args[i] = true -- Flip suspicious boolean flags
                elseif typeof(arg) == "string" and 
                      (arg:lower():find("exploit") or arg:lower():find("cheat") or arg:lower():find("hack")) then
                    args[i] = "verified" -- Replace suspicious strings
                end
            end
            
            -- Call with modified arguments
            return original(self, unpack(args))
        end
        
        -- Normal execution
        return original(self, ...)
    end)
    
    -- Same for invoke server
    CreateSecureHook(remoteFunction, "InvokeServer", function(original, self, ...)
        -- Check if this is an anti-cheat remote
        local args = {...}
        if self and self.Name and (
            self.Name:lower():find("anti") or
            self.Name:lower():find("cheat") or
            self.Name:lower():find("detect") or
            self.Name:lower():find("check")
        ) then
            -- Modify suspicious arguments
            for i, arg in pairs(args) do
                if typeof(arg) == "boolean" and arg == false then
                    args[i] = true -- Flip suspicious boolean flags
                elseif typeof(arg) == "string" and 
                      (arg:lower():find("exploit") or arg:lower():find("cheat") or arg:lower():find("hack")) then
                    args[i] = "verified" -- Replace suspicious strings
                end
            end
            
            -- Call with modified arguments
            return original(self, unpack(args))
        end
        
        -- Normal execution
        return original(self, ...)
    end)
end

-- Anti-detection for fly and noclip
local function SetupPhysicsBypass()
    if not AntiDetectConfig.EnablePhysicsBypass then return end
    
    -- Create detection-safe noclip collision group system
    local function setupCollisionGroups()
        pcall(function()
            PhysicsService:CreateCollisionGroup("SkyXNoCollide")
            PhysicsService:CollisionGroupSetCollidable("SkyXNoCollide", "Default", false)
        end)
    end
    
    setupCollisionGroups()
end

-- Dead Rails Specific Bypass
local function SetupDeadRailsBypass()
    if not AntiDetectConfig.EnableDeadRailsBypass then return end
    
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local ServerScriptService = game:GetService("ServerScriptService")
    
    -- Find and disable anti-cheat remotes
    local function disableAntiCheatRemotes()
        local antiCheatKeywords = {"anticheat", "exploit", "check", "detect", "validation", "secure", "ban"}
        
        -- Search for anti-cheat remotes
        for _, path in pairs({ReplicatedStorage, ServerScriptService}) do
            for _, descendant in pairs(path:GetDescendants()) do
                if descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction") then
                    local name = descendant.Name:lower()
                    
                    -- Check if remote name contains anti-cheat keywords
                    for _, keyword in pairs(antiCheatKeywords) do
                        if name:find(keyword) then
                            -- Override remote with dummy function
                            if descendant:IsA("RemoteEvent") then
                                CreateSecureHook(descendant, "FireServer", function(original, self, ...)
                                    -- Always return success but don't actually fire the remote
                                    return true
                                end)
                            elseif descendant:IsA("RemoteFunction") then
                                CreateSecureHook(descendant, "InvokeServer", function(original, self, ...)
                                    -- Return success value without actually invoking
                                    return true
                                end)
                            end
                            
                            print("Disabled anti-cheat remote: " .. descendant:GetFullName())
                            break
                        end
                    end
                end
            end
        end
    end
    
    -- Block specific Dead Rails anti-cheat systems
    local function blockDeadRailsAntiCheat()
        -- Dead Rails uses a network consistency check system
        -- This finds and disables network consistency checks
        
        -- Look for modules that might contain anti-cheat
        for _, module in pairs(ReplicatedStorage:GetDescendants()) do
            if module:IsA("ModuleScript") and not OriginalFunctions[module] then
                local success, result = pcall(function()
                    return require(module)
                end)
                
                if success and type(result) == "table" then
                    -- Check if this module has anti-cheat functions
                    for funcName, func in pairs(result) do
                        if type(func) == "function" and
                           (funcName:lower():find("check") or
                            funcName:lower():find("detect") or
                            funcName:lower():find("validate") or
                            funcName:lower():find("security")) then
                            
                            -- Override the function to do nothing
                            result[funcName] = function(...) return true end
                            print("Bypassed anti-cheat function: " .. module.Name .. "." .. funcName)
                        end
                    end
                end
            end
        end
        
        -- Hook the kick function
        local function protectFromKicks()
            if not AntiDetectConfig.EnableAntiKick then return end
            
            -- Hook LocalPlayer:Kick()
            if LocalPlayer.Kick and not OriginalFunctions[LocalPlayer]["Kick"] then
                CreateSecureHook(LocalPlayer, "Kick", function(original, self, ...)
                    print("Prevented kick attempt with reason: " .. tostring((...)))
                    return nil -- Don't call original function
                end)
            end
        end
        
        protectFromKicks()
    end
    
    -- Apply Dead Rails specific bypass
    disableAntiCheatRemotes()
    blockDeadRailsAntiCheat()
    
    -- Set up anti-teleport detection flags
    _G.LastPositions = {}
    _G.MovementFlags = {
        IsMovementAllowed = true, 
        LastValidation = tick(),
        ValidMovement = true
    }
    
    -- Monitor character position for suspicious flags
    RunService.Heartbeat:Connect(function()
        if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
        
        local hrp = LocalPlayer.Character.HumanoidRootPart
        if not _G.LastPositions[1] then
            -- Initialize position history
            for i = 1, 10 do
                _G.LastPositions[i] = hrp.Position
            end
        else
            -- Shift positions
            for i = 10, 2, -1 do
                _G.LastPositions[i] = _G.LastPositions[i-1]
            end
            _G.LastPositions[1] = hrp.Position
        end
        
        -- Check velocity to ensure it's within reasonable limits
        if hrp:FindFirstChild("Velocity") and hrp.Velocity.Magnitude > 500 then
            -- Cap velocity to prevent detection
            hrp.Velocity = hrp.Velocity.Unit * 500
        end
    end)
    
    print("Dead Rails bypass enabled successfully")
end

-- Memory Scanner Protection
local function SetupMemoryScannerProtection()
    if not AntiDetectConfig.EnableMemoryScannerProtection then return end
    
    -- Create fake functions to mislead scanners
    _G.legit = {}
    _G.legit.movement = {
        speed = 16,
        jump = 50,
        isFlying = false,
        isNoclip = false
    }
    
    -- Run garbage collection frequently to clear memory traces
    spawn(function()
        while true do
            wait(3)
            collectgarbage("collect")
        end
    end)
    
    -- Function to sanitize environment
    local function sanitizeEnvironment()
        if not AntiDetectConfig.EnableEnvironmentSanitization then return end
        
        -- Clean suspicious global variables
        for _, name in pairs({"exploit", "hack", "cheat", "inject", "script"}) do
            if _G[name] then
                _G[name] = nil
            end
        end
        
        -- Hide exploit functions by replacing them with legitimate-looking ones
        local exploitFuncNames = {
            "hookfunction", "hookmetamethod", "getnamecallmethod", "setreadonly",
            "makereadonly", "getrawmetatable", "setrawmetatable", "getgc", "setclipboard",
            "getconnections", "firesignal", "fireclickdetector"
        }
        
        for _, name in pairs(exploitFuncNames) do
            if getfenv()[name] and typeof(getfenv()[name]) == "function" then
                getfenv()[name .. "_original"] = getfenv()[name]  -- Backup for our use
                getfenv()[name] = function() return nil end       -- Replace with dummy
            end
        end
    end
    
    sanitizeEnvironment()
    print("Memory scanner protection enabled")
end

-- Anti-detection for farm teleports
local function SetupAntiFarmDetection()
    if not AntiDetectConfig.EnableAntiFarmDetection then return end
    
    -- Track teleport history to identify patterns
    local teleportHistory = {}
    local lastFarmTeleport = tick()
    
    -- Store in global table for access from main script
    _G.FarmTeleportData = {
        History = teleportHistory,
        LastTeleport = lastFarmTeleport,
        GetOffset = function()
            return Vector3.new(
                math.random(-AntiDetectConfig.MaxRandomOffset * 100, AntiDetectConfig.MaxRandomOffset * 100) / 100,
                math.random(0, AntiDetectConfig.MaxRandomOffset * 200) / 100,
                math.random(-AntiDetectConfig.MaxRandomOffset * 100, AntiDetectConfig.MaxRandomOffset * 100) / 100
            )
        end
    }
end

-- Initialize functions exposed to main script

-- Safe noclip function
function AntiDetect.SafeNoclip(enabled)
    if not AntiDetectConfig.EnablePhysicsBypass then
        -- Fall back to standard noclip if bypass is disabled
        if LocalPlayer.Character then
            for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = not enabled
                end
            end
        end
        return
    end
    
    if LocalPlayer.Character then
        for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                if enabled then
                    -- Instead of setting CanCollide false directly (which can be detected),
                    -- we modify the collision group to one that doesn't collide with anything
                    part.CollisionGroup = "SkyXNoCollide"
                else
                    part.CollisionGroup = "Default"
                end
            end
        end
    end
end

-- Safe fly function
function AntiDetect.SafeFly(enabled, rootPart)
    if not AntiDetectConfig.EnablePhysicsBypass then
        -- Fall back to standard fly if bypass is disabled
        return false
    end
    
    if not rootPart then
        if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            return false
        end
        rootPart = LocalPlayer.Character.HumanoidRootPart
    end
    
    if enabled then
        -- Setup hidden velocity instead of visible BodyVelocity
        if not rootPart:FindFirstChild("SkyXFlyVelocity") then
            local velPart = Instance.new("Part")
            velPart.Name = "SkyXFlyVelocity"
            velPart.Anchored = true
            velPart.CanCollide = false
            velPart.Transparency = 1
            velPart.Size = Vector3.new(0, 0, 0)
            
            -- Create weld to avoid detection
            local weld = Instance.new("Weld")
            weld.Part0 = velPart
            weld.Part1 = rootPart
            weld.C0 = CFrame.new()
            weld.C1 = CFrame.new()
            weld.Parent = velPart
            
            velPart.Parent = rootPart
        end
        
        return true
    else
        -- Clean up
        _G.LastPosition = nil
        
        if _G.FlyConnection then
            _G.FlyConnection:Disconnect()
            _G.FlyConnection = nil
        end
        
        local velPart = rootPart:FindFirstChild("SkyXFlyVelocity")
        if velPart then
            velPart:Destroy()
        end
        
        return true
    end
end

-- Safe teleport for farm functions
function AntiDetect.SafeFarmTeleport(position)
    if not AntiDetectConfig.EnableAntiFarmDetection then
        -- Fall back to standard teleport if farm detection is disabled
        if LocalPlayer.Character and LocalPlayer.Character.PrimaryPart then
            LocalPlayer.Character:SetPrimaryPartCFrame(CFrame.new(position))
        end
        return
    end
    
    local currentTime = tick()
    local timeSinceLast = currentTime - _G.FarmTeleportData.LastTeleport
    
    -- Add to history
    table.insert(_G.FarmTeleportData.History, 1, {
        position = position,
        time = currentTime
    })
    
    -- Keep history at reasonable size
    if #_G.FarmTeleportData.History > 10 then
        table.remove(_G.FarmTeleportData.History)
    end
    
    -- Check for suspicious pattern (too many teleports in short time)
    local teleportCount = 0
    for _, teleport in ipairs(_G.FarmTeleportData.History) do
        if currentTime - teleport.time < 3 then -- Last 3 seconds
            teleportCount = teleportCount + 1
        end
    end
    
    -- If too many teleports, add random delay
    local shouldDelay = teleportCount > 5 or timeSinceLast < 0.2
    
    if shouldDelay then
        local randomDelay = math.random(200, 500) / 1000 -- 0.2 to 0.5 seconds
        wait(randomDelay)
    end
    
    -- Add small random offset to destination to avoid pattern detection
    local randomOffset = _G.FarmTeleportData.GetOffset()
    
    -- Teleport to slightly offset position
    local targetPosition = position + randomOffset
    
    -- Use character's SetPrimaryPartCFrame which is already hooked by SetupTeleportSpoof
    if LocalPlayer.Character and LocalPlayer.Character.PrimaryPart then
        LocalPlayer.Character:SetPrimaryPartCFrame(CFrame.new(targetPosition))
    end
    
    _G.FarmTeleportData.LastTeleport = tick()
end

-- Initialize the anti-detection system
function AntiDetect.Initialize()
    -- Set up each anti-detection component
    if AntiDetectConfig.EnableTeleportSpoof then
        SetupTeleportSpoof()
    end
    
    if AntiDetectConfig.EnableRemoteSpyProtection then
        SetupAntiRemoteSpy()
    end
    
    if AntiDetectConfig.EnablePhysicsBypass then
        SetupPhysicsBypass()
    end
    
    if AntiDetectConfig.EnableAntiFarmDetection then
        SetupAntiFarmDetection()
    end
    
    return true
end

-- Stop the anti-detection system
function AntiDetect.Stop()
    -- Clean up as needed
    -- Most cleanup will happen automatically when functions are unhooked
    return true
end

-- Configuration functions
function AntiDetect.SetEnableTeleportSpoof(value)
    AntiDetectConfig.EnableTeleportSpoof = value
end

function AntiDetect.SetMaxSafeDistance(value)
    AntiDetectConfig.MaxSafeDistance = value
end

function AntiDetect.SetMinTeleportInterval(value)
    AntiDetectConfig.MinTeleportInterval = value
end

function AntiDetect.SetEnableRemoteSpyProtection(value)
    AntiDetectConfig.EnableRemoteSpyProtection = value
end

function AntiDetect.SetEnablePhysicsBypass(value)
    AntiDetectConfig.EnablePhysicsBypass = value
end

function AntiDetect.SetEnableAntiFarmDetection(value)
    AntiDetectConfig.EnableAntiFarmDetection = value
end

function AntiDetect.SetEnableHookProtection(value)
    AntiDetectConfig.EnableHookProtection = value
end

function AntiDetect.SetMaxRandomOffset(value)
    AntiDetectConfig.MaxRandomOffset = value
end

function AntiDetect.SetSafeWalkSpeed(value)
    AntiDetectConfig.SafeWalkSpeed = value
end

function AntiDetect.SetSafeJumpPower(value)
    AntiDetectConfig.SafeJumpPower = value
end

-- Return the module
return AntiDetect