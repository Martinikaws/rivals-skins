-- Rivals skin changer (Matcha)
local t_start = tick()

if not pcall(memory_read, "int", game.Address) then
    return
end

if not game:IsLoaded() then game.Loaded:Wait() end

-- Rivals only
local RIVALS_GAME_ID = 6035872082
local okGameId, gameId = pcall(function() return game.GameId end)
if not okGameId or tonumber(gameId) ~= RIVALS_GAME_ID then return end

local LP = game:GetService("Players").LocalPlayer
while not LP do
    task.wait(0.05)
    LP = game:GetService("Players").LocalPlayer
end

if game.GameId ~= 6035872082 then return end

if type(_G.__RIVALS_SKIN_CHANGER_RESTORE) == "function" then
    pcall(_G.__RIVALS_SKIN_CHANGER_RESTORE)
end
_G.__RIVALS_SKIN_CHANGER_RESTORE = nil
_G.__RIVALS_SKIN_CHANGER_ACTIVE = nil

-- Run lock
local RUN_LOCK_SECONDS = 180
do
    local busy = _G.__RIVALS_SKIN_CHANGER_BUSY
    if type(busy) == "number" and tick() - busy < RUN_LOCK_SECONDS then
        print("[RivalsSkinChanger] Already running - wait for it to finish, then run it again if needed")
        if typeof(notify) == "function" then
            pcall(notify, "Already running - wait for it to finish", "Rivals Skin Changer", 5)
        end
        return
    end
    _G.__RIVALS_SKIN_CHANGER_BUSY = tick()
end

if typeof(notify) == "function" then pcall(notify, "Starting - applying your skins...", "Rivals Skin Changer", 5) end

-- Game folders
local psRoot = LP:WaitForChild("PlayerScripts", 30)
local A = psRoot and psRoot:WaitForChild("Assets", 30)
if not A then
    for _, d in ipairs(LP:GetDescendants()) do
        if d.Name == "Assets" and d.Parent and d.Parent.Name == "PlayerScripts" then A = d break end
    end
end
local vm = A and A:WaitForChild("ViewModels", 30)
local wf = vm and vm:WaitForChild("Weapons", 30)
local mi = A and A:WaitForChild("Misc", 10)
local tf = A and A:FindFirstChild("Throwables")
local pf = A and A:FindFirstChild("Projectiles")
local stf = A and A:FindFirstChild("SpearTightropes")

if not wf then
    _G.__RIVALS_SKIN_CHANGER_BUSY = nil
    return
end

do
    local lastWf, lastVm = -1, -1
    for _ = 1, 20 do
        local wfCount = #wf:GetChildren()
        local vmCount = #vm:GetDescendants()
        if wfCount == lastWf and vmCount == lastVm then break end
        lastWf, lastVm = wfCount, vmCount
        task.wait(0.3)
    end
end

-- Memory
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
    Transparency = 288
}

-- Undo the previous run
local dictCache = {}
do

    local old = _G.__RIVALS_COSMETICS_STATE
    _G.__RIVALS_COSMETICS_STATE = nil
    if type(old) == "table" and type(old.restores) == "table" then
        local fin = game:GetService("ReplicatedStorage"):FindFirstChild("Modules")
        fin = fin and fin:FindFirstChild("Finishers")
        local charmsFolder = A and A:FindFirstChild("Charms")
        if old.key == tostring(fin and fin.Address) .. "/" .. tostring(charmsFolder and charmsFolder.Address) then
            for i = #old.restores, 1, -1 do
                local r = old.restores[i]
                if r.nameSlot then
                    wr(r.nameSlot, r.name)
                else
                    wr(r.sa, r.ia) if r.ca then wr(r.sa + 8, r.ca) end
                    wr(r.sb, r.ib) if r.cb then wr(r.sb + 8, r.cb) end
                    wr(r.ia + OFF.NameContainer, r.na)
                    wr(r.ib + OFF.NameContainer, r.nb)
                    wr(r.ia + OFF.Parent, r.pa)
                    wr(r.ib + OFF.Parent, r.pb)
                end
            end
        end
    end

    local prev = _G.__RIVALS_SKIN_CHANGER_STATE
    _G.__RIVALS_SKIN_CHANGER_STATE = nil

    if type(prev) == "table" and type(prev.restores) == "table" and prev.wfAddr == wf.Address then
        if type(prev.dicts) == "table" then dictCache = prev.dicts end

        for i = #prev.restores, 1, -1 do
            local r = prev.restores[i]
            if r.defSlot and r.origDefInst then
                wr(r.defSlot, r.origDefInst)
                if r.origDefCtrl then wr(r.defSlot + 8, r.origDefCtrl) end
            end
            if r.skinSlot and r.origSkinInst then
                wr(r.skinSlot, r.origSkinInst)
                if r.origSkinCtrl then wr(r.skinSlot + 8, r.origSkinCtrl) end
            end
            if r.defAddr and r.origDefNC then wr(r.defAddr + OFF.NameContainer, r.origDefNC) end
            if r.skinAddr and r.origSkinNC then wr(r.skinAddr + OFF.NameContainer, r.origSkinNC) end
            if r.defAddr and r.origDefParent then wr(r.defAddr + OFF.Parent, r.origDefParent) end
            if r.skinAddr and r.origSkinParent then wr(r.skinAddr + OFF.Parent, r.origSkinParent) end
        end
        local nc = prev.nameCopies or {}
        for i = #nc, 1, -1 do
            if nc[i][2] then wr(nc[i][1], nc[i][2]) end
        end
        local fl = prev.floats or {}
        for i = #fl, 1, -1 do
            pcall(mwr, "float", fl[i][1], fl[i][2])
        end
    end
end

local IMG_OFF = 0xA10

-- Folder slots
local ga = function(f)
    if not f or not f.Address then return end
    local n = rd(f.Address + OFF.Children)
    if not n or n == 0 then return end
    local b, e = rd(n), rd(n + 8)
    if b and e then return b, e end
end

local function findSlotAddress(inst, targetFolder)
    if not inst or not inst.Address or not targetFolder or not targetFolder.Address then return nil end
    local b, e = ga(targetFolder)
    if not b or not e then return nil end
    for slotAddr = b, e - 16, 16 do
        if rd(slotAddr) == inst.Address then
            return slotAddr
        end
    end
    return nil
end

-- Hotbar icons
local function writeImage(label, newAssetId)
    if not _scriptAlive or not label or not label.Address or not newAssetId then return false end
    if not label:IsDescendantOf(game) then return false end
    local a = label.Address
    local ptr = mrd("uintptr_t", a + IMG_OFF)
    if not ptr or ptr < 0x10000000000 or ptr > 0x7FFFFFFFFFFF then return false end
    local cur = mrd("string", ptr)
    if not cur or cur == newAssetId then return true end
    local cap = mrd("uint64_t", a + IMG_OFF + 24) or 31
    local len = #newAssetId
    if len > cap then return false end
    for i = 1, len do
        mwr("uint8_t", ptr + i - 1, string.byte(newAssetId, i))
    end
    mwr("uint8_t", ptr + len, 0)
    mwr("uint64_t", a + IMG_OFF + 16, len)
    return true
end

local function checkImgOffset()
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return end
    local votes, checked = {}, 0
    for _, d in ipairs(pg:GetDescendants()) do
        if d.ClassName == "ImageLabel" and d.Address then
            checked = checked + 1
            for off = 0x980, 0xB00, 8 do
                local ptr = mrd("uintptr_t", d.Address + off)
                if ptr and ptr > 0x10000000000 and ptr < 0x7FFFFFFFFFFF then
                    local s = mrd("string", ptr)
                    if s and s:find("rbxassetid://") then votes[off] = (votes[off] or 0) + 1 end
                end
            end
            if checked >= 40 then break end
        end
    end
    local best, bestN = nil, 0
    for off, n in pairs(votes) do
        if n > bestN then best, bestN = off, n end
    end
    if best and bestN >= 2 then IMG_OFF = best end
end
pcall(checkImgOffset)

-- Viewmodel root fix
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

