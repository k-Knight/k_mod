local ToggleSpeedKey = Enum.KeyCode.F8 -- The key that turns speed boost on/off (CTRL + SHIFT + <key>)
local IncreseBoostKey = Enum.KeyCode.RightBracket -- The key increases the boost (CTRL + SHIFT + <key>)
local DecreseBoostKey = Enum.KeyCode.LeftBracket -- The key decreases the boost (CTRL + SHIFT + <key>)
local BoostStep = 0.25 -- How much the speed boost changes

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

local my_speed = 0
local speed_mult = 0.25
local prev_pos = nil
local enabled = false

local check_collision = function(part, direction)
    local ray_dir = direction.Unit * speed_mult * 1.5
    raycastParams.FilterDescendantsInstances = {part.Parent}
    
    local result = workspace:Raycast(part.Position, ray_dir, raycastParams)
    if result then
        return true
    else
        return false
    end
end

RunService.Heartbeat:Connect(function(dt)
    if not enabled then
        return
    end

    local char = game.Players.LocalPlayer.Character
    if my_speed > 1 then
        local direction = char.Humanoid.MoveDirection
        if direction.Magnitude ~= 0 then
            local root = char.HumanoidRootPart
            local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = root.CFrame:components()
            local pos = Vector3.new(x, y ,z)

            if not check_collision(root, direction.Unit) then
                x = x + (direction.Unit.X * speed_mult)
                z = z + (direction.Unit.Z * speed_mult)
            else
                if prev_pos then
                    x = prev_pos.X + (direction.Unit.X * speed_mult * 0.25)
                    z = prev_pos.Z + (direction.Unit.Z * speed_mult * 0.25) 
                end
            end

            prev_pos = pos
            root.CFrame = CFrame.new(x, y, z, r00, raa01, r02, r10, r11, r12, r20, r21, r22)
        end
    end
end)

local record_speed = function(speed)
    my_speed = speed
end

game.Players.LocalPlayer.Character.Humanoid.Running:Connect(record_speed)
game.Players.LocalPlayer.CharacterAdded:Connect(function(character)
    character:WaitForChild("Humanoid", math.huge).Running:Connect(record_speed)
end)

UserInputService.InputBegan:Connect(function(input)
    local keysPressed = UserInputService:GetKeysPressed()

    local ctrl, shift = false, false
    local boostUp, boostDown, toggleSpeed = false, false, false

    for _, key in ipairs(keysPressed) do
        if key.KeyCode == Enum.KeyCode.LeftControl or key.KeyCode == Enum.KeyCode.RightControl then
            ctrl = true
        end
        if key.KeyCode == Enum.KeyCode.LeftShift or key.KeyCode == Enum.KeyCode.RightShift then
            shift = true
        end
        if key.KeyCode == ToggleSpeedKey then
            toggleSpeed = true
        end
        if key.KeyCode == IncreseBoostKey then
            boostUp = true
        end
        if key.KeyCode == DecreseBoostKey then
            boostDown = true
        end
    end

    if ctrl and shift then
        if toggleSpeed then
            enabled = not enabled
        end
        if boostUp then
            speed_mult = speed_mult + BoostStep
        end
        if boostDown then
            speed_mult = speed_mult - BoostStep
        end
    end
end)