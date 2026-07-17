--[[
    Fish and Monsters! Script
    Made by: patihrz
    Features:
    - Knit Client Controller Scanner & Invoker
    - Auto Fishing (Remote Bypass / Knit Hook)
    - Auto Fishing (UI Fallback)
    - Auto Join Raid & Auto Tap Boss (Spam PlayerTap Remote)
    - Built-in Remote Spy & GUI Scanner
    - WalkSpeed, JumpPower, & Infinite Jump
]]--

print("=================================")
print("[F&M] Starting script... | Version: 2.9 (Diagnostic Mode)")
print("=================================")


-- Load Rayfield UI Library
local success, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)

if not success or type(Rayfield) ~= "table" then
    warn("[F&M] Failed to load Rayfield from primary source: " .. tostring(Rayfield))
    -- Fallback ke repository Github resmi shlexware jika sirius.menu bermasalah
    local altSuccess, altRayfield = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/shlexware/Rayfield/main/source.lua"))()
    end)
    if altSuccess and type(altRayfield) == "table" then
        Rayfield = altRayfield
        print("[F&M] Rayfield loaded successfully from fallback source!")
    else
        warn("[F&M] Failed to load Rayfield from fallback: " .. tostring(altRayfield))
        return
    end
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
local autoBlatantFishing = false
local autoBlatantFishingV2 = false
local blatantCycleDelay = 0.5
local autoCatchAssist = false
local rodNameInput = "Fishingrod_Losi"
local floaterNameInput = "Floater_Doll"
local devSearchText = ""

local autoJoinRaid = false
local autoTeleportBoss = false
local autoTapBoss = false
local bossTapDelay = 0.01
local bossTapMultiplier = 1
local activeBossName = nil
local activeBossNames = {}
local cachedPlayerTap = nil

-- Auto Sell States
local teleportToSell = true
local autoSellMinutes = false
local sellIntervalMinutes = 5
local autoSellCount = false
local sellCountThreshold = 30
local caughtCount = 0

local sellCommon = true
local sellUncommon = true
local sellRare = true
local sellEpic = true
local sellLegendary = false
local detectedSellRemote = nil

local remoteSpyEnabled = false

-- Metatable Remote Spy Hook
local myNamecallHook
myNamecallHook = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    
    if remoteSpyEnabled then
        pcall(function()
            if self:IsA("RemoteEvent") or self:IsA("RemoteFunction") then
                local path = self:GetFullName()
                if not path:find("Movement") and not path:find("Ping") and not path:find("Heartbeat") and not path:find("Physics") and not path:find("Update") then
                    print(string.format("[RemoteSpy] %s:%s()", path, method))
                    for i, v in ipairs(args) do
                        print(string.format("  Arg #%d: %s (%s)", i, tostring(v), type(v)))
                        if type(v) == "table" then
                            for k2, v2 in pairs(v) do
                                print(string.format("    [%s] = %s (%s)", tostring(k2), tostring(v2), type(v2)))
                            end
                        end
                    end
                end
            end
        end)
    end
    
    return myNamecallHook(self, ...)
end)

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
local TabSell = Window:CreateTab("Auto Sell", 4483362458)
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

-- Dismiss Caught Fish Banner (Tap to continue)
local function isGuiVisible(gui)
    local current = gui
    while current do
        if current:IsA("GuiObject") and not current.Visible then
            return false
        end
        current = current.Parent
    end
    return true
end

local function dismissCaughtBanner()
    pcall(function()
        for _, gui in ipairs(LP.PlayerGui:GetDescendants()) do
            if isGuiVisible(gui) then
                local button = nil
                local text = ""
                pcall(function() text = gui:IsA("TextLabel") and gui.Text:lower() or (gui:IsA("TextButton") and gui.Text:lower() or "") end)
                local name = gui.Name:lower()

                -- Cocokkan TextLabel atau Button yang berisi "continue" atau "tap to"
                if text:find("continue") or text:find("tap to") or name:find("continue") or name:find("dismiss") or name:find("close") then
                    if gui:IsA("TextButton") or gui:IsA("ImageButton") then
                        button = gui
                    elseif gui.Parent and (gui.Parent:IsA("TextButton") or gui.Parent:IsA("ImageButton")) then
                        button = gui.Parent
                    end
                end
                
                -- Fallback: Cari button apa saja yang posisinya menutupi layar atau berada di Caught GUI
                if not button and (gui:IsA("TextButton") or gui:IsA("ImageButton")) and gui.Active then
                    local pathLower = gui:GetFullName():lower()
                    if pathLower:find("caught") or pathLower:find("showcase") or pathLower:find("preview") or 
                       pathLower:find("reward") or pathLower:find("success") or pathLower:find("continue") then
                        button = gui
                    end
                end
                
                if button then
                    if typeof(firesignal) == "function" then
                        pcall(firesignal, button.MouseButton1Click)
                        pcall(firesignal, button.Activated)
                    else
                        pcall(function() button.MouseButton1Click:Fire() end)
                        pcall(function() button.Activated:Fire() end)
                    end
                end
            end
        end
    end)
end



-- Find Raid Orb in workspace
local function findRaidOrb()
    -- 1. Cari lewat nama object di Workspace
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local name = obj.Name:lower()
            if name:find("raid") or name:find("orb") or name:find("circle") or name:find("portal") or name:find("boss event") or name:find("participate") then
                if obj:IsA("BasePart") then
                    return obj
                else
                    local bp = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                    if bp then return bp end
                end
            end
        end
    end

    -- 2. Cari lewat BillboardGui / TextLabel event raid yang melayang di Workspace (sangat kuat!)
    -- Penanda text seperti: "Raid will start", "Ready:", "Participate", dll.
    for _, gui in ipairs(Workspace:GetDescendants()) do
        if gui:IsA("TextLabel") then
            local txt = gui.Text:lower()
            if txt:find("raid") or txt:find("start in") or txt:find("ready:") or txt:find("participate") or txt:find("min:") then
                local billboard = gui:FindAncestorOfClass("BillboardGui")
                local adornee = billboard and (billboard.Adornee or billboard.Parent)
                if adornee and adornee:IsA("BasePart") then
                    print("[F&M Finder] Found Raid Zone via Billboard text '" .. gui.Text .. "': " .. adornee:GetFullName())
                    return adornee
                end
            end
        end
    end
    return nil
end


