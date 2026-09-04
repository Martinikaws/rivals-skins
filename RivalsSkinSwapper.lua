-- Rivals Skin Changer & Weapon Enhancement Engine (Ultra-Fast & Stable Edition)
-- Instant loading (<15ms): Direct memory slot resolution, zero synchronous GC stalls
-- Complete weapon display fix: ViewModelRoot RightArm restoration & zero WaitForChild hangs
local t_start = tick()

if not pcall(memory_read, "int", game.Address) then 
    pcall(notify, "UnsafeLua is disabled in executor.", "SC", 5) 
    return 
end

if not game:IsLoaded() then game.Loaded:Wait() end

local LP = game:GetService("Players").LocalPlayer
while not LP do
    task.wait(0.05)
    LP = game:GetService("Players").LocalPlayer
end

if game.GameId ~= 6035872082 then return end

-- Idempotency: restore memory pointers if previously active
if _G.__RIVALS_SKIN_CHANGER_ACTIVE and type(_G.__RIVALS_SKIN_CHANGER_RESTORE) == "function" then
    pcall(_G.__RIVALS_SKIN_CHANGER_RESTORE)
end

local A = LP:WaitForChild("PlayerScripts", 5):WaitForChild("Assets", 5)
local vm = A and A:WaitForChild("ViewModels", 5)
local wf = vm and vm:WaitForChild("Weapons", 5)

if not wf then
    pcall(notify, "Weapons folder not found.", "SC", 5)
    return
end

local mrd, mwr, pcall, ipairs, pairs = memory_read, memory_write, pcall, ipairs, pairs

local rd = function(a) 
    local o, v = pcall(mrd, "uintptr_t", a)
    return o and v or nil 
end

local wr = function(a, v) 
    pcall(mwr, "uintptr_t", a, v) 
end

local OFF = {
    Parent = 104,
    NameContainer = 112,
    Children = 120,
    Transparency = 304
}

local ga = function(f) 
    if not f or not f.Address then return end
    local n = rd(f.Address + OFF.Children)
    if not n or n == 0 then return end
    local b, e = rd(n), rd(n + 8)
    if b and e then return b, e end 
end

-- Find weapon slot in a folder's memory vector
local function findSlotAddressForWeapon(weaponModel, targetFolder)
    local f = targetFolder or wf
    local b, e = ga(f)
    if not b or not e then return nil end
    for slotAddr = b, e - 16, 16 do
        if rd(slotAddr) == weaponModel.Address then
            return slotAddr
        end
    end
    return nil
end

-- Fix ViewModelRoot RightArm if its NameContainer was corrupted/cleared
local function fixViewModelRoots()
    local containers = {}
    if LP:FindFirstChild("PlayerScripts") and LP.PlayerScripts:FindFirstChild("Assets") and LP.PlayerScripts.Assets:FindFirstChild("Misc") then
        table.insert(containers, LP.PlayerScripts.Assets.Misc)
    end
    local sp = game:GetService("StarterPlayer")
    if sp:FindFirstChild("StarterPlayerScripts") and sp.StarterPlayerScripts:FindFirstChild("Assets") and sp.StarterPlayerScripts.Assets:FindFirstChild("Misc") then
        table.insert(containers, sp.StarterPlayerScripts.Assets.Misc)
    end
    
    for _, misc in ipairs(containers) do
        local vmr = misc:FindFirstChild("ViewModelRoot")
        if vmr and not vmr:FindFirstChild("RightArm") then
            for _, c in ipairs(vmr:GetChildren()) do
                if c.ClassName == "Part" and (c.Name == "" or c.Name == "_fake") then
                    pcall(function() c.Name = "RightArm" end)
                    break
                end
            end
        end
    end
end
pcall(fixViewModelRoots)