-- Icon ids
local ITEM_ICONS = {
    ["Assault Rifle"] = {
        ["Standard"] = "rbxassetid://17160682738",
        ["10B Visits"] = "rbxassetid://122165086598560",
        ["AK-47"] = "rbxassetid://17691132793",
        ["AKEY-47"] = "rbxassetid://80017496220683",
        ["Augmented Rifle"] = "rbxassetid://18770192853",
        ["Boneclaw Rifle"] = "rbxassetid://100015754284323",
        ["Drum Gun"] = "rbxassetid://111251887761435",
        ["Gingerbread Augmented Rifle"] = "rbxassetid://85584922619813",
        ["Glorious Assault Rifle"] = "rbxassetid://130669996688265",
        ["Pearl Rifle"] = "rbxassetid://135277426561503",
        ["Phoenix Rifle"] = "rbxassetid://140228738718621",
    },
    ["Battle Axe"] = {
        ["Standard"] = "rbxassetid://93390542043222",
        ["Balloon Axe"] = "rbxassetid://102429983628211",
        ["Ban Axe"] = "rbxassetid://111046431576859",
        ["Cerulean Axe"] = "rbxassetid://76353832683350",
        ["Glorious Battle Axe"] = "rbxassetid://87227212476138",
        ["Keyttle Axe"] = "rbxassetid://122117068984402",
        ["Mimic Axe"] = "rbxassetid://111717370450373",
        ["Nordic Axe"] = "rbxassetid://80052264197135",
        ["Street Sign"] = "rbxassetid://121743888148209",
        ["The Shred"] = "rbxassetid://71234381808727",
        ["Tiki Axe"] = "rbxassetid://87247443182820",
    },
    ["Bow"] = {
        ["Standard"] = "rbxassetid://17160802080",
        ["Balloon Bow"] = "rbxassetid://128957010941029",
        ["Bat Bow"] = "rbxassetid://108984987378619",
        ["Beloved Bow"] = "rbxassetid://110219131386799",
        ["Compound Bow"] = "rbxassetid://17672234242",
        ["Dream Bow"] = "rbxassetid://101089313144218",
        ["Frostbite Bow"] = "rbxassetid://121895626623160",
        ["Glorious Bow"] = "rbxassetid://84201415206621",
        ["Key Bow"] = "rbxassetid://122525140091212",
        ["Palm Bow"] = "rbxassetid://82899577710787",
        ["Raven Bow"] = "rbxassetid://18766861627",
    },
    ["Burst Rifle"] = {
        ["Standard"] = "rbxassetid://17160801983",
        ["Aqua Burst"] = "rbxassetid://18837670807",
        ["Bullpup Burst"] = "rbxassetid://74974560606812",
        ["Electro Rifle"] = "rbxassetid://132227459821018",
        ["Glorious Burst Rifle"] = "rbxassetid://78517330608597",
        ["Keyst Rifle"] = "rbxassetid://78377522426003",
        ["Pine Burst"] = "rbxassetid://132753732294083",
        ["Pixel Burst"] = "rbxassetid://102648809593259",
        ["Sand Bullpup Burst"] = "rbxassetid://130731663986683",
        ["Spectral Burst"] = "rbxassetid://135012309412679",
    },
    ["Chainsaw"] = {
        ["Standard"] = "rbxassetid://17160801873",
        ["Blobsaw"] = "rbxassetid://17825963589",
        ["Buzzsaw"] = "rbxassetid://74057448201836",
        ["Festive Buzzsaw"] = "rbxassetid://80811854818775",
        ["Glorious Chainsaw"] = "rbxassetid://122622447397834",
        ["Handsaws"] = "rbxassetid://18766864583",
        ["Mega Drill"] = "rbxassetid://76663867023998",
        ["Sharksaw"] = "rbxassetid://136881251000627",
    },
    ["Crossbow"] = {
        ["Standard"] = "rbxassetid://140211832612284",
        ["Arch Crossbow"] = "rbxassetid://94981733362451",
        ["Campfire Crossbow"] = "rbxassetid://76911697867059",
        ["Crossbone"] = "rbxassetid://103469183638638",
        ["Frostbite Crossbow"] = "rbxassetid://101536997945363",
        ["Glorious Crossbow"] = "rbxassetid://70875146419725",
        ["Harpoon Crossbow"] = "rbxassetid://107460405492001",
        ["Pixel Crossbow"] = "rbxassetid://115931961841903",
        ["Violin Crossbow"] = "rbxassetid://74401302514014",
    },
    ["Daggers"] = {
        ["Standard"] = "rbxassetid://91885384580845",
        ["Aces"] = "rbxassetid://139089881483398",
        ["Bat Daggers"] = "rbxassetid://92001964015225",
        ["Broken Hearts"] = "rbxassetid://74156924296351",
        ["Cookies"] = "rbxassetid://114482325531769",
        ["Crystal Daggers"] = "rbxassetid://126221748659600",
        ["Glorious Daggers"] = "rbxassetid://76023189104485",
        ["Keynais"] = "rbxassetid://84562761142610",
        ["Paper Planes"] = "rbxassetid://84003122595879",
        ["Shurikens"] = "rbxassetid://135574097643275",
        ["Starfish"] = "rbxassetid://114567820096083",
        ["Toaster"] = "rbxassetid://103344379002564",
    },
    ["Distortion"] = {
        ["Standard"] = "rbxassetid://115712150398379",
        ["Bubble Distortion"] = "rbxassetid://73319804282513",
        ["Cyber Distortion"] = "rbxassetid://88995062151276",
        ["Electropunk Distortion"] = "rbxassetid://109544539643046",
        ["Experiment D15"] = "rbxassetid://103446773933340",
        ["Glorious Distortion"] = "rbxassetid://134722661973710",
        ["Magma Distortion"] = "rbxassetid://81103807698156",
        ["Plasma Distortion"] = "rbxassetid://126813935337091",
        ["Sleighstortion"] = "rbxassetid://111242141481650",
    },
    ["Energy Pistols"] = {
        ["Standard"] = "rbxassetid://79471670126710",
        ["Apex Pistols"] = "rbxassetid://136156057859453",
        ["Enerkey Pistols"] = "rbxassetid://132955794587057",
        ["Glorious Energy Pistols"] = "rbxassetid://114418789647547",
        ["Hacker Pistols"] = "rbxassetid://140621407555872",
        ["Hydro Pistols"] = "rbxassetid://115281889984097",
        ["Hyperlaser Guns"] = "rbxassetid://106947526362970",
        ["New Year Energy Pistols"] = "rbxassetid://126589959779039",
        ["Sol Pistols"] = "rbxassetid://115012735954576",
        ["Soul Pistols"] = "rbxassetid://72213738067158",
        ["Void Pistols"] = "rbxassetid://111278471262300",
    },
    ["Energy Rifle"] = {
        ["Standard"] = "rbxassetid://110259279810005",
        ["Apex Rifle"] = "rbxassetid://88144772234151",
        ["Enerkey Rifle"] = "rbxassetid://80940171527853",
        ["Glorious Energy Rifle"] = "rbxassetid://72632815443247",
        ["Hacker Rifle"] = "rbxassetid://122816271917525",
        ["Hydro Rifle"] = "rbxassetid://73690448730060",
        ["New Year Energy Rifle"] = "rbxassetid://111446782522703",
        ["Sol Rifle"] = "rbxassetid://96272849525291",
        ["Soul Rifle"] = "rbxassetid://129351366788323",
        ["Void Rifle"] = "rbxassetid://95985016411441",
    },
    ["Exogun"] = {
        ["Standard"] = "rbxassetid://17344796376",
        ["Exogourd"] = "rbxassetid://137140750597688",
        ["Glorious Exogun"] = "rbxassetid://129125201034206",
        ["Midnight Festive Exogun"] = "rbxassetid://127612442529810",
        ["Pearl Exogun"] = "rbxassetid://77698515863000",
        ["Ray Gun"] = "rbxassetid://18766861454",
        ["Repulsor"] = "rbxassetid://109263387714628",
        ["Singularity"] = "rbxassetid://17676876756",
        ["Wondergun"] = "rbxassetid://17672060360",
    },
    ["Fists"] = {
        ["Standard"] = "rbxassetid://17160801745",
        ["Boxing Gloves"] = "rbxassetid://17672060486",
        ["Brass Knuckles"] = "rbxassetid://106879679389340",
        ["Crab Claws"] = "rbxassetid://127492118111080",
        ["Festive Fists"] = "rbxassetid://102757458529795",
        ["Fist"] = "rbxassetid://109585706680035",
        ["Fists of Hurt"] = "rbxassetid://140103672289959",
        ["Glorious Fists"] = "rbxassetid://112839297231399",
        ["Pirate Hook"] = "rbxassetid://116717593932616",
        ["Pumpkin Claws"] = "rbxassetid://90996407819750",
        ["Spy Gloves"] = "rbxassetid://117198095640784",
    },
    ["Flamethrower"] = {
        ["Standard"] = "rbxassetid://89455038280473",
        ["Bubblethrower"] = "rbxassetid://76812523297712",
        ["Extinguisher"] = "rbxassetid://95815875434568",
        ["Glitterthrower"] = "rbxassetid://88920581735649",
        ["Glorious Flamethrower"] = "rbxassetid://71676635953177",
        ["Jack O'Thrower"] = "rbxassetid://140280020818514",
        ["Keythrower"] = "rbxassetid://130308634220965",
        ["Lamethrower"] = "rbxassetid://18766862822",
        ["Pixel Flamethrower"] = "rbxassetid://17771752104",
        ["Rainbowthrower"] = "rbxassetid://102070206928252",
        ["Snowblower"] = "rbxassetid://128743586418880",
    },
    ["Flare Gun"] = {
        ["Standard"] = "rbxassetid://17160801627",
        ["Banana Flare"] = "rbxassetid://123589213761955",
        ["Dynamite Gun"] = "rbxassetid://18766865384",
        ["Firework Gun"] = "rbxassetid://17691132917",
        ["Glorious Flare Gun"] = "rbxassetid://115324763672074",
        ["Pocket Volcano"] = "rbxassetid://133260045254190",
        ["Vexed Flare Gun"] = "rbxassetid://116287930550049",
        ["Wrapped Flare Gun"] = "rbxassetid://135638020129378",
    },
    ["Flashbang"] = {
        ["Standard"] = "rbxassetid://17160801529",
        ["Camera"] = "rbxassetid://18766865640",
        ["Disco Ball"] = "rbxassetid://17672061796",
        ["Glorious Flashbang"] = "rbxassetid://96760506528185",
        ["Lightbulb"] = "rbxassetid://125489177573287",
        ["Pixel Flashbang"] = "rbxassetid://132815625474597",
        ["Shining Star"] = "rbxassetid://108392227354212",
        ["Skullbang"] = "rbxassetid://73796957224972",
        ["Sol"] = "rbxassetid://124026864365877",
    },
    ["Freeze Ray"] = {
        ["Standard"] = "rbxassetid://18429552328",
        ["Bubble Ray"] = "rbxassetid://18766865819",
        ["Cooler"] = "rbxassetid://117258208589940",
        ["Glorious Freeze Ray"] = "rbxassetid://120211873831101",
        ["Gum Ray"] = "rbxassetid://121504417727123",
        ["Spider Ray"] = "rbxassetid://136838810668332",
        ["Temporal Ray"] = "rbxassetid://18429552503",
        ["Wrapped Freeze Ray"] = "rbxassetid://76183738050112",
    },
    ["Grappler"] = {
        ["Standard"] = "rbxassetid://103255844976245",
        ["Arcade Claw"] = "rbxassetid://81529455948004",
        ["Fishing Rod"] = "rbxassetid://86648406311812",
        ["Genie Lamp"] = "rbxassetid://118514051859760",
        ["Glorious Grappler"] = "rbxassetid://113576961532090",
        ["Lasso"] = "rbxassetid://77061966583531",
        ["Lifeguard Grappler"] = "rbxassetid://91214316625102",
    },
    ["Grenade"] = {
        ["Standard"] = "rbxassetid://17160801411",
        ["Cuddle Bomb"] = "rbxassetid://116801887274189",
        ["Dynamite"] = "rbxassetid://119066463640901",
        ["Fizz Bomb"] = "rbxassetid://123256093694497",
        ["Frozen Grenade"] = "rbxassetid://96120996159611",
        ["Glorious Grenade"] = "rbxassetid://103034870490455",
        ["Jingle Grenade"] = "rbxassetid://97646859596860",
        ["Keynade"] = "rbxassetid://102785971311114",
        ["Soul Grenade"] = "rbxassetid://85903097459179",
        ["Water Balloon"] = "rbxassetid://18766859819",
        ["Whoopee Cushion"] = "rbxassetid://17672062933",
    },
    ["Grenade Launcher"] = {
        ["Standard"] = "rbxassetid://17250453814",
        ["Balloon Launcher"] = "rbxassetid://137862701599991",
        ["Coconut Launcher"] = "rbxassetid://77621998397460",
        ["Gearnade Launcher"] = "rbxassetid://133756750612042",
        ["Glorious Grenade Launcher"] = "rbxassetid://134130354519919",
        ["Skull Launcher"] = "rbxassetid://103257281022910",
        ["Snowball Launcher"] = "rbxassetid://112349955391111",
        ["Swashbuckler"] = "rbxassetid://17821233828",
        ["Uranium Launcher"] = "rbxassetid://18766860114",
    },
    ["Gunblade"] = {
        ["Standard"] = "rbxassetid://131231034374465",
        ["Boneblade"] = "rbxassetid://126327381608481",
        ["Crude Gunblade"] = "rbxassetid://126996645502136",
        ["Elf's Gunblade"] = "rbxassetid://114103306647123",
        ["Glorious Gunblade"] = "rbxassetid://88003799126136",
        ["Gunsaw"] = "rbxassetid://102700915422689",
        ["Hyper Gunblade"] = "rbxassetid://134415898983004",
        ["Keyblade"] = "rbxassetid://117153249348040",
        ["Sharkbite"] = "rbxassetid://85479471132931",
    },
    ["Handgun"] = {
        ["Standard"] = "rbxassetid://17160801282",
        ["Blaster"] = "rbxassetid://17821234554",
        ["Gingerbread Handgun"] = "rbxassetid://95881238590412",
        ["Glorious Handgun"] = "rbxassetid://85129427786041",
        ["Gumball Handgun"] = "rbxassetid://106890990556815",
        ["Hand Gun"] = "rbxassetid://18837670624",
        ["Pixel Handgun"] = "rbxassetid://82199841278177",
        ["Pumpkin Handgun"] = "rbxassetid://88495685924653",
        ["Sandgun"] = "rbxassetid://111746039012812",
        ["Stealth Handgun"] = "rbxassetid://124919185835138",
        ["Towerstone Handgun"] = "rbxassetid://88654252790032",
        ["Warp Handgun"] = "rbxassetid://102974911528828",
    },
    ["Jump Pad"] = {
        ["Standard"] = "rbxassetid://79459600453621",
        ["Bounce House"] = "rbxassetid://71226436012588",
        ["Flamingo Floatie"] = "rbxassetid://127511599700842",
        ["Glorious Jump Pad"] = "rbxassetid://71803398862947",
        ["Jolly Man"] = "rbxassetid://97375473537804",
        ["Shady Chicken Sandwich"] = "rbxassetid://86361684164972",
        ["Spider Web"] = "rbxassetid://84204578032332",
        ["Trampoline"] = "rbxassetid://103567857194140",
    },
    ["Katana"] = {
        ["Standard"] = "rbxassetid://17160801158",
        ["Arch Katana"] = "rbxassetid://94679283541658",
        ["Crystal Katana"] = "rbxassetid://88872493010693",
        ["Cutlass"] = "rbxassetid://77773371747122",
        ["Evil Trident"] = "rbxassetid://101234805269080",
        ["Glorious Katana"] = "rbxassetid://75588958786035",
        ["Keytana"] = "rbxassetid://118899310989170",
        ["Lightning Bolt"] = "rbxassetid://18768968241",
        ["Linked Sword"] = "rbxassetid://83575725004177",
        ["New Year Katana"] = "rbxassetid://102866488046710",
        ["Pixel Katana"] = "rbxassetid://127922483074145",
        ["Riptide Katana"] = "rbxassetid://136245206320139",
        ["Saber"] = "rbxassetid://17672062341",
        ["Stellar Katana"] = "rbxassetid://72617738655198",
        ["Swordfish"] = "rbxassetid://105748422389590",
    },
    ["Knife"] = {
        ["Standard"] = "rbxassetid://17160800983",
        ["Armature.001"] = "rbxassetid://104026327618871",
        ["Balisong"] = "rbxassetid://93303458333011",
        ["Birthday Candle"] = "rbxassetid://74148583096733",
        ["Caladbolg"] = "rbxassetid://101180142582964",
        ["Candy Cane"] = "rbxassetid://124021545052910",
        ["Chancla"] = "rbxassetid://17672060795",
        ["Glorious Knife"] = "rbxassetid://77448895595314",
        ["Karambit"] = "rbxassetid://18766863586",
        ["Keylisong"] = "rbxassetid://100084654831857",
        ["Keyrambit"] = "rbxassetid://108512337101248",
        ["Machete"] = "rbxassetid://84364955819899",
        ["Pencil"] = "rbxassetid://131450909376802",
        ["Shark Tooth"] = "rbxassetid://124265657652842",
        ["Trophy Knife"] = "rbxassetid://78822531823097",
    },
    ["Maul"] = {
        ["Standard"] = "rbxassetid://81478141693597",
        ["Ban Hammer"] = "rbxassetid://126491383967029",
        ["Clown Hammer"] = "rbxassetid://95487416883384",
        ["Excalibur"] = "rbxassetid://81905348145140",
        ["Giant Popsicle"] = "rbxassetid://91916939347642",
        ["Glorious Maul"] = "rbxassetid://125917253783002",
        ["Ice Maul"] = "rbxassetid://100001888078290",
        ["Sleigh Maul"] = "rbxassetid://114892026951995",
        ["Starforge Maul"] = "rbxassetid://113691709735527",
    },
    ["Medkit"] = {
        ["Standard"] = "rbxassetid://17160800734",
        ["Box of Chocolates"] = "rbxassetid://132421415091712",
        ["Briefcase"] = "rbxassetid://18142172067",
        ["Bucket of Candy"] = "rbxassetid://93791981490691",
        ["Glorious Medkit"] = "rbxassetid://73358160718523",
        ["Ice Cream"] = "rbxassetid://131246559128209",
        ["Laptop"] = "rbxassetid://18770164868",
        ["Medkitty"] = "rbxassetid://125732280509514",
        ["Milk & Cookies"] = "rbxassetid://99156135330432",
        ["Sandwich"] = "rbxassetid://17838232333",
    },
    ["Minigun"] = {
        ["Standard"] = "rbxassetid://17250458611",
        ["Fighter Jet"] = "rbxassetid://70780739230558",
        ["Glorious Minigun"] = "rbxassetid://84246894288637",
        ["Lasergun 3000"] = "rbxassetid://103437974285778",
        ["Pixel Minigun"] = "rbxassetid://18766861798",
        ["Pumpkin Minigun"] = "rbxassetid://77388785880854",
        ["Shark Minigun"] = "rbxassetid://89295703576175",
        ["Wrapped Minigun"] = "rbxassetid://127077702465909",
    },
    ["Molotov"] = {
        ["Standard"] = "rbxassetid://109264750627289",
        ["Arch Molotov"] = "rbxassetid://96589300342777",
        ["Campfire Stick"] = "rbxassetid://83823494489693",
        ["Coffee"] = "rbxassetid://17672061538",
        ["Glorious Molotov"] = "rbxassetid://108930340066987",
        ["Hot Coals"] = "rbxassetid://110423024723304",
        ["Lava Lamp"] = "rbxassetid://79616583726432",
        ["Ship In A Bottle"] = "rbxassetid://125699268308415",
        ["Torch"] = "rbxassetid://115586189235552",
        ["Vexed Candle"] = "rbxassetid://78128648928195",
    },
    ["Paintball Gun"] = {
        ["Standard"] = "rbxassetid://17160853798",
        ["Boba Gun"] = "rbxassetid://18768830660",
        ["Brain Gun"] = "rbxassetid://85970592668118",
        ["Glorious Paintball Gun"] = "rbxassetid://86297318955856",
        ["Ketchup Gun"] = "rbxassetid://76083615050939",
        ["Lemonade Gun"] = "rbxassetid://119390099120478",
        ["Paintballoon Gun"] = "rbxassetid://100129918948246",
        ["Slime Gun"] = "rbxassetid://17672062472",
        ["Snowball Gun"] = "rbxassetid://113685354916533",
    },
    ["Permafrost"] = {
        ["Standard"] = "rbxassetid://74353733133888",
        ["Glorious Permafrost"] = "rbxassetid://119977291442329",
        ["Ice Permafrost"] = "rbxassetid://83722160119335",
        ["Permafrost.rbxm"] = "rbxassetid://77732280270853",
        ["Permasand"] = "rbxassetid://108398272946629",
        ["Snowman Permafrost"] = "rbxassetid://100890626643184",
        ["Starforge Permafrost"] = "rbxassetid://105290041968367",
        ["Temporal Permafrost"] = "rbxassetid://124975247676715",
    },
    ["RPG"] = {
        ["Standard"] = "rbxassetid://17160802243",
        ["Cupcake Launcher"] = "rbxassetid://100541838356180",
        ["Firework Launcher"] = "rbxassetid://75233372670156",
        ["Glorious RPG"] = "rbxassetid://130506879885802",
        ["Nuke Launcher"] = "rbxassetid://17672061995",
        ["Pencil Launcher"] = "rbxassetid://106934516693548",
        ["Pumpkin Launcher"] = "rbxassetid://94648176067808",
        ["Rocket Launcher"] = "rbxassetid://116931956715309",
        ["RPKEY"] = "rbxassetid://108438721125410",
        ["Spaceship Launcher"] = "rbxassetid://18766860860",
        ["Squid Launcher"] = "rbxassetid://130764310743404",
        ["Sundae Launcher"] = "rbxassetid://70578055340962",
    },
    ["Revolver"] = {
        ["Standard"] = "rbxassetid://17160800299",
        ["Boneclaw Revolver"] = "rbxassetid://119174697609264",
        ["Cruise Revolver"] = "rbxassetid://72223124823807",
        ["Desert Eagle"] = "rbxassetid://17821234372",
        ["Glorious Revolver"] = "rbxassetid://118135542031794",
        ["Keyvolver"] = "rbxassetid://87974031410344",
        ["Peppergun"] = "rbxassetid://124178691056979",
        ["Peppermint Sheriff"] = "rbxassetid://95859403750768",
        ["Sheriff"] = "rbxassetid://18770192507",
    },
    ["Riot Shield"] = {
        ["Standard"] = "rbxassetid://121172272442833",
        ["Broken Surfboard"] = "rbxassetid://114987869792187",
        ["Door"] = "rbxassetid://79242603995428",
        ["Energy Shield"] = "rbxassetid://90215439337413",
        ["Glorious Riot Shield"] = "rbxassetid://132866851386509",
        ["Masterpiece"] = "rbxassetid://79914271483818",
        ["Sled"] = "rbxassetid://73881731607231",
        ["Tombstone Shield"] = "rbxassetid://125895528641243",
    },
    ["Satchel"] = {
        ["Standard"] = "rbxassetid://82237471151891",
        ["Advanced Satchel"] = "rbxassetid://113860326910548",
        ["Bag o' Money"] = "rbxassetid://129192426700659",
        ["Glorious Satchel"] = "rbxassetid://100521994805910",
        ["Lifeguard Satchel"] = "rbxassetid://105277357472003",
        ["Notebook Satchel"] = "rbxassetid://124817464748150",
        ["Pizza Box"] = "rbxassetid://99166555665247",
        ["Potion Satchel"] = "rbxassetid://76787046046890",
        ["Suspicious Gift"] = "rbxassetid://76209303162814",
    },
    ["Scythe"] = {
        ["Standard"] = "rbxassetid://17160800186",
        ["Anchor"] = "rbxassetid://18766866743",
        ["Bat Scythe"] = "rbxassetid://131711174838548",
        ["Bug Net"] = "rbxassetid://115620701626004",
        ["Cryo Scythe"] = "rbxassetid://119930754357379",
        ["Crystal Scythe"] = "rbxassetid://73971549402646",
        ["Glorious Scythe"] = "rbxassetid://115811939422419",
        ["Keythe"] = "rbxassetid://114560926055433",
        ["Palm Scythe"] = "rbxassetid://97379805071194",
        ["Plastic Flamingo"] = "rbxassetid://112023194890462",
        ["Sakura Scythe"] = "rbxassetid://133811689655966",
        ["Scythe of Death"] = "rbxassetid://17825996537",
    },
    ["Shorty"] = {
        ["Standard"] = "rbxassetid://17160800091",
        ["Balloon Shorty"] = "rbxassetid://75590262133322",
        ["Bubble Shorty"] = "rbxassetid://111294137896866",
        ["Cannon Shorty"] = "rbxassetid://137616738436928",
        ["Demon Shorty"] = "rbxassetid://116443498278384",
        ["Glorious Shorty"] = "rbxassetid://105834197552222",
        ["Lovely Shorty"] = "rbxassetid://18766862000",
        ["Not So Shorty"] = "rbxassetid://17672062572",
        ["Too Shorty"] = "rbxassetid://18129531276",
        ["Wrapped Shorty"] = "rbxassetid://136522183669611",
    },
    ["Shotgun"] = {
        ["Standard"] = "rbxassetid://17160800007",
        ["Balloon Shotgun"] = "rbxassetid://17821234823",
        ["Broomstick"] = "rbxassetid://118061559757082",
        ["Cactus Shotgun"] = "rbxassetid://131606483507460",
        ["Glorious Shotgun"] = "rbxassetid://71704618059601",
        ["Hyper Shotgun"] = "rbxassetid://18768968419",
        ["Shark Shotgun"] = "rbxassetid://116415689080224",
        ["Shotkey"] = "rbxassetid://93004214983981",
        ["Wrapped Shotgun"] = "rbxassetid://74894345245237",
    },
    ["Slingshot"] = {
        ["Standard"] = "rbxassetid://17160799888",
        ["Boneshot"] = "rbxassetid://86606957688341",
        ["Glorious Slingshot"] = "rbxassetid://101195664167288",
        ["Goalpost"] = "rbxassetid://17672063165",
        ["Harp"] = "rbxassetid://80850043664453",
        ["Keyshot"] = "rbxassetid://74006265601388",
        ["Lucky Horseshoe"] = "rbxassetid://131242126669282",
        ["Palmshot"] = "rbxassetid://109640024736812",
        ["Reindeer Slingshot"] = "rbxassetid://121612921203624",
        ["Stick"] = "rbxassetid://17672063048",
    },
    ["Smoke Grenade"] = {
        ["Standard"] = "rbxassetid://17160799767",
        ["Balance"] = "rbxassetid://18766866168",
        ["Beach Ball"] = "rbxassetid://98068366944697",
        ["Emoji Cloud"] = "rbxassetid://17821234077",
        ["Eyeball"] = "rbxassetid://135911399763146",
        ["Glorious Smoke Grenade"] = "rbxassetid://139714146508398",
        ["Hourglass"] = "rbxassetid://108311418974073",
        ["Snowglobe"] = "rbxassetid://119390465944051",
    },
    ["Sniper"] = {
        ["Standard"] = "rbxassetid://17160799574",
        ["Campfire Sniper"] = "rbxassetid://127790438907599",
        ["Event Horizon"] = "rbxassetid://80749667426815",
        ["Eyething Sniper"] = "rbxassetid://103915302076013",
        ["Gingerbread Sniper"] = "rbxassetid://99943841952995",
        ["Glorious Sniper"] = "rbxassetid://118012090175286",
        ["Hyper Sniper"] = "rbxassetid://18766864081",
        ["Keyper"] = "rbxassetid://85472935605264",
        ["Kraken Sniper"] = "rbxassetid://95011666797584",
        ["Light Fifty"] = "rbxassetid://138029440298487",
        ["Pixel Sniper"] = "rbxassetid://17676081196",
    },
    ["Spear"] = {
        ["Standard"] = "rbxassetid://122801133017271",
        ["Chark Kebab"] = "rbxassetid://74005839754537",
        ["Fork"] = "rbxassetid://105821360943308",
        ["Giant Pencil"] = "rbxassetid://107812045486260",
        ["Glorious Spear"] = "rbxassetid://98259628954838",
        ["Plunger"] = "rbxassetid://82393330699241",
        ["Studio Light"] = "rbxassetid://70443632958263",
        ["Thunderpike"] = "rbxassetid://137630900832105",
    },
    ["Spray"] = {
        ["Standard"] = "rbxassetid://92882887485248",
        ["Boneclaw Spray"] = "rbxassetid://114078818081911",
        ["Campfire Spray"] = "rbxassetid://129294699009828",
        ["Glorious Spray"] = "rbxassetid://138246745001490",
        ["Key Spray"] = "rbxassetid://94061940442700",
        ["Lovely Spray"] = "rbxassetid://131203015026683",
        ["Nail Gun"] = "rbxassetid://110577809934251",
        ["Pine Spray"] = "rbxassetid://128285758736343",
        ["Spray Bottle"] = "rbxassetid://137955019285700",
    },
    ["Subspace Tripmine"] = {
        ["Standard"] = "rbxassetid://17160799418",
        ["Dev-in-the-Box"] = "rbxassetid://125056115146240",
        ["DIY Tripmine"] = "rbxassetid://85747991601740",
        ["Don't Press"] = "rbxassetid://17821233203",
        ["Glorious Subspace Tripmine"] = "rbxassetid://112555928142930",
        ["Hazard Sign"] = "rbxassetid://73264353773454",
        ["Pot o' Keys"] = "rbxassetid://125355191847719",
        ["Spring"] = "rbxassetid://18766860615",
        ["Trick or Treat"] = "rbxassetid://101693036028491",
    },
    ["Trowel"] = {
        ["Standard"] = "rbxassetid://17160799172",
        ["Garden Shovel"] = "rbxassetid://18766864873",
        ["Glorious Trowel"] = "rbxassetid://100888500368219",
        ["Paintbrush"] = "rbxassetid://84687920829755",
        ["Plastic Shovel"] = "rbxassetid://17672062201",
        ["Pumpkin Carver"] = "rbxassetid://78827307308671",
        ["Scooper"] = "rbxassetid://100816728062854",
        ["Snow Shovel"] = "rbxassetid://78271338778848",
    },
    ["Uzi"] = {
        ["Standard"] = "rbxassetid://17160798908",
        ["Arch Uzi"] = "rbxassetid://139852585731073",
        ["Demon Uzi"] = "rbxassetid://132973040482576",
        ["Ducky Uzi"] = "rbxassetid://133780419950894",
        ["Electro Uzi"] = "rbxassetid://96806694653207",
        ["Glorious Uzi"] = "rbxassetid://120045334159124",
        ["Keyzi"] = "rbxassetid://100392703246534",
        ["Money Gun"] = "rbxassetid://100705725115757",
        ["Pine Uzi"] = "rbxassetid://82545206964916",
        ["Water Uzi"] = "rbxassetid://17821233590",
    },
    ["War Horn"] = {
        ["Standard"] = "rbxassetid://104600246515190",
        ["Air Horn"] = "rbxassetid://111168146142976",
        ["Boneclaw Horn"] = "rbxassetid://138360812591331",
        ["Glorious War Horn"] = "rbxassetid://96293355496772",
        ["Lifeguard Whistle"] = "rbxassetid://93791958663348",
        ["Mammoth Horn"] = "rbxassetid://93076834584542",
        ["Megaphone"] = "rbxassetid://107074211847347",
        ["Trumpet"] = "rbxassetid://88975601634708",
    },
    ["Warper"] = {
        ["Standard"] = "rbxassetid://88033795039891",
        ["Arcane Warper"] = "rbxassetid://83632373572638",
        ["Bubbler"] = "rbxassetid://106002684466857",
        ["Electropunk Warper"] = "rbxassetid://75386728379756",
        ["Experiment W4"] = "rbxassetid://126884960764998",
        ["Frost Warper"] = "rbxassetid://70539216094396",
        ["Glitter Warper"] = "rbxassetid://94607497565715",
        ["Glorious Warper"] = "rbxassetid://95823647035211",
        ["Hotel Bell"] = "rbxassetid://117742703173821",
    },
    ["Warpstone"] = {
        ["Standard"] = "rbxassetid://94035693279005",
        ["Cyber Warpstone"] = "rbxassetid://133002984228937",
        ["Electropunk Warpstone"] = "rbxassetid://75299042976369",
        ["Glorious Warpstone"] = "rbxassetid://137583560042806",
        ["Teleport Disc"] = "rbxassetid://104608154111107",
        ["Unstable Warpstone"] = "rbxassetid://110083777654388",
        ["Warp Juice"] = "rbxassetid://74381576761026",
        ["Warpbone"] = "rbxassetid://96452209607150",
        ["Warpeye"] = "rbxassetid://127023603234857",
        ["Warpstar"] = "rbxassetid://102652397897598",
    },
    ["Wildcat"] = {
        ["Standard"] = "rbxassetid://77401164737509",
        ["Glorious Wildcat"] = "rbxassetid://115657943825380",
        ["Plasma Wildcat"] = "rbxassetid://86238922896100",
    },
}