-- Robust Boss Teleport Logic (Handles model, partial matches, billboards, and circles/orbs)
local function teleportToBossLogic(targetName)
    if not targetName then return false, "No boss name provided." end
    
    local char = LP.Character
    local playerHrp = char and char:FindFirstChild("HumanoidRootPart")
    if not playerHrp then return false, "Player Character/HumanoidRootPart not found." end

    -- 1. Coba cari model persis
    local bossModel = workspace:FindFirstChild(targetName, true)
    if bossModel then
        local hrp = bossModel:FindFirstChild("HumanoidRootPart") or bossModel:FindFirstChild("Head") or bossModel:FindFirstChildWhichIsA("BasePart")
        if hrp then
            playerHrp.CFrame = hrp.CFrame + Vector3.new(0, 6, 0)
            return true, "Teleported to exact Boss model: " .. bossModel.Name
        end
    end

    -- 2. Coba cari parsial nama (case-insensitive) di Workspace (misal: "Losi Hermit" -> "Losi_Hermit")
    local lowerTarget = targetName:lower():gsub("_", " ")
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local name = obj.Name:lower():gsub("_", " ")
            if name:find(lowerTarget, 1, true) or lowerTarget:find(name, 1, true) then
                local targetPart = obj:IsA("BasePart") and obj or (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart"))
                if targetPart then
                    playerHrp.CFrame = targetPart.CFrame + Vector3.new(0, 6, 0)
                    return true, "Teleported to partial match object: " .. obj.Name
                end
            end
        end
    end

    -- 3. Coba cari lewat BillboardGui / TextLabel di Workspace (penanda teks besar di atas circle)
    for _, gui in ipairs(workspace:GetDescendants()) do
        if gui:IsA("TextLabel") then
            local txt = gui.Text:lower():gsub("_", " ")
            if txt ~= "" and (txt:find(lowerTarget, 1, true) or lowerTarget:find(txt, 1, true)) then
                -- Cari part tempat GUI ini menempel
                local billboard = gui:FindAncestorOfClass("BillboardGui")
                local adornee = billboard and (billboard.Adornee or billboard.Parent)
                if adornee and adornee:IsA("BasePart") then
                    playerHrp.CFrame = adornee.CFrame + Vector3.new(0, 6, 0)
                    return true, "Teleported to Billboard marker: " .. gui.Text
                end
            end
        end
    end

    -- 4. Fallback ke Raid Orb / Circle penanda event terdekat
    local orb = findRaidOrb()
    if orb then
        playerHrp.CFrame = orb.CFrame + Vector3.new(0, 4, 0)
        return true, "Teleported to Raid Orb/Circle fallback: " .. orb.Name
    end

    return false, "Could not find boss model, match, marker, or raid orb in Workspace."
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

-- Extract fish name recursively from server response tables
local function extractFishName(data)
    if type(data) ~= "table" then return nil end
    local keys = {"FishName", "fishName", "Name", "name", "Id", "id", "ItemId", "itemId", "Type", "type"}
    for _, k in ipairs(keys) do
        if data[k] and type(data[k]) == "string" and data[k] ~= "" then
            return data[k]
        end
    end
    for k, v in pairs(data) do
        if type(v) == "string" and #v > 2 and not (v:match("^%x+-%x+-%x+-%x+-%x+$") or #v == 36) and v ~= "tap" and v ~= "begin" then
            return v
        elseif type(v) == "table" then
            local res = extractFishName(v)
            if res then return res end
        end
    end
    return nil
end

-- Cari posisi air di depan karakter menggunakan raycast
-- Mencoba berbagai sudut ke bawah untuk menemukan air/void
local function getWaterTarget(origin)
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return origin + Vector3.new(0, -5, -15)
    end

    local lookVec = hrp.CFrame.LookVector
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {char}

    -- Coba raycast ke depan-bawah dari berbagai jarak
    local distances = {15, 12, 18, 10, 20, 8}
    local downAngles = {-0.5, -0.7, -0.3, -0.9, -0.2}

    for _, dist in ipairs(distances) do
        for _, downAngle in ipairs(downAngles) do
            -- Arah: forward + down
            local dir = (lookVec + Vector3.new(0, downAngle, 0)).Unit
            local startPos = origin + Vector3.new(0, 2, 0) -- Sedikit di atas HRP
            local result = workspace:Raycast(startPos, dir * (dist + 10), raycastParams)

            if result then
                local hit = result.Instance
                local hitName = hit.Name:lower()
                local matName = tostring(result.Material):lower()

                -- Cek apakah hit water/terrain
                if result.Material == Enum.Material.Water or
                   hitName:find("water") or hitName:find("ocean") or hitName:find("sea") or hitName:find("lake") or
                   matName:find("water") then
                    -- Posisi di atas permukaan air sedikit
                    return result.Position + Vector3.new(0, 0.3, 0)
                end
            else
                -- Tidak ada hit (void) = kemungkinan air/laut terbuka
                -- Target: arahkan ke titik di depan-bawah sejauh dist
                local targetPos = origin + (lookVec * dist) + Vector3.new(0, -3, 0)
                return targetPos
            end
        end
    end

    -- Fallback: lempar lurus ke depan sejauh 15 studs, turun 3
    return origin + (lookVec * 15) + Vector3.new(0, -3, 0)
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
TabFishing:CreateSection("Auto Catch Assist")

TabFishing:CreateToggle({
    Name = "Auto Catch Assist (Manual/AFK)",
    CurrentValue = false,
    Flag = "AutoCatchAssist",
    Callback = function(value)
        autoCatchAssist = value
        if value then
            print("[F&M Assist] Enabled. Use with game's AFK mode or fish manually!")
        end
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

TabFishing:CreateSection("Blatant Fishing (Max Speed)")

TabFishing:CreateToggle({
    Name = "Blatant Fishing (Super Fast - Aggressive)",
    CurrentValue = false,
    Flag = "AutoBlatantFishing",
    Callback = function(value)
        autoBlatantFishing = value
        if value then
            -- Matikan mode lain agar tidak tabrakan
            autoBlatantFishingV2 = false
            print("[F&M Blatant] ENABLED - Mode blatant v1 aktif.")
            Rayfield:Notify({Title = "Blatant v1 ON", Content = "Spam fishing max speed aktif!", Duration = 3})
        end
    end
})

TabFishing:CreateToggle({
    Name = "Blatant Fishing v2 (Gacor - Inventory Safe)",
    CurrentValue = false,
    Flag = "AutoBlatantFishingV2",
    Callback = function(value)
        autoBlatantFishingV2 = value
        if value then
            -- Matikan mode lain agar tidak tabrakan
            autoBlatantFishing = false
            print("[F&M Blatant v2] ENABLED - Mode blatant v2 gacor & aman aktif.")
            Rayfield:Notify({Title = "Blatant v2 ON", Content = "Blatant v2 gacor & inventory-safe aktif!", Duration = 3})
        end
    end
})

TabFishing:CreateSlider({
    Name = "Blatant Cycle Delay (AFK Safety)",
    Range = {0.05, 5},
    Increment = 0.05,
    CurrentValue = 0.5,
    Flag = "BlatantCycleDelay",
    Callback = function(value)
        blatantCycleDelay = value
    end
})

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

-- Helper: raycast untuk deteksi permukaan air Terrain
local function getWaterTarget(origin)
    local terrainParams = RaycastParams.new()
    terrainParams.FilterType = Enum.RaycastFilterType.Include
    terrainParams.FilterDescendantsInstances = {Workspace.Terrain}
    terrainParams.IgnoreWater = false
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return origin + Vector3.new(0, -8, 0) end
    local lookOffset = hrp.CFrame.LookVector * 8
    local castPos = origin + lookOffset
    local waterY = nil
    local tr = Workspace:Raycast(Vector3.new(castPos.X, origin.Y+10, castPos.Z), Vector3.new(0,-150,0), terrainParams)
    if tr and tr.Material == Enum.Material.Water then
        waterY = tr.Position.Y
    else
        for _, s in ipairs({Vector3.new(5,0,0), Vector3.new(-5,0,0), Vector3.new(0,0,5), Vector3.new(0,0,-5)}) do
            local r = Workspace:Raycast(Vector3.new(castPos.X+s.X, origin.Y+10, castPos.Z+s.Z), Vector3.new(0,-150,0), terrainParams)
            if r and r.Material == Enum.Material.Water then waterY = r.Position.Y break end
        end
    end
    waterY = waterY or (origin.Y - 8)
    return Vector3.new(castPos.X, waterY, castPos.Z)
end



----------------------------------------------------
-- BLATANT FISHING (Max Speed, Terpisah)
----------------------------------------------------
local function runBlatantFishingCycle()
    local ThrowFloater        = findKnitRemote("FishingReplicationService", "ThrowFloater")
    local ConfirmFloatingCast = findKnitRemote("FishingReplicationService", "ConfirmFloatingCast")
    local StartFishing        = findKnitRemote("FishingReplicationService", "StartFishing")
    local StartPulling        = findKnitRemote("FishingReplicationService", "StartPulling")
    local StopFishing         = findKnitRemote("FishingReplicationService", "StopFishing")
    local FishingPullInput    = findKnitRemote("FishingRewardService",      "FishingPullInput")
    local RequestFishBite     = findKnitRemote("FishingRewardService",      "RequestFishBite")
    local FishCaught          = findKnitRemote("FishingRewardService",      "FishCaught")
    local FishingSuccess      = findKnitRemote("FishingRewardService",      "FishingSuccess")
    local FishingPullState    = findKnitRemote("FishingRewardService",      "FishingPullState")
    local RequestPreview      = findKnitRemote("AssetPreviewService",       "RequestPreview")
    local ReleasePreview      = findKnitRemote("AssetPreviewService",       "ReleasePreview")

    if not (ThrowFloater and ConfirmFloatingCast and StartPulling and StopFishing and FishingPullInput) then
        warn("[F&M Blatant] Missing core remotes!") return
    end

    equipRod()
    local activeRodName     = LP:GetAttribute("FishingCastRodId") or rodNameInput
    local activeFloaterName = LP:GetAttribute("FishingCastFloaterId") or floaterNameInput

    -- Reset state
    pcall(function() StopFishing:InvokeServer() end)
    task.wait(0.15)
    if StartFishing then
        pcall(function() StartFishing:InvokeServer(activeRodName, activeFloaterName) end)
    end

    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local origin = hrp.Position
    -- Cari target posisi air yang valid
    -- Prioritas 1: Baca posisi floater aktual yang sudah ada di workspace (paling akurat!)
    local target = nil
    local floaterInWorld = workspace:FindFirstChild(activeFloaterName, true)
    if floaterInWorld and floaterInWorld:IsA("BasePart") then
        target = floaterInWorld.Position
    end
    -- Prioritas 2: Raycast ke air
    if not target then
        target = getWaterTarget(origin)
    end

    local floatConfig = {LightInfluence=0, FaceCamera=true, Color=Color3.new(0.94,0.31,1), Transparency=0.02, LightEmission=1, Width=0.24}
    local oldCastId = LP:GetAttribute("FishingCastId") or ""


    -- ================================================================
    -- Pasang SEMUA listener server events sebelum melempar agar tidak miss
    -- ================================================================
    local caughtFishName = nil
    local serverReadyForPull = false
    local connections = {}

    -- FishCaught listener
    if FishCaught and FishCaught:IsA("RemoteEvent") then
        connections[#connections+1] = FishCaught.OnClientEvent:Connect(function(...)
            local args = {...}
            print("[F&M Blatant] [FishCaught] fired! " .. #args .. " args")
            for i, v in ipairs(args) do
                print("  [" .. i .. "] " .. typeof(v) .. ": " .. tostring(v))
                if type(v) == "string" and v ~= "" and not v:match("^%x+-%x+-%x+-%x+-%x+$") then
                    caughtFishName = caughtFishName or v
                end
                if type(v) == "table" then
                    local n = extractFishName(v)
                    if n then caughtFishName = caughtFishName or n end
                    dumpTable(v, "    ")
                end
            end
        end)
    end

    -- FishingSuccess listener
    if FishingSuccess and FishingSuccess:IsA("RemoteEvent") then
        connections[#connections+1] = FishingSuccess.OnClientEvent:Connect(function(...)
            local args = {...}
            print("[F&M Blatant] [FishingSuccess] fired! " .. #args .. " args")
            for i, v in ipairs(args) do
                print("  [" .. i .. "] " .. typeof(v) .. ": " .. tostring(v))
                if type(v) == "string" and v ~= "" and not v:match("^%x+-%x+-%x+-%x+-%x+$") then
                    caughtFishName = caughtFishName or v
                end
                if type(v) == "table" then
                    local n = extractFishName(v)
                    if n then caughtFishName = caughtFishName or n end
                    dumpTable(v, "    ")
                end
            end
        end)
    end

    -- FishingPullState listener - DIAGNOSIS: lihat arg apa yang dikirim server
    local pullStateCount = 0
    if FishingPullState and FishingPullState:IsA("RemoteEvent") then
        connections[#connections+1] = FishingPullState.OnClientEvent:Connect(function(...)
            pullStateCount = pullStateCount + 1
            if pullStateCount <= 3 then -- Print hanya 3 pertama supaya tidak spam
                local args = {...}
                print("[F&M Blatant] [FishingPullState] #" .. pullStateCount .. " fired! " .. #args .. " args")
                for i, v in ipairs(args) do
                    if type(v) == "table" then
                        dumpTable(v, "  ")
                    else
                        print("  [" .. i .. "] " .. typeof(v) .. ": " .. tostring(v))
                    end
                end
            end
            serverReadyForPull = true
        end)
    end

    local function disconnectAll()
        for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
        connections = {}
    end

    -- ================================================================
    -- ThrowFloater + ConfirmFloatingCast
    -- ================================================================
    pcall(function() ThrowFloater:InvokeServer(origin, target, activeRodName, activeFloaterName, floatConfig, 2.5) end)
    task.wait(0.25) -- Dipercepat dari 0.5
    if not autoBlatantFishing then disconnectAll() return end

    pcall(function() ConfirmFloatingCast:InvokeServer(target) end)
    task.wait(0.05) -- Dipercepat dari 0.2

    -- ================================================================
    -- RequestFishBite - trigger server untuk assign ikan
    -- ================================================================
    local uuid = nil
    if RequestFishBite then
        local biteOk, biteData = pcall(function()
            return RequestFishBite:InvokeServer(target + Vector3.new(0, 0.1, 0))
        end)
        if biteOk and type(biteData) == "table" then
            uuid = biteData.SessionId or biteData.sessionId or biteData.castId or biteData.CastId or extractUUID(biteData)
            print("[F&M Blatant] RequestFishBite OK, UUID: " .. tostring(uuid))
            if not uuid then dumpTable(biteData) end
        elseif biteOk and type(biteData) == "string" and biteData ~= "" then
            uuid = biteData
            print("[F&M Blatant] RequestFishBite OK (string), UUID: " .. tostring(uuid))
        elseif not biteOk then
            warn("[F&M Blatant] RequestFishBite error: " .. tostring(biteData))
        end
    end

    -- Fallback attribute
    if not uuid then
        local w = 0
        while w < 2 do -- Dipercepat dari 3
            if not autoBlatantFishing then disconnectAll() return end
            local castId = LP:GetAttribute("FishingCastId")
            if castId and castId ~= "" and castId ~= oldCastId then
                uuid = castId
                break
            end
            task.wait(0.05); w = w + 0.05
        end
    end

    if not uuid then
        disconnectAll()
        pcall(function() StopFishing:InvokeServer() end)
        return
    end

    print("[F&M Blatant] Bite! UUID: " .. tostring(uuid))

    -- Tunggu FishingPullState dari server (max 1s) - tanda server siap untuk StartPulling
    local wsrv = 0
    while wsrv < 1 and not serverReadyForPull do -- Dipercepat dari 2s
        task.wait(0.02); wsrv = wsrv + 0.02
    end

    -- ================================================================
    -- StartPulling + taps
    -- ================================================================
    pcall(function() StartPulling:InvokeServer() end)
    task.wait(0.02) -- Dipercepat dari 0.1

    pcall(function() FishingPullInput:InvokeServer(uuid, "begin") end)
    task.wait(0.02) -- Dipercepat dari 0.1

    -- Taps dengan delay sangat cepat (60ms) untuk kecepatan maksimal tapi tetap aman dari rate limit
    for i = 1, 15 do
        if not autoBlatantFishing then break end
        if caughtFishName then 
            print("[F&M Blatant] Ikan terdeteksi tertangkap lebih awal di tap #" .. i .. ", menghentikan tap loop.")
            break 
        end
        local ok, res = pcall(function()
            return FishingPullInput:InvokeServer(uuid, "tap")
        end)
        task.wait(0.06) -- Dipercepat dari 0.08
    end


    print("[F&M Blatant] Taps sent. Menunggu FishCaught / FishingSuccess (max 1.5s)...")

    -- Tunggu max 1.5 detik jika ikan belum terdeteksi tertangkap (dipercepat dari 3s)
    local wt = 0
    while wt < 1.5 and not caughtFishName do
        task.wait(0.02); wt = wt + 0.02
    end

    disconnectAll()

    if not caughtFishName then
        print("[F&M Blatant] Tidak ada event fish catch. Fallback NurseShark.")
        caughtFishName = "NurseShark"
    else
        print("[F&M Blatant] Ikan tertangkap: " .. caughtFishName)
    end

    -- Urutan claim: Lewati RequestPreview & ReleasePreview sepenuhnya agar langsung masuk inventory (SPAM MODE!)
    pcall(function() StopFishing:InvokeServer() end)
    task.wait(0.02)
    
    print("[F&M Blatant] Cycle completed!")
end

-- Blatant Fishing Loop Thread (Jeda minimal antar siklus)
task.spawn(function()
    while true do
        task.wait(0.05) -- Dipercepat dari 0.5s agar langsung lempar ulang
        if autoBlatantFishing then
            local ok, err = pcall(runBlatantFishingCycle)
            if not ok then
                warn("[F&M Blatant Error]: " .. tostring(err))
                task.wait(1)
            end
        end
    end
end)

-- ================================================================
-- BLATANT FISHING SYSTEM V2 (Ultra-Aggressive Spammer)
-- ================================================================
local function runBlatantFishingV2Cycle()
    local ThrowFloater        = findKnitRemote("FishingReplicationService", "ThrowFloater")
    local ConfirmFloatingCast = findKnitRemote("FishingReplicationService", "ConfirmFloatingCast")
    local StartFishing        = findKnitRemote("FishingReplicationService", "StartFishing")
    local StartPulling        = findKnitRemote("FishingReplicationService", "StartPulling")
    local StopFishing         = findKnitRemote("FishingReplicationService", "StopFishing")
    local FishingPullInput    = findKnitRemote("FishingRewardService",      "FishingPullInput")
    local RequestFishBite     = findKnitRemote("FishingRewardService",      "RequestFishBite")
    local FishCaught          = findKnitRemote("FishingRewardService",      "FishCaught")
    local FishingSuccess      = findKnitRemote("FishingRewardService",      "FishingSuccess")

    if not (ThrowFloater and ConfirmFloatingCast and RequestFishBite and StartPulling and StopFishing and FishingPullInput) then
        warn("[F&M Blatant v2] Missing core remotes!") return false
    end

    equipRod()
    local rod = getRod()
    local activeRodName = rod and rod.Name or rodNameInput
    
    local activeFloaterName = floaterNameInput
    for k, v in pairs(LP:GetAttributes()) do
        if type(v) == "string" and (k:lower():find("floater") or v:lower():find("floater")) and v ~= "" then
            activeFloaterName = v
            break
        end
    end

    -- Reset state & start new session
    pcall(function() StopFishing:InvokeServer() end)
    task.wait(0.05)
    if StartFishing then
        pcall(function() StartFishing:InvokeServer(activeRodName, activeFloaterName) end)
    end

    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    local origin = hrp.Position
    local target = getWaterTarget(origin)
    local floatConfig = {LightInfluence=0, FaceCamera=true, Color=Color3.new(0.94,0.31,1), Transparency=0.02, LightEmission=1, Width=0.24}
    local oldCastId = LP:GetAttribute("FishingCastId") or ""

    local caughtFishName = nil
    local serverReadyForPull = false
    local connections = {}

    local function disconnectAll()
        for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
        connections = {}
    end

    -- Event listeners for guaranteed catch detection
    if FishCaught and FishCaught:IsA("RemoteEvent") then
        connections[#connections+1] = FishCaught.OnClientEvent:Connect(function(...)
            for _, v in ipairs({...}) do
                if type(v) == "string" and v ~= "" and not v:match("^%x+-%x+-%x+-%x+-%x+$") then
                    caughtFishName = v
                end
                if type(v) == "table" then
                    local n = extractFishName(v)
                    if n then caughtFishName = n end
                end
            end
        end)
    end

    if FishingSuccess and FishingSuccess:IsA("RemoteEvent") then
        connections[#connections+1] = FishingSuccess.OnClientEvent:Connect(function(...)
            for _, v in ipairs({...}) do
                if type(v) == "string" and v ~= "" and not v:match("^%x+-%x+-%x+-%x+-%x+$") then
                    caughtFishName = v
                end
                if type(v) == "table" then
                    local n = extractFishName(v)
                    if n then caughtFishName = n end
                end
            end
        end)
    end

    if FishingPullState and FishingPullState:IsA("RemoteEvent") then
        connections[#connections+1] = FishingPullState.OnClientEvent:Connect(function(...)
            serverReadyForPull = true
        end)
    end

    -- 1. Throw Floater
    pcall(function() ThrowFloater:InvokeServer(origin, target, activeRodName, activeFloaterName, floatConfig, 2.5) end)
    task.wait(0.25) -- Jeda lempar pancing yang aman (terbukti work di v1)
    if not autoBlatantFishingV2 then disconnectAll() return false end

    -- 2. Confirm Cast
    pcall(function() ConfirmFloatingCast:InvokeServer(target) end)
    task.wait(0.10) -- Jeda konfirmasi yang aman
    if not autoBlatantFishingV2 then disconnectAll() return false end

    -- 3. Request Fish Bite
    local uuid = nil
    local biteOk, biteData = pcall(function()
        return RequestFishBite:InvokeServer(target + Vector3.new(0, 0.1, 0))
    end)
    if biteOk and type(biteData) == "table" then
        uuid = biteData.SessionId or biteData.sessionId or biteData.castId or biteData.CastId or extractUUID(biteData)
    elseif biteOk and type(biteData) == "string" and biteData ~= "" then
        uuid = biteData
    end

    -- Fallback UUID check
    if not uuid then
        local w = 0
        while w < 1.0 do
            if not autoBlatantFishingV2 then disconnectAll() return false end
            local castId = LP:GetAttribute("FishingCastId")
            if castId and castId ~= "" and castId ~= oldCastId then
                uuid = castId
                break
            end
            task.wait(0.02)
            w = w + 0.02
        end
    end

    if not uuid then
        disconnectAll()
        pcall(function() StopFishing:InvokeServer() end)
        return false
    end

    -- Tunggu FishingPullState dari server (max 1s) - tanda server siap untuk StartPulling
    local wsrv = 0
    while wsrv < 1 and not serverReadyForPull do
        if not autoBlatantFishingV2 then disconnectAll() return false end
        task.wait(0.02)
        wsrv = wsrv + 0.02
    end

    -- 4. Start Pulling
    pcall(function() StartPulling:InvokeServer() end)
    task.wait(0.02)

    -- 5. Begin Pull Input
    pcall(function() FishingPullInput:InvokeServer(uuid, "begin") end)
    task.wait(0.02)

    -- 6. Sequential Fast Tapping (20ms delay - 3x lebih cepat dari v1 tapi tetap terdaftar di server)
    for i = 1, 16 do
        if not autoBlatantFishingV2 or caughtFishName then break end
        pcall(function() FishingPullInput:InvokeServer(uuid, "tap") end)
        task.wait(0.02)
    end

    -- 7. Wait briefly for server confirmation event to log success
    local wt = 0
    while wt < 1.5 and not caughtFishName do
        if not autoBlatantFishingV2 then break end
        task.wait(0.02)
        wt = wt + 0.02
    end

    disconnectAll()

    -- 8. Claim & End Session
    pcall(function() StopFishing:InvokeServer() end)
    task.wait(0.05)

    if caughtFishName then
        print("[F&M Blatant v2] Successfully caught: " .. tostring(caughtFishName))
        return true
    else
        warn("[F&M Blatant v2] Failed to catch fish (Bite timeout). Resetting...")
        return false
    end
end

-- Blatant Fishing v2 Loop Thread
task.spawn(function()
    while true do
        task.wait(blatantCycleDelay)
        if autoBlatantFishingV2 then
            local ok, success = pcall(runBlatantFishingV2Cycle)
            if not ok or not success then
                task.wait(0.5)
            end
        end
    end
end)

-- Background Auto Clicker untuk Banner Ikan / Keluar (Berjalan terus-menerus real-time)
task.spawn(function()
    while true do
        task.wait(0.05) -- Cek setiap 50ms
        if autoBlatantFishing or autoBlatantFishingV2 or autoCatchAssist then
            dismissCaughtBanner()
        end
    end
end)



-- Auto Catch Assist Loop Thread (Instant Catch)
local lastAssistId = nil
local cachedAssistPullInput = nil
task.spawn(function()
    while true do
        task.wait(0.05)
        if autoCatchAssist then
            if not cachedAssistPullInput then
                cachedAssistPullInput = findKnitRemote("FishingRewardService", "FishingPullInput")
            end
            local castId = LP:GetAttribute("FishingCastId")
            if castId and castId ~= "" and castId ~= lastAssistId then
                lastAssistId = castId
                print("[F&M Assist] Bite! UUID: " .. tostring(castId))
                if cachedAssistPullInput then
                    -- "begin" dulu
                    pcall(function() cachedAssistPullInput:InvokeServer(castId, "begin") end)
                    task.wait(0.01)
                    
                    -- Spam 16 ketukan dengan jeda 10ms (Sangat instan!)
                    for i = 1, 16 do
                        if not autoCatchAssist then break end
                        pcall(function() cachedAssistPullInput:InvokeServer(castId, "tap") end)
                        task.wait(0.01)
                    end
                    
                    -- Langsung klaim dengan stop
                    local StopFishing = findKnitRemote("FishingReplicationService", "StopFishing")
                    if StopFishing then
                        pcall(function() StopFishing:InvokeServer() end)
                    end
                    
                    print("[F&M Assist] Instant Catch Completed!")
                end
            end
        else
            cachedAssistPullInput = nil
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
                                
                                -- Safe cross-executor click simulation
                                if typeof(firesignal) == "function" then
                                    pcall(firesignal, gui.MouseButton1Click)
                                    pcall(firesignal, gui.Activated)
                                else
                                    pcall(function() gui.MouseButton1Click:Fire() end)
                                    pcall(function() gui.Activated:Fire() end)
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
-- RAID EVENT TAB
----------------------------------------------------

-- Helper: dapatkan nama boss aktif dari server event (Paling Akurat!)
-- Response structure: result = { [1] = { BossName="Losi_Hermit", BossDisplayName="Losi Hermit", CurrentState="Gathering/Fighting/...", SpawnLocationName="Base", ... } }
local function detectBossFromEvents()
    local GetActiveEvents = findKnitRemote("BossFishEventService", "GetActiveEvents")
    if not GetActiveEvents then return {} end
    
    local ok, result = pcall(function() return GetActiveEvents:InvokeServer() end)
    if not ok or type(result) ~= "table" then return {} end

    local bosses = {}
    -- Iterasi semua event aktif (bisa lebih dari 1)
    for _, eventData in pairs(result) do
        if type(eventData) == "table" then
            local bossName = eventData.BossName       -- Field persis dari server: "Losi_Hermit"
            local state = eventData.CurrentState      -- "Gathering" / "Fighting" / dll
            
            if bossName and type(bossName) == "string" and bossName ~= "" then
                print("[F&M Boss] GetActiveEvents -> BossName: " .. bossName .. " | State: " .. tostring(state))
                table.insert(bosses, bossName)
            end
        end
    end

    return bosses
end


-- Helper: scan workspace for active boss model names (GENERIC / BEBAS NAMA)
local function findActiveBossNames()
    -- List kata kunci NPC/merchant/map agar tidak salah menargetkan NPC, baseplate, atau tombol GUI game
    local blacklistedKeywords = {
        "fish", "merchant", "nelayan", "shop", "seller", "toko", "quest", "innkeeper", "luther", "savepoint",
        "base", "map", "lobby", "ground", "spawn", "plot", "stand", "showcase", "leaderboard", "leaderboards",
        "wall", "bucket", "decor", "tree", "rock", "water", "aquarium", "building", "house", "fence", "bridge",
        "boat", "ship", "sea", "ocean", "island", "plate", "board", "road", "path", "terrain", "obby", "arena",
        "items", "settings", "close", "exit", "menu", "gui", "play", "afk", "confirm", "yes", "no", "cancel",
        "dock", "pier", "port", "shore", "sand", "cliff", "cave", "reef", "vent", "volcano", "iceberg", "bamboo",
        "platform", "zone", "area", "part", "region", "section", "piece", "chunk", "tile", "block"
    }

    local function isWordBlacklisted(word)
        if not word or type(word) ~= "string" then return true end
        local wordLower = word:lower()
        for _, kw in ipairs(blacklistedKeywords) do
            if wordLower == kw or wordLower:find(kw) then
                return true
            end
        end
        return false
    end

    -- 1. Coba lewat server event remote (PALING AKURAT - langsung dari server!)
    local remoteBosses = detectBossFromEvents()
    if #remoteBosses > 0 then
        return remoteBosses
    end

    local bosses = {}

    -- 2. Scan Workspace untuk model dengan Humanoid HP sangat tinggi (> 1000) - PALING RELIABLE
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name ~= LP.Name then
            local isPlayer = Players:GetPlayerFromCharacter(obj)
            if not isPlayer then
                if not isWordBlacklisted(obj.Name) then
                    local hum = obj:FindFirstChildOfClass("Humanoid")
                    if hum and hum.MaxHealth > 1000 then
                        print("[F&M Boss Auto] Step 2 (Humanoid HP > 1000) matched: " .. obj.Name .. " (HP: " .. hum.MaxHealth .. ")")
                        table.insert(bosses, obj.Name)
                    end
                end
            end
        end
    end

    -- 3. Scan Workspace untuk model dengan attribute Health/HP tinggi (>10k)
    if #bosses == 0 then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and obj.Name ~= LP.Name then
                local isPlayer = Players:GetPlayerFromCharacter(obj)
                if not isPlayer then
                    if not isWordBlacklisted(obj.Name) then
                        local hpAttr = obj:GetAttribute("Health") or obj:GetAttribute("HP") or obj:GetAttribute("MaxHealth") or obj:GetAttribute("BossHealth")
                        if hpAttr and type(hpAttr) == "number" and hpAttr > 10000 then
                            print("[F&M Boss Auto] Step 3 (HP Attribute > 10k) matched: " .. obj.Name)
                            table.insert(bosses, obj.Name)
                        end
                    end
                end
            end
        end
    end

    -- Deduplicate list
    local hash = {}
    local uniqueBosses = {}
    for _, v in ipairs(bosses) do
        if not hash[v] then
            uniqueBosses[#uniqueBosses + 1] = v
            hash[v] = true
        end
    end

    if #uniqueBosses == 0 then
        print("[F&M Boss Auto] No boss detected. Waiting for event...")
    end
    return uniqueBosses
end

-- Wrapper backwards compatibility
local function findActiveBossName()
    local list = findActiveBossNames()
    return list[1]
end



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

TabRaid:CreateButton({
    Name = "Teleport to Boss (Monster)",
    Callback = function()
        local targetName = activeBossName or findActiveBossName()
        if targetName then
            local success, msg = teleportToBossLogic(targetName)
            Rayfield:Notify({
                Title = "Boss Teleport",
                Content = msg,
                Duration = 4
            })
        else
            Rayfield:Notify({Title = "Boss Teleport", Content = "No active boss detected! Try scanning first.", Duration = 3})
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
    Name = "Auto Teleport to Boss (Loop)",
    CurrentValue = false,
    Flag = "AutoTeleportBoss",
    Callback = function(value)
        autoTeleportBoss = value
    end
})


TabRaid:CreateSection("Boss Tap Spammer")

TabRaid:CreateButton({
    Name = "Scan Active Boss Name",
    Callback = function()
        local foundList = findActiveBossNames()
        if #foundList > 0 then
            activeBossNames = foundList
            activeBossName = foundList[1]
            local display = table.concat(foundList, ", ")
            print("[F&M Boss] Bosses ditemukan: " .. display)
            Rayfield:Notify({Title = "Boss Found!", Content = "Boss aktif: " .. display, Duration = 5})
        else
            print("[F&M Boss] Tidak ada boss aktif ditemukan di Workspace.")
            Rayfield:Notify({Title = "Boss Not Found", Content = "Tidak ada boss aktif di workspace. Coba input manual atau tunggu event muncul.", Duration = 5})
        end
    end
})

TabRaid:CreateButton({
    Name = "[DEBUG] Boss Diagnosis (Check Console!)",
    Callback = function()
        print("=== BOSS TAP DIAGNOSIS ===")
        print("activeBossName = " .. tostring(activeBossName))
        print("cachedPlayerTap = " .. tostring(cachedPlayerTap))

        -- Coba cari PlayerTap remote
        local pt = findKnitRemote("BossFishEventService", "PlayerTap")
        print("findKnitRemote result = " .. tostring(pt))
        if pt then print("  Full path: " .. pt:GetFullName()) end

        -- Scan Workspace untuk Luther atau NPC lain
        print("--- Scanning NPC Models ---")
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and (obj.Name:lower():find("luther") or obj.Name:lower():find("fisherman") or obj.Name:lower():find("sell")) then
                local hrp = obj:FindFirstChildWhichIsA("BasePart")
                print("  NPC Found: " .. obj.Name .. " (" .. obj:GetFullName() .. ") | Pos: " .. (hrp and tostring(hrp.Position) or "N/A"))
            end
        end

        -- Scan semua BillboardGuis di Workspace
        print("--- Scanning BillboardGuis/TextLabels in Workspace ---")
        local countB = 0
        for _, gui in ipairs(Workspace:GetDescendants()) do
            if gui:IsA("BillboardGui") or gui:IsA("TextLabel") then
                local txt = gui:IsA("TextLabel") and gui.Text or ""
                if txt ~= "" or gui.Name:lower():find("raid") or gui.Name:lower():find("participate") or gui.Name:lower():find("boss") then
                    local parent = gui.Parent
                    print("  Gui: " .. gui.Name .. " (Text: '" .. txt .. "') | Parent: " .. (parent and parent:GetFullName() or "N/A"))
                    countB = countB + 1
                    if countB >= 15 then break end
                end
            end
        end

        -- Scan semua parts dengan kata kunci raid/event di Workspace
        print("--- Scanning Raid/Event/Portal Parts in Workspace ---")
        local countP = 0
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                local name = obj.Name:lower()
                if name:find("raid") or name:find("orb") or name:find("circle") or name:find("portal") or name:find("event") or name:find("participate") or name:find("zone") then
                    print("  Part Found: " .. obj.Name .. " (" .. obj:GetFullName() .. ") | Pos: " .. tostring(obj.Position))
                    countP = countP + 1
                    if countP >= 15 then break end
                end
            end
        end

        -- Scan ReplicatedStorage untuk Boss Service
        print("--- Scanning ReplicatedStorage RF folder ---")
        local rep = game:GetService("ReplicatedStorage")
        local packages = rep:FindFirstChild("Packages")
        if packages then
            local index = packages:FindFirstChild("_Index")
            if index then
                for _, child in ipairs(index:GetChildren()) do
                    if child.Name:find("sleitnick_knit") then
                        local services = child:FindFirstChild("Services", true)
                        if services then
                            local bossService = services:FindFirstChild("BossFishEventService")
                            if bossService then
                                print("  BossFishEventService FOUND!")
                                local rf = bossService:FindFirstChild("RF")
                                if rf then
                                    for _, r in ipairs(rf:GetChildren()) do
                                        print("  RF/" .. r.Name .. " (" .. r.ClassName .. ")")
                                    end
                                else
                                    print("  RF folder NOT FOUND!")
                                end
                            end
                        end
                    end
                end
            end
        end
        print("=== END DIAGNOSIS ===")
        Rayfield:Notify({Title = "Diagnosis Done!", Content = "Check console output!", Duration = 3})
    end
})


TabRaid:CreateInput({
    Name = "Boss Name (Manual Input)",
    PlaceholderText = "Contoh: Losi_Hermit, Windah_SM",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        if Text and Text ~= "" then
            activeBossNames = {}
            for name in string.gmatch(Text, "([^,%s]+)") do
                table.insert(activeBossNames, name)
            end
            activeBossName = activeBossNames[1]
            local display = table.concat(activeBossNames, ", ")
            print("[F&M Boss] Boss names di-set manual: " .. display)
            Rayfield:Notify({Title = "Boss Names Set", Content = "Bosses: " .. display, Duration = 3})
        end
    end
})

TabRaid:CreateToggle({
    Name = "Auto Tap Boss (Super Fast)",
    CurrentValue = false,
    Flag = "AutoTapBoss",
    Callback = function(value)
        autoTapBoss = value
        if value then
            -- Auto scan boss name saat toggle dinyalakan
            local foundList = findActiveBossNames()
            if #foundList > 0 then
                activeBossNames = foundList
                activeBossName = foundList[1]
                local display = table.concat(foundList, ", ")
                print("[F&M Boss] Auto-detected bosses: " .. display)
                Rayfield:Notify({Title = "Bosses Detected", Content = "Bosses: " .. display, Duration = 3})
            elseif #activeBossNames == 0 then
                warn("[F&M Boss] Boss name belum diset! Gunakan tombol Scan atau input manual.")
                Rayfield:Notify({Title = "Warning", Content = "Boss name kosong! Scan dulu atau input manual.", Duration = 5})
            end
        end
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

TabRaid:CreateSlider({
    Name = "Boss Tap Multiplier (x Damage)",
    Range = {1, 15},
    Increment = 1,
    CurrentValue = 1,
    Flag = "BossTapMultiplier",
    Callback = function(value)
        bossTapMultiplier = value
    end
})

-- Helper: Trigger participate ProximityPrompt atau tombol GUI
local function triggerParticipate()
    -- 1. Scan ProximityPrompts dekat player (jarak < 40 studs)
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then
                local actText = obj.ActionText:lower()
                local objText = obj.ObjectText:lower()
                if actText:find("participate") or actText:find("join") or actText:find("raid") or actText:find("ready") or
                   objText:find("participate") or objText:find("join") or objText:find("raid") or objText:find("ready") then
                    
                    local promptParent = obj.Parent
                    if promptParent and promptParent:IsA("BasePart") then
                        local dist = (promptParent.Position - hrp.Position).Magnitude
                        if dist < 40 then
                            print("[F&M Auto Join] Triggering ProximityPrompt: " .. obj:GetFullName())
                            task.spawn(function()
                                if typeof(fireproximityprompt) == "function" then
                                    fireproximityprompt(obj, 1)
                                else
                                    obj:InputHoldBegin()
                                    task.wait(0.2)
                                    obj:InputHoldEnd()
                                end
                            end)
                        end
                    end
                end
            end
        end
    end

    -- 2. Scan PlayerGui untuk tombol "PARTICIPATE" / "JOIN"
    for _, gui in ipairs(LP.PlayerGui:GetDescendants()) do
        if (gui:IsA("TextButton") or gui:IsA("ImageButton")) and isGuiVisible(gui) then
            local fullName = gui:GetFullName():lower()
            if not fullName:find("rayfield") then
                local text = ""
                pcall(function() text = gui.Text:lower() end)
                local name = gui.Name:lower()
                if text:find("participate") or text:find("join") or name:find("participate") or name:find("join") then
                    print("[F&M Auto Join] Clicking GUI Button: " .. gui:GetFullName())
                    pcall(function()
                        if typeof(firesignal) == "function" then
                            firesignal(gui.MouseButton1Click)
                            firesignal(gui.Activated)
                        else
                            gui.MouseButton1Click:Fire()
                            gui.Activated:Fire()
                        end
                    end)
                end
            end
        end
    end
end

-- Auto Join Raid Loop
task.spawn(function()
    while true do
        task.wait(2) -- Lebih responsif
        if autoJoinRaid then
            local orb = findRaidOrb()
            if orb then
                local char = LP.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.CFrame = orb.CFrame + Vector3.new(0, 3, 0)
                    task.wait(0.4)
                    triggerParticipate()
                end
            end
        end
    end
end)

-- Auto Teleport to Boss Loop
task.spawn(function()
    while true do
        task.wait(3)
        if autoTeleportBoss then
            local targetName = activeBossName or findActiveBossName()
            if targetName then
                teleportToBossLogic(targetName)
            end
        end
    end
end)

-- Helper: cari remote tap boss secara fleksibel
local function findBossTapRemote()
    local r = findKnitRemote("BossFishEventService", "PlayerTap")
    if r then return r end
    
    -- Fallback: scan seluruh ReplicatedStorage untuk nama remote yang mendekati
    for _, obj in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local name = obj.Name:lower()
            if name == "playertap" or name == "bosstap" or name == "raidtap" or name == "tap" or name == "clickboss" or name == "bossclick" then
                print("[F&M Boss Finder] Found tap remote: " .. obj:GetFullName())
                return obj
            end
        end
    end
    return nil
end

-- Auto Tap Boss Loop (dengan debug logging & error reporting)
local lastBossDebugTime = 0
task.spawn(function()
    while true do
        task.wait(bossTapDelay)
        if autoTapBoss then
            -- Cache PlayerTap secara dinamis
            if not cachedPlayerTap or not cachedPlayerTap.Parent then
                cachedPlayerTap = findBossTapRemote()
                if cachedPlayerTap then
                    print("[F&M Boss] Active Tap Remote: " .. cachedPlayerTap:GetFullName())
                end
            end

            -- Verifikasi apakah boss yang lama masih ada di workspace
            if #activeBossNames > 0 then
                local stillActive = {}
                for _, bName in ipairs(activeBossNames) do
                    local bossModel = workspace:FindFirstChild(bName, true)
                    -- Boss dianggap masih aktif jika modelnya ada di workspace
                    if bossModel then
                        table.insert(stillActive, bName)
                    end
                end
                
                if #stillActive == 0 then
                    -- Coba cari event aktif lagi
                    local newBosses = findActiveBossNames()
                    if #newBosses > 0 then
                        activeBossNames = newBosses
                        activeBossName = newBosses[1]
                    else
                        activeBossNames = {}
                        activeBossName = nil
                    end
                else
                    activeBossNames = stillActive
                    activeBossName = stillActive[1]
                end
            else
                local newBosses = findActiveBossNames()
                if #newBosses > 0 then
                    activeBossNames = newBosses
                    activeBossName = newBosses[1]
                end
            end

            -- Ambil targetsToTap (Hanya yang dekat / di map yang sama dengan player)
            local targetsToTap = {}
            local char = LP.Character
            local playerHrp = char and char:FindFirstChild("HumanoidRootPart")
            
            for _, bName in ipairs(activeBossNames) do
                local bossModel = workspace:FindFirstChild(bName, true)
                if bossModel and playerHrp then
                    local bossHrp = bossModel:FindFirstChild("HumanoidRootPart") or bossModel:FindFirstChildWhichIsA("BasePart")
                    if bossHrp then
                        local dist = (bossHrp.Position - playerHrp.Position).Magnitude
                        if dist < 450 then -- Jarak aman agar tidak kena anti-cheat / bugs
                            table.insert(targetsToTap, bName)
                        end
                    end
                else
                    -- Jika model fisik belum spawn (masih penanda event),
                    -- tapi player sudah berdiri sangat dekat dengan Raid Orb/Circle:
                    local orb = findRaidOrb()
                    if orb and playerHrp then
                        local dist = (orb.Position - playerHrp.Position).Magnitude
                        if dist < 120 then
                            table.insert(targetsToTap, bName)
                        end
                    end
                end
            end

            if #targetsToTap == 0 then
                -- Fallback: Cari model terdekat dari player di workspace
                if playerHrp then
                    local nearestModel = nil
                    local nearestDist = 150
                    for _, obj in ipairs(workspace:GetChildren()) do
                        if obj:IsA("Model") and obj ~= char then
                            local isPlayer = Players:GetPlayerFromCharacter(obj)
                            if not isPlayer then
                                local objPart = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")
                                if objPart then
                                    local d = (objPart.Position - playerHrp.Position).Magnitude
                                    if d < nearestDist then
                                        nearestModel = obj
                                        nearestDist = d
                                    end
                                end
                            end
                        end
                    end
                    if nearestModel then
                        table.insert(targetsToTap, nearestModel.Name)
                    end
                end
            end

            -- Debug status setiap 1 detik
            local now = os.clock()
            if now - lastBossDebugTime > 1.0 then
                lastBossDebugTime = now
                local display = #targetsToTap > 0 and table.concat(targetsToTap, ", ") or "NONE"
                print(string.format("[F&M Boss Loop] Active: Targets=%s | Remote=%s | Delay=%s",
                    display,
                    tostring(cachedPlayerTap and cachedPlayerTap.Name or "NOT FOUND"),
                    tostring(bossTapDelay)
                ))
            end

            -- 1. Metode Pertama: GUI Button Clicker (100% Bebas Deteksi Boss Name)
            -- Cari tombol TAP! game asli di layar secara dinamis dan trigger klik-nya
            task.spawn(function()
                for _, gui in ipairs(LP.PlayerGui:GetDescendants()) do
                    if (gui:IsA("TextButton") or gui:IsA("ImageButton")) and isGuiVisible(gui) then
                        local fullName = gui:GetFullName():lower()
                        -- CRITICAL: Abaikan semua button yang merupakan bagian dari Rayfield/Cheat UI kita!
                        if not fullName:find("rayfield") then
                            local text = ""
                            pcall(function() text = gui.Text end)
                            local name = gui.Name:lower()
                            
                            -- Sangat spesifik mencocokkan tombol TAP! game asli di layar
                            local isExactTapText = (text == "TAP!" or text == "TAP" or text:lower() == "tap!" or text:lower() == "tap")
                            local isTapButtonName = (name == "tapbutton" or name == "tap_button" or name == "clickbutton")
                            
                            if isExactTapText or isTapButtonName then
                                pcall(function()
                                    if typeof(firesignal) == "function" then
                                        firesignal(gui.MouseButton1Click)
                                        firesignal(gui.Activated)
                                    else
                                        gui.MouseButton1Click:Fire()
                                        gui.Activated:Fire()
                                    end
                                end)
                            end
                        end
                    end
                end
            end)

            -- 2. Metode Kedua: Direct Remote Spammer (Sangat Cepat)
            -- 2. Metode Kedua: Direct Remote Spammer (Sangat Cepat)
            -- Kirim remote langsung ke semua boss di targetsToTap secara parallel (dikali bossTapMultiplier)
            if cachedPlayerTap and #targetsToTap > 0 then
                for _, target in ipairs(targetsToTap) do
                    for i = 1, bossTapMultiplier do
                        task.spawn(function()
                            local ok, result = pcall(function()
                                if cachedPlayerTap:IsA("RemoteFunction") then
                                    return cachedPlayerTap:InvokeServer(target)
                                else
                                    return cachedPlayerTap:FireServer(target)
                                end
                            end)
                            if not ok then
                                warn("[F&M Boss] Tap Error for " .. tostring(target) .. ": " .. tostring(result))
                            end
                        end)
                    end
                end
            end

        else
            cachedPlayerTap = nil
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
    Name = "Scan Pet Configurations (Console)",
    Callback = function()
        print("=== PET CONFIGURATION SCAN ===")
        local found = 0
        for _, obj in ipairs(game:GetDescendants()) do
            if obj:IsA("ModuleScript") and (obj.Name:lower():find("pet") or obj.Name:lower():find("kelelawar") or obj.Name:lower():find("bat")) then
                found = found + 1
                print(string.format("[%d] ModuleScript Path: %s", found, obj:GetFullName()))
                -- Coba require dan print isinya
                local ok, result = pcall(require, obj)
                if ok then
                    print("  Require successful. Type:", typeof(result))
                    if type(result) == "table" then
                        for k, v in pairs(result) do
                            print(string.format("    Key: %s | Value: %s", tostring(k), tostring(v)))
                            if type(v) == "table" then
                                for k2, v2 in pairs(v) do
                                    print(string.format("      SubKey: %s | Value: %s", tostring(k2), tostring(v2)))
                                end
                            end
                        end
                    else
                        print("  Value:", tostring(result))
                    end
                else
                    print("  Require failed:", tostring(result))
                end
            end
        end
        print("=== SCAN COMPLETE (Found " .. found .. " modules) ===")
        Rayfield:Notify({Title = "Pet Scan", Content = "Found " .. found .. " pet modules. Check console!", Duration = 3})
    end
})

TabDeveloper:CreateButton({
    Name = "Exploit Pet Stats (Force 100% Client Chance)",
    Callback = function()
        print("=== EXPLOITING PET STATS ===")
        local modifiedCount = 0
        for _, obj in ipairs(game:GetDescendants()) do
            if obj:IsA("ModuleScript") then
                local nameLower = obj.Name:lower()
                if nameLower:find("pet") or nameLower:find("kelelawar") or nameLower:find("bat") or nameLower:find("config") or nameLower:find("data") then
                    local ok, result = pcall(require, obj)
                    if ok and type(result) == "table" then
                        -- Scan for chance/rate/peluang/instant keys and overwrite
                        local function scanAndModify(tbl, path)
                            for k, v in pairs(tbl) do
                                local kStr = tostring(k)
                                local kLower = kStr:lower()
                                if type(v) == "table" then
                                    scanAndModify(v, path .. "." .. kStr)
                                elseif type(v) == "number" then
                                    if kLower:find("chance") or kLower:find("rate") or kLower:find("prob") or kLower:find("peluang") or kLower:find("instant") then
                                        local oldVal = v
                                        if v > 1 then
                                            tbl[k] = 100
                                        else
                                            tbl[k] = 1.0
                                        end
                                        modifiedCount = modifiedCount + 1
                                        print(string.format("  [MODIFIED] %s.%s: %s -> %s", path, kStr, tostring(oldVal), tostring(tbl[k])))
                                    end
                                end
                            end
                        end
                        scanAndModify(result, obj.Name)
                    end
                end
            end
        end
        print("=== EXPLOIT COMPLETE (Modified " .. modifiedCount .. " keys) ===")
        Rayfield:Notify({Title = "Pet Exploit", Content = "Exploited " .. modifiedCount .. " pet/config keys! Check console.", Duration = 4})
    end
})

TabDeveloper:CreateInput({
    Name = "Filter Search Script Name",
    PlaceholderText = "Type keyword (e.g. Pet, Fishing, Controller)",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        devSearchText = Text
    end
})

TabDeveloper:CreateButton({
    Name = "Decompile Matching Controllers (Auto Clipboard)",
    Callback = function()
        local outputText = "=== DECOMPILING TARGET CONTROLLERS ===\n"
        local function log(str)
            print(str)
            outputText = outputText .. str .. "\n"
        end
        
        local targetNames = {"PetController", "FishingController", "MinigameController", "PetConfig", "FishingConfig", "PetData", "FishingData"}
        if devSearchText ~= "" then
            table.insert(targetNames, devSearchText)
        end
        
        log("Searching for controllers matching targets or keyword: " .. devSearchText)
        local found = 0
        local searchFolders = {
            LP:WaitForChild("PlayerScripts"),
            game:GetService("ReplicatedStorage")
        }
        
        for _, folder in ipairs(searchFolders) do
            for _, obj in ipairs(folder:GetDescendants()) do
                if obj:IsA("ModuleScript") or obj:IsA("LocalScript") then
                    local matched = false
                    for _, target in ipairs(targetNames) do
                        if obj.Name:lower():find(target:lower()) then
                            matched = true
                            break
                        end
                    end
                    
                    if matched then
                        found = found + 1
                        log(string.format("\n--- [%d] DECOMPILING: %s (%s) ---", found, obj:GetFullName(), obj.ClassName))
                        local ok, code = pcall(decompile, obj)
                        if ok and type(code) == "string" and code ~= "" then
                            local lines = string.split(code, "\n")
                            for idx, line in ipairs(lines) do
                                log(string.format("L%d: %s", idx, line))
                            end
                            log("------------------------------------------")
                        else
                            log("Decompilation failed / returned nil: " .. tostring(code))
                        end
                    end
                end
            end
        end
        log("=== DECOMPILATION RUN COMPLETE ===")
        
        -- Copy to clipboard or fallback to file write
        local clipSuccess = pcall(function()
            if setclipboard then setclipboard(outputText)
            elseif toclipboard then toclipboard(outputText)
            else error("No clipboard") end
        end)
        
        if clipSuccess then
            Rayfield:Notify({Title = "Copied to Clipboard!", Content = "Decompiled code copied! Paste it in chat.", Duration = 5})
        else
            local fileSuccess = pcall(function()
                writefile("pet_fishing_decompile.txt", outputText)
            end)
            if fileSuccess then
                Rayfield:Notify({Title = "Saved to File!", Content = "Saved as 'pet_fishing_decompile.txt' in executor workspace.", Duration = 5})
            else
                Rayfield:Notify({Title = "Decompile Done", Content = "Finished! Check F9 Console.", Duration = 5})
            end
        end
    end
})

TabDeveloper:CreateButton({
    Name = "List Matching Client Scripts (Auto Clipboard)",
    Callback = function()
        local outputText = "=== MATCHING CLIENT SCRIPTS ===\n"
        if devSearchText ~= "" then
            outputText = outputText .. "Filter Keyword: " .. devSearchText .. "\n"
        end
        
        local function log(str)
            print(str)
            outputText = outputText .. str .. "\n"
        end
        
        local found = 0
        local searchFolders = {
            LP:WaitForChild("PlayerScripts"),
            game:GetService("ReplicatedStorage")
        }
        
        for _, folder in ipairs(searchFolders) do
            for _, obj in ipairs(folder:GetDescendants()) do
                if obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
                    local path = obj:GetFullName()
                    if not path:find("CoreGui") and not path:find("Chat") and not path:find("Animate") and not path:find("Freecam") then
                        local show = true
                        if devSearchText ~= "" then
                            show = path:lower():find(devSearchText:lower()) ~= nil
                        end
                        
                        if show then
                            found = found + 1
                            log(string.format("[%d] %s (%s)", found, path, obj.ClassName))
                        end
                    end
                end
            end
        end
        log("=== SCAN COMPLETE (Found " .. found .. " matching scripts) ===")
        
        -- Copy to clipboard or fallback to file write
        local clipSuccess = pcall(function()
            if setclipboard then setclipboard(outputText)
            elseif toclipboard then toclipboard(outputText)
            else error("No clipboard") end
        end)
        
        if clipSuccess then
            Rayfield:Notify({Title = "Copied to Clipboard!", Content = "Script list copied! Paste it in chat.", Duration = 5})
        else
            local fileSuccess = pcall(function()
                writefile("client_scripts_list.txt", outputText)
            end)
            if fileSuccess then
                Rayfield:Notify({Title = "Saved to File!", Content = "Saved as 'client_scripts_list.txt' in executor workspace.", Duration = 5})
            else
                Rayfield:Notify({Title = "Scan Done", Content = "Finished! Check F9 Console.", Duration = 5})
            end
        end
    end
})

TabDeveloper:CreateButton({
    Name = "Scan Fishing Controller Connections (Auto Clipboard)",
    Callback = function()
        local outputText = "=== FISHING CONTROLLER CONNECTIONS ===\n"
        local function log(str)
            print(str)
            outputText = outputText .. str .. "\n"
        end
        
        local obj = LP.PlayerScripts.Controllers.FishingController
        local ok, code = pcall(decompile, obj)
        if ok and type(code) == "string" and code ~= "" then
            local lines = string.split(code, "\n")
            for idx, line in ipairs(lines) do
                if line:find("v_u_101") or line:find("v_u_208") or line:find("applyDifficultySettings") or line:find("isAutoCatch") or line:find("FishingPullState") then
                    log(string.format("Line %d: %s", idx, line:gsub("^%s+", "")))
                end
            end
        else
            log("Decompilation failed: " .. tostring(code))
        end
        
        -- Copy to clipboard or fallback to file write
        local clipSuccess = pcall(function()
            if setclipboard then setclipboard(outputText)
            elseif toclipboard then toclipboard(outputText)
            else error("No clipboard") end
        end)
        
        if clipSuccess then
            Rayfield:Notify({Title = "Copied to Clipboard!", Content = "Scan results copied! Paste it in chat.", Duration = 5})
        else
            local fileSuccess = pcall(function()
                writefile("fishing_connections.txt", outputText)
            end)
            if fileSuccess then
                Rayfield:Notify({Title = "Saved to File!", Content = "Saved as 'fishing_connections.txt' in executor workspace.", Duration = 5})
            else
                Rayfield:Notify({Title = "Scan Done", Content = "Finished! Check F9 Console.", Duration = 5})
            end
        end
    end
})

local decompileStart = 2500
local decompileEnd = 2750

TabDeveloper:CreateInput({
    Name = "Decompile Start Line",
    PlaceholderText = "2500",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        decompileStart = tonumber(Text) or 2500
    end
})

TabDeveloper:CreateInput({
    Name = "Decompile End Line",
    PlaceholderText = "2750",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        decompileEnd = tonumber(Text) or 2750
    end
})

TabDeveloper:CreateButton({
    Name = "Decompile Range of Target Script (Auto Clipboard)",
    Callback = function()
        local targetName = devSearchText ~= "" and devSearchText or "FishingController"
        
        local obj = nil
        local searchFolders = {
            LP:WaitForChild("PlayerScripts"),
            game:GetService("ReplicatedStorage")
        }
        
        for _, folder in ipairs(searchFolders) do
            for _, child in ipairs(folder:GetDescendants()) do
                if (child:IsA("ModuleScript") or child:IsA("LocalScript")) and child.Name:lower() == targetName:lower() then
                    obj = child
                    break
                end
            end
            if obj then break end
        end
        
        if not obj then
            for _, folder in ipairs(searchFolders) do
                for _, child in ipairs(folder:GetDescendants()) do
                    if (child:IsA("ModuleScript") or child:IsA("LocalScript")) and child.Name:lower():find(targetName:lower()) then
                        obj = child
                        break
                    end
                end
                if obj then break end
            end
        end
        
        if not obj then
            Rayfield:Notify({Title = "Not Found", Content = "Script '" .. targetName .. "' not found!", Duration = 3})
            return
        end
        
        local outputText = string.format("=== %s DECOMPILE L%d - L%d ===\n", obj.Name, decompileStart, decompileEnd)
        local function log(str)
            print(str)
            outputText = outputText .. str .. "\n"
        end
        
        local ok, code = pcall(decompile, obj)
        if ok and type(code) == "string" and code ~= "" then
            local lines = string.split(code, "\n")
            for idx = decompileStart, math.min(decompileEnd, #lines) do
                if lines[idx] then
                    log(string.format("L%d: %s", idx, lines[idx]))
                end
            end
        else
            log("Decompilation failed: " .. tostring(code))
        end
        
        -- Copy to clipboard
        local clipSuccess = pcall(function()
            if setclipboard then setclipboard(outputText)
            elseif toclipboard then toclipboard(outputText)
            else error("No clipboard") end
        end)
        
        if clipSuccess then
            Rayfield:Notify({Title = "Copied to Clipboard!", Content = "Line range copied! Paste it in chat.", Duration = 5})
        else
            local fileSuccess = pcall(function()
                writefile("script_decompile_range.txt", outputText)
            end)
            if fileSuccess then
                Rayfield:Notify({Title = "Saved to File!", Content = "Saved as 'script_decompile_range.txt' in executor workspace.", Duration = 5})
            else
                Rayfield:Notify({Title = "Decompile Done", Content = "Finished! Check F9 Console.", Duration = 5})
            end
        end
    end
})

TabDeveloper:CreateButton({
    Name = "List All Controller Names (F9/Clipboard)",
    Callback = function()
        local output = "=== KNIT CONTROLLERS ===\n"
        local ok, folder = pcall(function() return LP:WaitForChild("PlayerScripts"):WaitForChild("Controllers") end)
        if ok and folder then
            for _, child in ipairs(folder:GetChildren()) do
                output = output .. child.Name .. " (" .. child.ClassName .. ")\n"
            end
        else
            output = output .. "Controllers folder not found!\n"
        end
        
        local clipSuccess = pcall(function()
            if setclipboard then setclipboard(output)
            elseif toclipboard then toclipboard(output)
            else error("No clipboard") end
        end)
        
        if clipSuccess then
            Rayfield:Notify({Title = "Copied!", Content = "Controller list copied!", Duration = 5})
        else
            print(output)
            Rayfield:Notify({Title = "Done", Content = "Printed names in F9 console.", Duration = 5})
        end
    end
})

TabDeveloper:CreateButton({
    Name = "Decompile PetConfig Table (Auto Clipboard)",
    Callback = function()
        local obj = game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("PetConfig")
        local ok, code = pcall(decompile, obj)
        if ok and type(code) == "string" and code ~= "" then
            local clipSuccess = pcall(function()
                if setclipboard then setclipboard(code)
                elseif toclipboard then toclipboard(code)
                else error("No clipboard") end
            end)
            if clipSuccess then
                Rayfield:Notify({Title = "Copied!", Content = "PetConfig table copied to clipboard!", Duration = 5})
            else
                writefile("pet_config_decompile.txt", code)
                Rayfield:Notify({Title = "Saved to File!", Content = "Saved as 'pet_config_decompile.txt' in workspace.", Duration = 5})
            end
        else
            Rayfield:Notify({Title = "Error", Content = "Failed to decompile PetConfig: " .. tostring(code), Duration = 5})
        end
    end
})

local exploitPetUUID = "Cave Bat_605472_Legendary_1_0"

TabDeveloper:CreateSection("Pet Multi-Equip Exploit")

TabDeveloper:CreateInput({
    Name = "Exploit Pet UUID",
    PlaceholderText = "Cave Bat_605472_Legendary_1_0",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        exploitPetUUID = Text
    end
})

TabDeveloper:CreateButton({
    Name = "Equip Single Pet (UUID)",
    Callback = function()
        local Knit = getKnitClient()
        if not Knit then return end
        local PetService = Knit.GetService and Knit.GetService("PetService") or Knit.Services and Knit.Services.PetService
        if not PetService then return end
        
        local ok, err = pcall(function()
            return PetService:EquipPet(exploitPetUUID)
        end)
        if ok then
            Rayfield:Notify({Title = "Equipped Single", Content = "EquipPet sent: " .. exploitPetUUID, Duration = 3})
        else
            Rayfield:Notify({Title = "Error", Content = tostring(err), Duration = 3})
        end
    end
})

TabDeveloper:CreateButton({
    Name = "Equip Pet 10x (Spam Exploit)",
    Callback = function()
        local Knit = getKnitClient()
        if not Knit then
            Rayfield:Notify({Title = "Error", Content = "Knit client not found!", Duration = 3})
            return
        end
        local PetService = Knit.GetService and Knit.GetService("PetService") or Knit.Services and Knit.Services.PetService
        if not PetService then
            Rayfield:Notify({Title = "Error", Content = "PetService not found!", Duration = 3})
            return
        end
        
        Rayfield:Notify({Title = "Running Exploit", Content = "Spamming EquipPet for: " .. exploitPetUUID, Duration = 3})
        for i = 1, 10 do
            task.spawn(function()
                local ok, err = pcall(function()
                    return PetService:EquipPet(exploitPetUUID)
                end)
                if not ok then
                    warn("EquipPet fail:", tostring(err))
                end
            end)
        end
    end
})

TabDeveloper:CreateButton({
    Name = "Unequip Pet (Clean)",
    Callback = function()
        local Knit = getKnitClient()
        if not Knit then return end
        local PetService = Knit.GetService and Knit.GetService("PetService") or Knit.Services and Knit.Services.PetService
        if not PetService then return end
        
        pcall(function()
            PetService:UnequipPet(exploitPetUUID)
        end)
        Rayfield:Notify({Title = "Unequipped", Content = "Sent UnequipPet command.", Duration = 3})
    end
})

TabDeveloper:CreateButton({
    Name = "Scan PetService & Inventory (Auto Clipboard)",
    Callback = function()
        local outputText = "=== PET SERVICE & INVENTORY SCAN ===\n"
        local function log(str)
            print(str)
            outputText = outputText .. str .. "\n"
        end
        
        local Knit = getKnitClient()
        if not Knit then
            log("Knit framework not found!")
            return
        end
        
        local PetService = Knit.GetService and Knit.GetService("PetService") or Knit.Services and Knit.Services.PetService
        if not PetService then
            log("PetService not found in Knit!")
            return
        end
        
        log("PetService keys:")
        for k, v in pairs(PetService) do
            log(string.format("  %s (%s)", k, type(v)))
            if type(v) == "table" then
                for k2, v2 in pairs(v) do
                    log(string.format("    SubKey: %s (%s)", k2, type(v2)))
                end
            end
        end
        
        -- Try to fetch inventory
        local possibleMethods = {"GetPetData", "GetPets", "GetOwnedPets", "GetInventory", "GetMyPets", "GetPlayerData"}
        local foundData = false
        for _, method in ipairs(possibleMethods) do
            if PetService[method] then
                log("Invoking method: " .. method)
                local ok, res = pcall(function() return PetService[method](PetService) end)
                if ok then
                    log("Method " .. method .. " returned type: " .. type(res))
                    if type(res) == "table" then
                        foundData = true
                        for k, v in pairs(res) do
                            log(string.format("  [%s] = %s (%s)", tostring(k), tostring(v), type(v)))
                            if type(v) == "table" then
                                for k2, v2 in pairs(v) do
                                    log(string.format("    %s = %s (%s)", tostring(k2), tostring(v2), type(v2)))
                                    if type(v2) == "table" then
                                        for k3, v3 in pairs(v2) do
                                            log(string.format("      %s = %s", tostring(k3), tostring(v3)))
                                        end
                                    end
                                end
                            end
                        end
                    end
                else
                    log("Method " .. method .. " call failed: " .. tostring(res))
                end
            end
        end
        
        if not foundData then
            log("Could not retrieve pet inventory automatically using Knit methods.")
            -- Check replicated storage player folders
            local lpData = game:GetService("ReplicatedStorage"):FindFirstChild("PlayerData")
            if lpData then
                local myFolder = lpData:FindFirstChild(LP.Name)
                if myFolder then
                    log("Found PlayerData folder for player in ReplicatedStorage: " .. myFolder:GetFullName())
                    for _, child in ipairs(myFolder:GetDescendants()) do
                        if child:IsA("ValueObject") or child:IsA("Configuration") then
                            log(string.format("  %s = %s (%s)", child:GetFullName(), tostring(child.Value), child.ClassName))
                        end
                    end
                end
            end
        end
        
        -- Copy to clipboard
        local clipSuccess = pcall(function()
            if setclipboard then setclipboard(outputText)
            elseif toclipboard then toclipboard(outputText)
            else error("No clipboard") end
        end)
        
        if clipSuccess then
            Rayfield:Notify({Title = "Copied!", Content = "PetService scan results copied to clipboard!", Duration = 5})
        else
            writefile("pet_service_scan.txt", outputText)
            Rayfield:Notify({Title = "Saved to File!", Content = "Saved as 'pet_service_scan.txt' in workspace.", Duration = 5})
        end
    end
})

TabDeveloper:CreateButton({
    Name = "[DEBUG] Scan Inventory & Client State (Console)",
    Callback = function()
        print("=== INVENTORY & CLIENT STATE SCAN ===")
        
        -- 1. Scan LocalPlayer properties and folders
        print("--- Player Children ---")
        for _, child in ipairs(LP:GetChildren()) do
            print(string.format("  %s (%s)", child.Name, child.ClassName))
            if child:IsA("Folder") or child:IsA("Configuration") or child:IsA("StringValue") or child:IsA("ValueObject") then
                local items = child:GetChildren()
                print(string.format("    (Total items: %d)", #items))
                for i = 1, math.min(15, #items) do
                    print(string.format("    [%d] %s (%s)", i, items[i].Name, items[i].ClassName))
                    local attrs = items[i]:GetAttributes()
                    for k, v in pairs(attrs) do
                        print(string.format("      Attr: %s = %s", k, tostring(v)))
                    end
                end
            end
        end
        
        -- 2. Scan ReplicatedStorage player data
        print("--- ReplicatedStorage PlayerData / Replicas ---")
        for _, child in ipairs(ReplicatedStorage:GetChildren()) do
            local nameLower = child.Name:lower()
            if nameLower:find("replica") or nameLower:find("profile") or nameLower:find("data") or nameLower:find("state") or nameLower:find("inventory") then
                print(string.format("  Found candidate: %s (%s)", child.Name, child.ClassName))
                local items = child:GetChildren()
                for i = 1, math.min(10, #items) do
                    print(string.format("    [%d] %s (%s)", i, items[i].Name, items[i].ClassName))
                end
            end
        end
        
        -- 3. Scan Knit controllers inventory methods
        local Knit = getKnitClient()
        if Knit then
            print("--- Knit Controllers Inventory/Shop Candidates ---")
            for name, controller in pairs(Knit.Controllers or {}) do
                local nameLower = name:lower()
                if nameLower:find("inv") or nameLower:find("shop") or nameLower:find("merchant") or nameLower:find("fish") or nameLower:find("player") then
                    print(string.format("  Controller: %s", name))
                    for k, v in pairs(controller) do
                        if type(v) == "function" then
                            print(string.format("    Method: %s", k))
                        else
                            local valStr = tostring(v)
                            if type(v) == "table" then
                                valStr = "{...} (size " .. tostring(#v) .. ")"
                            end
                            print(string.format("    Property: %s = %s (%s)", k, valStr, typeof(v)))
                        end
                    end
                end
            end
        else
            print("Knit Client not found!")
        end
        
        print("=== SCAN COMPLETE ===")
        Rayfield:Notify({Title = "Diagnosis Done!", Content = "Scan finished. Check Console (F9)!", Duration = 4})
    end
})


TabDeveloper:CreateButton({
    Name = "[DEBUG] Fishing Diagnosis (Check Console!)",
    Callback = function()
        print("=== FISHING REMOTE DIAGNOSIS ===")
        
        -- Scan specific services
        local servicesToScan = {"FishingRewardService", "FishingReplicationService", "AssetPreviewService"}
        local rep = game:GetService("ReplicatedStorage")
        local packages = rep:FindFirstChild("Packages")
        if packages then
            local index = packages:FindFirstChild("_Index")
            if index then
                for _, child in ipairs(index:GetChildren()) do
                    if child.Name:find("sleitnick_knit") then
                        local services = child:FindFirstChild("Services", true)
                        if services then
                            for _, sName in ipairs(servicesToScan) do
                                local sObj = services:FindFirstChild(sName)
                                if sObj then
                                    print("Service Found: " .. sObj:GetFullName())
                                    for _, folder in ipairs(sObj:GetChildren()) do
                                        if folder.Name == "RF" or folder.Name == "RE" then
                                            for _, remote in ipairs(folder:GetChildren()) do
                                                print("  [" .. folder.Name .. "] " .. remote.Name .. " (" .. remote.ClassName .. ")")
                                            end
                                        end
                                    end
                                else
                                    print("Service NOT Found in " .. child.Name .. ": " .. sName)
                                end
                            end
                        end
                    end
                end
            end
        end
        print("=== END FISHING DIAGNOSIS ===")
        Rayfield:Notify({Title = "Diagnosis Done!", Content = "Check console output!", Duration = 3})
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

TabDeveloper:CreateButton({
    Name = "[DEBUG] Scan Workspace NPCs (Console)",
    Callback = function()
        print("=== WORKSPACE NPC SCAN ===")
        local count = 0
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") then
                local hum = obj:FindFirstChildOfClass("Humanoid")
                local isPlayer = game:GetService("Players"):GetPlayerFromCharacter(obj)
                
                if hum and not isPlayer then
                    count = count + 1
                    local hrp = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")
                    local posStr = hrp and tostring(hrp.Position) or "No Part"
                    print(string.format("[%d] Name: '%s' | Path: %s | Pos: %s", count, obj.Name, obj:GetFullName(), posStr))
                end
            end
        end
        print("=== SCAN COMPLETE (Found " .. count .. " NPCs) ===")
        Rayfield:Notify({Title = "NPC Scan Complete", Content = "Found " .. count .. " NPCs. Check Console!", Duration = 4})
    end
})


-- Metatable Hooking for Remote Spy (Dengan deep table serialization)
-- Hanya jalan di executor yang support getrawmetatable (Synapse, KRNL, etc.)
-- Delta / mobile executor: fallback gracefully
local hookSuccess, err = false, "Not attempted"

if typeof(getrawmetatable) == "function" and typeof(setreadonly) == "function"
    and typeof(newcclosure) == "function" and typeof(getnamecallmethod) == "function" then

    hookSuccess, err = pcall(function()
        local mt = getrawmetatable(game)
        local oldNamecall = mt.__namecall
        setreadonly(mt, false)
        
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if remoteSpyEnabled and (method == "FireServer" or method == "InvokeServer") then
                local args = {...}
                print("[Remote Spy] Fired: " .. self:GetFullName() .. " | Method: " .. method)
                if #args > 0 then
                    for i, v in ipairs(args) do
                        if type(v) == "table" then
                            print(string.format("   [%d] (table): {", i))
                            dumpTable(v, "      ")
                            print("   }")
                        else
                            print(string.format("   [%d] (%s): %s", i, typeof(v), tostring(v)))
                        end
                    end
                else
                    print("   Arguments: None")
                end
            end
            return oldNamecall(self, ...)
        end)
        
        setreadonly(mt, true)
    end)
else
    -- Delta / mobile executor: Remote Spy tidak tersedia
    hookSuccess = false
    err = "getrawmetatable/setreadonly/newcclosure not available (Delta/mobile executor)"
    print("[F&M] Remote Spy tidak tersedia di executor ini (Delta/mobile). Fitur lain tetap normal.")
end

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

----------------------------------------------------
-- TREASURE CHEST SECTION
----------------------------------------------------
TabPlayer:CreateSection("Treasure Chest")

-- Helper: scan semua attachment CHEST di workspace (semua map)
local function findAllChestAttachments()
    local results = {}
    local function scan(instance)
        for _, child in ipairs(instance:GetChildren()) do
            if child:IsA("Attachment") and child.Name:match("^CHEST_") then
                table.insert(results, child.Name)
            end
            scan(child)
        end
    end
    scan(workspace)
    return results
end

-- Helper: dapatkan RequestOpenChest remote
local function getOpenChestRemote()
    local pkgs = ReplicatedStorage:FindFirstChild("Packages")
    if not pkgs then return nil end
    local idx = pkgs:FindFirstChild("_Index")
    if not idx then return nil end
    for _, pkg in ipairs(idx:GetChildren()) do
        local knit = pkg:FindFirstChild("knit")
        if knit then
            local services = knit:FindFirstChild("Services")
            if services then
                local treasureSvc = services:FindFirstChild("TreasureService")
                if treasureSvc then
                    local rf = treasureSvc:FindFirstChild("RF")
                    if rf then
                        local remote = rf:FindFirstChild("RequestOpenChest")
                        if remote then return remote end
                    end
                end
            end
        end
    end
    return nil
end

TabPlayer:CreateButton({
    Name = "Open All Chests (Scan Map)",
    Callback = function()
        local remote = getOpenChestRemote()
        if not remote then
            Rayfield:Notify({Title = "Chest Error", Content = "RequestOpenChest remote tidak ditemukan!", Duration = 4})
            warn("[F&M Chest] RequestOpenChest remote tidak ditemukan!")
            return
        end

        local chests = findAllChestAttachments()
        if #chests == 0 then
            Rayfield:Notify({Title = "Chest", Content = "Tidak ada chest ditemukan di map ini.", Duration = 4})
            print("[F&M Chest] Tidak ada attachment CHEST_ ditemukan di workspace.")
            return
        end

        print("[F&M Chest] Ditemukan " .. #chests .. " chest, mulai open...")
        Rayfield:Notify({
            Title = "Chest Found!",
            Content = "Ditemukan " .. #chests .. " chest. Sedang dibuka...",
            Duration = 4
        })

        local opened = 0
        local failed = 0
        for _, chestName in ipairs(chests) do
            local ok, result = pcall(function()
                return remote:InvokeServer(chestName)
            end)
            if ok then
                opened = opened + 1
                print("[F&M Chest] Opened: " .. chestName .. " | result: " .. tostring(result))
            else
                failed = failed + 1
                print("[F&M Chest] Failed: " .. chestName .. " | err: " .. tostring(result))
            end
            task.wait(0.3) -- Delay antar chest agar tidak rate-limit
        end

        local msg = "Selesai! Opened: " .. opened
        if failed > 0 then msg = msg .. " | Failed: " .. failed end
        Rayfield:Notify({Title = "Chest Done!", Content = msg, Duration = 6})
        print("[F&M Chest] " .. msg)
    end
})

TabPlayer:CreateButton({
    Name = "Scan Chest Count (Debug)",
    Callback = function()
        local chests = findAllChestAttachments()
        print("[F&M Chest] Total chest di map: " .. #chests)
        for i, name in ipairs(chests) do
            print("  [" .. i .. "] " .. name)
        end
        Rayfield:Notify({
            Title = "Chest Scan",
            Content = "Ditemukan " .. #chests .. " chest. Lihat console untuk detail.",
            Duration = 4
        })
    end
})

----------------------------------------------------
-- AUTO SELL TAB SECTION
----------------------------------------------------
TabSell:CreateSection("Auto Sell Toggles")

local sellLabel = TabSell:CreateLabel("Detected Remote: Scanning...")
local inventoryLabel = TabSell:CreateLabel("Inventory Items: Scanning...")

-- Helper: dapatkan atau scan config ikan untuk filter rarity
local fishConfigCache = {}
local function cacheFishConfig()
    local getConfig = ReplicatedStorage:FindFirstChild("GetConfigOnDemand")
    if getConfig and getConfig:IsA("RemoteFunction") then
        local ok, data = pcall(function() return getConfig:InvokeServer("FishConfig") end)
        if ok and type(data) == "table" then
            fishConfigCache = data
            print("[F&M Auto Sell] FishConfig successfully cached! Total entries: " .. tostring(#data or 0))
            return true
        end
    end
    return false
end

-- Helper: cari rarity berdasarkan FishId dari cache config
local function getFishRarity(fishId)
    if not fishId then return "Common" end
    if not next(fishConfigCache) then cacheFishConfig() end
    local cfg = fishConfigCache[fishId]
    if cfg then
        return cfg.Rarity or cfg.rarity or cfg.RarityId or "Common"
    end
    -- Fallback case-insensitive
    for name, data in pairs(fishConfigCache) do
        if name and name:lower() == fishId:lower() then
            return data.Rarity or data.rarity or data.RarityId or "Common"
        end
    end
    return "Common"
end

local function scanTableForInventory(tbl, depth, list)
    if depth > 4 then return end
    if type(tbl) ~= "table" then return end
    
    -- Cek jika tabel ini sendiri merepresentasikan satu item ikan
    local fishId = tbl.FishId or tbl.fishId or tbl.Name or tbl.name or tbl.Id or tbl.id
    local instanceId = tbl.InstanceId or tbl.instanceId or tbl.UUID or tbl.uuid or tbl.instance
    if type(fishId) == "string" and type(instanceId) == "string" and instanceId:match("^%x%x%x%x%x%x%x%x$") then
        -- Masukkan jika belum ada
        local exists = false
        for _, item in ipairs(list) do
            if item.InstanceId == instanceId then exists = true; break end
        end
        if not exists then
            table.insert(list, {
                FishId = fishId,
                InstanceId = instanceId,
                Count = tbl.Count or tbl.count or 1,
                Rarity = tbl.Rarity or tbl.rarity
            })
        end
        return
    end
    
    -- Cek jika tabel ini adalah dictionary dari item ikan
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            -- Cek jika key adalah instanceId (8-char hex)
            if type(k) == "string" and k:match("^%x%x%x%x%x%x%x%x$") then
                local fId = v.FishId or v.fishId or v.Name or v.name or v.Id or v.id
                local exists = false
                for _, item in ipairs(list) do
                    if item.InstanceId == k then exists = true; break end
                end
                if not exists then
                    table.insert(list, {
                        FishId = fId or "Unknown",
                        InstanceId = k,
                        Count = v.Count or v.count or 1,
                        Rarity = v.Rarity or v.rarity
                    })
                end
            else
                scanTableForInventory(v, depth + 1, list)
            end
        elseif type(v) == "string" and type(k) == "string" and k:match("^%x%x%x%x%x%x%x%x$") then
            -- Kasus map sederhana: { ["47bc7979"] = "Axolotl" }
            local exists = false
            for _, item in ipairs(list) do
                if item.InstanceId == k then exists = true; break end
            end
            if not exists then
                table.insert(list, {
                    FishId = v,
                    InstanceId = k,
                    Count = 1
                })
            end
        end
    end
end

-- Helper: ambil inventory ikan LANGSUNG dari server via GetFishInventory remote
-- STRUKTUR CONFIRMED via debug:
--   result = DICTIONARY {
--     FishList = ARRAY [                         <-- ini yang kita iterasi
--       { FishId="Barred_Halmet", Rarity="Common", Count=28,
--         Instances = ARRAY [ {InstanceId=?,...}, {InstanceId=?,...}, ... ] },
--       ...
--     ],
--     TotalValue = number,
--     FavoritedFish = {[hexId]=true,...},
--     Money = number,
--   }
local function getInventoryFish()
    local fishList = {}

    local getInvRemote = nil
    pcall(function()
        getInvRemote = game:GetService("ReplicatedStorage")
            .Packages._Index["sleitnick_knit@1.7.0"]
            .knit.Services.FishermanShopService.RF.GetFishInventory
    end)
    if not getInvRemote then
        getInvRemote = findKnitRemote("FishermanShopService", "GetFishInventory")
    end

    if not getInvRemote then
        warn("[F&M Auto Sell] Remote GetFishInventory tidak ditemukan!")
        pcall(function() inventoryLabel:Set("Inventory Items: Remote NOT FOUND") end)
        return fishList
    end

    local ok, result = pcall(function()
        return getInvRemote:InvokeServer()
    end)

    if not ok or type(result) ~= "table" then
        warn("[F&M Auto Sell] GetFishInventory gagal: " .. tostring(result))
        pcall(function() inventoryLabel:Set("Inventory Items: Invoke Failed") end)
        return fishList
    end

    -- result adalah DICTIONARY, bukan array!
    -- Ambil result.FishList yang merupakan array of fish type entries
    local rawFishList = result.FishList or result.fishList or result.Fish or result.fish

    if type(rawFishList) ~= "table" then
        warn("[F&M Auto Sell] result.FishList tidak ada! Keys tersedia:")
        for k, v in pairs(result) do
            print("  [" .. tostring(k) .. "] = " .. type(v))
        end
        pcall(function() inventoryLabel:Set("Inventory Items: FishList key missing") end)
        return fishList
    end

    print("[F&M Auto Sell] FishList length: " .. #rawFishList)

    for _, fishEntry in ipairs(rawFishList) do
        local fishId    = fishEntry.FishId or fishEntry.fishId or fishEntry.Name or fishEntry.name
        local rarity    = fishEntry.Rarity or fishEntry.rarity or "Common"
        local instances = fishEntry.Instances or fishEntry.instances

        -- Hanya proses ikan yang ada di tas (punya Instances)
        if type(fishId) == "string" and type(instances) == "table" and #instances > 0 then
            print("[F&M Auto Sell] " .. fishId .. " [" .. tostring(rarity) .. "] x" .. #instances)

            for _, inst in ipairs(instances) do
                local instanceId = nil

                if type(inst) == "table" then
                    -- Coba semua kemungkinan field name untuk InstanceId
                    instanceId = inst.InstanceId or inst.instanceId
                        or inst.Id or inst.id
                        or inst.UUID or inst.uuid
                        or inst.GUID or inst.guid
                        or inst.Hash or inst.hash
                        or inst.Key or inst.key

                    -- Jika field tidak ketemu, log semua key untuk debug
                    if not instanceId then
                        local keys = {}
                        for k in pairs(inst) do table.insert(keys, tostring(k)) end
                        warn("[F&M Auto Sell] InstanceId field not found! Available keys: " .. table.concat(keys, ", "))
                    end
                elseif type(inst) == "string" then
                    -- Instance langsung berupa string hex
                    instanceId = inst
                end

                if type(instanceId) == "string" and instanceId ~= "" then
                    table.insert(fishList, {
                        FishId     = fishId,
                        InstanceId = instanceId,
                        Count      = 1,  -- SellSelectedFish selalu Count=1 per instance
                        Rarity     = rarity
                    })
                end
            end
        end
    end

    print("[F&M Auto Sell] Total parsed: " .. #fishList .. " instances")
    pcall(function() inventoryLabel:Set("Inventory Items: Found " .. #fishList) end)
    return fishList
end


-- Helper: cari BasePart dari FishermanSellPrompt (confirmed name via debug)
-- Naiki parent chain dari ProximityPrompt sampai ketemu BasePart
local cachedFishermanNPC = nil
local cachedFishermanPrompt = nil

local function findFishermanNPC()
    if cachedFishermanNPC and cachedFishermanNPC.Parent then
        return cachedFishermanNPC, cachedFishermanPrompt
    end

    local myPos = Vector3.new()
    pcall(function() myPos = LP.Character.HumanoidRootPart.Position end)

    local bestDist = math.huge
    local bestPart, bestPrompt = nil, nil

    -- Scan semua ProximityPrompt → cari FishermanSellPrompt
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and (
            obj.Name == "FishermanSellPrompt" or
            obj.ActionText == "Sell Fish" or
            obj.ObjectText:find("Fisherman")
        ) then
            -- Naiki parent chain sampai ketemu BasePart
            local part = nil
            local node = obj.Parent
            while node and node ~= workspace do
                if node:IsA("BasePart") then
                    part = node
                    break
                end
                -- Kalau node adalah Model, coba PrimaryPart atau child BasePart
                if node:IsA("Model") then
                    local pp = node.PrimaryPart
                    if pp then part = pp; break end
                    local bp = node:FindFirstChildWhichIsA("BasePart")
                    if bp then part = bp; break end
                end
                node = node.Parent
            end

            if part then
                local dist = (part.Position - myPos).Magnitude
                -- Prioritaskan GameSystemObject atau FishermanShop (tempat server check distance)
                local isSystem = obj:GetFullName():lower():find("gamesystemobject") or obj:GetFullName():lower():find("fishermanshop")
                local score = dist
                if isSystem then
                    score = dist - 100000 -- Berikan penalti jarak agar selalu dipilih
                end

                print("[F&M DEBUG] Candidate: " .. obj:GetFullName() .. " dist=" .. math.floor(dist) .. " (isSystem=" .. tostring(isSystem) .. ")")
                if score < bestDist then
                    bestDist = score
                    bestPart = part
                    bestPrompt = obj
                end
            else
                warn("[F&M DEBUG] Tidak dapat BasePart dari: " .. obj:GetFullName())
            end
        end
    end

    if bestPart then
        print("[F&M Auto Sell] ✓ Shop Part: " .. bestPart:GetFullName() .. " | Prompt: " .. bestPrompt:GetFullName() .. " | Score Dist: " .. math.floor(bestDist))
        cachedFishermanNPC = bestPart
        cachedFishermanPrompt = bestPrompt
    else
        warn("[F&M Auto Sell] ✗ Tidak ada BasePart ditemukan dari FishermanSellPrompt!")
    end

    return cachedFishermanNPC, cachedFishermanPrompt
end



-- Helper: buka shop lewat proximity prompt NPC
local function openShopNPC()
    local npcPart = findFishermanNPC()
    if npcPart then
        local prompt = npcPart.Parent:FindFirstChildWhichIsA("ProximityPrompt", true) or npcPart:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt then
            print("[F&M Auto Sell] Firing ProximityPrompt to open shop...")
            if typeof(fireproximityprompt) == "function" then
                pcall(fireproximityprompt, prompt)
            else
                pcall(function()
                    prompt:InputHoldBegin()
                    task.wait(0.2)
                    prompt:InputHoldEnd()
                end)
            end
            return true
        end
    end
    return false
end

-- Helper: otomatisasi klik tombol "Add All [Rarity] to Cart" dan "Sell All" di UI
local function clickShopButtonsToSell()
    local buttonsFound = {}
    for _, gui in ipairs(LP.PlayerGui:GetDescendants()) do
        if gui:IsA("TextButton") or gui:IsA("ImageButton") then
            local text = ""
            pcall(function() text = gui.Text:lower() end)
            local name = gui.Name:lower()
            buttonsFound[gui] = {text = text, name = name, path = gui:GetFullName():lower()}
        end
    end
    
    local function clickButtonByKeywords(keywords)
        for btn, info in pairs(buttonsFound) do
            local matchAll = true
            for _, kw in ipairs(keywords) do
                if not info.text:find(kw) and not info.name:find(kw) and not info.path:find(kw) then
                    matchAll = false
                    break
                end
            end
            if matchAll then
                pcall(function()
                    guiCollide(btn)
                end)
                return true
            end
        end
        return false
    end
    
    -- 1. Tambahkan ikan ke keranjang berdasarkan setting toggle
    local clickedAny = false
    if sellCommon then
        if clickButtonByKeywords({"add", "common"}) or clickButtonByKeywords({"cart", "common"}) or clickButtonByKeywords({"all", "common"}) then
            clickedAny = true
        end
    end
    if sellUncommon then
        if clickButtonByKeywords({"add", "uncommon"}) or clickButtonByKeywords({"cart", "uncommon"}) or clickButtonByKeywords({"all", "uncommon"}) then
            clickedAny = true
        end
    end
    if sellRare then
        if clickButtonByKeywords({"add", "rare"}) or clickButtonByKeywords({"cart", "rare"}) or clickButtonByKeywords({"all", "rare"}) then
            clickedAny = true
        end
    end
    if sellEpic then
        if clickButtonByKeywords({"add", "epic"}) or clickButtonByKeywords({"cart", "epic"}) or clickButtonByKeywords({"all", "epic"}) then
            clickedAny = true
        end
    end
    if sellLegendary then
        if clickButtonByKeywords({"add", "legendary"}) or clickButtonByKeywords({"cart", "legendary"}) or clickButtonByKeywords({"all", "legendary"}) then
            clickedAny = true
        end
    end
    
    -- 2. Klik tombol Sell
    task.wait(0.2)
    local sold = clickButtonByKeywords({"sell"}) or clickButtonByKeywords({"jual"}) or clickButtonByKeywords({"cart", "all"})
    
    -- 3. Tutup shop UI
    task.wait(0.2)
    local _ = clickButtonByKeywords({"close"}) or clickButtonByKeywords({"exit"}) or clickButtonByKeywords({"tutup"})
    
    return sold or clickedAny
end

-- Utama: lakukan penjualan berdasarkan filter rarity
local function performSell()
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local oldCFrame = nil

    -- ============================================================
    -- STEP 1: Dapatkan remote SellSelectedFish via path exact (Cobalt confirmed)
    -- ============================================================
    local sellSelectedRemote = nil
    pcall(function()
        sellSelectedRemote = game:GetService("ReplicatedStorage")
            .Packages._Index["sleitnick_knit@1.7.0"]
            .knit.Services.FishermanShopService.RF.SellSelectedFish
    end)
    -- Fallback: cari dengan findKnitRemote jika versi knit berubah
    if not sellSelectedRemote then
        sellSelectedRemote = findKnitRemote("FishermanShopService", "SellSelectedFish")
    end

    if not sellSelectedRemote then
        pcall(function() sellLabel:Set("Detected Remote: NOT FOUND!") end)
        warn("[F&M Auto Sell] SellSelectedFish remote tidak ditemukan!")
        return false, "Remote tidak ditemukan"
    end
    pcall(function() sellLabel:Set("Detected Remote: SellSelectedFish ✓") end)

    -- ============================================================
    -- STEP 2: Teleport ke BasePart NPC + Fire ProximityPrompt
    -- ============================================================
    if hrp and teleportToSell then
        local npcPart, prompt = findFishermanNPC()
        if npcPart then
            oldCFrame = hrp.CFrame
            print("[F&M Auto Sell] Teleporting ke BasePart: " .. npcPart:GetFullName())
            print("[F&M Auto Sell] Position: " .. tostring(npcPart.Position))

            -- UNANCHOR agar Roblox mengirim paket posisi CFrame terbaru ke server
            hrp.Anchored = false
            hrp.CFrame = npcPart.CFrame * CFrame.new(0, 1.5, 0)
            task.wait(0.3) -- Berikan jeda untuk replikasi posisi unanchored ke server

            -- ANCHOR setelah ter-teleport demi stabilitas
            hrp.Anchored = true
            task.wait(0.1)

            -- Fire ProximityPrompt (HoldDuration aware)
            if prompt then
                local holdTime = prompt.HoldDuration or 0
                pcall(function()
                    if typeof(fireproximityprompt) == "function" then
                        fireproximityprompt(prompt)
                    else
                        prompt:InputHoldBegin()
                        task.wait(holdTime + 0.15)
                        prompt:InputHoldEnd()
                    end
                end)
                task.wait(0.6) -- Tunggu server register sesi
                print("[F&M Auto Sell] ProximityPrompt fired! (holdTime=" .. holdTime .. ")")
            end
        else
            warn("[F&M Auto Sell] NPC BasePart tidak ditemukan — menjual dari posisi saat ini")
        end
    end


    -- ============================================================
    -- STEP 3: Ambil inventory dari server via GetFishInventory
    -- ============================================================
    local inventory = getInventoryFish()

    if #inventory == 0 then
        warn("[F&M Auto Sell] GetFishInventory kembali 0 ikan. Tas kosong atau remote gagal.")
        Rayfield:Notify({
            Title = "Inventory Kosong",
            Content = "Server lapor tas kosong. Pastikan kamu punya ikan di tas!",
            Duration = 4
        })
        if hrp and teleportToSell then
            hrp.Anchored = false
            if oldCFrame then hrp.CFrame = oldCFrame end
        end
        return false, "Inventory kosong dari server"
    end

    -- ============================================================
    -- STEP 4: Kelompokkan ikan berdasarkan rarity
    -- (meniru perilaku game: tiap rarity dikirim dalam 1 panggilan)
    -- ============================================================
    local rarityGroups = {}
    local rarityOrder = {"Common", "Uncommon", "Rare", "Epic", "Legendary"}
    local rarityEnabled = {
        Common    = sellCommon,
        Uncommon  = sellUncommon,
        Rare      = sellRare,
        Epic      = sellEpic,
        Legendary = sellLegendary
    }

    for _, item in ipairs(inventory) do
        -- Ambil rarity dari data server, atau lookup dari FishConfig
        local rarity = item.Rarity or item.rarity or getFishRarity(item.FishId) or "Common"
        -- Normalize: pastikan kapital pertama saja ("common" → "Common")
        rarity = rarity:sub(1,1):upper() .. rarity:sub(2):lower()
        -- Khusus "Uncommon" (biar tidak tertangkap sebagai "Common")
        if rarity == "Common" and tostring(item.Rarity or ""):lower():find("uncommon") then
            rarity = "Uncommon"
        end

        -- FILTER KHUSUS: Lewati rarity "Monster" agar tidak ikut terjual
        if rarity:lower() == "monster" or tostring(item.Rarity or ""):lower():find("monster") then
            -- Monster dilewati (tidak masuk list jual)
        else
            if rarityEnabled[rarity] then
                if not rarityGroups[rarity] then rarityGroups[rarity] = {} end
                table.insert(rarityGroups[rarity], {
                    FishId     = item.FishId,
                    Count      = item.Count or 1,
                    InstanceId = item.InstanceId
                })
            end
        end
    end

    -- ============================================================
    -- STEP 5: Kirim SellSelectedFish per rarity group
    -- ============================================================
    local totalSold = 0
    local success = false
    local resultType = "No items match filter"

    for _, rarity in ipairs(rarityOrder) do
        local group = rarityGroups[rarity]
        if group and #group > 0 then
            print("[F&M Auto Sell] Menjual " .. #group .. " ikan " .. rarity .. "...")
            local ok, result = pcall(function()
                return sellSelectedRemote:InvokeServer(group)
            end)
            if ok then
                totalSold = totalSold + #group
                success = true
                print("[F&M Auto Sell] ✓ Berhasil jual " .. rarity .. " (" .. #group .. " ikan) | Server Response: " .. tostring(result))
            else
                warn("[F&M Auto Sell] ✗ Gagal jual " .. rarity .. ": " .. tostring(result or err))
            end
            task.wait(1.2) -- Jeda lebih lama agar server tidak mendeteksi spam/throttle
        end
    end


    if totalSold > 0 then
        resultType = "SellSelectedFish (" .. totalSold .. " ikan terjual)"
        Rayfield:Notify({
            Title = "Auto Sell Berhasil! 🎣",
            Content = totalSold .. " ikan berhasil dijual!",
            Duration = 3
        })
    else
        Rayfield:Notify({
            Title = "Tidak Ada Yang Dijual",
            Content = "Tidak ada ikan yang cocok dengan rarity yang dipilih.",
            Duration = 3
        })
    end

    -- ============================================================
    -- STEP 6: Kembalikan posisi player ke semula
    -- ============================================================
    if hrp and teleportToSell then
        hrp.Anchored = false
        if oldCFrame then
            task.wait(0.05)
            hrp.CFrame = oldCFrame
        end
    end

    return success, resultType
end


TabSell:CreateToggle({
    Name = "Auto Teleport to NPC to Sell",
    CurrentValue = true,
    Flag = "TeleportToSell",
    Callback = function(value)
        teleportToSell = value
        print("[F&M Auto Sell] Teleport to NPC: " .. tostring(value))
    end
})


TabSell:CreateToggle({
    Name = "Auto Sell by Minutes (Interval)",
    CurrentValue = false,
    Flag = "AutoSellMin",
    Callback = function(value)
        autoSellMinutes = value
        print("[F&M Auto Sell] Sell by Minutes: " .. tostring(value))
    end
})

TabSell:CreateSlider({
    Name = "Sell Interval (Minutes)",
    Range = {1, 60},
    Increment = 1,
    CurrentValue = 5,
    Flag = "SellMinVal",
    Callback = function(value)
        sellIntervalMinutes = value
    end
})

TabSell:CreateToggle({
    Name = "Auto Sell by Fish Count",
    CurrentValue = false,
    Flag = "AutoSellCount",
    Callback = function(value)
        autoSellCount = value
        print("[F&M Auto Sell] Sell by Count: " .. tostring(value))
    end
})

TabSell:CreateSlider({
    Name = "Fish Count Threshold",
    Range = {5, 100},
    Increment = 5,
    CurrentValue = 30,
    Flag = "SellCountVal",
    Callback = function(value)
        sellCountThreshold = value
    end
})

TabSell:CreateSection("Select Rarities to Sell")

TabSell:CreateToggle({
    Name = "Sell Common",
    CurrentValue = true,
    Flag = "SellCommon",
    Callback = function(value) sellCommon = value end
})

TabSell:CreateToggle({
    Name = "Sell Uncommon",
    CurrentValue = true,
    Flag = "SellUncommon",
    Callback = function(value) sellUncommon = value end
})

TabSell:CreateToggle({
    Name = "Sell Rare",
    CurrentValue = true,
    Flag = "SellRare",
    Callback = function(value) sellRare = value end
})

TabSell:CreateToggle({
    Name = "Sell Epic",
    CurrentValue = true,
    Flag = "SellEpic",
    Callback = function(value) sellEpic = value end
})

TabSell:CreateToggle({
    Name = "Sell Legendary (WARNING: Keep Disabled)",
    CurrentValue = false,
    Flag = "SellLegendary",
    Callback = function(value) sellLegendary = value end
})

TabSell:CreateSection("Manual Actions")

TabSell:CreateButton({
    Name = "Sell All Selected Now",
    Callback = function()
        local ok, info = performSell()
        if ok then
            Rayfield:Notify({Title = "Auto Sell", Content = "Sukses menjual ikan: " .. info, Duration = 4})
        else
            Rayfield:Notify({Title = "Auto Sell Error", Content = "Gagal menjual: " .. info, Duration = 4})
        end
    end
})

TabSell:CreateButton({
    Name = "Manual Scan Sell Remote",
    Callback = function()
        detectedSellRemote = nil
        performSell()
        local r = detectedSellRemote
        if r then
            Rayfield:Notify({Title = "Sell Remote Found!", Content = "Remote: " .. r.Name .. "\nPath: " .. r:GetFullName(), Duration = 5})
        else
            Rayfield:Notify({Title = "Not Found", Content = "Remote tidak ditemukan di ReplicatedStorage.", Duration = 4})
        end
    end
})

-- Auto Sell Timer & Count Background Thread
task.spawn(function()
    local lastSellTime = os.clock()
    while true do
        task.wait(1)
        
        -- 1. Jual berdasarkan interval menit
        if autoSellMinutes then
            local elapsed = os.clock() - lastSellTime
            local threshold = sellIntervalMinutes * 60
            if elapsed >= threshold then
                print("[F&M Auto Sell] Menit tercapai (" .. sellIntervalMinutes .. " menit). Menjual...")
                local ok, info = performSell()
                if ok then
                    Rayfield:Notify({Title = "Auto Sell", Content = "Sukses menjual ikan (interval menit): " .. info, Duration = 4})
                end
                lastSellTime = os.clock()
            end
        else
            lastSellTime = os.clock()
        end
        
        -- 2. Jual berdasarkan jumlah tangkapan
        if autoSellCount then
            if caughtCount >= sellCountThreshold then
                print("[F&M Auto Sell] Jumlah ikan tercapai (" .. caughtCount .. "/" .. sellCountThreshold .. "). Menjual...")
                local ok, info = performSell()
                if ok then
                    Rayfield:Notify({Title = "Auto Sell", Content = "Sukses menjual " .. caughtCount .. " ikan: " .. info, Duration = 4})
                end
                caughtCount = 0
            end
        end
    end
end)

-- Global Fish Caught Event Hook (Fail-safe untuk mendeteksi mancing manual/bypass/assist/blatant)
task.spawn(function()
    local FishCaughtRemote = nil
    local tryCount = 0
    while not FishCaughtRemote and tryCount < 30 do
        task.wait(1)
        FishCaughtRemote = findKnitRemote("FishingRewardService", "FishCaught") or findKnitRemote("FishingRewardService", "FishingSuccess")
        tryCount = tryCount + 1
    end
    if FishCaughtRemote then
        print("[F&M Auto Sell] Global Hook FishCaught aktif di " .. FishCaughtRemote:GetFullName())
        FishCaughtRemote.OnClientEvent:Connect(function(...)
            caughtCount = caughtCount + 1
            print("[F&M Auto Sell] Tangkapan baru terdeteksi! Total caughtCount: " .. caughtCount)
        end)
    else
        warn("[F&M Auto Sell] Global hook gagal: remote event FishCaught/FishingSuccess tidak ditemukan.")
    end
end)

-- Jalankan scan pertama saat load
task.spawn(performSell)
task.spawn(cacheFishConfig)

print("[F&M] Script fully initialized! Load config or customize toggles.")
Rayfield:Notify({
    Title = "Fish & Monsters!",
    Content = "Script loaded successfully! Remote Bypass is ready.",
    Duration = 5
})