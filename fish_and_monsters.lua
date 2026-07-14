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
local autoBlatantFishing = false
local autoCatchAssist = false
local rodNameInput = "Fishingrod_Losi"
local floaterNameInput = "Floater_Doll"

local autoJoinRaid = false
local autoTapBoss = false
local bossTapDelay = 0.01
local activeBossName = nil

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
            autoFishingRemote = false
            print("[F&M Blatant] ENABLED - Mode blatant aktif, bypass dimatikan otomatis.")
            Rayfield:Notify({Title = "Blatant Mode ON", Content = "Spam fishing max speed aktif!", Duration = 3})
        end
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
-- AUTO FISHING REMOTE BYPASS (Stabil/Original)
----------------------------------------------------
local function runRemoteFishingCycle()
    local ThrowFloater        = findKnitRemote("FishingReplicationService", "ThrowFloater")
    local ConfirmFloatingCast = findKnitRemote("FishingReplicationService", "ConfirmFloatingCast")
    local RequestFishBite     = findKnitRemote("FishingRewardService",      "RequestFishBite")
    local StartPulling        = findKnitRemote("FishingReplicationService", "StartPulling")
    local StopFishing         = findKnitRemote("FishingReplicationService", "StopFishing")
    local FishingPullInput    = findKnitRemote("FishingRewardService",      "FishingPullInput")

    if not (ThrowFloater and ConfirmFloatingCast and RequestFishBite and StartPulling and StopFishing and FishingPullInput) then
        warn("[F&M Bypass] Missing remotes!") return
    end

    equipRod()
    task.wait(0.3)
    if not autoFishingRemote then return end

    pcall(function() StopFishing:InvokeServer() end)
    task.wait(0.3)

    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Deteksi dinamis nama joran (contoh: DryardRod)
    local rod = getRod()
    local activeRodName = rod and rod.Name or rodNameInput
    
    -- Deteksi dinamis nama floater dari attribute
    local activeFloaterName = floaterNameInput
    for k, v in pairs(LP:GetAttributes()) do
        if type(v) == "string" and (k:lower():find("floater") or v:lower():find("floater")) and v ~= "" then
            activeFloaterName = v
            break
        end
    end

    local origin = hrp.Position
    local target = getWaterTarget(origin)
    local floatConfig = {LightInfluence=0, FaceCamera=true, Color=Color3.new(0.94,0.31,1), Transparency=0.02, LightEmission=1, Width=0.24}

    -- 1. ThrowFloater
    pcall(function() ThrowFloater:InvokeServer(origin, target, activeRodName, activeFloaterName, floatConfig, 2.5) end)
    task.wait(1.5)
    if not autoFishingRemote then return end

    -- 2. ConfirmFloatingCast
    pcall(function() ConfirmFloatingCast:InvokeServer(target) end)

    -- 3. Tunggu bite (natural delay)
    task.wait(math.random(2, 3))
    if not autoFishingRemote then return end

    -- 4. RequestFishBite — ambil SessionId dari response
    local uuid = nil
    local biteOk, biteData = pcall(function()
        return RequestFishBite:InvokeServer(target + Vector3.new(0, 0.1, 0))
    end)
    if biteOk and type(biteData) == "table" then
        uuid = biteData.SessionId or biteData.sessionId or biteData.castId or extractUUID(biteData)
    end
    if not uuid then uuid = LP:GetAttribute("FishingCastId") end
    if not uuid then warn("[F&M Bypass] UUID nil, skip.") return end

    print("[F&M Bypass] UUID: " .. tostring(uuid))

    -- 5. StartPulling
    pcall(function() StartPulling:InvokeServer() end)
    task.wait(0.1)

    -- 6. Tap sequential (stabil, tidak spam berlebihan)
    for i = 1, 15 do
        if not autoFishingRemote then break end
        pcall(function() FishingPullInput:InvokeServer(uuid, "tap") end)
        task.wait(0.05)
    end

    task.wait(0.3)
    pcall(function() StopFishing:InvokeServer() end)
    print("[F&M Bypass] Cycle done.")
end

