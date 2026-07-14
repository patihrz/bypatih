--[[
    Fish and Monsters! Script
    Made by: Antigravity & patihrz
    Features:
    - Knit Client Controller Scanner & Invoker
    - Auto Fishing (Remote Bypass / Knit Hook)
    - Auto Fishing (UI Fallback)
    - Auto Join Raid & Auto Tap Boss (Spam PlayerTap Remote)
    - Built-in Remote Spy & GUI Scanner
    - WalkSpeed, JumpPower, & Infinite Jump
]]--

print("=================================")
print("[F&M] Starting script...")
print("=================================")

-- Load Rayfield UI Library
local success, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)

if not success then
    warn("[F&M] Failed to load Rayfield: " .. tostring(Rayfield))
    return
end

print("[F&M] Rayfield loaded successfully!")

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local LP = Players.LocalPlayer

-- States
local autoEquip = false
local autoCast = false
local autoTap = false
local tapDelay = 0.05

-- Remote Farming States
local autoFishingRemote = false
local rodNameInput = "Fishingrod_Losi"
local floaterNameInput = "Floater_Doll"

local autoJoinRaid = false
local autoTapBoss = false
local bossTapDelay = 0.01

local remoteSpyEnabled = false

-- Create Window
local Window = Rayfield:CreateWindow({
    Name = "Fish & Monsters!",
    LoadingTitle = "Fish & Monsters Client",
    LoadingSubtitle = "by patihrz",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "FM_Suite",
        FileName = "fm_config"
    },
    KeySystem = false
})

-- TABS
local TabFishing = Window:CreateTab("Auto Fishing", 4483362458)
local TabRaid = Window:CreateTab("Raid Event", 4483362458)
local TabDeveloper = Window:CreateTab("Developer / Spy", 4483362458)
local TabPlayer = Window:CreateTab("Player / Misc", 4483362458)

----------------------------------------------------
-- HELPER FUNCTIONS
----------------------------------------------------

-- Find and equip rod
local function getRod()
    local char = LP.Character
    if char then
        local tool = char:FindFirstChildOfClass("Tool")
        if tool and (tool.Name:lower():find("rod") or tool.Name:lower():find("pancing") or tool.Name:lower():find("pole")) then
            return tool
        end
    end
    for _, tool in ipairs(LP.Backpack:GetChildren()) do
        if tool:IsA("Tool") and (tool.Name:lower():find("rod") or tool.Name:lower():find("pancing") or tool.Name:lower():find("pole")) then
            return tool
        end
    end
    return nil
end

local function equipRod()
    local rod = getRod()
    if rod and rod.Parent ~= LP.Character then
        local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:EquipTool(rod)
            print("[F&M Helper] Equipped rod: " .. rod.Name)
        end
    end
end

