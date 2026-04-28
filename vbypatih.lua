local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

local Window = Rayfield:CreateWindow({
    Name = "Ride Braintrot For Brainrots! - Auto",
    LoadingTitle = "Ride Braintrot For Brainrots!",
    LoadingSubtitle = "by patihrz",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "RB4B_Auto",
        FileName = "rb4b_config",
    },
    KeySystem = false,
})

local TabMain = Window:CreateTab("Main")
local TabDebug = Window:CreateTab("Debug")

local cfg = {
    autoEnabled = false,
    autoDetectTiming = true,
    waitingDuration = 30,
    waitingTouchDuration = 1.2,
    roundDuration = 20,
    roundPickupStart = 15,
    floodDuration = 45,
    lobbyDuration = 9,
    postPickupDelay = 4,
    pickupTarget = 3,

    waitingNames = {
        "WaitingForPlayers",
        "Waiting For Players",
        "Waiting",
        "WaitingZone",
        "AFK Zone",
        "AFK",
        "Queue",
        "QueuePad",
        "Ready",
        "ReadyZone",
        "ReadyPad",
    },

    fuseNames = {
        "FuseMachine",
        "Fuse Machine",
        "Fuse",
        "FuseBox",
        "Fuse Box",
    },

    brainrotContainerNames = {
        "Brainrots",
        "SpawnedBrainrots",
        "Drops",
        "Pickups",
    },

    mythicalTokens = {
        "mythic",
        "mythical",
        "legendary+",
        "godly",
    },

    pickupRemoteCandidates = {
        "PickBrainrot",
        "PickupBrainrot",
        "CollectBrainrot",
        "TakeBrainrot",
    },
}

local state = {
    thread = nil,
    step = "IDLE",
    pickupCount = 0,
    lastDetectedPhase = "NONE",
    lastDetectedPhaseText = "",
}

local function now()
    return os.clock()
end

local function alive(inst)
    if not inst then return false end
    local ok = pcall(function() return inst.Parent end)
    return ok and inst.Parent ~= nil
end

local function getHRP()
    local ch = LP.Character
    if not ch then return nil end
    return ch:FindFirstChild("HumanoidRootPart")
end

local function dist(a, b)
    return (a - b).Magnitude
end

local function safeNotify(title, content, duration)
    pcall(function()
        Rayfield:Notify({
            Title = title,
            Content = content,
            Duration = duration or 3,
        })
    end)
end

local function containsAnyToken(text, tokens)
    local s = string.lower(tostring(text or ""))
    for _, token in ipairs(tokens) do
        if string.find(s, string.lower(token), 1, true) then
            return true
        end
    end
    return false
end

local function readTextLikeValue(inst)
    if not inst then return nil end

    local className = inst.ClassName
    if className == "StringValue" then
        local ok, value = pcall(function()
            return inst.Value
        end)
        if ok and value ~= nil and tostring(value) ~= "" then
            return tostring(value)
        end
    elseif className == "TextLabel" or className == "TextButton" or className == "TextBox" then
        local ok, value = pcall(function()
            return inst.Text
        end)
        if ok and value ~= nil and tostring(value) ~= "" then
            return tostring(value)
        end
    elseif className == "IntValue" or className == "NumberValue" then
        local ok, value = pcall(function()
            return inst.Value
        end)
        if ok and value ~= nil then
            return tostring(value)
        end
    end

    local okName, instName = pcall(function()
        return inst.Name
    end)
    if okName and instName and instName ~= "" then
        return tostring(instName)
    end

    return nil
end

local function detectPhaseState()
    local phaseMap = {
        WAITING = { "waiting for players", "waiting", "ready", "afk zone", "queue" },
        ROUND = { "round in progress", "round", "prepare", "preparing" },
        FLOOD = { "flood is coming", "flood", "incoming flood" },
        LOBBY = { "escape to lobby", "lobby", "back to lobby" },
    }

    for _, d in ipairs(Workspace:GetDescendants()) do
        local text = readTextLikeValue(d)
        if text then
            local lowerText = string.lower(text)
            for phaseName, tokens in pairs(phaseMap) do
                for _, token in ipairs(tokens) do
                    if string.find(lowerText, token, 1, true) then
                        return phaseName, text
                    end
                end
            end
        end
    end

    local playerGui = LP:FindFirstChildOfClass("PlayerGui")
    if playerGui then
        for _, d in ipairs(playerGui:GetDescendants()) do
            local text = readTextLikeValue(d)
            if text then
                local lowerText = string.lower(text)
                for phaseName, tokens in pairs(phaseMap) do
                    for _, token in ipairs(tokens) do
                        if string.find(lowerText, token, 1, true) then
                            return phaseName, text
                        end
                    end
                end
            end
        end
    end

    return nil, nil