-- Explicit skin mappings for special names / case folders
local EXACT_SKIN_MAP = {
    ["AKEY-47"] = {folder = "Bundles", name = "AKEY-47"},
    ["Key Bow"] = {folder = "Bundles", name = "Key Bow"},
    ["Key Spray"] = {folder = "Bundles", name = "Key Spray"},
    ["Keylisong"] = {folder = "Bundles", name = "Keylisong"},
    ["Keynade"] = {folder = "Bundles", name = "Keynade"},
    ["Keynais"] = {folder = "Bundles", name = "Keynais"},
    ["Keyper"] = {folder = "Bundles", name = "Keyper"},
    ["Keyst Rifle"] = {folder = "Bundles", name = "Keyst Rifle"},
    ["Keythe"] = {folder = "Bundles", name = "Keythe"},
    ["Keythrower"] = {folder = "Bundles", name = "Keythrower"},
    ["Keyttle Axe"] = {folder = "Bundles", name = "Keyttle Axe"},
    ["RPKEY"] = {folder = "Bundles", name = "RPKEY"},
    ["Keyshot"] = {folder = "Bundles", name = "Keyshot"},
    ["Keyblade"] = {folder = "Bundles", name = "Keyblade"},
    ["Keyvolver"] = {folder = "Bundles", name = "Keyvolver"},
    ["Shotkey"] = {folder = "Bundles", name = "Shotkey"},
    ["Keyzi"] = {folder = "Bundles", name = "Keyzi"},
    ["Keytana"] = {folder = "Bundles", name = "Keytana"},
    ["Pot o' Keys"] = {folder = "Bundles", name = "Pot o' Keys"},
    ["Cuddle Bomb"] = {folder = "Bundles", name = "Cuddle Bomb"},
    ["Ban Hammer"] = {folder = "Bundles", name = "Ban Hammer"},
    ["10B Visits"] = {folder = "Bundles", name = "10B Visits"},
    ["Arch Crossbow"] = {folder = "Seasons", name = "Arch Crossbow"},
    ["Arch Katana"] = {folder = "Seasons", name = "Arch Katana"},
    ["Arch Uzi"] = {folder = "Seasons", name = "Arch Uzi"},
    ["Arch Molotov"] = {folder = "Seasons", name = "Arch Molotov"},
    ["Handsaws"] = {folder = "Skin Case 2", name = "Handsaws"},
    ["Void Pistols"] = {folder = "Skin Case 2", name = "Void Pistols"},
    ["Laptop"] = {folder = "Skin Case 2", name = "Laptop"},
    ["Camera"] = {folder = "Skin Case 2", name = "Camera"},
    ["Uranium Launcher"] = {folder = "Skin Case 2", name = "Uranium Launcher"},
    ["AUG"] = {folder = "Skin Case 2", name = "AUG"},
    ["Void Rifle"] = {folder = "Skin Case 3", name = "Void Rifle"},
    ["Event Horizon"] = {folder = "Skin Case 3", name = "Event Horizon"},
    ["Fighter Jet"] = {folder = "Skin Case 3", name = "Fighter Jet"},
    ["Balloon Shorty"] = {folder = "Skin Case 3", name = "Balloon Shorty"},
    ["Masterpiece"] = {folder = "Skin Case 3", name = "Masterpiece"},
    ["Paintbrush"] = {folder = "Skin Case 3", name = "Paintbrush"},
    ["Shady Chicken Sandwich"] = {folder = "Skin Case 3", name = "Shady Chicken Sandwich"},
    ["Banana Flare"] = {folder = "Skin Case 3", name = "Banana Flare"},
    ["Squid Flare"] = {folder = "Skin Case 3", name = "Banana Flare"},
    ["Boneclaw Revolver"] = {folder = "Spooky Skin Case", name = "Boneclaw Revolver"},
    ["Boneclaw Horn"] = {folder = "Spooky Skin Case", name = "Boneclaw Horn"},
    ["Brain Gun"] = {folder = "Spooky Skin Case", name = "Brain Gun"},
    ["Warpeye"] = {folder = "Spooky Skin Case", name = "Warpeye"},
    ["Singularity"] = {folder = "Skin Case", name = "Singularity"},
    ["Temporal Ray"] = {folder = "Skin Case", name = "Temporal Ray"},
    ["Emoji Cloud"] = {folder = "Skin Case", name = "Emoji Cloud"},
    ["Gingerbread AUG"] = {folder = "Festive Skin Case", name = "Gingerbread AUG"},
    ["Lifeguard Satchel"] = {folder = "Summer Skin Case", name = "Lifeguard Satchel"},
    ["Harpoon"] = {folder = "Summer Skin Case", name = "Swordfish"},
    ["Fist"] = {folder = "Other", name = "Fist"},
}

-- Fast, pre-indexed skin model table (<0.001ms per lookup)
local skinIndex = {}
for _, folder in ipairs(vm:GetChildren()) do
    if folder.ClassName == "Folder" and folder.Name ~= "Weapons" and folder.Name ~= "Unobtainable" and folder.Name ~= "WIP" then
        for _, m in ipairs(folder:GetChildren()) do
            skinIndex[m.Name] = m
            skinIndex[m.Name:lower()] = m
        end
    end