local STANDARD_ICON_MAP = {
    ["rbxassetid://17160682738"] = "Assault Rifle",
    ["rbxassetid://93390542043222"] = "Battle Axe",
    ["rbxassetid://17160802080"] = "Bow",
    ["rbxassetid://17160801983"] = "Burst Rifle",
    ["rbxassetid://17160801873"] = "Chainsaw",
    ["rbxassetid://140211832612284"] = "Crossbow",
    ["rbxassetid://91885384580845"] = "Daggers",
    ["rbxassetid://115712150398379"] = "Distortion",
    ["rbxassetid://79471670126710"] = "Energy Pistols",
    ["rbxassetid://110259279810005"] = "Energy Rifle",
    ["rbxassetid://17344796376"] = "Exogun",
    ["rbxassetid://17160801745"] = "Fists",
    ["rbxassetid://89455038280473"] = "Flamethrower",
    ["rbxassetid://17160801627"] = "Flare Gun",
    ["rbxassetid://17160801529"] = "Flashbang",
    ["rbxassetid://18429552328"] = "Freeze Ray",
    ["rbxassetid://103255844976245"] = "Grappler",
    ["rbxassetid://17160801411"] = "Grenade",
    ["rbxassetid://17250453814"] = "Grenade Launcher",
    ["rbxassetid://131231034374465"] = "Gunblade",
    ["rbxassetid://17160801282"] = "Handgun",
    ["rbxassetid://79459600453621"] = "Jump Pad",
    ["rbxassetid://17160801158"] = "Katana",
    ["rbxassetid://17160800983"] = "Knife",
    ["rbxassetid://81478141693597"] = "Maul",
    ["rbxassetid://17160800734"] = "Medkit",
    ["rbxassetid://17250458611"] = "Minigun",
    ["rbxassetid://109264750627289"] = "Molotov",
    ["rbxassetid://17160853798"] = "Paintball Gun",
    ["rbxassetid://74353733133888"] = "Permafrost",
    ["rbxassetid://17160802243"] = "RPG",
    ["rbxassetid://17160800299"] = "Revolver",
    ["rbxassetid://121172272442833"] = "Riot Shield",
    ["rbxassetid://82237471151891"] = "Satchel",
    ["rbxassetid://17160800186"] = "Scythe",
    ["rbxassetid://17160800091"] = "Shorty",
    ["rbxassetid://17160800007"] = "Shotgun",
    ["rbxassetid://17160799888"] = "Slingshot",
    ["rbxassetid://17160799767"] = "Smoke Grenade",
    ["rbxassetid://17160799574"] = "Sniper",
    ["rbxassetid://122801133017271"] = "Spear",
    ["rbxassetid://92882887485248"] = "Spray",
    ["rbxassetid://17160799418"] = "Subspace Tripmine",
    ["rbxassetid://17160799172"] = "Trowel",
    ["rbxassetid://17160798908"] = "Uzi",
    ["rbxassetid://104600246515190"] = "War Horn",
    ["rbxassetid://88033795039891"] = "Warper",
    ["rbxassetid://94035693279005"] = "Warpstone",
    ["rbxassetid://77401164737509"] = "Wildcat",
}

-- Skin models
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
    ["Warpbone"] = {folder = "Spooky Skin Case", name = "Warpbone"},
    ["Warpstar"] = {folder = "Spooky Skin Case", name = "Warpstar"},
    ["Bat Bow"] = {folder = "Spooky Skin Case", name = "Bat Bow"},
    ["Bat Daggers"] = {folder = "Spooky Skin Case", name = "Bat Daggers"},
    ["Bat Scythe"] = {folder = "Spooky Skin Case", name = "Bat Scythe"},
    ["Blobsaw"] = {folder = "Spooky Skin Case", name = "Blobsaw"},
    ["Candy Bag"] = {folder = "Spooky Skin Case", name = "Candy Bag"},
    ["Candy Bucket"] = {folder = "Spooky Skin Case", name = "Bucket Of Candy"},
    ["Bucket Of Candy"] = {folder = "Spooky Skin Case", name = "Bucket Of Candy"},
    ["Jack O'Launcher"] = {folder = "Spooky Skin Case", name = "Jack O'Launcher"},
    ["Jack O'Thrower"] = {folder = "Spooky Skin Case", name = "Jack O'Thrower"},
    ["Pumpkin Carver"] = {folder = "Spooky Skin Case", name = "Pumpkin Carver"},
    ["Pumpkin Claws"] = {folder = "Spooky Skin Case", name = "Pumpkin Claws"},
    ["Pumpkin Handgun"] = {folder = "Spooky Skin Case", name = "Pumpkin Handgun"},
    ["Pumpkin Minigun"] = {folder = "Spooky Skin Case", name = "Pumpkin Minigun"},
    ["Scythe of Death"] = {folder = "Spooky Skin Case", name = "Scythe of Death"},
    ["Soul Grenade"] = {folder = "Spooky Skin Case", name = "Soul Grenade"},
    ["Soul Pistols"] = {folder = "Spooky Skin Case", name = "Soul Pistols"},
    ["Soul Rifle"] = {folder = "Spooky Skin Case", name = "Soul Rifle"},
    ["Spider Ray"] = {folder = "Spooky Skin Case", name = "Spider Ray"},
    ["Spider Web"] = {folder = "Spooky Skin Case", name = "Spider Web"},
    ["Tombstone Shield"] = {folder = "Spooky Skin Case", name = "Tombstone Shield"},
    ["Vexed Candle"] = {folder = "Spooky Skin Case", name = "Vexed Candle"},
    ["Vexed Flare Gun"] = {folder = "Spooky Skin Case", name = "Vexed Flare Gun"},
    ["Air Horn"] = {folder = "Community Skin Case", name = "Air Horn"},
    ["Anchor"] = {folder = "Community Skin Case", name = "Anchor"},
    ["Balance"] = {folder = "Community Skin Case", name = "Balance"},
    ["Banana"] = {folder = "Community Skin Case", name = "Banana"},
    ["Bongos"] = {folder = "Community Skin Case", name = "Bongos"},
    ["Boombox"] = {folder = "Community Skin Case", name = "Boombox"},
    ["Broken Hearts"] = {folder = "Community Skin Case", name = "Broken Hearts"},
    ["Bubbler"] = {folder = "Community Skin Case", name = "Bubbler"},
    ["Cardboard Gun"] = {folder = "Community Skin Case", name = "Cardboard Gun"},
    ["Cupcake Launcher"] = {folder = "Community Skin Case", name = "Cupcake Launcher"},
    ["Donut Gun"] = {folder = "Community Skin Case", name = "Donut Gun"},
    ["Double Bass"] = {folder = "Community Skin Case", name = "Double Bass"},
    ["Dragon Hammer"] = {folder = "Community Skin Case", name = "Dragon Hammer"},
    ["Eyeball"] = {folder = "Community Skin Case", name = "Eyeball"},
    ["Frying Pan"] = {folder = "Community Skin Case", name = "Frying Pan"},
    ["Genie Lamp"] = {folder = "Community Skin Case", name = "Genie Lamp"},
    ["Giggle Grenade"] = {folder = "Community Skin Case", name = "Giggle Grenade"},
    ["Giggle Gun"] = {folder = "Community Skin Case", name = "Giggle Gun"},
    ["Glove Knife"] = {folder = "Community Skin Case", name = "Glove Knife"},
    ["Guitar"] = {folder = "Community Skin Case", name = "Guitar"},
    ["Hotel Bell"] = {folder = "Community Skin Case", name = "Hotel Bell"},
    ["Hourglass"] = {folder = "Community Skin Case", name = "Hourglass"},
    ["Katana"] = {folder = "Community Skin Case", name = "Katana"},
    ["Light Fifty"] = {folder = "Community Skin Case", name = "Light Fifty"},
    ["Lightning Bolt"] = {folder = "Community Skin Case", name = "Lightning Bolt"},
    ["Lollipop Hammer"] = {folder = "Community Skin Case", name = "Lollipop Hammer"},
    ["Magic Wand"] = {folder = "Community Skin Case", name = "Magic Wand"},
    ["Maracas"] = {folder = "Community Skin Case", name = "Maracas"},
    ["Megaphone"] = {folder = "Community Skin Case", name = "Megaphone"},
    ["Money Gun"] = {folder = "Community Skin Case", name = "Money Gun"},
    ["Nail Gun"] = {folder = "Community Skin Case", name = "Nail Gun"},
    ["Paper Planes"] = {folder = "Community Skin Case", name = "Paper Planes"},
    ["Pencil Launcher"] = {folder = "Community Skin Case", name = "Pencil Launcher"},
    ["Pencil"] = {folder = "Community Skin Case", name = "Pencil"},
    ["Peppergun"] = {folder = "Community Skin Case", name = "Peppergun"},
    ["Pinata Bat"] = {folder = "Community Skin Case", name = "Pinata Bat"},
    ["Pizza Box"] = {folder = "Community Skin Case", name = "Pizza Box"},
    ["Plunger"] = {folder = "Community Skin Case", name = "Plunger"},
    ["Police Baton"] = {folder = "Community Skin Case", name = "Police Baton"},
    ["Poseidon's Trident"] = {folder = "Community Skin Case", name = "Poseidon's Trident"},
    ["Prismatic Hammer"] = {folder = "Community Skin Case", name = "Prismatic Hammer"},
    ["Record Player"] = {folder = "Community Skin Case", name = "Record Player"},
    ["Rubber Mallet"] = {folder = "Community Skin Case", name = "Rubber Mallet"},
    ["Saxophone"] = {folder = "Community Skin Case", name = "Saxophone"},
    ["Shuriken"] = {folder = "Community Skin Case", name = "Shurikens"},
    ["Shurikens"] = {folder = "Community Skin Case", name = "Shurikens"},
    ["Silly Guitar"] = {folder = "Community Skin Case", name = "Silly Guitar"},
    ["Spatula"] = {folder = "Community Skin Case", name = "Spatula"},
    ["Spray Bottle"] = {folder = "Community Skin Case", name = "Spray Bottle"},
    ["Spring"] = {folder = "Community Skin Case", name = "Spring"},
    ["Street Sign"] = {folder = "Community Skin Case", name = "Street Sign"},
    ["Studio Light"] = {folder = "Community Skin Case", name = "Studio Light"},
    ["Subspace Tripmine"] = {folder = "Community Skin Case", name = "Subspace Tripmine"},
    ["Swordfish"] = {folder = "Community Skin Case", name = "Swordfish"},
    ["Tape Measure"] = {folder = "Community Skin Case", name = "Tape Measure"},
    ["The Ban Hammer"] = {folder = "Community Skin Case", name = "The Ban Hammer"},
    ["Toaster"] = {folder = "Community Skin Case", name = "Toaster"},
    ["Torch"] = {folder = "Community Skin Case", name = "Torch"},
    ["Toy Hammer"] = {folder = "Community Skin Case", name = "Toy Hammer"},
    ["Traffic Cone"] = {folder = "Community Skin Case", name = "Traffic Cone"},
    ["Trampoline"] = {folder = "Community Skin Case", name = "Trampoline"},
    ["Trophy Knife"] = {folder = "Community Skin Case", name = "Trophy Knife"},
    ["Trumpet"] = {folder = "Community Skin Case", name = "Trumpet"},
    ["Violin Crossbow"] = {folder = "Community Skin Case", name = "Violin Crossbow"},
    ["War Horn"] = {folder = "Community Skin Case", name = "War Horn"},
    ["Wrench"] = {folder = "Community Skin Case", name = "Wrench"}
}

-- Skin model lookup
local function findSkinModel(skinName)
    local directMap = EXACT_SKIN_MAP[skinName]
    if directMap and vm then
        local f = vm:FindFirstChild(directMap.folder)
        if f then
            local inst = f:FindFirstChild(directMap.name)
            if inst then return inst end
            for _, c in ipairs(f:GetChildren()) do
                if c.Name:lower() == directMap.name:lower() then return c end
            end
        end
    end

    if not vm then return nil end
    local targetLower = skinName:lower()
    for _, folder in ipairs(vm:GetChildren()) do
        if folder.ClassName == "Folder" and folder.Name ~= "Weapons" then
            local inst = folder:FindFirstChild(skinName)
            if inst then return inst end
            for _, c in ipairs(folder:GetChildren()) do
                if c.Name:lower() == targetLower then return c end
            end
        end
    end

    local norm = targetLower:gsub("[%s%-%'%.]+", "")
    for _, folder in ipairs(vm:GetChildren()) do
        if folder.ClassName == "Folder" and folder.Name ~= "Weapons" then
            for _, c in ipairs(folder:GetChildren()) do
                if c.Name:lower():gsub("[%s%-%'%.]+", "") == norm then
                    return c
                end
            end
        end
    end
    return nil
end

-- Memory swap
local memoryRestores = {}
local renamedScripts = {}

local ENABLE_MODEL_SWAPS = true

local ENABLE_RIG_FIXES = false
local ENABLE_SOUND_REPLACEMENT = false

-- Name copies
local ENABLE_NAME_COPIES = true
local nameCopies = {}
local function copyName(target, nameSource)
    if not ENABLE_NAME_COPIES or not target or not nameSource then return false end
    local slot = target.Address + OFF.NameContainer
    local orig, name = rd(slot), rd(nameSource.Address + OFF.NameContainer)
    if not orig or not name or orig == 0 or name == 0 then return false end
    if orig ~= name then
        table.insert(nameCopies, {slot, orig})
        wr(slot, name)
    end
    return true
end

-- Config data
local ENABLE_SKIN_DATA_SYNC = true
local skinDataPairs = {}

local configWrapPairs = {}

local configSkybox = {}
local configSounds = {}

local configLighting = {}

local configFinishers, configCharms = {}, {}

-- Swap two instances
local function swapTwoWay(instA, instB, parentFolder)
    if not ENABLE_MODEL_SWAPS then return false end
    if not instA or not instB or not instA.Address or not instB.Address then return false end
    local a, b = instA.Address, instB.Address
    if a == b then return false end

    local folderA = instA.Parent or parentFolder
    local folderB = instB.Parent or parentFolder

    local slotA = findSlotAddress(instA, folderA)
    local slotB = findSlotAddress(instB, folderB)
    local origDefNC = rd(a + OFF.NameContainer)
    local origSkinNC = rd(b + OFF.NameContainer)
    local origDefParent = rd(a + OFF.Parent)
    local origSkinParent = rd(b + OFF.Parent)

    local origDefCtrl = slotA and rd(slotA + 8)
    local origSkinCtrl = slotB and rd(slotB + 8)

    table.insert(memoryRestores, {
        defSlot = slotA,
        skinSlot = slotB,
        origDefInst = a,
        origSkinInst = b,
        origDefCtrl = origDefCtrl,
        origSkinCtrl = origSkinCtrl,
        defAddr = a,
        skinAddr = b,
        origDefNC = origDefNC,
        origSkinNC = origSkinNC,
        origDefParent = origDefParent,
        origSkinParent = origSkinParent
    })

    if slotA then
        wr(slotA, b)
        if origSkinCtrl then wr(slotA + 8, origSkinCtrl) end
    end
    if slotB then
        wr(slotB, a)
        if origDefCtrl then wr(slotB + 8, origDefCtrl) end
    end
    wr(a + OFF.NameContainer, origSkinNC)
    wr(b + OFF.NameContainer, origDefNC)
    wr(a + OFF.Parent, origSkinParent)
    wr(b + OFF.Parent, origDefParent)
    return true
end

-- Rig fixes (off)
local function fixCrossbowRig(m)
    if not m then return end
    local b = m:FindFirstChild("Body")
    if not b then return end
    local p = b:FindFirstChild("Primary") or b:FindFirstChild("BodyPrimary") or b:FindFirstChildWhichIsA("BasePart")
    if not p then return end

    for _, c in ipairs(m:GetChildren()) do
        if c.Name == "Arch" or c.Name == "String" or c.Name:find("Arrow") or c.Name:find("Bow") or c.Name:find("Wing") then
            local cp = (c.ClassName == "Model" and (c.PrimaryPart or c:FindFirstChild("Primary") or c:FindFirstChildWhichIsA("BasePart"))) or (c:IsA("BasePart") and c)
            if cp and cp.Address and cp ~= p then
                local w = c:FindFirstChild("BodyWeld") or c:FindFirstChild("SkinAttachmentWeld")
                if not w and p.Address then
                    local existingMotor = m:FindFirstChildWhichIsA("Motor6D", true)
                    if existingMotor then
                        pcall(function() existingMotor.Part0 = p end)
                    end
                end
            end
        end
    end
end

local function fixBowRig(m)
    if not m then return end
    local b = m:FindFirstChild("Body")
    if not b then return end
    local p = b:FindFirstChild("Primary") or b:FindFirstChildWhichIsA("BasePart")
    if not p then return end
    for _, c in ipairs(m:GetChildren()) do
        if c.Name:find("String") or c.Name:find("Arrow") or c.Name:find("Limb") then
            if c:IsA("BasePart") and c.Address then
                local m6d = m:FindFirstChild(c.Name .. "Joint") or m:FindFirstChildWhichIsA("Motor6D", true)
                if m6d then
                    pcall(function() m6d.Part0 = p end)
                end
            end
        end
    end
end

local function fixRPGRig(m)
    if not m then return end
    local b = m:FindFirstChild("Body")
    if not b then return end
    local p = b:FindFirstChild("Primary") or b:FindFirstChildWhichIsA("BasePart")
    if not p then return end
    for _, c in ipairs(m:GetChildren()) do
        if c.Name:find("Rocket") or c.Name:find("Missile") or c.Name:find("Key") then
            if c:IsA("BasePart") and c.Address then
                local m6d = m:FindFirstChildWhichIsA("Motor6D", true)
                if m6d then
                    pcall(function() m6d.Part0 = p end)
                end
            end
        end
    end