end

local function updatePhaseDebug(phaseName, phaseText)
    local phaseLabel = phaseName or "NONE"
    local phaseValue = phaseText or ""

    if state.lastDetectedPhase ~= phaseLabel or state.lastDetectedPhaseText ~= phaseValue then
        state.lastDetectedPhase = phaseLabel
        state.lastDetectedPhaseText = phaseValue

        if phaseLabel ~= "NONE" then
            safeNotify("Phase Debug", phaseLabel .. (phaseValue ~= "" and (" | " .. phaseValue) or ""), 2)
        end
    end
end

local function isNameCandidate(inst, names)
    if not inst then return false end
    local n = string.lower(inst.Name)
    for _, v in ipairs(names) do
        if n == string.lower(v) then
            return true
        end
    end
    return false
end

local function getPartFrom(inst)
    if not inst or not alive(inst) then return nil end
    if inst:IsA("BasePart") then return inst end
    if inst:IsA("Model") then
        if inst.PrimaryPart then return inst.PrimaryPart end
        return inst:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

local function teleportTo(part, forwardDistance, upDistance)
    local hrp = getHRP()
    if not hrp or not part then return false end
    local ok = pcall(function()
        local offset = Vector3.new(0, upDistance or 3, -(forwardDistance or 8))
        hrp.CFrame = part.CFrame * CFrame.new(offset)
    end)
    return ok
end

local function findNearestByNames(names)
    local hrp = getHRP()
    if not hrp then return nil end

    local bestPart = nil
    local bestDist = 1e9

    for _, d in ipairs(Workspace:GetDescendants()) do
        if isNameCandidate(d, names) then
            local p = getPartFrom(d)
            if p then
                local dd = dist(hrp.Position, p.Position)
                if dd < bestDist then
                    bestDist = dd
                    bestPart = p
                end
            end
        end
    end

    return bestPart, bestDist
end

local function findReadyPointNearFuse()
    local waitingPart = findNearestByNames(cfg.waitingNames)
    if waitingPart then
        return waitingPart, "WAITING"
    end

    local fusePart = findNearestByNames(cfg.fuseNames)
    if fusePart then
        return fusePart, "FUSE_FALLBACK"
    end

    return nil, "NONE"
end

local function isMythicalBrainrot(inst)
    if not inst then return false end

    if containsAnyToken(inst.Name, cfg.mythicalTokens) then
        return true
    end

    local attrs = { "Rarity", "Tier", "Type", "Grade" }
    for _, attr in ipairs(attrs) do
        local ok, value = pcall(function() return inst:GetAttribute(attr) end)
        if ok and value ~= nil and containsAnyToken(value, cfg.mythicalTokens) then
            return true
        end
    end

    local rarityTag = inst:FindFirstChild("Rarity") or inst:FindFirstChild("Tier")
    if rarityTag and rarityTag:IsA("StringValue") then
        if containsAnyToken(rarityTag.Value, cfg.mythicalTokens) then
            return true
        end
    end

    return false
end

local function isInsideKnownContainer(inst)
    for _, containerName in ipairs(cfg.brainrotContainerNames) do
        local node = inst:FindFirstAncestor(containerName)
        if node then return true end
    end
    return false
end

local function getCarriedBrainrotCount()
    local backpack = LP:FindFirstChild("Backpack")
    if not backpack then return 0 end
    
    local count = 0
    for _, item in ipairs(backpack:GetChildren()) do
        if string.find(string.lower(item.Name), "brainrot", 1, true) then
            count = count + 1
        end
    end
    return count
end

local function findNearestMythicalBrainrot()
    local hrp = getHRP()
    if not hrp then return nil end

    local bestPart = nil
    local bestInst = nil
    local bestDist = 1e9

    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("Model") or d:IsA("BasePart") then
            if isInsideKnownContainer(d) and isMythicalBrainrot(d) then
                local p = getPartFrom(d)
                if p then
                    local dd = dist(hrp.Position, p.Position)
                    if dd < bestDist then
                        bestDist = dd
                        bestPart = p
                        bestInst = d
                    end
                end
            end
        end
    end

    return bestInst, bestPart, bestDist
end

