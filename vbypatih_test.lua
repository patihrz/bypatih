-- Test Version - Violence District
-- by patihrz

print("Script starting...")

local success, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)

if not success then
    print("ERROR: Rayfield failed to load!")
    print(Rayfield)
    return
end

print("Rayfield loaded successfully!")

local Window = Rayfield:CreateWindow({
    Name = "Violence District Test",
    LoadingTitle = "Violence District",
    LoadingSubtitle = "by patihrz - TEST VERSION",
    ConfigurationSaving = {
        Enabled = false
    },
    KeySystem = false
})

print("Window created!")

local TabTest = Window:CreateTab("Test Tab")

TabTest:CreateButton({
    Name = "Test Button - Click Me!",
    Callback = function()
        print("Button clicked!")
        Rayfield:Notify({
            Title = "Test",
            Content = "Script works! ✓",
            Duration = 5
        })
    end
})

print("Script loaded completely!")

Rayfield:Notify({
    Title = "Violence District",
    Content = "✓ Script berhasil dimuat!\nTest version by patihrz",
    Duration = 5
})
