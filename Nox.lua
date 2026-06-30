local NOX_URL = "https://raw.githubusercontent.com/N4N0z/ddd/refs/heads/main/Nox.lua"

local okFetch, source = pcall(game.HttpGet, game, NOX_URL)
if not okFetch then
    error("[Nox Hub] Failed to download the UI library: " .. tostring(source), 0)
end
if type(source) ~= "string" or #source < 10000 then
    error(("[Nox Hub] The hosted Nox.lua looks incomplete (%d bytes). Re-upload the full library to GitHub.")
        :format(type(source) == "string" and #source or -1), 0)
end

local chunk, compileErr = loadstring(source)
if not chunk then
    error("[Nox Hub] The UI library failed to compile: " .. tostring(compileErr), 0)
end

local Library = chunk()

do
    local prev = _G.NoxUniversal
    if prev and type(prev.Unload) == "function" then pcall(prev.Unload) end
end
local HUB = { conns = {}, drawings = {}, highlights = {}, dead = false }
_G.NoxUniversal = HUB
local function track(conn) table.insert(HUB.conns, conn); return conn end
local function trackDrawing(d) if d then table.insert(HUB.drawings, d) end; return d end

local Window = Library:CreateWindow({
    Name = "Nox Hub | Universal",
    LoadingAnimation = true,
    LoadingText = "Nox",
    LoadingDuration = 2.5,
})

local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local Workspace          = game:GetService("Workspace")
local Lighting           = game:GetService("Lighting")
local TeleportService    = game:GetService("TeleportService")
local StarterGui         = game:GetService("StarterGui")
local VirtualUser        = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

local HAS_CONFIG  = type(Library.SaveConfig) == "function"
    and type(Library.LoadConfig) == "function"
    and type(Library.ListConfigs) == "function"
local CONFIG_NAME = "universal"

local dropdownResync = {}
local function registerResync(handle, applyFn)
    if handle and applyFn then
        table.insert(dropdownResync, function() applyFn(handle:Get()) end)
    end
end
local function ResyncAll()
    for _, fn in ipairs(dropdownResync) do pcall(fn) end
end

local function GetCharacter() return LocalPlayer.Character end
local function GetHumanoid()
    local c = GetCharacter()
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function GetHRP()
    local c = GetCharacter()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function GetRootCFrame()
    local hrp = GetHRP()
    return hrp and hrp.CFrame
end

local function Notify(title, content, kind, dur)
    Window:Notify({ Title = title, Content = content, Type = kind or "Info", Duration = dur or 2.5 })
end

local PlayerTab = Window:AddTab({ Name = "Player", Subtitle = "Movement & character", Icon = "player" })

local MoveSub = PlayerTab:AddSubTab("Movement")

local wsEnabled, wsValue   = false, 16
local jpEnabled, jpValue   = false, 50
local infJump              = false
local gravityEnabled, gravityValue = false, 196.2
local defaultGravity = Workspace.Gravity

MoveSub:AddSection("Speed & Jump")
MoveSub:AddToggle({
    Name = "WalkSpeed", Default = false, Flag = "ws_enabled",
    Callback = function(v)
        wsEnabled = v
        local hum = GetHumanoid()
        if hum then hum.WalkSpeed = v and wsValue or 16 end
    end,
})
MoveSub:AddSlider({
    Name = "WalkSpeed Value", Min = 16, Max = 500, Default = 16, Suffix = "", Flag = "ws_value",
    Callback = function(v)
        wsValue = v
        if wsEnabled then local hum = GetHumanoid(); if hum then hum.WalkSpeed = v end end
    end,
})
MoveSub:AddToggle({
    Name = "JumpPower", Default = false, Flag = "jp_enabled",
    Callback = function(v)
        jpEnabled = v
        local hum = GetHumanoid()
        if hum then
            hum.UseJumpPower = true
            hum.JumpPower = v and jpValue or 50
        end
    end,
})
MoveSub:AddSlider({
    Name = "JumpPower Value", Min = 50, Max = 500, Default = 50, Suffix = "", Flag = "jp_value",
    Callback = function(v)
        jpValue = v
        if jpEnabled then local hum = GetHumanoid(); if hum then hum.UseJumpPower = true; hum.JumpPower = v end end
    end,
})
MoveSub:AddToggle({
    Name = "Infinite Jump", Default = false, Flag = "inf_jump",
    Callback = function(v) infJump = v end,
})

MoveSub:AddSection("Gravity")
MoveSub:AddToggle({
    Name = "Custom Gravity", Default = false, Flag = "grav_enabled",
    Callback = function(v)
        gravityEnabled = v
        Workspace.Gravity = v and gravityValue or defaultGravity
    end,
})
MoveSub:AddSlider({
    Name = "Gravity", Min = 0, Max = 400, Default = 196, Suffix = "", Flag = "grav_value",
    Callback = function(v)
        gravityValue = v
        if gravityEnabled then Workspace.Gravity = v end
    end,
})

track(LocalPlayer.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid", 10)
    if not hum then return end
    task.wait(0.2)
    if HUB.dead then return end
    if wsEnabled then hum.WalkSpeed = wsValue end
    if jpEnabled then hum.UseJumpPower = true; hum.JumpPower = jpValue end
end))

track(UserInputService.JumpRequest:Connect(function()
    if HUB.dead then return end
    if infJump then
        local hum = GetHumanoid()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end))

local FlySub = PlayerTab:AddSubTab("Fly & Noclip")

local flying, flySpeed = false, 50
local noclip = false
local flyConn, noclipConn

local function startFly()
    local hum = GetHumanoid()
    local hrp = GetHRP()
    if not hum or not hrp then return end
    hum.PlatformStand = true
    if flyConn then flyConn:Disconnect() end
    flyConn = RunService.RenderStepped:Connect(function()
        if HUB.dead or not flying then return end
        local h = GetHumanoid(); local root = GetHRP()
        if not h or not root then return end
        h.PlatformStand = true
        local dir = Vector3.zero
        local cf = Camera.CFrame
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end
        if dir.Magnitude > 0 then dir = dir.Unit * flySpeed else dir = Vector3.zero end
        root.Velocity = dir
        root.RotVelocity = Vector3.zero
    end)
end

local function stopFly()
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    local hum = GetHumanoid()
    if hum then hum.PlatformStand = false end
end

FlySub:AddToggle({
    Name = "Fly", Default = false, Flag = "fly_enabled",
    Callback = function(v)
        flying = v
        if v then startFly() else stopFly() end
        Notify("Fly", v and "Enabled (W/A/S/D, Space, Shift)" or "Disabled", v and "Success" or "Error")
    end,
})
FlySub:AddSlider({
    Name = "Fly Speed", Min = 10, Max = 500, Default = 50, Suffix = "", Flag = "fly_speed",
    Callback = function(v) flySpeed = v end,
})

local function startNoclip()
    if noclipConn then noclipConn:Disconnect() end
    noclipConn = RunService.Stepped:Connect(function()
        if HUB.dead or not noclip then return end
        local char = GetCharacter()
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end)
end

FlySub:AddToggle({
    Name = "Noclip", Default = false, Flag = "noclip_enabled",
    Callback = function(v)
        noclip = v
        if v then startNoclip() elseif noclipConn then noclipConn:Disconnect(); noclipConn = nil end
        Notify("Noclip", v and "Enabled" or "Disabled", v and "Success" or "Error")
    end,
})

local CharSub = PlayerTab:AddSubTab("Character")

CharSub:AddButton({
    Name = "Respawn", Primary = true,
    Callback = function()
        local hum = GetHumanoid()
        if hum then hum.Health = 0 end
        Notify("Character", "Respawning...", "Info")
    end,
})
CharSub:AddButton({
    Name = "Reset Stats",
    Callback = function()
        local hum = GetHumanoid()
        if hum then hum.WalkSpeed = 16; hum.JumpPower = 50; hum.UseJumpPower = true end
        Workspace.Gravity = defaultGravity
        Notify("Character", "Stats reset to default", "Success")
    end,
})

local antiAFK = true
CharSub:AddToggle({
    Name = "Anti-AFK", Default = true, Flag = "anti_afk",
    Callback = function(v) antiAFK = v end,
})

if not _G.NoxUniversalAntiAFK then
    _G.NoxUniversalAntiAFK = true
    LocalPlayer.Idled:Connect(function()
        if antiAFK then
            pcall(function()
                VirtualUser:Button2Down(Vector2.new(0, 0), Camera.CFrame)
                task.wait(1)
                VirtualUser:Button2Up(Vector2.new(0, 0), Camera.CFrame)
            end)
        end
    end)
end

local TpTab = Window:AddTab({ Name = "Teleport", Subtitle = "Players & waypoints", Icon = "teleport" })

local PlayerTpSub = TpTab:AddSubTab("Players")
local selectedPlayer = nil

local function GetPlayerNames()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(names, p.Name) end
    end
    table.sort(names)
    if #names == 0 then names = { "(no other players)" } end
    return names
end

local function ResolvePlayer(name)
    if not name then return nil end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name == name then return p end
    end
    return nil
end

local function applyPlayerSelect(v) selectedPlayer = v end
local playerDropdown = PlayerTpSub:AddDropdown({
    Name = "Player", Options = GetPlayerNames(), Default = nil,
    MaxVisible = 6, Searchable = true, Flag = "tp_player",
    Callback = applyPlayerSelect,
})
registerResync(playerDropdown, applyPlayerSelect)

PlayerTpSub:AddButton({
    Name = "Refresh Players",
    Callback = function()
        playerDropdown:SetOptions(GetPlayerNames())
        Notify("Teleport", "Player list refreshed", "Info")
    end,
})
PlayerTpSub:AddButton({
    Name = "Teleport To Player", Primary = true,
    Callback = function()
        local target = ResolvePlayer(selectedPlayer)
        local myHRP = GetHRP()
        local tHRP = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        if myHRP and tHRP then
            myHRP.CFrame = tHRP.CFrame * CFrame.new(0, 0, 3)
            Notify("Teleport", "Teleported to " .. target.Name, "Success")
        else
            Notify("Teleport", "Target unavailable", "Error")
        end
    end,
})

local following = false
PlayerTpSub:AddToggle({
    Name = "Follow Player", Default = false, Flag = "tp_follow",
    Callback = function(v) following = v end,
})
task.spawn(function()
    while true do
        if HUB.dead then break end
        if following then
            local target = ResolvePlayer(selectedPlayer)
            local myHRP = GetHRP()
            local tHRP = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            if myHRP and tHRP then
                myHRP.CFrame = tHRP.CFrame * CFrame.new(0, 0, 4)
            end
        end
        task.wait(0.4)
    end
end)

local WaypointSub = TpTab:AddSubTab("Waypoints")
local waypoints = {}
local pendingName = "Spot 1"
local selectedWaypoint = nil

local function WaypointNames()
    local names = {}
    for name in pairs(waypoints) do table.insert(names, name) end
    table.sort(names)
    if #names == 0 then names = { "(none)" } end
    return names
end

WaypointSub:AddInput({
    Name = "Waypoint Name", Placeholder = "Spot 1", Default = "Spot 1", Flag = "wp_name",
    Callback = function(text) pendingName = (text ~= "" and text) or "Spot 1" end,
})

local applyWpSelect = function(v) selectedWaypoint = v end
local waypointDropdown

WaypointSub:AddButton({
    Name = "Save Current Position", Primary = true,
    Callback = function()
        local cf = GetRootCFrame()
        if not cf then Notify("Waypoints", "No character", "Error"); return end
        waypoints[pendingName] = cf
        if waypointDropdown then waypointDropdown:SetOptions(WaypointNames()) end
        Notify("Waypoints", "Saved '" .. pendingName .. "'", "Success")
    end,
})

waypointDropdown = WaypointSub:AddDropdown({
    Name = "Saved Waypoints", Options = WaypointNames(), Default = nil,
    MaxVisible = 6, Searchable = true, Flag = "wp_selected",
    Callback = applyWpSelect,
})
registerResync(waypointDropdown, applyWpSelect)

WaypointSub:AddButton({
    Name = "Teleport To Waypoint",
    Callback = function()
        local cf = selectedWaypoint and waypoints[selectedWaypoint]
        local hrp = GetHRP()
        if cf and hrp then
            hrp.CFrame = cf
            Notify("Waypoints", "Teleported to '" .. selectedWaypoint .. "'", "Success")
        else
            Notify("Waypoints", "Waypoint unavailable", "Error")
        end
    end,
})
WaypointSub:AddButton({
    Name = "Delete Waypoint",
    Callback = function()
        if selectedWaypoint and waypoints[selectedWaypoint] then
            local removed = selectedWaypoint
            waypoints[selectedWaypoint] = nil
            waypointDropdown:SetOptions(WaypointNames())
            Notify("Waypoints", "Deleted '" .. removed .. "'", "Info")
        end
    end,
})

local TpMiscSub = TpTab:AddSubTab("Misc")
local clickTp = false

TpMiscSub:AddToggle({
    Name = "Click Teleport", Default = false, Flag = "tp_click",
    Description = "Hold the keybind and click to teleport there",
    Callback = function(v)
        clickTp = v
        Notify("Click TP", v and "Enabled - press key to teleport to cursor" or "Disabled", v and "Success" or "Error")
    end,
})
TpMiscSub:AddKeybind({
    Name = "Click TP Key", Default = Enum.KeyCode.T, Flag = "tp_click_key",
    OnPress = function()
        if not clickTp then return end
        local hrp = GetHRP()
        if not hrp then return end
        local mouseLoc = UserInputService:GetMouseLocation()
        local ray = Camera:ViewportPointToRay(mouseLoc.X, mouseLoc.Y)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { GetCharacter() }
        local result = Workspace:Raycast(ray.Origin, ray.Direction * 5000, params)
        if result then
            hrp.CFrame = CFrame.new(result.Position + Vector3.new(0, 3, 0))
        end
    end,
})
TpMiscSub:AddButton({
    Name = "Teleport To Spawn",
    Callback = function()
        local hrp = GetHRP()
        local spawn = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
        if hrp and spawn then
            hrp.CFrame = spawn.CFrame * CFrame.new(0, 3, 0)
            Notify("Teleport", "Teleported to spawn", "Success")
        else
            Notify("Teleport", "No spawn found", "Error")
        end
    end,
})

local VisualsTab = Window:AddTab({ Name = "Visuals", Subtitle = "ESP & lighting", Icon = "eye" })

local EspSub = VisualsTab:AddSubTab("ESP")

local hasDrawing = (typeof(Drawing) == "table") or (Drawing ~= nil and pcall(function() return Drawing.new end))

local esp = {
    enabled = true, players = true, npcs = false,
    chams = false, chamsFillT = 0.55, chamsOutlineT = 0,
    box = false, boxStyle = "Corner", boxFill = false, boxFillT = 0.8, boxThickness = 1,
    name = false, distance = false, health = false, healthText = false, healthPercent = false,
    tool = false, tracer = false, tracerOrigin = "Bottom",
    skeleton = false, hat = false, arrow = false, look = false,
    halo = false, headCircle = false, ring = false,
    teamCheck = false, friendCheck = false, visibleCheck = false, rainbow = false, smooth = true,
    distanceFade = false, chamsDepth = "AlwaysOnTop",
    maxDistance = 1000, textSize = 14, font = 2,
    color        = Color3.fromRGB(0, 120, 255),
    visibleColor = Color3.fromRGB(95, 220, 120),
    hiddenColor  = Color3.fromRGB(235, 75, 75),
    friendColor  = Color3.fromRGB(95, 150, 255),
    npcColor     = Color3.fromRGB(100, 180, 255),
}
local espObjects = {}
local npcObjects = {}
local FONT_MAP = { UI = 0, System = 1, Plain = 2, Monospace = 3 }

local function getEspParent()
    local ok, parent = pcall(function() return (gethui and gethui()) or game:GetService("CoreGui") end)
    if ok and parent then return parent end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local function newDrawing(class, props)
    if not hasDrawing then return nil end
    local ok, d = pcall(function() return Drawing.new(class) end)
    if not ok or not d then return nil end
    for k, v in pairs(props or {}) do pcall(function() d[k] = v end) end
    return trackDrawing(d)
end

local R15_BONES = {
    {"Head","UpperTorso"}, {"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"}, {"LeftUpperArm","LeftLowerArm"}, {"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"}, {"RightUpperArm","RightLowerArm"}, {"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"}, {"LeftUpperLeg","LeftLowerLeg"}, {"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"}, {"RightUpperLeg","RightLowerLeg"}, {"RightLowerLeg","RightFoot"},
}
local R6_BONES = {
    {"Head","Torso"}, {"Torso","Left Arm"}, {"Torso","Right Arm"},
    {"Torso","Left Leg"}, {"Torso","Right Leg"},
}
local MAX_BONES = #R15_BONES
local RING_SEGMENTS = 16
local DRAW_KEYS = { "boxFill","boxOutline","box","hpOutline","hp","hpText","name","dist","tool","tracer","look","hat","arrow","halo","headCircle" }

local espCounter = 0
local function createEspObject()
    local obj = { skeleton = {}, corners = {}, ring = {} }
    espCounter = espCounter + 1

    local hl = Instance.new("Highlight")
    hl.Name = "NoxESP_" .. espCounter
    hl.FillTransparency = esp.chamsFillT
    hl.OutlineTransparency = esp.chamsOutlineT
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Enabled = false
    pcall(function() hl.Parent = getEspParent() end)
    obj.highlight = hl
    table.insert(HUB.highlights, hl)

    if hasDrawing then
        obj.boxFill    = newDrawing("Square", { Filled = true, Transparency = 0.2, Color = esp.color, ZIndex = 0, Visible = false })
        obj.boxOutline = newDrawing("Square", { Thickness = 3, Filled = false, Color = Color3.new(0,0,0), ZIndex = 1, Visible = false })
        obj.box        = newDrawing("Square", { Thickness = 1, Filled = false, Color = esp.color, ZIndex = 2, Visible = false })
        for i = 1, 8 do obj.corners[i] = newDrawing("Line", { Thickness = 1.5, Color = esp.color, ZIndex = 2, Visible = false }) end
        obj.hpOutline  = newDrawing("Line",   { Thickness = 3, Color = Color3.new(0,0,0), ZIndex = 1, Visible = false })
        obj.hp         = newDrawing("Line",   { Thickness = 1, Color = Color3.fromRGB(0,255,0), ZIndex = 2, Visible = false })
        obj.hpText     = newDrawing("Text",   { Size = 11, Center = false, Outline = true, Font = esp.font, Color = Color3.new(1,1,1), ZIndex = 3, Visible = false })
        obj.name       = newDrawing("Text",   { Size = 14, Center = true, Outline = true, Font = esp.font, Color = esp.color, ZIndex = 3, Visible = false })
        obj.dist       = newDrawing("Text",   { Size = 13, Center = true, Outline = true, Font = esp.font, Color = Color3.new(1,1,1), ZIndex = 3, Visible = false })
        obj.tool       = newDrawing("Text",   { Size = 12, Center = true, Outline = true, Font = esp.font, Color = esp.color, ZIndex = 3, Visible = false })
        obj.tracer     = newDrawing("Line",   { Thickness = 1.5, Color = esp.color, ZIndex = 2, Visible = false })
        obj.look       = newDrawing("Line",   { Thickness = 1.5, Color = Color3.new(1,1,1), ZIndex = 2, Visible = false })
        obj.hat        = newDrawing("Triangle",{ Thickness = 1, Filled = true, Color = esp.color, ZIndex = 2, Visible = false })
        obj.arrow      = newDrawing("Triangle",{ Thickness = 1, Filled = true, Color = esp.color, ZIndex = 2, Visible = false })
        obj.halo       = newDrawing("Circle", { Thickness = 2, Filled = false, Color = esp.color, ZIndex = 2, Visible = false })
        obj.headCircle = newDrawing("Circle", { Thickness = 1.5, Filled = false, Color = esp.color, ZIndex = 2, Visible = false })
        for i = 1, RING_SEGMENTS do
            obj.ring[i] = newDrawing("Line", { Thickness = 1.5, Color = esp.color, ZIndex = 2, Visible = false })
        end
        for i = 1, MAX_BONES do
            obj.skeleton[i] = newDrawing("Line", { Thickness = 1, Color = esp.color, ZIndex = 2, Visible = false })
        end
    end
    return obj
end

local function removeEspObject(obj)
    if not obj then return end
    if obj.highlight then obj.highlight:Destroy() end
    for _, key in ipairs(DRAW_KEYS) do
        if obj[key] then pcall(function() obj[key]:Remove() end) end
    end
    for _, l in ipairs(obj.corners or {}) do pcall(function() l:Remove() end) end
    for _, l in ipairs(obj.ring or {}) do pcall(function() l:Remove() end) end
    for _, l in ipairs(obj.skeleton or {}) do pcall(function() l:Remove() end) end
end

local function createEsp(player)
    if espObjects[player] then return end
    local obj = createEspObject()
    obj.isFriend = false
    task.spawn(function()
        local ok, res = pcall(function() return LocalPlayer:IsFriendsWith(player.UserId) end)
        if ok then obj.isFriend = res == true end
    end)
    espObjects[player] = obj
end

local function removeEsp(player)
    local obj = espObjects[player]
    if not obj then return end
    removeEspObject(obj)
    espObjects[player] = nil
end

local function isFriendlyTeam(player)
    if not esp.teamCheck then return false end
    return player.Team ~= nil and LocalPlayer.Team ~= nil and player.Team == LocalPlayer.Team
end

local function baseColorNow()
    if esp.rainbow then return Color3.fromHSV((tick() * 0.4) % 1, 1, 1) end
    return esp.color
end

local function healthColor(frac)
    return Color3.fromRGB(math.floor(255 * (1 - frac)), math.floor(255 * frac), 0)
end

local function isVisible(char, part)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { GetCharacter(), Camera }
    local origin = Camera.CFrame.Position
    local result = Workspace:Raycast(origin, part.Position - origin, params)
    if not result then return true end
    return result.Instance:IsDescendantOf(char)
end

local function getBox2D(char)
    local cf, size = char:GetBoundingBox()
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local anyOn = false
    for x = -1, 1, 2 do for y = -1, 1, 2 do for z = -1, 1, 2 do
        local corner = (cf * CFrame.new(size.X/2 * x, size.Y/2 * y, size.Z/2 * z)).Position
        local sp, on = Camera:WorldToViewportPoint(corner)
        if sp.Z > 0 then
            anyOn = anyOn or on
            minX = math.min(minX, sp.X); minY = math.min(minY, sp.Y)
            maxX = math.max(maxX, sp.X); maxY = math.max(maxY, sp.Y)
        end
    end end end
    if minX == math.huge then return nil end
    return minX, minY, maxX, maxY, anyOn
end

local function hideObj(obj)
    for _, key in ipairs(DRAW_KEYS) do if obj[key] then obj[key].Visible = false end end
    for _, l in ipairs(obj.corners) do l.Visible = false end
    for _, l in ipairs(obj.ring) do l.Visible = false end
    for _, l in ipairs(obj.skeleton) do l.Visible = false end
    if obj.highlight then obj.highlight.Enabled = false end
end

local function setCornerBox(obj, l, t, r, b, col, thick)
    local L = math.clamp((r - l) * 0.28, 4, 16)
    local segs = {
        {Vector2.new(l, t), Vector2.new(l + L, t)}, {Vector2.new(l, t), Vector2.new(l, t + L)},
        {Vector2.new(r, t), Vector2.new(r - L, t)}, {Vector2.new(r, t), Vector2.new(r, t + L)},
        {Vector2.new(l, b), Vector2.new(l + L, b)}, {Vector2.new(l, b), Vector2.new(l, b - L)},
        {Vector2.new(r, b), Vector2.new(r - L, b)}, {Vector2.new(r, b), Vector2.new(r, b - L)},
    }
    for i, s in ipairs(segs) do
        local line = obj.corners[i]
        line.From, line.To, line.Color, line.Thickness, line.Visible = s[1], s[2], col, thick + 0.5, true
    end
end

local F = {}

local function renderEntity(obj, char, displayName, isPlayer, player)
    local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart or char:FindFirstChildWhichIsA("BasePart"))
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local dist = (hrp and F.myHRP) and (hrp.Position - F.myHRP.Position).Magnitude or 0

    local gate = isPlayer and esp.players or (not isPlayer and esp.npcs)
    local allowed = gate and char ~= nil and hrp ~= nil
        and (esp.maxDistance <= 0 or dist <= esp.maxDistance)
        and (not hum or hum.Health > 0)
    if isPlayer and allowed and isFriendlyTeam(player) then allowed = false end

    local col = isPlayer and F.baseCol or esp.npcColor
    if allowed and isPlayer and esp.friendCheck and obj.isFriend then col = esp.friendColor end
    if allowed and esp.visibleCheck then
        local probe = char:FindFirstChild("Head") or hrp
        col = isVisible(char, probe) and esp.visibleColor or esp.hiddenColor
    end

    if obj.highlight then
        obj.highlight.Enabled = allowed and esp.chams
        if allowed and esp.chams then
            obj.highlight.Adornee = char
            obj.highlight.FillColor = col
            obj.highlight.OutlineColor = col
            obj.highlight.FillTransparency = esp.chamsFillT
            obj.highlight.OutlineTransparency = esp.chamsOutlineT
            obj.highlight.DepthMode = esp.chamsDepth == "Occluded"
                and Enum.HighlightDepthMode.Occluded or Enum.HighlightDepthMode.AlwaysOnTop
        end
    end

    if not hasDrawing then return end
    if not allowed or not F.anyDraw then hideObj(obj); return end

    local fade = esp.distanceFade and math.clamp(1 - dist / math.max(esp.maxDistance, 1), 0.2, 1) or 1
    local rootScreen, rootOn = Camera:WorldToViewportPoint(hrp.Position)
    local onScreen = rootScreen.Z > 0 and rootOn
    local left, top, right, bottom, boxOn = getBox2D(char)
    local haveBox = left ~= nil and boxOn

    if haveBox and esp.smooth then
        local prev = obj._rect
        if prev then
            local a = 0.45
            left   = prev[1] + (left - prev[1]) * a
            top    = prev[2] + (top - prev[2]) * a
            right  = prev[3] + (right - prev[3]) * a
            bottom = prev[4] + (bottom - prev[4]) * a
        end
        obj._rect = { left, top, right, bottom }
    end

    local showFull = esp.box and haveBox and esp.boxStyle == "Full"
    local showCorner = esp.box and haveBox and esp.boxStyle == "Corner"
    obj.box.Visible = showFull
    obj.boxOutline.Visible = showFull
    if showFull then
        local pos = Vector2.new(left, top)
        local sz  = Vector2.new(right - left, bottom - top)
        obj.boxOutline.Position = pos - Vector2.new(1, 1); obj.boxOutline.Size = sz + Vector2.new(2, 2)
        obj.boxOutline.Thickness = esp.boxThickness + 2
        obj.box.Position = pos; obj.box.Size = sz; obj.box.Color = col; obj.box.Thickness = esp.boxThickness
    end
    if showCorner then setCornerBox(obj, left, top, right, bottom, col, esp.boxThickness)
    else for _, l in ipairs(obj.corners) do l.Visible = false end end

    if esp.box and esp.boxFill and haveBox then
        obj.boxFill.Position = Vector2.new(left, top)
        obj.boxFill.Size = Vector2.new(right - left, bottom - top)
        obj.boxFill.Color = col
        obj.boxFill.Transparency = esp.boxFillT * fade
        obj.boxFill.Visible = true
    else obj.boxFill.Visible = false end

    local frac = hum and math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1) or 1
    if esp.health and haveBox and hum then
        local barX = left - 5
        obj.hpOutline.From = Vector2.new(barX, top - 1); obj.hpOutline.To = Vector2.new(barX, bottom + 1); obj.hpOutline.Visible = true
        obj.hp.From = Vector2.new(barX, bottom); obj.hp.To = Vector2.new(barX, bottom - (bottom - top) * frac)
        obj.hp.Color = healthColor(frac); obj.hp.Visible = true
    else obj.hp.Visible = false; obj.hpOutline.Visible = false end

    if esp.healthText and haveBox and hum then
        obj.hpText.Text = esp.healthPercent and (math.floor(frac * 100) .. "%") or tostring(math.floor(hum.Health))
        obj.hpText.Font = esp.font
        obj.hpText.Position = Vector2.new(left - 24, (top + bottom) / 2 - 6)
        obj.hpText.Color = healthColor(frac)
        obj.hpText.Visible = true
    else obj.hpText.Visible = false end

    if esp.name and haveBox then
        obj.name.Text = displayName
        obj.name.Size = esp.textSize
        obj.name.Font = esp.font
        obj.name.Position = Vector2.new((left + right) / 2, top - esp.textSize - 2)
        obj.name.Color = col
        obj.name.Visible = true
    else obj.name.Visible = false end

    if esp.distance and haveBox then
        obj.dist.Text = math.floor(dist) .. "m"
        obj.dist.Size = esp.textSize - 1
        obj.dist.Font = esp.font
        obj.dist.Position = Vector2.new((left + right) / 2, bottom + 2)
        obj.dist.Visible = true
    else obj.dist.Visible = false end

    if esp.tool and haveBox then
        local toolInst = char:FindFirstChildOfClass("Tool")
        if toolInst then
            obj.tool.Text = toolInst.Name
            obj.tool.Size = esp.textSize - 2
            obj.tool.Font = esp.font
            obj.tool.Position = Vector2.new((left + right) / 2, bottom + 2 + (esp.distance and esp.textSize or 0))
            obj.tool.Color = col
            obj.tool.Visible = true
        else obj.tool.Visible = false end
    else obj.tool.Visible = false end

    if esp.tracer and onScreen then
        obj.tracer.From = F.tracerFrom
        obj.tracer.To = Vector2.new(rootScreen.X, rootScreen.Y)
        obj.tracer.Color = col
        obj.tracer.Visible = true
    else obj.tracer.Visible = false end

    if esp.look and char:FindFirstChild("Head") then
        local head = char.Head
        local fromP = Camera:WorldToViewportPoint(head.Position)
        local toP = Camera:WorldToViewportPoint(head.Position + head.CFrame.LookVector * 4)
        if fromP.Z > 0 and toP.Z > 0 then
            obj.look.From = Vector2.new(fromP.X, fromP.Y)
            obj.look.To = Vector2.new(toP.X, toP.Y)
            obj.look.Color = col
            obj.look.Visible = true
        else obj.look.Visible = false end
    else obj.look.Visible = false end

    if esp.hat and char:FindFirstChild("Head") then
        local head = char.Head
        local topPos = head.Position + Vector3.new(0, head.Size.Y * 0.5 + 0.6, 0)
        local sp, on = Camera:WorldToViewportPoint(topPos)
        if sp.Z > 0 and on then
            local apex = Vector2.new(sp.X, sp.Y)
            local w = math.clamp(haveBox and (right - left) * 0.45 or 9, 6, 26)
            local h = w * 1.1
            obj.hat.PointA = apex
            obj.hat.PointB = apex + Vector2.new(-w, -h)
            obj.hat.PointC = apex + Vector2.new(w, -h)
            obj.hat.Color = col
            obj.hat.Visible = true
        else obj.hat.Visible = false end
    else obj.hat.Visible = false end

    if esp.halo and char:FindFirstChild("Head") then
        local head = char.Head
        local topPos = head.Position + Vector3.new(0, head.Size.Y * 0.5 + 1.4, 0)
        local sp, on = Camera:WorldToViewportPoint(topPos)
        if sp.Z > 0 and on then
            obj.halo.Position = Vector2.new(sp.X, sp.Y)
            obj.halo.Radius = math.clamp(haveBox and (right - left) * 0.35 or 10, 6, 34)
            obj.halo.Color = col
            obj.halo.Visible = true
        else obj.halo.Visible = false end
    else obj.halo.Visible = false end

    if esp.headCircle and char:FindFirstChild("Head") then
        local head = char.Head
        local sp, on = Camera:WorldToViewportPoint(head.Position)
        local edge = Camera:WorldToViewportPoint(head.Position + Camera.CFrame.UpVector * (head.Size.Y * 0.6))
        if sp.Z > 0 and on then
            local r = math.clamp((Vector2.new(sp.X, sp.Y) - Vector2.new(edge.X, edge.Y)).Magnitude, 4, 40)
            obj.headCircle.Position = Vector2.new(sp.X, sp.Y)
            obj.headCircle.Radius = r
            obj.headCircle.Color = col
            obj.headCircle.Visible = true
        else obj.headCircle.Visible = false end
    else obj.headCircle.Visible = false end

    if esp.ring then
        local cf, size = char:GetBoundingBox()
        local feetY = cf.Position.Y - size.Y * 0.5
        local centerW = Vector3.new(hrp.Position.X, feetY, hrp.Position.Z)
        local worldR = math.max(size.X, size.Z) * 0.55 + 1
        local pts = {}
        for i = 1, RING_SEGMENTS do
            local a = (i - 1) / RING_SEGMENTS * math.pi * 2
            local wp = centerW + Vector3.new(math.cos(a) * worldR, 0, math.sin(a) * worldR)
            local s = Camera:WorldToViewportPoint(wp)
            pts[i] = { Vector2.new(s.X, s.Y), s.Z > 0 }
        end
        for i = 1, RING_SEGMENTS do
            local a, b = pts[i], pts[i % RING_SEGMENTS + 1]
            local line = obj.ring[i]
            if a[2] and b[2] then
                line.From, line.To, line.Color, line.Visible = a[1], b[1], col, true
            else line.Visible = false end
        end
    else
        for _, l in ipairs(obj.ring) do l.Visible = false end
    end

    if esp.skeleton then
        local bones = char:FindFirstChild("UpperTorso") and R15_BONES or R6_BONES
        local i = 0
        for _, pair in ipairs(bones) do
            local a = char:FindFirstChild(pair[1])
            local b = char:FindFirstChild(pair[2])
            if a and b then
                local sa = Camera:WorldToViewportPoint(a.Position)
                local sb = Camera:WorldToViewportPoint(b.Position)
                if sa.Z > 0 and sb.Z > 0 then
                    i = i + 1
                    local line = obj.skeleton[i]
                    if line then
                        line.From = Vector2.new(sa.X, sa.Y)
                        line.To = Vector2.new(sb.X, sb.Y)
                        line.Color = col
                        line.Visible = true
                    end
                end
            end
        end
        for j = i + 1, MAX_BONES do obj.skeleton[j].Visible = false end
    else
        for _, l in ipairs(obj.skeleton) do l.Visible = false end
    end

    if esp.arrow and not onScreen then
        local dir = Vector2.new(rootScreen.X, rootScreen.Y) - F.center
        if rootScreen.Z < 0 then dir = -dir end
        if dir.Magnitude > 0 then
            dir = dir.Unit
            local arrowPos = F.center + dir * math.min(F.vp.X, F.vp.Y) * 0.32
            local ang = math.atan2(dir.Y, dir.X)
            local s = 16
            obj.arrow.PointA = arrowPos + Vector2.new(math.cos(ang), math.sin(ang)) * s
            obj.arrow.PointB = arrowPos + Vector2.new(math.cos(ang + 2.6), math.sin(ang + 2.6)) * s
            obj.arrow.PointC = arrowPos + Vector2.new(math.cos(ang - 2.6), math.sin(ang - 2.6)) * s
            obj.arrow.Color = col
            obj.arrow.Visible = true
        else obj.arrow.Visible = false end
    else obj.arrow.Visible = false end

    if esp.distanceFade or obj._faded then
        local t = esp.distanceFade and fade or 1
        for _, k in ipairs(DRAW_KEYS) do
            if k ~= "boxFill" then local d = obj[k]; if d and d.Visible then d.Transparency = t end end
        end
        for _, l in ipairs(obj.corners) do if l.Visible then l.Transparency = t end end
        for _, l in ipairs(obj.ring) do if l.Visible then l.Transparency = t end end
        for _, l in ipairs(obj.skeleton) do if l.Visible then l.Transparency = t end end
        obj._faded = esp.distanceFade
    end