local function findPickupRemote()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local root = remotes or ReplicatedStorage

    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("RemoteEvent") and isNameCandidate(d, cfg.pickupRemoteCandidates) then
            return d
        end
    end

    return nil
end

local function pickupBrainrot(target)
    if not target then return false end

    local prompt = target:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt then
        local promptPart = prompt.Parent and getPartFrom(prompt.Parent)
        if promptPart then
            teleportTo(promptPart)
            task.wait(0.08)
        end

        local fired = pcall(function()
            fireproximityprompt(prompt)
        end)
        if fired then return true end

        local firedWithHold = pcall(function()
            fireproximityprompt(prompt, prompt.HoldDuration or 0)
        end)
        if firedWithHold then return true end

        local inputHold = pcall(function()
            prompt:InputHoldBegin()
            task.wait((prompt.HoldDuration or 0) + 0.05)
            prompt:InputHoldEnd()
        end)
        if inputHold then return true end
    end

    local remote = findPickupRemote()
    if remote then
        local ok = pcall(function()
            remote:FireServer(target)
        end)
        if ok then return true end
    end

    local click = target:FindFirstChildWhichIsA("ClickDetector", true)
    if click then
        local ok = pcall(function()
            fireclickdetector(click)
        end)
        if ok then return true end
    end

    return false
end

local function waitPhase(seconds, phaseName)
    local t0 = now()
    while cfg.autoEnabled and (now() - t0) < seconds do
        local left = math.max(0, math.ceil(seconds - (now() - t0)))
        state.step = phaseName .. " (" .. tostring(left) .. "s)"
        task.wait(0.25)
    end
    return cfg.autoEnabled
end

local function waitForPhase(targetPhase, fallbackSeconds, phaseName)
    if not cfg.autoDetectTiming then
        return waitPhase(fallbackSeconds, phaseName)
    end

    local t0 = now()
    local seenTarget = false

    while cfg.autoEnabled and (now() - t0) < fallbackSeconds do
        local detectedPhase, detectedText = detectPhaseState()
        if detectedPhase == targetPhase then
            seenTarget = true
            updatePhaseDebug(detectedPhase, detectedText)
            state.step = phaseName .. " [AUTO]"
            task.wait(0.25)
            return true
        end

        if seenTarget and detectedPhase ~= targetPhase then
            updatePhaseDebug(detectedPhase or "NONE", detectedText)
            return true
        end

        local left = math.max(0, math.ceil(fallbackSeconds - (now() - t0)))
        if detectedText then
            updatePhaseDebug(detectedPhase or "NONE", detectedText)
            state.step = phaseName .. " [" .. tostring(detectedText) .. "] (" .. tostring(left) .. "s)"
        else
            state.step = phaseName .. " (" .. tostring(left) .. "s)"
        end

        task.wait(0.25)
    end

    return cfg.autoEnabled
end

local function doLobbyEscapePhase()
    local t0 = now()
    while cfg.autoEnabled and (now() - t0) < cfg.lobbyDuration do
        local left = math.max(0, math.ceil(cfg.lobbyDuration - (now() - t0)))
        state.step = "ESCAPE TO LOBBY (" .. tostring(left) .. "s)"

        if cfg.autoDetectTiming then
            local detectedPhase = detectPhaseState()
            if detectedPhase == "WAITING" then
                state.step = "WAITING FOR PLAYERS [AUTO]"
                return true
            end
        end

        local lobbyPart = findNearestByNames({
            "Lobby",
            "LobbySpawn",
            "Spawn",
            "SpawnLocation",
            "MainLobby",
        })
        if lobbyPart then
            teleportTo(lobbyPart)
        end

        task.wait(0.25)
    end
    return cfg.autoEnabled
end

