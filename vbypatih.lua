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
    waitingDuration = 30,
    roundDuration = 20,
    floodDuration = 45,
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

local function teleportTo(part)
    local hrp = getHRP()
    if not hrp or not part then return false end
    local ok = pcall(function()
        hrp.CFrame = part.CFrame + Vector3.new(0, 3, 0)
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

local function doFloodPickCycle()
    local t0 = now()
    local picked = false

    while cfg.autoEnabled and (now() - t0) < cfg.floodDuration do
        if state.pickupCount >= cfg.pickupTarget then
            break
        end
        
        local left = math.max(0, math.ceil(cfg.floodDuration - (now() - t0)))
        state.step = "FLOOD IS COMING (" .. tostring(left) .. "s) [" .. state.pickupCount .. "/" .. cfg.pickupTarget .. "]"

        local carriedCount = getCarriedBrainrotCount()
        if carriedCount >= 3 then
            safeNotify("Inventory", "Sudah carry 3 brainrot, harus ke Fuse", 2)
            break
        end

        local mythic, mythicPart = findNearestMythicalBrainrot()
        if mythic and mythicPart then
            teleportTo(mythicPart)
            task.wait(0.12)
            local pickupSuccess = pickupBrainrot(mythic)
            if pickupSuccess then
                state.pickupCount = state.pickupCount + 1
                picked = true
                safeNotify("Step", "Mythical diambil (" .. state.pickupCount .. "/" .. cfg.pickupTarget .. ")", 2)
            end

            local fusePart = findNearestByNames(cfg.fuseNames)
            if fusePart then
                teleportTo(fusePart)
                safeNotify("Step", "Teleport ke Fuse Machine", 2)
            else
                safeNotify("Step", "Fuse Machine tidak ditemukan", 2)
            end
            break
        end

        task.wait(0.25)
    end

    if picked and cfg.postPickupDelay > 0 then
        waitPhase(cfg.postPickupDelay, "POST PICKUP")
    end
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
            teleportTo(waitingPart)
            if source == "WAITING" then
                safeNotify("Step", "Teleport ke Waiting (dekat fuse)", 2)
            else
                safeNotify("Step", "Waiting tidak ketemu, fallback ke Fuse", 2)
            end
        else
            safeNotify("Step", "Waiting/Fuse tidak ditemukan", 2)
        end

        if not waitPhase(cfg.waitingDuration, "WAITING FOR PLAYERS") then break end
        if not waitPhase(cfg.roundDuration, "ROUND IN PROGRESS") then break end
        doFloodPickCycle()

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

TabDebug:CreateParagraph({
    Title = "Config",
    Content = "Lokasi ready akan cari waitingNames dulu (termasuk AFK Zone), kalau gagal otomatis pakai fuseNames."
})

Rayfield:LoadConfiguration()
safeNotify("Loaded", "Refactor siap: waiting -> flood pick mythical -> fuse", 4)
