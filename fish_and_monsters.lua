--[[
    Fish and Monsters! Script
    Made by: Antigravity & patihrz
    Features:
    - Auto Equip & Auto Cast
    - GUI-based Auto Tap (Faster than Macro)
    - Auto Join Raid & Auto Tap Boss (GUI/ClickDetector Spam)
    - Built-in Remote Spy & GUI Scanner (Outputs to F9 Console / `/console`)
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
        end
    end
end

-- Cast Line
local function castRod()
    local rod = getRod()
    if rod then
        equipRod()
        task.wait(0.1)
        rod:Activate()
        -- Simulate a click fallback
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

----------------------------------------------------
-- AUTO FISHING TAB
----------------------------------------------------
TabFishing:CreateSection("Fishing Controls")

TabFishing:CreateToggle({
    Name = "Auto Equip Rod",
    CurrentValue = false,
    Flag = "AutoEquip",
    Callback = function(value)
        autoEquip = value
    end
})

TabFishing:CreateToggle({
    Name = "Auto Cast Rod",
    CurrentValue = false,
    Flag = "AutoCast",
    Callback = function(value)
        autoCast = value
    end
})

TabFishing:CreateToggle({
    Name = "Auto Tap GUI (Fast Catch)",
    CurrentValue = false,
    Flag = "AutoTap",
    Callback = function(value)
        autoTap = value
    end
})

TabFishing:CreateSlider({
    Name = "Fishing Tap Delay",
    Range = {0.01, 1},
    Increment = 0.01,
    CurrentValue = 0.05,
    Flag = "TapDelay",
    Callback = function(value)
        tapDelay = value
    end
})

-- Auto Fishing Loops
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
        task.wait(3) -- Cast check frequency
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
                            
                            -- Detect fishing minigame tap buttons
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

-- Auto Tap Boss Loop (Abuses GUI signals and ClickDetectors at high speed)
task.spawn(function()
    while true do
        task.wait(bossTapDelay)
        if autoTapBoss then
            pcall(function()
                -- 1. Click physical click detectors on the Boss model in Workspace
                for _, desc in ipairs(Workspace:GetDescendants()) do
                    if desc:IsA("ClickDetector") then
                        if fireclickdetector then
                            for i = 1, 10 do
                                fireclickdetector(desc, 0)
                            end
                        end
                    end
                end
                
                -- 2. Click Raid Tap UI Buttons
                for _, gui in ipairs(LP.PlayerGui:GetDescendants()) do
                    if gui:IsA("TextButton") or gui:IsA("ImageButton") then
                        if gui.Visible and gui.Active then
                            local name = gui.Name:lower()
                            local text = (gui:IsA("TextButton") and gui.Text:lower()) or ""
                            
                            if name:find("boss") or name:find("raid") or name:find("tap") or name:find("click") or
                               text:find("boss") or text:find("raid") or text:find("tap") or text:find("click") then
                                
                                -- Abuse tap: fire 20 times in a single loop
                                for i = 1, 20 do
                                    firesignal(gui.MouseButton1Click)
                                    firesignal(gui.Activated)
                                end
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
TabDeveloper:CreateSection("Network & GUI Logger (Output: F9 Console)")

TabDeveloper:CreateToggle({
    Name = "Enable Remote Spy (Print to F9)",
    CurrentValue = false,
    Flag = "RemoteSpy",
    Callback = function(value)
        remoteSpyEnabled = value
        Rayfield:Notify({
            Title = "Remote Spy",
            Content = value and "Remote Spy Enabled! Type /console in chat to view logs." or "Remote Spy Disabled.",
            Duration = 3
        })
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
        Rayfield:Notify({Title = "Scan Complete", Content = "Found " .. count .. " remotes. Check F9 console!", Duration = 3})
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
        Rayfield:Notify({Title = "Scan Complete", Content = "Found " .. count .. " buttons. Check F9 console!", Duration = 3})
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
    Content = "Script loaded successfully! Open /console in chat to view Spy info.",
    Duration = 5
})