end

track(RunService.RenderStepped:Connect(function()
    if HUB.dead then return end

    local anyDraw = esp.box or esp.name or esp.distance or esp.health or esp.healthText
        or esp.tool or esp.tracer or esp.skeleton or esp.hat or esp.arrow or esp.look
        or esp.halo or esp.headCircle or esp.ring
    F.anyDraw = anyDraw

    -- Nothing to render → hide once, then idle. Avoids all per-frame work
    -- (viewport math, GetHRP, per-entity loop) when ESP is off or empty.
    if not (esp.enabled and (anyDraw or esp.chams)) then
        if not F.allHidden then
            for _, obj in pairs(espObjects) do hideObj(obj) end
            for _, obj in pairs(npcObjects) do hideObj(obj) end
            F.allHidden = true
        end
        return
    end
    F.allHidden = false

    F.myHRP = GetHRP()
    F.baseCol = baseColorNow()
    F.vp = Camera.ViewportSize
    F.center = Vector2.new(F.vp.X / 2, F.vp.Y / 2)
    F.tracerFrom = F.center
    if esp.tracerOrigin == "Bottom" then F.tracerFrom = Vector2.new(F.vp.X / 2, F.vp.Y)
    elseif esp.tracerOrigin == "Top" then F.tracerFrom = Vector2.new(F.vp.X / 2, 0)
    elseif esp.tracerOrigin == "Mouse" then
        local m = UserInputService:GetMouseLocation(); F.tracerFrom = Vector2.new(m.X, m.Y)
    end

    for player, obj in pairs(espObjects) do
        renderEntity(obj, player.Character, player.DisplayName, true, player)
    end
    for model, obj in pairs(npcObjects) do
        if model.Parent then renderEntity(obj, model, model.Name, false, nil)
        else hideObj(obj) end
    end
end))

