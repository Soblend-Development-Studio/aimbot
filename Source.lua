local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local LocalPlayer       = Players.LocalPlayer
local Camera            = workspace.CurrentCamera
local CONFIG = {
    enabled = true,
    toggleKey = Enum.KeyCode.F,
    detectionRadius = 60,
    smoothness = 0.06,
    deadZonePixels = 80,
    targetPart = "Head",
    onlyWhileAiming = false,
    aimButton = Enum.UserInputType.MouseButton2,
    ignoreTeammates = true,
}

local isAimButtonHeld   = false
local currentTarget     = nil   
local debugLabel        = nil
local function buildStatusUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name            = "AimAssistUI"
    screenGui.ResetOnSpawn    = false
    screenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
    screenGui.Parent          = LocalPlayer.PlayerGui
    local frame = Instance.new("Frame")
    frame.Size                = UDim2.new(0, 220, 0, 36)
    frame.Position            = UDim2.new(0, 12, 0, 12)
    frame.BackgroundColor3    = Color3.fromRGB(20, 20, 20)
    frame.BackgroundTransparency = 0.35
    frame.BorderSizePixel     = 0
    frame.Parent              = screenGui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    local label = Instance.new("TextLabel")
    label.Size                = UDim2.new(1, -12, 1, 0)
    label.Position            = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Font                = Enum.Font.GothamBold
    label.TextSize            = 13
    label.TextColor3          = Color3.fromRGB(255, 255, 255)
    label.TextXAlignment      = Enum.TextXAlignment.Left
    label.Text                = "🎯 Aim Assist: ON"
    label.Parent              = frame
    return label
end
local function updateStatus(target)
    if not debugLabel then return end
    if not CONFIG.enabled then
        debugLabel.Text = "🎯 Aim Assist: OFF  [" .. CONFIG.toggleKey.Name .. "]"
        debugLabel.TextColor3 = Color3.fromRGB(180, 80, 80)
        return
    end
    if target then
        debugLabel.Text = "🎯 → " .. target.Name
        debugLabel.TextColor3 = Color3.fromRGB(100, 220, 130)
    else
        debugLabel.Text = "🎯 Aim Assist: ON  [" .. CONFIG.toggleKey.Name .. "]"
        debugLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    end
end
local function isValidTarget(player)
    if player == LocalPlayer then return false end
    if not player.Character then return false end
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    if CONFIG.ignoreTeammates and LocalPlayer.Team ~= nil then
        if player.Team == LocalPlayer.Team then return false end
    end

    return true
end
local function getScreenPosition(character)
    local part = character:FindFirstChild(CONFIG.targetPart)
        or character:FindFirstChild("HumanoidRootPart")
    if not part then return nil, nil end
    local screenPos, onScreen = Camera:WorldToScreenPoint(part.Position)
    if not onScreen then return nil, nil end
    return Vector2.new(screenPos.X, screenPos.Y), part.Position
end
local function findBestTarget()
    local myChar    = LocalPlayer.Character
    local myRoot    = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end
    local viewportSize  = Camera.ViewportSize
    local screenCenter  = viewportSize / 2
    local bestPlayer    = nil
    local bestDist      = math.huge 
    for _, player in ipairs(Players:GetPlayers()) do
        if isValidTarget(player) then
            local targetRoot = player.Character:FindFirstChild("HumanoidRootPart")
            if targetRoot then
                local dist3D = (targetRoot.Position - myRoot.Position).Magnitude
                if dist3D <= CONFIG.detectionRadius then
                    local screenPos, _ = getScreenPosition(player.Character)
                    if screenPos then
                        local distScreen = (screenPos - screenCenter).Magnitude
                        if distScreen < bestDist then
                            bestDist   = distScreen
                            bestPlayer = player
                        end
                    end
                end
            end
        end
    end
    return bestPlayer
end
local function applyAssist(dt)
    if not CONFIG.enabled then return end
    if CONFIG.onlyWhileAiming and not isAimButtonHeld then
        currentTarget = nil
        return
    end
    currentTarget = findBestTarget()
    updateStatus(currentTarget)
    if not currentTarget or not currentTarget.Character then return end
    local screenPos, worldPos = getScreenPosition(currentTarget.Character)
    if not screenPos or not worldPos then return end
    local viewportSize  = Camera.ViewportSize
    local screenCenter  = viewportSize / 2
    local offset        = screenPos - screenCenter
    if offset.Magnitude < CONFIG.deadZonePixels then return end
    local fovRad    = math.rad(Camera.FieldOfView)
    local aspect    = viewportSize.X / viewportSize.Y
    local deltaYaw   = (offset.X / viewportSize.X) * fovRad * aspect
    local deltaPitch = (offset.Y / viewportSize.Y) * fovRad
    local lerpFactor = math.clamp(CONFIG.smoothness, 0, 1)
    local cframe = Camera.CFrame
    local newCFrame = cframe
        * CFrame.Angles(0, -deltaYaw  * lerpFactor, 0)
        * CFrame.Angles(-deltaPitch * lerpFactor, 0, 0)

    Camera.CFrame = newCFrame
end
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == CONFIG.toggleKey then
        CONFIG.enabled = not CONFIG.enabled
        updateStatus(nil)
    end
    if input.UserInputType == CONFIG.aimButton then
        isAimButtonHeld = true
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == CONFIG.aimButton then
        isAimButtonHeld = false
    end
end)
RunService.RenderStepped:Connect(function(dt)
    applyAssist(dt)
end)
debugLabel = buildStatusUI()
updateStatus(nil)