end

local function fixGrenadeRig(m)
    if not m then return end
    local b = m:FindFirstChild("Body") or m
    local p = b:FindFirstChild("Primary") or b:FindFirstChildWhichIsA("BasePart")
    if not p then return end
    for _, c in ipairs(m:GetChildren()) do
        if c.Name:find("Pin") or c.Name:find("Ring") or c.Name:find("Lever") or c.Name:find("Cap") then
            if c:IsA("BasePart") and c.Address then
                local m6d = m:FindFirstChildWhichIsA("Motor6D", true)
                if m6d then
                    pcall(function() m6d.Part0 = p end)
                end
            end
        end
    end
end

local function fixGunbladeRig(m)
    if not m then return end
    local b = m:FindFirstChild("Body")
    if not b then return end
    local p = b:FindFirstChild("Primary") or b:FindFirstChildWhichIsA("BasePart")
    if not p then return end
    for _, c in ipairs(m:GetChildren()) do
        if c.Name:find("Blade") or c.Name:find("Sheath") or c.Name:find("Key") then
            if c:IsA("BasePart") and c.Address then
                local m6d = m:FindFirstChildWhichIsA("Motor6D", true)
                if m6d then
                    pcall(function() m6d.Part0 = p end)
                end
            end
        end
    end
end

local function fixKatanaRig(m)
    if not m then return end
    local b = m:FindFirstChild("Body")
    if not b then return end
    local p = b:FindFirstChild("Primary") or b:FindFirstChildWhichIsA("BasePart")
    if not p then return end
    for _, c in ipairs(m:GetChildren()) do
        if c.Name:find("Sheath") or c.Name:find("Blade") or c.Name:find("Handle") or c.Name:find("Wing") then
            if c:IsA("BasePart") and c.Address then
                local m6d = m:FindFirstChildWhichIsA("Motor6D", true)
                if m6d then
                    pcall(function() m6d.Part0 = p end)
                end
            end
        end
    end
end

local function rigSkinModel(m)
    if not m then return end
    for _, sub in ipairs(m:GetChildren()) do
        if sub.ClassName == "Model" then
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

-- Effects
local MISC_SPECIAL_MAP = {
    ["Arch Molotov"] = { BurningEffects = "Arch Molotov", MolotovExplosionEffects = "Arch Molotov", FireHitboxes = "Arch Molotov" },
    ["Ship In A Bottle"] = { BurningEffects = "Ship In A Bottle", MolotovExplosionEffects = "Ship In A Bottle", FireHitboxes = "Ship In A Bottle" },
    ["Coffee"] = { BurningEffects = "Coffee", MolotovExplosionEffects = "Coffee", FireHitboxes = "Coffee" },
    ["Vexed Candle"] = { BurningEffects = "Vexed Candle", MolotovExplosionEffects = "Vexed Candle", FireHitboxes = "Vexed Candle" },
    ["Lava Lamp"] = { MolotovExplosionEffects = "Lava Lamp", FireHitboxes = "Lava Lamp" },
    ["Hot Coals"] = { FireHitboxes = "Hot Coals" },
    ["Arch Katana"] = { DeflectHitEffects = "Arch Katana", DeflectActiveEffects = "Arch Katana" },
    ["Pixel Katana"] = { DeflectActiveEffects = "Pixel Katana" },
    ["Keytana"] = { DeflectHitEffects = "Keytana", DeflectActiveEffects = "Keytana" },
    ["Crystal Katana"] = { DeflectHitEffects = "Crystal Katana", DeflectActiveEffects = "Crystal Katana" },
    ["New Year Katana"] = { DeflectHitEffects = "New Year Katana", DeflectActiveEffects = "New Year Katana" },
    ["Stellar Katana"] = { DeflectHitEffects = "Stellar Katana", DeflectActiveEffects = "Stellar Katana" },
    ["Evil Trident"] = { DeflectHitEffects = "Evil Trident", DeflectActiveEffects = "Evil Trident" },
    ["Saber"] = { DeflectHitEffects = "Saber", DeflectActiveEffects = "Saber" },
    ["Lightning Bolt"] = { DeflectHitEffects = "Lightning Bolt", DeflectActiveEffects = "Lightning Bolt" },
    ["Riptide Katana"] = { DeflectHitEffects = "Riptide Katana", DeflectActiveEffects = "Riptide Katana" },
    ["Keythrower"] = { BurningEffects = "Keythrower", FlamethrowerFlames = "Keythrower", FlamethrowerAirblasts = "Keythrower" },
    ["Pixel Flamethrower"] = { BurningEffects = "Pixel Flamethrower", FlamethrowerFlames = "Pixel Flamethrower", FlamethrowerAirblasts = "Pixel Flamethrower" },
    ["Jack O'Thrower"] = { BurningEffects = "Jack O'Thrower", FlamethrowerFlames = "Jack O'Thrower" },
    ["Snowblower"] = { BurningEffects = "Snowblower", FlamethrowerFlames = "Snowblower" },
    ["Rainbowthrower"] = { BurningEffects = "Rainbowthrower", FlamethrowerFlames = "Rainbowthrower" },
    ["Glitterthrower"] = { BurningEffects = "Glitterthrower", FlamethrowerFlames = "Glitterthrower" },
    ["Extinguisher"] = { BurningEffects = "Extinguisher", FlamethrowerFlames = "Extinguisher" },
    ["Bubblethrower"] = { BurningEffects = "Bubblethrower", FlamethrowerFlames = "Bubblethrower" },
    ["Temporal Ray"] = { FreezeEffects = "Temporal" },
    ["Bubble Ray"] = { FreezeEffects = "Bubble" },
    ["Spider Ray"] = { FreezeEffects = "Cocoon" },
    ["Wrapped Freeze Ray"] = { FreezeEffects = "Wrapped" },
    ["Gum Ray"] = { FreezeEffects = "Gum" },
    ["Snowglobe"] = { SmokeClouds = "Snowglobe" },
    ["Emoji Cloud"] = { SmokeClouds = "Emoji Cloud" },
    ["Balance"] = { SmokeClouds = "Balance" },
    ["Eyeball"] = { SmokeClouds = "Eyeball" },
    ["Hourglass"] = { SmokeClouds = "Hourglass" },
    ["Beach Ball"] = { SmokeClouds = "Beach Ball" },
    ["Trampoline"] = { JumpPads = "Trampoline" },
    ["Bounce House"] = { JumpPads = "Bounce House" },
    ["Shady Chicken Sandwich"] = { JumpPads = "Shady Chicken Sandwich" },
    ["Glorious Jump Pad"] = { JumpPads = "Glorious Jump Pad" },
    ["Spider Web"] = { JumpPads = "Spider Web" },
    ["Jolly Man"] = { JumpPads = "Jolly Man" },
    ["Electropunk Warper"] = { Portals = "Electropunk Warper" },
    ["Experiment W4"] = { Portals = "Experiment W4" },
    ["Glitter Warper"] = { Portals = "Glitter Warper" },
    ["Frost Warper"] = { Portals = "Frost Warper" },
    ["Arcane Warper"] = { Portals = "Arcane Warper" },
    ["Hotel Bell"] = { Portals = "Hotel Bell" },
    ["Bubbler"] = { Portals = "Bubbler" },
    ["Experiment D15"] = { Vortexes = "Distortion" },
    ["Cyber Distortion"] = { Vortexes = "Cyber Distortion" },
    ["Sleighstortion"] = { Vortexes = "Sleighstortion" },
    ["Magma Distortion"] = { Vortexes = "Magma Distortion" },
    ["Plasma Distortion"] = { Vortexes = "Plasma Distortion" },
    ["Bubble Distortion"] = { Vortexes = "Bubble Distortion" },
    ["Teleport Disc"] = { BlipEffects = "Teleport Disc" },
    ["Warpeye"] = { BlipEffects = "Warpeye" },
    ["Electropunk Warpstone"] = { BlipEffects = "Electropunk Warpstone" },
    ["Warpstar"] = { BlipEffects = "Warpstar" },
    ["Warpbone"] = { BlipEffects = "Warpbone" },
    ["Cyber Warpstone"] = { BlipEffects = "Cyber Warpstone" },
    ["Wondergun"] = { MuzzleFlashes = "Wondergun" },
    ["Singularity"] = { MuzzleFlashes = "Singularity" },
    ["Midnight Festive Exogun"] = { MuzzleFlashes = "Midnight Festive Exogun" },
    ["Repulsor"] = { MuzzleFlashes = "Repulsor" }
}

local MISC_EXPLOSIONS_MAP = {
    Wondergun = "WondergunExplosionParticles",
    Singularity = "SingularityExplosionParticles",
    ["Midnight Festive Exogun"] = "MidnightFestiveExogunExplosionParticles",
    Repulsor = "RepulsorExplosionParticles",
    Exogourd = "ExogourdExplosionParticles",
    ["Ray Gun"] = "RayGunExplosionParticles",
    Advanced = "AdvancedExplosionParticles",
    ["Cyber Distortion"] = "CyberExplosionParticles",
    Sleighstortion = "SleighstortionExplosionParticles",
    ["Magma Distortion"] = "MagmaDistortionExplosionParticles",
    ["Plasma Distortion"] = "PlasmaDistortionExplosionParticles",
    ["Experiment D15"] = "ExperimentD15ExplosionParticles",
    ["Gum Ray"] = "GumRayExplosionEffect",
    ["Bubble Ray"] = "BubbleRayExplosionEffect",
    ["Spider Ray"] = "SpiderRayExplosionEffect",
    ["Temporal Ray"] = "TemporalRayExplosionEffect",
    ["Wrapped Freeze Ray"] = "WrappedFreezeRayExplosionEffect",
    RPKEY = "RPKEYExplosionEffect"
}

local MISC_EXPLOSIONS_BASE = {
    Exogun = "ExogunExplosionParticles",
    Distortion = "DistortionExplosionParticles",
    ["Freeze Ray"] = "FreezeRayExplosionEffect",
    RPG = "ExplosionEffect"
}

-- Sniper scopes
local SCOPE_RETICLES = {
    ["Pixel Sniper"] = {
        blur = "rbxassetid://18171031143",
        circle = "rbxassetid://18171045114"
    },
    Keyper = {
        blur = "rbxassetid://129335242148588",
        circle = "rbxassetid://81498448678518"
    }
}


local _scriptAlive = true

-- Sound callbacks (off)
local ACTIVE_CONFIG_SKINS = {}

local ENABLE_SOUND_CALLBACKS = false

local function applySoundCallbacks()
    if not ENABLE_SOUND_CALLBACKS then return end
    local rs = game:GetService("ReplicatedStorage")
    local sc = rs:FindFirstChild("Modules") and rs.Modules:FindFirstChild("AnimationLibrary") and rs.Modules.AnimationLibrary:FindFirstChild("SoundCallbacks")
    if not sc then return end

    local function pfx(n)
        return n:lower():gsub("[%s%-%'%.]+", "")
    end

    local abn = {}
    for _, c in ipairs(sc:GetChildren()) do
        abn[c.Name] = c
    end

    for weaponName, skinTarget in pairs(ACTIVE_CONFIG_SKINS) do
        local wp = pfx(weaponName)
        local sp = pfx(skinTarget)
        local spfx = wp .. "_" .. sp .. "_"
        for name, inst in pairs(abn) do
            if name:sub(1, #spfx) == spfx then
                local suffix = name:sub(#spfx + 1)
                local defInst = abn[wp .. "_" .. suffix]

                if defInst and inst and defInst.Address and inst.Address and defInst.Address ~= inst.Address then
                    swapTwoWay(defInst, inst, sc)
                end
            end
        end
    end
end

-- Live features (off)
local ENABLE_PERSISTENT_FEATURES = false

local tickJobs = {}
local function every(interval, fn)
    table.insert(tickJobs, {interval = interval, acc = 0, fn = fn})
end
local tickConn = nil
if ENABLE_PERSISTENT_FEATURES then
    tickConn = game:GetService("RunService").RenderStepped:Connect(function(dt)
        if not _scriptAlive then return end
        for _, j in ipairs(tickJobs) do
            j.acc = j.acc + (dt or 1 / 60)
            if j.acc >= j.interval then
                j.acc = 0
                pcall(j.fn)
            end
        end
    end)
end

do
    local rs = game:GetService("ReplicatedStorage")
    every(0.3, function()
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

local KATANA_WINGS1_CFS = {
    CFrame.new(0.0002, 0.7842, 0.3093, -0.0000, 0.0000, -1.0000, 0.0000, 1.0000, 0.0000, 1.0000, 0.0000, -0.0000),
    CFrame.new(0.0002, 0.7051, 0.5293, -0.0000, 0.0000, -1.0000, 0.0000, 1.0000, 0.0000, 1.0000, 0.0000, -0.0000),
    CFrame.new(0.0002, 0.4365, 0.2489, -0.0000, 0.0000, -1.0000, 0.0000, 1.0000, 0.0000, 1.0000, 0.0000, -0.0000),
    CFrame.new(0.0002, 0.5693, 0.4387, -0.0000, 0.0000, -1.0000, 0.0000, 1.0000, 0.0000, 1.0000, 0.0000, -0.0000),
    CFrame.new(0.0002, 0.9033, 0.6045, -0.0000, 0.0000, -1.0000, 0.0000, 1.0000, 0.0000, 1.0000, 0.0000, -0.0000),
    CFrame.new(0.0002, 1.1191, 0.5842, -0.0000, 0.0000, -1.0000, 0.0000, 1.0000, 0.0000, 1.0000, 0.0000, -0.0000),
    CFrame.new(0.0002, 0.4941, 0.3402, -0.0000, 0.0000, -1.0000, 0.0000, 1.0000, 0.0000, 1.0000, 0.0000, -0.0000),
    CFrame.new(0.0002, 0.8711, 0.4950, 1.0000, 0.0000, 0.0000, 0.0000, 1.0000, 0.0000, 0.0000, 0.0000, 1.0000)
}

local KATANA_WINGS2_CFS = {
    CFrame.new(0.0002, 0.7842, -0.2913, 0.0000, 0.0000, 1.0000, 0.0000, 1.0000, 0.0000, -1.0000, 0.0000, 0.0000),
    CFrame.new(0.0002, 0.7051, -0.5112, 0.0000, 0.0000, 1.0000, 0.0000, 1.0000, 0.0000, -1.0000, 0.0000, 0.0000),
    CFrame.new(0.0002, 0.4365, -0.2307, 0.0000, 0.0000, 1.0000, 0.0000, 1.0000, 0.0000, -1.0000, 0.0000, 0.0000),
    CFrame.new(0.0002, 0.5693, -0.4207, 0.0000, 0.0000, 1.0000, 0.0000, 1.0000, 0.0000, -1.0000, 0.0000, 0.0000),
    CFrame.new(0.0002, 0.9033, -0.5864, 0.0000, 0.0000, 1.0000, 0.0000, 1.0000, 0.0000, -1.0000, 0.0000, 0.0000),
    CFrame.new(0.0002, 1.1191, -0.5662, 0.0000, 0.0000, 1.0000, 0.0000, 1.0000, 0.0000, -1.0000, 0.0000, 0.0000),
    CFrame.new(0.0002, 0.4941, -0.3221, 0.0000, 0.0000, 1.0000, 0.0000, 1.0000, 0.0000, -1.0000, 0.0000, 0.0000),
    CFrame.new(0.0002, 0.8711, -0.4769, 1.0000, 0.0000, 0.0000, 0.0000, 1.0000, 0.0000, 0.0000, 0.0000, 1.0000)
}

local UZI_WING1_CFS = {
    CFrame.new(0.2378, 0.3091, -0.5935, 0.4226, 0.5825, 0.6943, 0.0000, 0.7661, -0.6428, -0.9063, 0.2716, 0.3237),
    CFrame.new(0.2371, 0.3089, -0.5945, 0.4226, 0.5825, 0.6943, 0.0000, 0.7661, -0.6428, -0.9063, 0.2716, 0.3237)
}

local UZI_WING2_CFS = {
    CFrame.new(-0.2374, 0.3092, -0.5944, -0.4226, 0.5825, 0.6943, -0.0000, 0.7661, -0.6428, -0.9063, -0.2716, -0.3237),
    CFrame.new(-0.2384, 0.3089, -0.5944, -0.4226, 0.5825, 0.6943, -0.0000, 0.7661, -0.6428, -0.9063, -0.2716, -0.3237)
}

local lastEquippedWeapon = nil
local function alignWeaponWings()
    local fp = workspace:FindFirstChild("ViewModels") and workspace.ViewModels:FindFirstChild("FirstPerson")
    if not fp then return end

    for _, vmInst in ipairs(fp:GetChildren()) do
        local wName = vmInst.Name:match("%-%s*(.-)%s*%-") or vmInst.Name:match(LP.Name .. "%s*%-%s*(.-)%s*$")
        if wName and wName ~= lastEquippedWeapon then
            lastEquippedWeapon = wName
        end

        local iv = vmInst:FindFirstChild("ItemVisual")
        if iv then
            local body = iv:FindFirstChild("Body") or iv:FindFirstChild("Model")
            local bp = body and (body:FindFirstChild("Primary") or body:FindFirstChild("BodyPrimary"))
            if bp then
                local bcf = bp.CFrame

                local uw1 = iv:FindFirstChild("Wing1")
                local uw2 = iv:FindFirstChild("Wing2")
                if uw1 and uw2 then
                    local idx1 = 1
                    for _, c in ipairs(uw1:GetChildren()) do
                        if c.ClassName == "MeshPart" or c.ClassName == "Part" then
                            local cf = UZI_WING1_CFS[idx1] or UZI_WING1_CFS[2]
                            if cf then c.CFrame = bcf * cf end
                            idx1 = idx1 + 1
                        end
                    end
                    local idx2 = 1
                    for _, c in ipairs(uw2:GetChildren()) do
                        if c.ClassName == "MeshPart" or c.ClassName == "Part" then
                            local cf = UZI_WING2_CFS[idx2] or UZI_WING2_CFS[2]
                            if cf then c.CFrame = bcf * cf end
                            idx2 = idx2 + 1
                        end
                    end
                end

                local kw1 = iv:FindFirstChild("Wings1")
                local kw2 = iv:FindFirstChild("Wings2")
                if kw1 and kw2 then
                    local idx1 = 1
                    for _, c in ipairs(kw1:GetChildren()) do
                        if c.ClassName == "MeshPart" or c.ClassName == "Part" then
                            local cf = KATANA_WINGS1_CFS[idx1]
                            if cf then c.CFrame = bcf * cf end
                            idx1 = idx1 + 1
                        end
                    end
                    local idx2 = 1
                    for _, c in ipairs(kw2:GetChildren()) do
                        if c.ClassName == "MeshPart" or c.ClassName == "Part" then
                            local cf = KATANA_WINGS2_CFS[idx2]
                            if cf then c.CFrame = bcf * cf end
                            idx2 = idx2 + 1
                        end
                    end
                end
            end
        end
    end
end

local SOUND_REPLACEMENTS = {
    ["13236548545"] = { primary = "rbxassetid://17662574783", secondary = "rbxassetid://18764343961" },
    ["13236548480"] = { primary = "rbxassetid://90757583550672", secondary = "rbxassetid://110122962237431" },
    ["13455395017"] = { primary = "rbxassetid://18887149414" },
    ["13236549929"] = { primary = "rbxassetid://18887149414", volume = 0 },
    ["13236549962"] = { primary = "rbxassetid://18887149414", volume = 0 },
    ["13270206222"] = { primary = "rbxassetid://17672502566", secondary = "rbxassetid://124463680760542" },
    ["13270206087"] = { primary = "rbxassetid://77109116351775", volume = 0.8 },
    ["13455229044"] = { primary = "rbxassetid://113227486192611" },
    ["13455229188"] = { primary = "rbxassetid://17672502879" },
    ["13455394948"] = { primary = "rbxassetid://17672502716" },
    ["13269929260"] = { primary = "rbxassetid://17672502716" },
    ["13269934368"] = { primary = "rbxassetid://17672502879" },
    ["13642104835"] = { primary = "rbxassetid://113227486192611", secondary = "rbxassetid://17672502879" },
    ["14417089307"] = { primary = "rbxassetid://104731232227748", secondary = "rbxassetid://13483008798" },
    ["14417089152"] = { primary = "rbxassetid://104731232227748", volume = 0 },
    ["14417088974"] = { primary = "rbxassetid://104731232227748", volume = 0 },
    ["13087405232"] = { primary = "rbxassetid://104731232227748", secondary = "rbxassetid://14457782622" },
    ["14240943641"] = { primary = "rbxassetid://14457783670" },
    ["14240944488"] = { primary = "rbxassetid://14457783670", volume = 0 },
    ["14240944327"] = { primary = "rbxassetid://14457783670", volume = 0 },
    ["13087406981"] = { primary = "rbxassetid://14457783670" },
    ["82715240396507"] = { primary = "rbxassetid://81230732872783" },
    ["15132679812"] = { primary = "rbxassetid://81230732872783" },
    ["13682532502"] = { primary = "rbxassetid://114610550422028" },
    ["76155503538875"] = { primary = "rbxassetid://114610550422028", volume = 0 },
    ["15132681423"] = { primary = "rbxassetid://114610550422028" },
    ["13087410000"] = { primary = "rbxassetid://13087362838", secondary = "rbxassetid://90757583550672" },
    ["13160326139"] = { primary = "rbxassetid://110122962237431", secondary = "rbxassetid://71387264231358" },
    ["96886470957330"] = { primary = "rbxassetid://135836738518083", secondary = "rbxassetid://115657023572170" },
    ["13479562219"] = { primary = "rbxassetid://115657023572170", secondary = "rbxassetid://96253147006478" },
    ["13515046921"] = { primary = "rbxassetid://96253147006478", volume = 0.5 },
    ["13515046988"] = { primary = "rbxassetid://96253147006478", volume = 0.5 },
    ["14522189766"] = { primary = "rbxassetid://96253147006478", secondary = "rbxassetid://14522189766" },
    ["13158735106"] = { primary = "rbxassetid://18179281854" },
    ["16526185100"] = { primary = "rbxassetid://16526185100", secondary = "rbxassetid://90757583550672" },
    ["16526184479"] = { primary = "rbxassetid://16526184479", secondary = "rbxassetid://110122962237431" },
    ["13744359504"] = { primary = "rbxassetid://110122962237431" },
    ["17209245734"] = { primary = "rbxassetid://17209245734", secondary = "rbxassetid://129124742663895" },
    ["90757583550672"] = { primary = "rbxassetid://90757583550672" },
    ["14812827622"] = { primary = "rbxassetid://72790275842437" },
    ["14812827928"] = { primary = "rbxassetid://72790275842437" },
    ["10730819"] = { primary = "rbxassetid://10730819" },
    ["132455961912409"] = { primary = "rbxassetid://132455961912409" },
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

local soundConnections = {}
pcall(function()
    if not ENABLE_SOUND_REPLACEMENT then return end
    local ss = game:GetService("SoundService")
    if ss then
        for _, s in ipairs(ss:GetDescendants()) do
            if s.ClassName == "Sound" then hookSound(s) end
        end
        if not ENABLE_PERSISTENT_FEATURES then return end
        table.insert(soundConnections, ss.DescendantAdded:Connect(function(s)
            if s.ClassName == "Sound" then hookSound(s) end
        end))
    end
    table.insert(soundConnections, workspace.DescendantAdded:Connect(function(s)
        if s.ClassName == "Sound" then hookSound(s) end
    end))
end)

every(0.1, function()
    local fp = workspace:FindFirstChild("ViewModels") and workspace.ViewModels:FindFirstChild("FirstPerson")
    if fp then
        for _, vmInst in ipairs(fp:GetChildren()) do
            for _, s in ipairs(vmInst:GetDescendants()) do
                if s.ClassName == "Sound" then hookSound(s) end
            end
        end
    end
end)

local sampleAnimInstance = nil
local function getSampleAnim()
    if sampleAnimInstance and sampleAnimInstance.Parent then return sampleAnimInstance end
    for _, d in ipairs(LP:GetDescendants()) do
        if d.ClassName == "Animation" then sampleAnimInstance = d return d end
    end
    local rs = game:GetService("ReplicatedStorage")
    for _, d in ipairs(rs:GetDescendants()) do
        if d.ClassName == "Animation" then sampleAnimInstance = d return d end
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
    if not ENABLE_PERSISTENT_FEATURES then return end
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
                    playCustomTrack(animator, "rbxassetid://121991964753861", 1.43)
                elseif input.KeyCode == Enum.KeyCode.F then
                    playCustomTrack(animator, "rbxassetid://89426100452654", 1)
                end
            elseif wName == "Katana" and animator then
                if input.KeyCode == Enum.KeyCode.F then
                    playCustomTrack(animator, "rbxassetid://119980219668284", 1)
                end
            end
        end
    end)
end)

-- Notifications
local function notifyUser(title, text, duration)
    duration = duration or 8
    if typeof(notify) == "function" then
        pcall(notify, text, title, duration)
    end
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration
        })
    end)