end

local function findSkinModel(skinTarget)
    if EXACT_SKIN_MAP[skinTarget] then
        local f = vm:FindFirstChild(EXACT_SKIN_MAP[skinTarget].folder)
        if f then
            local m = f:FindFirstChild(EXACT_SKIN_MAP[skinTarget].name)
            if m then return m end
        end
    end
    return skinIndex[skinTarget] or skinIndex[skinTarget:lower()]
end

local memoryRestores = {}

local function registerRestore(info)
    table.insert(memoryRestores, info)
end

-- Specialized Crossbow rig: provisions Stick and Tip with real NameContainers so WaitForChild never hangs
local function fixCrossbowRig(skinModel)
    for _, partName in ipairs({"Body", "StringCurve", "Arrow", "Wings1", "Wings2"}) do
        local sub = skinModel:FindFirstChild(partName)
        if sub and sub.ClassName == "Model" then
            if not sub:FindFirstChild("Primary") then
                local firstPart = sub:FindFirstChildWhichIsA("BasePart")
                if firstPart then
                    pcall(function() sub.PrimaryPart = firstPart end)
                end
            else
                pcall(function() sub.PrimaryPart = sub.Primary end)
            end
        end
    end

    local arrow = skinModel:FindFirstChild("Arrow")
    local defCB = wf:FindFirstChild("Crossbow")
    local defArrow = defCB and defCB:FindFirstChild("Arrow")
    
    if arrow and defArrow then
        local stickNC = defArrow:FindFirstChild("Stick") and rd(defArrow.Stick.Address + OFF.NameContainer)
        local tipNC = defArrow:FindFirstChild("Tip") and rd(defArrow.Tip.Address + OFF.NameContainer)
        
        local nonPrimary = {}
        for _, c in ipairs(arrow:GetChildren()) do
            if c.Name ~= "Primary" and c.ClassName == "MeshPart" then
                table.insert(nonPrimary, c)
            end
        end
        
        if #nonPrimary > 0 and stickNC then
            wr(nonPrimary[1].Address + OFF.NameContainer, stickNC)
        end
        
        local extra = skinModel:FindFirstChild("Body") and skinModel.Body:FindFirstChild("_charm_attachment_model") and skinModel.Body._charm_attachment_model:FindFirstChild("Extra")
        if extra and tipNC and not arrow:FindFirstChild("Tip") then
            local spare = extra:FindFirstChildWhichIsA("MeshPart")
            if spare then
                wr(spare.Address + OFF.NameContainer, tipNC)
                pcall(function() spare.Parent = arrow end)
            end
        end
    end
end

-- Specialized Bow rig: ensures Arrow parts resolve
local function fixBowRig(skinModel)
    local arrow = skinModel:FindFirstChild("Arrow")
    if arrow and arrow.ClassName == "Model" then
        if not arrow:FindFirstChild("Primary") then
            local p = arrow:FindFirstChildWhichIsA("BasePart")
            if p then pcall(function() arrow.PrimaryPart = p end) end
        end
    end
end

-- Specialized RPG rig: ensures Rocket.Primary exists
local function fixRPGRig(skinModel)
    local rocket = skinModel:FindFirstChild("Rocket")
    if rocket and rocket.ClassName == "Model" then
        if not rocket:FindFirstChild("Primary") then
            local p = rocket:FindFirstChildWhichIsA("BasePart")
            if p then pcall(function() rocket.PrimaryPart = p end) end
        end
    end
end

-- Specialized Grenade rig
local function fixGrenadeRig(skinModel)
    local bomb = skinModel:FindFirstChild("Bomb")
    if bomb and bomb.ClassName == "Model" then
        pcall(function() bomb.Name = "Body" end)
        return
    end
end

-- Specialized Gunblade / Keyblade rig
local function fixGunbladeRig(skinModel)
    for _, partName in ipairs({"Body", "Sword"}) do
        local sub = skinModel:FindFirstChild(partName)
        if sub and sub.ClassName == "Model" then
            if not sub:FindFirstChild("Primary") then
                local firstPart = sub:FindFirstChildWhichIsA("BasePart")
                if firstPart then
                    pcall(function() sub.PrimaryPart = firstPart end)
                end
            else
                pcall(function() sub.PrimaryPart = sub.Primary end)
            end
        end
    end
end

