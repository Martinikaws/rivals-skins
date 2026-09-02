-- =========================================================================
--  RIVALS FIRST-PERSON VISUAL TRANSFORMER (100% AutoExec & Queue Safe)
-- =========================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LP = Players.LocalPlayer
if not LP then return end

-- 📂 READ CONFIGURATION FROM WORKSPACE
local configFileName = "rivals_config.lua"
local skinConfig = {}

local function loadConfig()
    skinConfig = {}
    if isfile and readfile and isfile(configFileName) then
        local content = readfile(configFileName)
        for line in content:gmatch("[^\r\n]+") do
            local eq = line:find("=")
            if eq then
                local w = line:sub(1, eq - 1):match("^%s*(.-)%s*$")
                local s = line:sub(eq + 1):match("^%s*(.-)%s*$")
                if #w > 0 and #s > 0 and s ~= "Default" and s ~= "Standard" then
                    skinConfig[w:lower()] = s
                end
            end
        end
    end
end

loadConfig()

-- 🔍 FIND SKIN MODEL FROM ASSETS
local function findSkinModel(skinTarget)
    local assets = LP:FindFirstChild("PlayerScripts") and LP.PlayerScripts:FindFirstChild("Assets")
    local vm = assets and assets:FindFirstChild("ViewModels")
    if not vm then return nil end

    for _, folder in ipairs(vm:GetChildren()) do
        if folder:IsA("Folder") and folder.Name ~= "Weapons" then
            local found = folder:FindFirstChild(skinTarget)
            if found then return found end
        end
    end

    -- Check Bundles, Seasons, Unobtainable aliases
    if vm:FindFirstChild("Bundles") then
        if skinTarget == "Keyblade" and vm.Bundles:FindFirstChild("Gunblade") then return vm.Bundles.Gunblade end
        if skinTarget == "Crystal Daggers" and vm.Bundles:FindFirstChild("Crystal Daggers") then return vm.Bundles["Crystal Daggers"] end
    end
    if vm:FindFirstChild("Seasons") then
        local s = vm.Seasons
        if skinTarget == "Arch Katana" and s:FindFirstChild("Katana") then return s.Katana end
        if skinTarget == "Arch Molotov" and s:FindFirstChild("Molotov") then return s.Molotov end
        if skinTarget == "Spy Gloves" and s:FindFirstChild("Fists") then return s.Fists end
        if skinTarget == "Arch Crossbow" and s:FindFirstChild("Arch Crossbow") then return s["Arch Crossbow"] end
        if skinTarget == "Arch Uzi" and (s:FindFirstChild("Arch Uzi") or s:FindFirstChild("Uzi")) then return s:FindFirstChild("Arch Uzi") or s.Uzi end
    end
    if vm:FindFirstChild("Unobtainable") and skinTarget == "Armature.001" then
        return vm.Unobtainable:FindFirstChild("Armature.001")
    end

    return nil
end

-- 🎨 TRANSFORM FIRST-PERSON VIEWMODEL
local function transformViewModel(itemVisual, weaponName)
    local targetSkinName = skinConfig[weaponName:lower()]
    if not targetSkinName then return end

    local sourceSkin = findSkinModel(targetSkinName)
    if not sourceSkin then return end

    local body = itemVisual:FindFirstChild("Body") or itemVisual:FindFirstChild("Model") or itemVisual:FindFirstChild("Bottom") or itemVisual:FindFirstChild("LeftBody")
    if not body then return end

    local bodyPrimary = body:FindFirstChild("Primary") or body.PrimaryPart
    if not bodyPrimary then return end

    -- Hide original weapon visual parts
    for _, child in ipairs(itemVisual:GetChildren()) do
        for _, desc in ipairs(child:GetDescendants()) do
            if desc:IsA("BasePart") and desc.Name ~= "Primary" and not desc:GetAttribute("CustomSkinPart") then
                desc.Transparency = 1
            elseif desc:IsA("Decal") or desc:IsA("Texture") then
                desc.Transparency = 1
            end
        end
    end

    -- If already transformed with this skin, avoid duplicating
    if itemVisual:GetAttribute("AppliedSkin") == targetSkinName then return end
    itemVisual:SetAttribute("AppliedSkin", targetSkinName)

    -- Remove any old custom skin clone
    local oldSkinClone = itemVisual:FindFirstChild("CustomSkinVisual")
    if oldSkinClone then oldSkinClone:Destroy() end

    -- Clone the target skin model cleanly
    local skinClone = sourceSkin:Clone()
    skinClone.Name = "CustomSkinVisual"
    skinClone:SetAttribute("CustomSkinPart", true)

    local cloneBody = skinClone:FindFirstChild("Body") or skinClone:FindFirstChild("Model") or skinClone:FindFirstChild("Bottom") or skinClone:FindFirstChild("LeftBody") or skinClone:GetChildren()[1]
    local clonePrimary = cloneBody and (cloneBody:FindFirstChild("Primary") or cloneBody.PrimaryPart)

    -- Clean detached clutter from skin (spider legs, loose shells, giant wings)
    for _, c in ipairs(skinClone:GetChildren()) do
        local n = c.Name:lower()
        if n:find("leg") or n:find("shell") or n:find("watermelon") or n:find("banana") or n:find("apple") or (n:find("wing") and not targetSkinName:lower():find("crossbow")) then
            c:Destroy()
        elseif cloneBody and c ~= cloneBody and (n:find("drill") or n:find("slice") or n:find("top") or n:find("front") or n:find("back") or n:find("sword")) then
            for _, p in ipairs(c:GetChildren()) do
                p.Parent = cloneBody
            end
            c:Destroy()
        end
    end

    -- Weld all parts of the new skin to the weapon's native Primary part
    for _, desc in ipairs(skinClone:GetDescendants()) do
        if desc:IsA("BasePart") then
            desc.CanCollide = false
            desc.CanTouch = false
            desc.CanQuery = false
            desc.Massless = true
            desc.CastShadow = false
            desc:SetAttribute("CustomSkinPart", true)

            if desc.Name ~= "Primary" and bodyPrimary then
                local weld = Instance.new("WeldConstraint")
                weld.Part0 = bodyPrimary
                weld.Part1 = desc
                weld.Parent = desc
            end
        end
    end

    skinClone.Parent = itemVisual
    
    -- Snap skin position to weapon primary
    if clonePrimary and bodyPrimary then
        skinClone:PivotTo(bodyPrimary.CFrame)
    end
end

-- 👁️ VIEWMODEL SCANNER & DETECTOR
local function scanViewModels()
    local vmFolder = Workspace:FindFirstChild("ViewModels")
    local fp = vmFolder and vmFolder:FindFirstChild("FirstPerson")
    local targetFolder = fp or Workspace:FindFirstChild("Camera") or Workspace.CurrentCamera

    if targetFolder then
        for _, vm in ipairs(targetFolder:GetChildren()) do
            local iv = vm:FindFirstChild("ItemVisual")
            if iv then
                local nameParts = vm.Name:split(" - ")
                local wName = nameParts[2] or vm.Name
                transformViewModel(iv, wName)
            end
        end
    end
end

RunService.Heartbeat:Connect(function()
    scanViewModels()
end)

LP.CharacterAdded:Connect(function()
    task.wait(0.3)
    loadConfig()
end)

pcall(notify, "First-Person Skin Transformer Active! (100% Queue & Teleport Safe)", "SC", 5)