local function isPlayerCharacter(model)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character == model then return true end
    end
    return false
end

local function refreshNPCs()
    if not esp.npcs then
        for model, obj in pairs(npcObjects) do removeEspObject(obj); npcObjects[model] = nil end
        return
    end
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("Humanoid") then
            local model = d.Parent
            if model and model:IsA("Model") and not npcObjects[model] and not isPlayerCharacter(model) then
                local part = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
                if part then npcObjects[model] = createEspObject() end
            end
        end
    end
    for model, obj in pairs(npcObjects) do
        if not model.Parent or not model:FindFirstChildOfClass("Humanoid") or isPlayerCharacter(model) then
            removeEspObject(obj); npcObjects[model] = nil
        end
    end
end

task.spawn(function()
    while not HUB.dead do
        pcall(refreshNPCs)
        task.wait(2)
    end
end)

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then createEsp(p) end
end
track(Players.PlayerAdded:Connect(function(p) if p ~= LocalPlayer then createEsp(p) end end))
track(Players.PlayerRemoving:Connect(removeEsp))

if not hasDrawing then
    EspSub:AddParagraph({
        Title = "Limited ESP Mode",
        Text = "This executor has no Drawing API, so only Chams (Highlight) is available.",
    })
end

EspSub:AddSection("Targets")
EspSub:AddToggle({ Name = "Master Enable", Default = true, Flag = "esp_enabled", Callback = function(v) esp.enabled = v end })
EspSub:AddToggle({ Name = "Players", Default = true, Flag = "esp_players", Callback = function(v) esp.players = v end })
EspSub:AddToggle({ Name = "NPCs", Default = false, Flag = "esp_npcs", Description = "Non-player humanoids (mobs)", Callback = function(v) esp.npcs = v end })