-- Remote Bypass Loop (delay wajar)
task.spawn(function()
    while true do
        task.wait(1)
        if autoFishingRemote then
            local ok, err = pcall(runRemoteFishingCycle)
            if not ok then
                warn("[F&M Bypass Error]: " .. tostring(err))
                task.wait(2)
            end
        end
    end
end)

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
    local RequestPreview      = findKnitRemote("AssetPreviewService",       "RequestPreview")
    local ReleasePreview      = findKnitRemote("AssetPreviewService",       "ReleasePreview")

    if not (ThrowFloater and ConfirmFloatingCast and StartPulling and StopFishing and FishingPullInput) then
        warn("[F&M Blatant] Missing remotes!") return
    end

    equipRod()
    -- Deteksi joran (contoh: DryardRod)
    local rod = getRod()
    local activeRodName = rod and rod.Name or rodNameInput
    
    -- Deteksi floater
    local activeFloaterName = floaterNameInput
    for k, v in pairs(LP:GetAttributes()) do
        if type(v) == "string" and (k:lower():find("floater") or v:lower():find("floater")) and v ~= "" then
            activeFloaterName = v
            break
        end
    end

    -- Reset state
    pcall(function() StopFishing:InvokeServer() end)
    task.wait(0.1)

    -- StartFishing (sesuai urutan Cobalt log)
    if StartFishing then
        pcall(function() StartFishing:InvokeServer(activeRodName, activeFloaterName) end)
    end

    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local origin = hrp.Position
    local target = getWaterTarget(origin)
    local floatConfig = {LightInfluence=0, FaceCamera=true, Color=Color3.new(0.94,0.31,1), Transparency=0.02, LightEmission=1, Width=0.24}

    -- Catat UUID sebelum lempar (untuk deteksi perubahan)
    local oldCastId = LP:GetAttribute("FishingCastId") or ""

    -- ThrowFloater
    pcall(function() ThrowFloater:InvokeServer(origin, target, activeRodName, activeFloaterName, floatConfig, 2.5) end)
    task.wait(0.3)
    if not autoBlatantFishing then return end

    -- ConfirmFloatingCast
    pcall(function() ConfirmFloatingCast:InvokeServer(target) end)

    -- Tunggu server assign FishingCastId baru (max 6 detik)
    -- Ini tanda server sudah siap, ikan sudah gigit pelampung
    local uuid = nil
    local waited = 0
    while waited < 6 do
        if not autoBlatantFishing then return end
        local castId = LP:GetAttribute("FishingCastId")
        if castId and castId ~= "" and castId ~= oldCastId then
            uuid = castId
            break
        end
        task.wait(0.1)
        waited = waited + 0.1
    end

    if not uuid then
        -- Timeout: tidak ada bite dalam 6 detik, reset dan coba lagi
        pcall(function() StopFishing:InvokeServer() end)
        return
    end

    print("[F&M Blatant] Bite! UUID: " .. tostring(uuid))

    -- StartPulling
    pcall(function() StartPulling:InvokeServer() end)
    task.wait(0.05)

    -- "begin" dulu (sesuai log Cobalt)
    pcall(function() FishingPullInput:InvokeServer(uuid, "begin") end)
    task.wait(0.05)

    -- Spam 12 "tap" inputs sequentially dengan jeda 15ms dan tangkap hasil return terakhir
    local lastResult = nil
    for i = 1, 12 do
        if not autoBlatantFishing then break end
        local ok, res = pcall(function() return FishingPullInput:InvokeServer(uuid, "tap") end)
        if ok and res then
            lastResult = res
        end
        task.wait(0.015)
    end

    print("[F&M Blatant] Finished sending taps. Checking response...")
    if lastResult then
        print("[F&M Blatant] FishingPullInput return value:")
        dumpTable(lastResult)
    end
    
    task.wait(0.2)

    -- Ambil nama ikan dari response remote tap jika ada
    local caughtFish = extractFishName(lastResult)

    -- Jika tidak ketemu di remote return, scan attribute (dengan proteksi rod/floater)
    if not caughtFish then
        for k, v in pairs(LP:GetAttributes()) do
            if type(v) == "string" and v ~= "" then
                local kl = k:lower()
                -- Cari kata 'fish' tapi ignore 'fishingfloater', 'fishingrod', dll
                if kl:find("fish") and not (kl:find("rod") or kl:find("floater") or kl:find("equip") or kl:find("tool")) then
                    caughtFish = v
                    break
                end
            end
        end
    end
    if not caughtFish and char then
        for k, v in pairs(char:GetAttributes()) do
            if type(v) == "string" and v ~= "" then
                local kl = k:lower()
                if kl:find("fish") and not (kl:find("rod") or kl:find("floater") or kl:find("equip") or kl:find("tool")) then
                    caughtFish = v
                    break
                end
            end
        end
    end

    -- Debug print all attributes jika masih belum terdeteksi (membantu trace nama key aslinya)
    if not caughtFish then
        print("[F&M Blatant Debug] Scan attribute failed. Printing all LP attributes:")
        for k, v in pairs(LP:GetAttributes()) do
            print("   " .. k .. " = " .. tostring(v) .. " (" .. typeof(v) .. ")")
        end
    end

    -- Fallback nama ikan default jika tidak terdeteksi (agar remote preview tetap berjalan)
    caughtFish = caughtFish or "NurseShark" 

    -- Kirim RequestPreview dan ReleasePreview untuk claim & hilangkan UI
    if RequestPreview then
        print("[F&M Blatant] Sending RequestPreview for: " .. tostring(caughtFish))
        pcall(function() RequestPreview:InvokeServer("FishModels", caughtFish, nil) end)
    end
    task.wait(0.15)
    if ReleasePreview then
        print("[F&M Blatant] Sending ReleasePreview for: " .. tostring(caughtFish))
        pcall(function() ReleasePreview:InvokeServer(caughtFish, nil) end)
    end

    task.wait(0.5)
    pcall(function() StopFishing:InvokeServer() end)
    print("[F&M Blatant] Cycle completed!")
