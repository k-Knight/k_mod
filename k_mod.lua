local _g = getgenv().shared

if not _g then
  getgenv().shared = {}
  _g = getgenv().shared
end

local first_time_init = false
local debug_output = false

local k_log = function(msg)
  if debug_output then
    print(msg)
  end
end

if not _g.k_mod then
  _g.k_mod = {}
  first_time_init = true
end
k_log("k_mod - first_time_init :: " .. tostring(first_time_init))

local Camera = workspace.CurrentCamera
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

if not _g.k_mod.esp then
  _g.k_mod.esp = {}

  _g.k_mod.esp.enabled = false
  _g.k_mod.esp.holder = Instance.new("Folder", game.CoreGui)
  _g.k_mod.esp.name_tag = Instance.new("BillboardGui")
  _g.k_mod.esp.highlights = {}
  _g.k_mod.esp.dist_indicators = {}
end

_g.k_mod.player = Players.LocalPlayer
_g.k_mod.position = nil

if not _g.k_mod.aim_assist then
  _g.k_mod.aim_assist = {}

  _g.k_mod.aim_assist.enabled = false
  _g.k_mod.aim_assist.team_check = true -- If set to true then the script would only lock your aim at enemy team members.
  _g.k_mod.aim_assist.fov_circle = Drawing.new("Circle")
end

if not _g.k_mod.speedboost then
  _g.k_mod.speedboost = {}
end

-- ============================================= USER CONFIG START =============================================
  _g.k_mod.aim_assist.toggle_enabled_key = Enum.KeyCode.F15 -- turns aimbot on/off
  _g.k_mod.aim_assist.toggle_team_key = Enum.KeyCode.F14 -- toggles the team check condition
  _g.k_mod.aim_assist.aim_parts = {"Torso", "UpperTorso", "LowerTorso", "Head"} -- Where the aimbot script would lock at (first item - highest priority).
  _g.k_mod.aim_assist.fov_radius = 120 -- The radius of the circle / FOV.
  _g.k_mod.aim_assist.assisnt_strength = 0.66 -- aim assist streght multiplier
  _g.k_mod.aim_assist.horizontal_only = false -- aim assist only horizontally
  _g.k_mod.esp.toggle_key = Enum.KeyCode.F13 -- turns esp on/off
  _g.k_mod.esp.range_devider = 2.8 -- multicrew tank combat 4 value is 2.9 roblox units per 1 meter
  _g.k_mod.speedboost.hotkey = Enum.KeyCode.V -- applies speedboost while key is hold down
  _g.k_mod.speedboost.increase_boost = Enum.KeyCode.RightBracket -- increases the boost
  _g.k_mod.speedboost.decrease_boost = Enum.KeyCode.LeftBracket -- decreases the boost
  _g.k_mod.speedboost.toggle_mode = Enum.KeyCode.Semicolon -- toggles jump_boost for speed_boost, (ctrl + <button>) toggles noclip
  _g.k_mod.speedboost.boost_step = 0.1
  _g.k_mod.rejoin_key = Enum.KeyCode.R -- rejoin server on (ctrl + shift + <button>)
-- ============================================== USER CONFIG END ==============================================

local mousemoverel = (mousemoverel or (Input and Input.MouseMove)) or nil

-- ============================================= UTIL START =============================================
  _g.k_mod.get_local_char = function()
    return Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
  end

  _g.k_mod.get_humanoid = function(char)
    return char:WaitForChild("Humanoid")
  end

  _g.k_mod.set_local_clip = function(state)
    local bool = false

    if state then
      bool = true
    end

    for i, v in pairs(_g.k_mod.get_local_char():GetChildren()) do
      if v:IsA("BasePart") then
        v.CanCollide = bool
      end
    end
  end

  _g.k_mod.rejoin_server = function()
    local ts = game:GetService("TeleportService")
    local p = game:GetService("Players").LocalPlayer

    ts:TeleportToPlaceInstance(game.PlaceId, game.JobId, p)
  end
-- ============================================== UTIL END ==============================================

