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
local cachedPlayerTap = nil

-- Auto Sell States
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
local function dismissCaughtBanner()
    pcall(function()
        for _, gui in ipairs(LP.PlayerGui:GetDescendants()) do
            if gui:IsA("TextButton") or gui:IsA("ImageButton") or gui:IsA("TextLabel") then
                local text = ""
                pcall(function() text = gui.Text:lower() end)
                local name = gui.Name:lower()
                
                if text:find("continue") or text:find("tap to") or name:find("continue") or name:find("dismiss") then
                    local button = nil
                    if gui:IsA("TextButton") or gui:IsA("ImageButton") then
                        button = gui
                    elseif gui.Parent and (gui.Parent:IsA("TextButton") or gui.Parent:IsA("ImageButton")) then
                        button = gui.Parent
                    end
                    
                    if button and button.Visible then
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
        end
    end)
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
        print("[F&M Blatant] Target dari floater di workspace: " .. tostring(target))
    end
    -- Prioritas 2: Raycast ke air
    if not target then
        target = getWaterTarget(origin)
        print("[F&M Blatant] Target dari raycast: " .. tostring(target))
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

    -- FishingPullState listener — DIAGNOSIS: lihat arg apa yang dikirim server
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
    -- RequestFishBite — trigger server untuk assign ikan
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

    -- Tunggu FishingPullState dari server (max 1s) — tanda server siap untuk StartPulling
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

    -- Taps dengan delay cepat (80ms) untuk kecepatan maksimal tapi tetap aman dari rate limit
    for i = 1, 15 do
        if not autoBlatantFishing then break end
        if caughtFishName then 
            print("[F&M Blatant] Ikan terdeteksi tertangkap lebih awal di tap #" .. i .. ", menghentikan tap loop.")
            break 
        end
        local ok, res = pcall(function()
            return FishingPullInput:InvokeServer(uuid, "tap")
        end)
        task.wait(0.08) -- Dipercepat dari 0.15
    end


    print("[F&M Blatant] Taps sent. Menunggu FishCaught / FishingSuccess (max 3s)...")

    -- Tunggu max 3 detik jika ikan belum terdeteksi tertangkap
    local wt = 0
    while wt < 3 and not caughtFishName do
        task.wait(0.05); wt = wt + 0.05
    end

    disconnectAll()

    if not caughtFishName then
        print("[F&M Blatant] Tidak ada event fish catch. Fallback NurseShark.")
        caughtFishName = "NurseShark"
    else
        print("[F&M Blatant] Ikan tertangkap: " .. caughtFishName)
    end

    -- Urutan claim: RequestPreview → StopFishing → ReleasePreview x2 (dengan delay minimal 0.05s)
    if RequestPreview then
        print("[F&M Blatant] RequestPreview: " .. caughtFishName)
        pcall(function() RequestPreview:InvokeServer("FishModels", caughtFishName, nil) end)
    end
    task.wait(0.05) -- Dipercepat dari 0.15
    pcall(function() StopFishing:InvokeServer() end)
    task.wait(0.05) -- Dipercepat dari 0.15
    if ReleasePreview then
        pcall(function() ReleasePreview:InvokeServer(caughtFishName, nil) end)
        task.wait(0.02)
        pcall(function() ReleasePreview:InvokeServer(caughtFishName, nil) end)
    end

    -- Klik banner overlay 'Tap to continue' secara instan agar tidak nunggu lama
    task.spawn(function()
        for i = 1, 10 do
            dismissCaughtBanner()
            task.wait(0.05)
        end
    end)

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
local function detectBossFromEvents()
    local GetActiveEvents = findKnitRemote("BossFishEventService", "GetActiveEvents")
    if not GetActiveEvents then return nil end
    
    local ok, result = pcall(function() return GetActiveEvents:InvokeServer() end)
    if ok and type(result) == "table" then
        print("[F&M Boss Spy] GetActiveEvents returned table:")
        -- Cari string mana pun di keys atau values (tanpa batasan _SM)
        for k, v in pairs(result) do
            -- Validasi key string (bukan internal settings)
            if type(k) == "string" and k ~= "" and not (k == "status" or k == "time" or k == "active") then
                return k
            elseif type(v) == "string" and v ~= "" and not (v == "status" or v == "time" or v == "active") then
                return v
            elseif type(v) == "table" then
                for k2, v2 in pairs(v) do
                    if type(k2) == "string" and k2 ~= "" and not (k2 == "status" or k2 == "time" or k2 == "active") then
                        return k2
                    elseif type(v2) == "string" and v2 ~= "" and not (v2 == "status" or v2 == "time" or v2 == "active") then
                        return v2
                    end
                end
            end
        end
    end
    return nil
end

