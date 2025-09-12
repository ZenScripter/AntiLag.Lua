-- ZenScripter's AntiLag.lua with Smart Filtering and Auto FPS Tuning
-- Place in StarterPlayerScripts, PlayerGui, or use executor.

local plr = game:GetService("Players").LocalPlayer
local pgui = plr:WaitForChild("PlayerGui")
local runService = game:GetService("RunService")

-- Whitelist and Blacklist (customize these!)
local whitelist = {"Hitbox", "Ability", "Music", "Emote", "Player", "Humanoid", "GUI"}
local blacklist = {"ParticleEmitter", "Trail", "Smoke", "Fire", "Sparkles", "Explosion", "SurfaceAppearance", "Decal", "Texture"}

-- GUI Setup
if not pgui:FindFirstChild("AntiLagSmartFPSGui") then
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AntiLagSmartFPSGui"
    screenGui.Parent = pgui

    local dragFrame = Instance.new("Frame")
    dragFrame.Size = UDim2.new(0,180,0,50)
    dragFrame.Position = UDim2.new(0,30,0,30)
    dragFrame.BackgroundColor3 = Color3.fromRGB(30,30,30)
    dragFrame.BorderSizePixel = 0
    dragFrame.Active = true
    dragFrame.Selectable = true
    dragFrame.Parent = screenGui

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.5,0,1,0)
    btn.Position = UDim2.new(0,0,0,0)
    btn.BackgroundColor3 = Color3.fromRGB(60,200,90)
    btn.Text = "AntiLag: OFF"
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 17
    btn.Parent = dragFrame

    local fpsLabel = Instance.new("TextLabel")
    fpsLabel.Size = UDim2.new(0.5,0,1,0)
    fpsLabel.Position = UDim2.new(0.5,0,0,0)
    fpsLabel.BackgroundTransparency = 1
    fpsLabel.TextColor3 = Color3.new(1,1,1)
    fpsLabel.Font = Enum.Font.SourceSansBold
    fpsLabel.TextSize = 17
    fpsLabel.Text = "FPS: 0"
    fpsLabel.Parent = dragFrame

    -- Drag Support
    local uis = game:GetService("UserInputService")
    local dragging, dragStart, startPos
    dragFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = dragFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    uis.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            dragFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    -- Smart Filtering
    local function isWhitelisted(obj)
        for _, w in ipairs(whitelist) do
            if obj.Name:lower():find(w:lower()) then return true end
        end
        if plr.Character and obj:IsDescendantOf(plr.Character) then return true end
        return false
    end

    local function isBlacklisted(obj)
        for _, b in ipairs(blacklist) do
            if obj:IsA(b) or obj.Name:lower():find(b:lower()) then return true end
        end
        return false
    end

    local function cleanLaggyObjects()
        local cleaned = 0
        for _, obj in ipairs(workspace:GetDescendants()) do
            if isWhitelisted(obj) then continue end
            if isBlacklisted(obj) then
                pcall(function() obj:Destroy() end)
                cleaned = cleaned + 1
            end
        end
        return cleaned
    end

    -- FPS Counter
    local lastTime = tick()
    local frameCount = 0
    local currentFPS = 60
    runService.RenderStepped:Connect(function()
        frameCount = frameCount + 1
        local now = tick()
        if now - lastTime >= 1 then
            currentFPS = frameCount
            fpsLabel.Text = "FPS: "..currentFPS
            frameCount = 0
            lastTime = now
        end
    end)

    -- Auto FPS Tuning
    local antiLagOn = false
    local cleanLoop
    local minFPS = 40
    local maxFPS = 120
    local normalInterval = 3   -- seconds
    local fastInterval = 1     -- seconds (if FPS drops)
    local slowInterval = 5     -- seconds (if FPS high)
    local interval = normalInterval

    local function updateInterval()
        if currentFPS < minFPS then
            interval = fastInterval
        elseif currentFPS > maxFPS then
            interval = slowInterval
        else
            interval = normalInterval
        end
    end

    local function setAntiLag(on)
        antiLagOn = on
        if on then
            btn.Text = "AntiLag: ON"
            btn.BackgroundColor3 = Color3.fromRGB(200,120,40)
            if cleanLoop then cleanLoop:Disconnect() end
            cleanLoop = runService.RenderStepped:Connect(function()
                updateInterval()
                if tick() % interval < 0.03 then
                    local cleaned = cleanLaggyObjects()
                    -- Optional: fpsLabel.Text = "FPS: "..currentFPS.." | Cleaned: "..cleaned
                end
            end)
        else
            btn.Text = "AntiLag: OFF"
            btn.BackgroundColor3 = Color3.fromRGB(60,200,90)
            if cleanLoop then cleanLoop:Disconnect() end
        end
    end

    btn.MouseButton1Click:Connect(function()
        setAntiLag(not antiLagOn)
    end)
end

-- GUI persistence: If GUI gets removed by the game (e.g., round reset), recreate it:
local function ensureGui()
    local gui = pgui:FindFirstChild("AntiLagSmartFPSGui")
    if not gui then
        loadstring(game:HttpGet("https://raw.githubusercontent.com/ZenScripter/AntiLag.Lua/main/AntiLagSmartFPS.lua"))()
    end
end

game:GetService("RunService").RenderStepped:Connect(function()
    ensureGui()
end)

print("AntiLagSmartFPS Loaded! Whitelist/blacklist and auto FPS tuning enabled.")