end

-- Config
local function parseSkinSwapLine(rawLine)
    local l = rawLine:gsub(string.char(13), "")
    if l:match("^%s*%-%-") then return nil end
    local w, o, t = l:match("^%s*([^|]-)%s*|%s*([^>]-)%s*>%s*(.-)%s*$")
    if w and o and t and #w > 0 and #o > 0 and #t > 0 and o ~= t then return w, o, t end
end

local function parseConfigLine(rawLine)
    local l = rawLine:gsub(string.char(13), ""):gsub(string.char(10), ""):match("^%s*(.-)%s*$")
    if not l or #l == 0 or l:sub(1, 2) == "--" or l:sub(1, 1) == "#" or l == "return {" or l == "}" then
        return nil, nil
    end

    local sep = l:find("=") or l:find(":")
    if not sep then return nil, nil end

    local w = l:sub(1, sep - 1):match("^%s*(.-)%s*$")
    local s = l:sub(sep + 1):match("^%s*(.-)%s*$")
    if not w or not s then return nil, nil end

    s = s:gsub("[,;]+$", ""):match("^%s*(.-)%s*$")

    w = w:gsub('^%["', ''):gsub('"%]$', ''):gsub("^%['", ''):gsub("'%]$", ''):gsub('^%[', ''):gsub('%]$', '')

    w = w:gsub('^"', ''):gsub('"$', ''):gsub("^'", ''):gsub("'$", ''):match("^%s*(.-)%s*$")
    s = s:gsub('^"', ''):gsub('"$', ''):gsub("^'", ''):gsub("'$", ''):match("^%s*(.-)%s*$")

    if w and s and #w > 0 and #s > 0 then
        return w, s
    end
    return nil, nil
end

-- Lua table reading
local NODE_SIZE, NODE_KEY, STRING_DATA = 32, 16, 24

local function nodeKey(node)
    local kp = rd(node + NODE_KEY)
    if not kp or kp < 0x10000 then return nil end
    local ok, str = pcall(mrd, "string", kp + STRING_DATA)
    if ok and type(str) == "string" and #str > 0 and #str < 80 then return str end
end

-- 2^lsizenode (byte +6) is the real node count; walking past it reads other
-- tables' nodes and can match a foreign entry with the same key.
local function nodeCount(t)
    if not t or t < 0x10000 then return nil end
    local ok, l = pcall(mrd, "byte", t + 6)
    if not ok or not l or l < 0 or l > 20 then return nil end
    return 2 ^ l
end

local function walkNodes(base, maxNodes, wanted)
    local found, n, readable, want = {}, 0, 0, 0
    for _ in pairs(wanted) do want = want + 1 end
    for i = 0, maxNodes - 1 do
        local node = base + i * NODE_SIZE
        local k = nodeKey(node)
        if k then
            readable = readable + 1

            if wanted[k] and not found[k] then
                local okT, tt = pcall(mrd, "int", node + 12)
                if okT and tt ~= 0 then found[k], n = node, n + 1 end
            end
        end
        if n == want then break end
        if i == 63 and readable == 0 then break end
    end
    return found, n
end

local function tableFields(t, maxNodes, wanted)
    if not t or t < 0x10000 then return nil, 0 end
    maxNodes = math.min(maxNodes, nodeCount(t) or maxNodes)
    local best, bestN, bestBase = nil, 0, nil
    for off = 0, 56, 8 do
        local base = rd(t + off)
        if base and base > 0x10000 then
            local found, n = walkNodes(base, maxNodes, wanted)
            if n > bestN then best, bestN, bestBase = found, n, base end
        end
    end
    return best, bestN, bestBase
end

local VM_ANCHOR, COS_ANCHOR = {["Assault Rifle"] = true}, {["Glass"] = true}

local SCAN_KEY = "AK-47"

local function walkAround(center, span, wanted)
    local found, n = {}, 0
    local function visit(node)
        local k = nodeKey(node)
        if k and wanted[k] and not found[k] then

            local okT, tt = pcall(mrd, "int", node + 12)
            if okT and tt ~= 0 then found[k], n = node, n + 1 end
        end
    end
    visit(center)
    for i = 1, span do
        visit(center + i * NODE_SIZE)
        visit(center - i * NODE_SIZE)
    end
    return found, n
end

-- Registry route
local ROUTE = {thread = 0x170, slot = 0x178, globalState = 0x18, registry = 0x620, node = 0x18, array = 0x20}
local TAG_TABLE, TAG_THREAD = 7, 10

local function rbyte(a) local ok, v = pcall(mrd, "byte", a) return ok and v or nil end
local function rint(a) local ok, v = pcall(mrd, "int", a) return ok and v or nil end

local function moduleTable(ms)
    if not ms or not ms.Address then return nil end
    local thread = rd(ms.Address + ROUTE.thread)
    if not thread or thread < 0x10000 or rbyte(thread) ~= TAG_THREAD then return nil end
    local g = rd(thread + ROUTE.globalState)
    local reg = g and g > 0x10000 and rd(g + ROUTE.registry)
    if not reg or reg < 0x10000 or rbyte(reg) ~= TAG_TABLE or rint(g + ROUTE.registry + 12) ~= TAG_TABLE then return nil end
    local slot, size, arr = rint(ms.Address + ROUTE.slot), rint(reg + 8), rd(reg + ROUTE.array)
    if not slot or not size or not arr or slot < 1 or slot > size then return nil end
    local t = rd(arr + (slot - 1) * 16)
    if not t or t < 0x10000 or rbyte(t) ~= TAG_TABLE then return nil end
    return t
end

local function nodesOf(t, maxNodes, wanted)
    local base = t and t > 0x10000 and rbyte(t) == TAG_TABLE and rd(t + ROUTE.node)
    if not base or base < 0x10000 then return nil end
    local count = math.min(maxNodes, nodeCount(t) or maxNodes)
    local found, n = walkNodes(base, count, wanted)
    return found, n, base, count
end

local function dictionariesViaRegistry(wantVm, wantCos)
    local mods = game:GetService("ReplicatedStorage"):FindFirstChild("Modules")
    local vm, cos, vmBase, cosBase, vmCount, cosCount
    if wantVm then
        local f = nodesOf(moduleTable(mods and mods:FindFirstChild("ItemLibrary")), 256, {ViewModels = true, ViewModelOrder = true})
        local dict = f and f.ViewModels and f.ViewModelOrder and rd(f.ViewModels)
        local d, _, base, count = nodesOf(dict, 8192, VM_ANCHOR)
        if d and d["Assault Rifle"] then vm, vmBase, vmCount = d["Assault Rifle"], base, count end
    end
    if wantCos then
        local f = nodesOf(moduleTable(mods and mods:FindFirstChild("CosmeticLibrary")), 256, {Cosmetics = true})
        local dict = f and f.Cosmetics and rd(f.Cosmetics)
        local d, _, base, count = nodesOf(dict, 16384, COS_ANCHOR)
        if d and d["Glass"] then cos, cosBase, cosCount = d["Glass"], base, count end
    end
    return vm, cos, vmBase, cosBase, vmCount, cosCount
end

-- Item dictionaries
local function findDictionaries(cache, needVm, needCos)
    local vm, cos = nil, nil

    local forceScan = cache.forceScan
    if not forceScan then
        if needVm and cache.vm and select(2, walkAround(cache.vm, 2048, VM_ANCHOR)) > 0 then vm = cache.vm end
        if needCos and cache.cos and select(2, walkAround(cache.cos, 4096, COS_ANCHOR)) > 0 then cos = cache.cos end
        if (vm or not needVm) and (cos or not needCos) then
            cache.route = "cache"
            return vm, cos
        end
    end

    local okR, rvm, rcos, rvmBase, rcosBase, rvmCount, rcosCount = false, nil, nil, nil, nil, nil, nil
    if not forceScan then
        okR, rvm, rcos, rvmBase, rcosBase, rvmCount, rcosCount =
            pcall(dictionariesViaRegistry, needVm and not vm, needCos and not cos)
    end
    if okR then
        if rvm then vm, cache.vmBase, cache.vmCount = rvm, rvmBase, rvmCount end
        if rcos then cos, cache.cosBase, cache.cosCount = rcos, rcosBase, rcosCount end
    end
    if (vm or not needVm) and (cos or not needCos) then
        cache.vm, cache.cos = vm or cache.vm, cos or cache.cos
        cache.route = "registry"
        return vm, cos
    end

    cache.route, cache.vmBase, cache.cosBase, cache.vmCount, cache.cosCount = "scan", nil, nil, nil, nil

    local job = game.JobId
    local okG, rows = pcall(getgc, {SCAN_KEY})

    if game.JobId ~= job then return nil, nil, "server changed during the scan" end
    for _, r in ipairs(okG and type(rows) == "table" and rows or {}) do

        local f = tableFields(rd(r.addr), 32, {Animations = true, Rarity = true, Type = true})
        if f and f.Animations then
            if needVm and not vm and select(2, walkAround(r.addr, 2048, VM_ANCHOR)) > 0 then vm = r.addr end
        elseif f and f.Rarity and f.Type then
            if needCos and not cos and select(2, walkAround(r.addr, 4096, COS_ANCHOR)) > 0 then cos = r.addr end
        end
    end

    if (needVm and not vm) or (needCos and not cos) then
        if game.JobId ~= job then return nil, nil, "server changed during the scan" end
        local okF, frows = pcall(getgc, {"ViewModels", "Cosmetics"})
        for _, r in ipairs(okF and type(frows) == "table" and frows or {}) do
            if r.key == "ViewModels" and needVm and not vm then
                local f = tableFields(rd(r.addr), 2048, VM_ANCHOR)
                vm = f and f["Assault Rifle"] or vm
            elseif r.key == "Cosmetics" and needCos and not cos then
                local f = tableFields(rd(r.addr), 4096, COS_ANCHOR)
                cos = f and f["Glass"] or cos
            end
        end
        if game.JobId ~= job then return nil, nil, "server changed during the scan" end
    end
    cache.vm, cache.cos = vm or cache.vm, cos or cache.cos
    return vm, cos, (not okG) and "gc scan failed" or nil
end

local VM_FIELDS = {Animations = true, RootPartOffset = true, Image = true, ImageHighResolution = true}
local WRAP_FIELDS = {WrapGroups = true}