EspSub:AddSection("Boxes")
EspSub:AddToggle({ Name = "2D Box", Default = false, Flag = "esp_box", Callback = function(v) esp.box = v end })
local applyBoxStyle = function(v) esp.boxStyle = v end
local boxStyleDropdown = EspSub:AddDropdown({
    Name = "Box Style", Options = { "Corner", "Full" }, Default = "Corner",
    MaxVisible = 2, Flag = "esp_boxstyle", Callback = applyBoxStyle,
})
registerResync(boxStyleDropdown, applyBoxStyle)
EspSub:AddSlider({ Name = "Box Thickness", Min = 1, Max = 5, Default = 1, Suffix = "", Flag = "esp_boxthick", Callback = function(v) esp.boxThickness = v end })
EspSub:AddToggle({ Name = "Box Fill", Default = false, Flag = "esp_boxfill", Callback = function(v) esp.boxFill = v end })
EspSub:AddSlider({ Name = "Box Fill Opacity", Min = 0, Max = 100, Default = 80, Suffix = "%", Flag = "esp_boxfill_op", Callback = function(v) esp.boxFillT = v / 100 end })

EspSub:AddSection("Chams")
EspSub:AddToggle({ Name = "Chams (Highlight)", Default = false, Flag = "esp_chams", Callback = function(v) esp.chams = v end })
local applyChamsDepth = function(v) esp.chamsDepth = v end
local chamsDepthDropdown = EspSub:AddDropdown({
    Name = "Chams Depth", Options = { "AlwaysOnTop", "Occluded" }, Default = "AlwaysOnTop",
    MaxVisible = 2, Flag = "esp_chamsdepth", Callback = applyChamsDepth,
})
registerResync(chamsDepthDropdown, applyChamsDepth)
EspSub:AddSlider({ Name = "Chams Fill", Min = 0, Max = 100, Default = 45, Suffix = "%", Flag = "esp_chams_fill", Callback = function(v) esp.chamsFillT = 1 - v / 100 end })
EspSub:AddSlider({ Name = "Chams Outline", Min = 0, Max = 100, Default = 100, Suffix = "%", Flag = "esp_chams_out", Callback = function(v) esp.chamsOutlineT = 1 - v / 100 end })

EspSub:AddSection("Text & Bars")
EspSub:AddToggle({ Name = "Name", Default = false, Flag = "esp_name", Callback = function(v) esp.name = v end })
EspSub:AddToggle({ Name = "Distance", Default = false, Flag = "esp_distance", Callback = function(v) esp.distance = v end })
EspSub:AddToggle({ Name = "Held Tool", Default = false, Flag = "esp_tool", Callback = function(v) esp.tool = v end })
EspSub:AddToggle({ Name = "Health Bar", Default = false, Flag = "esp_health", Callback = function(v) esp.health = v end })
EspSub:AddToggle({ Name = "Health Number", Default = false, Flag = "esp_healthtext", Callback = function(v) esp.healthText = v end })
EspSub:AddToggle({ Name = "Health As %", Default = false, Flag = "esp_healthpct", Callback = function(v) esp.healthPercent = v end })
EspSub:AddSlider({ Name = "Text Size", Min = 10, Max = 22, Default = 14, Suffix = "", Flag = "esp_textsize", Callback = function(v) esp.textSize = v end })
local applyFont = function(v) esp.font = FONT_MAP[v] or 2 end
local fontDropdown = EspSub:AddDropdown({
    Name = "Text Font", Options = { "UI", "System", "Plain", "Monospace" }, Default = "Plain",
    MaxVisible = 4, Flag = "esp_font", Callback = applyFont,
})
registerResync(fontDropdown, applyFont)

EspSub:AddSection("Extras")
EspSub:AddToggle({ Name = "Halo (head ring)", Default = false, Flag = "esp_halo", Callback = function(v) esp.halo = v end })
EspSub:AddToggle({ Name = "Head Circle", Default = false, Flag = "esp_headcircle", Callback = function(v) esp.headCircle = v end })
EspSub:AddToggle({ Name = "Ground Ring (3D)", Default = false, Flag = "esp_ring", Callback = function(v) esp.ring = v end })
EspSub:AddToggle({ Name = "Skeleton", Default = false, Flag = "esp_skeleton", Callback = function(v) esp.skeleton = v end })
EspSub:AddToggle({ Name = "Chinese Hat (cone)", Default = false, Flag = "esp_hat", Callback = function(v) esp.hat = v end })
EspSub:AddToggle({ Name = "Look Direction", Default = false, Flag = "esp_look", Callback = function(v) esp.look = v end })
EspSub:AddToggle({ Name = "Tracers", Default = false, Flag = "esp_tracers", Callback = function(v) esp.tracer = v end })
EspSub:AddToggle({ Name = "Off-Screen Arrows", Default = false, Flag = "esp_arrow", Callback = function(v) esp.arrow = v end })
local applyTracerOrigin = function(v) esp.tracerOrigin = v end
local tracerOriginDropdown = EspSub:AddDropdown({
    Name = "Tracer Origin", Options = { "Bottom", "Center", "Top", "Mouse" },
    Default = "Bottom", MaxVisible = 4, Flag = "esp_tracer_origin",
    Callback = applyTracerOrigin,
})
registerResync(tracerOriginDropdown, applyTracerOrigin)

EspSub:AddSection("Behavior")
EspSub:AddToggle({ Name = "Team Check (hide allies)", Default = false, Flag = "esp_team", Callback = function(v) esp.teamCheck = v end })
EspSub:AddToggle({ Name = "Friend Color", Default = false, Flag = "esp_friend", Description = "Color Roblox friends differently", Callback = function(v) esp.friendCheck = v end })
EspSub:AddToggle({
    Name = "Visibility Check", Default = false, Flag = "esp_visible",
    Description = "Color targets by line-of-sight",
    Callback = function(v) esp.visibleCheck = v end,
})
EspSub:AddToggle({ Name = "Box Smoothing", Default = true, Flag = "esp_smooth", Callback = function(v) esp.smooth = v end })
EspSub:AddToggle({ Name = "Distance Fade", Default = false, Flag = "esp_fade", Description = "Fade ESP for far targets", Callback = function(v) esp.distanceFade = v end })
EspSub:AddToggle({ Name = "Rainbow", Default = false, Flag = "esp_rainbow", Callback = function(v) esp.rainbow = v end })
EspSub:AddSlider({
    Name = "Max Distance", Min = 0, Max = 5000, Default = 1000, Suffix = "m", Flag = "esp_maxdist",
    Description = "0 = unlimited", Callback = function(v) esp.maxDistance = v end,
})

EspSub:AddSection("Colors")
EspSub:AddColorPicker({ Name = "Main Color", Default = Color3.fromRGB(0, 120, 255), Flag = "esp_color", Callback = function(c) esp.color = c end })
EspSub:AddColorPicker({ Name = "Visible Color", Default = Color3.fromRGB(95, 220, 120), Flag = "esp_viscolor", Callback = function(c) esp.visibleColor = c end })
EspSub:AddColorPicker({ Name = "Hidden Color", Default = Color3.fromRGB(235, 75, 75), Flag = "esp_hidcolor", Callback = function(c) esp.hiddenColor = c end })
EspSub:AddColorPicker({ Name = "Friend Color", Default = Color3.fromRGB(95, 150, 255), Flag = "esp_friendcolor", Callback = function(c) esp.friendColor = c end })
EspSub:AddColorPicker({ Name = "NPC Color", Default = Color3.fromRGB(100, 180, 255), Flag = "esp_npccolor", Callback = function(c) esp.npcColor = c end })

local WorldSub = VisualsTab:AddSubTab("World")

local fullbright = false
local savedLighting = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd,
    GlobalShadows = Lighting.GlobalShadows,
    Ambient = Lighting.Ambient,
}

WorldSub:AddToggle({
    Name = "Fullbright", Default = false, Flag = "fullbright",
    Callback = function(v)
        fullbright = v
        if v then
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.FogEnd = 1e9
            Lighting.GlobalShadows = false
            Lighting.Ambient = Color3.fromRGB(180, 180, 180)
        else
            Lighting.Brightness = savedLighting.Brightness
            Lighting.ClockTime = savedLighting.ClockTime
            Lighting.FogEnd = savedLighting.FogEnd
            Lighting.GlobalShadows = savedLighting.GlobalShadows
            Lighting.Ambient = savedLighting.Ambient
        end
    end,
})

local defaultFOV = Camera.FieldOfView
WorldSub:AddSlider({
    Name = "Field of View", Min = 30, Max = 120, Default = math.floor(defaultFOV), Suffix = "°", Flag = "fov",
    Callback = function(v) Camera.FieldOfView = v end,
})

local CombatTab = Window:AddTab({ Name = "Combat", Subtitle = "Aimbot", Icon = "target" })
local AimSub = CombatTab:AddSubTab("Aimbot")

local aim = {
    enabled    = false,
    smoothness = 12,
    fov        = 150,
    part       = "Head",
    teamCheck  = false,
    visibleCheck = false,
    aliveCheck = true,
    useRightClick = true,
    altKey     = nil,
    toggleMode = false,
    showFov    = true,
    fovColor   = Color3.fromRGB(0, 120, 255),
}

local mb2Down, altDown, toggleLocked = false, false, false
local function aimWanted()
    if aim.toggleMode then return toggleLocked end
    return (aim.useRightClick and mb2Down) or (aim.altKey ~= nil and altDown)
end

track(UserInputService.InputBegan:Connect(function(input, gp)
    if HUB.dead then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then mb2Down = true end
    if aim.altKey and input.KeyCode == aim.altKey then
        altDown = true
        if aim.toggleMode then toggleLocked = not toggleLocked end
    elseif input.UserInputType == Enum.UserInputType.MouseButton2 and aim.toggleMode and aim.useRightClick then
        toggleLocked = not toggleLocked
    end
end))
track(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then mb2Down = false end
    if aim.altKey and input.KeyCode == aim.altKey then altDown = false end
end))

local fovCircle = newDrawing("Circle", { Thickness = 1.5, Filled = false, Visible = false })

local function getAimPart(char)
    if not char then return nil end
    return char:FindFirstChild(aim.part)
        or char:FindFirstChild("Head")
        or char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("Torso")
end

local function isAlive(char)
    if not aim.aliveCheck then return true end
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    return hum ~= nil and hum.Health > 0
end

local function isVisible(char, part)
    if not aim.visibleCheck then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { GetCharacter() }
    local origin = Camera.CFrame.Position
    local dir = part.Position - origin
    local result = Workspace:Raycast(origin, dir, params)
    if not result then return true end
    return result.Instance:IsDescendantOf(char)
end

local function getClosestTarget()
    local best, bestDist
    local mouse = UserInputService:GetMouseLocation()
    local center = Vector2.new(mouse.X, mouse.Y)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            if aim.teamCheck and p.Team ~= nil and LocalPlayer.Team ~= nil and p.Team == LocalPlayer.Team then
                continue
            end
            local char = p.Character
            local part = getAimPart(char)
            if part and isAlive(char) then
                local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                if onScreen then
                    local d = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                    if d <= aim.fov and (not bestDist or d < bestDist) then
                        if isVisible(char, part) then
                            best, bestDist = part, d
                        end
                    end
                end
            end
        end
    end
    return best
end