-- Cast Line (UI/Tool fallback)
local function castRod()
    local rod = getRod()
    if rod then
        equipRod()
        task.wait(0.1)
        rod:Activate()
        VirtualUser:Button1Down(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
        task.wait(0.05)
        VirtualUser:Button1Up(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
    end
end

-- Find Raid Orb in workspace
local function findRaidOrb()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local name = obj.Name:lower()
            if name:find("raid") or name:find("orb") or name:find("circle") or name:find("portal") or name:find("boss event") or name:find("participate") then
                if obj:IsA("BasePart") then
                    return obj
                else
                    return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                end
            end
        end
    end
    return nil
end

-- Dump table contents to console helper
local function dumpTable(t, indent)
    indent = indent or "  "
    if type(t) == "table" then
        for k, v in pairs(t) do
            if type(v) == "table" then
                print(indent .. tostring(k) .. " = {")
                dumpTable(v, indent .. "  ")
                print(indent .. "}")
            else
                print(indent .. tostring(k) .. " = " .. tostring(v) .. " (" .. typeof(v) .. ")")
            end
        end
    else
        print(indent .. tostring(t))
    end
end

-- Extract UUID from various data structures recursively
local function extractUUID(val)
    if type(val) == "string" then
        if val:match("^%x+-%x+-%x+-%x+-%x+$") or #val == 36 then
            return val
        end
    elseif type(val) == "table" then
        for k, v in pairs(val) do
            local res = extractUUID(v)
            if res then return res end
        end
    end
    return nil
end

-- Robust Knit Remote Lookup
local function findKnitRemote(serviceName, remoteName)
    local rep = game:GetService("ReplicatedStorage")
    local packages = rep:FindFirstChild("Packages")
    if packages then
        local index = packages:FindFirstChild("_Index")
        if index then
            for _, child in ipairs(index:GetChildren()) do
                if child.Name:find("sleitnick_knit") then
                    local services = child:FindFirstChild("Services", true)
                    if services then
                        local service = services:FindFirstChild(serviceName)
                        if service then
                            local rf = service:FindFirstChild("RF")
                            local re = service:FindFirstChild("RE")
                            local rem = (rf and rf:FindFirstChild(remoteName)) or (re and re:FindFirstChild(remoteName))
                            if rem then return rem end
                        end
                    end
                end
            end
        end
    end
    return rep:FindFirstChild(remoteName, true)
end

-- Try to require Knit framework Client-side
local function getKnitClient()
    local rep = game:GetService("ReplicatedStorage")
    local knitModule = rep:FindFirstChild("knit", true) or rep:FindFirstChild("Knit", true)
    if knitModule and knitModule:IsA("ModuleScript") then
        local success, Knit = pcall(require, knitModule)
        if success then
            return Knit
        end
    end
    return nil
end

----------------------------------------------------
-- AUTO FISHING TAB
----------------------------------------------------
TabFishing:CreateSection("Remote Bypass Farming (Recommended)")

TabFishing:CreateToggle({
    Name = "Auto Fishing (Remote Bypass)",
    CurrentValue = false,
    Flag = "AutoFishingRemote",
    Callback = function(value)
        autoFishingRemote = value
    end
})

TabFishing:CreateInput({
    Name = "Rod Name (for Remote)",
    PlaceholderText = "Fishingrod_Losi",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        rodNameInput = Text
    end
})

TabFishing:CreateInput({
    Name = "Floater Name (for Remote)",
    PlaceholderText = "Floater_Doll",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        floaterNameInput = Text
    end
})

TabFishing:CreateSection("UI/Tool Click Fallback")

TabFishing:CreateToggle({
    Name = "Auto Equip Rod",
    CurrentValue = false,
    Flag = "AutoEquip",
    Callback = function(value)
        autoEquip = value
    end
})

TabFishing:CreateToggle({
    Name = "Auto Cast Rod (Tool Click)",
    CurrentValue = false,
    Flag = "AutoCast",
    Callback = function(value)
        autoCast = value
    end
})

TabFishing:CreateToggle({
    Name = "Auto Tap GUI (Screen Buttons)",
    CurrentValue = false,
    Flag = "AutoTap",
    Callback = function(value)
        autoTap = value
    end
})

TabFishing:CreateSlider({
    Name = "Fishing Tap Delay (UI Mode)",
    Range = {0.01, 1},
    Increment = 0.01,
    CurrentValue = 0.05,
    Flag = "TapDelay",
    Callback = function(value)
        tapDelay = value
    end
})

----------------------------------------------------
-- REMOTE AUTO FISHING SYSTEM LOGIC
----------------------------------------------------

local function runRemoteFishingCycle()
    local ThrowFloater = findKnitRemote("FishingReplicationService", "ThrowFloater")
    local ConfirmFloatingCast = findKnitRemote("FishingReplicationService", "ConfirmFloatingCast")
    local RequestFishBite = findKnitRemote("FishingReplicationService", "RequestFishBite")
    local StartPulling = findKnitRemote("FishingReplicationService", "StartPulling")
    local StopFishing = findKnitRemote("FishingReplicationService", "StopFishing")
    local FishingPullInput = findKnitRemote("FishingRewardService", "FishingPullInput")

    if not (ThrowFloater and ConfirmFloatingCast and RequestFishBite and StartPulling and StopFishing and FishingPullInput) then
        warn("[F&M Remote Farm] Missing remotes!")
        return
    end

    equipRod()
    task.wait(0.3)

    if not autoFishingRemote then return end

    print("[F&M Remote Farm] Resetting fishing state...")
    pcall(function() StopFishing:InvokeServer() end)
    task.wait(0.2)

    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local origin = hrp.Position
    local target = origin + hrp.CFrame.LookVector * 8 + Vector3.new(0, -4.5, 0)

    -- 1. Throw Floater
    print("[F&M Remote Farm] 1. Casting Floater...")
    local floatConfig = {
        LightInfluence = 0,
        FaceCamera = true,
        Color = Color3.new(0.94117647409439, 0.3098039329052, 1),
        Transparency = 0.02,
        LightEmission = 1,
        Width = 0.24
    }

    local uuid = nil

    local castSuccess, castResult = pcall(function() 
        return ThrowFloater:InvokeServer(origin, target, rodNameInput, floaterNameInput, floatConfig, 2.5) 
    end)
    if castSuccess then
        print("[F&M Remote Farm] ThrowFloater Result:")
        dumpTable(castResult)
        uuid = extractUUID(castResult)
    end
    task.wait(1.5)

    if not autoFishingRemote then return end

    -- 2. Confirm Floating Cast
    print("[F&M Remote Farm] 2. Confirming Cast...")
    local confirmSuccess, confirmResult = pcall(function() 
        return ConfirmFloatingCast:InvokeServer() 
    end)
    if confirmSuccess then
        print("[F&M Remote Farm] ConfirmFloatingCast Result:")
        dumpTable(confirmResult)
        if not uuid then uuid = extractUUID(confirmResult) end
    end

    -- Wait for bite
    print("[F&M Remote Farm] Waiting for bite...")
    task.wait(math.random(2, 4))

    if not autoFishingRemote then return end

    -- 3. Request Fish Bite
    print("[F&M Remote Farm] 3. Requesting Fish Bite...")
    local biteSuccess, biteResult = pcall(function() 
        return RequestFishBite:InvokeServer() 
    end)
    if biteSuccess then
        print("[F&M Remote Farm] RequestFishBite Result:")
        dumpTable(biteResult)
        if not uuid then uuid = extractUUID(biteResult) end
    end
    task.wait(0.5)

    if not autoFishingRemote then return end

    -- 4. Start Pulling
    print("[F&M Remote Farm] 4. Invoking StartPulling...")
    local pullSuccess, pullResult = pcall(function() 
        return StartPulling:InvokeServer() 
    end)
    if pullSuccess then
        print("[F&M Remote Farm] StartPulling Result:")
        dumpTable(pullResult)
        if not uuid then uuid = extractUUID(pullResult) end
    end

    -- LocalPlayer Attributes Scan Fallback
    if not uuid then
        for k, v in pairs(LP:GetAttributes()) do
            if type(v) == "string" and (v:match("^%x+-%x+-%x+-%x+-%x+$") or #v == 36) then
                uuid = v
                print("[F&M Attribute Hook] Found UUID in LP Attribute (" .. k .. "): " .. uuid)
                break
            end
        end
    end

    -- Character Attributes Scan Fallback
    if not uuid and char then
        for k, v in pairs(char:GetAttributes()) do
            if type(v) == "string" and (v:match("^%x+-%x+-%x+-%x+-%x+$") or #v == 36) then
                uuid = v
                print("[F&M Attribute Hook] Found UUID in Character Attribute (" .. k .. "): " .. uuid)
                break
            end
        end
    end

    -- Knit Controller Hook Fallback (Scan all controllers for UUID properties/values)
    if not uuid then
        print("[F&M Remote Farm] Fetching UUID from local Knit controllers...")
        local Knit = getKnitClient()
        if Knit then
            for ctrlName, ctrl in pairs(Knit.Controllers or {}) do
                pcall(function()
                    for key, val in pairs(ctrl) do
                        if type(val) == "string" and (val:match("^%x+-%x+-%x+-%x+-%x+$") or #val == 36) then
                            uuid = val
                            print("[F&M Knit Hook] Found UUID by value match in (" .. ctrlName .. "." .. key .. "): " .. uuid)
                            break
                        elseif type(val) == "table" then
                            local temp = extractUUID(val)
                            if temp then
                                uuid = temp
                                print("[F&M Knit Hook] Found UUID in table (" .. ctrlName .. "." .. key .. "): " .. uuid)
                                break
                            end
                        end
                    end
                end)
                if uuid then break end
            end
        end
    end

    if not uuid then
        warn("[F&M Remote Farm] Gagal mendapatkan UUID. Mencoba menembak dengan UUID acak...")
        uuid = game:GetService("HttpService"):GenerateGUID(false):lower()
    end

    print("[F&M Remote Farm] Active Session UUID: " .. tostring(uuid))
    task.wait(0.1)

    -- 5. Spam FishingPullInput
    print("[F&M Remote Farm] 5. Tapping remote to catch fish...")
    for i = 1, 60 do
        if not autoFishingRemote then break end
        pcall(function()
            FishingPullInput:InvokeServer(uuid, "tap")
        end)
        task.wait(0.01)
    end

    task.wait(0.5)

    -- 6. Stop Fishing
    pcall(function() StopFishing:InvokeServer() end)
    print("[F&M Remote Farm] Cycle completed.")
end

-- Remote Farm Loop Thread
task.spawn(function()
    while true do
        task.wait(1)
        if autoFishingRemote then
            local status, err = pcall(runRemoteFishingCycle)
            if not status then
                warn("[F&M Remote Farm Loop Error]: " .. tostring(err))
            end
            task.wait(1)
        end
    end
end)


----------------------------------------------------
-- UI FALLBACK LOOPS
----------------------------------------------------
task.spawn(function()
    while true do
        task.wait(1)
        if autoEquip then
            equipRod()
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(3)
        if autoCast then
            local char = LP.Character
            if char then
                local rod = getRod()
                if rod and rod.Parent == char then
                    castRod()
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(tapDelay)
        if autoTap then
            pcall(function()
                for _, gui in ipairs(LP.PlayerGui:GetDescendants()) do
                    if gui:IsA("TextButton") or gui:IsA("ImageButton") then
                        if gui.Visible and gui.Active then
                            local name = gui.Name:lower()
                            local text = (gui:IsA("TextButton") and gui.Text:lower()) or ""
                            
                            if name:find("tap") or name:find("click") or name:find("reel") or name:find("shake") or name:find("fish") or
                               text:find("tap") or text:find("click") or text:find("reel") or text:find("shake") or text:find("fish") then
                                
                                firesignal(gui.MouseButton1Click)
                                firesignal(gui.Activated)
                            end
                        end
                    end
                end
            end)
        end
    end
end)


----------------------------------------------------
-- RAID EVENT TAB
----------------------------------------------------
TabRaid:CreateSection("Raid Boss Controls")

TabRaid:CreateButton({
    Name = "Teleport to Raid Orb (Join)",
    Callback = function()
        local orb = findRaidOrb()
        if orb then
            local char = LP.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.CFrame = orb.CFrame + Vector3.new(0, 3, 0)
                Rayfield:Notify({Title = "Raid Teleport", Content = "Teleported to " .. orb.Name, Duration = 3})
            end
        else
            Rayfield:Notify({Title = "Raid Teleport", Content = "Raid Orb/Circle not found in workspace!", Duration = 3})
        end
    end
})

TabRaid:CreateToggle({
    Name = "Auto Teleport to Raid Orb (Loop)",
    CurrentValue = false,
    Flag = "AutoJoinRaid",
    Callback = function(value)
        autoJoinRaid = value
    end
})

TabRaid:CreateToggle({
    Name = "Auto Tap Boss (Super Fast)",
    CurrentValue = false,
    Flag = "AutoTapBoss",
    Callback = function(value)
        autoTapBoss = value
    end
})

TabRaid:CreateSlider({
    Name = "Boss Tap Delay (Sec)",
    Range = {0.001, 0.5},
    Increment = 0.005,
    CurrentValue = 0.01,
    Flag = "BossTapDelay",
    Callback = function(value)
        bossTapDelay = value
    end
})

-- Auto Join Raid Loop
task.spawn(function()
    while true do
        task.wait(5)
        if autoJoinRaid then
            local orb = findRaidOrb()
            if orb then
                local char = LP.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.CFrame = orb.CFrame + Vector3.new(0, 3, 0)
                end
            end
        end
    end
end)

-- Auto Tap Boss Loop (Uses PlayerTap Remote)
task.spawn(function()
    while true do
        task.wait(bossTapDelay)
        if autoTapBoss then
            pcall(function()
                local PlayerTap = findKnitRemote("FishingRewardService", "PlayerTap")
                if PlayerTap then
                    -- Send multiple taps per frame to abuse the boss HP
                    for i = 1, 50 do
                        PlayerTap:InvokeServer()
                    end
                else
                    -- Fallback to UI / click detector
                    for _, desc in ipairs(Workspace:GetDescendants()) do
                        if desc:IsA("ClickDetector") then
                            if fireclickdetector then
                                for i = 1, 10 do fireclickdetector(desc, 0) end
                            end
                        end
                    end
                end
            end)
        end
    end
end)


----------------------------------------------------
-- DEVELOPER & SCANNER TAB
----------------------------------------------------
TabDeveloper:CreateSection("Network & GUI Logger (Output: F9 / Delta Console)")

TabDeveloper:CreateToggle({
    Name = "Enable Remote Spy (Print to Console)",
    CurrentValue = false,
    Flag = "RemoteSpy",
    Callback = function(value)
        remoteSpyEnabled = value
        Rayfield:Notify({
            Title = "Remote Spy",
            Content = value and "Remote Spy Enabled! Check Console." or "Remote Spy Disabled.",
            Duration = 3
        })
    end
})

TabDeveloper:CreateButton({
    Name = "Scan Knit Client Controllers",
    Callback = function()
        print("=== KNIT CONTROLLER SCAN ===")
        local Knit = getKnitClient()
        if not Knit then
            print("Knit framework not found client-side!")
            return
        end
        if not Knit.Started then
            print("Knit is not started yet.")
        end
        
        local count = 0
        for name, controller in pairs(Knit.Controllers or {}) do
            count = count + 1
            print("Controller #" .. count .. ": " .. name)
            for k, v in pairs(controller) do
                if type(v) == "function" then
                    print("  Method: " .. k)
                elseif type(v) == "string" or type(v) == "number" or type(v) == "boolean" then
                    print("  Property: " .. k .. " = " .. tostring(v))
                elseif type(v) == "table" then
                    print("  Table Property: " .. k)
                end
            end
        end
        print("=== SCAN COMPLETE ===")
        Rayfield:Notify({Title = "Knit Scan", Content = "Knit scan finished. Check console!", Duration = 3})
    end
})

TabDeveloper:CreateButton({
    Name = "Scan ReplicatedStorage (Find Remotes)",
    Callback = function()
        print("=== REPLICATEDSTORAGE REMOTE LIST ===")
        local count = 0
        for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                count = count + 1
                print(string.format("[%d] %s: %s", count, obj.ClassName, obj:GetFullName()))
            end
        end
        print("=== SCAN COMPLETE (Found " .. count .. " remotes) ===")
        Rayfield:Notify({Title = "Scan Complete", Content = "Found " .. count .. " remotes. Check Console!", Duration = 3})
    end
})

TabDeveloper:CreateButton({
    Name = "Scan Visible GUI Buttons",
    Callback = function()
        print("=== VISIBLE BUTTONS LIST ===")
        local count = 0
        for _, gui in ipairs(LP.PlayerGui:GetDescendants()) do
            if gui:IsA("TextButton") or gui:IsA("ImageButton") then
                if gui.Visible and gui.Parent and gui.Parent.Visible ~= false then
                    count = count + 1
                    local text = gui:IsA("TextButton") and gui.Text or "[Image]"
                    print(string.format("[%d] Path: %s | Text: '%s' | Name: '%s'", count, gui:GetFullName(), text, gui.Name))
                end
            end
        end
        print("=== SCAN COMPLETE (Found " .. count .. " visible buttons) ===")
        Rayfield:Notify({Title = "Scan Complete", Content = "Found " .. count .. " buttons. Check Console!", Duration = 3})
    end
})

-- Metatable Hooking for Remote Spy
local hookSuccess, err = pcall(function()
    local mt = getrawmetatable(game)
    local oldNamecall = mt.__namecall
    setreadonly(mt, false)
    
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if remoteSpyEnabled and (method == "FireServer" or method == "InvokeServer") then
            local args = {...}
            print("[Remote Fired] Path: " .. self:GetFullName() .. " | Method: " .. method)
            if #args > 0 then
                for i, v in ipairs(args) do
                    print(string.format("   [%d]: %s (%s)", i, tostring(v), typeof(v)))
                end
            else
                print("   Arguments: None")
            end
        end
        return oldNamecall(self, ...)
    end)
    
    setreadonly(mt, true)
end)

if not hookSuccess then
    warn("[F&M] Remote Spy Hooking failed: " .. tostring(err))
end


----------------------------------------------------
-- PLAYER / MISC TAB
----------------------------------------------------
local speedEnabled = false
local walkSpeedValue = 16
local jumpPowerValue = 50
local infiniteJump = false

TabPlayer:CreateSection("Character Modifiers")

TabPlayer:CreateToggle({
    Name = "WalkSpeed Hack",
    CurrentValue = false,
    Flag = "SpeedEnabled",
    Callback = function(value)
        speedEnabled = value
        local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = speedEnabled and walkSpeedValue or 16
        end
    end
})

TabPlayer:CreateSlider({
    Name = "WalkSpeed Value",
    Range = {16, 250},
    Increment = 1,
    CurrentValue = 16,
    Flag = "WSVal",
    Callback = function(value)
        walkSpeedValue = value
        if speedEnabled then
            local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.WalkSpeed = walkSpeedValue
            end
        end
    end
})

TabPlayer:CreateToggle({
    Name = "JumpPower Hack",
    CurrentValue = false,
    Flag = "JumpEnabled",
    Callback = function(value)
        local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.UseJumpPower = true
            hum.JumpPower = value and jumpPowerValue or 50
        end
    end
})

TabPlayer:CreateSlider({
    Name = "JumpPower Value",
    Range = {50, 500},
    Increment = 5,
    CurrentValue = 50,
    Flag = "JPVal",
    Callback = function(value)
        jumpPowerValue = value
        local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.UseJumpPower = true
            hum.JumpPower = jumpPowerValue
        end
    end
})

TabPlayer:CreateToggle({
    Name = "Infinite Jump",
    CurrentValue = false,
    Flag = "InfJump",
    Callback = function(value)
        infiniteJump = value
    end
})

-- WalkSpeed Respawner Hook
LP.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and speedEnabled then
        hum.WalkSpeed = walkSpeedValue
    end
end)

-- Infinite Jump Hook
game:GetService("UserInputService").JumpRequest:Connect(function()
    if infiniteJump then
        local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

print("[F&M] Script fully initialized! Load config or customize toggles.")
Rayfield:Notify({
    Title = "Fish & Monsters!",
    Content = "Script loaded successfully! Remote Bypass is ready.",
    Duration = 5
})
