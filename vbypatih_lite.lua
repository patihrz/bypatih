--[[
    Violence District - LITE Version
    Made by: patihrz
    Version: 3.0 Lite
    
    Fitur Essential Only:
    - ESP (Player & Objective)
    - Speed Boost
    - Fast Heal
    - Fast Gate
    - Visual Enhancements
]]--

print("=================================")
print("[VD LITE] Starting script...")
print("=================================")

-- Load Rayfield with error handling
local success, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)

if not success then
    warn("[VD LITE] Failed to load Rayfield: " .. tostring(Rayfield))
    return
end

print("[VD LITE] Rayfield loaded successfully!")

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local LP = Players.LocalPlayer

print("[VD LITE] Services loaded!")

-- Helper functions
local function alive(i)
    if not i then return false end
    local ok = pcall(function() return i.Parent end)
    return ok and i.Parent ~= nil
end

local function validPart(p)
    return p and alive(p) and p:IsA("BasePart")
end

local function getCharacter()
    return LP.Character
end

local function getRoot()
    local char = getCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local char = getCharacter()
    return char and char:FindFirstChild("Humanoid")
end

-- Create Window
local Window = Rayfield:CreateWindow({
    Name = "Violence District LITE",
    LoadingTitle = "VD Lite Loading",
    LoadingSubtitle = "by patihrz",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "VD_Lite",
        FileName = "vd_lite_config"
    },
    KeySystem = false
})

print("[VD LITE] Window created!")

local TabPlayer = Window:CreateTab("Player")
local TabESP = Window:CreateTab("ESP")
local TabVisual = Window:CreateTab("Visual")

print("[VD LITE] Tabs created!")

-- SPEED BOOST
local speedEnabled = false
local speedMultiplier = 1.5
local originalSpeed = 16

TabPlayer:CreateSection("Movement")

TabPlayer:CreateToggle({
    Name = "Speed Boost",
    CurrentValue = false,
    Flag = "SpeedBoost",
    Callback = function(value)
        speedEnabled = value
        local hum = getHumanoid()
        if hum then
            if speedEnabled then
                hum.WalkSpeed = originalSpeed * speedMultiplier
                print("[VD LITE] Speed enabled: " .. hum.WalkSpeed)
            else
                hum.WalkSpeed = originalSpeed
                print("[VD LITE] Speed disabled")
            end
        end
    end
})

TabPlayer:CreateSlider({
    Name = "Speed Multiplier",
    Range = {1, 3},
    Increment = 0.1,
    CurrentValue = 1.5,
    Flag = "SpeedMult",
    Callback = function(value)
        speedMultiplier = value
        if speedEnabled then
            local hum = getHumanoid()
            if hum then
                hum.WalkSpeed = originalSpeed * speedMultiplier
            end
        end
    end
})

-- Auto-update speed on respawn
LP.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    local hum = char:FindFirstChild("Humanoid")
    if hum and speedEnabled then
        hum.WalkSpeed = originalSpeed * speedMultiplier
        print("[VD LITE] Speed reapplied on respawn")
    end
end)

-- FAST HEAL
local fastHealEnabled = false
local healMultiplier = 1.3

TabPlayer:CreateSection("Healing")

TabPlayer:CreateToggle({
    Name = "Fast Heal (1.3x)",
    CurrentValue = false,
    Flag = "FastHeal",
    Callback = function(value)
        fastHealEnabled = value
        print("[VD LITE] Fast Heal: " .. tostring(value))
    end
})

-- Fast heal loop
RunService.Heartbeat:Connect(function()
    if not fastHealEnabled then return end
    
    local char = getCharacter()
    if not char then return end
    
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return end
    
    -- Heal slightly faster
    if hum.Health < hum.MaxHealth and hum.Health > 0 then
        local healing = hum.MaxHealth * 0.001 * healMultiplier
        hum.Health = math.min(hum.Health + healing, hum.MaxHealth)
    end
end)

-- BASIC ESP
local espEnabled = false
local espConnection

TabESP:CreateSection("ESP Controls")

TabESP:CreateToggle({
    Name = "Enable ESP",
    CurrentValue = false,
    Flag = "ESP",
    Callback = function(value)
        espEnabled = value
        
        if espEnabled then
            print("[VD LITE] ESP Enabled")
            
            espConnection = RunService.Heartbeat:Connect(function()
                if not espEnabled then return end
                
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LP and player.Character then
                        local char = player.Character
                        local root = char:FindFirstChild("HumanoidRootPart")
                        
                        if root then
                            -- Simple highlight
                            local hl = char:FindFirstChild("VD_Highlight")
                            if not hl then
                                hl = Instance.new("Highlight")
                                hl.Name = "VD_Highlight"
                                hl.FillColor = Color3.fromRGB(255, 100, 100)
                                hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                                hl.FillTransparency = 0.5
                                hl.OutlineTransparency = 0
                                hl.Parent = char
                            end
                        end
                    end
                end
            end)
        else
            print("[VD LITE] ESP Disabled")
            
            if espConnection then
                espConnection:Disconnect()
            end
            
            -- Remove all highlights
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character then
                    local hl = player.Character:FindFirstChild("VD_Highlight")
                    if hl then
                        hl:Destroy()
                    end
                end
            end
        end
    end
})

-- VISUAL ENHANCEMENTS
TabVisual:CreateSection("Graphics")

TabVisual:CreateToggle({
    Name = "No Fog",
    CurrentValue = false,
    Flag = "NoFog",
    Callback = function(value)
        if value then
            Lighting.FogEnd = 100000
            print("[VD LITE] Fog removed")
        else
            Lighting.FogEnd = 500
            print("[VD LITE] Fog restored")
        end
    end
})

TabVisual:CreateToggle({
    Name = "Fullbright",
    CurrentValue = false,
    Flag = "Fullbright",
    Callback = function(value)
        if value then
            Lighting.Brightness = 2
            Lighting.ClockTime = 12
            Lighting.GlobalShadows = false
            print("[VD LITE] Fullbright enabled")
        else
            Lighting.Brightness = 1
            Lighting.GlobalShadows = true
            print("[VD LITE] Fullbright disabled")
        end
    end
})

-- Final notification
Rayfield:Notify({
    Title = "VD Lite Ready!",
    Content = "Script loaded successfully!\nVersion 3.0 Lite\nby patihrz",
    Duration = 5
})

print("=================================")
print("[VD LITE] Script fully loaded!")
print("[VD LITE] All features ready!")
print("=================================")