-- ============================================= SPEEDBOOST START =============================================
  _g.k_mod.speedboost.raycastParams = RaycastParams.new()
  _g.k_mod.speedboost.raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
  _g.k_mod.speedboost.prev_dir = nil
  _g.k_mod.speedboost.my_speed = 0
  _g.k_mod.speedboost.prev_y_diff = 0
  _g.k_mod.speedboost.bounce_supression = 0
  _g.k_mod.speedboost.prev_pos = nil
  _g.k_mod.speedboost.speed_mult = 0.1
  _g.k_mod.speedboost.enabled = false
  _g.k_mod.speedboost.clip_mode = true
  _g.k_mod.speedboost.jump_boost = false

  _g.k_mod.speedboost.check_collision = function(part, direction)
    if _g.k_mod.speedboost.clip_mode then
      _g.k_mod.set_local_clip(true)
    else
      _g.k_mod.set_local_clip(false)

      return false
    end
    local raycastParams = _g.k_mod.speedboost.raycastParams
    local ray_dir = direction.Unit * _g.k_mod.speedboost.speed_mult * 1.5

    raycastParams.FilterDescendantsInstances = {part.Parent}
    
    local result = workspace:Raycast(part.Position, ray_dir, raycastParams)
    if result then
        return true
    else
        return false
    end
  end

  _g.k_mod.speedboost.record_speed = function(speed)
    _g.k_mod.speedboost.my_speed = speed
  end

  _g.k_mod.speedboost.on_heartbeat = function(dt)
    if not _g.k_mod.speedboost.enabled then
      return
    end
  
    local char = _g.k_mod.get_local_char()
    local speed_mult = _g.k_mod.speedboost.speed_mult
    local prev_pos = _g.k_mod.speedboost.prev_pos
    local jump_boost = _g.k_mod.speedboost.jump_boost

    local direction = char.Humanoid.MoveDirection

    if _g.k_mod.speedboost.prev_dir then
      direction = (direction * 0.33) + (_g.k_mod.speedboost.prev_dir * 0.66)
    end

    local root = char.HumanoidRootPart
    local apply_change = false
    local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = root.CFrame:components()
    local pos = Vector3.new(x, y ,z)
    local bounce_supression = _g.k_mod.speedboost.bounce_supression

    if jump_boost and prev_pos then
      local diff = y - prev_pos.Y

      if diff > 0.1 then
        if bounce_supression < 0.1 then
          if _g.k_mod.speedboost.prev_y_diff > 0.1 then
            y = y + (speed_mult * 1.5)
            apply_change = true
          else
            y = prev_pos.Y
            _g.k_mod.speedboost.bounce_supression = 0.15
          end
        else
          y = prev_pos.Y
          _g.k_mod.speedboost.bounce_supression = bounce_supression - dt
        end
      end

      _g.k_mod.speedboost.prev_y_diff = diff
    end
  
    if _g.k_mod.speedboost.my_speed > 1 then
        if direction.Magnitude ~= 0 then
            if not _g.k_mod.speedboost.check_collision(root, direction.Unit) then
              x = x + (direction.Unit.X * speed_mult)
              z = z + (direction.Unit.Z * speed_mult)
            else
              k_log("speedboost: collision prevention")
              if prev_pos then
                x = prev_pos.X + (direction.Unit.X * speed_mult * 0.25)
                z = prev_pos.Z + (direction.Unit.Z * speed_mult * 0.25)
              end
            end
  
            apply_change = true
        end
    end

    if apply_change then
      root.CFrame = CFrame.new(x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
    end

    _g.k_mod.speedboost.prev_pos = pos
    _g.k_mod.speedboost.prev_dir = direction
  end
-- ============================================== SPEEDBOOST END ==============================================

-- ============================================= ESP START =============================================
  _g.k_mod.esp.FriendColor = Color3.fromRGB(0, 0, 255)
  _g.k_mod.esp.EnemyColor = Color3.fromRGB(255, 0, 0)
  _g.k_mod.esp.UseTeamColor = true

  _g.k_mod.esp.holder.Name = "ESP"

  _g.k_mod.esp.name_tag.Name = "nilNameTag"
  _g.k_mod.esp.name_tag.Enabled = false
  _g.k_mod.esp.name_tag.Size = UDim2.new(0, 200, 0, 50)
  _g.k_mod.esp.name_tag.AlwaysOnTop = true
  _g.k_mod.esp.name_tag.StudsOffset = Vector3.new(0, 1.8, 0)

  if _g.k_mod.esp.tag then
    _g.k_mod.esp.tag:Destroy()
  end
  _g.k_mod.esp.tag = Instance.new("TextLabel", _g.k_mod.esp.name_tag)
  _g.k_mod.esp.tag.Name = "Tag"
  _g.k_mod.esp.tag.BackgroundTransparency = 1
  _g.k_mod.esp.tag.Position = UDim2.new(0, -50, 0, 0)
  _g.k_mod.esp.tag.Size = UDim2.new(0, 300, 0, 20)
  _g.k_mod.esp.tag.TextSize = 15
  _g.k_mod.esp.tag.TextColor3 = Color3.new(100 / 255, 100 / 255, 100 / 255)
  _g.k_mod.esp.tag.TextStrokeColor3 = Color3.new(0 / 255, 0 / 255, 0 / 255)
  _g.k_mod.esp.tag.TextStrokeTransparency = 0.4
  _g.k_mod.esp.tag.Text = " "
  _g.k_mod.esp.tag.Font = Enum.Font.SourceSansBold
  _g.k_mod.esp.tag.TextScaled = false

  if _g.k_mod.esp.dist then
    _g.k_mod.esp.dist:Destroy()
  end
  _g.k_mod.esp.dist = Instance.new("TextLabel", _g.k_mod.esp.name_tag)
  _g.k_mod.esp.dist.Name = "Distance"
  _g.k_mod.esp.dist.BackgroundTransparency = 1
  _g.k_mod.esp.dist.Position = UDim2.new(0, -50, 0, -15)
  _g.k_mod.esp.dist.Size = UDim2.new(0, 300, 0, 20)
  _g.k_mod.esp.dist.TextSize = 15
  _g.k_mod.esp.dist.TextColor3 = Color3.new(255, 255, 255)
  _g.k_mod.esp.dist.TextStrokeColor3 = Color3.new(0, 0, 0)
  _g.k_mod.esp.dist.TextStrokeTransparency = 0.4
  _g.k_mod.esp.dist.TextTransparency = 0.4
  _g.k_mod.esp.dist.Text = "kakaha"
  _g.k_mod.esp.dist.Font = Enum.Font.SourceSansBold
  _g.k_mod.esp.dist.TextScaled = false

  _g.k_mod.esp.get_dist_to_player = function(char)
    local part = _g.k_mod.aim_assist.find_aim_part(char)
    if part and _g.k_mod.position then
      local dist = (part.Position - _g.k_mod.position).Magnitude

      if dist then
        return dist / _g.k_mod.esp.range_devider
      end
    end

    return nil
  end

  _g.k_mod.esp.load_character = function(v)
    repeat wait() until v.Character ~= nil
    v.Character:WaitForChild("Humanoid")

    local v_holder = _g.k_mod.esp.holder:FindFirstChild(v.Name)
    pcall(function() v_holder:ClearAllChildren() end)

    local t = _g.k_mod.esp.name_tag:Clone()
    t.Name = v.Name .. "NameTag"
    t.Enabled = true
    t.Parent = v_holder
    t.Adornee = v.Character:WaitForChild("Head", 5)

    if not t.Adornee then
      return _g.k_mod.esp.unload_character(v)
    end

    t.Tag.Text = v.Name
    t.Tag.TextColor3 = Color3.new(v.TeamColor.r, v.TeamColor.g, v.TeamColor.b)

    if v ~= _g.k_mod.player then
      local dist = _g.k_mod.esp.get_dist_to_player(v.Character)
      if dist then
        t.Distance.Text = math.floor(dist)
      else
        t.Distance.Text = " "
      end

      _g.k_mod.esp.dist_indicators[v] = t.Distance
    else
      t.Distance.Text = " "
    end

    local update

    local update_name_tag = function()
      if not pcall(function()
        v.Character.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        local maxh = math.floor(v.Character.Humanoid.MaxHealth)
        local h = math.floor(v.Character.Humanoid.Health)
      end) then
        update:Disconnect()
      end
    end

    update_name_tag()

    update = v.Character.Humanoid.Changed:Connect(update_name_tag)
  end

  _g.k_mod.esp.unload_character = function(v)
    local v_holder = _g.k_mod.esp.holder:FindFirstChild(v.Name)

    if v_holder and (v_holder:FindFirstChild(v.Name .. "Box") ~= nil or v_holder:FindFirstChild(v.Name .. "NameTag") ~= nil) then
      v_holder:ClearAllChildren()
    end
  end

  _g.k_mod.esp.load_player = function(v)
    if not _g.k_mod.esp.enabled then
      return
    end

    local v_holder = Instance.new("Folder", _g.k_mod.esp.holder)
    v_holder.Name = v.Name

    v.CharacterAdded:Connect(function()
      pcall(_g.k_mod.esp.load_character, v)
    end)

    v.CharacterRemoving:Connect(function()
      pcall(_g.k_mod.esp.load_character, v)
    end)

    v.Changed:Connect(function(prop)
      if prop == "TeamColor" then
        _g.k_mod.esp.unload_character(v)
        wait()
        _g.k_mod.esp.load_character(v)
      end
    end)

    _g.k_mod.esp.load_character(v)
  end

  _g.k_mod.esp.unload_player = function(v)
    _g.k_mod.esp.unload_character(v)

    local v_holder = _g.k_mod.esp.holder:FindFirstChild(v.Name)

    if v_holder then
      v_holder:Destroy()
    end
  end

  _g.k_mod.esp.load_all_players = function()
    for i,v in pairs(Players:GetPlayers()) do
      spawn(function() pcall(_g.k_mod.esp.load_player, v) end)
    end
  end

  _g.k_mod.esp.unload_all_players = function()
    for i,v in pairs(Players:GetPlayers()) do
      spawn(function() pcall(_g.k_mod.esp.unload_player, v) end)
    end

    for i,v in pairs(_g.k_mod.esp.highlights) do
      _g.k_mod.esp.remove_hightlight(_g.k_mod.esp.highlights[i])
    end

    _g.k_mod.esp.highlights = {}
  end

  _g.k_mod.esp.remove_hightlight = function(highlight)
    highlight.inner:Destroy()
    highlight.outer:Destroy()
    _g.k_mod.esp.highlights[highlight.id] = nil
  end

  _g.k_mod.esp.update_hightlight = function(highlight, color)
    if highlight.counter < 1 then
      local id = highlight.id
      local color = highlight.color
      _g.k_mod.esp.remove_hightlight(highlight)
      _g.k_mod.esp.create_hightlight(id, color)
    else
      highlight.counter = highlight.counter - 1
      if color then
        highlight.color = color
        highlight.inner.Color3 = color
      end
    end
  end

  _g.k_mod.esp.create_hightlight = function(id, color)
    local char = id.Character or id.CharacterAdded:Wait()
    local part = _g.k_mod.aim_assist.find_aim_part(char)

    if part then
      local highlight2 = Instance.new("BoxHandleAdornment")
      highlight2.Size = Vector3.new(1.2, 1.2, 1.2)
      highlight2.Name = "GetReal"
      highlight2.Adornee = part
      highlight2.AlwaysOnTop = true
      highlight2.ZIndex = 0
      highlight2.Transparency = 0.3
      highlight2.Color3 = Color3.fromRGB(255, 255, 255)
      highlight2.Parent = part

      local highlight1 = Instance.new("BoxHandleAdornment")
      highlight1.Size = Vector3.new(1, 1, 1)
      highlight1.Name = "GetReal"
      highlight1.Adornee = part
      highlight1.AlwaysOnTop = true
      highlight1.ZIndex = 5
      highlight1.Transparency = 0.3
      highlight1.Color3 = color
      highlight1.Parent = part

      _g.k_mod.esp.highlights[id] = { inner = highlight1, outer = highlight2, counter = 60, id = id, color = color }
    else
      k_log("no target for :: " .. tostring(id))
    end
  end

  _g.k_mod.esp.esp_fun = function(target, color)
    if not _g.k_mod.esp.enabled or not target then
      return
    end

    local highlight = _g.k_mod.esp.highlights[target]
    if not highlight then
        _g.k_mod.esp.create_hightlight(target, color)
    else
      _g.k_mod.esp.update_hightlight(highlight, color)
    end
  end

  _g.k_mod.esp.update_distance = function(player)
    local dist_indicator = _g.k_mod.esp.dist_indicators[player]

    if dist_indicator then
      local char = player.Character or player.CharacterAdded:Wait()
      local dist = _g.k_mod.esp.get_dist_to_player(char)

      if dist then
        dist_indicator.Text = math.floor(dist)
      else
        dist_indicator.Text = " "
      end
    end
  end

  _g.k_mod.esp.update_player = function(player)
    pcall(_g.k_mod.esp.update_distance, player)

    _g.k_mod.esp.esp_fun(player,
      _g.k_mod.esp.UseTeamColor and player.TeamColor.Color or
      ((_g.k_mod.player.TeamColor == player.TeamColor) and
      _g.k_mod.esp.FriendColor or _g.k_mod.esp.EnemyColor)
    )
  end

  if first_time_init then
    _g.k_mod.esp.load_all_players()

    Players.PlayerAdded:Connect(function(v)
      pcall(_g.k_mod.esp.load_player, v)
    end)

    Players.PlayerRemoving:Connect(function(v)
      pcall(_g.k_mod.esp.unload_player, v)
    end)
  end

  Players.LocalPlayer.NameDisplayDistance = 0
-- ============================================== ESP END ==============================================

-- ============================================= AIM ASSIST START =============================================
  _g.k_mod.aim_assist.Sensitivity = 0.0 -- How many seconds it takes for the aimbot script to officially lock onto the target's aimpart.
  _g.k_mod.aim_assist.CircleTransparency = 0.25 -- Transparency of the circle.

  _g.k_mod.aim_assist.fov_circle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
  _g.k_mod.aim_assist.fov_circle.Radius = _g.k_mod.aim_assist.fov_radius
  _g.k_mod.aim_assist.fov_circle.Filled = false
  _g.k_mod.aim_assist.fov_circle.Color = Color3.fromRGB(255, 255, 255) -- (RGB) Color that the FOV circle would appear as.
  _g.k_mod.aim_assist.fov_circle.Visible = true
  _g.k_mod.aim_assist.fov_circle.Radius = _g.k_mod.aim_assist.fov_radius
  _g.k_mod.aim_assist.fov_circle.NumSides = 64
  _g.k_mod.aim_assist.fov_circle.Thickness = 2
  if _g.k_mod.aim_assist.enabled then
    _g.k_mod.aim_assist.fov_circle.Transparency = _g.k_mod.aim_assist.CircleTransparency
  else
    _g.k_mod.aim_assist.fov_circle.Transparency = 0.0
  end

  _g.k_mod.aim_assist.assist_to_target = function(target)
    if not target then
      return
    end

    local strenght = _g.k_mod.aim_assist.assisnt_strength
    local Mouse = _g.k_mod.player:GetMouse()
    local posVector3 = Camera:WorldToScreenPoint(target.Position)
    local x, y = posVector3.X - Mouse.X, posVector3.Y - Mouse.Y

    if math.abs(x) > 4 then
      x = math.sign(x) * math.max(math.sqrt(math.abs(x)) * strenght, 4)
    end
    if math.abs(y) > 4 then
      y = math.sign(y) * math.max(math.sqrt(math.abs(y)) * strenght, 4)
    end

    if KRNL_LOADED then
      if x < 0 then
        x = x + 1 + 0xFFFFFFFF
      end
      if y < 0 then
        y = y + 1 + 0xFFFFFFFF
      end
    end

    if _g.k_mod.aim_assist.horizontal_only then
      y = 0
    end

    mousemoverel(x, y)
  end

  _g.k_mod.aim_assist.check_health = function(player)
    if player then
      if player.Character then
        if player.Character:FindFirstChild("Humanoid") and player.Character:FindFirstChild("Humanoid").Health then
          return player.Character:FindFirstChild("Humanoid").Health
        end
        if player.Character["Health"] then
          return player.Character["Health"]
        end
      end
    end

    return -1
  end

  _g.k_mod.aim_assist.find_aim_part = function(character)
    for _, v in ipairs(_g.k_mod.aim_assist.aim_parts) do
      if character:FindFirstChild(v) ~= nil then
        return character[v]
      end
    end

    return nil
  end

  _g.k_mod.aim_assist.get_closest_target = function()
    local max_dist = _g.k_mod.aim_assist.fov_radius
    local target = nil
    local min_depth = math.huge
    local min_dist = math.huge
    local check_health = _g.k_mod.aim_assist.check_health
    local find_aim_part = _g.k_mod.aim_assist.find_aim_part

    for _, v in next, Players:GetPlayers() do
      if v.Name ~= _g.k_mod.player.Name then
        if not _g.k_mod.aim_assist.team_check or v.Team ~= _g.k_mod.player.Team then
          if v.Character ~= nil then
            local success, health = pcall(check_health, v)
            if success and health ~= 0 then
              local aimPart = find_aim_part(v.Character)
              if aimPart then
                local vector3, onScreen = Camera:WorldToViewportPoint(aimPart.Position)
                if vector3.Z >= 0 then
                  local MousePoint = UserInputService:GetMouseLocation()
                  local dist = math.sqrt(math.pow(vector3.X - MousePoint.X, 2) + math.pow(vector3.Y - MousePoint.Y, 2))

                  if dist < max_dist then
                    local dist_diff = min_dist - dist
                    local depth_diff = min_depth / vector3.Z

                    if dist_diff > 0 or depth_diff > 1.2 then
                      target = aimPart
                      min_depth = vector3.Z
                      min_dist = dist
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

    return target
  end
-- ============================================== AIM ASSIST END ==============================================

_g.k_mod.input_ended_handler = function(input, gameProcessed)
  if not gameProcessed and input.KeyCode == _g.k_mod.speedboost.hotkey then
    _g.k_mod.speedboost.enabled = false
    _g.k_mod.set_local_clip(true)
  end
end

_g.k_mod.input_began_handler = function(input, gameProcessed)
  local ctrl, shift = false, false
  local keysPressed = UserInputService:GetKeysPressed()

  for _, key in ipairs(keysPressed) do
    if key.KeyCode == Enum.KeyCode.LeftControl or key.KeyCode == Enum.KeyCode.RightControl then
        ctrl = true
    end
    if key.KeyCode == Enum.KeyCode.LeftShift or key.KeyCode == Enum.KeyCode.RightShift then
        shift = true
    end
  end

  if input.KeyCode == _g.k_mod.aim_assist.toggle_enabled_key then
    _g.k_mod.aim_assist.enabled = not _g.k_mod.aim_assist.enabled
    if _g.k_mod.aim_assist.enabled then
      _g.k_mod.aim_assist.fov_circle.Transparency = _g.k_mod.aim_assist.CircleTransparency
    else
      _g.k_mod.aim_assist.fov_circle.Transparency = 0.0
    end
  end
  if input.KeyCode == _g.k_mod.aim_assist.toggle_team_key then
    _g.k_mod.aim_assist.team_check = not _g.k_mod.aim_assist.team_check
  end
  if input.KeyCode == _g.k_mod.esp.toggle_key then
    _g.k_mod.esp.enabled = not _g.k_mod.esp.enabled
    if _g.k_mod.esp.enabled then
      _g.k_mod.esp.load_all_players()
    else
      _g.k_mod.esp.unload_all_players()
    end
  end
  if not gameProcessed and input.KeyCode == Enum.KeyCode.V then
    _g.k_mod.speedboost.enabled = true
  end
  if input.KeyCode == _g.k_mod.speedboost.increase_boost then
    _g.k_mod.speedboost.speed_mult = _g.k_mod.speedboost.speed_mult + _g.k_mod.speedboost.boost_step
    k_log("speed_mult is :: " .. tostring(_g.k_mod.speedboost.speed_mult))
  end
  if input.KeyCode == _g.k_mod.speedboost.decrease_boost then
    _g.k_mod.speedboost.speed_mult = _g.k_mod.speedboost.speed_mult - _g.k_mod.speedboost.boost_step
    k_log("speed_mult is :: " .. tostring(_g.k_mod.speedboost.speed_mult))
  end
  if ctrl and shift and input.KeyCode == _g.k_mod.rejoin_key then
    _g.k_mod.rejoin_server()
  end
  if input.KeyCode == _g.k_mod.speedboost.toggle_mode then
    if ctrl then
      _g.k_mod.speedboost.clip_mode = not _g.k_mod.speedboost.clip_mode
      k_log("clip_mode is :: " .. tostring(_g.k_mod.speedboost.clip_mode))
    else
      _g.k_mod.speedboost.jump_boost = not _g.k_mod.speedboost.jump_boost
      k_log("jump_boost is :: " .. tostring(_g.k_mod.speedboost.jump_boost))
    end
  end
end

_g.k_mod.on_render_stepped = function()
  _g.k_mod.aim_assist.fov_circle.Position = Vector2.new(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)

  if _g.k_mod.aim_assist.enabled == true then
    local target = _g.k_mod.aim_assist.get_closest_target()
    if target ~= nil then
      if mousemoverel ~= nil then
        _g.k_mod.aim_assist.assist_to_target(target)
      else
        TweenService:Create(Camera, TweenInfo.new(_g.k_mod.aim_assist.Sensitivity, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
        {
          CFrame = CFrame.new(Camera.CFrame.Position, target.Position)
        }):Play()
      end
    end
  end

  pcall(function()
    local char_part = _g.k_mod.aim_assist.find_aim_part(_g.k_mod.get_local_char())
    if char_part then
      _g.k_mod.position = char_part.Position
    end
  end)
  
  for i, v in pairs(Players:GetPlayers()) do
      if v ~= _g.k_mod.player then
        pcall(_g.k_mod.esp.update_player, v)
      end
  end
end

_g.k_mod.on_heartbeat = function(dt)
  _g.k_mod.speedboost.on_heartbeat(dt)
end

_g.k_mod.on_local_char_running = function(speed)
  _g.k_mod.speedboost.record_speed(speed)
end

_g.k_mod.on_local_char_added = function(character)
  character:WaitForChild("Humanoid", math.huge).Running:Connect(function(...) return _g.k_mod.on_local_char_running(...) end)
end

k_log("Current experience :: " .. tostring(game.GameId))

if first_time_init then
  UserInputService.InputBegan:Connect(function(...) return _g.k_mod.input_began_handler(...) end)
  UserInputService.InputEnded:Connect(function(...) return _g.k_mod.input_ended_handler(...) end)
  RunService.RenderStepped:Connect(function(...) return _g.k_mod.on_render_stepped(...) end)
  RunService.Heartbeat:Connect(function(...) return _g.k_mod.on_heartbeat(...) end)
  pcall(function()
    game.Players.LocalPlayer.Character.Humanoid.Running:Connect(function(...) return _g.k_mod.on_local_char_running(...) end)
    game.Players.LocalPlayer.CharacterAdded:Connect(function(...) return _g.k_mod.on_local_char_added(...) end)
  end)

  if game.GameId == 73885730 then
    loadstring(game:HttpGet("https://rawscripts.net/raw/Prison-Life-RoXploit-Gui-Remake-27106"))()
  end
  if game.GameId == 113491250 then
    loadstring(game:HttpGet("https://raw.githubusercontent.com/dementiaenjoyer/homohack/main/loader.lua"))()
  end
end