local function doTimedPickCycle(cycleDuration, phaseLabel)
    local t0 = now()
    local picked = false
    local shouldFuse = false

    while cfg.autoEnabled and (now() - t0) < cycleDuration do
        if state.pickupCount >= cfg.pickupTarget then
            shouldFuse = true
            break
        end
        
        local left = math.max(0, math.ceil(cycleDuration - (now() - t0)))
        state.step = phaseLabel .. " (" .. tostring(left) .. "s) [" .. state.pickupCount .. "/" .. cfg.pickupTarget .. "]"

        local carriedCount = getCarriedBrainrotCount()
        if carriedCount >= 3 then
            safeNotify("Inventory", "Sudah carry 3 brainrot, harus ke Fuse", 2)
            shouldFuse = true
            break
        end

        local mythic, mythicPart = findNearestMythicalBrainrot()
        if mythic and mythicPart then
            -- Teleport close to mythical, not directly on it
            teleportTo(mythicPart)
            task.wait(0.15)
            
            -- Try pickup with retry
            local pickupSuccess = pickupBrainrot(mythic)
            if pickupSuccess then
                state.pickupCount = state.pickupCount + 1
                picked = true
                safeNotify("Step", "Mythical diambil (" .. state.pickupCount .. "/" .. cfg.pickupTarget .. ")", 2)

                task.wait(0.2)
                local carriedAfterPickup = getCarriedBrainrotCount()
                if carriedAfterPickup >= 3 or state.pickupCount >= cfg.pickupTarget then
                    shouldFuse = true
                    break
                end
            else
                safeNotify("Step", "Pickup gagal (brainrot hilang?)", 2)
            end

            task.wait(0.1)
        end

        task.wait(0.3)
    end

    if picked and (shouldFuse or getCarriedBrainrotCount() > 0) then
        local fusePart = findNearestByNames(cfg.fuseNames)
        if fusePart then
            teleportTo(fusePart)
            safeNotify("Step", "Ke Fuse Machine", 2)
        end
    end

    if picked and cfg.postPickupDelay > 0 then
        waitPhase(cfg.postPickupDelay, "POST PICKUP")
    end

    return picked
end

local function runLoop()
    state.pickupCount = 0
    safeNotify("Auto", "Loop started (target: " .. cfg.pickupTarget .. ")", 2)

    while cfg.autoEnabled do
        if state.pickupCount >= cfg.pickupTarget then
            safeNotify("Auto", "Target pickup count reached! (" .. state.pickupCount .. "/" .. cfg.pickupTarget .. ")", 3)
            break
        end

        state.step = "TO_WAITING"
        local waitingPart, source = findReadyPointNearFuse()
        if waitingPart then
            if source == "WAITING" then
                -- Must touch waiting floor first so player is registered in queue.
                teleportTo(waitingPart, 0, 5)
                task.wait(cfg.waitingTouchDuration)
            else
                teleportTo(waitingPart, 18, 5)
            end
            if source == "WAITING" then
                safeNotify("Step", "Injak lantai Waiting (join queue)", 2)
            else
                safeNotify("Step", "Waiting tidak ketemu, fallback ke Fuse", 2)
            end
        else
            safeNotify("Step", "Waiting/Fuse tidak ditemukan", 2)
        end

        if not waitForPhase("WAITING", cfg.waitingDuration, "WAITING FOR PLAYERS") then break end

        local roundPickupStart = math.max(0, math.min(cfg.roundPickupStart, cfg.roundDuration))
        if cfg.autoDetectTiming then
            if not waitForPhase("ROUND", 3, "ROUND IN PROGRESS") then break end
            roundPickupStart = 0
        elseif roundPickupStart > 0 then
            if not waitForPhase("ROUND", roundPickupStart, "ROUND IN PROGRESS") then break end
        end

        local roundWindow = math.max(0, cfg.roundDuration - roundPickupStart)
        if roundWindow > 0 then
            local pickedInRound = doTimedPickCycle(roundWindow, "ROUND IN PROGRESS")
            if not pickedInRound then
                if cfg.autoDetectTiming then
                    local fusePart = findNearestByNames(cfg.fuseNames)
                    if fusePart then
                        teleportTo(fusePart)
                        safeNotify("Step", "Mythic tidak ada, langsung ke Fuse", 2)
                    end
                else
                    local readyPart = findNearestByNames(cfg.waitingNames)
                    if readyPart then
                        teleportTo(readyPart, 0, 5)
                        safeNotify("Step", "Mythic tidak ada di round, balik ke AFK", 2)
                    end
                end
            end
        end

        if not waitForPhase("FLOOD", 3, "FLOOD IS COMING") then break end
        doTimedPickCycle(cfg.floodDuration, "FLOOD IS COMING")

        if not doLobbyEscapePhase() then break end

        if not cfg.autoEnabled then break end
    end

    state.step = "IDLE"
    state.thread = nil
    safeNotify("Auto", "Loop stopped", 2)
end

TabMain:CreateSection("Automation")
TabMain:CreateToggle({
    Name = "Auto Waiting -> Flood Pick -> Fuse",
    CurrentValue = false,
    Flag = "AutoMain",
    Callback = function(v)
        cfg.autoEnabled = v
        if v and not state.thread then
            state.thread = task.spawn(runLoop)
        end
    end,
})

