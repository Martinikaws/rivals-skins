if not pcall(memory_read, "int", game.Address) then 
    pcall(notify, "UnsafeLua is disabled in executor.", "SC", 5) 
    return 
end

local mrd, mwr, pcall, ipairs, pairs = memory_read, memory_write, pcall, ipairs, pairs
local floor = math.floor

local rd = function(a) 
    local o, v = pcall(mrd, "uintptr_t", a)
    return o and v or nil 
end

local wr = function(a, v) 
    pcall(mwr, "uintptr_t", a, v) 
end

local configFileName = "rivals_config.lua"

if not isfile or not readfile or not isfile(configFileName) then
    pcall(notify, configFileName .. " not found in workspace.", "SC", 5)
    return 
end

local r2 = readfile(configFileName)
local en = {}

for l in r2:gmatch("[^\r\n]+") do 
    local q = l:find("=")
    if q then 
        local w = l:sub(1, q - 1):match("^%s*(.-)%s*$")
        local s = l:sub(q + 1):match("^%s*(.-)%s*$")
        if #w > 0 and #s > 0 then 
            en[#en + 1] = {w, s} 
        end 
    end 
end

if #en == 0 then return end

task.spawn(function() 
    local pfx = function(n) return n:lower():gsub("[%s%-'%.]+", "") end
    local AL = game:GetService("ReplicatedStorage"):WaitForChild("Modules", 10)
    AL = AL and AL:WaitForChild("AnimationLibrary", 10)
    if not AL then return end
    
    local function swapCallbackFolder(folder)
        if not folder then return end
        local abn = {}
        for _, c in ipairs(folder:GetChildren()) do abn[c.Name] = c end
        for _, e in ipairs(en) do 
            local wp, sp = pfx(e[1]), pfx(e[2])
            local spfx = wp .. "_" .. sp .. "_"
            for name, inst in pairs(abn) do 
                if name:sub(1, #spfx) == spfx then 
                    local di = abn[wp .. "_" .. name:sub(#spfx + 1)]
                    if di then 
                        local a8, b8 = mrd("uintptr_t", di.Address + 0x8), mrd("uintptr_t", inst.Address + 0x8)
                        local a10, b10 = mrd("uintptr_t", di.Address + 0x10), mrd("uintptr_t", inst.Address + 0x10)
                        if a8 and b8 and a8 ~= b8 then 
                            mwr("uintptr_t", di.Address + 0x8, b8)
                            mwr("uintptr_t", inst.Address + 0x8, a8) 
                        end 
                        if a10 and b10 and a10 ~= b10 then 
                            mwr("uintptr_t", di.Address + 0x10, b10)
                            mwr("uintptr_t", inst.Address + 0x10, a10) 
                        end
                    end 
                end 
            end 
        end 
    end
    
    swapCallbackFolder(AL:WaitForChild("SoundCallbacks", 10))
    swapCallbackFolder(AL:FindFirstChild("EffectCallbacks"))
end)

local LP = game:GetService("Players").LocalPlayer
if not LP or game.GameId ~= 6035872082 then return end

local OFF = {
    Parent = 104,
    NameContainer = 112,
    Children = 120,
    Transparency = 304
}

local A = LP.PlayerScripts:WaitForChild("Assets", 10)
local vm = A and A:WaitForChild("ViewModels", 10)
local wf = vm and vm:WaitForChild("Weapons", 10)
local tf = A and A:FindFirstChild("Throwables")
local pf = A and A:FindFirstChild("Projectiles")
local mi = A and A:FindFirstChild("Misc")

local ff = function(p, n) return p and p:FindFirstChild(n) end

local ga = function(f) 
    if not f or not f.Address then return end
    local n = rd(f.Address + OFF.Children)
    if not n or n == 0 then return end
    local b, e = rd(n), rd(n + 8)
    if b and e then return b, e end 
end

local fs = function(b, e, t) 
    if not b or not e then return end
    for i = 0, floor((e - b) / 16) - 1 do 
        local a = b + i * 16
        if rd(a) == t then return a end 
    end 
end

local function cleanSubModel(m)
    if not m then return end
    local mainBody = m:FindFirstChild("Body") or m:FindFirstChild("Model") or m:FindFirstChild("Bottom") or m:FindFirstChild("LeftBody") or m:GetChildren()[1]

    for _, c in ipairs(m:GetChildren()) do
        local n = c.Name:lower()
        if n:find("leg") or n:find("shell") or n:find("watermelon") or n:find("banana") or n:find("apple") or n:find("wing") then
            for _, desc in ipairs(c:GetDescendants()) do
                if desc.Address then
                    pcall(mwr, "float", desc.Address + OFF.Transparency, 1.0)
                end
            end
            pcall(mwr, "uintptr_t", c.Address + OFF.Parent, 0)
        elseif mainBody and c ~= mainBody and (n:find("drill") or n:find("slice") or n:find("top") or n:find("front") or n:find("back") or n:find("finger") or n:find("arm")) then
            for _, p in ipairs(c:GetChildren()) do
                p.Parent = mainBody
            end
            pcall(mwr, "uintptr_t", c.Address + OFF.Parent, 0)
        end
    end
end

local function swc(parent, default, skin) 
    if not parent or not default or not skin then return false end
    if default == skin then return false end
    local b, e = ga(parent)
    if not b then return false end
    local sl = fs(b, e, default.Address)
    if not sl then return false end
    
    cleanSubModel(skin)
    
    wr(skin.Address + OFF.NameContainer, rd(default.Address + OFF.NameContainer))
    wr(skin.Address + OFF.Parent, parent.Address)
    
    local ok = pcall(function() 
        wr(sl, skin.Address) 
    end) 
    return ok
end

local function swe(fn, cn, ba) 
    if not mi then return end
    local f = ff(mi, fn)
    if not f then return end
    local d, k = ff(f, ba or "Default") or ff(f, "Standard"), ff(f, cn)
    if not d or not k then return end
    if cn == (ba or "Default") or cn == "Standard" then return end
    swc(f, d, k) 
end

local S = {
    Snowglobe = {SmokeClouds = "Snowglobe"}, ["Emoji Cloud"] = {SmokeClouds = "Emoji Cloud"}, Balance = {SmokeClouds = "Balance"}, Eyeball = {SmokeClouds = "Eyeball"}, Hourglass = {SmokeClouds = "Hourglass"},
    ["Temporal Ray"] = {FreezeEffects = "Temporal"}, ["Bubble Ray"] = {FreezeEffects = "Bubble"}, ["Spider Ray"] = {FreezeEffects = "Cocoon"}, ["Wrapped Freeze Ray"] = {FreezeEffects = "Wrapped"}, ["Gum Ray"] = {FreezeEffects = "Gum"},
    ["Pixel Flamethrower"] = {BurningEffects = "Pixel Flamethrower", FlamethrowerFlames = "Pixel Flamethrower", FlamethrowerAirblasts = "Pixel Flamethrower"},
    ["Jack O'Thrower"] = {BurningEffects = "Jack O'Thrower", FlamethrowerFlames = "Jack O'Thrower"},
    Keythrower = {BurningEffects = "Keythrower", FlamethrowerFlames = "Keythrower", FlamethrowerAirblasts = "Keythrower"},
    Snowblower = {BurningEffects = "Snowblower", FlamethrowerFlames = "Snowblower"},
    Blobsaw = {ChainsawParticles = "Chainsaw"}, Megaphone = {WarHornEffects = "Megaphone"},
    Trampoline = {JumpPads = "Trampoline"}, ["Bounce House"] = {JumpPads = "Bounce House"}, ["Shady Chicken Sandwich"] = {JumpPads = "Shady Chicken Sandwich"}, ["Glorious Jump Pad"] = {JumpPads = "Glorious Jump Pad"}, ["Spider Web"] = {JumpPads = "Spider Web"}, ["Jolly Man"] = {JumpPads = "Jolly Man"},
    ["Electropunk Warper"] = {Portals = "Electropunk Warper"}, ["Experiment W4"] = {Portals = "Experiment W4"}, ["Glitter Warper"] = {Portals = "Glitter Warper"}, ["Frost Warper"] = {Portals = "Frost Warper"}, ["Arcane Warper"] = {Portals = "Arcane Warper"}, ["Hotel Bell"] = {Portals = "Hotel Bell"},
    ["Experiment D15"] = {Vortexes = "Distortion"}, ["Cyber Distortion"] = {Vortexes = "Cyber Distortion"}, Sleighstortion = {Vortexes = "Sleighstortion"}, ["Magma Distortion"] = {Vortexes = "Magma Distortion"}, ["Plasma Distortion"] = {Vortexes = "Plasma Distortion"},
    ["Teleport Disc"] = {BlipEffects = "Teleport Disc"}, Warpeye = {BlipEffects = "Warpeye"},
    ["Evil Trident"] = {DeflectActiveEffects = "Evil Trident", DeflectHitEffects = "Evil Trident"},
    Saber = {DeflectHitEffects = "Saber"},
    ["Lightning Bolt"] = {DeflectHitEffects = "Lightning Bolt"},
    ["New Year Katana"] = {DeflectHitEffects = "New Year Katana"},
    ["Stellar Katana"] = {DeflectActiveEffects = "Stellar Katana", DeflectHitEffects = "Stellar Katana"},
    ["Pixel Katana"] = {DeflectActiveEffects = "Pixel Katana"},
    ["Crystal Katana"] = {DeflectActiveEffects = "Crystal Katana", DeflectHitEffects = "Crystal Katana"},
    ["Arch Katana"] = {DeflectActiveEffects = "Arch Katana", DeflectHitEffects = "Arch Katana"},
    Keytana = {DeflectActiveEffects = "Keytana", DeflectHitEffects = "Keytana"},
    Coffee = {MolotovExplosionEffects = "Coffee", BurningEffects = "Coffee", FireHitboxes = "Coffee"},
    ["Vexed Candle"] = {MolotovExplosionEffects = "Vexed Candle", BurningEffects = "Vexed Candle", FireHitboxes = "Vexed Candle"},
    ["Arch Molotov"] = {BurningEffects = "Arch Molotov", MolotovExplosionEffects = "Arch Molotov", FireHitboxes = "Arch Molotov"},
    ["Lava Lamp"] = {MolotovExplosionEffects = "Lava Lamp", FireHitboxes = "Lava Lamp"},
    ["Hot Coals"] = {FireHitboxes = "Hot Coals"},
    Rainbowthrower = {BurningEffects = "Rainbowthrower", FlamethrowerFlames = "Rainbowthrower"},
    Glitterthrower = {BurningEffects = "Glitterthrower", FlamethrowerFlames = "Glitterthrower"},
    ["Electropunk Warpstone"] = {BlipEffects = "Electropunk Warpstone"},
    Warpstar = {BlipEffects = "Warpstar"}, Warpbone = {BlipEffects = "Warpbone"}, ["Cyber Warpstone"] = {BlipEffects = "Cyber Warpstone"},
    Extinguisher = {BurningEffects = "Extinguisher", FlamethrowerFlames = "Extinguisher"}
}

local function performFullSwap()
    if not vm or not wf then return end

    local sc = {}
    for _, f in ipairs(vm:GetChildren()) do 
        if f:IsA("Folder") and f.Name ~= "Weapons" then 
            for _, x in ipairs(f:GetChildren()) do 
                sc[x.Name] = x 
            end 
        end 
    end

    if vm:FindFirstChild("Bundles") then
        if vm.Bundles:FindFirstChild("Gunblade") then sc["Keyblade"] = vm.Bundles.Gunblade end
        if vm.Bundles:FindFirstChild("Crystal Daggers") then sc["Crystal Daggers"] = vm.Bundles["Crystal Daggers"] end
    end
    if vm:FindFirstChild("Seasons") then
        local seasons = vm.Seasons
        if seasons:FindFirstChild("Katana") then sc["Arch Katana"] = seasons.Katana end
        if seasons:FindFirstChild("Molotov") then sc["Arch Molotov"] = seasons.Molotov end
        if seasons:FindFirstChild("Fists") then sc["Spy Gloves"] = seasons.Fists end
        if seasons:FindFirstChild("Arch Crossbow") then sc["Arch Crossbow"] = seasons["Arch Crossbow"] end
        if seasons:FindFirstChild("Uzi") then sc["Arch Uzi"] = seasons.Uzi end
        if seasons:FindFirstChild("Arch Uzi") then sc["Arch Uzi"] = seasons["Arch Uzi"] end
    end
    if vm:FindFirstChild("Unobtainable") then
        if vm.Unobtainable:FindFirstChild("Armature.001") then sc["Armature.001"] = vm.Unobtainable["Armature.001"] end
    end

    local aW = {}
    for _, w in ipairs(wf:GetChildren()) do aW[w.Name] = w end

    for _, item in ipairs(en) do
        local weaponName = item[1]
        local skinTarget = item[2]
        
        local defVm = aW[weaponName]
        local skinVm = sc[skinTarget]
        if defVm and skinVm then
            swc(wf, defVm, skinVm)
        end
        
        if tf then
            local defTh = tf:FindFirstChild(weaponName)
            local skinTh = tf:FindFirstChild(skinTarget)
            if defTh and skinTh then
                swc(tf, defTh, skinTh)
            end
        end
        
        if pf then
            local defPr = pf:FindFirstChild(weaponName)
            local skinPr = pf:FindFirstChild(skinTarget)
            if defPr and skinPr then
                swc(pf, defPr, skinPr)
            end
        end
        
        if S[skinTarget] and mi then
            for effectCategory, effectName in pairs(S[skinTarget]) do
                swe(effectCategory, effectName)
            end
        end
    end
    
    for _, w in ipairs(wf:GetChildren()) do
        cleanSubModel(w)
    end
end

performFullSwap()

pcall(notify, "Rivals skins applied successfully!", "SC", 4)