end

-- Blatant Fishing Loop Thread
task.spawn(function()
    while true do
        task.wait(0.5)
        if autoBlatantFishing then
            local ok, err = pcall(runBlatantFishingCycle)
            if not ok then
                warn("[F&M Blatant Error]: " .. tostring(err))
                task.wait(1)
            end
        end
    end
end)

-- Auto Catch Assist Loop Thread
-- Dipakai dengan AFK mode game — jangan jalankan bersama Blatant Mode!
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
                    -- "begin" dulu (sesuai urutan game asli)
                    pcall(function() cachedAssistPullInput:InvokeServer(castId, "begin") end)
                    task.wait(0.05)
                    
                    -- Spam 12 "tap" input secara sekuensial dengan delay 15ms
                    for i = 1, 12 do
                        if not autoCatchAssist then break end
                        pcall(function() cachedAssistPullInput:InvokeServer(castId, "tap") end)
                        task.wait(0.015)
                    end
                    print("[F&M Assist] Taps sent!")
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

-- Helper: dapatkan nama boss aktif dari server event (Paling Akurat!)
local function detectBossFromEvents()
    local GetActiveEvents = findKnitRemote("BossFishEventService", "GetActiveEvents")
    if not GetActiveEvents then return nil end
    
    local ok, result = pcall(function() return GetActiveEvents:InvokeServer() end)
    if ok and type(result) == "table" then
        print("[F&M Boss Spy] GetActiveEvents returned table:")
        -- Cari string yang diakhiri _SM di keys atau values
        for k, v in pairs(result) do
            if type(k) == "string" and k:match("_SM$") then
                return k
            elseif type(v) == "string" and v:match("_SM$") then
                return v
            elseif type(v) == "table" then
                for k2, v2 in pairs(v) do
                    if type(k2) == "string" and k2:match("_SM$") then
                        return k2
                    elseif type(v2) == "string" and v2:match("_SM$") then
                        return v2
                    end
                end
            end
        end
    end
    return nil
end