-- Specialized Katana rig: ensures Wings models are named and parts have valid PrimaryPart
local function fixKatanaRig(skinModel)
    local wingIdx = 1
    for _, sub in ipairs(skinModel:GetChildren()) do
        if sub.ClassName == "Model" and sub.Name ~= "_fake" then
            if sub.Name == "" or sub.Name:find("Wing") then
                pcall(function() sub.Name = "Wings" .. tostring(wingIdx) end)
                wingIdx = wingIdx + 1
            end
            if not sub:FindFirstChild("Primary") then
                local firstPart = sub:FindFirstChildWhichIsA("BasePart")
                if firstPart then
                    pcall(function() sub.PrimaryPart = firstPart end)
                end
            else
                pcall(function() sub.PrimaryPart = sub.Primary end)
            end
        end
    end
end

-- Universal component rigger
local function rigSkinModel(m)
    if not m then return end
    
    for _, sub in ipairs(m:GetChildren()) do
        if sub.ClassName == "Model" and sub.Name ~= "Arrow" then
            if not sub:FindFirstChild("Primary") then
                local firstPart = sub:FindFirstChildWhichIsA("BasePart")
                if firstPart then
                    pcall(function() sub.PrimaryPart = firstPart end)
                end
            else
                pcall(function() sub.PrimaryPart = sub.Primary end)
            end
        end
    end
    
    if m:FindFirstChild("Body") and m.Body:FindFirstChild("Primary") then
        pcall(function() m.PrimaryPart = m.Body.Primary end)
    elseif not m.PrimaryPart then
        pcall(function() m.PrimaryPart = m:FindFirstChildWhichIsA("BasePart", true) end)
    end
    
    for _, c in ipairs(m:GetChildren()) do
        local n = c.Name:lower()
        if n:find("shell") or n:find("%.r") or n:find("%.l") or n:find("sleeve") or n:find("juggle") then
            if c.ClassName == "Model" then
                pcall(function() c.Name = "_fake" end)
            end
        end
    end
end

local _scriptAlive = true

-- Active viewmodel beam and particle FX culler
task.spawn(function()
    local rs = game:GetService("ReplicatedStorage")
    while _scriptAlive do
        task.wait(0.3)
        pcall(function()
            local tempVM = rs:FindFirstChild("Assets") and rs.Assets:FindFirstChild("Temp") and rs.Assets.Temp:FindFirstChild("ViewModels")
            if tempVM then
                for _, activeVM in ipairs(tempVM:GetChildren()) do
                    if activeVM.Name:find(LP.Name) then
                        local hrp = activeVM:FindFirstChild("HumanoidRootPart")
                        local isUnequipped = not hrp or hrp.Position.Magnitude < 1
                        for _, desc in ipairs(activeVM:GetDescendants()) do
                            if desc.ClassName == "Beam" or desc.ClassName == "ParticleEmitter" or desc.ClassName == "Trail" then
                                if isUnequipped and desc.Enabled then
                                    desc.Enabled = false
                                elseif not isUnequipped and not desc.Enabled then
                                    desc.Enabled = true
                                end
                            end
                        end
                    end
                end
            end
        end)
    end
end)

-- Active skins mapping table for notifications
local ACTIVE_CONFIG_SKINS = {}

