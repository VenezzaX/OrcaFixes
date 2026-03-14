--[[
╔══════════════════════════════════════════════════════════════╗
║  orca-addon-merged.lua  (orcaaddons.lua — FINAL)            ║
║  Repo: VenezzaX/OrcaFixes  →  orcaaddons.lua               ║
║                                                              ║
║  LOAD ORDER:                                                 ║
║    loadstring(game:HttpGet("ORCAADDONS_RAW_URL"))()         ║
║    loadstring(game:HttpGet("https://raw.githubusercontent   ║
║      .com/richie0866/orca/master/public/latest.lua"))()     ║
║                                                              ║
║  NOTE: orcafixes.lua is NO LONGER needed as a separate      ║
║  file. All helpers are inlined here to avoid the            ║
║  _G sandbox isolation issue between loadstring chunks.      ║
╚══════════════════════════════════════════════════════════════╝
--]]

-- ════════════════════════════════════════════════════════════
-- Guard: prevent double-injection across re-executions
-- Uses shared_environment / getgenv if available, else _G
-- ════════════════════════════════════════════════════════════
local env = (getgenv and getgenv()) or _G
if env.__ORCA_ADDON_LOADED then
    warn("[OrcaAddons] Already loaded — skipping.")
    return
end
env.__ORCA_ADDON_LOADED = true

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
local jobValues = { killaura = 15, reachextend = 20 }

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
    if result then root.CFrame = CFrame.new(result.Position + Vector3.new(0, 3, 0)) end
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
            if pr and ph and (pr.Position - root.Position).Magnitude <= jobValues.killaura then
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
            lbl.Size                   = UDim2.new(1, 0, 1, 0)
            lbl.BackgroundTransparency = 1
            lbl.TextColor3             = Color3.fromRGB(255, 60, 60)
            lbl.TextStrokeTransparency = 0
            lbl.Font                   = Enum.Font.GothamBold
            lbl.TextSize               = 14
            lbl.Text                   = pl.DisplayName
            bb.Parent                  = pr
            espCache[pl]               = bb
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
            Lighting.Ambient        = Color3.new(1, 1, 1)
            Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
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
            handle.CFrame = root.CFrame * CFrame.new(0, 0, -jobValues.reachextend)
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
-- UI HELPERS  (inlined — no _G passing needed)
-- ════════════════════════════════════════════════════════════

-- Poll for Orca's ScreenGui (checks PlayerGui + CoreGui)
local function waitForOrcaGui(timeout)
    local elapsed = 0
    while elapsed < (timeout or 20) do
        for _, sg in ipairs(pgui:GetChildren()) do
            if sg:IsA("ScreenGui") and sg.Name == "Orca" then return sg end
        end
        local ok, cg = pcall(function() return game:GetService("CoreGui") end)
        if ok then
            for _, sg in ipairs(cg:GetChildren()) do
                if sg:IsA("ScreenGui") and sg.Name == "Orca" then return sg end
            end
        end
        task.wait(0.1)
        elapsed += 0.1
    end
    return nil
end

-- Poll for Orca's root Frame (Roact mounts it after ScreenGui exists)
local function waitForOrcaRoot(gui, timeout)
    local elapsed = 0
    while elapsed < (timeout or 10) do
        for _, c in ipairs(gui:GetChildren()) do
            if c:IsA("Frame") then return c end
        end
        task.wait(0.1)
        elapsed += 0.1
    end
    return nil
end

-- Wait for a Frame to have non-zero AbsoluteSize (Roact layout pass)
local function waitForLayout(frame, timeout)
    local elapsed = 0
    while elapsed < (timeout or 8) do
        if frame.AbsoluteSize.X > 0 and frame.AbsoluteSize.Y > 0 then return true end
        task.wait(0.05)
        elapsed += 0.05
    end
    return false
end

-- Resolution-safe card X position (45% of root width)
local function computeCardX(root)
    waitForLayout(root, 8)
    return math.round(root.AbsoluteSize.X * 0.45)
end

-- Find Orca's Navbar frame (Frame with ≥3 button-like children, short height)
local function findNavbar(root)
    waitForLayout(root, 8)
    for _, child in ipairs(root:GetDescendants()) do
        if child:IsA("Frame") then
            local abs = child.AbsoluteSize
            if abs.X > 200 and abs.Y > 30 and abs.Y < 90 then
                local n = 0
                for _, c in ipairs(child:GetChildren()) do
                    if c:IsA("TextButton") or c:IsA("Frame") then n += 1 end
                end
                if n >= 3 then return child end
            end
        end
    end
    return nil
end

-- ════════════════════════════════════════════════════════════
-- UI COMPONENT HELPERS
-- ════════════════════════════════════════════════════════════
local C = {
    bg      = Color3.fromRGB(22,  22,  26),
    bgRow   = Color3.fromRGB(27,  28,  32),
    bgHover = Color3.fromRGB(40,  40,  52),
    bgOn    = Color3.fromRGB(28,  44,  36),
    accent  = Color3.fromRGB(55,  204, 149),
    fg      = Color3.new(1, 1, 1),
    fg2     = Color3.fromRGB(180, 180, 195),
    stroke  = Color3.new(1, 1, 1),
    section = Color3.fromRGB(130, 130, 160),
}
local TI = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local function tw(inst, props) TweenService:Create(inst, TI, props):Play() end
local function px(x, y) return UDim2.new(0, x, 0, y) end
local function corner(inst, r) local c = Instance.new("UICorner", inst); c.CornerRadius = UDim.new(0, r or 8) end
local function stroke(inst, t) local s = Instance.new("UIStroke", inst); s.Color = C.stroke; s.Transparency = t or 0.88; s.Thickness = 1 end

local function makeSection(parent, label, order)
    local lbl = Instance.new("TextLabel", parent)
    lbl.Text = label; lbl.Font = Enum.Font.GothamBlack; lbl.TextSize = 11
    lbl.TextColor3 = C.section; lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, 0, 0, 22); lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.LayoutOrder = order; lbl.ZIndex = parent.ZIndex + 1
end

local function makeToggle(parent, jobKey, label, hint, order)
    local ROW_H = hint and 48 or 44

    local row = Instance.new("Frame", parent)
    row.Name = "Toggle_"..jobKey; row.Size = UDim2.new(1, 0, 0, ROW_H)
    row.BackgroundColor3 = C.bgRow; row.BorderSizePixel = 0
    row.LayoutOrder = order; row.ZIndex = parent.ZIndex + 1
    corner(row, 8)

    local nameLbl = Instance.new("TextLabel", row)
    nameLbl.Text = label; nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextSize = 14
    nameLbl.TextColor3 = C.fg; nameLbl.BackgroundTransparency = 1
    nameLbl.Size = UDim2.new(1, -54, 0, 20); nameLbl.Position = px(12, hint and 8 or 12)
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left; nameLbl.ZIndex = row.ZIndex + 1

    if hint then
        local h = Instance.new("TextLabel", row)
        h.Text = hint; h.Font = Enum.Font.Gotham; h.TextSize = 10
        h.TextColor3 = C.fg2; h.BackgroundTransparency = 1
        h.Size = UDim2.new(1, -54, 0, 14); h.Position = px(12, 26)
        h.TextXAlignment = Enum.TextXAlignment.Left; h.ZIndex = row.ZIndex + 1
    end

    local pill = Instance.new("Frame", row)
    pill.Size = px(36, 20); pill.Position = UDim2.new(1, -46, 0.5, -10)
    pill.BackgroundColor3 = Color3.fromRGB(55, 55, 68); pill.BorderSizePixel = 0
    pill.ZIndex = row.ZIndex + 1; corner(pill, 10)

    local knob = Instance.new("Frame", pill)
    knob.Size = px(16, 16); knob.Position = px(2, 2)
    knob.BackgroundColor3 = C.fg; knob.BorderSizePixel = 0
    knob.ZIndex = pill.ZIndex + 1; corner(knob, 8)

    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(1, 0, 1, 0); btn.BackgroundTransparency = 1
    btn.Text = ""; btn.ZIndex = row.ZIndex + 5

    local function refresh()
        local on = jobs[jobKey]
        tw(pill,    { BackgroundColor3 = on and C.accent or Color3.fromRGB(55, 55, 68) })
        tw(knob,    { Position = on and px(18, 2) or px(2, 2) })
        tw(nameLbl, { TextColor3 = on and C.accent or C.fg })
        tw(row,     { BackgroundColor3 = on and C.bgOn or C.bgRow })
    end

    btn.MouseEnter:Connect(function()
        if not jobs[jobKey] then tw(row, { BackgroundColor3 = C.bgHover }) end
    end)
    btn.MouseLeave:Connect(function()
        if not jobs[jobKey] then tw(row, { BackgroundColor3 = C.bgRow }) end
    end)
    btn.Activated:Connect(function()
        jobs[jobKey] = not jobs[jobKey]
        refresh()
    end)
end

-- ════════════════════════════════════════════════════════════
-- MAIN UI INJECTION
-- Runs in a task.spawn so workers start immediately while
-- we wait for Orca to finish mounting its Roact tree
-- ════════════════════════════════════════════════════════════
task.spawn(function()

    -- 1. Wait for Orca's ScreenGui (up to 25s — Orca loads after us)
    local gui = waitForOrcaGui(25)
    if not gui then
        warn("[OrcaAddons] Orca ScreenGui not found within 25s. UI not injected.")
        return
    end

    -- 2. Wait for Orca's root Frame (Roact render pass)
    local root = waitForOrcaRoot(gui, 10)
    if not root then
        warn("[OrcaAddons] Orca root Frame not found within 10s. UI not injected.")
        return
    end

    -- 3. Wait for Roact layout pass (AbsoluteSize becomes non-zero)
    waitForLayout(root, 8)

    -- 4. Build Card
    local cardX = computeCardX(root)

    local card = Instance.new("Frame")
    card.Name                   = "_OrcaAddonCard"
    card.Size                   = px(326, 648)
    card.Position               = UDim2.new(0, cardX - 280, 1, 0)  -- off-screen start
    card.AnchorPoint            = Vector2.new(0, 1)
    card.BackgroundColor3       = C.bg
    card.BackgroundTransparency = 0
    card.BorderSizePixel        = 0
    card.Visible                = false
    card.ZIndex                 = 6
    corner(card, 16); stroke(card)

    local shadow = Instance.new("Frame", card)
    shadow.Size = UDim2.new(1, 24, 1, 24); shadow.Position = px(-12, -12)
    shadow.BackgroundColor3 = Color3.new(0,0,0); shadow.BackgroundTransparency = 0.65
    shadow.BorderSizePixel = 0; shadow.ZIndex = card.ZIndex - 1; corner(shadow, 20)

    local title = Instance.new("TextLabel", card)
    title.Text = "Addons"; title.Font = Enum.Font.GothamBlack; title.TextSize = 20
    title.TextColor3 = C.fg; title.TextXAlignment = Enum.TextXAlignment.Left
    title.BackgroundTransparency = 1; title.Size = px(278, 30)
    title.Position = px(24, 24); title.ZIndex = card.ZIndex + 1

    local scroll = Instance.new("ScrollingFrame", card)
    scroll.Name = "Scroll"; scroll.Size = UDim2.new(1, 0, 1, -68)
    scroll.Position = px(0, 68); scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0; scroll.ScrollBarThickness = 3
    scroll.ScrollBarImageColor3 = C.fg; scroll.ScrollBarImageTransparency = 0.7
    scroll.CanvasSize = px(0, 0); scroll.ClipsDescendants = true
    scroll.ZIndex = card.ZIndex + 1

    local list = Instance.new("UIListLayout", scroll)
    list.Padding = UDim.new(0, 4); list.SortOrder = Enum.SortOrder.LayoutOrder
    list.FillDirection = Enum.FillDirection.Vertical

    local pad = Instance.new("UIPadding", scroll)
    pad.PaddingLeft = UDim.new(0, 24); pad.PaddingRight = UDim.new(0, 24)
    pad.PaddingTop = UDim.new(0, 8); pad.PaddingBottom = UDim.new(0, 8)

    list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = px(0, list.AbsoluteContentSize.Y + 16)
    end)

    -- 5. Populate rows
    local o = 0
    o+=1; makeSection(scroll, "─── CHARACTER", o)
    o+=1; makeToggle(scroll, "noclip",      "NoClip",         "Walk through walls",              o)
    o+=1; makeToggle(scroll, "infjump",     "Infinite Jump",  "Jump again mid-air",              o)
    o+=1; makeToggle(scroll, "clicktp",     "Click Teleport", "Left-click to teleport",          o)
    o+=1; makeToggle(scroll, "spinbot",     "Spin Bot",       "Rotate character continuously",   o)
    o+=1; makeSection(scroll, "─── COMBAT", o)
    o+=1; makeToggle(scroll, "killaura",    "Kill Aura",      "Kills enemies within "..jobValues.killaura.."st",   o)
    o+=1; makeToggle(scroll, "silentaim",   "Silent Aim",     "Snap camera to nearest player",   o)
    o+=1; makeToggle(scroll, "reachextend", "Reach Extend",   "Extends tool reach "..jobValues.reachextend.."st", o)
    o+=1; makeSection(scroll, "─── VISUAL", o)
    o+=1; makeToggle(scroll, "esp",         "ESP Names",      "Names + distance over players",   o)
    o+=1; makeToggle(scroll, "fullbright",  "Fullbright",     "Max ambient lighting",            o)
    o+=1; makeSection(scroll, "─── MISC", o)
    o+=1; makeToggle(scroll, "antiafk",     "Anti-AFK",       "Prevents idle kick",              o)

    card.Parent = root

    -- 6. Tab button
    local isOpen = false

    local tab = Instance.new("Frame")
    tab.Name = "_AddonTab"; tab.Size = px(100, 56)
    tab.BackgroundTransparency = 1; tab.ZIndex = 10

    local icon = Instance.new("ImageLabel", tab)
    icon.Image = "rbxassetid://8992259774"; icon.ImageColor3 = Color3.new(1,1,1)
    icon.ImageTransparency = 0.6; icon.Size = px(36, 36)
    icon.Position = UDim2.new(0.5, -18, 0, 4); icon.BackgroundTransparency = 1
    icon.ZIndex = tab.ZIndex + 1

    local tabLbl = Instance.new("TextLabel", tab)
    tabLbl.Text = "Addons"; tabLbl.Font = Enum.Font.GothamBold; tabLbl.TextSize = 9
    tabLbl.TextColor3 = Color3.new(1,1,1); tabLbl.TextTransparency = 0.6
    tabLbl.BackgroundTransparency = 1; tabLbl.Size = UDim2.new(1,0,0,12)
    tabLbl.Position = UDim2.new(0,0,1,-14); tabLbl.TextXAlignment = Enum.TextXAlignment.Center
    tabLbl.ZIndex = tab.ZIndex + 1

    local tabBtn = Instance.new("TextButton", tab)
    tabBtn.Size = UDim2.new(1,0,1,0); tabBtn.BackgroundTransparency = 1
    tabBtn.Text = ""; tabBtn.ZIndex = tab.ZIndex + 5

    local function setOpen(v)
        isOpen = v
        tw(icon,   { ImageTransparency = v and 0 or 0.6,
                     ImageColor3       = v and C.accent or Color3.new(1,1,1) })
        tw(tabLbl, { TextTransparency  = v and 0 or 0.6,
                     TextColor3        = v and C.accent or Color3.new(1,1,1) })
        if v then
            card.Visible = true
            tw(card, { Position = UDim2.new(0, cardX, 1, 0) })
        else
            tw(card, { Position = UDim2.new(0, cardX - 280, 1, 0) })
            task.delay(0.22, function()
                if not isOpen then card.Visible = false end
            end)
        end
    end

    tabBtn.Activated:Connect(function() setOpen(not isOpen) end)

    -- 7. Attach tab to Navbar or floating fallback
    local navbar = findNavbar(root)
    if navbar then
        tab.Position = UDim2.new(1, 4, 0, 0)
        tab.Parent   = navbar
        if navbar.Size.X.Offset > 0 then
            navbar.Size = px(navbar.Size.X.Offset + 100, navbar.Size.Y.Offset)
        end
    else
        local floatBar = Instance.new("Frame", root)
        floatBar.Name = "_AddonFloatBar"; floatBar.Size = px(100, 56)
        floatBar.Position = UDim2.new(0, cardX, 1, -56)
        floatBar.BackgroundColor3 = C.bg; floatBar.BorderSizePixel = 0
        floatBar.ZIndex = 9; corner(floatBar, 8); stroke(floatBar)
        tab.Position = px(0, 0)
        tab.Parent   = floatBar
    end

    -- 8. [J] hotkey
    UserInputService.InputBegan:Connect(function(inp, gpe)
        if gpe then return end
        if inp.KeyCode == Enum.KeyCode.J then setOpen(not isOpen) end
    end)

    print("[OrcaAddons] Injected! Press J or click Addons tab to open.")
end)