TabMain:CreateToggle({
    Name = "Auto Detect Timing",
    CurrentValue = cfg.autoDetectTiming,
    Flag = "AutoDetectTiming",
    Callback = function(v)
        cfg.autoDetectTiming = v
    end,
})

TabMain:CreateSlider({
    Name = "Waiting For Players (sec)",
    Range = {5, 120},
    Increment = 1,
    CurrentValue = cfg.waitingDuration,
    Flag = "WaitingDuration",
    Callback = function(v)
        cfg.waitingDuration = v
    end,
})

TabMain:CreateSlider({
    Name = "Touch Waiting Floor (sec)",
    Range = {0, 5},
    Increment = 0.1,
    CurrentValue = cfg.waitingTouchDuration,
    Flag = "WaitingTouchDuration",
    Callback = function(v)
        cfg.waitingTouchDuration = v
    end,
})

TabMain:CreateSlider({
    Name = "Round In Progress (sec)",
    Range = {5, 120},
    Increment = 1,
    CurrentValue = cfg.roundDuration,
    Flag = "RoundDuration",
    Callback = function(v)
        cfg.roundDuration = v
    end,
})

TabMain:CreateSlider({
    Name = "Round Spawn Start (sec)",
    Range = {0, 60},
    Increment = 1,
    CurrentValue = cfg.roundPickupStart,
    Flag = "RoundPickupStart",
    Callback = function(v)
        cfg.roundPickupStart = v
    end,
})

TabMain:CreateSlider({
    Name = "Flood Is Coming (sec)",
    Range = {5, 120},
    Increment = 1,
    CurrentValue = cfg.floodDuration,
    Flag = "FloodDuration",
    Callback = function(v)
        cfg.floodDuration = v
    end,
})

TabMain:CreateSlider({
    Name = "Escape to Lobby (sec)",
    Range = {8, 10},
    Increment = 1,
    CurrentValue = cfg.lobbyDuration,
    Flag = "LobbyDuration",
    Callback = function(v)
        cfg.lobbyDuration = v
    end,
})

TabMain:CreateSlider({
    Name = "Delay Setelah Pickup (sec)",
    Range = {0, 15},
    Increment = 1,
    CurrentValue = cfg.postPickupDelay,
    Flag = "PostPickupDelay",
    Callback = function(v)
        cfg.postPickupDelay = v
    end,
})

TabMain:CreateSlider({
    Name = "Target Brainrot Count",
    Range = {1, 5},
    Increment = 1,
    CurrentValue = cfg.pickupTarget,
    Flag = "PickupTarget",
    Callback = function(v)
        cfg.pickupTarget = v
    end,
})

TabDebug:CreateSection("Scanner")
TabDebug:CreateButton({
    Name = "Scan Waiting & Fuse",
    Callback = function()
        local wp, wd = findNearestByNames(cfg.waitingNames)
        local fp, fd = findNearestByNames(cfg.fuseNames)
        local msg = "Waiting: " .. (wp and (math.floor(wd) .. "m") or "not found") .. " | Fuse: " .. (fp and (math.floor(fd) .. "m") or "not found")
        safeNotify("Scan", msg, 5)
    end,
})

TabDebug:CreateButton({
    Name = "Scan Mythical",
    Callback = function()
        local mi, mp, md = findNearestMythicalBrainrot()
        if mi and mp then
            safeNotify("Mythical", tostring(mi.Name) .. " (" .. math.floor(md) .. "m)", 5)
        else
            safeNotify("Mythical", "Not found", 5)
        end
    end,
})

TabDebug:CreateButton({
    Name = "Check Detected Phase",
    Callback = function()
        local phaseName, phaseText = detectPhaseState()
        updatePhaseDebug(phaseName or "NONE", phaseText or "")
        if phaseName then
            safeNotify("Phase Debug", phaseName .. (phaseText and phaseText ~= "" and (" | " .. phaseText) or ""), 5)
        else
            safeNotify("Phase Debug", "NONE | no phase text found", 5)
        end
    end,
})

TabDebug:CreateParagraph({
    Title = "Config",
    Content = "Lokasi ready akan cari waitingNames dulu (termasuk AFK Zone), kalau gagal otomatis pakai fuseNames."
})

Rayfield:LoadConfiguration()
safeNotify("Loaded", "Refactor siap: waiting -> flood pick mythical -> fuse", 4)