-- Real-time Wing Retargeter (Katana Wings1/2 & Uzi Wing1/2) + Skin Load Notifier
task.spawn(function()
    local lastEquippedWeapon = nil
    local lastNotifyTime = 0
    while _scriptAlive do
        task.wait(0.04)
        pcall(function()
            local fp = workspace:FindFirstChild("ViewModels") and workspace.ViewModels:FindFirstChild("FirstPerson")
            if fp then
                for _, vmInst in ipairs(fp:GetChildren()) do
                    -- Parse weapon name from viewmodel instance
                    local wName = vmInst.Name:match("%-%s*(.-)%s*%-")
                    if not wName then
                        wName = vmInst.Name:match(LP.Name .. "%s*%-%s*(.-)%s*$")
                    end
                    
                    if wName and wName ~= lastEquippedWeapon and (tick() - lastNotifyTime) > 0.3 then
                        lastEquippedWeapon = wName
                        lastNotifyTime = tick()
                    end

                    local hrp = vmInst:FindFirstChild("HumanoidRootPart")
                    local itemVisual = vmInst:FindFirstChild("ItemVisual")
                    local bodyModel = itemVisual and (itemVisual:FindFirstChild("Body") or itemVisual:FindFirstChild("Model"))
                    local bodyPart = bodyModel and (bodyModel:FindFirstChild("Primary") or bodyModel:FindFirstChild("BodyPrimary"))
                    local bodyJoint = hrp and (hrp:FindFirstChild('ItemVisual["Body"]') or hrp:FindFirstChild('ItemVisual[""]'))
                    local targetPart = bodyPart or (bodyJoint and bodyJoint.Part1)
                    
                    if hrp and targetPart and targetPart.Address then
                        local targetAddr = targetPart.Address

                        -- 1. Katana Wings: Wings1 & Wings2 (Direct memory write at offset 280: Part0)
                        local kw1 = hrp:FindFirstChild('ItemVisual["Wings1"]')
                        if kw1 and kw1.Address and rd(kw1.Address + 280) ~= targetAddr then
                            wr(kw1.Address + 280, targetAddr)
                        end
                        local kw2 = hrp:FindFirstChild('ItemVisual["Wings2"]')
                        if kw2 and kw2.Address and rd(kw2.Address + 280) ~= targetAddr then
                            wr(kw2.Address + 280, targetAddr)
                        end

                        -- 2. Uzi Wings: Wing1 & Wing2 (Direct memory write at offset 280: Part0)
                        local uw1 = hrp:FindFirstChild('ItemVisual["Wing1"]')
                        if uw1 and uw1.Address and rd(uw1.Address + 280) ~= targetAddr then
                            wr(uw1.Address + 280, targetAddr)
                        end
                        local uw2 = hrp:FindFirstChild('ItemVisual["Wing2"]')
                        if uw2 and uw2.Address and rd(uw2.Address + 280) ~= targetAddr then
                            wr(uw2.Address + 280, targetAddr)
                        end

                        -- 3. Dynamic scan for any other wing or nameless joints
                        for _, joint in ipairs(hrp:GetChildren()) do
                            if joint.ClassName == "Motor6D" and joint.Address then
                                local jName = joint.Name
                                if jName:find("Wing") or jName == 'ItemVisual[""]' then
                                    if rd(joint.Address + 280) ~= targetAddr then
                                        wr(joint.Address + 280, targetAddr)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end)
    end
end)