track(RunService.RenderStepped:Connect(function()
    if HUB.dead then return end
    if fovCircle then
        fovCircle.Visible = aim.enabled and aim.showFov
        if fovCircle.Visible then
            local mouse = UserInputService:GetMouseLocation()
            fovCircle.Position = Vector2.new(mouse.X, mouse.Y)
            fovCircle.Radius = aim.fov
            fovCircle.Color = aim.fovColor
        end
    end

    if not aim.enabled or not aimWanted() then return end
    local target = getClosestTarget()
    if not target then return end

    local camPos = Camera.CFrame.Position
    local goal = CFrame.new(camPos, target.Position)
    local alpha = math.clamp(1 / math.max(aim.smoothness, 1), 0, 1)
    Camera.CFrame = Camera.CFrame:Lerp(goal, alpha)
end))

AimSub:AddSection("Aimbot")
AimSub:AddToggle({
    Name = "Enabled", Default = false, Flag = "aim_enabled",
    Callback = function(v)
        aim.enabled = v
        if not v then toggleLocked = false end
        Notify("Aimbot", v and "Enabled (hold Right-Click)" or "Disabled", v and "Success" or "Error")
    end,
})
AimSub:AddSlider({
    Name = "Smoothness", Min = 1, Max = 40, Default = 12, Suffix = "",
    Description = "Higher = smoother / slower lock", Flag = "aim_smooth",
    Callback = function(v) aim.smoothness = v end,
})
AimSub:AddSlider({
    Name = "FOV (px)", Min = 30, Max = 600, Default = 150, Suffix = "", Flag = "aim_fov",
    Callback = function(v) aim.fov = v end,
})

local applyAimPart = function(v) aim.part = v end
local aimPartDropdown = AimSub:AddDropdown({
    Name = "Target Part", Options = { "Head", "UpperTorso", "Torso", "HumanoidRootPart" },
    Default = "Head", MaxVisible = 4, Flag = "aim_part",
    Callback = applyAimPart,
})
registerResync(aimPartDropdown, applyAimPart)

AimSub:AddSection("Filters")
AimSub:AddToggle({ Name = "Team Check", Default = false, Flag = "aim_team", Callback = function(v) aim.teamCheck = v end })
AimSub:AddToggle({ Name = "Wall Check (visible only)", Default = false, Flag = "aim_visible", Callback = function(v) aim.visibleCheck = v end })
AimSub:AddToggle({ Name = "Alive Check", Default = true, Flag = "aim_alive", Callback = function(v) aim.aliveCheck = v end })

AimSub:AddSection("Activation")
AimSub:AddToggle({ Name = "Hold Right-Click", Default = true, Flag = "aim_rmb", Callback = function(v) aim.useRightClick = v end })
AimSub:AddToggle({
    Name = "Toggle Mode", Default = false, Flag = "aim_toggle",
    Description = "Press the key/button to lock instead of holding",
    Callback = function(v) aim.toggleMode = v; toggleLocked = false end,
})
AimSub:AddKeybind({
    Name = "Alt Aim Key", Default = nil, Flag = "aim_altkey",
    Callback = function(k) aim.altKey = k; altDown = false end,
})

AimSub:AddSection("FOV Circle")
AimSub:AddToggle({
    Name = "Show FOV Circle", Default = true, Flag = "aim_showfov",
    Description = hasDrawing and "Follows the cursor" or "Drawing API unavailable on this executor",
    Callback = function(v)
        aim.showFov = v and hasDrawing
        if v and not hasDrawing then Notify("Aimbot", "FOV circle needs Drawing API", "Warning", 3) end
    end,
})
AimSub:AddColorPicker({
    Name = "FOV Circle Color", Default = Color3.fromRGB(0, 120, 255), Flag = "aim_fovcolor",
    Callback = function(c) aim.fovColor = c end,
})

-- ── Silent Aim (raycast method) ─────────────────────────────────────────────
-- KILLSTREAK ships an internal aim-assist module at
-- PlayerScripts.Client.Handicap.Systems.SilentAim. The weapon fire code
-- (WeaponAttack_FireBullet) asks SilentAim:getInstance():getPivotCFrame(camera)
-- every shot and, when it returns a CFrame, casts the bullet RAY down that
-- vector instead of the camera's. So enabling + widening that singleton bends
-- each shot's raycast onto the closest visible enemy. The server trusts the
-- client's raycast, so it's a true silent lock with NO camera movement.
local SilentSub = CombatTab:AddSubTab("Silent Aim")

local silent = {
    enabled  = false,
    fov      = 360,   -- angular FOV in degrees (360 = whole screen)
    range    = 1000,
    minRange = 0,
    headOnly = false,
    wallbang = false, -- pierce walls + lock targets through geometry
}
local DEFAULT_BONES = { "Head", "UpperTorso", "LowerTorso" }
local WALLBANG_ATTR = "Wallbangable"
local WALLBANG_THRESHOLD = 1e9   -- beats every wall's own Wallbangable value

local function findByPath(root, ...)
    local node = root
    for _, name in ipairs({ ... }) do
        if not node then return nil end
        node = node:FindFirstChild(name)
    end
    return node
end

local function safeRequire(inst)
    if not inst then return nil end
    local ok, mod = pcall(require, inst)
    if ok then return mod end
    return nil
end

-- IMPORTANT: the Sakura framework loads modules by requiring the ORIGINALS under
-- StarterPlayer.StarterPlayerScripts.Client (see SakuraBootstrapper), NOT the
-- per-player copies under PlayerScripts. Requiring the PlayerScripts copies gives
-- a second, dead instance the game never consults. Always use the StarterPlayer
-- originals so we touch the live singletons the weapon code actually reads.
local rf  = game:GetService("ReplicatedFirst")
local sps = findByPath(game:GetService("StarterPlayer"), "StarterPlayerScripts")

local SAClass  = safeRequire(findByPath(sps, "Client", "Handicap", "Systems", "SilentAim"))
local FOVUtil  = safeRequire(findByPath(rf, "Sakura", "Util", "FOVUtil"))
local VisUtil  = safeRequire(findByPath(rf, "Sakura", "Util", "VisibilityUtil"))
local TargetU  = safeRequire(findByPath(sps, "Client", "Handicap", "TargetUtil"))
local WeaponC  = safeRequire(findByPath(sps, "Client", "Weapon", "WeaponClient"))

local SUPPORTED = SAClass and FOVUtil and TargetU

-- Pick the best lock target ourselves using our own FOV/range, optionally
-- skipping the line-of-sight test for wall bang.
local function pickTarget(camCF)
    local origin = camCF.Position
    local bones  = silent.headOnly and { "Head" } or DEFAULT_BONES
    local visParams = (not silent.wallbang) and TargetU:getRaycastParams() or nil
    local best, bestScore = nil, math.huge
    for _, t in TargetU:getValidTargets() do
        local inst = t.Instance
        for _, boneName in ipairs(bones) do
            local bone = inst:FindFirstChild(boneName)
            if bone and bone:IsA("BasePart") then
                local pos = bone.Position
                local d = (pos - origin).Magnitude
                if d <= silent.range and d >= silent.minRange then
                    local ang = FOVUtil:calculateAngle(camCF, pos)
                    if ang <= silent.fov / 2 and ang < bestScore then
                        if silent.wallbang or not VisUtil
                            or VisUtil:isPositionVisible(origin, pos, visParams) then
                            best, bestScore = pos, ang
                        end
                    end
                end
            end
        end
    end
    return best
end

-- Replace SilentAim:getPivotCFrame on the class. WeaponAttack_FireBullet calls
-- getInstance():getPivotCFrame(camera) every shot and aims the bullet ray down
-- whatever CFrame we return. Overriding the method (not the instance flags) means
-- the game's handicap controller toggling Enabled / zeroing the FOV can't fight us.
local function installOverride()
    if not SUPPORTED or SAClass.__noxOverride then return end
    local realPivot = SAClass.getPivotCFrame
    SAClass.getPivotCFrame = function(self, camCF)
        if not silent.enabled then return realPivot(self, camCF) end
        local pos = pickTarget(camCF)
        if pos then return CFrame.lookAt(camCF.Position, pos) end
        return nil   -- no target -> normal shot
    end
    SAClass.__noxOverride = true
end

-- Make sure a singleton exists so getInstance() is non-nil and the fire path
-- actually calls getPivotCFrame.
local function ensureInstance()
    if not SAClass then return end
    local inst = SAClass.getInstance and SAClass:getInstance()
    if not inst and SAClass.new then pcall(SAClass.new) end
end

local function applyWallbang()
    -- 1) Workspace attr covers parts that have no Wallbangable of their own (the
    --    weapon walks ancestors until it finds one, reaching Workspace).
    -- 2) Walls DO carry their own Wallbangable (drywall=1, concrete/steel=2...),
    --    found before Workspace, so we also raise the equipped weapon's
    --    WallbangThreshold above all of them to force penetration.
    pcall(function()
        Workspace:SetAttribute(WALLBANG_ATTR, silent.wallbang and -1e9 or nil)
    end)
    if WeaponC then
        local cw = WeaponC.CurrentWeapon
        if cw then
            if silent.wallbang then
                if cw.__noxOldWB == nil then cw.__noxOldWB = cw.WallbangThreshold or 0 end
                cw.WallbangThreshold = WALLBANG_THRESHOLD
            elseif cw.__noxOldWB ~= nil then
                cw.WallbangThreshold = cw.__noxOldWB
                cw.__noxOldWB = nil
            end
        end
    end
end

local function applySilent()
    installOverride()
    if silent.enabled then ensureInstance() end
    applyWallbang()
end

if not SUPPORTED then
    SilentSub:AddSection("Silent Aim — Raycast")
    SilentSub:AddParagraph({
        Title = "Unavailable",
        Content = "This game has no internal raycast aim module. Use the Aimbot tab instead.",
    })
else
    SilentSub:AddSection("Silent Aim — Raycast")
    SilentSub:AddParagraph({
        Title = "Raycast method",
        Content = "Redirects every shot's bullet ray onto the closest enemy inside the FOV. No camera movement — just fire and it locks. Turn on Wall Bang below to shoot through walls and lock enemies behind cover.",
    })
    SilentSub:AddToggle({
        Name = "Enabled", Default = false, Flag = "silent_enabled",
        Callback = function(v)
            silent.enabled = v
            applySilent()
            Notify("Silent Aim", v and "Enabled — fire to lock" or "Disabled", v and "Success" or "Error")
        end,
    })
    SilentSub:AddSlider({
        Name = "FOV", Min = 1, Max = 360, Default = 360, Suffix = "°", Flag = "silent_fov",
        Description = "Angular cone the lock searches inside",
        Callback = function(v) silent.fov = v end,
    })
    SilentSub:AddSlider({
        Name = "Range", Min = 50, Max = 5000, Default = 1000, Suffix = "", Flag = "silent_range",
        Callback = function(v) silent.range = v end,
    })
    SilentSub:AddSlider({
        Name = "Min Range", Min = 0, Max = 50, Default = 0, Suffix = "", Flag = "silent_minrange",
        Callback = function(v) silent.minRange = v end,
    })
    SilentSub:AddToggle({
        Name = "Headshot Only", Default = false, Flag = "silent_head",
        Description = "Lock the ray onto heads only",
        Callback = function(v) silent.headOnly = v end,
    })

    SilentSub:AddSection("Wall Bang")
    SilentSub:AddToggle({
        Name = "Bullets Through Walls", Default = false, Flag = "silent_wallbang",
        Description = "Pierce all geometry and lock onto enemies behind walls",
        Callback = function(v)
            silent.wallbang = v
            applySilent()
            Notify("Silent Aim", v and "Wallbang ON — shots pierce walls" or "Wallbang OFF", v and "Success" or "Error")
        end,
    })

    installOverride()

    -- Keep the singleton alive (the game may destroy it for mouse players) and,
    -- while wall bang is on, keep raising the currently-equipped weapon's
    -- threshold so it survives weapon switches.
    track(RunService.Heartbeat:Connect(function()
        if HUB.dead then return end
        if silent.enabled then ensureInstance() end
        if silent.wallbang then applyWallbang() end
    end))
end

-- ════════════════════════════════════════════════════════════════════════════
-- GAME SUPPORT FRAMEWORK
-- The universal tabs above load in every game. Each entry in SupportedGames is
-- keyed by universe GameId; if the current game matches, its Build() runs and
-- adds a dedicated tab with that game's features. Unsupported games simply run
-- the universal hub. To support a new game, add another SupportedGames[id].
-- ════════════════════════════════════════════════════════════════════════════
local SupportedGames = {}

-- executor signal-fire (different executors expose it under different names)
local fireSignal = firesignal
    or (getgenv and getgenv().firesignal)
    or replicatesignal
local HAS_FIRESIGNAL = type(fireSignal) == "function"

