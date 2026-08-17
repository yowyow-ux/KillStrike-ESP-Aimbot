-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

-- System State
local espEnabled = false
local aimbotEnabled = false
local aimbotKey = Enum.KeyCode.E -- Keybind to lock onto enemies when Aimbot is active
local maxAimbotFOV = 80 -- 80-degree total Field of View cone
local isLocking = false
local currentTarget = nil

-- ==========================================
-- PROGRAMMATIC GUI CONSTRUCTION
-- ==========================================

-- Screen GUI Container
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CheatMenuGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = PlayerGui

-- Main Window Frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 220, 0, 180)
MainFrame.Position = UDim2.new(0.5, -110, 0.4, -90) -- Center-ish on screens
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true -- Allows development/visual testing dragging
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = MainFrame

-- Title Banner Text
local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "TitleLabel"
TitleLabel.Size = UDim2.new(1, 0, 0, 40)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "KILLSTREAK UTILITIES"
TitleLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
TitleLabel.TextSize = 16
TitleLabel.Font = Enum.Font.SourceSansBold
TitleLabel.Parent = MainFrame

-- ESP Feature Toggle Button
local ESPButton = Instance.new("TextButton")
ESPButton.Name = "ESPButton"
ESPButton.Size = UDim2.new(0, 180, 0, 40)
ESPButton.Position = UDim2.new(0, 20, 0, 50)
ESPButton.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
ESPButton.Text = "ESP: OFF"
ESPButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ESPButton.TextSize = 14
ESPButton.Font = Enum.Font.SourceSans
ESPButton.Parent = MainFrame

local ESPCorner = Instance.new("UICorner")
ESPCorner.CornerRadius = UDim.new(0, 6)
ESPCorner.Parent = ESPButton

-- Aimbot Feature Toggle Button
local AimbotButton = Instance.new("TextButton")
AimbotButton.Name = "AimbotButton"
AimbotButton.Size = UDim2.new(0, 180, 0, 40)
AimbotButton.Position = UDim2.new(0, 20, 0, 105)
AimbotButton.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
AimbotButton.Text = "Aimbot: OFF (Hold E)"
AimbotButton.TextColor3 = Color3.fromRGB(255, 255, 255)
AimbotButton.TextSize = 14
AimbotButton.Font = Enum.Font.SourceSans
AimbotButton.Parent = MainFrame

local AimbotCorner = Instance.new("UICorner")
AimbotCorner.CornerRadius = UDim.new(0, 6)
AimbotCorner.Parent = AimbotButton

-- UI Update Wrappers
local function updateButtonVisual(button, enabled, featureName, extraInfo)
    extraInfo = extraInfo or ""
    if enabled then
        button.BackgroundColor3 = Color3.fromRGB(60, 180, 60)
        button.Text = featureName .. ": ON " .. extraInfo
    else
        button.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
        button.Text = featureName .. ": OFF " .. extraInfo
    end
end

-- ==========================================
-- GAMEPLAY LOGIC (ESP & AIMBOT)
-- ==========================================

-- Dynamically configure visibility state of Highlight instances
local function manageHighlight(character)
    local highlight = character:FindFirstChild("ESPHighlight")
    if not highlight then
        highlight = Instance.new("Highlight")
        highlight.Name = "ESPHighlight"
        highlight.Adornee = character
        highlight.FillColor = Color3.fromRGB(255, 60, 60)
        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        highlight.FillTransparency = 0.6
        highlight.OutlineTransparency = 0
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Parent = character
    end
    highlight.Enabled = espEnabled
end

-- Refresh state across every remote character model
local function refreshAllESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            manageHighlight(player.Character)
        end
    end
end

local function onPlayerAdded(player)
    if player ~= LocalPlayer then
        player.CharacterAdded:Connect(function(character)
            task.wait(0.1) -- Provide short window for asset assembly loading
            manageHighlight(character)
        end)
        if player.Character then
            manageHighlight(player.Character)
        end
    end
end

-- Track Closest Living Target Character within the 80-degree FOV cone
local function getClosestPlayerInFOV()
    local closestPlayer = nil
    local shortestDistance = math.huge
    local localCharacter = LocalPlayer.Character
    
    if not localCharacter or not localCharacter:FindFirstChild("HumanoidRootPart") then
        return nil
    end
    
    local localHRP = localCharacter.HumanoidRootPart

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character
            local hp = char:FindFirstChildOfClass("Humanoid")
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local head = char:FindFirstChild("Head")
            
            if hp and hp.Health > 0 and hrp and head then
                -- Calculate angular offset from camera's forward vector
                local targetDirection = (head.Position - Camera.CFrame.Position).Unit
                local cameraDirection = Camera.CFrame.LookVector
                local dotProduct = cameraDirection:Dot(targetDirection)
                local angleDegrees = math.deg(math.acos(dotProduct))
                
                -- Check if target is inside the 80-degree total cone (40 degrees from center line)
                if angleDegrees <= (maxAimbotFOV / 2) then
                    local distance = (hrp.Position - localHRP.Position).Magnitude
                    if distance < shortestDistance then
                        shortestDistance = distance
                        closestPlayer = char
                    end
                end
            end
        end
    end
    return closestPlayer
end

-- ==========================================
-- INTERACTION & SEED HOOKS
-- ==========================================

-- Button Toggle Connections
ESPButton.MouseButton1Click:Connect(function()
    espEnabled = not espEnabled
    updateButtonVisual(ESPButton, espEnabled, "ESP")
    refreshAllESP()
end)

AimbotButton.MouseButton1Click:Connect(function()
    aimbotEnabled = not aimbotEnabled
    updateButtonVisual(AimbotButton, aimbotEnabled, "Aimbot", "(Hold E)")
    if not aimbotEnabled then
        isLocking = false
        currentTarget = nil
    end
end)

-- Initialize Player Monitoring Loops
for _, player in ipairs(Players:GetPlayers()) do
    onPlayerAdded(player)
end
Players.PlayerAdded:Connect(onPlayerAdded)

-- Keybind Actions for Aim-assist Activation
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or not aimbotEnabled then return end
    if input.KeyCode == aimbotKey then
        isLocking = true
        currentTarget = getClosestPlayerInFOV()
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == aimbotKey then
        isLocking = false
        currentTarget = nil
    end
end)

-- Smooth Frame Alignment LookAt Vector Loop
RunService.RenderStepped:Connect(function()
    if aimbotEnabled and isLocking and currentTarget and currentTarget:FindFirstChild("Head") then
        local head = currentTarget.Head
        local hp = currentTarget:FindFirstChildOfClass("Humanoid")
        
        if hp and hp.Health <= 0 then
            currentTarget = nil
            return
        end
        
        -- Double-check that target hasn't moved completely out of the FOV parameter during lock
        local targetDirection = (head.Position - Camera.CFrame.Position).Unit
        local cameraDirection = Camera.CFrame.LookVector
        local dotProduct = cameraDirection:Dot(targetDirection)
        local angleDegrees = math.deg(math.acos(dotProduct))
        
        if angleDegrees > (maxAimbotFOV / 2) then
            -- Optional: Drop lock or try to re-acquire a closer target within FOV
            currentTarget = getClosestPlayerInFOV()
            if not currentTarget then return end
        end
        
        -- Interpolate structural orientation of the client viewport
        local targetCFrame = CFrame.new(Camera.CFrame.Position, head.Position)
        Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, 0.2)
    end
end)