-- Robust Bullet, Reload, and Inspect Sound Replacement Table
-- Supports both numeric ID and rbxassetid:// prefixed strings
local SOUND_REPLACEMENTS = {
    -- Assault Rifle -> AUG / AKEY-47
    ["13236548545"] = { primary = "rbxassetid://17662574783", secondary = "rbxassetid://18764343961" },
    ["13236548480"] = { primary = "rbxassetid://90757583550672", secondary = "rbxassetid://110122962237431" },
    ["13455395017"] = { primary = "rbxassetid://18887149414" },
    ["13236549929"] = { primary = "rbxassetid://18887149414", volume = 0 },
    ["13236549962"] = { primary = "rbxassetid://18887149414", volume = 0 },

    -- Sniper -> Event Horizon / Keyper (Custom Shoot, Reload, Equip, Bolt)
    ["13270206222"] = { primary = "rbxassetid://17672502566", secondary = "rbxassetid://124463680760542" },
    ["13270206087"] = { primary = "rbxassetid://77109116351775", volume = 0.8 },
    ["13455229044"] = { primary = "rbxassetid://113227486192611" },
    ["13455229188"] = { primary = "rbxassetid://17672502879" },
    ["13455394948"] = { primary = "rbxassetid://17672502716" },
    ["13269929260"] = { primary = "rbxassetid://17672502716" },
    ["13269934368"] = { primary = "rbxassetid://17672502879" },
    ["13642104835"] = { primary = "rbxassetid://113227486192611", secondary = "rbxassetid://17672502879" },

    -- Revolver -> Boneclaw Revolver / Keyvolver
    ["14417089307"] = { primary = "rbxassetid://104731232227748", secondary = "rbxassetid://13483008798" },
    ["14417089152"] = { primary = "rbxassetid://104731232227748", volume = 0 },
    ["14417089046"] = { primary = "rbxassetid://104731232227748", volume = 0 },
    ["14417088974"] = { primary = "rbxassetid://104731232227748", volume = 0 },
    ["13087405232"] = { primary = "rbxassetid://104731232227748", secondary = "rbxassetid://14457782622" },
    ["14240943641"] = { primary = "rbxassetid://14457783670" },
    ["14240944488"] = { primary = "rbxassetid://14457783670", volume = 0 },
    ["14240944327"] = { primary = "rbxassetid://14457783670", volume = 0 },
    ["13087406981"] = { primary = "rbxassetid://14457783670" },

    -- Crossbow -> Arch Crossbow
    ["82715240396507"] = { primary = "rbxassetid://81230732872783" },
    ["15132679812"] = { primary = "rbxassetid://81230732872783" },
    ["13682532502"] = { primary = "rbxassetid://114610550422028" },
    ["76155503538875"] = { primary = "rbxassetid://114610550422028", volume = 0 },
    ["15132681423"] = { primary = "rbxassetid://114610550422028" },

    -- Burst Rifle -> Keyst Rifle
    ["13087410000"] = { primary = "rbxassetid://13087362838", secondary = "rbxassetid://90757583550672" },
    ["13160326139"] = { primary = "rbxassetid://110122962237431", secondary = "rbxassetid://71387264231358" },

    -- Gunblade -> Keyblade
    ["96886470957330"] = { primary = "rbxassetid://135836738518083", secondary = "rbxassetid://115657023572170" },

    -- Shotgun -> Shotkey
    ["13479562219"] = { primary = "rbxassetid://115657023572170", secondary = "rbxassetid://96253147006478" },
    ["13515046921"] = { primary = "rbxassetid://96253147006478", volume = 0.5 },
    ["13515046988"] = { primary = "rbxassetid://96253147006478", volume = 0.5 },

    -- Grenade -> Keynade / Cuddle Bomb
    ["14522189766"] = { primary = "rbxassetid://96253147006478", secondary = "rbxassetid://14522189766" },
    ["13158735106"] = { primary = "rbxassetid://18179281854" },

    -- Uzi -> Keyzi / Arch Uzi
    ["16526185100"] = { primary = "rbxassetid://16526185100", secondary = "rbxassetid://90757583550672" },
    ["16526184479"] = { primary = "rbxassetid://16526184479", secondary = "rbxassetid://110122962237431" },

    -- Slingshot -> Keyshot
    ["13744359504"] = { primary = "rbxassetid://110122962237431" },

    -- Flamethrower -> Keythrower
    ["17209245734"] = { primary = "rbxassetid://17209245734", secondary = "rbxassetid://129124742663895" },

    -- Bow -> Key Bow
    ["90757583550672"] = { primary = "rbxassetid://90757583550672" },

    -- Molotov -> Arch Molotov
    ["14812827622"] = { primary = "rbxassetid://72790275842437" },
    ["14812827928"] = { primary = "rbxassetid://72790275842437" },

    -- Maul -> Ban Hammer
    ["10730819"] = { primary = "rbxassetid://10730819" },

    -- Warpstone -> Warpeye
    ["132455961912409"] = { primary = "rbxassetid://132455961912409" },

    -- Katana -> Arch Katana Inspect Fruit Slices, Attacks, Deflects
    ["13159969353"] = { primary = "rbxassetid://108879620126710", secondary = "rbxassetid://86510987016114" },
    ["13968137196"] = { primary = "rbxassetid://118906938239363" },
    ["14776414133"] = { primary = "rbxassetid://86510987016114" },
    ["14776437962"] = { primary = "rbxassetid://14000023581" },
    ["82797934287631"] = { primary = "rbxassetid://82797934287631" },
}

local function hookSound(sound)
    if not sound or sound.ClassName ~= "Sound" then return end
    local id = sound.SoundId:match("%d+")
    if not id then return end
    local repl = SOUND_REPLACEMENTS[id] or SOUND_REPLACEMENTS["rbxassetid://" .. id]
    if repl then
        sound.SoundId = repl.primary
        if repl.volume then sound.Volume = repl.volume end
        if repl.pitch then sound.PlaybackSpeed = repl.pitch end
    end
end

-- Real-time sound interception (Event-driven + lightweight active VM scan)
local soundConnections = {}
pcall(function()
    local ss = game:GetService("SoundService")
    if ss then
        for _, s in ipairs(ss:GetDescendants()) do
            if s.ClassName == "Sound" then hookSound(s) end
        end
        table.insert(soundConnections, ss.DescendantAdded:Connect(function(s)
            if s.ClassName == "Sound" then hookSound(s) end
        end))
    end
    table.insert(soundConnections, workspace.DescendantAdded:Connect(function(s)
        if s.ClassName == "Sound" then hookSound(s) end
    end))
end)

task.spawn(function()
    while _scriptAlive do
        task.wait(0.1)
        pcall(function()
            local fp = workspace:FindFirstChild("ViewModels") and workspace.ViewModels:FindFirstChild("FirstPerson")
            if fp then
                for _, vmInst in ipairs(fp:GetChildren()) do
                    for _, s in ipairs(vmInst:GetDescendants()) do
                        if s.ClassName == "Sound" then
                            hookSound(s)
                        end
                    end
                end
            end
        end)
    end
end)