-- Helper: scan workspace for active boss model name (pola _SM)
local function findActiveBossName()
    -- 1. Coba lewat server event remote
    local bossFromRemote = detectBossFromEvents()
    if bossFromRemote then
        print("[F&M Boss] Found boss via GetActiveEvents remote: " .. bossFromRemote)
        return bossFromRemote
    end

    -- 2. Fallback: scan workspace descendants
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") then
            -- Nama boss biasanya diakhiri _SM (contoh: Windah_SM, Losi_SM, dll)
            if obj.Name:match("_SM$") then
                print("[F&M Boss] Found boss model in workspace: " .. obj.Name)
                return obj.Name
            end
        end
    end
    return nil
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

TabRaid:CreateToggle({
    Name = "Auto Teleport to Raid Orb (Loop)",
    CurrentValue = false,
    Flag = "AutoJoinRaid",
    Callback = function(value)
        autoJoinRaid = value
    end
})

TabRaid:CreateSection("Boss Tap Spammer")

TabRaid:CreateButton({
    Name = "Scan Active Boss Name",
    Callback = function()
        local found = findActiveBossName()
        if found then
            activeBossName = found
            print("[F&M Boss] Boss ditemukan: " .. found)
            Rayfield:Notify({Title = "Boss Found!", Content = "Boss aktif: " .. found, Duration = 5})
        else
            print("[F&M Boss] Tidak ada boss aktif ditemukan di Workspace.")
            Rayfield:Notify({Title = "Boss Not Found", Content = "Tidak ada boss _SM di workspace. Coba input manual.", Duration = 5})
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

        -- Scan semua model di workspace (10 level)
        print("--- Scanning Workspace Models (pola _SM / Boss / Monster) ---")
        local count = 0
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") then
                local n = obj.Name
                if n:find("_SM") or n:lower():find("boss") or n:lower():find("monster") or n:lower():find("fish") then
                    print("  Found: " .. n .. " (" .. obj:GetFullName() .. ")")
                    count = count + 1
                    if count >= 20 then print("  [... truncated]") break end
                end
            end
        end
        if count == 0 then print("  (tidak ada model relevan ditemukan)") end

        -- Scan BossFishEventService langsung
        print("--- Scanning BossFishEventService RF folder ---")
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
                            else
                                print("  BossFishEventService NOT FOUND in " .. child.Name)
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
    PlaceholderText = "Contoh: Windah_SM",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        if Text and Text ~= "" then
            activeBossName = Text
            print("[F&M Boss] Boss name di-set manual: " .. Text)
            Rayfield:Notify({Title = "Boss Name Set", Content = "Boss: " .. Text, Duration = 3})
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
            local found = findActiveBossName()
            if found then
                activeBossName = found
                print("[F&M Boss] Auto-detected boss: " .. found)
                Rayfield:Notify({Title = "Boss Detected", Content = "Boss: " .. found, Duration = 3})
            elseif not activeBossName then
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

-- Auto Tap Boss Loop (dengan cache remote + debug verbose)
local cachedPlayerTap = nil
task.spawn(function()
    while true do
        task.wait(bossTapDelay)
        if autoTapBoss then
            -- Cache PlayerTap sekali saja
            if not cachedPlayerTap then
                cachedPlayerTap = findKnitRemote("BossFishEventService", "PlayerTap")
                if cachedPlayerTap then
                    print("[F&M Boss] PlayerTap remote FOUND: " .. cachedPlayerTap:GetFullName())
                else
                    warn("[F&M Boss] PlayerTap remote NIL - BossFishEventService tidak ditemukan!")
                end
            end

            -- Auto-detect boss name setiap loop jika belum ada
            if not activeBossName then
                activeBossName = findActiveBossName()
                if activeBossName then
                    print("[F&M Boss] Auto-detected boss name: " .. activeBossName)
                end
            end

            if cachedPlayerTap and activeBossName then
                -- Kirim 12 tap sekuensial dengan jeda 15ms untuk mencegah proteksi spam server
                for i = 1, 12 do
                    if not autoTapBoss then break end
                    task.spawn(function()
                        pcall(function()
                            cachedPlayerTap:InvokeServer(activeBossName)
                        end)
                    end)
                    task.wait(0.015)
                end
            elseif not cachedPlayerTap then
                cachedPlayerTap = nil
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

-- Metatable Hooking for Remote Spy (Dengan deep table serialization)
local hookSuccess, err = pcall(function()
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
