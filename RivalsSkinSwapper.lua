-- =========================================================================
--  RIVALS 100% TELEPORT & QUEUE-SAFE SKIN SWAPPER
-- =========================================================================

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

local LP = game:GetService("Players").LocalPlayer
if not LP or game.GameId ~= 6035872082 then return end

local OFF = {
    Parent = 104,
    Children = 120,
    Transparency = 304
}

local A = LP.PlayerScripts:WaitForChild("Assets", 10)
local vm = A and A:WaitForChild("ViewModels", 10)
local wf = vm and vm:WaitForChild("Weapons", 10)

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

local function hideClutter(m)
    if not m then return end
    for _, c in ipairs(m:GetChildren()) do
        local n = c.Name:lower()
        if n:find("leg") or n:find("shell") or n:find("watermelon") or n:find("banana") or n:find("apple") or n:find("wing") then
            for _, desc in ipairs(c:GetDescendants()) do
                if desc.Address then
                    pcall(mwr, "float", desc.Address + OFF.Transparency, 1.0)
                end
            end
        end
    end
end

local function safeSwap(parent, default, skin) 
    if not parent or not default or not skin then return false end
    if default == skin then return false end
    local b, e = ga(parent)
    if not b then return false end
    local sl = fs(b, e, default.Address)
    if not sl then return false end
    
    hideClutter(skin)
    
    local ok = pcall(function() 
        wr(sl, skin.Address) 
    end) 
    return ok
end

local function applySkins()
    local configFileName = "rivals_config.lua"
    if not isfile or not readfile or not isfile(configFileName) then return end
    
    local r2 = readfile(configFileName)
    local en = {}
    for l in r2:gmatch("[^\r\n]+") do 
        local q = l:find("=")
        if q then 
            local w = l:sub(1, q - 1):match("^%s*(.-)%s*$")
            local s = l:sub(q + 1):match("^%s*(.-)%s*$")
            if #w > 0 and #s > 0 then en[#en + 1] = {w, s} end 
        end 
    end
    if #en == 0 or not vm or not wf then return end

    local sc = {}
    for _, f in ipairs(vm:GetChildren()) do 
        if f:IsA("Folder") and f.Name ~= "Weapons" then 
            for _, x in ipairs(f:GetChildren()) do sc[x.Name] = x end 
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

    local count = 0
    for _, item in ipairs(en) do
        local weaponName = item[1]
        local skinTarget = item[2]
        
        local defVm = aW[weaponName]
        local skinVm = sc[skinTarget]
        if defVm and skinVm then 
            if safeSwap(wf, defVm, skinVm) then count = count + 1 end 
        end
    end
    
    for _, w in ipairs(wf:GetChildren()) do hideClutter(w) end
    print("Teleport-Safe Skins Applied! Swapped count:", count)
end

applySkins()
pcall(notify, "Teleport & Queue Safe Skins Active!", "SC", 4)