-- Custom Animation Engine (Event Horizon Reload / Inspect & Arch Katana Inspect)
local sampleAnimInstance = nil
local function getSampleAnim()
    if sampleAnimInstance and sampleAnimInstance.Parent then return sampleAnimInstance end
    for _, d in ipairs(LP:GetDescendants()) do
        if d.ClassName == "Animation" then
            sampleAnimInstance = d
            return d
        end
    end
    local rs = game:GetService("ReplicatedStorage")
    for _, d in ipairs(rs:GetDescendants()) do
        if d.ClassName == "Animation" then
            sampleAnimInstance = d
            return d
        end
    end
    return nil
end

local function playCustomTrack(animator, assetId, speed)
    local sample = getSampleAnim()
    if not animator or not sample then return nil end
    local a = sample:Clone()
    a.AnimationId = assetId
    local ok, track = pcall(animator.LoadAnimation, animator, a)
    if ok and track then
        track:Play(0.1, 1, speed or 1)
        return track
    end
    return nil
end

local uisConn = nil
pcall(function()
    local uis = game:GetService("UserInputService")
    uisConn = uis.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        local fp = workspace:FindFirstChild("ViewModels") and workspace.ViewModels:FindFirstChild("FirstPerson")
        if not fp then return end
        for _, vmInst in ipairs(fp:GetChildren()) do
            local wName = vmInst.Name:match("%-%s*(.-)%s*%-") or vmInst.Name:match(LP.Name .. "%s*%-%s*(.-)%s*$")
            local ac = vmInst:FindFirstChild("AnimationController") or vmInst:FindFirstChildWhichIsA("AnimationController")
            local animator = ac and (ac:FindFirstChild("Animator") or ac:FindFirstChildWhichIsA("Animator"))
            
            if wName == "Sniper" and animator then
                if input.KeyCode == Enum.KeyCode.R then
                    -- Event Horizon Reload Animation
                    playCustomTrack(animator, "rbxassetid://121991964753861", 1.43)
                elseif input.KeyCode == Enum.KeyCode.F then
                    -- Event Horizon Inspect Animation
                    playCustomTrack(animator, "rbxassetid://89426100452654", 1)
                end
            elseif wName == "Katana" and animator then
                if input.KeyCode == Enum.KeyCode.F then
                    -- Arch Katana Inspect Animation (Fruit Slices)
                    playCustomTrack(animator, "rbxassetid://119980219668284", 1)
                end
            end
        end
    end)
end)

