--[[
╔══════════════════════════════════════════════════════════════╗
║  orca-addon-fixes.lua                                        ║                  ║
║                                                              ║
║  PURPOSE: Patches Orca's UI safely AFTER Orca loads.        ║
║  Uses task.wait() to ensure Orca's Roact tree, store,       ║
║  ScreenGui and Navbar are fully mounted before injecting.   ║
║                                                              ║

║  WHAT THIS FILE FIXES:                                      ║
║  [FIX-1] Defers all UI injection until Orca's ScreenGui    ║
║          exists in PlayerGui (polls every 0.1s, 20s max)   ║
║  [FIX-2] Defers Navbar injection until AbsoluteSize is     ║
║          non-zero (Roact finishes layout pass)              ║
║  [FIX-3] Prevents double-injection via _G guard flag       ║
║  [FIX-4] Safely finds Orca root Frame via WaitForChild     ║
║          with timeout instead of FindFirstChild            ║
║  [FIX-5] Card slide-in position now computed from          ║
║          actual root AbsoluteSize to avoid off-screen      ║
║          placement on non-1080p displays                   ║
╚══════════════════════════════════════════════════════════════╝
--]]

-- ────────────────────────────────────────────────────────────
-- [FIX-3] Guard: abort if addon was already injected
-- ────────────────────────────────────────────────────────────
if _G.__ORCA_ADDON_INJECTED then
    warn("[OrcaFixes] Already injected — skipping duplicate load.")
    return
end
_G.__ORCA_ADDON_INJECTED = true

-- ────────────────────────────────────────────────────────────
-- Services
-- ────────────────────────────────────────────────────────────
local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local lp   = Players.LocalPlayer
local pgui = lp:WaitForChild("PlayerGui")

-- ────────────────────────────────────────────────────────────
-- [FIX-1] Wait for Orca's ScreenGui using task.wait polling
-- Returns the ScreenGui or nil after timeout
-- ────────────────────────────────────────────────────────────
local function waitForOrcaGui(timeout)
    timeout = timeout or 20
    local elapsed = 0
    while elapsed < timeout do
        -- Check PlayerGui first (syn.protect_gui puts it here)
        for _, sg in ipairs(pgui:GetChildren()) do
            if sg:IsA("ScreenGui") and sg.Name == "Orca" then
                return sg
            end
        end
        -- Fallback: CoreGui (some executors parent it here)
        local cg = game:GetService("CoreGui")
        for _, sg in ipairs(cg:GetChildren()) do
            if sg:IsA("ScreenGui") and sg.Name == "Orca" then
                return sg
            end
        end
        task.wait(0.1)
        elapsed += 0.1
    end
    return nil
end

-- ────────────────────────────────────────────────────────────
-- [FIX-4] Wait for Orca's root Frame inside ScreenGui
-- Roact mounts a Frame as the first child after render
-- ────────────────────────────────────────────────────────────
local function waitForOrcaRoot(gui, timeout)
    timeout = timeout or 10
    local elapsed = 0
    local root
    while elapsed < timeout do
        for _, c in ipairs(gui:GetChildren()) do
            if c:IsA("Frame") then root = c; break end
        end
        if root then break end
        task.wait(0.1)
        elapsed += 0.1
    end
    return root
end

-- ────────────────────────────────────────────────────────────
-- [FIX-2] Wait until a Frame has a non-zero AbsoluteSize
-- Roact completes layout AFTER parenting — we must wait
-- ────────────────────────────────────────────────────────────
local function waitForLayout(frame, timeout)
    timeout = timeout or 8
    local elapsed = 0
    while elapsed < timeout do
        if frame.AbsoluteSize.X > 0 and frame.AbsoluteSize.Y > 0 then
            return true
        end
        task.wait(0.05)
        elapsed += 0.05
    end
    return false
end

-- ────────────────────────────────────────────────────────────
-- Helper: find Orca's Navbar inside root
-- Orca's Navbar is a Frame with ≥3 TextButton children
-- each containing an ImageLabel (the icon+label pattern)
-- ────────────────────────────────────────────────────────────
local function findNavbar(root)
    -- Wait for layout first so AbsoluteSize is meaningful
    waitForLayout(root, 8)
    for _, child in ipairs(root:GetDescendants()) do
        if child:IsA("Frame") then
            local abs = child.AbsoluteSize
            if abs.X > 200 and abs.Y > 30 and abs.Y < 90 then
                local btnCount = 0
                for _, c in ipairs(child:GetChildren()) do
                    if c:IsA("TextButton") or c:IsA("Frame") then
                        btnCount += 1
                    end
                end
                if btnCount >= 3 then
                    return child
                end
            end
        end
    end
    return nil
end

-- ────────────────────────────────────────────────────────────
-- [FIX-5] Compute card X position relative to root width
-- so it's correct on all resolutions (not hardcoded 374px)
-- ────────────────────────────────────────────────────────────
local function computeCardX(root)
    waitForLayout(root, 8)
    local w = root.AbsoluteSize.X
    -- Orca's layout: navbar ~100px wide per tab, cards at 374
    -- Ratio 374/830 ≈ 0.45 of total width
    return math.round(w * 0.45)
end

-- ────────────────────────────────────────────────────────────
-- Expose helpers to _G so the addons file can consume them
-- without re-running discovery logic
-- ────────────────────────────────────────────────────────────
_G.__OrcaAddonHelpers = {
    waitForOrcaGui  = waitForOrcaGui,
    waitForOrcaRoot = waitForOrcaRoot,
    waitForLayout   = waitForLayout,
    findNavbar      = findNavbar,
    computeCardX    = computeCardX,
}

print("[OrcaFixes] Loaded — helpers registered in _G.__OrcaAddonHelpers")
