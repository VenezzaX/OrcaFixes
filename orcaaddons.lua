--[[
╔══════════════════════════════════════════════════════════════╗
║  orca-addon-functions.lua                                    ║
║                                                              ║
║  PURPOSE: Injects the Addons tab + worker jobs into Orca.   ║
║  Depends on orca-addon-fixes.lua being loaded first.        ║
║    loadstring(game:HttpGet("https://raw.githubusercontent   ║
║      .com/richie0866/orca/master/public/latest.lua"))()     ║
║                                                             ║
║  ADDONS INCLUDED:                                           ║
║  Character  — NoClip, InfiniteJump, ClickTeleport, SpinBot ║
║  Combat     — KillAura, SilentAim, ReachExtend             ║
║  Visual     — ESP Names, Fullbright                        ║
║  Misc       — Anti-AFK                                     ║
╚══════════════════════════════════════════════════════════════╝
--]]

-- ────────────────────────────────────────────────────────────
-- Dependency check
-- ────────────────────────────────────────────────────────────
local helpers = _G.__OrcaAddonHelpers
if not helpers then
    error("[OrcaAddons] orca-addon-fixes.lua must be loaded BEFORE this file!")
end

local waitForOrcaGui  = helpers.waitForOrcaGui
local waitForOrcaRoot = helpers.waitForOrcaRoot
local waitForLayout   = helpers.waitForLayout
local findNavbar      = helpers.findNavbar
local computeCardX    = helpers.computeCardX

-- ════════════════════════════════════════════════════════════
-- Services
-- ════════════════════════════════════════════════════════════
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Lighting         = game:GetService("Lighting")
local Workspace        = game:GetService("Workspace")

local lp   = Players.LocalPlayer
local pgui = lp:WaitForChild("PlayerGui")

-- ════════════════════════════════════════════════════════════
-- Addon job state  (workers read, UI writes)
-- ════════════════════════════════════════════════════════════
local jobs = {
    noclip      = false,
    infjump     = false,
    clicktp     = false,
    killaura    = false,
    esp         = false,
    fullbright  = false,
    antiafk     = false,
    spinbot     = false,
    reachextend = false,
    silentaim   = false,
}

local jobValues = {
    killaura    = 15,   -- stud radius
    reachextend = 20,   -- stud offset
}

-- ════════════════════════════════════════════════════════════
-- Workers
-- ════════════════════════════════════════════════════════════

-- NoClip
RunService.Stepped:Connect(function()
    if not jobs.noclip then return end
    local char = lp.Character
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = false end
    end
end)

-- Infinite Jump
UserInputService.JumpRequest:Connect(function()
    if not jobs.infjump then return end
    local char = lp.Character
    local hum  = char and char:FindFirstChildWhichIsA("Humanoid")
    if hum and hum:GetState() ~= Enum.HumanoidStateType.Dead then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

-- Click Teleport
UserInputService.InputBegan:Connect(function(inp, gpe)
    if gpe or not jobs.clicktp then return end
    if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    local char = lp.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local ray    = Workspace.CurrentCamera:ScreenPointToRay(inp.Position.X, inp.Position.Y)
    local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000)
    if result then
        root.CFrame = CFrame.new(result.Position + Vector3.new(0, 3, 0))
    end
end)

-- Kill Aura
task.spawn(function()
    while true do
        task.wait(0.1)
        if not jobs.killaura then continue end
        local char = lp.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then continue end
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl == lp then continue end
            local pc = pl.Character
            local pr = pc and pc:FindFirstChild("HumanoidRootPart")
            local ph = pc and pc:FindFirstChildWhichIsA("Humanoid")
            if pr and ph and (pr.Position - root.Position).Magnitude <= (jobValues.killaura or 15) then
                ph.Health = 0
            end
        end
    end
end)

-- ESP
local espCache = {}
local function clearESP()
    for _, bb in pairs(espCache) do
        if bb and bb.Parent then bb:Destroy() end
    end
    espCache = {}
end
RunService.RenderStepped:Connect(function()
    if not jobs.esp then clearESP(); return end
    local cam = Workspace.CurrentCamera
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl == lp then continue end
        local pc = pl.Character
        local pr = pc and pc:FindFirstChild("HumanoidRootPart")
        if not pr then
            if espCache[pl] then espCache[pl]:Destroy(); espCache[pl] = nil end
            continue
        end
        if not (espCache[pl] and espCache[pl].Parent) then
            local bb  = Instance.new("BillboardGui")
            bb.AlwaysOnTop = true
            bb.Size        = UDim2.new(0, 4, 0, 4)
            bb.StudsOffset = Vector3.new(0, 3, 0)
            local lbl = Instance.new("TextLabel", bb)
            lbl.Size                     = UDim2.new(1, 0, 1, 0)
            lbl.BackgroundTransparency   = 1
            lbl.TextColor3               = Color3.fromRGB(255, 60, 60)
            lbl.TextStrokeTransparency   = 0
            lbl.Font                     = Enum.Font.GothamBold
            lbl.TextSize                 = 14
            lbl.Text                     = pl.DisplayName
            bb.Parent                    = pr
            espCache[pl]                 = bb
        else
            local lbl = espCache[pl]:FindFirstChildWhichIsA("TextLabel")
            if lbl then
                local d = math.floor((cam.CFrame.Position - pr.Position).Magnitude)
                lbl.Text = pl.DisplayName .. "
[" .. d .. "m]"
            end
        end
    end
end)

-- Fullbright
local origAmb, origOut
task.spawn(function()
    local on = false
    while true do
        task.wait(0.2)
        if jobs.fullbright and not on then
            on = true
            origAmb = Lighting.Ambient
            origOut = Lighting.OutdoorAmbient
            Lighting.Ambient         = Color3.new(1, 1, 1)
            Lighting.OutdoorAmbient  = Color3.new(1, 1, 1)
        elseif not jobs.fullbright and on then
            on = false
            Lighting.Ambient        = origAmb or Color3.new(0.5, 0.5, 0.5)
            Lighting.OutdoorAmbient = origOut or Color3.new(0.5, 0.5, 0.5)
        end
    end
end)

-- Anti-AFK
lp.Idled:Connect(function()
    if not jobs.antiafk then return end
    local vu = Instance.new("VirtualUser")
    vu.Parent = game
    vu:CaptureController()
    vu:ClickButton2(Vector2.new())
    vu:Destroy()
end)

-- Spin Bot
local spinAngle = 0
RunService.Heartbeat:Connect(function(dt)
    if not jobs.spinbot then return end
    local char = lp.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    spinAngle += dt * 10
    root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, spinAngle, 0)
end)

-- Reach Extend
RunService.Stepped:Connect(function()
    if not jobs.reachextend then return end
    local char = lp.Character
    if not char then return end
    for _, tool in ipairs(char:GetChildren()) do
        if not tool:IsA("Tool") then continue end
        local handle = tool:FindFirstChild("Handle")
        local root   = char:FindFirstChild("HumanoidRootPart")
        if handle and root then
            handle.CFrame = root.CFrame * CFrame.new(0, 0, -(jobValues.reachextend or 20))
        end
    end
end)

-- Silent Aim
UserInputService.InputBegan:Connect(function(inp, gpe)
    if gpe or not jobs.silentaim then return end
    if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    local char = lp.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local closest, closestDist = nil, math.huge
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl == lp then continue end
        local pc = pl.Character
        local ph = pc and pc:FindFirstChildWhichIsA("Humanoid")
        local pr = pc and pc:FindFirstChild("HumanoidRootPart")
        if ph and pr and ph.Health > 0 then
            local d = (pr.Position - root.Position).Magnitude
            if d < closestDist then closestDist = d; closest = pr end
        end
    end
    if closest then
        Workspace.CurrentCamera.CFrame = CFrame.lookAt(
            Workspace.CurrentCamera.CFrame.Position, closest.Position
        )
    end
end)

-- ════════════════════════════════════════════════════════════
-- Orca UI injection
-- Depends on fixes helpers for safe, deferred discovery
-- ════════════════════════════════════════════════════════════

-- Orca dark-theme colour tokens (matches jobs.reducer accent)
local C = {
    bg      = Color3.fromRGB(22,  22,  26),    -- #161620
    bgRow   = Color3.fromRGB(27,  28,  32),    -- #1B1C20 (Orca card row bg)
    bgHover = Color3.fromRGB(40,  40,  52),
    accent  = Color3.fromRGB(55,  204, 149),   -- #37CC95 (Orca accent)
    fg      = Color3.new(1, 1, 1),
    fg2     = Color3.fromRGB(180, 180, 195),
    stroke  = Color3.new(1, 1, 1),
    section = Color3.fromRGB(130, 130, 160),
}

local TI = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function tween(inst, props)
    TweenService:Create(inst, TI, props):Play()
end

local function px(x, y) return UDim2.new(0, x, 0, y) end

local function addCorner(inst, r)
    local c = Instance.new("UICorner", inst)
    c.CornerRadius = UDim.new(0, r or 8)
end

local function addStroke(inst, col, t)
    local s = Instance.new("UIStroke", inst)
    s.Color        = col or C.stroke
    s.Transparency = t  or 0.88
    s.Thickness    = 1
end

-- ────────────────────────────────────────────────────────────
-- Build addon card UI
-- cardX  = computed X offset (FIX-5 resolution-safe)
-- root   = Orca's root Frame
-- ────────────────────────────────────────────────────────────
local function buildCard(root, cardX)
    local card = Instance.new("Frame")
    card.Name                   = "_OrcaAddonCard"
    card.Size                   = px(326, 648)
    -- Start off-screen to the left, slide in on open
    card.Position               = UDim2.new(0, cardX - 250, 1, 0)
    card.AnchorPoint            = Vector2.new(0, 1)
    card.BackgroundColor3       = C.bg
    card.BackgroundTransparency = 0
    card.BorderSizePixel        = 0
    card.Visible                = false
    card.ZIndex                 = 6
    addCorner(card, 16)
    addStroke(card)

    -- Drop shadow (approximates Orca's Glow component)
    local shadow = Instance.new("Frame", card)
    shadow.Name                   = "Shadow"
    shadow.Size                   = UDim2.new(1, 24, 1, 24)
    shadow.Position               = px(-12, -12)
    shadow.BackgroundColor3       = Color3.new(0, 0, 0)
    shadow.BackgroundTransparency = 0.65
    shadow.BorderSizePixel        = 0
    shadow.ZIndex                 = card.ZIndex - 1
    addCorner(shadow, 20)

    -- Title label (matches Orca TextLabel pattern: GothamBlack 20px)
    local title = Instance.new("TextLabel", card)
    title.Text               = "Addons"
    title.Font               = Enum.Font.GothamBlack
    title.TextSize           = 20
    title.TextColor3         = C.fg
    title.TextXAlignment     = Enum.TextXAlignment.Left
    title.TextYAlignment     = Enum.TextYAlignment.Top
    title.BackgroundTransparency = 1
    title.Size               = px(278, 30)
    title.Position           = px(24, 24)
    title.ZIndex             = card.ZIndex + 1

    -- ScrollingFrame for toggle rows
    local scroll = Instance.new("ScrollingFrame", card)
    scroll.Name                    = "Scroll"
    scroll.Size                    = UDim2.new(1, 0, 1, -68)
    scroll.Position                = px(0, 68)
    scroll.BackgroundTransparency  = 1
    scroll.BorderSizePixel         = 0
    scroll.ScrollBarThickness      = 3
    scroll.ScrollBarImageColor3    = C.fg
    scroll.ScrollBarImageTransparency = 0.7
    scroll.CanvasSize              = px(0, 0)
    scroll.ClipsDescendants        = true
    scroll.ZIndex                  = card.ZIndex + 1

    local list = Instance.new("UIListLayout", scroll)
    list.Padding       = UDim.new(0, 4)
    list.SortOrder     = Enum.SortOrder.LayoutOrder
    list.FillDirection = Enum.FillDirection.Vertical

    local pad = Instance.new("UIPadding", scroll)
    pad.PaddingLeft   = UDim.new(0, 24)
    pad.PaddingRight  = UDim.new(0, 24)
    pad.PaddingTop    = UDim.new(0, 8)
    pad.PaddingBottom = UDim.new(0, 8)

    -- Auto-size scroll canvas as rows are added
    list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = px(0, list.AbsoluteContentSize.Y + 16)
    end)

    return card, scroll
end

-- ────────────────────────────────────────────────────────────
-- Build a section header row
-- ────────────────────────────────────────────────────────────
local function makeSection(parent, label, order)
    local lbl = Instance.new("TextLabel", parent)
    lbl.Text             = label
    lbl.Font             = Enum.Font.GothamBlack
    lbl.TextSize         = 11
    lbl.TextColor3       = C.section
    lbl.BackgroundTransparency = 1
    lbl.Size             = UDim2.new(1, 0, 0, 22)
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.LayoutOrder      = order
    lbl.ZIndex           = parent.ZIndex + 1
    return lbl
end

-- ────────────────────────────────────────────────────────────
-- Build a toggle row (pill switch matching Orca BrightButton)
-- Returns the row Frame
-- ────────────────────────────────────────────────────────────
local function makeToggle(parent, jobKey, label, hint, order)
    local ROW_H = hint and 48 or 44

    local row = Instance.new("Frame", parent)
    row.Name              = "Toggle_" .. jobKey
    row.Size              = UDim2.new(1, 0, 0, ROW_H)
    row.BackgroundColor3  = C.bgRow
    row.BorderSizePixel   = 0
    row.LayoutOrder       = order
    row.ZIndex            = parent.ZIndex + 1
    addCorner(row, 8)

    -- Main label (GothamBold 14px — matches Orca ConfigItem)
    local nameLbl = Instance.new("TextLabel", row)
    nameLbl.Text             = label
    nameLbl.Font             = Enum.Font.GothamBold
    nameLbl.TextSize         = 14
    nameLbl.TextColor3       = C.fg
    nameLbl.BackgroundTransparency = 1
    nameLbl.Size             = UDim2.new(1, -54, 0, 20)
    nameLbl.Position         = px(12, hint and 8 or 12)
    nameLbl.TextXAlignment   = Enum.TextXAlignment.Left
    nameLbl.ZIndex           = row.ZIndex + 1

    -- Subtitle hint (Gotham 10px — matches Orca hover hint style)
    if hint then
        local hintLbl = Instance.new("TextLabel", row)
        hintLbl.Text              = hint
        hintLbl.Font              = Enum.Font.Gotham
        hintLbl.TextSize          = 10
        hintLbl.TextColor3        = C.fg2
        hintLbl.BackgroundTransparency = 1
        hintLbl.Size              = UDim2.new(1, -54, 0, 14)
        hintLbl.Position          = px(12, 26)
        hintLbl.TextXAlignment    = Enum.TextXAlignment.Left
        hintLbl.ZIndex            = row.ZIndex + 1
    end

    -- Pill track (inactive = dark grey, active = #37CC95)
    local pill = Instance.new("Frame", row)
    pill.Size            = px(36, 20)
    pill.Position        = UDim2.new(1, -46, 0.5, -10)
    pill.BackgroundColor3 = Color3.fromRGB(55, 55, 68)
    pill.BorderSizePixel = 0
    pill.ZIndex          = row.ZIndex + 1
    addCorner(pill, 10)

    -- Knob
    local knob = Instance.new("Frame", pill)
    knob.Size            = px(16, 16)
    knob.Position        = px(2, 2)
    knob.BackgroundColor3 = C.fg
    knob.BorderSizePixel = 0
    knob.ZIndex          = pill.ZIndex + 1
    addCorner(knob, 8)

    -- Invisible hit area (full row)
    local btn = Instance.new("TextButton", row)
    btn.Size                 = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text                 = ""
    btn.ZIndex               = row.ZIndex + 5

    local function refresh()
        local on = jobs[jobKey]
        tween(pill,    { BackgroundColor3 = on and C.accent or Color3.fromRGB(55, 55, 68) })
        tween(knob,    { Position = on and px(18, 2) or px(2, 2) })
        tween(nameLbl, { TextColor3 = on and C.accent or C.fg })
    end

    btn.MouseEnter:Connect(function()
        if not jobs[jobKey] then tween(row, { BackgroundColor3 = C.bgHover }) end
    end)
    btn.MouseLeave:Connect(function()
        if not jobs[jobKey] then tween(row, { BackgroundColor3 = C.bgRow }) end
    end)
    btn.Activated:Connect(function()
        jobs[jobKey] = not jobs[jobKey]
        tween(row, {
            BackgroundColor3 = jobs[jobKey]
                and Color3.fromRGB(28, 44, 36)
                or  C.bgRow
        })
        refresh()
    end)

    return row
end

-- ────────────────────────────────────────────────────────────
-- Build tab button (mirrors Orca NavbarTab: 100×56, icon+label)
-- ────────────────────────────────────────────────────────────
local function buildTabButton(onToggle)
    local tab = Instance.new("Frame")
    tab.Name             = "_AddonTab"
    tab.Size             = px(100, 56)
    tab.BackgroundTransparency = 1
    tab.ZIndex           = 10

    -- Icon (wrench asset — from Orca's rbxassetid list)
    local icon = Instance.new("ImageLabel", tab)
    icon.Image               = "rbxassetid://8992259774"
    icon.ImageColor3         = Color3.new(1, 1, 1)
    icon.ImageTransparency   = 0.6
    icon.Size                = px(36, 36)
    icon.Position            = UDim2.new(0.5, -18, 0, 4)
    icon.BackgroundTransparency = 1
    icon.ZIndex              = tab.ZIndex + 1

    -- Label (GothamBold 9px — matches Orca NavbarTab labels)
    local lbl = Instance.new("TextLabel", tab)
    lbl.Text              = "Addons"
    lbl.Font              = Enum.Font.GothamBold
    lbl.TextSize          = 9
    lbl.TextColor3        = Color3.new(1, 1, 1)
    lbl.TextTransparency  = 0.6
    lbl.BackgroundTransparency = 1
    lbl.Size              = UDim2.new(1, 0, 0, 12)
    lbl.Position          = UDim2.new(0, 0, 1, -14)
    lbl.TextXAlignment    = Enum.TextXAlignment.Center
    lbl.ZIndex            = tab.ZIndex + 1

    -- Hit area
    local btn = Instance.new("TextButton", tab)
    btn.Size             = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text             = ""
    btn.ZIndex           = tab.ZIndex + 5
    btn.Activated:Connect(onToggle)

    return tab, icon, lbl
end

-- ────────────────────────────────────────────────────────────
-- Main injection — runs after Orca is fully mounted
-- ────────────────────────────────────────────────────────────
task.spawn(function()
    -- [FIX-1] Wait for Orca's ScreenGui (up to 20s)
    local gui = waitForOrcaGui(20)
    if not gui then
        warn("[OrcaAddons] Orca ScreenGui not found within 20s — aborting injection.")
        return
    end

    -- [FIX-4] Wait for Orca's root Frame
    local root = waitForOrcaRoot(gui, 10)
    if not root then
        warn("[OrcaAddons] Orca root Frame not found within 10s — aborting injection.")
        return
    end

    -- [FIX-2] Wait for Roact layout pass to complete
    local ok = waitForLayout(root, 8)
    if not ok then
        warn("[OrcaAddons] Root AbsoluteSize never became non-zero — layout may be broken.")
    end

    -- [FIX-5] Resolution-safe card X position
    local cardX = computeCardX(root)

    -- Build card with scroll area
    local card, scroll = buildCard(root, cardX)

    -- Populate toggle rows
    local order = 0

    order += 1; makeSection(scroll, "─── CHARACTER", order)
    order += 1; makeToggle(scroll, "noclip",      "NoClip",         "Walk through walls",             order)
    order += 1; makeToggle(scroll, "infjump",     "Infinite Jump",  "Jump again mid-air",             order)
    order += 1; makeToggle(scroll, "clicktp",     "Click Teleport", "Left-click to teleport",         order)
    order += 1; makeToggle(scroll, "spinbot",     "Spin Bot",       "Rotate character continuously",  order)

    order += 1; makeSection(scroll, "─── COMBAT", order)
    order += 1; makeToggle(scroll, "killaura",    "Kill Aura",      "Kills enemies within "..jobValues.killaura.."st",  order)
    order += 1; makeToggle(scroll, "silentaim",   "Silent Aim",     "Snaps camera to nearest player", order)
    order += 1; makeToggle(scroll, "reachextend", "Reach Extend",   "Extends tool reach "..jobValues.reachextend.."st", order)

    order += 1; makeSection(scroll, "─── VISUAL", order)
    order += 1; makeToggle(scroll, "esp",         "ESP Names",      "Name + distance over players",   order)
    order += 1; makeToggle(scroll, "fullbright",  "Fullbright",     "Max ambient lighting",           order)

    order += 1; makeSection(scroll, "─── MISC", order)
    order += 1; makeToggle(scroll, "antiafk",     "Anti-AFK",       "Prevents idle kick",             order)

    -- Parent card into Orca's root now
    card.Parent = root

    -- Track open state
    local isOpen = false

    local function setOpen(v)
        isOpen = v
        if v then
            card.Visible  = true
            -- Slide in from left (matches Orca Card spring animation)
            tween(card, { Position = UDim2.new(0, cardX, 1, 0) })
        else
            tween(card, { Position = UDim2.new(0, cardX - 280, 1, 0) })
            task.delay(0.22, function()
                if not isOpen then card.Visible = false end
            end)
        end
    end

    -- Build tab button
    local tab, tabIcon, tabLabel = buildTabButton(function()
        setOpen(not isOpen)
        tween(tabIcon,  { ImageTransparency = isOpen and 0 or 0.6,
                          ImageColor3       = isOpen and C.accent or Color3.new(1, 1, 1) })
        tween(tabLabel, { TextTransparency  = isOpen and 0 or 0.6,
                          TextColor3        = isOpen and C.accent or Color3.new(1, 1, 1) })
    end)

    -- Find and attach to Orca's Navbar
    -- [FIX-2] Navbar discovery waits for non-zero layout
    local navbar = findNavbar(root)
    if navbar then
        tab.Position = UDim2.new(1, 4, 0, 0)
        tab.Parent   = navbar
        -- Widen navbar frame to prevent clipping
        if navbar.Size.X.Offset > 0 then
            navbar.Size = px(navbar.Size.X.Offset + 100, navbar.Size.Y.Offset)
        end
    else
        -- Fallback: floating button anchored to bottom of root
        local floatFrame = Instance.new("Frame", root)
        floatFrame.Name             = "_AddonFloatBar"
        floatFrame.Size             = px(100, 56)
        floatFrame.Position         = UDim2.new(0, cardX, 1, -56)
        floatFrame.BackgroundColor3 = C.bg
        floatFrame.BorderSizePixel  = 0
        floatFrame.ZIndex           = 9
        addCorner(floatFrame, 8)
        addStroke(floatFrame)
        tab.Position = px(0, 0)
        tab.Parent   = floatFrame
    end

    -- [J] hotkey toggle
    UserInputService.InputBegan:Connect(function(inp, gpe)
        if gpe then return end
        if inp.KeyCode == Enum.KeyCode.J then
            setOpen(not isOpen)
            tween(tabIcon,  { ImageTransparency = isOpen and 0 or 0.6,
                              ImageColor3       = isOpen and C.accent or Color3.new(1, 1, 1) })
            tween(tabLabel, { TextTransparency  = isOpen and 0 or 0.6,
                              TextColor3        = isOpen and C.accent or Color3.new(1, 1, 1) })
        end
    end)

    print("[OrcaAddons] Injected successfully! Press J or click the Addons tab to open.")
end)