-- Animations, offsets, icons, wraps
local function syncSkinData(pairList, wrapPairs, cache)
    if #pairList == 0 and #wrapPairs == 0 then return 0 end
    local vm, cos, err = findDictionaries(cache, #pairList > 0, #wrapPairs > 0)
    if #pairList > 0 and not vm and #wrapPairs > 0 and not cos then return 0, err or "item dictionaries not found" end

    local vmWanted, cosWanted = {}, {}
    for _, p in ipairs(pairList) do vmWanted[p[1]], vmWanted[p[2]] = true, true end
    for _, p in ipairs(wrapPairs) do cosWanted[p[1]], cosWanted[p[2]] = true, true end

    local vmNodes = vm and (cache.vmBase and walkNodes(cache.vmBase, cache.vmCount or 8192, vmWanted) or walkAround(vm, 2048, vmWanted)) or {}
    local cosNodes = cos and (cache.cosBase and walkNodes(cache.cosBase, cache.cosCount or 16384, cosWanted) or walkAround(cos, 4096, cosWanted)) or {}

    local function viewModelSlots(name)
        local node = vmNodes[name]
        local f = node and tableFields(rd(node), 32, VM_FIELDS)
        if f and f.Animations and f.RootPartOffset then
            return {f.Animations, f.RootPartOffset, f.Image or false, f.ImageHighResolution or false}
        end
    end

    local synced, missed = 0, {}
    for _, p in ipairs(pairList) do
        local d, k = viewModelSlots(p[1]), viewModelSlots(p[2])
        local vals = k and {rd(k[1]), rd(k[2]), k[3] and rd(k[3]), k[4] and rd(k[4])}
        if d and vals and vals[1] and vals[2] and vals[1] ~= 0 and vals[2] ~= 0 then

            for j = 1, 4 do
                if d[j] and vals[j] and vals[j] ~= 0 then wr(d[j], vals[j]) end
            end
            synced = synced + 1
        else
            missed[#missed + 1] = p[2]
        end
    end

    local function wrapGroupsSlot(name)
        local node = cosNodes[name]
        local f = node and tableFields(rd(node), 32, WRAP_FIELDS)
        return f and f.WrapGroups
    end
    local wrapsApplied, wrapsMissed = 0, {}
    for _, p in ipairs(wrapPairs) do
        local ownedSlot, targetSlot = wrapGroupsSlot(p[1]), wrapGroupsSlot(p[2])
        local targetGroups = targetSlot and rd(targetSlot)
        if ownedSlot and targetGroups and targetGroups ~= 0 and ownedSlot ~= targetSlot then
            wr(ownedSlot, targetGroups)
            wrapsApplied = wrapsApplied + 1
        else
            wrapsMissed[#wrapsMissed + 1] = p[1] .. "=" .. p[2]
        end
    end
    local note = (#missed > 0) and ("not found: " .. table.concat(missed, ", ")) or err
    return synced, note, wrapsApplied, wrapsMissed, missed
end

-- Skin swaps
local function applySkinSwapper()
    if not isfile or not readfile then
        return 0, "Executor does not support isfile/readfile functions."
    end

    local candidatePaths = {
        "rivals_config.lua",
        "workspace/rivals_config.lua",
        "rivals_config.lua.txt",
        "rivals_config.txt",
        "workspace/rivals_config.txt",
        "rivals_config (1).lua",
        "rivals_config(1).lua",
        "Rivals_Config.lua",
        "rivals_config"
    }

    if typeof(listfiles) == "function" then
        pcall(function()
            for _, folder in ipairs({"", "workspace"}) do
                local files = listfiles(folder) or {}
                for _, f in ipairs(files) do
                    local clean = f:lower():gsub(string.char(92), "/")
                    if clean:find("rivals_config") then
                        table.insert(candidatePaths, f)
                    end
                end
            end
        end)
    end

    local targetFile = nil
    for _, path in ipairs(candidatePaths) do
        local ok, exists = pcall(isfile, path)
        if ok and exists then
            targetFile = path
            break
        end
    end

    if not targetFile then
        return 0, "rivals_config.lua was not found in your executor's workspace folder! Make sure rivals_config.lua is placed in your workspace directory."
    end

    print("[RivalsSkinChanger] Config: " .. tostring(targetFile))
    local okRead, r2 = pcall(readfile, targetFile)
    if not okRead or not r2 then
        return 0, "Failed to read file '" .. tostring(targetFile) .. "'. File may be locked by another application."
    end

    if r2:sub(1, 3) == string.char(239, 187, 191) then
        r2 = r2:sub(4)
    end

    if #r2:gsub("%s+", "") == 0 then
        return 0, "Config file '" .. tostring(targetFile) .. "' is completely empty (0 bytes). Please generate your config on the website."
    end

    if not wf then
        return 0, "Game assets folder (ViewModels.Weapons) is not loaded yet. Are you in a match or shooting range?"
    end

    local parsedPairs = 0
    local nonDefaultPairs = 0
    local missingBaseWeapons = {}
    local missingSkinModels = {}
    local swappedCount = 0
    local skippedNoScript = {}
    local vmMods = LP.PlayerScripts:FindFirstChild("Modules")
    vmMods = vmMods and vmMods:FindFirstChild("ViewModels")

    local jobs, swapJobs, touched, skippedConflicts = {}, {}, {}, {}

    local section = "skins"
    for _, rawLine in ipairs(r2:split(string.char(10))) do
        local header = rawLine:gsub(string.char(13), ""):match("^%s*%[%s*(.-)%s*%]%s*$")
        if header then
            local h = header:lower()

            section = h:find("wrap") and "wraps" or (h:find("sky") and "skybox"
                or (h:find("light") and "lighting" or (h:find("finisher") and "finishers"
                or (h:find("charm") and "charms" or (h:find("sound") and "sounds"
                or (h:find("skin") and "skins" or "other"))))))
        elseif section == "other" then

        elseif section == "finishers" or section == "charms" then
            local owned, target = parseConfigLine(rawLine)
            if owned and target and owned ~= target then
                local list = section == "finishers" and configFinishers or configCharms
                list[#list + 1] = {owned, target}
            end
        elseif section == "wraps" then
            local owned, target = parseConfigLine(rawLine)
            if owned and target then configWrapPairs[#configWrapPairs + 1] = {owned, target} end
        elseif section == "skybox" then
            local key, value = parseConfigLine(rawLine)
            if key and value then configSkybox[key:lower()] = value end
        elseif section == "sounds" then
            local key, value = parseConfigLine(rawLine)
            if key and value then configSounds[key:lower()] = value end
        elseif section == "lighting" then
            local key, value = parseConfigLine(rawLine)
            if key and value then configLighting[key:lower()] = value end
        else
            local weaponName, skinTarget = parseConfigLine(rawLine)
            if weaponName and skinTarget then
                jobs[#jobs + 1] = {weaponName, skinTarget, weaponName}
            else
                local w, owned, target = parseSkinSwapLine(rawLine)
                if w then swapJobs[#swapJobs + 1] = {w, target, owned} end
            end
        end
    end
    for _, j in ipairs(swapJobs) do jobs[#jobs + 1] = j end

    for _, job in ipairs(jobs) do
        local weaponName, skinTarget, srcName = job[1], job[2], job[3]
        local ownedSwap = srcName ~= weaponName
        parsedPairs = parsedPairs + 1
        local skinLower = skinTarget:lower()
        local isSkin = skinLower ~= "default" and skinLower ~= "standard"
        -- Set once the skin's own viewmodel script is in place. That script
        -- finds its effects by their real names, so they must not be renamed.
        local scriptMoved = false

        if isSkin and (touched[skinTarget] or touched[srcName]) then
            table.insert(skippedConflicts, srcName .. " -> " .. skinTarget)
        else
            if isSkin then
                touched[skinTarget], touched[srcName] = true, true
                nonDefaultPairs = nonDefaultPairs + 1
                if not ownedSwap then ACTIVE_CONFIG_SKINS[weaponName] = skinTarget end
                local function findSource()
                    if ownedSwap then return findSkinModel(srcName) end
                    return wf:FindFirstChild(weaponName)
                end

                local defModel = findSource()
                if not defModel then
                    for _ = 1, 6 do
                        task.wait(0.5)
                        defModel = findSource()
                        if defModel then break end
                    end
                end
                if not defModel then
                    table.insert(missingBaseWeapons, srcName)
                else

                    local skinModel = findSkinModel(skinTarget)
                    if not skinModel then
                        for _ = 1, 6 do
                            task.wait(0.5)
                            skinModel = findSkinModel(skinTarget)
                            if skinModel then break end
                        end
                    end
                    if not skinModel then
                        table.insert(missingSkinModels, skinTarget)
                    else
                        if defModel.Address and skinModel.Address and defModel.Address ~= skinModel.Address then
                            if ENABLE_RIG_FIXES then rigSkinModel(skinModel) end

                            local weaponLower = weaponName:lower()
                            if weaponLower:find("crossbow") or skinLower:find("crossbow") then
                                if ENABLE_RIG_FIXES then pcall(fixCrossbowRig, skinModel) end
                            elseif weaponLower:find("bow") or skinLower:find("bow") then
                                if ENABLE_RIG_FIXES then pcall(fixBowRig, skinModel) end
                            elseif weaponLower:find("rpg") or skinLower:find("rpkey") or skinLower:find("rocket") then
                                if ENABLE_RIG_FIXES then pcall(fixRPGRig, skinModel) end
                            elseif weaponLower == "grenade" or skinLower:find("nade") or skinLower:find("bomb") then
                                if ENABLE_RIG_FIXES then pcall(fixGrenadeRig, skinModel) end
                            elseif weaponLower == "gunblade" or skinLower:find("gunblade") or skinLower:find("blade") then
                                if ENABLE_RIG_FIXES then pcall(fixGunbladeRig, skinModel) end
                            elseif weaponLower == "katana" or skinLower:find("katana") then
                                if ENABLE_RIG_FIXES then pcall(fixKatanaRig, skinModel) end
                            end

                            local baseMod = vmMods and vmMods:FindFirstChild("Base" .. (weaponName:gsub(" ", "")))
                            local defMod = baseMod and baseMod:FindFirstChild(srcName)
                            local skinMod = baseMod and baseMod:FindFirstChild(skinTarget)
                            if defMod and not skinMod and not ownedSwap then
                                table.insert(skippedNoScript, weaponName .. "=" .. skinTarget)
                            elseif swapTwoWay(defModel, skinModel, wf) then
                                swappedCount = swappedCount + 1
                                table.insert(skinDataPairs, {srcName, skinTarget})
                                if defMod and skinMod then
                                    scriptMoved = swapTwoWay(defMod, skinMod, baseMod) and true or false
                                elseif ownedSwap then

                                    local fam = baseMod or (vmMods and vmMods:FindFirstChild(weaponName))
                                    local om = fam and fam:FindFirstChild(srcName)
                                    local sm = fam and fam:FindFirstChild(skinTarget)
                                    if om and sm then
                                        scriptMoved = swapTwoWay(om, sm, fam) and true or false
                                    elseif sm and copyName(sm, skinModel) then
                                        scriptMoved = true
                                        table.insert(renamedScripts, {srcName, skinTarget})
                                    elseif om then
                                        copyName(om, defModel)
                                    end
                                elseif not baseMod then

                                    local fam = vmMods and vmMods:FindFirstChild(weaponName)
                                    local sm = fam and fam:FindFirstChild(skinTarget)
                                    if sm and not fam:FindFirstChild(weaponName) and copyName(sm, fam) then
                                        scriptMoved = true
                                        table.insert(renamedScripts, {weaponName, skinTarget})
                                    end
                                end
                            end
                        end
                    end
                end

                -- Thrown, fired and stuck-in-the-wall copies of the item (a
                -- grenade in flight, an arrow, the thrown spear and its rope).
                -- The game picks them by skin name, for every weapon.
                for _, folder in ipairs({tf or false, pf or false, stf or false}) do
                    local ts = folder and folder:FindFirstChild(skinTarget)
                    if ts then
                        local tb = folder:FindFirstChild(srcName)
                        if tb then
                            swapTwoWay(tb, ts, folder)
                        else
                            copyName(ts, ownedSwap and findSkinModel(srcName) or wf:FindFirstChild(weaponName))
                        end
                    end
                end

                if mi then
                    local spec = MISC_SPECIAL_MAP[skinTarget]
                    if spec then
                        for folderName, itemName in pairs(spec) do
                            local folder = mi:FindFirstChild(folderName)
                            if folder then

                                local weaponItem = folder:FindFirstChild(srcName)
                                local skinItem = folder:FindFirstChild(itemName)
                                if skinItem and weaponItem then
                                    swapTwoWay(weaponItem, skinItem, folder)
                                elseif skinItem then
                                    copyName(skinItem, ownedSwap and findSkinModel(srcName) or wf:FindFirstChild(weaponName))
                                end
                            end
                        end
                    end

                    -- Every other effect folder keyed by skin name (muzzle flashes,
                    -- flames, deflects...): the owned item takes the target's entry.
                    -- A variant of the owned entry ("Hyperlaser Guns Red") would
                    -- still win for its hand, so it is renamed out of the way.
                    for _, folder in ipairs(mi:GetChildren()) do
                        if folder.ClassName == "Folder" and not (spec and spec[folder.Name]) then
                            local skinItem = folder:FindFirstChild(skinTarget)
                            if skinItem then
                                local weaponItem = folder:FindFirstChild(srcName)
                                if weaponItem then
                                    swapTwoWay(weaponItem, skinItem, folder)
                                else
                                    copyName(skinItem, ownedSwap and findSkinModel(srcName) or wf:FindFirstChild(weaponName))
                                end
                                local prefix = srcName .. " "
                                for _, v in ipairs(folder:GetChildren()) do
                                    if v.Name:sub(1, #prefix) == prefix and not findSkinModel(v.Name)
                                        and not folder:FindFirstChild(skinTarget .. v.Name:sub(#prefix)) then
                                        copyName(v, folder)
                                    end
                                end
                            end
                        end
                    end

                    local expSkin = MISC_EXPLOSIONS_MAP[skinTarget]

                    local expBase = MISC_EXPLOSIONS_MAP[srcName]
                    if not ownedSwap then expBase = MISC_EXPLOSIONS_BASE[weaponName] end
                    if expSkin and expBase and not scriptMoved then
                        local sx = mi:FindFirstChild(expSkin)
                        local dx = mi:FindFirstChild(expBase)
                        if sx and dx then
                            swapTwoWay(dx, sx, mi)
                        end
                    end
                end
            end
        end
    end

    pcall(applySoundCallbacks)

    if swappedCount == 0 then
        if parsedPairs == 0 then
            return 0, "Found '" .. tostring(targetFile) .. "', but no valid Weapon=Skin lines were detected! Check file format."
        elseif nonDefaultPairs == 0 then
            return 0, "All " .. parsedPairs .. " weapons in '" .. tostring(targetFile) .. "' are set to Default. Please select at least one custom skin on the site."
        elseif #missingBaseWeapons > 0 and #missingSkinModels == 0 then
            return 0, "Base weapons (" .. table.concat(missingBaseWeapons, ", ") .. ") not found in game folder."
        elseif #missingSkinModels > 0 then
            return 0, "Skin models not found in game assets: " .. table.concat(missingSkinModels, ", ")
        else
            return 0, "Memory swap failed. Ensure memory read/write permissions are allowed in executor."
        end
    end

    if #missingBaseWeapons > 0 then
        print("[RivalsSkinChanger] Not swapped - model not found for: " .. table.concat(missingBaseWeapons, ", "))
    end
    if #missingSkinModels > 0 then
        print("[RivalsSkinChanger] Not swapped - skin model not found: " .. table.concat(missingSkinModels, ", "))
    end
    if #skippedConflicts > 0 then
        print("[RivalsSkinChanger] Skipped (skin already used by another line): " .. table.concat(skippedConflicts, ", "))
    end
    if #skippedNoScript > 0 then
        print("[RivalsSkinChanger] Left default (skin has no viewmodel script of its own): " .. table.concat(skippedNoScript, ", "))
    end
    if #renamedScripts > 0 then
        local names = {}
        for _, rn in ipairs(renamedScripts) do names[#names + 1] = rn[2] end
        print("[RivalsSkinChanger] Using the skin's own viewmodel script: " .. table.concat(names, ", "))
    end
    return swappedCount, nil
end

-- Wait for the game
local gameReady = false
do
    local mods = game:GetService("ReplicatedStorage"):WaitForChild("Modules", 30)
    local il = mods and mods:WaitForChild("ItemLibrary", 30)
    local cl = mods and mods:WaitForChild("CosmeticLibrary", 30)
    local job, t0, told = game.JobId, tick(), false
    while tick() - t0 < 60 do
        local okI, itemTable = pcall(moduleTable, il)
        if okI and itemTable then

            for _ = 1, 10 do
                local okC, cosTable = pcall(moduleTable, cl)
                if okC and cosTable then break end
                task.wait(0.5)
            end
            gameReady = true
            break
        end
        if not told and tick() - t0 > 2 then
            told = true
            print("[RivalsSkinChanger] Waiting for the game to finish loading...")
        end
        task.wait(0.5)
        if game.JobId ~= job then
            print("[RivalsSkinChanger] Server changed while waiting - stopped")
            _G.__RIVALS_SKIN_CHANGER_BUSY = nil
            return
        end
    end
    if not gameReady then
        print("[RivalsSkinChanger] The game still isn't reporting its item tables after 60s - going ahead anyway")
    end
end

local count, errorReason = applySkinSwapper()
local elapsed = math.floor((tick() - t_start) * 1000)

if count == 0 then
    local errText = errorReason or "Unknown error while loading skins."
    warn("[RivalsSkinChanger] ==================================================")
    warn("[RivalsSkinChanger] ERROR: 0 SKINS LOADED!")
    warn("[RivalsSkinChanger] Details: " .. errText)
    warn("[RivalsSkinChanger] ==================================================")
    notifyUser("Rivals Skin Changer Error", "0 Skins Loaded: " .. errText, 10)
else
    local msg = "Swapped " .. tostring(count) .. " skins in " .. tostring(elapsed) .. "ms!"
    print("[RivalsSkinChanger] " .. msg)
    notifyUser("Rivals Skin Changer", "Swapped " .. tostring(count) .. " skins - loading animations, offsets and icons...", 6)
end

local function replaceStandardIcon(label)
    if not label or not label.Address then return end
    local ptr = mrd("uintptr_t", label.Address + IMG_OFF)
    if not ptr or ptr < 0x10000000000 or ptr > 0x7FFFFFFFFFFF then return end
    local cur = mrd("string", ptr)
    if not cur then return end
    local weaponName = STANDARD_ICON_MAP[cur]
    if weaponName and ACTIVE_CONFIG_SKINS[weaponName] then
        local skinTarget = ACTIVE_CONFIG_SKINS[weaponName]
        local skinIcon = ITEM_ICONS[weaponName] and (ITEM_ICONS[weaponName][skinTarget] or ITEM_ICONS[weaponName][skinTarget:lower()])
        if skinIcon and skinIcon ~= cur then
            writeImage(label, skinIcon)
        end
    end
end

local runService = game:GetService("RunService")
local renderSteppedConn = nil
local pgDescConn = nil

local function fastSyncGui()
    if not _scriptAlive or not game:IsLoaded() or not LP or not LP.Parent or not LP:IsDescendantOf(game) then return end
    pcall(alignWeaponWings)
    local pg = LP:FindFirstChild("PlayerGui")
    local mg = pg and pg:FindFirstChild("MainGui")
    local mf = mg and mg:FindFirstChild("MainFrame")
    if not mf then return end

    local fi = mf:FindFirstChild("FighterInterfaces")
    local lni = fi and fi:FindFirstChild(LP.Name)
    if lni then
        local sub = lni:FindFirstChild("BottomRight") or lni:FindFirstChild("BottomCenter") or lni:FindFirstChild("BottomLeft")
        local c = sub and sub:FindFirstChild("Container")
        local hb = c and c:FindFirstChild("Hotbar")
        local cont = hb and hb:FindFirstChild("Container")
        if cont then
            for _, slot in ipairs(cont:GetChildren()) do
                if slot.ClassName == "Frame" then
                    if slot.Name == "EquippedDisplay" then
                        local c2 = slot:FindFirstChild("Container")
                        local w2 = c2 and c2:FindFirstChild("Weapon")
                        local iconLabel = w2 and w2:FindFirstChild("Icon")
                        if iconLabel and iconLabel.ClassName == "ImageLabel" and lastEquippedWeapon then
                            local skinTarget = ACTIVE_CONFIG_SKINS[lastEquippedWeapon]
                            if skinTarget then
                                local skinIcon = ITEM_ICONS[lastEquippedWeapon] and (ITEM_ICONS[lastEquippedWeapon][skinTarget] or ITEM_ICONS[lastEquippedWeapon][skinTarget:lower()])
                                if skinIcon then
                                    writeImage(iconLabel, skinIcon)
                                end
                            end
                        end
                    elseif slot.Name ~= "KeybindGamepadEquipLast" and slot.Name ~= "KeybindGamepadEquipNext" and slot.Name ~= "Layout" then
                        local weaponName = slot.Name
                        local skinTarget = ACTIVE_CONFIG_SKINS[weaponName]
                        if skinTarget then
                            local skinIcon = ITEM_ICONS[weaponName] and (ITEM_ICONS[weaponName][skinTarget] or ITEM_ICONS[weaponName][skinTarget:lower()])
                            if skinIcon then
                                local iconLabel = slot:FindFirstChild("Icon")
                                if iconLabel and iconLabel.ClassName == "ImageLabel" then
                                    writeImage(iconLabel, skinIcon)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    local eq = mf:FindFirstChild("Equipment")
    if eq and eq.Visible then
        for _, d in ipairs(eq:GetDescendants()) do
            if d.ClassName == "ImageLabel" or d.ClassName == "ImageButton" then
                replaceStandardIcon(d)
            end
        end
    end

    local pages = mf:FindFirstChild("Pages")
    if pages then
        local pw = pages:FindFirstChild("PickWeapons")
        if pw and pw.Visible then
            local list = pw:FindFirstChild("List") and pw.List:FindFirstChild("Container")
            if list then
                for _, f in ipairs(list:GetChildren()) do
                    local btn = f:FindFirstChild("Button")
                    local pic = btn and btn:FindFirstChild("Icon") and btn.Icon:FindFirstChild("Picture")
                    if pic and pic.ClassName == "ImageLabel" then
                        replaceStandardIcon(pic)
                    end
                end
            end
            local chosen = pw:FindFirstChild("ChosenWeapons")
            if chosen then
                for _, f in ipairs(chosen:GetChildren()) do
                    local btn = f:FindFirstChild("Button")
                    local pic = btn and btn:FindFirstChild("Picture")
                    if pic and pic.ClassName == "ImageLabel" then
                        replaceStandardIcon(pic)
                    end
                end
            end
        end

        local pw2 = pages:FindFirstChild("PickWeaponsList")
        if pw2 and pw2.Visible then
            local lc = pw2:FindFirstChild("ListContainer") and pw2.ListContainer:FindFirstChild("List") and pw2.ListContainer.List:FindFirstChild("Container")
            if lc then
                for _, s in ipairs(lc:GetChildren()) do
                    local btn = s:FindFirstChild("Button")
                    local pic = btn and btn:FindFirstChild("Icon") and btn.Icon:FindFirstChild("Picture")
                    if pic and pic.ClassName == "ImageLabel" then
                        replaceStandardIcon(pic)
                    end
                end
            end
            local ch = pw2:FindFirstChild("ChosenWeapons")
            if ch then
                for _, s in ipairs(ch:GetChildren()) do
                    local btn = s:FindFirstChild("Button")
                    local pic = btn and btn:FindFirstChild("Picture")
                    if pic and pic.ClassName == "ImageLabel" then
                        replaceStandardIcon(pic)
                    end
                end
            end
        end
    end

    local sniperSkin = ACTIVE_CONFIG_SKINS["Sniper"]
    local scopeConf = sniperSkin and SCOPE_RETICLES[sniperSkin]
    if scopeConf then
        local ii = mf:FindFirstChild("ItemInterfaces")
        local si = ii and ii:FindFirstChild(LP.Name .. " - Sniper")
        local sc2 = si and si:FindFirstChild("Mouse") and si.Mouse:FindFirstChild("Scope")
        if sc2 then
            local bi = sc2:FindFirstChild("Blur") and sc2.Blur:FindFirstChild("ImageLabel")
            local ci = sc2:FindFirstChild("Circle") and sc2.Circle:FindFirstChild("ImageLabel")
            if bi then writeImage(bi, scopeConf.blur) end
            if ci then writeImage(ci, scopeConf.circle) end
        end
    end
end

pcall(function()
    if not ENABLE_PERSISTENT_FEATURES then return end
    renderSteppedConn = runService.RenderStepped:Connect(fastSyncGui)
end)

pcall(function()
    local pg = LP:FindFirstChild("PlayerGui")
    if pg then
        if not ENABLE_PERSISTENT_FEATURES then return end
        pgDescConn = pg.DescendantAdded:Connect(function(d)
            if d.ClassName == "ImageLabel" or d.ClassName == "ImageButton" then
                replaceStandardIcon(d)
                if d.Name == "Icon" and d.Parent and d.Parent.ClassName == "Frame" then
                    local wName = d.Parent.Name
                    local skinTarget = ACTIVE_CONFIG_SKINS[wName]
                    if skinTarget then
                        local skinIcon = ITEM_ICONS[wName] and (ITEM_ICONS[wName][skinTarget] or ITEM_ICONS[wName][skinTarget:lower()])
                        if skinIcon then
                            writeImage(d, skinIcon)
                        end
                    end
                end
            end
        end)
    end
end)

-- Wraps
local function readWrapPairs()
    local list, seen = {}, {}

    for _, p in ipairs(configWrapPairs) do
        if not seen[p[1]] then
            seen[p[1]] = true
            list[#list + 1] = p
        end
    end
    for _, p in ipairs({"rivals_wraps.lua", "rivals_wraps.txt", "workspace/rivals_wraps.lua", "workspace/rivals_wraps.txt"}) do
        local okE, exists = pcall(isfile, p)
        if okE and exists then
            local okR, content = pcall(readfile, p)
            if okR and content then
                for line in content:gmatch("[^\r\n]+") do

                    local owned, target = line:match("^%s*([^=%-][^=]-)%s*=%s*(.-)%s*$")
                    if owned and target and target ~= "" and not seen[owned] then
                        seen[owned] = true
                        list[#list + 1] = {owned, target}
                    end
                end
                break
            end
        end
    end
    return list
end

-- Skybox
local SKYBOX_PRESETS = {
    ["blue"] = {"14147881792", "14147882149", "14147882761", "14147883091", "14147882405", "14147881297"},
    ["station"] = {"2108482005", "2108545280", "2108482231", "2108482395", "2108482542", "2108482676"},
    ["graveyard"] = {"135908632589654", "103020541883227", "135908632589654", "135908632589654", "135908632589654", "72960281658487"},
    ["sudden death"] = {"84214501374682", "89972436184102", "84214501374682", "84214501374682", "84214501374682", "92138082970751"},
    ["space"] = {"10196550937", "10196550667", "10196550367", "10196550128", "10196549902", "10196567794"},
    ["westown"] = {"12261809766", "12261813110", "12261809766", "12261809766", "12261809766", "12261813678"},
    ["black"] = {"91612392386438", "91612392386438", "91612392386438", "91612392386438", "91612392386438", "91612392386438"},
    -- Uploaded skybox packs (tools/skies in the site repo), bk, dn, ft, lf, rt, up.
    ["cloudy 01"] = {"126754633897436", "86836627001306", "95905829433933", "122177936450348", "73237790687889", "90043570165995"},
    ["cloudy 02"] = {"94510925134380", "83533436371824", "98229751924468", "106855992262577", "71111483218129", "119866829919660"},
    ["cloudy 03"] = {"134908890676304", "98162794332047", "125777961418491", "109989177196148", "137809355685720", "114251179295721"},
    ["cloudy 04"] = {"107504801883128", "100991020543969", "73636039679787", "110786702878669", "82663836073959", "112042298121106"},
    ["cloudy 05"] = {"79487977466864", "90350734201812", "101510283118396", "102883759888031", "120175709830675", "136284198010930"},
    ["cloudy 06"] = {"133455855232355", "75675276221409", "102683810113255", "134026356692589", "111492255033052", "101979509281748"},
    ["cloudy 07"] = {"124630411829214", "137650278511829", "94482967698658", "103953753436574", "112959082352845", "137140884144826"},
    ["cloudy 08"] = {"90205622288987", "110151968622887", "104626178246233", "91598099503456", "81058694870129", "93729434721830"},
    ["cloudy 09"] = {"139434321199889", "98219516871257", "105913104685597", "125324169983163", "116997570198371", "103330194362875"},
    ["cloudy 10"] = {"81449501205294", "124487320003897", "80904431050447", "86646953803917", "75263551301936", "97788349971545"},
    ["cloudy 11"] = {"120871881275722", "127341735225402", "116601891103440", "94491027998722", "88353388175296", "91160816562958"},
    ["cloudy 12"] = {"113535280016994", "127900371948747", "120725193588788", "111770429925795", "129196586387140", "79378495098669"},
    ["cloudy 13"] = {"108831654470087", "79181118455270", "112187446252336", "104704362496407", "140447704903267", "71772855934062"},
    ["cloudy 14"] = {"105093562532797", "85003418570488", "131779651921685", "70609184831645", "86282293662867", "134608849387985"},
    ["cloudy 15"] = {"131536188889612", "118093331916732", "107336475861306", "110056465107774", "105163681975273", "92081035276480"},
    ["cloudy 16"] = {"109782717368475", "76246782640274", "121489338023768", "105948832901369", "115101533846700", "114420609506473"},
    ["cloudy 17"] = {"88662414547866", "110554210020228", "88313273447587", "134665095359798", "90541216303413", "121014099637227"},
    ["cloudy 18"] = {"106360292691579", "103249577541997", "110484795494314", "129304457043156", "114083127638311", "78124003378079"},
    ["cloudy 19"] = {"115116233569094", "133685857606690", "95607439806027", "93689502105544", "128807133605420", "111228278131898"},
    ["cloudy 20"] = {"124208488902038", "91200268945217", "111384709364077", "140170044783927", "118024637233382", "111697448595697"},
    ["cloudy 21"] = {"104201550309251", "117677338325723", "78563702293497", "120997393510904", "103388622930665", "89839615332589"},
    ["cloudy 22"] = {"74892504537101", "88612926659487", "79034090244073", "71664566729417", "134540865217875", "127631258082669"},
    ["cloudy 23"] = {"119599708543402", "83824957038386", "122253064867736", "82619654415458", "100939349583458", "74891504302768"},
    ["cloudy 24"] = {"121378533477721", "117082750895246", "115547003946313", "121390352061507", "79982218533687", "72692515998179"},
    ["cloudy 25"] = {"83309474203162", "124498349051494", "134496968945569", "107851671443849", "85866561501104", "78405144176503"},
    ["galaxy"] = {"84129238345796", "103265672483730", "111177857256367", "136671627884048", "112973201740035", "79105441573587"},
    ["blue nebula"] = {"86686245579171", "108113096612020", "81877733877143", "119128617757798", "128328409316361", "102542960042748"},
    ["gold nebula"] = {"84095138366077", "77738459731844", "119092184893445", "137679633917616", "122487493876092", "103170638607510"},

    ["classic"] = {"rbxasset://sky/sky512_bk.tex", "rbxasset://sky/sky512_dn.tex", "rbxasset://sky/sky512_ft.tex",
                   "rbxasset://sky/sky512_lf.tex", "rbxasset://sky/sky512_rt.tex", "rbxasset://sky/sky512_up.tex"}
}
local SKYBOX_FACES = {{"bk", 0xe8}, {"dn", 0x118}, {"ft", 0x148}, {"lf", 0x178}, {"rt", 0x1a8}, {"up", 0x1d8}}

local function skyboxAssetId(v)
    v = tostring(v):match("^%s*(.-)%s*$")
    if v:find("://") then return v end
    local digits = v:match("^(%d+)$")
    return digits and ("rbxassetid://" .. digits) or nil
end

local function writeRobloxString(base, str)
    local ptr, cap = rd(base), mrd("uint64_t", base + 24)
    if not ptr or not cap or ptr < 0x10000 or #str > cap then return false end
    for i = 1, #str do mwr("uint8_t", ptr + i - 1, string.byte(str, i)) end
    mwr("uint8_t", ptr + #str, 0)
    mwr("uint64_t", base + 16, #str)
    return true
end

local function applySkybox(conf)
    local ids = {}
    local preset = conf.preset or conf.skybox or conf.name
    -- "gray" is Roblox's DebugSkyGray render flag, not a set of images: it
    -- greys the sky at once, on every map. Any other choice turns it off.
    local gray = preset and tostring(preset):lower() == "gray"
    if type(setfflag) == "function" then pcall(setfflag, "DebugSkyGray", gray and 1 or 0) end
    if gray then return 0, "gray sky on - shows straight away" end
    if preset then
        local p = SKYBOX_PRESETS[tostring(preset):lower()]
        if not p then return 0, "unknown skybox preset '" .. tostring(preset) .. "'" end
        for i, v in ipairs(p) do ids[i] = skyboxAssetId(v) end
    end
    local all = conf.all and skyboxAssetId(conf.all)
    if all then for i = 1, 6 do ids[i] = all end end
    for i, f in ipairs(SKYBOX_FACES) do
        local one = conf[f[1]] and skyboxAssetId(conf[f[1]])
        if one then ids[i] = one end
    end

    local given = 0
    for i = 1, 6 do if ids[i] then given = given + 1 end end
    if given == 0 then return 0, nil end

    local skies, seen = {}, {}
    local function add(inst)
        if inst and inst.ClassName == "Sky" and inst.Address and not seen[inst.Address] then
            seen[inst.Address] = true
            skies[#skies + 1] = inst
        end
    end
    local roots = {}
    local playerScripts = LP:FindFirstChild("PlayerScripts")
    local starterScripts = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")

    if playerScripts then roots[#roots + 1] = playerScripts end
    if starterScripts then roots[#roots + 1] = starterScripts end
    for _, root in ipairs(roots) do
        for _, sub in ipairs({"Assets", "Modules"}) do
            local folder = root:FindFirstChild(sub)
            local profiles = folder and folder:FindFirstChild("LightingProfiles")
            for _, prof in ipairs(profiles and profiles:GetChildren() or {}) do
                for _, c in ipairs(prof:GetChildren()) do add(c) end
            end
        end
    end

    if not playerScripts then
        for _, d in ipairs(LP:GetDescendants()) do
            local profiles = d.Parent and d.Parent.Parent
            if profiles and profiles.Name == "LightingProfiles" then add(d) end
        end
    end
    for _, c in ipairs(game:GetService("Lighting"):GetChildren()) do add(c) end

    local patched, skipped = 0, 0
    for _, d in ipairs(skies) do
        local ok = 0
        for i, f in ipairs(SKYBOX_FACES) do
            if ids[i] and writeRobloxString(d.Address + f[2], ids[i]) then ok = ok + 1 end
        end
        if ok == given then patched = patched + 1 else skipped = skipped + 1 end
    end
    if patched == 0 then return 0, "no sky templates found" end
    return patched, (skipped > 0) and (skipped .. " sky templates were left alone (id too long for the game's buffer)") or nil
end

-- Hit, headshot and kill sounds
-- ClientViewModel.PlayHitmarkerSound hands plain string constants to
-- CreateSound: "...13110130082" on a body hit, "...16537449730" layered with
-- "...16537337310" on a headshot. Kill sounds come from
-- SoundLibrary.EliminationSounds. Luau interns strings, so each id is a
-- single object, and SoundLibrary lists all of them (AlwaysPreload,
-- EliminationSounds) - that is how they are found. Rewriting an object's
-- text changes what the next CreateSound plays. Each sits in a 56-byte
-- block: text at +24, length at +20, room for 31 characters.
local SOUND_TARGETS = {
    ["rbxassetid://13110130082"] = "hit",
    ["rbxassetid://16537449730"] = "critical",
    ["rbxassetid://16537337310"] = "criticallayer",
    ["rbxassetid://16530229616"] = "kill",
    ["rbxassetid://16530229541"] = "kill",
    ["rbxassetid://16530229695"] = "kill",
}
local SOUND_TEXT_MAX, SOUND_LEN, TAG_STRING = 31, 20, 6

-- nil = keep the game's sound, "" = silence, false = not usable.
local function soundText(v)
    v = tostring(v):match("^%s*(.-)%s*$")
    local low = v:lower()
    if low == "" or low == "default" then return nil end
    if low == "none" or low == "mute" or low == "off" then return "" end
    local id = skyboxAssetId(v)
    if id and #id <= SOUND_TEXT_MAX then return id end
    return false
end

local function writeLuaString(ts, text)
    if #text > SOUND_TEXT_MAX then return false end
    for i = 1, #text do mwr("byte", ts + STRING_DATA + i - 1, string.byte(text, i)) end
    mwr("byte", ts + STRING_DATA + #text, 0)
    mwr("int", ts + SOUND_LEN, #text)
    return true
end

local function collectSoundStrings(out, tbl, depth)
    local size, arr = rint(tbl + 8), rd(tbl + ROUTE.array)
    if not size or not arr or size < 1 or size > 256 or arr < 0x10000 then return end
    for i = 0, size - 1 do
        local v = arr + i * 16
        local tag, p = rint(v + 12), rd(v)
        if tag == TAG_STRING and p and p > 0x10000 then
            local ok, s = pcall(mrd, "string", p + STRING_DATA)
            if ok and SOUND_TARGETS[s] then out[s] = p end
        elseif tag == TAG_TABLE and depth > 0 and p and p > 0x10000 then
            collectSoundStrings(out, p, depth - 1)
        end
    end
end

local function applySounds(conf)
    -- Put back the text the last run wrote, where it is still ours.
    local prev = _G.__RIVALS_SOUND_STATE
    _G.__RIVALS_SOUND_STATE = nil
    for _, r in ipairs(type(prev) == "table" and prev.restores or {}) do
        local ok, now = pcall(mrd, "string", r[1] + STRING_DATA)
        if ok and now == r[3] then writeLuaString(r[1], r[2]) end
    end

    local want, bad = {}, {}
    for key, value in pairs(conf) do
        if key == "hit" or key == "critical" or key == "kill" then
            local text = soundText(value)
            if text == false then
                bad[#bad + 1] = key .. "=" .. tostring(value)
            elseif text then
                want[key] = text
            end
        end
    end
    -- A custom headshot replaces the layered pair, so its second layer goes quiet.
    if want.critical then want.criticallayer = "" end
    if not next(want) then return 0, (#bad > 0) and ("not an audio id: " .. table.concat(bad, ", ")) or nil end

    local modules = game:GetService("ReplicatedStorage"):FindFirstChild("Modules")
    local f = nodesOf(moduleTable(modules and modules:FindFirstChild("SoundLibrary")), 64,
        {AlwaysPreload = true, EliminationSounds = true})
    local found = {}
    for _, node in pairs(f or {}) do
        local t = rd(node)
        if t and t > 0x10000 then collectSoundStrings(found, t, 1) end
    end

    local restores, changed = {}, 0
    for original, ts in pairs(found) do
        local text = want[SOUND_TARGETS[original]]
        if text and writeLuaString(ts, text) then
            restores[#restores + 1] = {ts, original, text}
            changed = changed + 1
        end
    end
    _G.__RIVALS_SOUND_STATE = {restores = restores}
    if changed == 0 then
        return 0, "sounds not found - rejoin if an earlier run already changed them"
    end
    return changed, (#bad > 0) and ("not an audio id: " .. table.concat(bad, ", ")) or nil
end

-- Lighting
local LIGHTING_FIELDS = {
    brightness = {off = 0x108, key = "Brightness"},
    exposure = {off = 0x114, key = "ExposureCompensation"},
    diffuse = {off = 0x10c, key = "EnvironmentDiffuseScale"},
    specular = {off = 0x110, key = "EnvironmentSpecularScale"},
    shadowsoftness = {off = nil, key = "ShadowSoftness"},
    ambient = {off = 0xc0, key = "Ambient", color = true},
    outdoor = {off = 0xf0, key = "OutdoorAmbient", color = true},
    fogcolor = {off = 0xe4, key = "FogColor", color = true}
}
local LIGHTING_PRESETS = {
    ["dark"] = {brightness = 0.35, exposure = -1.3, diffuse = 0.15, specular = 0.2, ambient = 0.02, outdoor = 0.03, fogcolor = 0.02},
    -- The game's own skies, tuned by hand to each sky's colours.
    ["blue"] = {brightness = 2.2, exposure = 0.1, diffuse = 1, specular = 1, ambient = "#4a4f58", outdoor = "#8a93a3", fogcolor = "#bfd2e8"},
    ["classic"] = {brightness = 2, exposure = 0, diffuse = 1, specular = 1, ambient = "#4c5058", outdoor = "#8c96a8", fogcolor = "#c0d0e8"},
    ["space"] = {brightness = 0.6, exposure = -0.5, diffuse = 1, specular = 1, ambient = "#1c1630", outdoor = "#3a2f5c", fogcolor = "#0c0918"},
    ["graveyard"] = {brightness = 0.8, exposure = -0.4, diffuse = 1, specular = 1, ambient = "#26302a", outdoor = "#46584c", fogcolor = "#3b4a40"},
    ["sudden death"] = {brightness = 1.2, exposure = -0.2, diffuse = 1, specular = 1, ambient = "#3a1c1c", outdoor = "#6e3434", fogcolor = "#7a2e2a"},
    ["station"] = {brightness = 1.8, exposure = 0, diffuse = 1, specular = 1, ambient = "#4a3a36", outdoor = "#8a6e66", fogcolor = "#d19a86"},
    ["westown"] = {brightness = 2.4, exposure = 0.15, diffuse = 1, specular = 1, ambient = "#554536", outdoor = "#9c8466", fogcolor = "#e0c29a"},
    ["black"] = {brightness = 0.35, exposure = -1.3, diffuse = 0.15, specular = 0.2, ambient = 0.02, outdoor = 0.03, fogcolor = 0.02},
    ["gray"] = {brightness = 1.6, exposure = -0.05, diffuse = 1, specular = 1, ambient = "#4a4a4a", outdoor = "#808080", fogcolor = "#9a9a9a"},
    -- One per uploaded sky, from its colours (tools/skies/lighting_from_skies.py).
    -- "Preset=match" picks the one named like the current skybox.
    ["cloudy 01"] = {brightness = 1.85, exposure = 0.05, diffuse = 1, specular = 1, ambient = "#443b39", outdoor = "#767278", fogcolor = "#aa8782"},
    ["cloudy 02"] = {brightness = 2.73, exposure = 0.3, diffuse = 1, specular = 1, ambient = "#565149", outdoor = "#908c83", fogcolor = "#c9b89b"},
    ["cloudy 03"] = {brightness = 2.28, exposure = 0.27, diffuse = 1, specular = 1, ambient = "#4f4745", outdoor = "#908680", fogcolor = "#ac938b"},
    ["cloudy 04"] = {brightness = 2.52, exposure = 0.3, diffuse = 1, specular = 1, ambient = "#4b5153", outdoor = "#7f8ea4", fogcolor = "#d7f0fd"},
    ["cloudy 05"] = {brightness = 2.41, exposure = 0.3, diffuse = 1, specular = 1, ambient = "#484e51", outdoor = "#7d8ea7", fogcolor = "#cde8fa"},
    ["cloudy 06"] = {brightness = 1.95, exposure = 0.1, diffuse = 1, specular = 1, ambient = "#3b4045", outdoor = "#67799d", fogcolor = "#c7e4fb"},
    ["cloudy 07"] = {brightness = 2.12, exposure = 0.19, diffuse = 1, specular = 1, ambient = "#48434a", outdoor = "#847d91", fogcolor = "#cdb8d5"},
    ["cloudy 08"] = {brightness = 2.29, exposure = 0.27, diffuse = 1, specular = 1, ambient = "#494948", outdoor = "#838992", fogcolor = "#c7c8c3"},
    ["cloudy 09"] = {brightness = 2.01, exposure = 0.13, diffuse = 1, specular = 1, ambient = "#48412c", outdoor = "#7d7b76", fogcolor = "#b0994b"},
    ["cloudy 10"] = {brightness = 1.8, exposure = 0.03, diffuse = 1, specular = 1, ambient = "#3a3c3b", outdoor = "#6c7273", fogcolor = "#6c736f"},
    ["cloudy 11"] = {brightness = 1.21, exposure = -0.27, diffuse = 1, specular = 1, ambient = "#2e2842", outdoor = "#595073", fogcolor = "#5b4a97"},
    ["cloudy 12"] = {brightness = 1.05, exposure = -0.35, diffuse = 1, specular = 1, ambient = "#28262a", outdoor = "#4e4b5f", fogcolor = "#655b6c"},
    ["cloudy 13"] = {brightness = 1.83, exposure = 0.04, diffuse = 1, specular = 1, ambient = "#423b36", outdoor = "#7d7067", fogcolor = "#c2a692"},
    ["cloudy 14"] = {brightness = 2.01, exposure = 0.13, diffuse = 1, specular = 1, ambient = "#374539", outdoor = "#678271", fogcolor = "#8ccd96"},
    ["cloudy 15"] = {brightness = 0.91, exposure = -0.42, diffuse = 1, specular = 1, ambient = "#232229", outdoor = "#4c4544", fogcolor = "#3b374b"},
    ["cloudy 16"] = {brightness = 2.02, exposure = 0.14, diffuse = 1, specular = 1, ambient = "#41414d", outdoor = "#787a94", fogcolor = "#a9aadc"},
    ["cloudy 17"] = {brightness = 1.54, exposure = -0.1, diffuse = 1, specular = 1, ambient = "#433031", outdoor = "#72606c", fogcolor = "#ab696a"},
    ["cloudy 18"] = {brightness = 1.54, exposure = -0.1, diffuse = 1, specular = 1, ambient = "#353435", outdoor = "#60656f", fogcolor = "#928f93"},
    ["cloudy 19"] = {brightness = 1.55, exposure = -0.1, diffuse = 1, specular = 1, ambient = "#4a2f2d", outdoor = "#8b5b56", fogcolor = "#ac5753"},
    ["cloudy 20"] = {brightness = 2.44, exposure = 0.3, diffuse = 1, specular = 1, ambient = "#4c4d55", outdoor = "#8b8c97", fogcolor = "#9597af"},
    ["cloudy 21"] = {brightness = 1.65, exposure = -0.05, diffuse = 1, specular = 1, ambient = "#4f3221", outdoor = "#856540", fogcolor = "#ab5928"},
    ["cloudy 22"] = {brightness = 1.23, exposure = -0.26, diffuse = 1, specular = 1, ambient = "#41271e", outdoor = "#744f3f", fogcolor = "#b05335"},
    ["cloudy 23"] = {brightness = 2.0, exposure = 0.13, diffuse = 1, specular = 1, ambient = "#493f41", outdoor = "#8f747d", fogcolor = "#c39aa4"},
    ["cloudy 24"] = {brightness = 2.3, exposure = 0.28, diffuse = 1, specular = 1, ambient = "#4c4947", outdoor = "#918787", fogcolor = "#9e938e"},
    ["cloudy 25"] = {brightness = 1.74, exposure = -0.0, diffuse = 1, specular = 1, ambient = "#3b393f", outdoor = "#706c7b", fogcolor = "#9791a6"},
    ["galaxy"] = {brightness = 0.5, exposure = -0.62, diffuse = 1, specular = 1, ambient = "#1b0f5b", outdoor = "#432493", fogcolor = "#07031f"},
    ["blue nebula"] = {brightness = 0.52, exposure = -0.61, diffuse = 1, specular = 1, ambient = "#101923", outdoor = "#23364b", fogcolor = "#060c12"},
    ["gold nebula"] = {brightness = 0.63, exposure = -0.56, diffuse = 1, specular = 1, ambient = "#211a13", outdoor = "#463728", fogcolor = "#130d07"},
}
local COLOR3_FLOATS = 16

local function lightingColor(v)
    local hex = tostring(v):match("^#?(%x%x%x%x%x%x)$")
    if hex then
        return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
    end
    local n = tonumber(v)
    if n then return n, n, n end
end

local function applyLighting(conf, cache)
    local values = {}
    local name = conf.preset and tostring(conf.preset):lower()
    if name == "match" then
        local sky = configSkybox.preset or configSkybox.skybox or configSkybox.name
        name = sky and tostring(sky):lower()
        if not (name and LIGHTING_PRESETS[name]) then return 0, "no lighting preset matches this skybox - left as it is" end
    end
    local preset = name and LIGHTING_PRESETS[name]
    if conf.preset and not preset then return 0, "unknown lighting preset '" .. tostring(conf.preset) .. "'" end
    for k, v in pairs(preset or {}) do values[k] = v end
    for k in pairs(LIGHTING_FIELDS) do
        if conf[k] then values[k] = conf[k] end
    end
    if not next(values) then return 0, nil end

    local L = game:GetService("Lighting")
    local applied = 0
    for name, raw in pairs(values) do
        local field = LIGHTING_FIELDS[name]
        if field and field.off then
            if field.color then
                local r, g, b = lightingColor(raw)
                if r then
                    mwr("float", L.Address + field.off, r)
                    mwr("float", L.Address + field.off + 4, g)
                    mwr("float", L.Address + field.off + 8, b)
                    applied = applied + 1
                end
            else
                local n = tonumber(raw)
                if n then
                    mwr("float", L.Address + field.off, n)
                    applied = applied + 1
                end
            end
        end
    end

    local nodes = {}
    for _, addr in ipairs(cache.lightNodes or {}) do
        if nodeKey(addr) == "ExposureCompensation" and nodeKey(addr + NODE_SIZE) == "Brightness" then
            nodes[#nodes + 1] = addr
        end
    end

    if #nodes == 0 then
        local lpFolders = {}
        local ps = LP:FindFirstChild("PlayerScripts")
        local folder = ps and ps:FindFirstChild("Modules") and ps.Modules:FindFirstChild("LightingProfiles")
        if folder then
            lpFolders[1] = folder
        else
            for _, d in ipairs(LP:GetDescendants()) do
                if d.Name == "LightingProfiles" and d.Parent and d.Parent.Name == "Modules" then lpFolders[1] = d break end
            end
        end
        for _, prof in ipairs(lpFolders[1] and lpFolders[1]:GetChildren() or {}) do
            if prof.ClassName == "ModuleScript" then
                local okT, t = pcall(moduleTable, prof)
                local f = okT and t and nodesOf(t, 64, {LightingProperties = true})
                local props = f and f.LightingProperties and rd(f.LightingProperties)
                local pf = props and nodesOf(props, 64, {ExposureCompensation = true, Brightness = true})
                if pf and pf.ExposureCompensation and pf.Brightness then nodes[#nodes + 1] = pf.ExposureCompensation end
            end
        end
        if #nodes > 0 then cache.lightNodes = nodes end
    end
    if #nodes == 0 then
        local okG, rows = pcall(getgc, {"ExposureCompensation"})
        for _, r in ipairs(okG and type(rows) == "table" and rows or {}) do
            if r.addr and nodeKey(r.addr) == "ExposureCompensation" and nodeKey(r.addr + NODE_SIZE) == "Brightness" then
                nodes[#nodes + 1] = r.addr
            end
        end
        cache.lightNodes = nodes
    end

    local profiles = 0
    for _, exposureNode in ipairs(nodes) do

        local wrote = false
        for i = -12, 12 do
            local node = exposureNode + i * NODE_SIZE
            local key = nodeKey(node)
            if key then
                for name, field in pairs(LIGHTING_FIELDS) do
                    if field.key == key and values[name] then
                        if field.color then
                            local ud = rd(node)
                            local r, g, b = lightingColor(values[name])
                            if ud and ud > 0x10000 and r then
                                mwr("float", ud + COLOR3_FLOATS, r)
                                mwr("float", ud + COLOR3_FLOATS + 4, g)
                                mwr("float", ud + COLOR3_FLOATS + 8, b)
                                wrote = true
                            end
                        else
                            local n = tonumber(values[name])
                            if n then
                                mwr("double", node, n)
                                wrote = true
                            end
                        end
                    end
                end
            end
        end
        if wrote then profiles = profiles + 1 end
    end
    return applied, (profiles > 0) and ("kept across map changes on " .. profiles .. " lighting profiles")
        or "applied to the current area only (lighting profiles not found)"
end

local wrapPairs = readWrapPairs()
if ENABLE_SKIN_DATA_SYNC and (#skinDataPairs > 0 or #wrapPairs > 0) then
    print("[RivalsSkinChanger] Applying skin animations, offsets, icons" .. (#wrapPairs > 0 and " + wraps" or "") .. "...")
    local tSync = tick()
    local okS, synced, note, wrapsApplied, wrapsMissed, skinsMissed = pcall(syncSkinData, skinDataPairs, wrapPairs, dictCache)
    local firstRoute = dictCache.route

    dictCache.knownMissing = dictCache.knownMissing or {}
    local function unexplained()
        local n = 0
        for _, name in ipairs(okS and skinsMissed or {}) do if not dictCache.knownMissing[name] then n = n + 1 end end
        for _, name in ipairs(okS and wrapsMissed or {}) do if not dictCache.knownMissing[name] then n = n + 1 end end
        return n
    end
    local function retry(label, forceScan)
        print("[RivalsSkinChanger] " .. tostring((synced or 0)) .. "/" .. #skinDataPairs .. " skins, "
            .. tostring(wrapsApplied or 0) .. "/" .. #wrapPairs .. " wraps - retrying with " .. label .. "...")
        dictCache.vm, dictCache.cos, dictCache.vmBase, dictCache.cosBase = nil, nil, nil, nil
        dictCache.forceScan = forceScan
        local ok2, s2, n2, w2, wm2, sm2 = pcall(syncSkinData, skinDataPairs, wrapPairs, dictCache)
        dictCache.forceScan = nil

        if ok2 and ((s2 or 0) + (w2 or 0)) >= ((synced or 0) + (wrapsApplied or 0)) then
            okS, synced, note, wrapsApplied, wrapsMissed, skinsMissed = ok2, s2, n2, w2, wm2, sm2
        end
    end
    if okS and unexplained() > 0 then retry("a fresh lookup", false) end
    if okS and unexplained() > 0 then
        notifyUser("Rivals Skin Changer", "Some skins didn't load - double-checking with a full memory scan (~30s)...", 6)
        retry("a full memory scan (~30s)", true)
        if gameReady then
            for _, name in ipairs(skinsMissed or {}) do dictCache.knownMissing[name] = true end
            for _, name in ipairs(wrapsMissed or {}) do dictCache.knownMissing[name] = true end
        end
        local gone = {}
        if skinsMissed and #skinsMissed > 0 then gone[#gone + 1] = "skins: " .. table.concat(skinsMissed, ", ") end
        if wrapsMissed and #wrapsMissed > 0 then gone[#gone + 1] = "wraps: " .. table.concat(wrapsMissed, ", ") end
        if #gone > 0 then
            print("[RivalsSkinChanger] Not in the game's item list (check the names in your config) - " .. table.concat(gone, " | "))
        end
    end
    if okS then
        local parts = {}
        if #skinDataPairs > 0 then parts[#parts + 1] = "Animations, offsets + icons applied: " .. tostring(synced) .. "/" .. #skinDataPairs end
        if #wrapPairs > 0 then parts[#parts + 1] = "Wraps applied: " .. tostring(wrapsApplied or 0) .. "/" .. #wrapPairs end
        local msg = table.concat(parts, " | ")
        local wrapNote = (wrapsMissed and #wrapsMissed > 0) and (" (wraps not found: " .. table.concat(wrapsMissed, ", ") .. ")") or ""
        print("[RivalsSkinChanger] " .. msg .. (note and (" (" .. note .. ")") or "") .. wrapNote .. string.format(" in %.1fs", tick() - tSync)
            .. (firstRoute == "scan" and " (registry route failed - used the slow memory scan)" or ""))
        notifyUser("Rivals Skin Changer", msg, 6)
    else
        print("[RivalsSkinChanger] Skin animation sync error: " .. tostring(synced))
        notifyUser("Rivals Skin Changer", "Animation sync failed - skins are still swapped", 6)
    end
end
do
    local okSky, patched, skyNote = pcall(applySkybox, configSkybox)
    if okSky and (patched or 0) > 0 then
        local msg = "Skybox set on " .. tostring(patched) .. " map profiles - it shows on the next map or area load"
        print("[RivalsSkinChanger] " .. msg .. (skyNote and (" (" .. skyNote .. ")") or ""))
        notifyUser("Rivals Skin Changer", msg, 6)
    elseif okSky and skyNote then
        print("[RivalsSkinChanger] Skybox: " .. tostring(skyNote))
    elseif not okSky then
        print("[RivalsSkinChanger] Skybox error: " .. tostring(patched))
    end
end

do
    local okS, changed, soundNote = pcall(applySounds, configSounds)
    if okS and (changed or 0) > 0 then
        print("[RivalsSkinChanger] Sounds: " .. tostring(changed) .. " replaced - heard from the next hit"
            .. (soundNote and (" (" .. soundNote .. ")") or ""))
    elseif okS and soundNote then
        print("[RivalsSkinChanger] Sounds: " .. tostring(soundNote))
    elseif not okS then
        print("[RivalsSkinChanger] Sounds error: " .. tostring(changed))
    end
end

do
    local okL, applied, lightNote = pcall(applyLighting, configLighting, dictCache)
    if okL and (applied or 0) > 0 then
        print("[RivalsSkinChanger] Lighting: " .. tostring(applied) .. " settings" .. (lightNote and (" - " .. lightNote) or ""))
    elseif okL and lightNote then
        print("[RivalsSkinChanger] Lighting: " .. tostring(lightNote))
    elseif not okL then
        print("[RivalsSkinChanger] Lighting error: " .. tostring(applied))
    end
end

-- Finishers and charms
-- Season rank charms
local floatRestores = {}
local function showOnlyVariant(model, keepName)
    local extra = model:FindFirstChild("Extra")
    local keep = extra and extra:FindFirstChild(keepName)
    if not keep then return false end
    for _, v in ipairs(extra:GetChildren()) do
        if v.Address ~= keep.Address then
            local parts = v:GetDescendants()
            parts[#parts + 1] = v
            for _, d in ipairs(parts) do
                local c = d.ClassName
                if c == "Part" or c == "MeshPart" or c == "UnionOperation" then
                    local addr = d.Address + OFF.Transparency
                    local okR, old = pcall(mrd, "float", addr)
                    if okR and old then
                        floatRestores[#floatRestores + 1] = {addr, old}
                        pcall(mwr, "float", addr, 1)
                    end
                end
            end
        end
    end
    return true
end

local function applyCosmetics()
    if #configFinishers == 0 and #configCharms == 0 then return nil end
    local modules = game:GetService("ReplicatedStorage"):FindFirstChild("Modules")
    local finishers = modules and modules:FindFirstChild("Finishers")
    local charmModels = A and A:FindFirstChild("Charms")
    local psModules = psRoot and psRoot:FindFirstChild("Modules")
    local charmScripts = psModules and psModules:FindFirstChild("Charms")
    local used, done, missed = {}, {}, {}
    local function claim(kind, a, b)
        if used[kind .. a] or used[kind .. b] then return false end
        used[kind .. a], used[kind .. b] = true, true
        return true
    end
    for _, p in ipairs(configFinishers) do
        local owned, target = p[1], p[2]
        local a, b
        for _ = 1, 20 do
            a = finishers and finishers:FindFirstChild(owned)
            b = finishers and finishers:FindFirstChild(target)
            if a and b then break end
            task.wait(0.5)
        end
        if not a or not b then
            missed[#missed + 1] = owned .. "=" .. target .. " (" .. (not a and owned or target) .. " isn't a finisher)"
        elseif not claim("f:", owned, target) then
            missed[#missed + 1] = owned .. "=" .. target .. " (already used by another line)"
        elseif swapTwoWay(a, b, finishers) then
            done[#done + 1] = owned .. " -> " .. target
        else
            missed[#missed + 1] = owned .. "=" .. target .. " (swap failed)"
        end
    end
    for _, p in ipairs(configCharms) do
        local owned, target = p[1], p[2]
        -- Charm models (the unreleased seasons especially) can still be
        -- streaming in when autoexec starts the script: look again for up to 10s.
        local a, b, variant
        for _ = 1, 20 do
            a = charmModels and charmModels:FindFirstChild(owned)
            b, variant = charmModels and charmModels:FindFirstChild(target), nil
            if not b and charmModels then
                local base, rank = target:match("^(Season %d+)%s+(.+)$")
                local m = base and charmModels:FindFirstChild(base)
                local extra = m and m:FindFirstChild("Extra")
                if extra and extra:FindFirstChild(rank) then b, variant = m, rank end
            end
            if a and b then break end
            task.wait(0.5)
        end
        if not a or not b then
            missed[#missed + 1] = owned .. "=" .. target .. " (" .. (not a and owned or target) .. " isn't a charm)"
        elseif not claim("c:", owned, variant and b.Name or target) then
            missed[#missed + 1] = owned .. "=" .. target .. " (already used by another line)"
        elseif swapTwoWay(a, b, charmModels) then
            if variant then showOnlyVariant(b, variant) end
            local oa = charmScripts and charmScripts:FindFirstChild(owned)
            local ob = charmScripts and charmScripts:FindFirstChild(target)
            if oa and ob then
                swapTwoWay(oa, ob, charmScripts)
            elseif ob then
                copyName(ob, b)
            elseif oa then
                copyName(oa, a)
            end
            done[#done + 1] = owned .. " -> " .. target
        else
            missed[#missed + 1] = owned .. "=" .. target .. " (swap failed)"
        end
    end
    return done, missed
end

do
    local okC, done, missed = pcall(applyCosmetics)
    if not okC then
        print("[RivalsSkinChanger] Finishers/charms error: " .. tostring(done))
    elseif done then
        if #done > 0 then
            local msg = "Finishers/charms: " .. table.concat(done, ", ")
            print("[RivalsSkinChanger] " .. msg .. " - finishers show from their next use, charms on the next equip")
            notifyUser("Rivals Skin Changer", msg, 6)
        end
        if #missed > 0 then
            print("[RivalsSkinChanger] Finishers/charms not applied: " .. table.concat(missed, "; "))
        end
    end
end

-- Save state
_G.__RIVALS_SKIN_CHANGER_STATE = {restores = memoryRestores, wfAddr = wf.Address, nameCopies = nameCopies, dicts = dictCache, floats = floatRestores}
_G.__RIVALS_SKIN_CHANGER_BUSY = nil