-- ─── Looksmax & Mog  (universe 10126164619) ─────────────────────────────────
SupportedGames[10126164619] = {
    Name = "Looksmax & Mog",
    Build = function()
        local GameTab = Window:AddTab({ Name = "Game", Subtitle = "Looksmax & Mog", Icon = "rbxasset://textures/ui/Controls/DefaultController/Thumbstick1@2x.png" })
        -- promote the supported-game tab to the front of the hotbar (main tab)
        pcall(function() GameTab._hBtn.LayoutOrder = -1 end)
        local AutoClickSub = GameTab:AddSubTab("Auto Click")

        local autoMog   = false   -- master: solve every mog-battle minigame
        local autoGym   = false   -- reps + auto-treadmill when fatigued
        local barClicks = 25      -- tug-of-war Activated fires per frame

        local function fireActivated(btn)
            if btn and HAS_FIRESIGNAL then
                pcall(fireSignal, btn.Activated)
            end
        end

        -- The gym uses two minigame singletons (require returns the live tables
        -- the game itself drives). One handles Bench/Squat (ClickBar), the other
        -- LatPulldown/Curl (DragBar). Driving them directly = one toggle does
        -- ALL exercises with Perfect form, whatever machine you're on.
        local GymClick, GymDrag, GymWork
        do
            local ok, base = pcall(function()
                return LocalPlayer.PlayerScripts.Client.Controllers.Gym
            end)
            if ok and base then
                pcall(function() GymClick = require(base.GymClickBarMinigame) end)
                pcall(function() GymDrag  = require(base.GymDragBarMinigame) end)
                pcall(function() GymWork  = require(base.GymWorkoutClient) end)
            end
        end

        -- Auto Treadmill: hold the player on the best treadmill their BODY LEVEL
        -- unlocks. The server gates by level (and gates Golden/Rainbow by
        -- gamepass, so those are excluded). Re-asserting HRP every frame beats
        -- the server's position revert; the game's own zone detection (~14 studs)
        -- then reports the treadmill and body XP accrues.
        local GymCtrl, GymLevelUI
        pcall(function() GymCtrl    = require(LocalPlayer.PlayerScripts.Client.Controllers.GymController) end)
        pcall(function() GymLevelUI = require(LocalPlayer.PlayerScripts.Client.Controllers.Gym.GymLevelUI) end)
        local TREADMILLS = {   -- best XP first; req = body level required
            { name = "Level7Treadmill", req = 7 },
            { name = "Level3Treadmill", req = 5 },
            { name = "Level2Treadmill", req = 3 },
            { name = "Level1Treadmill", req = 1 },
        }
        local treadTarget, treadName, lastTreadScan = nil, nil, 0
        local treadModel, treadZonePart, gameTreadOff = nil, nil, false
        local function bodyLevel()
            -- The HUD "Body Level: N" label is populated from the initial profile
            -- sync, so it's correct right after joining (unlike LastKnownBodyLevel,
            -- which only updates when a GymProgressUpdated event fires). Fall back
            -- to the gym module state, then 1.
            local pg  = LocalPlayer:FindFirstChild("PlayerGui")
            local hud = pg and pg:FindFirstChild("Hud")
            local gl  = hud and hud:FindFirstChild("GymLevel")
            local bl  = gl and gl:FindFirstChild("BodyLevel")
            if bl and bl:IsA("TextLabel") then
                local n = tostring(bl.Text):match("(%d+)")
                if n then return tonumber(n) end
            end
            if GymLevelUI and tonumber(GymLevelUI.LastBodyLevel) then return tonumber(GymLevelUI.LastBodyLevel) end
            if GymCtrl and tonumber(GymCtrl.LastKnownBodyLevel) then return tonumber(GymCtrl.LastKnownBodyLevel) end
            return 1
        end
        local function pickTreadmill()
            local lvl = bodyLevel()
            for _, t in ipairs(TREADMILLS) do
                if lvl >= t.req then return t.name end
            end
            return "Level1Treadmill"
        end
        local function nearestTread(name)
            -- returns BOTH the treadmill model and its zone part, so we can
            -- direct-drive the server (SendTreadmillZoneState needs the model).
            local gym = Workspace:FindFirstChild("Gym")
            local hrp = GetHRP()
            if not gym or not hrp then return nil, nil end
            local bestM, bestZ, bestD
            for _, d in ipairs(gym:GetDescendants()) do
                if d:IsA("Model") and d.Name == name then
                    local zp = d:FindFirstChild("Runway", true) or d:FindFirstChildWhichIsA("BasePart", true)
                    if zp then
                        local dist = (hrp.Position - zp.Position).Magnitude
                        if not bestD or dist < bestD then bestD, bestM, bestZ = dist, d, zp end
                    end
                end
            end
            return bestM, bestZ
        end

        -- Kill the game's own nearest-treadmill detection so it can't pick a
        -- closer BASIC treadmill out from under us. We re-assert the chosen
        -- (best) zone every frame via SendTreadmillZoneState instead.
        local function suppressGameTread()
            if gameTreadOff then return end
            pcall(function()
                if GymWork and GymWork.TreadmillZoneConnection then
                    GymWork.TreadmillZoneConnection:Disconnect()
                    GymWork.TreadmillZoneConnection = nil
                end
            end)
            gameTreadOff = true
        end
        local function restoreGameTread()
            if not gameTreadOff then return end
            pcall(function()
                if GymWork and GymWork.StartTreadmillZoneDetection then
                    GymWork:StartTreadmillZoneDetection()
                end
            end)
            gameTreadOff = false
        end

        local function driveTreadmill()
            local now = os.clock()
            -- re-pick / re-locate at most once a second (handles level-ups & moving)
            if not treadTarget or (now - lastTreadScan) > 1 then
                lastTreadScan = now
                local name = pickTreadmill()
                local m, zp = nearestTread(name)
                if m and zp then
                    treadName, treadModel, treadZonePart = name, m, zp
                    treadTarget = zp.Position + Vector3.new(0, 3, 0)
                else
                    treadModel, treadZonePart, treadTarget = nil, nil, nil
                end
            end
            if treadTarget and treadZonePart and treadModel then
                suppressGameTread()                      -- block the game's basic-treadmill pick
                local hrp = GetHRP()
                if hrp then hrp.CFrame = CFrame.new(treadTarget) end
                -- force-report OUR chosen best treadmill to the server every frame
                pcall(function() GymWork:SendTreadmillZoneState(treadZonePart, treadModel) end)
            end
        end

        -- ShapeTouch ("scan") minigame singleton. Shapes are 3D models tracked
        -- in .Animations; each has ShapeKind/BattleId attributes. Claiming a
        -- non-bomb shape via PlayShapeClickFeedback scores it instantly.
        local ShapeTouch
        do
            local ok, mod = pcall(function()
                return LocalPlayer.PlayerScripts.Client.UI.Mogging.MoggingShapeTouchClient
            end)
            if ok and mod then
                pcall(function() ShapeTouch = require(mod) end)
            end
        end

        local function driveShapeTouch()
            if not ShapeTouch or ShapeTouch.Running ~= true then return end
            local battleId = ShapeTouch.ActiveBattleId
            local clicked  = ShapeTouch.ClickedModels
            local function claim(model)
                if typeof(model) == "Instance" and model.Parent ~= nil
                    and (type(clicked) ~= "table" or clicked[model] ~= true)
                    and model:GetAttribute("ShapeKind") ~= "Bomb"           -- never touch bombs
                    and model:GetAttribute("BattleId") == battleId then
                    pcall(function() ShapeTouch:PlayShapeClickFeedback(model) end)
                end
            end
            -- LocalShapesById is the authoritative spawn registry (keyed by ShapeId);
            -- Animations is only the subset with running tweens, so check both.
            if type(ShapeTouch.LocalShapesById) == "table" then
                for _, model in pairs(ShapeTouch.LocalShapesById) do claim(model) end
            end
            if type(ShapeTouch.Animations) == "table" then
                for model in pairs(ShapeTouch.Animations) do claim(model) end
            end
        end

        -- MoggingQTEClient = the "osu" timing circles. Unlike the spam circles
        -- (instant click = Perfect), these score on a shrinking-ring timing:
        -- Perfect only fires when reaction progress >= ReactionPerfectAt (~0.92).
        -- So we wait for each target's window instead of clicking on spawn.
        local QTE
        do
            local ok, mod = pcall(function()
                return LocalPlayer.PlayerScripts.Client.UI.Mogging.MoggingQTEClient
            end)
            if ok and mod then pcall(function() QTE = require(mod) end) end
        end

        local function driveQTE()
            if not QTE or QTE.Running ~= true then return end
            local targets = QTE.ActiveTargets
            if type(targets) ~= "table" then return end
            for btn, data in pairs(targets) do
                if typeof(btn) == "Instance" and btn.Parent ~= nil
                    and type(data) == "table" and data.Clicked ~= true then
                    local dur  = tonumber(data.CountdownDuration) or 3
                    local prog = (os.clock() - (tonumber(data.SpawnedAt) or 0)) / math.max(0.1, dur)
                    if prog >= 0.93 then   -- inside the Perfect window (ReactionPerfectAt ~0.92)
                        fireActivated(btn)
                    end
                end
            end
        end

        -- MoggingMusicMinigameClient = the "osu mania" A/S/D falling-note lanes.
        -- A note scores Perfect when it reaches the hit marker; we force Perfect
        -- via the game's own FinishTarget once the note is essentially on it.
        local Music
        do
            local ok, mod = pcall(function()
                return LocalPlayer.PlayerScripts.Client.UI.Mogging.MoggingMusicMinigameClient
            end)
            if ok and mod then pcall(function() Music = require(mod) end) end
        end

        local function driveMusic()
            if not Music or Music.Running ~= true then return end
            local targets = Music.ActiveTargets
            if type(targets) ~= "table" then return end
            for lane, data in pairs(targets) do
                if type(data) == "table" and data.MarkedMiss ~= true
                    and data.Model and data.Model.Parent then
                    local prog = (os.clock() - (tonumber(data.StartedAt) or 0)) / math.max(0.1, tonumber(data.TravelTime) or 1)
                    if prog >= 0.9 then   -- note is on/near the hit marker
                        pcall(function() Music:FinishTarget(lane, "Perfect") end)
                    end
                end
            end
        end

        -- MoggingArrowQTEClient = the sweeping arrow / green-zone timing bar.
        -- Let the game judge: when its OWN EvaluateInput reports Perfect, submit.
        local Arrow
        do
            local ok, mod = pcall(function()
                return LocalPlayer.PlayerScripts.Client.UI.Mogging.MoggingArrowQTEClient
            end)
            if ok and mod then pcall(function() Arrow = require(mod) end) end
        end

        local function driveArrow()
            if not Arrow or Arrow.Running ~= true or Arrow.Paused == true then return end
            -- snap the arrow onto the target centre so the game's own judge
            -- (|Position - TargetCenter| <= PerfectHalfWidth) is always Perfect
            if type(Arrow.TargetCenter) == "number" then
                Arrow.Position = Arrow.TargetCenter
            end
            pcall(function() Arrow:SubmitInput(Arrow.ComputerButton) end)
        end

        local function driveGymClick()
            -- Bench Press / Squat: fill the bar and bank a Perfect rep each cooldown.
            if GymClick and GymClick.Running == true and GymClick.Reversing ~= true then
                GymClick.ActiveRepStarted   = true
                GymClick.ActiveRepStartedAt = os.clock()   -- ~0 elapsed => Perfect form
                GymClick.Fill               = 1
                pcall(function() GymClick:CompleteRep() end)
            end
        end

        local function driveGymDrag()
            -- Lat Pulldown / Curl: feign a drag to the endpoint; the game's own
            -- Step loop then flips to the release phase and banks the rep.
            if GymDrag and GymDrag.Running == true and GymDrag.Phase == "Forward" then
                local frame = GymDrag.Frame
                if frame then
                    local ap, sz = frame.AbsolutePosition, frame.AbsoluteSize
                    GymDrag.PointerPosition = Vector2.new(ap.X + sz.X * 0.5, ap.Y + sz.Y * 0.5)
                end
                GymDrag.Dragging       = true
                GymDrag.LastSafeAreaAt = os.clock()
                GymDrag.TargetProgress = 1
            end
        end

        -- ONE merged gym farm: bank Perfect reps until fatigued, then run the
        -- best body-level treadmill. It ALSO upgrades you to the best treadmill
        -- whenever you're standing on any treadmill (so you never get stuck on
        -- the basic one). `repSpot` remembers where you were repping.
        local repSpot
        local function onAnyTreadmill()
            local k = GymWork and GymWork.CurrentTreadmillZoneKey
            return type(k) == "string" and k ~= ""
        end
        local function driveGymFarm()
            local ratio      = (GymWork and tonumber(GymWork.CurrentFatigueRatio)) or 0
            local repRunning = (GymClick and GymClick.Running == true) or (GymDrag and GymDrag.Running == true)
            if repRunning and ratio < 0.95 then
                -- fresh & on a machine: remember the spot and bank Perfect reps
                restoreGameTread(); treadTarget = nil
                local hrp = GetHRP(); if hrp then repSpot = hrp.CFrame end
                driveGymClick()
                driveGymDrag()
            elseif ratio >= 0.95 or onAnyTreadmill() then
                -- fatigued, OR standing on ANY treadmill -> force the BEST one
                driveTreadmill()
            elseif repSpot then
                -- recovered and off the treadmill: head back to the machine
                restoreGameTread(); treadTarget = nil
                local hrp = GetHRP(); if hrp then hrp.CFrame = repSpot end
            end
        end

        -- Mogging: targets are clones named "ActiveClickMinigameButton" with an
        -- .Activated handler that scores instantly. Fire them as they spawn.
        track(LocalPlayer:WaitForChild("PlayerGui").DescendantAdded:Connect(function(d)
            if HUB.dead or not autoMog then return end
            if d.Name == "ActiveClickMinigameButton" and d:IsA("GuiButton") then
                task.defer(function()
                    if not HUB.dead and autoMog then fireActivated(d) end
                end)
            end
        end))

        local function getClickBtn(frame)
            return frame and frame.Visible and frame:FindFirstChild("ClickButton")
        end

        local function driveClickSpam(pg)
            -- spam-circle minigame: instant click = Perfect. Only scan the
            -- Mogging GUI subtree (and only if present) instead of all PlayerGui.
            local mog = pg:FindFirstChild("Mogging")
            if not mog then return end
            for _, d in ipairs(mog:GetDescendants()) do
                if d.Name == "ActiveClickMinigameButton" and d:IsA("GuiButton") then
                    fireActivated(d)
                end
            end
        end

        local function driveTug(pg)
            for _, guiName in ipairs({ "Session", "Session2v2" }) do
                local s = pg:FindFirstChild(guiName)
                local btn = getClickBtn(s and s:FindFirstChild("TugofWarBar"))
                if btn then
                    for _ = 1, barClicks do fireActivated(btn) end
                end
            end
        end

        -- ONE entry point that solves whatever mog-battle minigame is on screen.
        -- Each driver self-guards on its module's Running flag / element presence,
        -- so running them all every frame is safe and covers every situation.
        local function solveMogBattle(pg)
            driveClickSpam(pg)   -- spam circles
            driveQTE()           -- osu timing circles
            driveShapeTouch()    -- scan shapes (skips bombs)
            driveMusic()         -- osu-mania A/S/D lanes
            driveArrow()         -- sweeping arrow / green zone
            driveTug(pg)         -- tug of war bar
        end

        track(RunService.Heartbeat:Connect(function()
            if HUB.dead then return end
            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            if not pg then return end

            if autoMog then solveMogBattle(pg) end   -- every mog-battle minigame
        end))

        -- ── Auto Queue ──────────────────────────────────────────────────────
        -- The whole matchmaking flow (MoggingController) collapses to one
        -- client->server call:
        --     F.ClientToServer.Fire("StartMogging", { Mode = "1v1"/"2v2", DeviceType })
        -- and "CancelMoggingQueue" leaves the queue. State is readable from the
        -- PlayerGui: "Matchmaking" is on while searching, "Session"/"Session2v2"
        -- during a battle, "Conclusion"/"BossConclusion" right after. So we only
        -- (re)fire when NONE of those are showing -> you're back in the lobby.
        -- Pair with "Auto Mog Battle" for a hands-off farm: queue, solve, requeue.
        local autoQueue, queueMode = false, "1v1"
        local F
        do
            local ok, mod = pcall(function()
                return require(game:GetService("ReplicatedStorage").Shared.Lib.F)
            end)
            if ok then F = mod end
        end
        local MogUtil
        do
            local ok, u = pcall(function()
                return require(LocalPlayer.PlayerScripts.Client.UI.Mogging.MoggingUIUtil)
            end)
            if ok then MogUtil = u end
        end
        local function canFire()
            return F and type(F.ClientToServer) == "table" and type(F.ClientToServer.Fire) == "function"
        end
        local function deviceType()
            if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then return "Touch" end
            if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then return "Gamepad" end
            return "KeyboardMouse"
        end

        -- IMPORTANT: GUI .Enabled flags are NOT reliable for "am I in a match" -- during
        -- a battle every mogging GUI can read false while MoggingController still holds an
        -- ActiveSessionBattleId (which itself is never cleared, so it's useless too). The
        -- only trustworthy signal is the server's own match lifecycle. F.Listen APPENDS
        -- handlers, so we ride alongside the game's: stay "busy" from search start through
        -- the entire match, and only allow a requeue a few seconds after MoggingSessionFinished.
        local mogBusy = false
        if F and type(F.ServerToClient) == "table" and type(F.ServerToClient.Listen) == "function" then
            pcall(function()
                F.ServerToClient.Listen({
                    MoggingSearchStarted       = function() mogBusy = true end,
                    MoggingOpponentFound       = function() mogBusy = true end,
                    MoggingSessionStarted      = function() mogBusy = true end,
                    MoggingSessionReadyToStart = function() mogBusy = true end,
                    MoggingSearchFailed        = function() mogBusy = false end,
                    MoggingSessionFinished     = function()
                        -- match over; let the results screen show, then re-allow queueing
                        task.delay(4, function() mogBusy = false end)
                    end,
                })
            end)
        end

        -- live "in a battle / searching right now" backstop, independent of the events
        local function inSessionNow(pg)
            if MogUtil and MogUtil.SessionActive == true then return true end
            for _, n in ipairs({ "Session", "Session2v2", "Matchmaking", "Conclusion", "BossConclusion" }) do
                local g = pg:FindFirstChild(n)
                if g and g.Enabled then return true end
            end
            return false
        end

        local function fireQueue(mode)
            if not canFire() then return false end
            pcall(function()
                F.ClientToServer.Fire("StartMogging", { Mode = mode, DeviceType = deviceType() })
            end)
            return true
        end
        local function leaveQueue()
            mogBusy = false
            if not canFire() then return end
            pcall(function() F.ClientToServer.Fire("CancelMoggingQueue", {}) end)
        end

        local nextQueueAt = 0
        track(RunService.Heartbeat:Connect(function()
            if HUB.dead or not autoQueue then return end
            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            if not pg then return end
            if mogBusy or inSessionNow(pg) then return end   -- searching or mid-match -> never requeue
            local now = os.clock()
            if now < nextQueueAt then return end
            if fireQueue(queueMode) then
                nextQueueAt = now + 5     -- cooldown until MoggingSearchStarted flips mogBusy
            end
        end))

        -- ── Auto Gym Farm ───────────────────────────────────────────────────
        -- A workout can ONLY be started by the machine's server-side ProximityPrompt
        -- (there is no "start workout" remote). So we walk to a FREE machine, hold its
        -- prompt (fireproximityprompt), then let the rep solver bank Perfect reps.
        --
        -- Two live data sources from GymMachineHighlightController drive the routing:
        --   MachineClaims[GymMachineId] = { UserId, DisplayName }  -> who's on each machine
        --   FatigueStates[ExerciseType] = { Exhausted, Remaining, ResetEndsAtClient, Limit }
        -- Fatigue is PER-EXERCISE (maxing Bench doesn't block Squat/Lat/Curl), each has
        -- its own ~30s reset, and the Limit scales with body level. So we: pick an
        -- exercise that isn't resting AND has a machine nobody else is using, lift until
        -- it exhausts, then move to the next available one. Only when ALL four are
        -- unavailable (resting or taken) do we run on a treadmill, breaking out the
        -- instant one frees up. Verified live: claims keyed by GymMachineId, per-exercise
        -- FatigueStates with Exhausted/Remaining/ResetEndsAtClient, treadmill zone pays XP.
        local farmActive = false
        local GymCtrl, GymWorkout, GymHighlight
        do
            local ok1, c = pcall(function() return require(LocalPlayer.PlayerScripts.Client.Controllers.GymController) end)
            if ok1 then GymCtrl = c end
            local ok2, w = pcall(function() return require(LocalPlayer.PlayerScripts.Client.Controllers.Gym.GymWorkoutClient) end)
            if ok2 then GymWorkout = w end
            local ok3, h = pcall(function() return require(LocalPlayer.PlayerScripts.Client.Controllers.Gym.GymMachineHighlightController) end)
            if ok3 then GymHighlight = h end
        end

        local FARM_EXERCISES = { "BenchPress", "Squat", "LatPulldown", "Curl" }
        local function nearestModel(name)
            local gym = Workspace:FindFirstChild("Gym")
            local hrp = GetHRP()
            if not gym or not hrp then return nil end
            local best, bestD
            for _, c in ipairs(gym:GetChildren()) do
                if c.Name == name then
                    local ok, pivot = pcall(function() return c:GetPivot().Position end)
                    if ok then
                        local d = (pivot - hrp.Position).Magnitude
                        if not bestD or d < bestD then bestD = d; best = c end
                    end
                end
            end
            return best
        end
        local function isInGym()
            if not GymCtrl then return true end
            if GymCtrl.IsInGym then local ok, v = pcall(function() return GymCtrl:IsInGym() end); if ok then return v == true end end
            return GymCtrl.InGym == true
        end
        local function inWorkoutNow()
            return GymCtrl ~= nil and GymCtrl.InWorkout == true
        end
        -- per-exercise cooldown (each exercise rests on its own ~30s timer)
        local function exerciseResting(exType)
            local fs = GymHighlight and GymHighlight.FatigueStates and GymHighlight.FatigueStates[exType]
            if type(fs) ~= "table" then return false end
            if fs.ResetEndsAtClient ~= nil then return (fs.ResetEndsAtClient - os.clock()) > 0 end
            return fs.Exhausted == true
        end
        -- is this physical machine free (unclaimed, or claimed by us)?
        local function machineFreeForMe(model)
            local id = model:GetAttribute("GymMachineId")
            if not id or not GymHighlight or type(GymHighlight.MachineClaims) ~= "table" then return true end
            local claim = GymHighlight.MachineClaims[id]
            if type(claim) ~= "table" or type(claim.UserId) ~= "number" then return true end
            return claim.UserId == LocalPlayer.UserId
        end
        -- nearest machine of this exercise that nobody else is using
        local function freeMachineFor(exType)
            local gym = Workspace:FindFirstChild("Gym")
            local hrp = GetHRP()
            if not gym or not hrp then return nil end
            local best, bestD
            for _, c in ipairs(gym:GetChildren()) do
                if c.Name == exType and machineFreeForMe(c) then
                    local ok, pivot = pcall(function() return c:GetPivot().Position end)
                    if ok then
                        local d = (pivot - hrp.Position).Magnitude
                        if not bestD or d < bestD then bestD = d; best = c end
                    end
                end
            end
            return best
        end
        -- an exercise is doable only if it isn't resting AND has a d machine
        local function pickAvailable(startIdx)
            for off = 0, #FARM_EXERCISES - 1 do
                local idx = (startIdx - 1 + off) % #FARM_EXERCISES + 1
                local ex = FARM_EXERCISES[idx]
                if not exerciseResting(ex) then
                    local m = freeMachineFor(ex)
                    if m then return ex, m, idx end
                end
            end
            return nil
        end
        local function startWorkoutAt(machine)
            local hrp = GetHRP(); if not hrp then return false end
            local pp = machine:FindFirstChild("ProximityPart"); if not pp then return false end
            local prompt = pp:FindFirstChildWhichIsA("ProximityPrompt"); if not prompt then return false end
            local seat = machine:FindFirstChild("SeatLocation") or pp
            hrp.CFrame = CFrame.new(seat.Position + Vector3.new(0, 3, 0))
            task.wait(1)                                   -- let position settle + prompt register
            if HUB.dead or not farmActive then return false end
            if type(fireproximityprompt) == "function" then pcall(fireproximityprompt, prompt) end
            local t0 = os.clock()
            repeat task.wait(0.1) until inWorkoutNow() or os.clock() - t0 > 4 or HUB.dead or not farmActive
            return inWorkoutNow()
        end

        local farmIndex = 1
        local farmWarned = false
        task.spawn(function()
            while true do
                if HUB.dead then return end
                if not farmActive or not GymCtrl or not GymWorkout then
                    task.wait(0.4)
                elseif not isInGym() then
                    if not farmWarned then
                        farmWarned = true
                        Notify("Auto Farm", "Enter the gym first (press the GYM button), then farming begins.", "Info", 4)
                    end
                    task.wait(1)
                else
                    farmWarned = false
                    local ex, machine, idx = pickAvailable(farmIndex)
                    if ex and machine then
                        farmIndex = idx % #FARM_EXERCISES + 1   -- next search starts after this one
                        if startWorkoutAt(machine) then
                            -- bank Perfect reps until THIS exercise hits its own limit
                            local t0 = os.clock()
                            while not HUB.dead and farmActive and inWorkoutNow()
                                and not exerciseResting(ex) and os.clock() - t0 < 60 do
                                driveGymClick()   -- Bench / Squat
                                driveGymDrag()    -- Lat Pulldown / Curl
                                task.wait(0.08)
                            end
                        end
                        pcall(function() GymWorkout:RequestExit("AutoFarm") end)
                    else
                        -- nothing doable (every exercise resting or every machine taken)
                        -- -> run on the BEST body-level treadmill, bail the instant one opens
                        pcall(function() GymWorkout:RequestExit("AutoFarm") end)
                        treadTarget = nil                  -- force a fresh best-treadmill pick
                        local tEnd = os.clock() + 35
                        while not HUB.dead and farmActive and os.clock() < tEnd do
                            driveTreadmill()               -- best treadmill, direct-drive (suppress + SendTreadmillZoneState)
                            if pickAvailable(farmIndex) then break end   -- an exercise freed up
                            task.wait(0.1)
                        end
                        restoreGameTread()                 -- hand detection back when leaving
                        treadTarget = nil
                    end
                end
            end
        end)

        AutoClickSub:AddSection("Supported Game")
        AutoClickSub:AddParagraph({
            Title = "\u{2705} Looksmax & Mog",
            Text = "Game detected and supported. These cheats only appear here — other games fall back to the universal hub.",
        })

        AutoClickSub:AddSection("Auto Click")
        if not HAS_FIRESIGNAL then
            AutoClickSub:AddParagraph({
                Title = "Unsupported Executor",
                Text = "Your executor does not expose 'firesignal', so the instant auto-clickers cannot fire the in-game buttons. Use an executor that supports firesignal.",
            })
        end

        AutoClickSub:AddToggle({
            Name = "Auto Mog Battle", Default = false, Flag = "ac_mog",
            Description = "Solves every battle minigame",
            Callback = function(v)
                autoMog = v
                Notify("Auto Mog", "Battle solver " .. (v and "enabled" or "disabled"), v and "Success" or "Error")
            end,
        })
        AutoClickSub:AddSlider({
            Name = "Tug Click Rate", Min = 1, Max = 100, Default = 25, Suffix = "", Flag = "ac_barrate",
            Description = "Tug-of-war spam per frame",
            Callback = function(v) barClicks = v end,
        })

        local QueueSub = GameTab:AddSubTab("Auto Queue")
        QueueSub:AddSection("Matchmaking")
        if not canFire() then
            QueueSub:AddParagraph({
                Title = "Unavailable",
                Text = "Couldn't reach the matchmaking remote (ReplicatedStorage.Shared.Lib.F). Auto Queue won't work on this build.",
            })
        end
        local function setMode(v) queueMode = (v == "2v2") and "2v2" or "1v1" end
        local modeDropdown = QueueSub:AddDropdown({
            Name = "Mode", Options = { "1v1", "2v2" }, Default = "1v1", Flag = "mog_queue_mode",
            Callback = setMode,
        })
        registerResync(modeDropdown, setMode)
        QueueSub:AddToggle({
            Name = "Auto Queue", Default = false, Flag = "mog_autoqueue",
            Description = "Re-queues automatically whenever you land back in the lobby",
            Callback = function(v)
                autoQueue = v
                Notify("Auto Queue", v and ("Queuing " .. queueMode .. " matches") or "Disabled", v and "Success" or "Error")
            end,
        })
        QueueSub:AddButton({
            Name = "Queue Now", Primary = true,
            Callback = function()
                local ok = fireQueue(queueMode)
                Notify("Auto Queue", ok and ("Queued " .. queueMode) or "Remote unavailable", ok and "Success" or "Error")
            end,
        })
        QueueSub:AddButton({
            Name = "Leave Queue",
            Callback = function()
                leaveQueue()
                Notify("Auto Queue", "Left queue", "Info")
            end,
        })
        QueueSub:AddParagraph({
            Title = "Full AFK farm",
            Text = "Enable Auto Queue here plus 'Auto Mog Battle' on the Auto Click tab: it queues, the solver wins the match, then it queues again. 2v2 may need a squad depending on the game's rules.",
        })

        local FarmSub = GameTab:AddSubTab("Auto Farm")
        FarmSub:AddSection("Gym Auto Farm")
        if not (GymCtrl and GymWorkout and type(fireproximityprompt) == "function") then
            FarmSub:AddParagraph({
                Title = "Limited support",
                Text = (type(fireproximityprompt) ~= "function")
                    and "Your executor has no 'fireproximityprompt', so workouts can't be auto-started."
                    or "Couldn't hook the gym controllers on this game build.",
            })
        end
        FarmSub:AddToggle({
            Name = "Auto Gym Farm", Default = false, Flag = "gym_autofarm",
            Description = "Rotates bench/squat/lat/curl, runs on a treadmill while fatigued",
            Callback = function(v)
                farmActive = v
                Notify("Auto Farm", v and "Farming: lift -> rest run -> repeat" or "Stopped", v and "Success" or "Error")
            end,
        })
        FarmSub:AddParagraph({
            Title = "How it works",
            Text = "Enter the gym first. It rotates bench/squat/lat/curl, only using a machine no one else is on, and skips any exercise that's resting. Each exercise rests on its own ~30s timer (limit scales with body level). When all four are resting or taken it runs on a treadmill, then jumps back the moment one frees up.",
        })

        -- focus this tab on load so the game's cheats are front-and-center
        pcall(function() Window:_selectTab(GameTab) end)
    end,
}

-- Dispatch: load the current game's module if we support it.
do
    local entry = SupportedGames[game.GameId]
    if entry then
        local ok, err = pcall(entry.Build)
        if ok then
            Notify("Game Support", entry.Name .. " features loaded", "Success", 4)
        else
            warn("[Nox Hub] Failed to build game module for " .. tostring(entry.Name) .. ": " .. tostring(err))
            Notify("Game Support", "Error loading " .. entry.Name .. " features", "Error", 5)
        end
    else
        Notify("Universal Mode", "No specific support for this game yet — universal features only", "Info", 4)
    end
end

local ServerTab = Window:AddTab({ Name = "Server", Subtitle = "Join & hop", Icon = "globe" })
local ServerSub = ServerTab:AddSubTab("Actions")

ServerSub:AddButton({
    Name = "Rejoin Server", Primary = true,
    Callback = function()
        Notify("Server", "Rejoining...", "Info")
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end,
})
ServerSub:AddButton({
    Name = "Server Hop",
    Callback = function()
        Notify("Server", "Finding a new server...", "Info")
        task.spawn(function()
            local ok, err = pcall(function()
                local HttpService = game:GetService("HttpService")
                local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId)
                local raw = game:HttpGet(url)
                local data = HttpService:JSONDecode(raw)
                for _, s in ipairs(data.data or {}) do
                    if type(s.playing) == "number" and s.playing < s.maxPlayers and s.id ~= game.JobId then
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
                        return
                    end
                end
                TeleportService:Teleport(game.PlaceId, LocalPlayer)
            end)
            if not ok then Notify("Server", "Hop failed: " .. tostring(err), "Error", 4) end
        end)
    end,
})
ServerSub:AddButton({
    Name = "Copy Job ID",
    Callback = function()
        local ok = pcall(function() (setclipboard or toclipboard or writeclipboard)(game.JobId) end)
        Notify("Server", ok and "Job ID copied" or "Clipboard unavailable", ok and "Success" or "Error")
    end,
})