-- Helper: scan workspace for active boss model name (Pola _SM, Proximity Bebas Nama, & High HP)
local function findActiveBossName()
    -- 1. Coba lewat server event remote (Paling akurat)
    local bossFromRemote = detectBossFromEvents()
    if bossFromRemote then
        print("[F&M Boss] Found boss via GetActiveEvents remote: " .. bossFromRemote)
        return bossFromRemote
    end

    -- 2. Fallback A: scan workspace descendants untuk pola _SM
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") then
            if obj.Name:match("_SM$") then
                print("[F&M Boss] Found boss model ending with _SM in workspace: " .. obj.Name)
                return obj.Name
            end
        end
    end

    -- 3. Fallback B: Proximity Scan dekat RaidCircle / RaidOrb (BEBAS NAMA)
    -- Deteksi model apa pun di arena raid yang bukan player
    local raidOrb = findRaidOrb()
    if raidOrb then
        local nearestModel = nil
        local nearestDist = 200 -- Radius area raid
        
        -- Cek top-level children dulu (biasanya model boss ditaruh langsung di Workspace)
        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj:IsA("Model") and obj.Name ~= LP.Name then
                local isPlayer = Players:GetPlayerFromCharacter(obj)
                if not isPlayer then
                    local hrp = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")
                    if hrp then
                        local dist = (hrp.Position - raidOrb.Position).Magnitude
                        if dist < nearestDist then
                            nearestModel = obj.Name
                            nearestDist = dist
                        end
                    end
                end
            end
        end
        
        -- Jika tidak ketemu di top-level, cari di dalam descendants
        if not nearestModel then
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("Model") and obj.Name ~= LP.Name then
                    local isPlayer = Players:GetPlayerFromCharacter(obj)
                    if not isPlayer then
                        local hrp = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")
                        if hrp then
                            local dist = (hrp.Position - raidOrb.Position).Magnitude
                            if dist < nearestDist then
                                nearestModel = obj.Name
                                nearestDist = dist
                            end
                        end
                    end
                end
            end
        end

        if nearestModel then
            print("[F&M Boss] Found boss model via Proximity (Name-Independent): " .. nearestModel)
            return nearestModel
        end
    end

    -- 4. Fallback C: Scan model dengan HP sangat tinggi (> 100k) di workspace
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name ~= LP.Name then
            local isPlayer = Players:GetPlayerFromCharacter(obj)
            if not isPlayer then
                local hum = obj:FindFirstChildOfClass("Humanoid")
                if hum and hum.MaxHealth > 100000 then
                    print("[F&M Boss] Found boss model via High HP (>100k): " .. obj.Name)
                    return obj.Name
                end
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

            -- Verifikasi apakah boss yang lama masih ada di workspace
            if activeBossName then
                local bossModel = workspace:FindFirstChild(activeBossName, true)
                if not bossModel then
                    -- Reset nama agar men-scan ulang jika boss sudah mati atau berganti
                    local newBossName = findActiveBossName()
                    if newBossName ~= activeBossName then
                        activeBossName = newBossName
                        if newBossName then
                            print("[F&M Boss] Boss berganti / terdeteksi baru: " .. newBossName)
                        else
                            print("[F&M Boss] Boss lama telah mati/hilang. Mencari boss baru...")
                        end
                    end
                end
            else
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

-- Helper: dapatkan atau scan remote penjualan
local function performSell()
    local remote = detectedSellRemote
    if not remote then
        -- Auto-detect remote
        for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA("RemoteFunction") or obj:IsA("RemoteEvent") then
                local name = obj.Name:lower()
                if name:find("sell") or name:find("merchant") then
                    remote = obj
                    detectedSellRemote = obj
                    pcall(function() sellLabel:Set("Detected Remote: " .. obj:GetFullName()) end)
                    break
                end
            end
        end
    end
    
    if not remote then
        warn("[F&M Auto Sell] Sell/Merchant remote tidak ditemukan!")
        pcall(function() sellLabel:Set("Detected Remote: NOT FOUND!") end)
        return false, "Remote tidak ditemukan"
    end
    
    -- Siapkan list rarity yang akan dijual
    local rarities = {}
    if sellCommon then table.insert(rarities, "Common") end
    if sellUncommon then table.insert(rarities, "Uncommon") end
    if sellRare then table.insert(rarities, "Rare") end
    if sellEpic then table.insert(rarities, "Epic") end
    if sellLegendary then table.insert(rarities, "Legendary") end
    
    -- Format 1: Kirim array rarities (e.g. {"Common", "Uncommon"})
    -- Format 2: Kirim dictionary (e.g. {Common = true, Uncommon = true})
    local dictFormat = {}
    for _, r in ipairs(rarities) do
        dictFormat[r] = true
    end
    
    local success, err
    if remote:IsA("RemoteFunction") then
        success, err = pcall(function() return remote:InvokeServer(rarities) end)
        if not success then
            success, err = pcall(function() return remote:InvokeServer(dictFormat) end)
        end
        if not success then
            success, err = pcall(function() return remote:InvokeServer() end)
        end
    else -- RemoteEvent
        success, err = pcall(function() remote:FireServer(rarities) end)
        if not success then
            success, err = pcall(function() remote:FireServer(dictFormat) end)
        end
        if not success then
            success, err = pcall(function() remote:FireServer() end)
        end
    end
    
    if success then
        print("[F&M Auto Sell] Sukses memanggil remote: " .. remote:GetFullName())
        return true, remote.Name
    else
        warn("[F&M Auto Sell] Gagal memanggil remote: " .. tostring(err))
        return false, tostring(err)
    end
end

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
            Rayfield:Notify({Title = "Auto Sell", Content = "Sukses menjual ikan terpilih lewat " .. info, Duration = 4})
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
                    Rayfield:Notify({Title = "Auto Sell", Content = "Sukses menjual ikan (interval menit) lewat " .. info, Duration = 4})
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
                    Rayfield:Notify({Title = "Auto Sell", Content = "Sukses menjual " .. caughtCount .. " ikan lewat " .. info, Duration = 4})
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

print("[F&M] Script fully initialized! Load config or customize toggles.")
Rayfield:Notify({
    Title = "Fish & Monsters!",
    Content = "Script loaded successfully! Remote Bypass is ready.",
    Duration = 5
})

