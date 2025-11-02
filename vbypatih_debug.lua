--[[
    Violence District - Debug Version
    Made by: patihrz
    Testing script loading
]]--

print("================================")
print("[VD DEBUG] Script started!")
print("================================")

-- Test 1: Print
print("[TEST 1] Basic print works ✓")

-- Test 2: Services
print("[TEST 2] Loading services...")
local success1, result1 = pcall(function()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local Workspace = game:GetService("Workspace")
    local LP = Players.LocalPlayer
    print("[TEST 2] Services loaded ✓")
    print("[TEST 2] LocalPlayer: " .. tostring(LP.Name))
end)

if not success1 then
    print("[TEST 2] FAILED: " .. tostring(result1))
end

-- Test 3: Rayfield
print("[TEST 3] Loading Rayfield...")
local success2, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)

if success2 then
    print("[TEST 3] Rayfield loaded ✓")
else
    print("[TEST 3] FAILED: " .. tostring(Rayfield))
    return
end

-- Test 4: Create Window
print("[TEST 4] Creating window...")
local success3, Window = pcall(function()
    return Rayfield:CreateWindow({
        Name = "VD Debug Test",
        LoadingTitle = "Testing...",
        LoadingSubtitle = "by patihrz",
        ConfigurationSaving = {
            Enabled = false
        },
        KeySystem = false
    })
end)

if success3 then
    print("[TEST 4] Window created ✓")
else
    print("[TEST 4] FAILED: " .. tostring(Window))
    return
end

-- Test 5: Create Tab
print("[TEST 5] Creating tab...")
local success4, Tab = pcall(function()
    return Window:CreateTab("Debug")
end)

if success4 then
    print("[TEST 5] Tab created ✓")
else
    print("[TEST 5] FAILED: " .. tostring(Tab))
    return
end

-- Test 6: Add button
print("[TEST 6] Adding button...")
local success5 = pcall(function()
    Tab:CreateButton({
        Name = "Test Button - Click Me!",
        Callback = function()
            print("[BUTTON] Button clicked!")
            Rayfield:Notify({
                Title = "Success!",
                Content = "Script is working properly!",
                Duration = 3
            })
        end
    })
end)

if success5 then
    print("[TEST 6] Button added ✓")
else
    print("[TEST 6] FAILED")
end

-- Final notification
Rayfield:Notify({
    Title = "Debug Test Complete",
    Content = "All tests passed!\nCheck console for details.",
    Duration = 5
})

print("================================")
print("[VD DEBUG] All tests completed!")
print("================================")