ServerSub:AddParagraph({
    Title = "Session Info",
    Text = ("Place: %d\nJob: %s\nPlayers: %d/%d")
        :format(game.PlaceId, tostring(game.JobId), #Players:GetPlayers(), Players.MaxPlayers),
})

local SettingsTab = Window:AddTab({ Name = "Settings", Subtitle = "Config & UI", Icon = "settings" })
local SettingsSub = SettingsTab:AddSubTab("General")

if type(Library.SetTheme) == "function" then
    SettingsSub:AddDropdown({
        Name = "Theme", Options = { "Dark", "Light", "OLED" }, Default = "Dark",
        Flag = "ui_theme",
        Callback = function(v) pcall(function() Library:SetTheme(v) end) end,
    })
end

if HAS_CONFIG then
    SettingsSub:AddSection("Configuration")
    SettingsSub:AddButton({
        Name = "Save Config", Primary = true,
        Callback = function()
            local ok = pcall(function() Library:SaveConfig(CONFIG_NAME) end)
            Notify("Config", ok and "Saved" or "Save failed", ok and "Success" or "Error")
        end,
    })
    SettingsSub:AddButton({
        Name = "Load Config",
        Callback = function()
            local ok = pcall(function() Library:LoadConfig(CONFIG_NAME) end)
            if ok then ResyncAll() end
            Notify("Config", ok and "Loaded" or "Load failed", ok and "Success" or "Error")
        end,
    })
else
    SettingsSub:AddParagraph({
        Title = "Config Saving Unavailable",
        Text = "This Nox UI build does not expose the flag/config system (requires v2.3+). All other features still work.",
    })
end

SettingsSub:AddSection("UI")

-- ── Misc: performance ───────────────────────────────────────────────────────
local MiscSub = SettingsTab:AddSubTab("Misc")
local setFPS = setfpscap or (getgenv and getgenv().setfpscap) or set_fps_cap
local HAS_FPS = type(setFPS) == "function"
local fpsUnlocked, fpsCap = false, 0   -- 0 = unlimited

local function applyFps()
    if HAS_FPS then pcall(setFPS, fpsUnlocked and fpsCap or 60) end
end

MiscSub:AddSection("Performance")
if not HAS_FPS then
    MiscSub:AddParagraph({
        Title = "FPS Unlock Unavailable",
        Text = "Your executor does not expose 'setfpscap', so the FPS cap can't be changed.",
    })
end
MiscSub:AddToggle({
    Name = "Unlock FPS", Default = false, Flag = "misc_fpsunlock",
    Description = "Removes the cap (0 = unlimited)",
    Callback = function(v)
        fpsUnlocked = v
        applyFps()
        Notify("Misc", v and (fpsCap == 0 and "FPS uncapped (unlimited)" or ("FPS cap " .. fpsCap))
            or "FPS cap back to 60", v and "Success" or "Info")
    end,
})
MiscSub:AddSlider({
    Name = "FPS Cap", Min = 0, Max = 1000, Default = 0, Suffix = "", Flag = "misc_fpscap",
    Description = "0 = unlimited",
    Callback = function(v)
        fpsCap = v
        if fpsUnlocked then applyFps() end
    end,
})

function HUB.Unload()
    if HUB.dead then return end
    HUB.dead = true
    flying = false; noclip = false; following = false; aim.enabled = false
    silent.enabled = false
    silent.wallbang = false
    pcall(function() Workspace:SetAttribute(WALLBANG_ATTR, nil) end)
    pcall(function()
        if WeaponC and WeaponC.CurrentWeapon and WeaponC.CurrentWeapon.__noxOldWB ~= nil then
            WeaponC.CurrentWeapon.WallbangThreshold = WeaponC.CurrentWeapon.__noxOldWB
            WeaponC.CurrentWeapon.__noxOldWB = nil
        end
    end)
    pcall(function()
        if SAClass and SAClass.getInstance then
            local i = SAClass:getInstance()
            if i and i.disable then i:disable() end
        end
    end)
    if getgenv and getgenv().NoxAim then getgenv().NoxAim.enabled = false end
    pcall(function() if flyConn then flyConn:Disconnect() end end)
    pcall(function() if noclipConn then noclipConn:Disconnect() end end)
    for _, c in ipairs(HUB.conns) do pcall(function() c:Disconnect() end) end
    for _, d in ipairs(HUB.drawings) do pcall(function() d:Remove() end) end
    for _, h in ipairs(HUB.highlights) do pcall(function() h:Destroy() end) end
    table.clear(espObjects)
    table.clear(npcObjects)
    pcall(function()
        local hum = GetHumanoid()
        if hum then hum.PlatformStand = false; hum.WalkSpeed = 16; hum.JumpPower = 50 end
    end)
    Workspace.Gravity = defaultGravity
    Camera.FieldOfView = defaultFOV
    if fullbright then
        Lighting.Brightness = savedLighting.Brightness
        Lighting.ClockTime = savedLighting.ClockTime
        Lighting.FogEnd = savedLighting.FogEnd
        Lighting.GlobalShadows = savedLighting.GlobalShadows
        Lighting.Ambient = savedLighting.Ambient
    end
    pcall(function() Window:Destroy() end)
end

SettingsSub:AddButton({
    Name = "Unload Hub",
    Callback = function()
        HUB.Unload()
        _G.NoxUniversal = nil
    end,
})

Notify("Nox Hub", "Universal loaded successfully", "Success", 4)