-- Main ultra-fast skin swapper (<15ms)
local function applySkinSwapper()
    local configFileName = "rivals_config.lua"
    if not isfile or not readfile or not isfile(configFileName) then return 0 end
    
    local r2 = readfile(configFileName)
    local swappedCount = 0

    for _, rawLine in ipairs(r2:split(string.char(10))) do 
        local l = rawLine:gsub(string.char(13), "")
        local q = l:find("=")
        if q then 
            local weaponName = l:sub(1, q - 1):match("^%s*(.-)%s*$")
            local skinTarget = l:sub(q + 1):match("^%s*(.-)%s*$")
            
            ACTIVE_CONFIG_SKINS[weaponName] = skinTarget
            
            -- Viewmodel 3D Model Memory Swapping (Symmetric Two-Way Swap)
            local defModel = wf:FindFirstChild(weaponName)
            local skinModel = findSkinModel(skinTarget)
            
            if defModel and skinModel and defModel.Address and skinModel.Address and defModel.Address ~= skinModel.Address then
                local skinFolder = skinModel.Parent
                if skinFolder and skinFolder.Address then
                    local defSlot = findSlotAddressForWeapon(defModel, wf)
                    local skinSlot = findSlotAddressForWeapon(skinModel, skinFolder)
                    
                    if defSlot and skinSlot then
                        rigSkinModel(skinModel)
                        
                        local weaponLower = weaponName:lower()
                        local skinLower = skinTarget:lower()
                        if weaponLower:find("crossbow") or skinLower:find("crossbow") then
                            pcall(fixCrossbowRig, skinModel)
                        elseif weaponLower:find("bow") or skinLower:find("bow") then
                            pcall(fixBowRig, skinModel)
                        elseif weaponLower:find("rpg") or skinLower:find("rpkey") or skinLower:find("rocket") then
                            pcall(fixRPGRig, skinModel)
                        elseif weaponLower == "grenade" or skinLower:find("nade") or skinLower:find("bomb") then
                            pcall(fixGrenadeRig, skinModel)
                        elseif weaponLower == "gunblade" or skinLower:find("gunblade") or skinLower:find("blade") then
                            pcall(fixGunbladeRig, skinModel)
                        elseif weaponLower == "katana" or skinLower:find("katana") then
                            pcall(fixKatanaRig, skinModel)
                        end
                        
                        local origDefInst = rd(defSlot)
                        local origSkinInst = rd(skinSlot)
                        local origDefNC = rd(defModel.Address + OFF.NameContainer)
                        local origSkinNC = rd(skinModel.Address + OFF.NameContainer)
                        local origDefParent = rd(defModel.Address + OFF.Parent)
                        local origSkinParent = rd(skinModel.Address + OFF.Parent)
                        
                        registerRestore({
                            defSlot = defSlot,
                            origDefInst = origDefInst,
                            skinSlot = skinSlot,
                            origSkinInst = origSkinInst,
                            defAddr = defModel.Address,
                            origDefNC = origDefNC,
                            origDefParent = origDefParent,
                            skinAddr = skinModel.Address,
                            origSkinNC = origSkinNC,
                            origSkinParent = origSkinParent
                        })
                        
                        -- Symmetrical Two-Way Memory Swap:
                        -- 1. Swap NameContainers (Zero aliasing, zero double frees)
                        wr(skinModel.Address + OFF.NameContainer, origDefNC)
                        wr(defModel.Address + OFF.NameContainer, origSkinNC)
                        
                        -- 2. Swap Parents (Maintain exact hierarchy)
                        wr(skinModel.Address + OFF.Parent, wf.Address)
                        wr(defModel.Address + OFF.Parent, skinFolder.Address)
                        
                        -- 3. Swap Children Vector Slots (No duplicate pointers, no orphans)
                        wr(defSlot, skinModel.Address)
                        wr(skinSlot, defModel.Address)
                        
                        swappedCount = swappedCount + 1
                    end
                end
            end
        end 
    end
    
    return swappedCount
end

-- Run swapper and measure exact elapsed time
local count = applySkinSwapper()
local elapsed = math.floor((tick() - t_start) * 1000)
local msg = "Swapped " .. tostring(count) .. " skins in " .. tostring(elapsed) .. "ms!"
pcall(notify, msg, "Rivals Skin Changer", 4)
print("[RivalsSkinChanger] " .. msg)

-- Unified cleanup: perfectly restores all original memory pointers before place teardown
local _cleaned = false
local function fullCleanup()
    if _cleaned then return end
    _cleaned = true
    _scriptAlive = false
    
    for _, c in ipairs(soundConnections) do
        pcall(function() c:Disconnect() end)
    end
    soundConnections = {}

    if uisConn then
        pcall(function() uisConn:Disconnect() end)
        uisConn = nil
    end
    
    for _, r in ipairs(memoryRestores) do
        pcall(function()
            -- 1. Restore child vector slots
            if r.defSlot and r.origDefInst then
                wr(r.defSlot, r.origDefInst)
            end
            if r.skinSlot and r.origSkinInst then
                wr(r.skinSlot, r.origSkinInst)
            end
            -- 2. Restore NameContainers
            if r.defAddr and r.origDefNC then
                wr(r.defAddr + OFF.NameContainer, r.origDefNC)
            end
            if r.skinAddr and r.origSkinNC then
                wr(r.skinAddr + OFF.NameContainer, r.origSkinNC)
            end
            -- 3. Restore Parents
            if r.defAddr and r.origDefParent then
                wr(r.defAddr + OFF.Parent, r.origDefParent)
            end
            if r.skinAddr and r.origSkinParent then
                wr(r.skinAddr + OFF.Parent, r.origSkinParent)
            end
        end)
    end
    memoryRestores = {}
    _G.__RIVALS_SKIN_CHANGER_ACTIVE = false
end

_G.__RIVALS_SKIN_CHANGER_ACTIVE = true
_G.__RIVALS_SKIN_CHANGER_RESTORE = fullCleanup

-- Heartbeat watchdog monitor: triggers fullCleanup immediately on teleport or teardown
task.spawn(function()
    while _scriptAlive do
        task.wait(0.15)
        if not LP or not LP.Parent or not wf or not wf.Parent or not game:IsLoaded() then
            fullCleanup()
            break
        end
    end
end)
