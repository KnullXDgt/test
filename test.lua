-- ====================================================================
--                 INSTANT FISHING V2 - CLEAN
--          Fishing + AutoSell + Auto Small Notification
-- ====================================================================

-- ====== SERVICES ======
local Service = {
    Players = game:GetService("Players"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    HttpService = game:GetService("HttpService"),
    RunService = game:GetService("RunService"),
    Lighting = game:GetService("Lighting"),
    Stats = game:GetService("Stats"),
}
Service.LocalPlayer = Service.Players.LocalPlayer

-- ====== HEURISTIC DISCOVERY ======
local Remote = {
    Net = Service.ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net,
}

Remote.Resolve = function(targetName)
    local allRemotes = Remote.Net:GetChildren()
    for i, remote in ipairs(allRemotes) do
        if remote.Name == targetName then
            return allRemotes[i + 1]
        end
    end
    return nil
end

-- ====== REMOTES ======
for key, remoteName in pairs({
    charge = "RF/ChargeFishingRod",
    minigame = "RF/RequestFishingMinigameStarted",
    fishing = "RE/CatchFishCompleted",
    cancel = "RF/CancelFishingInputs",
    sell = "RF/SellAllItems",
    updateAutoFishing = "RF/UpdateAutoFishingState",
    markAutoFishing = "RF/MarkAutoFishingUsed",
    fishCaught = "RE/FishCaught",
    equipTool = "RE/EquipToolFromHotbar",
    fishingRadar = "RF/UpdateFishingRadar",
    equipOxygen = "RF/EquipOxygenTank",
    unequipOxygen = "RF/UnequipOxygenTank",
    weatherPurchase = "RF/PurchaseWeatherEvent",
    purchaseBait = "RF/PurchaseBait",
    equipBait = "RE/EquipBait",
    purchaseRod = "RF/PurchaseFishingRod",
    equipItem = "RE/EquipItem",
    purchaseBM = "RF/PurchaseBlackMarketItem",
    bpPurchase = "RE/BPPurchaseRequest",
    purchaseMerchant = "RF/PurchaseMarketItem",
    spawnTotem = "RE/SpawnTotem",
    totemCreated = "RE/TotemCreated",
    totemSpawned = "RE/TotemSpawned",
}) do
    Remote[key] = Remote.Resolve(remoteName)
end
Remote.cutscene = Remote.Net:WaitForChild("RE/ReplicateCutscene", 10)
Remote.abilityVFX = Remote.Net:WaitForChild("RE/PlayAbilityVFX", 10)
Remote.baitCast = Remote.Net:FindFirstChild("RE/BaitCastVisual")
Remote.enchantAltar1 = Remote.Resolve("RE/ActivateEnchantingAltar")
Remote.enchantAltar2 = Remote.Resolve("RE/ActivateSecondEnchantingAltar")
Remote.enchantRoll = Remote.Resolve("RE/RollEnchant")
Remote.createTranscended = Remote.Resolve("RF/CreateTranscendedStone")

-- Support Features state
local SupportState = {
    cutsceneConns = {
        Blocked = {},
        AttrWatcher = nil,
        IgnoreWatcher = nil,
        RootWatcher = nil,
        Watcher = nil,
    },
    abilityVFXConns = { Blocked = {} },
    hidePlayersConns = {},
    skinEffectConns = {
        Active = false,
        Connections = {},
        Roots = setmetatable({}, { __mode = "k" }),
        RodLines = setmetatable({}, { __mode = "k" }),
    },
    weatherVFXConns = {
        Active = false,
        Connections = {},
        Roots = setmetatable({}, { __mode = "k" }),
        RootNames = {},
        FogRoots = setmetatable({}, { __mode = "k" }),
        Brightness = nil,
        BrightnessConn = nil,
    },
    effectLocks = setmetatable({}, { __mode = "k" }),
    noFishAnimActive = false,
    autoEquipRodConn = nil,
    disableCutsceneActive = false,
    cutsceneHookDone = false,
    walkPlatform = nil,
    walkOnWaterConn = nil,
    walkOnWaterCharConn = nil,
    lockPosConn = nil,
    lockedCFrame = nil,
    animCtrlPatched = false,
    snDisplay = nil,
}

-- ====== INVENTORY ======
local Data = {
    Replion = require(Service.ReplicatedStorage.Packages.Replion),
    Events = nil, -- lazy-loaded saat weather feature dipakai
}
Data.Player = Data.Replion.Client:WaitReplion("Data")
Data.ItemUtility = require(Service.ReplicatedStorage.Shared.ItemUtility)
Data.FishingConstants = require(Service.ReplicatedStorage.Shared.Constants)

Data.getFishCount = function()
    local ok, count = pcall(function()
        local inventory = Data.Player:Get("Inventory") or Data.Player.Data.Inventory
        if not inventory or type(inventory.Items) ~= "table" then return 0 end
        local c = 0
        for _, item in ipairs(inventory.Items) do
            if type(item) == "table" and item.Id then
                local itemData = Data.ItemUtility.GetItemDataFromItemType("Fish", item.Id)
                local data = itemData and itemData.Data
                if data and data.Type == "Fish" then c = c + 1 end
            end
        end
        return c
    end)
    return ok and count or 0
end

-- ====== CONFIG ======
local Config = {
    InstantFishing  = false,
    CastWait        = 0.5,
    AutoSell        = false,
    AutoSellMode    = "Delay",
    SellDelay       = 10,
    SellCount       = 10,
    DisableFishNotif = false,
    TeleportLocation = "Ancient Jungle",
    RandomResults     = false,
    PerfectCast       = false,
    BlatantActive     = false,
    BlatantDelay      = 0,
    PriorityEvent         = "Select Option",
    SelectEvent           = "Select Option",
    SelectedWeatherEvents = {},
    BuyWeatherActive      = false,
    SelectedTotem         = "Luck Totem",
    AutoSpawnTotem        = false,
    EnchantType           = "Normal Enchant Stone",
    TargetEnchant         = "Select Option",
    AutoEnchantReroll     = false,
    SelectedSecretFish    = "Select Option",
    TranscendedOption     = "Select Option",
    TranscendedAmount     = 1,
    AutoCreateTranscended = false,
    -- Rod
    SelectedRod           = "Starter Rod",
    -- Bait
    SelectedBait          = "Topwater Bait",
    -- Black Market
    SelectedBMItems       = {},
    AutoBuyBM             = false,
    -- Battlepass
    SelectedBPSlots       = {},
    AutoBuyBP             = false,
    -- Merchant
    SelectedMerchantItem  = "Select Option",
    MerchantQty           = 1,
    AutoBuyMerchant       = false,
}

-- Shared runtime state. Kept in one table to stay light on Luau locals.
local Runtime = {
    StableResult = false,
    Random = Random.new(),
    Fishing = {
        Phase = "Idle",
        Owner = nil,
        CatchSerial = 0,
        LastCatchAt = 0,
        Failures = {},
        WaitReady = function() return false end,
        AwaitCatch = function() return false end,
        Recover = function() end,
        ResetServer = function() end,
        HandleResult = function() end,
    },
    Sell = {
        Busy = false,
        Pending = false,
        Phase = "Idle",
        Reason = nil,
        LastCall = 0,
        CompletedAt = 0,
        Revision = 0,
        CountSeen = -1,
        Ticket = 0,
        Worker = nil,
        Monitor = nil,
        Thread = nil,
        Finish = function() end,
        Wait = function() return true end,
        Flush = function() return false end,
        Queue = function() return false end,
        CheckCount = function() end,
        Execute = function() return false end,
        Start = function() end,
        Stop = function() end,
    },
}

-- Automation/shop state is declared once; feature logic fills its fields.
local S = {}
local UI = {}
local FishingModes = {
    Active = false,
    V1 = { Thread = nil },
    V2 = { Thread = nil, Active = false, Delay = 0, SnapReel = false },
    Blatant = {
        Thread = nil,
        Generation = 0,
        Visual = {
            clearInventoryVisuals = function() end,
            pending = {},
            nextTicket = 0,
            captureBadge = function() return 0 end,
            copies = {},
            copySerial = 0,
            badgeCount = 0,
            badgeOverride = false,
            writingBadge = false,
            refreshThread = nil,
            refreshTicket = 0,
            dirty = false,
            maxCopies = 80,
            cloneBatchSize = 12,
        },
    },
}

-- BaitCastVisual identifies the exact Beam(s) used as fishing line. Keep this
-- whitelist separate from rod aura heuristics so every rod skin is supported.
SupportState.releaseSkinLock = function(obj)
    local lock = obj and SupportState.effectLocks[obj]
    if not (lock and lock.Skin) then return end
    lock.Skin = nil
    if lock.Weather then
        lock.Apply()
        return
    end
    for _, connection in ipairs(lock.Connections or {}) do
        pcall(function() connection:Disconnect() end)
    end
    pcall(function()
        if obj.Parent and lock.Mode == "Enabled" then
            obj.Enabled = lock.Original
        end
    end)
    SupportState.effectLocks[obj] = nil
end

SupportState.trackRodLines = function(baitData)
    if not baitData then return end
    local equippedModel = baitData.EquippedToolModel
    local connectingJoint = baitData.ConnectingJoint
    if not equippedModel or connectingJoint == nil then return end
    local handle = equippedModel:FindFirstChild("Handle")
    if not handle then return end
    local baseName = tostring(connectingJoint)
    for index = 0, 5 do
        local beamName = index == 0 and baseName
            or string.format("%s.%d", baseName, index)
        local beam = handle:FindFirstChild(beamName)
        if beam and beam:IsA("Beam") then
            SupportState.skinEffectConns.RodLines[beam] = true
            SupportState.releaseSkinLock(beam)
        end
    end
end

-- ====== TELEPORT LOCATIONS ======
local Catalog = {}
Catalog.Locations = {
    ["Fisherman Island"]         = CFrame.new(-32.0142937, 9.53156853, 2714.27515, 0.363515794, -3.19144746e-08, 0.931588054, 4.9133412e-08, 1, 1.50857478e-08, -0.931588054, 4.02881888e-08, 0.363515794),
    ["Ancient Jungle"]           = CFrame.new(1467.427, 7.57433128, -327.696991, -0.300987154, 1.26613644e-08, -0.953628182, 1.90450802e-08, 1, 7.26597627e-09, 0.953628182, -1.597496e-08, -0.300987154),
    ["Ancient Ruin"]             = CFrame.new(6045.40186, -588.600952, 4608.93799, -0.995750964, 9.74889502e-09, -0.09208709, 1.08396971e-08, 1, -1.13451657e-08, 0.09208709, -1.2295156e-08, -0.995750964),
    ["Aquarium"]                 = CFrame.new(-3039.55811, -624.242798, -10573.4902, 0.936068058, -3.43754998e-08, -0.351818979, 1.69289542e-08, 1, -5.26658539e-08, 0.351818979, 4.33428937e-08, 0.936068058),
    ["Copper Canyon Mines"]      = CFrame.new(-4079.10596, -547.17395, 548.034973, -0.308991671, -1.66687215e-08, -0.951064765, -2.51436969e-08, 1, -9.3574366e-09, 0.951064765, 2.10219149e-08, -0.308991671),
    ["Copper Canyon [SPOT 1]"]   = CFrame.new(-4145.04297, 7.94670057, 617.357971, 0.407304734, 3.55349208e-08, 0.913292289, -5.54303945e-08, 1, -1.41880721e-08, -0.913292289, -4.48452866e-08, 0.407304734),
    ["Copper Canyon [SPOT 2]"]   = CFrame.new(-4241.76807, 60.4801407, 414.652008, -0.333387047, -3.28869056e-08, -0.942790031, -5.01047523e-08, 1, -1.71646164e-08, 0.942790031, 4.15158006e-08, -0.333387047),
    ["Coral Reefs"]              = CFrame.new(-2921.85791, 3.24999928, 2083.29712, 0.204768002, 1.61142459e-08, 0.978810549, -2.3231685e-08, 1, -1.16030021e-08, -0.978810549, -2.0363494e-08, 0.204768002),
    ["Crater Island"]            = CFrame.new(1074.37598, 4.02703142, 5098.47705, 0.226213664, 4.25005418e-08, 0.974077702, -6.19699563e-08, 1, -2.92400575e-08, -0.974077702, -5.3749055e-08, 0.226213664),
    ["Crater Island [TOP]"]      = CFrame.new(981.225281, 44.0553894, 5070.90479, 0.982008815, -4.95258412e-08, 0.188835099, 4.87237379e-08, 1, 8.88976359e-09, -0.188835099, 4.70925465e-10, 0.982008815),
    ["Crystal Depths"]           = CFrame.new(5729.33398, -904.818481, 15408.0781, 0.968347371, -5.45384964e-08, 0.249606386, 5.29429762e-08, 1, 1.31058382e-08, -0.249606386, 5.23901589e-10, 0.968347371),
    ["Gloomcap Grotto"]       = CFrame.new(5952.28955, -845.708496, 12480.1211, -0.555313528, -5.78371733e-08, 0.831641078, -4.77615529e-08, 1, 3.76539084e-08, -0.831641078, -1.88107432e-08, -0.555313528),
    ["Esoteric Depths"]          = CFrame.new(3207.32397, -1302.8551, 1444.52002, 0.393792599, -5.87720095e-08, -0.919199347, 2.26275283e-08, 1, -5.42444454e-08, 0.919199347, 5.61850844e-10, 0.393792599),
    ["Kohana"]                   = CFrame.new(-655.468994, 17.2447758, 501.037994, -0.2748532, 6.53977068e-08, -0.96148622, 1.85690503e-08, 1, 6.27091055e-08, 0.96148622, -6.18086415e-10, -0.2748532),
    ["Kohana Lab"]               = CFrame.new(-201.608002, 63.5564651, 475.351013, -0.857192814, 1.06985297e-07, 0.514995575, 9.11874309e-08, 1, -5.59618059e-08, -0.514995575, -1.00893593e-09, -0.857192814),
    ["Kohana Volcano"]           = CFrame.new(-552.304993, 20.7285309, 183.195007, 0.936509848, 1.00695118e-07, 0.350641221, -9.46366967e-08, 1, -3.44138549e-08, -0.350641221, -9.54613943e-10, 0.936509848),
    ["Lava Basin"]               = CFrame.new(894.223022, 89.0328903, -10195.5469, -0.387528092, -5.57523698e-08, -0.921857893, -2.20962768e-08, 1, -5.11894989e-08, 0.921857893, 5.32258293e-10, -0.387528092),
    ["Leviathan Den"]            = CFrame.new(3472.98291, -287.843201, 3471.07104, -0.922677159, 5.1146575e-08, -0.385573477, 4.73799773e-08, 1, 1.92704004e-08, 0.385573477, -4.88103502e-10, -0.922677159),
    ["Sisyphus Statue"]          = CFrame.new(-3739.76123, -135.074448, -1010.62256, -0.935245752, 9.59386242e-08, -0.353999078, 9.15687366e-08, 1, 2.90942843e-08, 0.353999078, -5.20494403e-09, -0.935245752),
    ["Lucky Abyss"]              = CFrame.new(-9132.19824, -269.540222, 813.390991, 0.85008198, 1.07898984e-07, -0.526650369, -8.86397729e-08, 1, 6.18017495e-08, 0.526650369, -5.85438409e-09, 0.85008198),
    ["Lucky Volcano"]            = CFrame.new(-8569.07227, -69.1043396, -424.654999, 0.52721554, 2.7758805e-08, -0.849731624, -1.33568694e-08, 1, 2.43804692e-08, 0.849731624, -1.5040077e-09, 0.52721554),
    ["Lucky Volcano Black Market"] = CFrame.new(-8610.20312, -66.52478, -451.74463, -0.2025885880, -0.0000000350, -0.9792639613, -0.0000000417, 1.0000000000, -0.0000000271, 0.9792639613, 0.0000000354, -0.2025885880),
    ["Mariana Trench"]           = CFrame.new(-9255.89844, -255.639084, -1.05099988, 0.855513036, 2.17598988e-08, 0.517781258, 7.29563077e-10, 1, -4.32307061e-08, -0.517781258, 3.7362188e-08, 0.855513036),
    ["Mutation Vents"]           = CFrame.new(-9112.33496, -91.77034, -1639.62903, 0.916036785, 1.55229181e-08, 0.401094198, -1.53244155e-08, 1, -3.7028427e-09, -0.401094198, -2.75459433e-09, 0.916036785),
    ["Pirate Cove"]              = CFrame.new(3406.97192, 4.19296837, 3497.08594, 0.710760236, -6.10149513e-08, -0.703434408, 3.57538994e-08, 1, -5.06123961e-08, 0.703434408, 1.08227542e-08, 0.710760236),
    ["Pirate Treasure Room"]     = CFrame.new(3349.35107, -297.941223, 3086.00293, 0.736163676, 6.15624174e-08, 0.676803589, -5.27107495e-08, 1, -3.36267156e-08, -0.676803589, -1.09200586e-08, 0.736163676),
    ["Planetary Observatory"]    = CFrame.new(440.902008, 9.17811108, 2148.80103, -0.899665594, 9.41240543e-08, 0.436579615, 7.73939064e-08, 1, -5.61075595e-08, -0.436579615, -1.66894392e-08, -0.899665594),
    ["Rushing Current"]          = CFrame.new(-9687.6123, -74.2790375, -1779.64294, 0.984130561, -1.05019289e-07, -0.177445754, 1.00051885e-07, 1, -3.69418025e-08, 0.177445754, 1.86017726e-08, 0.984130561),
    ["Sacred Temple"]            = CFrame.new(1453.83899, -22.1250057, -621.651978, -0.984368861, 8.34887288e-08, -0.176119015, 8.47873949e-08, 1, 1.51353347e-10, 0.176119015, -1.47836854e-08, -0.984368861),
    ["Sewers"]                   = CFrame.new(-1448.10901, -1041.58875, -10447.0791, -0.0303385258, 1.56512865e-08, 0.999539673, -2.29750796e-09, 1, -1.57282294e-08, -0.999539673, -2.77362155e-09, -0.0303385258),
    ["Shiny Abyss"]              = CFrame.new(-9729.08105, -269.540405, 810.505981, -0.922163904, 8.79246684e-08, -0.386799365, 8.71174208e-08, 1, 1.96177457e-08, 0.386799365, -1.56061866e-08, -0.922163904),
    ["Silent Reach"]             = CFrame.new(-10021.376, -72.1012039, 178.304993, 0.92953819, -1.05133402e-07, -0.368725896, 9.08463846e-08, 1, -5.61073037e-08, 0.368725896, 1.86564666e-08, 0.92953819),
    ["Starfall Gardens"]         = CFrame.new(-22266.7402, -252.371613, -7991.04102, -0.997285604, -4.51148878e-08, 0.0736306831, -4.4403258e-08, 1, 1.13018075e-08, -0.0736306831, 8.00168731e-09, -0.997285604),
    ["Stingrays Shores"]         = CFrame.new(-2131.052, 16.6846867, -848.953003, 0.99431318, 9.72805907e-08, -0.106495626, -9.48916821e-08, 1, 2.74991727e-08, 0.106495626, -1.7237241e-08, 0.99431318),
    ["The Celestarium"]          = CFrame.new(-28372.2051, -161.000824, -8254.71875, -0.996008456, 6.65103916e-10, 0.0892589167, 6.51938892e-10, 1, -1.76646225e-10, -0.0892589167, -1.17749782e-10, -0.996008456),
    ["Titan Pressure"]           = CFrame.new(-9867.53418, -84.1045456, -1188.15601, 0.93777144, 5.86523363e-09, 0.347253144, -5.8607732e-09, 1, -1.06311016e-09, -0.347253144, -1.03821751e-09, 0.93777144),
    ["Treasure Room"]            = CFrame.new(-3597.32397, -275.650909, -1641.22388, 0.99970746, 9.09716462e-08, 0.0241864715, -9.12070561e-08, 1, 8.62978933e-09, -0.0241864715, -1.08332419e-08, 0.99970746),
    ["Tropical Grove"]           = CFrame.new(-2140.7959, 53.4871521, 3622.71411, -0.86444521, 1.01028469e-07, 0.502727032, 8.12888246e-08, 1, -6.11837621e-08, -0.502727032, -1.20239187e-08, -0.86444521),
    ["Underground Cellar"]       = CFrame.new(2161.39111, -91.1981583, -729.22699, -0.374913067, -1.11294611e-07, 0.927059948, -2.94585263e-08, 1, 1.08137804e-07, -0.927059948, 1.3232456e-08, -0.374913067),
    ["Underwater City"]          = CFrame.new(-3140.83301, -643.476807, -10415.8057, 0.0199023858, -5.86244049e-08, -0.999801934, -5.80112491e-09, 1, -5.87514961e-08, 0.999801934, 6.96927094e-09, 0.0199023858),
    ["Volcanic Cavern"]          = CFrame.new(1145.14001, 74.9419708, -10234.5576, -0.47354874, 4.72444803e-08, -0.880767643, 2.73236118e-08, 1, 3.89494552e-08, 0.880767643, -5.62128832e-09, -0.47354874),
    ["Weather Machine"]          = CFrame.new(-1528.40698, 2.87499928, 1915.32397, -0.994741976, -1.69911782e-08, -0.10241317, -1.71090466e-08, 1, 2.72504852e-10, 0.10241317, 2.02326378e-09, -0.994741976),
}

local Navigation = {
    autoTpSpawnConn = nil,
    preEventCFrame = nil,
    eventWaterPlatform = nil,
    eventWaterConn = nil,
    eventWaterCharConn = nil,
    eventWatcherConn = nil,
    eventTeleportActive = false,
    npcInitList = nil,
}

Navigation.getNPCNames = function()
    local names = {}
    local npcFolder = workspace:FindFirstChild("NPC")
    if npcFolder then
        for _, model in ipairs(npcFolder:GetChildren()) do
            if model:IsA("Model") then
                table.insert(names, model.Name)
            end
        end
        table.sort(names)
    end
    return names
end


Catalog.SavedLocationFile = "OrvionFishIt/SavedLocation.json"

Navigation.getSavedLocation = function()
    if not isfile(Catalog.SavedLocationFile) then return nil end
    local ok, data = pcall(function()
        return Service.HttpService:JSONDecode(readfile(Catalog.SavedLocationFile))
    end)
    if not ok or not data then return nil end
    return CFrame.new(table.unpack(data))
end

Navigation.saveCurrentLocation = function()
    local char = Service.LocalPlayer.Character
    if not char then return false end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = root.CFrame:GetComponents()
    local ok = pcall(function()
        writefile(Catalog.SavedLocationFile, Service.HttpService:JSONEncode({
            x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22
        }))
    end)
    return ok
end

-- ====== UTILITIES ======
Navigation.teleportToSaved = function()
    local cf = Navigation.getSavedLocation()
    if not cf then return false end
    pcall(function()
        local char = Service.LocalPlayer.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        root.CFrame = cf
    end)
    return cf ~= nil
end

Navigation.setAutoTeleportOnSpawn = function(state)
    if Navigation.autoTpSpawnConn then Navigation.autoTpSpawnConn:Disconnect(); Navigation.autoTpSpawnConn = nil end
    if state then
        if Service.LocalPlayer.Character then
            task.spawn(function()
                task.wait(0.5)
                pcall(Navigation.teleportToSaved)
            end)
        end
        Navigation.autoTpSpawnConn = Service.LocalPlayer.CharacterAdded:Connect(function()
            task.wait(1)
            pcall(Navigation.teleportToSaved)
        end)
    end
end

Navigation.getPlayerList = function()
    local names = {}
    for _, p in ipairs(Service.Players:GetPlayers()) do
        if p ~= Service.LocalPlayer then
            table.insert(names, p.Name)
        end
    end
    table.sort(names)
    return names
end

Catalog.LocationNames = {
    "Ancient Jungle", "Ancient Ruin", "Aquarium",
    "Copper Canyon [SPOT 1]", "Copper Canyon [SPOT 2]", "Copper Canyon Mines",
    "Coral Reefs", "Crater Island", "Crater Island [TOP]", "Crystal Depths",
    "Esoteric Depths", "Fisherman Island", "Gloomcap Grotto",
    "Kohana", "Kohana Lab", "Kohana Volcano",
    "Lava Basin", "Leviathan Den", "Lucky Abyss", "Lucky Volcano",
    "Mariana Trench", "Mutation Vents",
    "Pirate Cove", "Pirate Treasure Room", "Planetary Observatory",
    "Rushing Current", "Sacred Temple", "Sewers",
    "Shiny Abyss", "Silent Reach", "Sisyphus Statue",
    "Starfall Gardens", "Stingrays Shores",
    "The Celestarium", "Titan Pressure", "Treasure Room", "Tropical Grove",
    "Underground Cellar", "Underwater City",
    "Volcanic Cavern", "Weather Machine"
}

Navigation.teleportTo = function(name)
    local cf = Catalog.Locations[name]
    if not cf then return end
    pcall(function()
        local char = Service.LocalPlayer.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        root.CFrame = cf
    end)
end

Navigation.teleportToBM = function(cf)
    local root = Service.LocalPlayer.Character
        and Service.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if root then root.CFrame = cf end
end

-- ====== CAST QUALITY HELPER ======
-- Built-in auto fishing keeps its native stable result. The manual instant
-- modes share one official charge flow: fast OK or sampled Perfect.

Runtime.getCastWaterY = function(power)
    local waterY = 1.2854545116425
    pcall(function()
        local char = Service.LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local castDist = power * 15 + 10
        local castPos = root.CFrame.Position + root.CFrame.LookVector * castDist
        local rp = RaycastParams.new()
        rp.IgnoreWater = false
        rp.FilterType = Enum.RaycastFilterType.Exclude
        rp.FilterDescendantsInstances = { char }
        local result = workspace:Raycast(
            Vector3.new(castPos.X, castPos.Y + 20, castPos.Z),
            Vector3.new(0, -40, 0), rp)
        if result then waterY = result.Position.Y end
    end)
    return waterY
end

Runtime.Fishing.IsModeActive = function(mode)
    if mode == "V1" then return Config.InstantFishing end
    if mode == "V2" then return FishingModes.V2.Active end
    if mode == "Blatant" then return Config.BlatantActive end
    return true
end

Runtime.Fishing.IsBlocked = function()
    local character = Service.LocalPlayer.Character
    return character and character:GetAttribute("IsTrading") == true or false
end

Runtime.Fishing.WaitReady = function(mode)
    while Runtime.Fishing.IsModeActive(mode) do
        if Runtime.Fishing.Owner and Runtime.Fishing.Owner ~= mode then
            task.wait(0.05)
        else
            local character = Service.LocalPlayer.Character
            if character and character:GetAttribute("SellAll") == true then
                Runtime.Sell.Wait(Runtime.Sell.Ticket)
            end
            if not Runtime.Fishing.IsBlocked() then
                Runtime.Fishing.Owner = mode
                return true
            else
                task.wait(0.05)
            end
        end
    end
    return false
end

Runtime.Fishing.Recover = function(mode)
    if Runtime.Fishing.Owner == mode then
        Runtime.Fishing.Owner = nil
        Runtime.Fishing.Phase = "Idle"
    end
end

Runtime.Fishing.ResetServer = function(mode)
    Runtime.Fishing.Failures[mode] = 0
    Runtime.Fishing.Owner = nil
    Runtime.Fishing.Phase = "Idle"
    if Remote.cancel then
        pcall(function() Remote.cancel:InvokeServer(true) end)
    end
end

Runtime.Fishing.HandleResult = function(mode, ok)
    if ok then
        Runtime.Fishing.Failures[mode] = 0
        return
    end
    Runtime.Fishing.Failures[mode] = (Runtime.Fishing.Failures[mode] or 0) + 1
    if Runtime.Fishing.Failures[mode] >= 2 then
        Runtime.Fishing.ResetServer(mode)
        task.wait(0.15)
    else
        Runtime.Fishing.Recover(mode)
    end
    task.wait(0.35)
end

Runtime.Fishing.AwaitCatch = function(mode, catchSerial)
    Runtime.Fishing.Phase = "AwaitCatch"
    local deadline = os.clock() + 3
    while Runtime.Fishing.IsModeActive(mode)
        and Runtime.Fishing.CatchSerial <= catchSerial
        and os.clock() < deadline
    do
        task.wait(0.03)
    end
    if Runtime.Fishing.CatchSerial <= catchSerial then
        Runtime.Fishing.Recover(mode)
        return false
    end

    Runtime.Fishing.Phase = "PostCatch"
    task.wait(0.15)
    Runtime.Sell.CheckCount()
    if Runtime.Sell.Pending then Runtime.Sell.Flush() end
    local character = Service.LocalPlayer.Character
    if Runtime.Sell.Busy
        or (character and character:GetAttribute("SellAll") == true)
    then
        Runtime.Sell.Wait(Runtime.Sell.Ticket)
    end

    if not Runtime.Fishing.IsModeActive(mode) then
        Runtime.Fishing.Recover(mode)
        return false
    end
    Runtime.Fishing.Owner = nil
    Runtime.Fishing.Phase = "Idle"
    return true
end

Runtime.requestConfiguredCast = function(mode)
    if not Runtime.Fishing.WaitReady(mode) then return false end

    local targetPower = Config.PerfectCast and 0.99 or 0.10
    if Config.RandomResults and not Config.PerfectCast then
        -- Uniform two-decimal result: 0.10, 0.11, ... 0.98, 0.99.
        targetPower = Runtime.Random:NextInteger(10, 99) / 100
    end
    -- Native ChargeFishingRod returns (accepted, authoritative start time).
    Runtime.Fishing.Phase = "Charging"
    local chargeCallOk, chargeAccepted, serverChargeStart = pcall(function()
        return Remote.charge:InvokeServer()
    end)
    if not chargeCallOk or not chargeAccepted
        or type(serverChargeStart) ~= "number"
    then
        Runtime.Fishing.Recover(mode)
        return false
    end

    local deadline = workspace:GetServerTimeNow() + 2
    while workspace:GetServerTimeNow() < deadline do
        local powerOk, currentPower = pcall(function()
            return Data.FishingConstants:GetPower(serverChargeStart)
        end)
        if powerOk and type(currentPower) == "number"
            and currentPower >= targetPower
        then
            currentPower = math.clamp(currentPower, 0, 1)
            local requestTime = workspace:GetServerTimeNow()
            local waterY = Runtime.getCastWaterY(currentPower)
            Runtime.Fishing.Phase = "Minigame"
            local minigameCallOk, started = pcall(function()
                return Remote.minigame:InvokeServer(
                    waterY, currentPower, requestTime)
            end)
            if minigameCallOk and started ~= false then return true end
            Runtime.Fishing.Recover(mode)
            return false
        end
        Service.RunService.Heartbeat:Wait()
    end

    -- Never submit a different tier if the requested power was not reached.
    Runtime.Fishing.Recover(mode)
    return false
end

-- ====== FISHING SYSTEM V1 ======
FishingModes.V1.Stop = function()
    Config.InstantFishing = false
    FishingModes.Active = false
    if FishingModes.V1.Thread then
        pcall(task.cancel, FishingModes.V1.Thread)
        FishingModes.V1.Thread = nil
    end
    Runtime.Fishing.ResetServer("V1")
end

FishingModes.V1.Start = function()
    if FishingModes.V1.Thread then task.cancel(FishingModes.V1.Thread) end
    FishingModes.V1.Thread = task.spawn(function()
        Runtime.Fishing.ResetServer("V1")
        task.wait(0.1)
        while Config.InstantFishing do
            FishingModes.Active = true
            local ok = pcall(function()
                if not Runtime.requestConfiguredCast("V1") then error("V1 cast request rejected") end
                if Config.CastWait > 0 then task.wait(Config.CastWait) end
                local catchSerial = Runtime.Fishing.CatchSerial
                Runtime.Fishing.Phase = "Completing"
                if not pcall(function() Remote.fishing:FireServer() end) then
                    error("V1 catch completion failed")
                end
                if not Runtime.Fishing.AwaitCatch("V1", catchSerial) then
                    error("V1 catch acknowledgement timeout")
                end
                task.wait(0.3)
            end)
            Runtime.Fishing.HandleResult("V1", ok)
            FishingModes.Active = false
        end
        FishingModes.Active = false
    end)
end

-- ====== FISHING SYSTEM V2 (Snap Reel) ======
-- AdjustSpeed: FishCaught = 3
FishingModes.V2.AnimationController = require(Service.ReplicatedStorage.Controllers.AnimationController)
FishingModes.V2.OriginalPlayAnimation = FishingModes.V2.AnimationController.PlayAnimation
FishingModes.V2.AnimationController.PlayAnimation = function(self, name, ...)
    local track, b, c = FishingModes.V2.OriginalPlayAnimation(self, name, ...)
    if FishingModes.V2.SnapReel and track then
        if name == "FishCaught" then
            pcall(function() track:AdjustSpeed(3) end)
        end
    end
    return track, b, c
end

-- hide bait via ChildAdded, duration exact dari BaitCastVisual
FishingModes.V2.CosmeticFolder = workspace:WaitForChild("CosmeticFolder", 10)
FishingModes.V2.PendingDuration = nil

if Remote.baitCast then
    Remote.baitCast.OnClientEvent:Connect(function(player, baitData)
        SupportState.trackRodLines(baitData)
        if player ~= Service.LocalPlayer then return end
        if not FishingModes.V2.SnapReel then return end
        if not (baitData and baitData.CastPosition and baitData.Origin) then return end
        local power = baitData.Power or 0
        local dist = (baitData.Origin - baitData.CastPosition).Magnitude
        FishingModes.V2.PendingDuration = dist / 40 * (1.2 - power * 0.4)
    end)
end

if FishingModes.V2.CosmeticFolder then
    FishingModes.V2.CosmeticFolder.ChildAdded:Connect(function(bait)
        if not FishingModes.V2.SnapReel then return end
        if bait.Name ~= tostring(Service.LocalPlayer.UserId) then return end

        local duration = FishingModes.V2.PendingDuration or 0.4
        FishingModes.V2.PendingDuration = nil

        local hidden = {}

        if bait:IsA("BasePart") or bait:IsA("MeshPart") then
            hidden[bait] = bait.Transparency
            bait.Transparency = 1
        end
        for _, d in ipairs(bait:GetDescendants()) do
            if d:IsA("BasePart") or d:IsA("MeshPart") then
                hidden[d] = d.Transparency
                d.Transparency = 1
            elseif d:IsA("Beam") or d:IsA("Trail") or d:IsA("ParticleEmitter") then
                hidden[d] = d.Enabled
                d.Enabled = false
            end
        end

        local baitAttachment = bait:FindFirstChildWhichIsA("Attachment")
        if baitAttachment then
            for _, root in ipairs({ Service.LocalPlayer.Character, FishingModes.V2.CosmeticFolder }) do
                if root then
                    for _, obj in ipairs(root:GetDescendants()) do
                        if obj:IsA("Beam") and obj.Attachment1 == baitAttachment and obj.Enabled then
                            hidden[obj] = obj.Enabled
                            obj.Enabled = false
                        end
                    end
                end
            end
        end

        task.wait(duration)

        for obj, orig in pairs(hidden) do
            pcall(function()
                if not obj.Parent then return end
                if SupportState.skinEffectConns.Active
                    and SupportState.isVisualEffect(obj)
                    and not SupportState.isRodLine(obj)
                then
                    SupportState.lockEffect("Skin", obj)
                elseif type(orig) == "number" then
                    obj.Transparency = orig
                else
                    obj.Enabled = orig
                end
            end)
        end
    end)
end


-- ====== BLATANT VISUAL ======
FishingModes.Blatant.Stop = function(restarting)
    if FishingModes.Blatant.Thread then
        task.cancel(FishingModes.Blatant.Thread)
        FishingModes.Blatant.Thread = nil
    end
    FishingModes.Blatant.Generation = FishingModes.Blatant.Generation + 1
    FishingModes.Active = false
    Config.BlatantActive = false
    table.clear(FishingModes.Blatant.Visual.pending)
    pcall(FishingModes.Blatant.Visual.clearInventoryVisuals)
    if not restarting then Runtime.Fishing.ResetServer("Blatant") end
end

FishingModes.Blatant.Start = function()
    FishingModes.Blatant.Stop(true)
    Runtime.Fishing.Owner = nil
    Runtime.Fishing.Phase = "Idle"
    Config.BlatantActive = true
    FishingModes.Blatant.Generation = FishingModes.Blatant.Generation + 1
    FishingModes.Blatant.Thread = task.spawn(function()
        Runtime.Fishing.ResetServer("Blatant")
        task.wait(0.1)
        while Config.BlatantActive do
            FishingModes.Active = true
            local ok = pcall(function()
                if not Runtime.requestConfiguredCast("Blatant") then
                    error("Blatant cast request rejected")
                end
                if Config.BlatantDelay > 0 then task.wait(Config.BlatantDelay) end
                FishingModes.Blatant.Visual.nextTicket = FishingModes.Blatant.Visual.nextTicket + 1
                local ticket = FishingModes.Blatant.Visual.nextTicket
                FishingModes.Blatant.Visual.pending[ticket] = FishingModes.Blatant.Visual.captureBadge()
                local catchSerial = Runtime.Fishing.CatchSerial
                Runtime.Fishing.Phase = "Completing"
                if not pcall(function() Remote.fishing:FireServer() end) then
                    FishingModes.Blatant.Visual.pending[ticket] = nil
                    error("Blatant catch completion failed")
                else
                    task.delay(2, function()
                        FishingModes.Blatant.Visual.pending[ticket] = nil
                    end)
                end
                if not Runtime.Fishing.AwaitCatch("Blatant", catchSerial) then
                    error("Blatant catch acknowledgement timeout")
                end
            end)
            Runtime.Fishing.HandleResult("Blatant", ok)
            task.wait(0.1)
            FishingModes.Active = false
        end
        FishingModes.Active = false
    end)
end

FishingModes.V2.Stop = function()
    FishingModes.V2.Active = false
    FishingModes.Active = false
    FishingModes.V2.SnapReel = false
    if FishingModes.V2.Thread then
        pcall(task.cancel, FishingModes.V2.Thread)
        FishingModes.V2.Thread = nil
    end
    Runtime.Fishing.ResetServer("V2")
end

FishingModes.V2.Start = function()
    if FishingModes.V2.Thread then task.cancel(FishingModes.V2.Thread) end
    FishingModes.V2.SnapReel = true
    FishingModes.V2.Thread = task.spawn(function()
        Runtime.Fishing.ResetServer("V2")
        task.wait(0.1)
        while FishingModes.V2.Active do
            FishingModes.Active = true
            local ok = pcall(function()
                if not Runtime.requestConfiguredCast("V2") then error("V2 cast request rejected") end
                if FishingModes.V2.Delay > 0 then task.wait(FishingModes.V2.Delay) end
                local catchSerial = Runtime.Fishing.CatchSerial
                Runtime.Fishing.Phase = "Completing"
                local completed = pcall(function() Remote.fishing:FireServer() end)
                if not completed then error("V2 catch completion failed") end
                if not Runtime.Fishing.AwaitCatch("V2", catchSerial) then
                    error("V2 catch acknowledgement timeout")
                end
                task.wait(0.05)
            end)
            Runtime.Fishing.HandleResult("V2", ok)
            FishingModes.Active = false
        end
        FishingModes.Active = false
    end)
end

-- ====== AUTO SELL SYSTEM ======
Runtime.Sell.Finish = function(ticket)
    if ticket ~= Runtime.Sell.Ticket then return end
    local worker = Runtime.Sell.Worker
    local monitor = Runtime.Sell.Monitor
    Runtime.Sell.Busy = false
    Runtime.Sell.Phase = "Idle"
    Runtime.Sell.Worker = nil
    Runtime.Sell.Monitor = nil
    Runtime.Sell.CompletedAt = os.clock()
    -- Fake Blatant inventory entries represent the sold batch and must not
    -- survive into later sell cycles.
    pcall(FishingModes.Blatant.Visual.clearInventoryVisuals)
    if worker and worker ~= coroutine.running() then pcall(task.cancel, worker) end
    if monitor and monitor ~= coroutine.running() then pcall(task.cancel, monitor) end
end

Runtime.Sell.Wait = function(ticket)
    local deadline = os.clock() + 5.5
    local clearSince = nil
    while os.clock() < deadline do
        local character = Service.LocalPlayer.Character
        local selling = character and character:GetAttribute("SellAll") == true
        local active = (Runtime.Sell.Busy and Runtime.Sell.Ticket == ticket) or selling
        if active then
            clearSince = nil
        elseif not clearSince then
            clearSince = os.clock()
        elseif os.clock() - clearSince >= 0.15 then
            return true
        end
        task.wait(0.05)
    end
    if Runtime.Sell.Busy and Runtime.Sell.Ticket == ticket then
        Runtime.Sell.Finish(ticket)
    end
    return false
end

Runtime.Sell.Execute = function()
    if Runtime.Sell.Busy or Runtime.Sell.Phase ~= "Idle" then return false end
    if os.clock() - Runtime.Sell.LastCall < 0.25 then return false end
    if not Remote.sell then return false end
    local character = Service.LocalPlayer.Character
    if character and (character:GetAttribute("SellAll") == true
        or character:GetAttribute("IsTrading") == true)
    then
        return false
    end

    Runtime.Sell.Busy = true
    Runtime.Sell.Phase = "Starting"
    Runtime.Sell.Pending = false
    Runtime.Sell.LastCall = os.clock()
    Runtime.Sell.Ticket = Runtime.Sell.Ticket + 1
    local ticket = Runtime.Sell.Ticket
    local startedAt = os.clock()
    local sawSellAll = false
    local callDone = false

    -- The request and its watchdog are separate so a stalled RF cannot pin
    -- every fishing loop forever on low-end/mobile executors.
    Runtime.Sell.Worker = task.spawn(function()
        pcall(function() return Remote.sell:InvokeServer() end)
        if ticket ~= Runtime.Sell.Ticket then return end
        callDone = true
    end)
    Runtime.Sell.Monitor = task.spawn(function()
        while ticket == Runtime.Sell.Ticket do
            local char = Service.LocalPlayer.Character
            local selling = char and char:GetAttribute("SellAll") == true
            if selling then
                sawSellAll = true
                Runtime.Sell.Phase = "Selling"
            elseif sawSellAll
                or (callDone and os.clock() - startedAt >= 0.35)
            then
                Runtime.Sell.Finish(ticket)
                return
            elseif os.clock() - startedAt >= 5 then
                Runtime.Sell.Finish(ticket)
                return
            end
            task.wait(0.05)
        end
    end)

    return true
end

Runtime.Sell.Flush = function()
    if not Runtime.Sell.Pending then return false end
    return Runtime.Sell.Execute()
end

Runtime.Sell.Queue = function(reason)
    Runtime.Sell.Pending = true
    Runtime.Sell.Reason = reason or Runtime.Sell.Reason or "Manual"
    local nativeAuto = false
    local currentGUID = nil
    pcall(function()
        nativeAuto = Data.Player:Get("AutoFishing") == true
    end)
    pcall(function()
        if FishingModes.Controller then
            if FishingModes.Controller.GetCurrentGUID then
                currentGUID = FishingModes.Controller:GetCurrentGUID()
            else
                currentGUID = FishingModes.Controller.CurrentGUID
            end
        end
    end)
    if Runtime.Fishing.Phase == "Idle"
        and not nativeAuto
        and currentGUID == nil
    then
        task.defer(function()
            if Runtime.Fishing.Phase == "Idle" then Runtime.Sell.Flush() end
        end)
    end
    return true
end

Runtime.Sell.CheckCount = function()
    if not Config.AutoSell or Config.AutoSellMode ~= "Count" then return end
    local currentCount = Data.getFishCount()
    if Runtime.Sell.CountSeen < 0 then
        Runtime.Sell.CountSeen = currentCount
        if currentCount >= Config.SellCount
            and not Runtime.Sell.Pending
            and not Runtime.Sell.Busy
        then
            Runtime.Sell.Queue("Count")
        end
    elseif currentCount ~= Runtime.Sell.CountSeen then
        local increased = currentCount > Runtime.Sell.CountSeen
        Runtime.Sell.CountSeen = currentCount
        if increased and currentCount >= Config.SellCount
            and not Runtime.Sell.Pending
            and not Runtime.Sell.Busy
        then
            Runtime.Sell.Queue("Count")
        end
    end
end

Runtime.Sell.Stop = function()
    Config.AutoSell = false
    Runtime.Sell.Pending = false
    Runtime.Sell.CountSeen = -1
    if Runtime.Sell.Thread then
        task.cancel(Runtime.Sell.Thread)
        Runtime.Sell.Thread = nil
    end
end

Runtime.Sell.Start = function()
    if Runtime.Sell.Thread then task.cancel(Runtime.Sell.Thread) end
    Runtime.Sell.CountSeen = -1

    Runtime.Sell.Thread = task.spawn(function()
        local currentMode = Config.AutoSellMode
        local seenRevision = Runtime.Sell.Revision
        local lastSellTick = os.clock()

        while Config.AutoSell do
            if currentMode ~= Config.AutoSellMode
                or seenRevision ~= Runtime.Sell.Revision
            then
                currentMode = Config.AutoSellMode
                seenRevision = Runtime.Sell.Revision
                lastSellTick = os.clock()
                Runtime.Sell.CountSeen = -1
            end

            if Config.AutoSellMode == "Delay" then
                local timerStart = math.max(lastSellTick, Runtime.Sell.CompletedAt)
                if os.clock() - timerStart >= Config.SellDelay
                    and not Runtime.Sell.Pending
                    and not Runtime.Sell.Busy
                then
                    Runtime.Sell.Queue("Delay")
                    lastSellTick = os.clock()
                end
                task.wait(0.5)

            elseif Config.AutoSellMode == "Count" then
                Runtime.Sell.CheckCount()
                task.wait(0.5)
            end
        end
    end)
end

-- ====== SMALL NOTIFICATION (AUTO ON) ======
FishingModes.FishNameToId = {}

for itemId = 1, 1000 do
    local fishData = Data.ItemUtility.GetItemDataFromItemType("Fish", itemId)
    if fishData and fishData.Data and fishData.Data.Name then
        FishingModes.FishNameToId[fishData.Data.Name] = itemId
    end
end



do
    local okTextController, TextNotificationController = pcall(
        require,
        Service.ReplicatedStorage.Controllers.TextNotificationController
    )
    local okVisualController, FishCaughtVisual = pcall(
        require,
        Service.ReplicatedStorage.Controllers.FishingController:WaitForChild("FishCaughtVisual")
    )

    -- One shared table keeps this block below Luau's local-register limit.
    -- Blatant reuses the native badge and releases it when inventory opens.

    local function resolveInventoryGrid()
        if FishingModes.Blatant.Visual.inventoryGrid and FishingModes.Blatant.Visual.inventoryGrid.Parent then
            return FishingModes.Blatant.Visual.inventoryGrid
        end
        pcall(function()
            FishingModes.Blatant.Visual.inventoryGui = Service.LocalPlayer.PlayerGui:FindFirstChild("Inventory")
            local main = FishingModes.Blatant.Visual.inventoryGui
                and FishingModes.Blatant.Visual.inventoryGui:FindFirstChild("Main")
            local content = main and main:FindFirstChild("Content")
            local pages = content and content:FindFirstChild("Pages")
            local inventoryPage = pages and pages:FindFirstChild("Inventory2")
            local pageMain = inventoryPage and inventoryPage:FindFirstChild("Main")
            FishingModes.Blatant.Visual.inventoryGrid = pageMain and pageMain:FindFirstChild("Inventory")
        end)
        return FishingModes.Blatant.Visual.inventoryGrid
    end

    local function resolveInventoryBadge()
        if FishingModes.Blatant.Visual.nativeBadge and FishingModes.Blatant.Visual.nativeBadge.Parent then
            return FishingModes.Blatant.Visual.nativeBadge, FishingModes.Blatant.Visual.nativeText
        end
        pcall(function()
            local backpack = Service.LocalPlayer.PlayerGui:FindFirstChild("Backpack")
            local display = backpack and backpack:FindFirstChild("Display")
            local inventoryButton = display and display:FindFirstChild("Inventory")
            FishingModes.Blatant.Visual.nativeBadge = inventoryButton
                and inventoryButton:FindFirstChild("Notification")
            if FishingModes.Blatant.Visual.nativeBadge then
                if FishingModes.Blatant.Visual.nativeBadge:IsA("TextLabel")
                    or FishingModes.Blatant.Visual.nativeBadge:IsA("TextButton")
                then
                    FishingModes.Blatant.Visual.nativeText = FishingModes.Blatant.Visual.nativeBadge
                else
                    FishingModes.Blatant.Visual.nativeText = FishingModes.Blatant.Visual.nativeBadge
                        :FindFirstChildWhichIsA("TextLabel", true)
                        or FishingModes.Blatant.Visual.nativeBadge
                            :FindFirstChildWhichIsA("TextButton", true)
                end
            end
        end)
        return FishingModes.Blatant.Visual.nativeBadge, FishingModes.Blatant.Visual.nativeText
    end

    FishingModes.Blatant.Visual.captureBadge = function()
        if FishingModes.Blatant.Visual.badgeOverride then
            return FishingModes.Blatant.Visual.badgeCount
        end
        local notification, textObject = resolveInventoryBadge()
        return notification and notification.Visible and textObject
            and tonumber(textObject.Text) or 0
    end

    local function refreshInventoryBadge()
        if not FishingModes.Blatant.Visual.badgeOverride then return end
        local notification, textObject = resolveInventoryBadge()
        if not notification or not notification:IsA("GuiObject") then return end
        FishingModes.Blatant.Visual.writingBadge = true
        pcall(function()
            notification.Visible = FishingModes.Blatant.Visual.badgeCount > 0
            if textObject then
                textObject.Text = tostring(FishingModes.Blatant.Visual.badgeCount)
                textObject.Visible = FishingModes.Blatant.Visual.badgeCount > 0
            end
        end)
        FishingModes.Blatant.Visual.writingBadge = false
    end

    local function removeVisualInventoryTiles()
        local grid = resolveInventoryGrid()
        if not grid then return end
        for _, child in ipairs(grid:GetChildren()) do
            if child:GetAttribute("OrvionVisualDuplicate") then
                pcall(function() child:Destroy() end)
            end
        end
    end

    local function metadataMatches(actual, expected)
        if type(expected) ~= "table" then return true end
        if type(actual) ~= "table" then return false end
        for _, key in ipairs({ "VariantId", "Weight" }) do
            local wanted = expected[key]
            if wanted ~= nil then
                local value = actual[key]
                if type(wanted) == "number" and type(value) == "number" then
                    if math.abs(value - wanted) > 0.000001 then return false end
                elseif value ~= wanted then
                    return false
                end
            end
        end
        return true
    end

    local function metadataKey(itemId, metadata)
        local variant = type(metadata) == "table" and metadata.VariantId or nil
        local weight = type(metadata) == "table" and metadata.Weight or nil
        if type(weight) == "number" then
            weight = string.format("%.6f", weight)
        end
        return table.concat({
            tostring(itemId),
            tostring(variant or ""),
            tostring(weight or ""),
        }, "\31")
    end

    local function resolveCaughtItemUUIDs(serials)
        local inventory = Data.Player:Get("Inventory") or Data.Player.Data.Inventory
        local items = inventory and inventory.Items
        if type(items) ~= "table" then return end

        local inventoryUUIDs = {}
        local exactBuckets = {}
        local idBuckets = {}
        -- Inventory items are appended newest-last. Build newest-first buckets
        -- once instead of scanning the complete inventory for every clone.
        for index = #items, 1, -1 do
            local item = items[index]
            local uuid = type(item) == "table" and item.UUID or nil
            if type(item) == "table" and uuid ~= nil then
                uuid = tostring(uuid)
                inventoryUUIDs[uuid] = true
                local entry = { UUID = uuid, Metadata = item.Metadata }
                local exactKey = metadataKey(item.Id, item.Metadata)
                local idKey = tostring(item.Id)
                exactBuckets[exactKey] = exactBuckets[exactKey] or {}
                idBuckets[idKey] = idBuckets[idKey] or {}
                table.insert(exactBuckets[exactKey], entry)
                table.insert(idBuckets[idKey], entry)
            end
        end

        -- Preserve UUIDs already resolved, but release stale/sold entries.
        local claimed = {}
        for _, serial in ipairs(serials) do
            local descriptor = FishingModes.Blatant.Visual.copies[serial]
            if descriptor and descriptor.UUID then
                descriptor.UUID = tostring(descriptor.UUID)
                if inventoryUUIDs[descriptor.UUID] then
                    claimed[descriptor.UUID] = true
                else
                    descriptor.UUID = nil
                end
            end
        end

        -- Serials are newest-first, so identical catches receive the newest
        -- available UUID first. Exact metadata is the normal O(1) path.
        local cursors = {}
        for _, serial in ipairs(serials) do
            local descriptor = FishingModes.Blatant.Visual.copies[serial]
            if descriptor and not descriptor.UUID then
                local exactKey = metadataKey(descriptor.ItemId, descriptor.Metadata)
                local bucket = exactBuckets[exactKey]
                local cursor = cursors[exactKey] or 1
                while bucket and bucket[cursor]
                    and claimed[bucket[cursor].UUID]
                do
                    cursor = cursor + 1
                end

                local entry = bucket and bucket[cursor]
                if entry then
                    cursors[exactKey] = cursor + 1
                else
                    -- Rare compatibility fallback for incomplete FishCaught
                    -- metadata. It still requires the same item id/metadata.
                    for _, candidate in ipairs(
                        idBuckets[tostring(descriptor.ItemId)] or {}
                    ) do
                        if not claimed[candidate.UUID]
                            and metadataMatches(candidate.Metadata, descriptor.Metadata)
                        then
                            entry = candidate
                            break
                        end
                    end
                end

                if entry then
                    descriptor.UUID = entry.UUID
                    claimed[entry.UUID] = true
                end
            end
        end
    end

    local function findSourceInventoryTile(descriptor)
        local grid = resolveInventoryGrid()
        if not grid then return nil end
        local uuid = descriptor.UUID
        if not uuid then return nil end
        local source = grid:FindFirstChild(uuid)
        if source and source:IsA("GuiObject")
            and not source:GetAttribute("OrvionVisualDuplicate")
        then
            return source
        end
        return nil
    end

    local function makeVisualTileInert(tile)
        local objects = { tile }
        for _, object in ipairs(tile:GetDescendants()) do
            table.insert(objects, object)
        end
        for _, object in ipairs(objects) do
            if object:IsA("GuiButton") then
                object.Active = false
                object.Selectable = false
                object.AutoButtonColor = false
            elseif object:IsA("LocalScript") or object:IsA("Script") then
                object:Destroy()
            end
        end
    end

    local function inventoryIsOpen()
        local inventoryGui = FishingModes.Blatant.Visual.inventoryGui
        return inventoryGui and inventoryGui.Parent and inventoryGui.Enabled == true
    end

    local requestInventoryVisualRefresh

    local function refreshStillValid(ticket, grid)
        return ticket == FishingModes.Blatant.Visual.refreshTicket
            and Config.BlatantActive
            and inventoryIsOpen()
            and grid
            and grid.Parent ~= nil
    end

    local function refreshVisualInventoryTiles(ticket)
        if ticket ~= FishingModes.Blatant.Visual.refreshTicket
            or not inventoryIsOpen()
        then return end
        local grid = resolveInventoryGrid()
        if not grid then return end

        local serials = {}
        for serial in pairs(FishingModes.Blatant.Visual.copies) do
            table.insert(serials, serial)
        end
        table.sort(serials, function(a, b) return a > b end)
        resolveCaughtItemUUIDs(serials)

        -- Keep valid clones made by an earlier batch/catch. Only orphaned
        -- clones are removed, so retries never rebuild successful work.
        local existing = {}
        for _, child in ipairs(grid:GetChildren()) do
            if child:GetAttribute("OrvionVisualDuplicate") then
                local serial = tonumber(child:GetAttribute("OrvionVisualSerial"))
                local descriptor = serial
                    and FishingModes.Blatant.Visual.copies[serial]
                if descriptor
                    and descriptor.UUID
                    and child:GetAttribute("OrvionVisualUUID") == descriptor.UUID
                then
                    existing[serial] = true
                else
                    pcall(function() child:Destroy() end)
                end
            end
        end

        local pending = {}
        for _, serial in ipairs(serials) do
            if not existing[serial] then table.insert(pending, serial) end
        end

        for attempt = 1, 3 do
            if #pending == 0 or not refreshStillValid(ticket, grid) then break end
            local unresolved = {}
            local processed = 0
            for _, serial in ipairs(pending) do
                if not refreshStillValid(ticket, grid) then return end
                local descriptor = FishingModes.Blatant.Visual.copies[serial]
                local source = descriptor and findSourceInventoryTile(descriptor)
                if source then
                    local clone = source:Clone()
                    clone.Name = source.Name .. "_OrvionVisual_" .. tostring(serial)
                    clone:SetAttribute("OrvionVisualDuplicate", true)
                    clone:SetAttribute("OrvionVisualSerial", serial)
                    clone:SetAttribute("OrvionVisualUUID", descriptor.UUID)
                    clone.LayoutOrder = source.LayoutOrder + 1
                    clone.Visible = true
                    makeVisualTileInert(clone)
                    if refreshStillValid(ticket, grid)
                        and FishingModes.Blatant.Visual.copies[serial] == descriptor
                    then
                        clone.Parent = grid
                    else
                        clone:Destroy()
                        return
                    end
                else
                    table.insert(unresolved, serial)
                end

                processed = processed + 1
                if processed % FishingModes.Blatant.Visual.cloneBatchSize == 0 then
                    Service.RunService.Heartbeat:Wait()
                    if not refreshStillValid(ticket, grid) then return end
                end
            end
            pending = unresolved
            if #pending > 0 and attempt < 3 then
                task.wait(0.15)
                if not refreshStillValid(ticket, grid) then return end
                resolveCaughtItemUUIDs(serials)
            end
        end
        FishingModes.Blatant.Visual.dirty = #pending > 0
    end

    requestInventoryVisualRefresh = function(delayTime)
        FishingModes.Blatant.Visual.dirty = true
        if not inventoryIsOpen() then return end
        FishingModes.Blatant.Visual.refreshTicket =
            FishingModes.Blatant.Visual.refreshTicket + 1
        local ticket = FishingModes.Blatant.Visual.refreshTicket
        if FishingModes.Blatant.Visual.refreshThread then
            pcall(task.cancel, FishingModes.Blatant.Visual.refreshThread)
        end
        FishingModes.Blatant.Visual.refreshThread = task.delay(delayTime or 0.1, function()
            if ticket ~= FishingModes.Blatant.Visual.refreshTicket then return end
            if Config.BlatantActive
                and FishingModes.Blatant.Visual.dirty
                and inventoryIsOpen()
            then
                local ok, err = pcall(refreshVisualInventoryTiles, ticket)
                if not ok then
                    warn("[Orvion] inventory visual refresh failed:", err)
                end
            end
            if ticket == FishingModes.Blatant.Visual.refreshTicket then
                FishingModes.Blatant.Visual.refreshThread = nil
            end
        end)
    end

    local function registerVisualInventoryCopy(fishItemId, fishMetadata, badgeBaseline)
        FishingModes.Blatant.Visual.copySerial = FishingModes.Blatant.Visual.copySerial + 1
        local serial = FishingModes.Blatant.Visual.copySerial
        FishingModes.Blatant.Visual.copies[serial] = {
            ItemId = fishItemId,
            Metadata = type(fishMetadata) == "table" and fishMetadata or nil,
            UUID = nil,
        }
        FishingModes.Blatant.Visual.copies[
            serial - FishingModes.Blatant.Visual.maxCopies
        ] = nil
        if not FishingModes.Blatant.Visual.badgeOverride then
            FishingModes.Blatant.Visual.badgeCount = tonumber(badgeBaseline) or 0
            FishingModes.Blatant.Visual.badgeOverride = true
        end
        FishingModes.Blatant.Visual.badgeCount = FishingModes.Blatant.Visual.badgeCount + 2
        requestInventoryVisualRefresh(0.12)
        task.defer(refreshInventoryBadge)
    end

    FishingModes.Blatant.Visual.clearInventoryVisuals = function()
        FishingModes.Blatant.Visual.refreshTicket =
            FishingModes.Blatant.Visual.refreshTicket + 1
        if FishingModes.Blatant.Visual.refreshThread then
            pcall(task.cancel, FishingModes.Blatant.Visual.refreshThread)
            FishingModes.Blatant.Visual.refreshThread = nil
        end
        FishingModes.Blatant.Visual.dirty = false
        table.clear(FishingModes.Blatant.Visual.copies)
        FishingModes.Blatant.Visual.copySerial = 0
        removeVisualInventoryTiles()
    end

    task.defer(function()
        resolveInventoryGrid()
        local notification, textObject = resolveInventoryBadge()
        if textObject then
            textObject:GetPropertyChangedSignal("Text"):Connect(function()
                if FishingModes.Blatant.Visual.badgeOverride
                    and not FishingModes.Blatant.Visual.writingBadge
                then
                    task.defer(refreshInventoryBadge)
                end
            end)
        end
        if notification and notification:IsA("GuiObject") then
            notification:GetPropertyChangedSignal("Visible"):Connect(function()
                if FishingModes.Blatant.Visual.badgeOverride
                    and not FishingModes.Blatant.Visual.writingBadge
                then
                    task.defer(refreshInventoryBadge)
                end
            end)
        end
        if FishingModes.Blatant.Visual.inventoryGui then
            FishingModes.Blatant.Visual.inventoryGui:GetPropertyChangedSignal("Enabled"):Connect(function()
                if FishingModes.Blatant.Visual.inventoryGui.Enabled then
                    if FishingModes.Blatant.Visual.badgeOverride then
                        -- Release ownership; the game's native claim performs reset.
                        FishingModes.Blatant.Visual.badgeCount = 0
                        FishingModes.Blatant.Visual.badgeOverride = false
                    end
                    if Config.BlatantActive then
                        requestInventoryVisualRefresh(0.08)
                    end
                else
                    FishingModes.Blatant.Visual.refreshTicket =
                        FishingModes.Blatant.Visual.refreshTicket + 1
                    if FishingModes.Blatant.Visual.refreshThread then
                        pcall(task.cancel, FishingModes.Blatant.Visual.refreshThread)
                        FishingModes.Blatant.Visual.refreshThread = nil
                    end
                    FishingModes.Blatant.Visual.dirty = true
                    removeVisualInventoryTiles()
                end
            end)
        end
    end)

    local function deliverFishNotification(fishItemId)
        local payload = {
            Type = "Item",
            ItemId = fishItemId,
            Text = "",
            CustomDuration = 5
        }
        if not (okTextController and TextNotificationController) then return end
        TextNotificationController:DeliverNotification(payload)
    end

    if Remote.fishCaught then
        Remote.fishCaught.OnClientEvent:Connect(function(fishName, fishMetadata, _, _, visualData)
            Runtime.Fishing.CatchSerial = Runtime.Fishing.CatchSerial + 1
            Runtime.Fishing.LastCatchAt = os.clock()
            -- Manual/native fishing has no custom loop boundary, so process its
            -- queued sell after Replion receives the newly caught item.
            task.delay(0.15, function()
                Runtime.Sell.CheckCount()
                if Runtime.Sell.Pending and Runtime.Fishing.Phase == "Idle" then
                    Runtime.Sell.Flush()
                end
            end)
            local fishItemId = FishingModes.FishNameToId[fishName]
            if not fishItemId then return end

            local ticket, badgeBaseline = next(FishingModes.Blatant.Visual.pending)
            local isBlatantCatch = ticket ~= nil
            if ticket then FishingModes.Blatant.Visual.pending[ticket] = nil end

            local notificationCount = isBlatantCatch and 2 or 1
            -- Text notifications are globally auto-on. Only Blatant duplicates
            -- the tile; manual, V1, V2, and native auto fishing receive one.
            for _ = 1, notificationCount do
                pcall(deliverFishNotification, fishItemId)
            end

            if isBlatantCatch then
                registerVisualInventoryCopy(fishItemId, fishMetadata, badgeBaseline)
            elseif FishingModes.Blatant.Visual.badgeOverride then
                FishingModes.Blatant.Visual.badgeCount = FishingModes.Blatant.Visual.badgeCount + 1
                task.defer(refreshInventoryBadge)
            end

            if isBlatantCatch
                and okVisualController
                and FishCaughtVisual
                and visualData
                and visualData.origin
            then
                local generation = FishingModes.Blatant.Generation
                local nativeDelay = tonumber(visualData.delayTime) or 0
                local extraDelay = math.max(nativeDelay, 0)
                task.delay(extraDelay, function()
                    if not Config.BlatantActive
                        or generation ~= FishingModes.Blatant.Generation
                    then return end
                    pcall(
                        FishCaughtVisual.playCaughtFishVisual,
                        Service.LocalPlayer,
                        visualData.origin,
                        fishName,
                        fishMetadata
                    )
                end)
            end
        end)
    end
end

-- ====== BIG POPUP TOGGLE ======
FishingModes.Controller = require(Service.ReplicatedStorage.Controllers.FishingController)

-- Stable Result: block auto worker charge only (isAuto == true), manual fishing unaffected
do
    local origCharge = FishingModes.Controller.RequestChargeFishingRod
    FishingModes.Controller.RequestChargeFishingRod = function(self, pos, isAuto, ...)
        if Runtime.StableResult and isAuto == true then return end
        return origCharge(self, pos, isAuto, ...)
    end
end

-- Re-invoke true kalau server matiin auto fishing (movement detection dll)
Data.Player:OnChange("AutoFishing", function(value)
    if Runtime.StableResult and not value then
        task.wait(0.1)
        if not Runtime.StableResult then return end
        pcall(function()
            Remote.updateAutoFishing:InvokeServer(true)
        end)
    end
end)
SupportState.updateBigPopup = function()
    if not SupportState.snDisplay then
        local sn = Service.LocalPlayer.PlayerGui:FindFirstChild("Small Notification")
        SupportState.snDisplay = sn and sn:FindFirstChild("Display")
    end
    if SupportState.snDisplay then
        if Config.DisableFishNotif then
            SupportState.snDisplay.Parent = nil
        else
            local sn = Service.LocalPlayer.PlayerGui:FindFirstChild("Small Notification")
            if sn then SupportState.snDisplay.Parent = sn end
        end
    end
end

-- ====== SUPPORT FEATURES FUNCTIONS ======

SupportState.setAutoEquipRod = function(state)
    if SupportState.autoEquipRodConn then SupportState.autoEquipRodConn:Disconnect() SupportState.autoEquipRodConn = nil end
    if state then
        local ok, equipped = pcall(function() return Data.Player:Get("EquippedId") end)
        if not (ok and equipped and equipped ~= "") then
            task.wait(0.2)
            pcall(function() Remote.equipTool:FireServer(1) end)
        end
        SupportState.autoEquipRodConn = Data.Player:OnChange("EquippedId", function(value)
            if not value or value == "" then
                task.wait(0.2)
                pcall(function() Remote.equipTool:FireServer(1) end)
            end
        end)
    end
end

-- Disable every replicated cutscene on this client, regardless of owner/tier.
SupportState.ensureCutsceneHook = function()
    if SupportState.cutsceneHookDone then return true end
    local ok, hooked = pcall(function()
        local CutsceneCtrl = require(Service.ReplicatedStorage.Controllers.CutsceneController)
        if not CutsceneCtrl then return false end
        local origPlay = CutsceneCtrl.Play
        if type(origPlay) ~= "function" then return false end
        CutsceneCtrl.Play = function(self, ...)
            if SupportState.disableCutsceneActive then return end
            return origPlay(self, ...)
        end
        return true
    end)
    SupportState.cutsceneHookDone = ok and hooked == true
    return SupportState.cutsceneHookDone
end

SupportState.stopLocalCutscene = function()
    local cutsceneActive = Service.LocalPlayer:GetAttribute("InCutscene") == true
        or Service.LocalPlayer:GetAttribute("IgnoreFOV") == true
        or workspace:FindFirstChild("CutsceneStuff") ~= nil
    if not cutsceneActive then return end
    pcall(function()
        local CutsceneCtrl = require(Service.ReplicatedStorage.Controllers.CutsceneController)
        if CutsceneCtrl and type(CutsceneCtrl.Stop) == "function" then
            CutsceneCtrl:Stop()
        end
    end)
    pcall(function() Service.LocalPlayer:SetAttribute("InCutscene", false) end)
    pcall(function() Service.LocalPlayer:SetAttribute("IgnoreFOV", false) end)
end

SupportState.blockCutsceneConnections = function()
    if not getconnections or not Remote.cutscene then return end
    for _, conn in pairs(getconnections(Remote.cutscene.OnClientEvent)) do
        if not table.find(SupportState.cutsceneConns.Blocked, conn) then
            local disabled = pcall(function() conn:Disable() end)
            if disabled then
                table.insert(SupportState.cutsceneConns.Blocked, conn)
            end
        end
    end
end

SupportState.setDisableCutscenes = function(state)
    if state then
        SupportState.disableCutsceneActive = true
        SupportState.ensureCutsceneHook()
        SupportState.blockCutsceneConnections()
        SupportState.stopLocalCutscene()

        if SupportState.cutsceneConns.Watcher then
            pcall(task.cancel, SupportState.cutsceneConns.Watcher)
        end
        SupportState.cutsceneConns.Watcher = task.spawn(function()
            while SupportState.disableCutsceneActive do
                SupportState.ensureCutsceneHook()
                SupportState.blockCutsceneConnections()
                task.wait(0.5)
            end
        end)

        if not SupportState.cutsceneConns.AttrWatcher then
            SupportState.cutsceneConns.AttrWatcher = Service.LocalPlayer:GetAttributeChangedSignal("InCutscene"):Connect(function()
                if SupportState.disableCutsceneActive and Service.LocalPlayer:GetAttribute("InCutscene") then
                    SupportState.stopLocalCutscene()
                end
            end)
        end
        if not SupportState.cutsceneConns.IgnoreWatcher then
            SupportState.cutsceneConns.IgnoreWatcher = Service.LocalPlayer:GetAttributeChangedSignal("IgnoreFOV"):Connect(function()
                if SupportState.disableCutsceneActive and Service.LocalPlayer:GetAttribute("IgnoreFOV") then
                    SupportState.stopLocalCutscene()
                end
            end)
        end
        if not SupportState.cutsceneConns.RootWatcher then
            SupportState.cutsceneConns.RootWatcher = workspace.ChildAdded:Connect(function(child)
                if SupportState.disableCutsceneActive and child.Name == "CutsceneStuff" then
                    task.defer(SupportState.stopLocalCutscene)
                end
            end)
        end
    else
        SupportState.disableCutsceneActive = false
        if SupportState.cutsceneConns.Watcher then
            pcall(task.cancel, SupportState.cutsceneConns.Watcher)
            SupportState.cutsceneConns.Watcher = nil
        end
        for _, conn in ipairs(SupportState.cutsceneConns.Blocked) do
            pcall(function() conn:Enable() end)
        end
        table.clear(SupportState.cutsceneConns.Blocked)
        if SupportState.cutsceneConns.AttrWatcher then
            SupportState.cutsceneConns.AttrWatcher:Disconnect()
            SupportState.cutsceneConns.AttrWatcher = nil
        end
        if SupportState.cutsceneConns.IgnoreWatcher then
            SupportState.cutsceneConns.IgnoreWatcher:Disconnect()
            SupportState.cutsceneConns.IgnoreWatcher = nil
        end
        if SupportState.cutsceneConns.RootWatcher then
            SupportState.cutsceneConns.RootWatcher:Disconnect()
            SupportState.cutsceneConns.RootWatcher = nil
        end
    end
end

-- Disable Ability VFX - block remote + destroy attribute (tanpa hook module)
SupportState.setDisableAbilityVFX = function(state)
    if state then
        if not SupportState.abilityVFXConns.Active then
            SupportState.abilityVFXConns.Active = true

            -- block RE/PlayAbilityVFX connection + re-check 3x
            if Remote.abilityVFX then
                for _, conn in pairs(getconnections(Remote.abilityVFX.OnClientEvent)) do
                    conn:Disable()
                    table.insert(SupportState.abilityVFXConns.Blocked, conn)
                end
                task.spawn(function()
                    for i = 1, 3 do
                        task.wait(1)
                        if not SupportState.abilityVFXConns.Active then return end
                        local conns = getconnections(Remote.abilityVFX.OnClientEvent)
                        for _, conn in pairs(conns) do
                            if not table.find(SupportState.abilityVFXConns.Blocked, conn) then
                                conn:Disable()
                                table.insert(SupportState.abilityVFXConns.Blocked, conn)
                            end
                        end
                    end
                end)
            end

            -- One workspace watcher replaces per-instance/per-character listeners.
            local function destroyAbilityVFX(v)
                if not v then return end
                if v:GetAttribute("AbilityVFX") == true or v:GetAttribute("AbilityAuraVFX") == true
                or v.Name == "AbilityCharacterAura" then
                    pcall(function() v:Destroy() end)
                end
            end
            for _, v in ipairs(workspace:GetDescendants()) do destroyAbilityVFX(v) end
            SupportState.abilityVFXConns.Live = workspace.DescendantAdded:Connect(function(v)
                if SupportState.abilityVFXConns.Active then destroyAbilityVFX(v) end
            end)
        end
    else
        SupportState.abilityVFXConns.Active = false
        for _, conn in pairs(SupportState.abilityVFXConns.Blocked) do
            if typeof(conn) == "userdata" then conn:Enable() end
        end
        SupportState.abilityVFXConns.Blocked = {}
        if SupportState.abilityVFXConns.Live then
            SupportState.abilityVFXConns.Live:Disconnect()
            SupportState.abilityVFXConns.Live = nil
        end
    end
end

-- Shared lightweight VFX locks. Weather and skin may target the same emitter;
-- restore it only after both toggles release their own lock.
SupportState.isVisualEffect = function(obj)
    return obj:IsA("ParticleEmitter") or obj:IsA("Beam") or obj:IsA("Trail")
        or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles")
        or obj:IsA("Light") or obj:IsA("Highlight") or obj:IsA("PostEffect")
        or obj:IsA("Atmosphere") or obj:IsA("Clouds")
        or obj:IsA("Decal") or obj:IsA("Texture")
end

SupportState.isWeatherPart = function(obj)
    if not obj:IsA("BasePart") then return false end
    if string.lower(obj.Name) == "screeneffect" then return true end
    if obj.Anchored and not obj.CanCollide and obj.Material == Enum.Material.Ice then
        local mesh = obj:FindFirstChildOfClass("BlockMesh")
        if mesh and (mesh.Scale.X >= 1000 or mesh.Scale.Z >= 1000) then
            return true
        end
    end
    return false
end

SupportState.lockEffect = function(tag, obj)
    if not obj then return end
    if not SupportState.isVisualEffect(obj)
        and not (tag == "Weather" and SupportState.isWeatherPart(obj))
    then return end
    local lock = SupportState.effectLocks[obj]
    if not lock then
        if obj:IsA("Atmosphere") then
            lock = { Mode = "Atmosphere", Density = obj.Density, Haze = obj.Haze, Glare = obj.Glare }
        elseif obj:IsA("Clouds") then
            lock = { Mode = "Clouds", Cover = obj.Cover, Density = obj.Density }
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            lock = { Mode = "Transparency", Original = obj.Transparency }
        elseif obj:IsA("BasePart") then
            lock = {
                Mode = "PartTransparency",
                Transparency = obj.Transparency,
                LocalTransparencyModifier = obj.LocalTransparencyModifier,
            }
        else
            local ok, enabled = pcall(function() return obj.Enabled end)
            if not ok then return end
            lock = { Mode = "Enabled", Original = enabled }
        end
        lock.Connections = {}
        lock.Apply = function()
            if not lock.Skin and not lock.Weather then return end
            pcall(function()
                if lock.Mode == "Atmosphere" then
                    if obj.Density ~= 0 then obj.Density = 0 end
                    if obj.Haze ~= 0 then obj.Haze = 0 end
                    if obj.Glare ~= 0 then obj.Glare = 0 end
                elseif lock.Mode == "Clouds" then
                    if obj.Cover ~= 0 then obj.Cover = 0 end
                    if obj.Density ~= 0 then obj.Density = 0 end
                elseif lock.Mode == "Transparency" then
                    if obj.Transparency ~= 1 then obj.Transparency = 1 end
                elseif lock.Mode == "PartTransparency" then
                    if obj.Transparency ~= 1 then obj.Transparency = 1 end
                    if obj.LocalTransparencyModifier ~= 1 then
                        obj.LocalTransparencyModifier = 1
                    end
                elseif obj.Enabled ~= false then
                    obj.Enabled = false
                end
            end)
        end
        SupportState.effectLocks[obj] = lock
        local properties
        if lock.Mode == "Atmosphere" then
            properties = { "Density", "Haze", "Glare" }
        elseif lock.Mode == "Clouds" then
            properties = { "Cover", "Density" }
        elseif lock.Mode == "Transparency" then
            properties = { "Transparency" }
        elseif lock.Mode == "PartTransparency" then
            properties = { "Transparency", "LocalTransparencyModifier" }
        else
            properties = { "Enabled" }
        end
        for _, property in ipairs(properties) do
            local ok, signal = pcall(function()
                return obj:GetPropertyChangedSignal(property)
            end)
            if ok and signal then
                table.insert(lock.Connections, signal:Connect(lock.Apply))
            end
        end
    end
    lock[tag] = true
    lock.Apply()
end

SupportState.releaseEffects = function(tag)
    for obj, lock in pairs(SupportState.effectLocks) do
        lock[tag] = nil
        if not lock.Skin and not lock.Weather then
            for _, connection in ipairs(lock.Connections or {}) do
                pcall(function() connection:Disconnect() end)
            end
            table.clear(lock.Connections or {})
            pcall(function()
                if not obj.Parent then return end
                if lock.Mode == "Atmosphere" then
                    obj.Density, obj.Haze, obj.Glare = lock.Density, lock.Haze, lock.Glare
                elseif lock.Mode == "Clouds" then
                    obj.Cover, obj.Density = lock.Cover, lock.Density
                elseif lock.Mode == "Transparency" then
                    obj.Transparency = lock.Original
                elseif lock.Mode == "PartTransparency" then
                    obj.Transparency = lock.Transparency
                    obj.LocalTransparencyModifier = lock.LocalTransparencyModifier
                else
                    obj.Enabled = lock.Original
                end
            end)
            SupportState.effectLocks[obj] = nil
        end
    end
end

SupportState.clearVFXConnections = function(bucket)
    for _, connection in ipairs(bucket.Connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(bucket.Connections)
    if bucket.Roots then
        bucket.Roots = setmetatable({}, { __mode = "k" })
    end
end

SupportState.watchVFXRoot = function(bucket, tag, root, predicate)
    if not root or (bucket.Roots and bucket.Roots[root]) then return end
    if bucket.Roots then bucket.Roots[root] = true end
    for _, obj in ipairs(root:GetDescendants()) do
        if (SupportState.isVisualEffect(obj)
            or (tag == "Weather" and SupportState.isWeatherPart(obj)))
            and predicate(obj)
        then
            SupportState.lockEffect(tag, obj)
        end
    end
    table.insert(bucket.Connections, root.DescendantAdded:Connect(function(obj)
        if bucket.Active
            and (SupportState.isVisualEffect(obj)
                or (tag == "Weather" and SupportState.isWeatherPart(obj)))
            and predicate(obj)
        then
            SupportState.lockEffect(tag, obj)
        end
    end))
end

SupportState.isRodLine = function(obj)
    if not obj:IsA("Beam") then return false end
    if SupportState.skinEffectConns.RodLines[obj] then return true end
    if obj:GetAttribute("FishingLine") == true
        or obj:GetAttribute("RodLine") == true
    then return true end
    local lowerName = string.lower(obj.Name)
    if lowerName == "rodline" or lowerName == "fishingline"
        or lowerName == "fishing line" or lowerName == "rope"
    then return true end
    if not string.match(obj.Name, "^%d+%.?%d*$") then return false end
    local cursor = obj.Parent
    for _ = 1, 6 do
        if not cursor then break end
        if cursor.Name == "Handle" then return true end
        cursor = cursor.Parent
    end
    return false
end

SupportState.isSkinEffect = function(obj)
    if SupportState.isRodLine(obj) then return false end
    local cosmetic = workspace:FindFirstChild("CosmeticFolder")
    if cosmetic and obj:IsDescendantOf(cosmetic) then return true end
    local cursor = obj
    for _ = 1, 12 do
        if not cursor then break end
        if cursor.Name == "!!!FISHING_VIEW_MODEL!!!"
            or cursor.Name == "!!!EQUIPPED_TOOL!!!"
        then return true end
        cursor = cursor.Parent
    end
    return false
end

-- Disable fishing skin/bait/catch effects for every player, preserving rod lines.
SupportState.setDisableSkinEffect = function(state)
    local bucket = SupportState.skinEffectConns
    SupportState.clearVFXConnections(bucket)
    bucket.Active = state
    if not state then
        SupportState.releaseEffects("Skin")
        return
    end

    local function attachCharacter(char)
        if bucket.Active and char then
            SupportState.watchVFXRoot(bucket, "Skin", char, SupportState.isSkinEffect)
        end
    end
    local function attachPlayer(player)
        if player.Character then attachCharacter(player.Character) end
        table.insert(bucket.Connections, player.CharacterAdded:Connect(attachCharacter))
    end
    local function attachCosmetic(cosmetic)
        if bucket.Active and cosmetic then
            SupportState.watchVFXRoot(bucket, "Skin", cosmetic, SupportState.isSkinEffect)
        end
    end

    for _, player in ipairs(Service.Players:GetPlayers()) do
        attachPlayer(player)
    end
    table.insert(bucket.Connections, Service.Players.PlayerAdded:Connect(attachPlayer))

    attachCosmetic(workspace:FindFirstChild("CosmeticFolder"))
    table.insert(bucket.Connections, workspace.ChildAdded:Connect(function(child)
        if bucket.Active and child.Name == "CosmeticFolder" then
            attachCosmetic(child)
        end
    end))
end

-- Disable weather emitters attached to the avatar and weather containers nearby.
Catalog.WeatherKeywords = {
    "weather", "fog", "wind", "radiant", "storm", "snow", "galaxy",
    "meteor", "frostmoon", "frost", "rain", "aurora",
}

SupportState.isWeatherEffect = function(obj)
    local cursor = obj
    for _ = 1, 9 do
        if not cursor then break end
        local name = string.lower(cursor.Name)
        for _, keyword in ipairs(Catalog.WeatherKeywords) do
            if string.find(name, keyword, 1, true) then return true end
        end
        if cursor:GetAttribute("WeatherVFX") == true
            or cursor:GetAttribute("WeatherEffect") == true
        then
            return true
        end
        cursor = cursor.Parent
    end
    return false
end

SupportState.collectWeatherRootNames = function()
    local bucket = SupportState.weatherVFXConns
    table.clear(bucket.RootNames)
    pcall(function()
        local controller = Service.ReplicatedStorage.Controllers:FindFirstChild("WeatherController")
        if not controller then return end
        for _, folderName in ipairs({ "Weather", "Assets" }) do
            local folder = controller:FindFirstChild(folderName)
            if folder then
                for _, child in ipairs(folder:GetChildren()) do
                    bucket.RootNames[string.lower(child.Name)] = true
                end
            end
        end
    end)
end

SupportState.isWeatherRoot = function(root)
    if not root then return false end
    local lowerName = string.lower(root.Name)
    if SupportState.weatherVFXConns.RootNames[lowerName] then return true end
    if string.find(lowerName, "fogeffect", 1, true) then return true end
    return SupportState.isWeatherEffect(root)
end

SupportState.updateWeatherBrightness = function()
    local bucket = SupportState.weatherVFXConns
    local hasFog = false
    if bucket.Active then
        for root in pairs(bucket.FogRoots) do
            if root and root.Parent then
                hasFog = true
                break
            end
        end
    end

    if hasFog then
        if bucket.Brightness == nil then
            local current = Service.Lighting.Brightness
            bucket.Brightness = current > 0 and current or 4
        end
        if not bucket.BrightnessConn then
            bucket.BrightnessConn = Service.Lighting:GetPropertyChangedSignal("Brightness"):Connect(function()
                if not bucket.Active then return end
                local target = bucket.Brightness
                if target and Service.Lighting.Brightness ~= target then
                    Service.Lighting.Brightness = target
                end
            end)
        end
        if Service.Lighting.Brightness ~= bucket.Brightness then
            Service.Lighting.Brightness = bucket.Brightness
        end
    else
        if bucket.BrightnessConn then
            bucket.BrightnessConn:Disconnect()
            bucket.BrightnessConn = nil
        end
        if bucket.Brightness ~= nil then
            Service.Lighting.Brightness = bucket.Brightness
            bucket.Brightness = nil
        end
    end
end

SupportState.setDisableWeatherVFX = function(state)
    local bucket = SupportState.weatherVFXConns
    SupportState.clearVFXConnections(bucket)
    bucket.Active = state
    bucket.FogRoots = setmetatable({}, { __mode = "k" })
    if not state then
        SupportState.updateWeatherBrightness()
        SupportState.releaseEffects("Weather")
        return
    end

    SupportState.collectWeatherRootNames()

    local function matchesServiceEffect(obj)
        return obj:IsA("Atmosphere") or obj:IsA("Clouds")
            or SupportState.isWeatherEffect(obj)
    end
    local function attachWeatherRoot(root)
        if not bucket.Active or not root then return end
        if SupportState.isWeatherPart(root) then
            SupportState.lockEffect("Weather", root)
            return
        end
        if not SupportState.isWeatherRoot(root) then return end
        local lowerName = string.lower(root.Name)
        if string.find(lowerName, "fog", 1, true) then
            bucket.FogRoots[root] = true
            SupportState.updateWeatherBrightness()
        end
        if SupportState.isVisualEffect(root) then
            SupportState.lockEffect("Weather", root)
        end
        SupportState.watchVFXRoot(bucket, "Weather", root, function()
            return true
        end)
    end
    local function attachCharacter(char)
        if bucket.Active and char then
            SupportState.watchVFXRoot(bucket, "Weather", char, SupportState.isWeatherEffect)
        end
    end
    local function attachCamera()
        if bucket.Active and workspace.CurrentCamera then
            SupportState.watchVFXRoot(
                bucket,
                "Weather",
                workspace.CurrentCamera,
                matchesServiceEffect
            )
        end
    end

    attachCharacter(Service.LocalPlayer.Character)
    attachCamera()
    SupportState.watchVFXRoot(bucket, "Weather", Service.Lighting, matchesServiceEffect)
    SupportState.watchVFXRoot(bucket, "Weather", workspace.Terrain, matchesServiceEffect)
    for _, root in ipairs(workspace:GetChildren()) do
        if root ~= Service.LocalPlayer.Character and root ~= workspace.CurrentCamera then
            attachWeatherRoot(root)
        end
    end

    table.insert(bucket.Connections, workspace.ChildAdded:Connect(attachWeatherRoot))
    table.insert(bucket.Connections, workspace.ChildRemoved:Connect(function(root)
        if bucket.FogRoots[root] then
            bucket.FogRoots[root] = nil
            SupportState.updateWeatherBrightness()
        end
    end))
    table.insert(bucket.Connections, Service.LocalPlayer.CharacterAdded:Connect(attachCharacter))
    table.insert(bucket.Connections, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(attachCamera))
end

-- Hide Other Players
SupportState.setHideOtherPlayers = function(state)
    for _, conn in pairs(SupportState.hidePlayersConns) do conn:Disconnect() end
    SupportState.hidePlayersConns = {}

    local function hidePlayer(player)
        if player == Service.LocalPlayer then return end
        local char = player.Character
        if char then
            for _, obj in ipairs(char:GetDescendants()) do
                if obj:IsA("BasePart") or obj:IsA("MeshPart") then
                        obj.Transparency = state and 1 or 0
                end
                if obj:IsA("Decal") then
                    obj.Transparency = state and 1 or 0
                end
            end
        end
    end

    if state then
        for _, p in ipairs(Service.Players:GetPlayers()) do
            hidePlayer(p)
        end
        table.insert(SupportState.hidePlayersConns, Service.Players.PlayerAdded:Connect(function(p)
            p.CharacterAdded:Connect(function() task.wait(0.5) hidePlayer(p) end)
        end))
    else
        for _, p in ipairs(Service.Players:GetPlayers()) do
            hidePlayer(p)  -- state = false -> transparencyModifier = 0 = show
        end
    end
end

SupportState.setWalkOnWater = function(state)
    if SupportState.walkOnWaterConn then SupportState.walkOnWaterConn:Disconnect() SupportState.walkOnWaterConn = nil end
    if SupportState.walkOnWaterCharConn then SupportState.walkOnWaterCharConn:Disconnect() SupportState.walkOnWaterCharConn = nil end
    if SupportState.walkPlatform then SupportState.walkPlatform:Destroy() SupportState.walkPlatform = nil end

    if not state then
        local char = Service.LocalPlayer.Character
        local hum = char and char:FindFirstChildWhichIsA("Humanoid")
        if hum then pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, true) end) end
        return
    end

    SupportState.walkPlatform = Instance.new("Part")
    SupportState.walkPlatform.Anchored = true
    SupportState.walkPlatform.CanCollide = false  -- off dulu
    SupportState.walkPlatform.Transparency = 1
    SupportState.walkPlatform.Size = Vector3.new(10, 0.5, 10)
    SupportState.walkPlatform.Name = "WalkOnWaterPlatform"
    SupportState.walkPlatform.CFrame = CFrame.new(0, -9999, 0)  -- jauh di bawah
    SupportState.walkPlatform.Parent = workspace

    local function attachToChar(char)
        local hum = char:FindFirstChildWhichIsA("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        if not hum or not root then return end

        local terrain = workspace:FindFirstChildWhichIsA("Terrain")

        -- Raycast ke bawah untuk detect water surface Y (akurat)
        local function getWaterSurfaceY(pos)
            local rayParams = RaycastParams.new()
            rayParams.FilterType = Enum.RaycastFilterType.Include
            rayParams.FilterDescendantsInstances = {terrain}
            local result = workspace:Raycast(
                Vector3.new(pos.X, pos.Y + 10, pos.Z),
                Vector3.new(0, -20, 0),
                rayParams
            )
            if result and result.Material == Enum.Material.Water then
                return result.Position.Y
            end
            return nil
        end

        -- Detect water via Terrain:ReadVoxels di posisi kaki
        local function checkWaterAt(pos)
            local ok, isWater = pcall(function()
                local vox = terrain:ReadVoxels(
                    Region3.new(pos, pos + Vector3.new(0.1, 0.1, 0.1)):ExpandToGrid(4), 4
                )
                return vox and vox[1] and vox[1][1] and vox[1][1][1] == Enum.Material.Water
            end)
            return ok and isWater or false
        end

        local inWater = false
        local waterSurfaceY = nil

        -- disable swimming SEKARANG agar tidak bisa swim sama sekali
        pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, false) end)

        if SupportState.walkOnWaterConn then SupportState.walkOnWaterConn:Disconnect() end
        SupportState.walkOnWaterConn = Service.RunService.Stepped:Connect(function()
            if not root.Parent then return end
            local pos = root.Position
            local feetPos = pos - Vector3.new(0, 3, 0)  -- posisi kaki

            local isWaterNow = checkWaterAt(feetPos)

            if isWaterNow and not inWater then
                -- baru masuk air -> raycast untuk dapat exact surface Y
                inWater = true
                waterSurfaceY = getWaterSurfaceY(pos) or (pos.Y - 2)
                SupportState.walkPlatform.CFrame = CFrame.new(pos.X, waterSurfaceY, pos.Z)
                SupportState.walkPlatform.CanCollide = true
            elseif not isWaterNow and inWater then
                inWater = false
                waterSurfaceY = nil
                SupportState.walkPlatform.CanCollide = false
                SupportState.walkPlatform.CFrame = CFrame.new(0, -9999, 0)
            end

            -- platform ikut XZ, Y = exact water surface (tidak berubah saat loncat)
            if inWater and waterSurfaceY then
                SupportState.walkPlatform.CFrame = CFrame.new(pos.X, waterSurfaceY, pos.Z)
            end
        end)
    end

    local char = Service.LocalPlayer.Character
    if char then attachToChar(char) end
    SupportState.walkOnWaterCharConn = Service.LocalPlayer.CharacterAdded:Connect(attachToChar)
end

-- Lock Position
SupportState.setLockPosition = function(state)
    if SupportState.lockPosConn then SupportState.lockPosConn:Disconnect() SupportState.lockPosConn = nil end
    if state then
        local char = Service.LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            SupportState.lockedCFrame = root.CFrame
            -- Anchored = true -> tidak bisa di-fling, tidak BAC (pure client)
            pcall(function() root.Anchored = true end)
        end
    else
        SupportState.lockedCFrame = nil
        local char = Service.LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            pcall(function() root.Anchored = false end)
        end
    end
end

-- Bypass Radar
SupportState.setBypassRadar = function(state)
    if Remote.fishingRadar then
        pcall(function() Remote.fishingRadar:InvokeServer(state) end)
    end
end

-- Auto Equip Diving Gear
SupportState.setAutoEquipDivingGear = function(state)
    local diveData = Data.ItemUtility.GetItemDataFromItemType("Gears", "Diving Gear")
    if not diveData then return end
    local itemId = diveData.Data and diveData.Data.Id
    if not itemId then return end

    local currentEquipped = Data.Player:Get("EquippedOxygenTankId")
    if state then
        if currentEquipped ~= itemId then
            pcall(function() Remote.equipOxygen:InvokeServer(itemId) end)
        end
    else
        if currentEquipped == itemId then
            pcall(function() Remote.unequipOxygen:InvokeServer() end)
        end
    end
end

-- Disable Fishing Animation
SupportState.setNoFishingAnimation = function(state)
    SupportState.noFishAnimActive = state
    pcall(function()
        local AnimCtrl = require(Service.ReplicatedStorage.Controllers.AnimationController)
        if state then
            AnimCtrl:DestroyActiveAnimationTracks()
        end
    end)
end

-- patch AnimController untuk Disable Fishing Animation (jalan bersama V2)
SupportState.ensureAnimPatch = function()
    if SupportState.animCtrlPatched then return end
    SupportState.animCtrlPatched = true
    local AnimCtrl = require(Service.ReplicatedStorage.Controllers.AnimationController)
    local orig = AnimCtrl.PlayAnimation
    local FISHING_ANIMS = {
        StartRodCharge=true, LoopedRodCharge=true, RodThrow=true,
        ReelStart=true, ReelIntermission=true, FishCaught=true,
        FishingFailure=true, EquipIdle=true, EquipIdleFake=true,
        ReelingIdle=true, HoldFish1=true, HoldFish2=true, HoldFish3=true
    }
    AnimCtrl.PlayAnimation = function(self, name, ...)
        -- Disable Fishing Animation: block BEFORE orig runs
        if SupportState.noFishAnimActive and FISHING_ANIMS[name] then
            return nil, nil, nil
        end
        local track, b, c = orig(self, name, ...)
        -- V2 AdjustSpeed FishCaught
        if FishingModes.V2.SnapReel and track and name == "FishCaught" then
            pcall(function() track:AdjustSpeed(3) end)
        end
        return track, b, c
    end
end
SupportState.ensureAnimPatch()

-- ====== UI (NEW LIBRARY) ======

-- ====== CONSTANTS ======
Catalog.EventList = {
    "Admin - 1x1x1 Rage",
    "Admin - 2025 Anniversary",
    "Admin - 2025 Christmas",
    "Admin - 2026 Valentines",
    "Admin - 3RR0R 3V3NT",
    "Admin - Bermuda Triangle",
    "Admin - Black Hole",
    "Admin - Bloodmoon",
    "Admin - Frostmoon",
    "Admin - Ghost Worm",
    "Admin - Leviathan Awakening",
    "Admin - Meteor Rain",
    "Admin - Purple Bloodmoon",
    "Admin - Volcano Eruption",
    "Dark Megalodon Hunt",
    "Glacial Serpent Hunt",
    "Megalodon Hunt",
    "Thunderzilla Hunt",
}

Catalog.TotemList = {
    "Abyssal Totem",
    "Cosmic Totem",
    "Easter Totem",
    "Love Totem",
    "Luck Totem",
    "Mutation Totem",
    "Noob Totem",
    "Shiny Totem",
    "Super Cosmic Totem",
    "Super Easter Totem",
    "Super Love Totem"
}

UI.Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/KnullXDgt/Orvion-UI-Library-Gen2/main/source.luau?t=" .. os.time()
))()
UI.execName = "Unknown"
pcall(function() UI.execName = getexecutorname() end)

-- ====== PING TIMER UI ======
local function createPingUI()
    local UIS = game:GetService("UserInputService")
    local pingGui = Instance.new("ScreenGui")
    pingGui.Name = "PingTimerUI"
    pingGui.ResetOnSpawn = false
    pingGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pingGui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
    UI.pingGui = pingGui

    local frame = Instance.new("Frame", pingGui)
    frame.Size = UDim2.new(0, 220, 0, 40)
    frame.Position = UDim2.new(0.015, 0, 0.165, 0)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    frame.BackgroundTransparency = 0.15
    frame.BorderSizePixel = 0
    frame.Active = true
    Instance.new("UICorner", frame).CornerRadius = UDim.new(1, 0)

    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 18
    label.Text = "Ping: -- ms | 0:00:00"
    UI.pingLabel = label

    local dragging, dragStart, startPos = false, nil, nil
    pcall(function() frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = frame.Position
        end
    end) end)
    pcall(function() UIS.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end) end)
    pcall(function() UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end) end)
end

UI.Window = UI.Library:CreateWindow({
    Title          = "Orvion Hub",
    Icon           = "rbxassetid://95126399202412",
    TitleImage     = "rbxassetid://138517423977481",
    Subtitle       = "",
    Badges         = {"v0.1", "Executor: " .. UI.execName},
    Center       = true,
    Draggable    = true,
    Resizable    = true,
    ToggleButton = true,
    ConfigFolder = "OrvionFishIt",
})

-- ====== FISHING TAB ======
-- ====== INFO TAB ======
UI.InfoTab = UI.Window:CreateTab("Info", "rbxassetid://94529541997278")
UI.Window:AddWelcomeCard(UI.InfoTab)
UI.InfoSection = UI.Window:AddCollapsible(UI.InfoTab, "Information", true)
UI.Window:AddParagraph(UI.InfoSection, "What is Orvion Hub?", "Orvion Hub is a reflection of my coding journey  built through trial, error, and a lot of iteration. It shows how much I have grown as a developer, and how much I still have left to learn.\nLowkey started this just for myself, no cap. Somewhere along the way it turned into something worth sharing.")

UI.FishingTab = UI.Window:CreateTab("Main", "rbxassetid://117906088481880")

UI.SupportSection = UI.Window:AddCollapsible(UI.FishingTab, "Support Features", false)

UI.Window:AddToggle(UI.SupportSection, "Show Real-Ping", "", false, function(state)
    if state then
        if UI.pingTimerThread then pcall(task.cancel, UI.pingTimerThread) UI.pingTimerThread = nil end
        createPingUI()
        local startTime = os.time()
        UI.pingTimerThread = task.spawn(function()
            while UI.pingGui and UI.pingGui.Parent do
                task.wait(1)
                local ok, ping = pcall(function()
                    return math.floor(Service.Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
                end)
                local p = ok and ping or 0
                local elapsed = os.time() - startTime
                local h = math.floor(elapsed / 3600)
                local m = math.floor((elapsed % 3600) / 60)
                local s = elapsed % 60
                if UI.pingLabel then
                    UI.pingLabel.Text = string.format("Ping: %d ms | %d:%02d:%02d", p, h, m, s)
                end
            end
        end)
    else
        if UI.pingTimerThread then pcall(task.cancel, UI.pingTimerThread) UI.pingTimerThread = nil end
        if UI.pingGui then pcall(function() UI.pingGui:Destroy() end) UI.pingGui = nil UI.pingLabel = nil end
    end
end, "Toggle_Show Real-Ping")
UI.Window:AddToggle(UI.SupportSection, "Disable Obtained Fish", "", false, function(state)
    Config.DisableFishNotif = state
    SupportState.updateBigPopup()
end, "Toggle_Disable Obtained Fish")

UI.Window:AddToggle(UI.SupportSection, "Disable Fishing Animation", "", false, function(state)
    SupportState.setNoFishingAnimation(state)
end, "Toggle_Disable Fishing Animation")

UI.Window:AddToggle(UI.SupportSection, "Disable Cutscenes", "", false, function(state)
    SupportState.setDisableCutscenes(state)
end, "Toggle_Disable Cutscenes")

UI.Window:AddToggle(UI.SupportSection, "Disable Skin Effect", "", false, function(state)
    SupportState.setDisableSkinEffect(state)
end, "Toggle_Disable Skin Effect")

UI.Window:AddToggle(UI.SupportSection, "Disable Ability VFX", "", false, function(state)
    SupportState.setDisableAbilityVFX(state)
end, "Toggle_Disable Ability VFX")

UI.Window:AddToggle(UI.SupportSection, "Disable Weather VFX", "", false, function(state)
    SupportState.setDisableWeatherVFX(state)
end, "Toggle_Disable Weather VFX")

UI.Window:AddToggle(UI.SupportSection, "Auto Equip Rod", "", false, function(state)
    SupportState.setAutoEquipRod(state)
end, "Toggle_Auto Equip Rod")

UI.Window:AddToggle(UI.SupportSection, "Hide Other Players", "", false, function(state)
    SupportState.setHideOtherPlayers(state)
end, "Toggle_Hide Other Players")

UI.Window:AddToggle(UI.SupportSection, "Walk On Water", "", false, function(state)
    SupportState.setWalkOnWater(state)
end, "Toggle_Walk On Water")

UI.Window:AddToggle(UI.SupportSection, "Bypass Radar", "", false, function(state)
    SupportState.setBypassRadar(state)
end, "Toggle_Bypass Radar")

UI.Window:AddToggle(UI.SupportSection, "Auto Equip Diving Gear", "", false, function(state)
    SupportState.setAutoEquipDivingGear(state)
end, "Toggle_Auto Equip Diving Gear")

UI.Window:AddToggle(UI.SupportSection, "Lock Position", "", false, function(state)
    SupportState.setLockPosition(state)
end, "Toggle_Lock Position")
UI.Window:AddToggle(UI.SupportSection, "Anti AFK", "", true, function(state)
    if state then
        if getconnections then
            for _, connection in pairs(getconnections(Service.LocalPlayer.Idled)) do
                pcall(function() connection:Disable() end)
            end
        end
    else
        if getconnections then
            for _, connection in pairs(getconnections(Service.LocalPlayer.Idled)) do
                pcall(function() connection:Enable() end)
            end
        end
    end
end)
-- Instant Fishing v1
UI.FishingSection = UI.Window:AddCollapsible(UI.FishingTab, "Instant Fishing", false)

UI.Window:AddInput(UI.FishingSection, "Delay Complete", "", "Write your input here...", function(v)
    local n = tonumber(v)
    if n and n >= 0 then Config.CastWait = n end
end, "Input_Delay Complete")

UI.Window:AddToggle(UI.FishingSection, "Instant Fishing", "", false, function(state)
    Config.InstantFishing = state
    if state then FishingModes.V1.Start() else FishingModes.V1.Stop() end
end, "Toggle_Instant Fishing")

-- Instant Fishing v2
UI.FishingV2Section = UI.Window:AddCollapsible(UI.FishingTab, "Instant Fishing V2", false)

UI.Window:AddInput(UI.FishingV2Section, "Delay Complete V2", "", "Write your input here...", function(v)
    local n = tonumber(v)
    if n and n >= 0 then FishingModes.V2.Delay = n end
end, "Input_Delay Complete V2")

UI.Window:AddToggle(UI.FishingV2Section, "Instant Fishing V2", "", false, function(state)
    FishingModes.V2.Active = state
    if state then FishingModes.V2.Start() else FishingModes.V2.Stop() end
end, "Toggle_Instant Fishing v2")

-- Blatant (Visual)
UI.BlatantSection = UI.Window:AddCollapsible(UI.FishingTab, "Blatant (Visual)", false)
UI.Window:AddInput(UI.BlatantSection, "Delay Blatant", "", "Write your input here...", function(v)
    local n = tonumber(v)
    if n and n >= 0 then Config.BlatantDelay = n end
end, "Input_Blatant Delay")
UI.Window:AddToggle(UI.BlatantSection, "Blatant (Visual)", "", false, function(state)
    Config.BlatantActive = state
    if state then FishingModes.Blatant.Start() else FishingModes.Blatant.Stop() end
end, "Toggle_Blatant Visual")

-- Stable Results
UI.StableSection = UI.Window:AddCollapsible(UI.FishingTab, "Stable Results", false)

UI.Window:AddToggle(UI.StableSection, "Stable Result", "", false, function(state)
    if Remote.updateAutoFishing then
        pcall(function()
            if state then
                Runtime.StableResult = true
                Remote.updateAutoFishing:InvokeServer(true)
                if Remote.markAutoFishing then
                    pcall(function() Remote.markAutoFishing:InvokeServer() end)
                end
            else
                Runtime.StableResult = false
                Remote.updateAutoFishing:InvokeServer(false)
                pcall(function() Remote.cancel:InvokeServer(true) end)
            end
        end)
    end
end, "Toggle_Stable Result")

UI.Window:AddToggle(UI.StableSection, "Random Results", "", false, function(state)
    Config.RandomResults = state
end, "Toggle_Random Results")

UI.Window:AddToggle(UI.StableSection, "Auto Perfect", "", false, function(state)
    Config.PerfectCast = state
end, "Toggle_Auto Perfect")

-- ====== SELL FEATURES (under Main tab) ======
UI.SellSection = UI.Window:AddCollapsible(UI.FishingTab, "Sell Features", false)

UI.Window:AddDropdown(UI.SellSection, "Select Sell Mode", "", {"Delay", "Count"}, false, "Delay", function(value)
    Config.AutoSellMode = value
    if not Runtime.Sell.Busy then Runtime.Sell.Pending = false end
    Runtime.Sell.CountSeen = -1
    Runtime.Sell.Revision = Runtime.Sell.Revision + 1
end, "Dropdown_Sell Mode")

UI.Window:AddInput(UI.SellSection, "Set Value", "", "Write your input here...", function(v)
    local n = tonumber(v)
    if n and n >= 1 then
        Config.SellDelay = n
        Config.SellCount = n
        if not Runtime.Sell.Busy then Runtime.Sell.Pending = false end
        Runtime.Sell.CountSeen = -1
        Runtime.Sell.Revision = Runtime.Sell.Revision + 1
    end
end, "Input_Sell Delay")

UI.Window:AddToggle(UI.SellSection, "Start Sell", "", false, function(state)
    Config.AutoSell = state
    if state then Runtime.Sell.Start() else Runtime.Sell.Stop() end
end, "Toggle_Auto Sell")

UI.Window:AddButton(UI.SellSection, "Sell All Now", "", "rbxassetid://16932740082", function()
    Runtime.Sell.Queue("Manual")
    UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="Sold!", Color=Color3.fromRGB(150,150,170), Delay=2 })
end)

-- ====== TELEPORT TAB ======

-- ====== EVENT TELEPORT LOGIC ======
Navigation.stopEventWalkOnWater = function()
    if Navigation.eventWaterConn then Navigation.eventWaterConn:Disconnect(); Navigation.eventWaterConn = nil end
    if Navigation.eventWaterCharConn then Navigation.eventWaterCharConn:Disconnect(); Navigation.eventWaterCharConn = nil end
    if Navigation.eventWaterPlatform then Navigation.eventWaterPlatform:Destroy(); Navigation.eventWaterPlatform = nil end
    local char = Service.LocalPlayer.Character
    local hum = char and char:FindFirstChildWhichIsA("Humanoid")
    if hum then pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, true) end) end
end

Navigation.startEventWalkOnWater = function()
    Navigation.stopEventWalkOnWater()
    Navigation.eventWaterPlatform = Instance.new("Part")
    Navigation.eventWaterPlatform.Anchored = true
    Navigation.eventWaterPlatform.CanCollide = false
    Navigation.eventWaterPlatform.Transparency = 1
    Navigation.eventWaterPlatform.Size = Vector3.new(10, 0.5, 10)
    Navigation.eventWaterPlatform.CFrame = CFrame.new(0, -9999, 0)
    Navigation.eventWaterPlatform.Parent = workspace

    local function attachEventChar(char)
        local hum = char:FindFirstChildWhichIsA("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        if not hum or not root then return end
        local terrain = workspace:FindFirstChildWhichIsA("Terrain")
        local inWater = false
        local waterSurfaceY = nil
        pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, false) end)

        local function getWaterSurfaceY(pos)
            local rp = RaycastParams.new()
            rp.FilterType = Enum.RaycastFilterType.Include
            rp.FilterDescendantsInstances = {terrain}
            local res = workspace:Raycast(Vector3.new(pos.X, pos.Y + 10, pos.Z), Vector3.new(0, -20, 0), rp)
            if res and res.Material == Enum.Material.Water then return res.Position.Y end
            return nil
        end

        local function checkWaterAt(pos)
            local ok, isWater = pcall(function()
                local vox = terrain:ReadVoxels(Region3.new(pos, pos + Vector3.new(0.1,0.1,0.1)):ExpandToGrid(4), 4)
                return vox and vox[1] and vox[1][1] and vox[1][1][1] == Enum.Material.Water
            end)
            return ok and isWater or false
        end

        if Navigation.eventWaterConn then Navigation.eventWaterConn:Disconnect() end
        Navigation.eventWaterConn = Service.RunService.Stepped:Connect(function()
            if not root.Parent then return end
            local pos = root.Position
            local feetPos = pos - Vector3.new(0, 3, 0)
            local isWaterNow = checkWaterAt(feetPos)
            if isWaterNow and not inWater then
                inWater = true
                waterSurfaceY = getWaterSurfaceY(pos) or (pos.Y - 2)
                Navigation.eventWaterPlatform.CFrame = CFrame.new(pos.X, waterSurfaceY, pos.Z)
                Navigation.eventWaterPlatform.CanCollide = true
                pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, false) end)
            elseif not isWaterNow and inWater then
                inWater = false
                waterSurfaceY = nil
                Navigation.eventWaterPlatform.CanCollide = false
                Navigation.eventWaterPlatform.CFrame = CFrame.new(0, -9999, 0)
                pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, true) end)
            end
            if inWater and waterSurfaceY then
                Navigation.eventWaterPlatform.CFrame = CFrame.new(pos.X, waterSurfaceY, pos.Z)
            end
        end)
    end

    local char = Service.LocalPlayer.Character
    if char then attachEventChar(char) end
    Navigation.eventWaterCharConn = Service.LocalPlayer.CharacterAdded:Connect(attachEventChar)
end

Navigation.findEventPosition = function(eventName)
    -- 1. EventSpawnLocations (exact, works for Thunderzilla too)
    if not Data.Events then
        pcall(function() Data.Events = Data.Replion.Client:WaitReplion("Events") end)
    end
    local pos = nil
    pcall(function()
        if Data.Events then
            local locs = Data.Events:GetExpect("EventSpawnLocations")
            if locs and locs[eventName] then pos = locs[eventName] end
        end
    end)
    if pos then return pos end
    -- 2. Fallback: workspace exact match (admin events)
    local lowerName = eventName:lower()
    local stripped = lowerName:gsub("%s*hunt%s*$", "")
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") then
            local n = obj.Name:lower()
            if n == lowerName or n == stripped then return obj:GetPivot().Position end
        end
    end
    return nil
end


UI.TpTab = UI.Window:CreateTab("Teleport", "rbxassetid://6723742952")
UI.TpSection = UI.Window:AddCollapsible(UI.TpTab, "Teleport to Island", false)

UI.Window:AddDropdown(UI.TpSection, "Select Island", "", Catalog.LocationNames, false, "Ancient Jungle", function(value)
    Config.TeleportLocation = value
end, "Dropdown_Select Map")

UI.Window:AddButton(UI.TpSection, "Teleport", "", "", function()
    Navigation.teleportTo(Config.TeleportLocation)
    UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="Teleported to " .. Config.TeleportLocation, Color=Color3.fromRGB(150,150,170), Delay=2 })
end)


-- Teleport to Event
Navigation.getBestEventPos = function()
    local priority = Config.PriorityEvent
    local selectEv = Config.SelectEvent
    if priority and priority ~= "Select Option" then
        local pos = Navigation.findEventPosition(priority)
        if pos then return pos, "priority" end
    end
    if selectEv and selectEv ~= "Select Option" then
        local pos = Navigation.findEventPosition(selectEv)
        if pos then return pos, "select" end
    end
    return nil, nil
end

UI.TpEventSection = UI.Window:AddCollapsible(UI.TpTab, "Teleport to Event", false)




















UI.Window:AddDropdown(UI.TpEventSection, "Priority Event", "", Catalog.EventList, false, "Select Option", function(value)
    Config.PriorityEvent = value
    if Navigation.eventTeleportActive then
        local pos = Navigation.getBestEventPos()
        if pos then
            pcall(function()
                local ch = Service.LocalPlayer.Character
                local rt = ch and ch:FindFirstChild("HumanoidRootPart")
                if rt then rt.CFrame = CFrame.new(pos + Vector3.new(0, 6, 0)) end
            end)
            Navigation.startEventWalkOnWater()
        end
    end
end)
UI.Window:AddDropdown(UI.TpEventSection, "Select Event", "", Catalog.EventList, false, "Select Option", function(value)
    Config.SelectEvent = value
    if Navigation.eventTeleportActive then
        local pos = Navigation.getBestEventPos()
        if pos then
            pcall(function()
                local ch = Service.LocalPlayer.Character
                local rt = ch and ch:FindFirstChild("HumanoidRootPart")
                if rt then rt.CFrame = CFrame.new(pos + Vector3.new(0, 6, 0)) end
            end)
            Navigation.startEventWalkOnWater()
        end
    end
end)
UI.Window:AddToggle(UI.TpEventSection, "Start Auto Event", "", false, function(state)
    if state then
        local char = Service.LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        Navigation.preEventCFrame = root.CFrame
        Navigation.eventTeleportActive = true
        local initPos, initSource = Navigation.getBestEventPos()
        local wasFound = initPos ~= nil
        local currentSource = initSource
        if initPos then
            pcall(function() root.CFrame = CFrame.new(initPos + Vector3.new(0, 6, 0)) end)
            Navigation.startEventWalkOnWater()
        end
        Navigation.eventWatcherConn = workspace.DescendantRemoving:Connect(function(removed)
            if not Navigation.eventTeleportActive or not wasFound then return end
            if not removed:IsA("Model") then return end
            local eventName = (currentSource == "priority") and Config.PriorityEvent or Config.SelectEvent
            if not eventName or eventName == "Select Option" then return end
            local lowerName = eventName:lower()
            local strippedName = lowerName:gsub("%s*hunt%s*$", "")
            local removedLower = removed.Name:lower()
            if removedLower ~= lowerName and removedLower ~= strippedName then return end
            task.defer(function()
                    if not Navigation.eventTeleportActive then return end
                    local pos, source = Navigation.getBestEventPos()
                    if pos then
                        if currentSource ~= source then
                            wasFound = true
                            currentSource = source
                            pcall(function()
                                local ch = Service.LocalPlayer.Character
                                local rt = ch and ch:FindFirstChild("HumanoidRootPart")
                                if rt then rt.CFrame = CFrame.new(pos + Vector3.new(0, 6, 0)) end
                            end)
                            Navigation.startEventWalkOnWater()
                        end
                    else
                        wasFound = false
                        currentSource = nil
                        Navigation.stopEventWalkOnWater()
                        if Navigation.preEventCFrame then
                            pcall(function()
                                local ch = Service.LocalPlayer.Character
                                local rt = ch and ch:FindFirstChild("HumanoidRootPart")
                                if rt then rt.CFrame = Navigation.preEventCFrame end
                            end)
                        end
                    end
                end)
        end)
        task.spawn(function()
            while Navigation.eventTeleportActive do
                task.wait(2)
                if not Navigation.eventTeleportActive then break end
                local pos, source = Navigation.getBestEventPos()
                if pos then
                    if not wasFound or currentSource ~= source then
                        wasFound = true
                        currentSource = source
                        pcall(function()
                            local ch = Service.LocalPlayer.Character
                            local rt = ch and ch:FindFirstChild("HumanoidRootPart")
                            if rt then rt.CFrame = CFrame.new(pos + Vector3.new(0, 6, 0)) end
                        end)
                        Navigation.startEventWalkOnWater()
                    end
                else
                    if wasFound then
                        wasFound = false
                        currentSource = nil
                        Navigation.stopEventWalkOnWater()
                        if Navigation.preEventCFrame then
                            pcall(function()
                                local ch = Service.LocalPlayer.Character
                                local rt = ch and ch:FindFirstChild("HumanoidRootPart")
                                if rt then rt.CFrame = Navigation.preEventCFrame end
                            end)
                        end
                    end
                end
            end
        end)
    else
        Navigation.eventTeleportActive = false
        if Navigation.eventWatcherConn then Navigation.eventWatcherConn:Disconnect(); Navigation.eventWatcherConn = nil end
        Navigation.stopEventWalkOnWater()
        if Navigation.preEventCFrame then
            pcall(function()
                local char = Service.LocalPlayer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root then root.CFrame = Navigation.preEventCFrame end
            end)
            Navigation.preEventCFrame = nil
        end
    end
end, "Toggle_Start Auto Event")



-- Teleport to NPC
UI.TpNpcSection = UI.Window:AddCollapsible(UI.TpTab, "Teleport to NPC", false)
Navigation.npcInitList = Navigation.getNPCNames()
UI.SelectNpcDropdown = UI.Window:AddDropdown(UI.TpNpcSection, "Select NPC", "", Navigation.npcInitList, false, Navigation.npcInitList[1] or "Select NPC", function(value)
    Config.TeleportNPC = value
end, "Dropdown_Select NPC")
UI.Window:AddButtonGrid(UI.TpNpcSection,
    { Title = "Teleport", Callback = function()
    local name = Config.TeleportNPC
    if not name or name == "" then return end
    local teleported = false
    pcall(function()
        local char = Service.LocalPlayer.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local npcFolder = workspace:FindFirstChild("NPC")
        if not npcFolder then return end
        for _, model in ipairs(npcFolder:GetChildren()) do
            if model:IsA("Model") and model.Name == name then
                root.CFrame = model:GetPivot() * CFrame.new(0, 0, 4)
                teleported = true
                return
            end
        end

    end)
    if teleported then
        UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="Teleported to " .. name, Color=Color3.fromRGB(150,150,170), Delay=2 })
    else
        UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="NPC not found: " .. name, Color=Color3.fromRGB(150,150,170), Delay=2 })
    end
    end},
    { Title = "Refresh", Callback = function()
        local nl = Navigation.getNPCNames()
        UI.SelectNpcDropdown:Refresh(nl, nl[1] or "Select NPC")
        UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="Refreshed " .. #nl .. " NPCs!", Color=Color3.fromRGB(150,150,170), Delay=2 })
    end}
)

-- Teleport to Player
UI.TpPlayerSection = UI.Window:AddCollapsible(UI.TpTab, "Teleport to Player", false)
UI.SelectPlayerDropdown = UI.Window:AddDropdown(UI.TpPlayerSection, "Pick Player", "", Navigation.getPlayerList(), false, "Select Option", function(value)
    Config.TeleportPlayer = value
end)
UI.Window:AddButtonGrid(UI.TpPlayerSection,
    { Title = "Teleport", Callback = function()
        local target = Config.TeleportPlayer
        if not target or target == "" then return end
        pcall(function()
            local char = Service.LocalPlayer.Character
            if not char then return end
            local root = char:FindFirstChild("HumanoidRootPart")
            if not root then return end
            local tp = Service.Players:FindFirstChild(target)
            if not tp then return end
            local tc = tp.Character
            if not tc then return end
            local tr = tc:FindFirstChild("HumanoidRootPart")
            if not tr then return end
            root.CFrame = tr.CFrame + Vector3.new(3, 0, 0)
        end)
        UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="Teleported to " .. tostring(Config.TeleportPlayer), Color=Color3.fromRGB(150,150,170), Delay=2 })
    end},
    { Title = "Refresh", Callback = function()
        local pl = Navigation.getPlayerList(); UI.SelectPlayerDropdown:Refresh(pl, pl[1] or "Select Player")
    end}
)

-- Saved Location
UI.SavedLocSection = UI.Window:AddCollapsible(UI.TpTab, "Saved Location", false)
UI.Window:AddButton(UI.SavedLocSection, "Save Current Location", "", "rbxassetid://16932740082", function()
    local ok = Navigation.saveCurrentLocation()
    local msg = ok and "Location saved!" or "Failed to save location."
    UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content=msg, Color=Color3.fromRGB(150,150,170), Delay=2 })
end)
UI.Window:AddButton(UI.SavedLocSection, "Teleport to Saved", "", "rbxassetid://16932740082", function()
    local ok, result = pcall(Navigation.teleportToSaved)
    local msg = (ok and result) and "Teleported to saved!" or "No saved location."
    UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content=msg, Color=Color3.fromRGB(150,150,170), Delay=2 })
end)
UI.Window:AddButton(UI.SavedLocSection, "Reset Saved Location", "", "rbxassetid://16932740082", function()
    pcall(function()
        if isfile(Catalog.SavedLocationFile) then delfile(Catalog.SavedLocationFile) end
    end)
    UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="Saved location cleared.", Color=Color3.fromRGB(150,150,170), Delay=2 })
end)
UI.Window:AddToggle(UI.SavedLocSection, "Auto Teleport on Spawn", "", false, function(state)
    Navigation.setAutoTeleportOnSpawn(state)
end, "Toggle_Auto Teleport on Spawn")


-- ====== SHOP: AUTO BUY WEATHER ======
S.WEATHER_LIST = {"Fog", "Radiant", "Storm", "Treasure Hunt", "Wind"}
S.weatherWatchConn = nil
S.weatherWorker = nil
S.weatherQueue = {}
S.weatherQueued = {}
S.weatherGeneration = 0

S.stopWeatherWatcher = function()
    S.weatherGeneration = S.weatherGeneration + 1
    if S.weatherWatchConn then
        pcall(function() S.weatherWatchConn:Disconnect() end)
        S.weatherWatchConn = nil
    end
    if S.weatherWorker then
        pcall(task.cancel, S.weatherWorker)
        S.weatherWorker = nil
    end
    table.clear(S.weatherQueue)
    table.clear(S.weatherQueued)
    Config.BuyWeatherActive = false
end

S.buyWeatherEvent = function(eventName, silent)
    local ok, result = pcall(function()
        return Remote.weatherPurchase:InvokeServer(eventName)
    end)
    if ok and result == true then
        if not silent then
            UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content=eventName, Color=Color3.fromRGB(150,150,170), Delay=3 })
        end
        return true
    end
    return false
end

S.enqueueWeather = function(eventName)
    if not Config.BuyWeatherActive then return end
    if not table.find(Config.SelectedWeatherEvents, eventName) then return end
    if S.weatherQueued[eventName] then return end
    S.weatherQueued[eventName] = true
    table.insert(S.weatherQueue, eventName)
    if S.weatherWorker then return end

    local generation = S.weatherGeneration
    S.weatherWorker = task.spawn(function()
        while Config.BuyWeatherActive
            and generation == S.weatherGeneration
            and #S.weatherQueue > 0
        do
            local eventName = table.remove(S.weatherQueue, 1)

            while Runtime.Sell.Busy and Config.BuyWeatherActive
                and generation == S.weatherGeneration
            do
                task.wait(0.1)
            end

            local success = false
            for attempt = 1, 2 do
                if not Config.BuyWeatherActive
                    or generation ~= S.weatherGeneration
                then
                    break
                end
                success = S.buyWeatherEvent(eventName, attempt == 1)
                if success then break end
                task.wait(1.5)
            end

            S.weatherQueued[eventName] = nil
            task.wait(0.35)
        end
        if generation == S.weatherGeneration then
            S.weatherWorker = nil
        end
    end)
end

S.startWeatherWatcher = function()
    if S.weatherWatchConn then
        pcall(function() S.weatherWatchConn:Disconnect() end)
        S.weatherWatchConn = nil
    end
    if S.weatherWorker then
        pcall(task.cancel, S.weatherWorker)
        S.weatherWorker = nil
    end
    table.clear(S.weatherQueue)
    table.clear(S.weatherQueued)
    S.weatherGeneration = S.weatherGeneration + 1
    Config.BuyWeatherActive = true

    -- Lazy-load Data.Events
    if not Data.Events then
        pcall(function()
            Data.Events = Data.Replion.Client:WaitReplion("Events")
        end)
    end
    if not Data.Events then return end
    -- Connect watcher langsung (jangan terlambat detect event selesai)
    S.weatherWatchConn = Data.Events:OnArrayRemove("WeatherMachine", function(_, removedEvent)
        if not Config.BuyWeatherActive then return end
        if not table.find(Config.SelectedWeatherEvents, removedEvent) then return end
        S.enqueueWeather(removedEvent)
    end)
    -- Initial buy di-defer: tunggu dropdown autoload selesai dulu
    task.defer(function()
        if not Config.BuyWeatherActive then return end
        local activeList = {}
        pcall(function() activeList = Data.Events:GetExpect("WeatherMachine") or {} end)
        for _, ev in ipairs(Config.SelectedWeatherEvents) do
            if not Config.BuyWeatherActive then break end
            if ev ~= "Select Option" and not table.find(activeList, ev) then
                S.enqueueWeather(ev)
            end
        end
    end)
end

UI.AutomationTab = UI.Window:CreateTab("Automation", "rbxassetid://102105242487044")

S.WeatherSection = UI.Window:AddCollapsible(UI.AutomationTab, "Weather Features", false)

UI.Window:AddDropdown(S.WeatherSection, "Select Weather", "", S.WEATHER_LIST, 3, {}, function(selected)
    Config.SelectedWeatherEvents = {}
    if type(selected) == "table" then
        for i = 1, math.min(#selected, 3) do
            table.insert(Config.SelectedWeatherEvents, selected[i])
        end
    end
end, "Dropdown_Select Weather")

UI.Window:AddToggle(S.WeatherSection, "Buy Weather", "", false, function(state)
    Config.BuyWeatherActive = state
    if state then
        S.startWeatherWatcher()
    else
        S.stopWeatherWatcher()
    end
end, "Toggle_Buy Weather")

S.TotemSection = UI.Window:AddCollapsible(UI.AutomationTab, "Totem Features", false)














S.autoSpawnThread = nil
S.totemWatchConn = nil
S.totemCreatedConn = nil
S.totemDistMonitor = nil
S.totemWorldPos = nil  -- posisi totem aktif di world

-- listen RE/TotemSpawned untuk dapat posisi totem
if Remote.totemSpawned then
    Remote.totemSpawned.OnClientEvent:Connect(function(pos)
        S.totemWorldPos = pos
    end)
end

S.findTotemUUID = function(totemName)
    local uuid = nil
    pcall(function()
        local inv = Data.Player:GetExpect("Inventory")
        for catName, items in pairs(inv) do
            if type(items) == "table" then
                for _, item in pairs(items) do
                    if type(item) == "table" and item.UUID and item.Id then
                        local ok2, data = pcall(Data.ItemUtility.GetItemDataFromItemType, catName, item.Id)
                        if ok2 and data and data.Data then
                            local name = tostring(data.Data.Name or "")
                            if name == totemName then
                                uuid = item.UUID
                                return
                            end
                        end
                    end
                end
            end
        end
    end)
    return uuid
end

S.spawnTotem = nil -- forward declare

S.scheduleRespawn = function()
    if not Config.AutoSpawnTotem then return end
    if S.totemWatchConn then S.totemWatchConn:Disconnect(); S.totemWatchConn = nil end
    if S.totemCreatedConn then S.totemCreatedConn:Disconnect(); S.totemCreatedConn = nil end
    if S.autoSpawnThread then pcall(task.cancel, S.autoSpawnThread); S.autoSpawnThread = nil end

    if Remote.totemCreated then
        S.totemCreatedConn = Remote.totemCreated.OnClientEvent:Connect(function(model, totemId)
            -- filter: hanya model yang di-spawn oleh kita (cek posisi dekat player)
            if not model then return end
            local root = Service.LocalPlayer.Character and Service.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local ok, pivot = pcall(function() return model:GetPivot() end)
                if ok and pivot then
                    local dist = (pivot.Position - root.Position).Magnitude
                    if dist > 50 then return end  -- bukan totem kita
                end
            end
            if S.totemCreatedConn then S.totemCreatedConn:Disconnect(); S.totemCreatedConn = nil end
            if S.autoSpawnThread then pcall(task.cancel, S.autoSpawnThread); S.autoSpawnThread = nil end
            S.totemWatchConn = model.AncestryChanged:Connect(function()
                if model.Parent ~= nil then return end
                if S.totemWatchConn then S.totemWatchConn:Disconnect(); S.totemWatchConn = nil end
                if Config.AutoSpawnTotem then
                    task.wait(2)
                    S.spawnTotem()
                end
            end)

            -- monitor jarak: jika player jauh > 100 studs dari totem -> re-spawn
            if S.totemDistMonitor then pcall(task.cancel, S.totemDistMonitor); S.totemDistMonitor = nil end
            S.totemDistMonitor = task.spawn(function()
                while Config.AutoSpawnTotem and model.Parent ~= nil do
                    task.wait(10)
                    if not Config.AutoSpawnTotem or model.Parent == nil then break end
                    if S.totemWorldPos then
                        local root = Service.LocalPlayer.Character and Service.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        if root then
                            local dist = (S.totemWorldPos - root.Position).Magnitude
                            if dist > 100 then
                                -- player jauh -> disconnect watcher lama, re-spawn
                                if S.totemWatchConn then S.totemWatchConn:Disconnect(); S.totemWatchConn = nil end
                                S.totemDistMonitor = nil
                                task.wait(1)
                                S.spawnTotem()
                                break
                            end
                        end
                    end
                end
            end)
        end)
    end
end

S.spawnTotem = function(isManual)
    local totemName = Config.SelectedTotem
    if not totemName or totemName == "" then return false end
    local uuid = S.findTotemUUID(totemName)
    if not uuid then
        UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="Not found in inventory", Color=Color3.fromRGB(150,150,170), Delay=3 })
        return false
    end
    local rf = Remote.spawnTotem
    if not rf then return false end
    local ok = pcall(function() rf:FireServer(uuid) end)
    if ok then
        if isManual then
            UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content=totemName .. " spawned", Color=Color3.fromRGB(150,150,170), Delay=3 })
        end
        if Config.AutoSpawnTotem then S.scheduleRespawn() end
        return true
    end
    return false
end

S.stopAutoSpawn = function()
    if S.autoSpawnThread then pcall(task.cancel, S.autoSpawnThread); S.autoSpawnThread = nil end
    if S.totemWatchConn then S.totemWatchConn:Disconnect(); S.totemWatchConn = nil end
    if S.totemCreatedConn then S.totemCreatedConn:Disconnect(); S.totemCreatedConn = nil end
    Config.AutoSpawnTotem = false
end

S.startAutoSpawn = function()
    S.stopAutoSpawn()
    Config.AutoSpawnTotem = true
    task.spawn(S.spawnTotem)
end

UI.Window:AddDropdown(S.TotemSection, "Select Totem", "", Catalog.TotemList, false, Config.SelectedTotem, function(value)
    Config.SelectedTotem = value or "Luck Totem"
end, "Dropdown_Select Totem")

UI.Window:AddButton(S.TotemSection, "Refresh Totem List", "", "rbxassetid://16932740082", function()
    local inv = nil
    pcall(function() inv = Data.Player:Get("Inventory") end)
    if not inv or not inv.Totems then
        UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Content="Inventory not found", Color=Color3.fromRGB(150,150,170), Delay=2 })
        return
    end
    local ownedTypes = {}
    for _, item in ipairs(inv.Totems) do
        if type(item) == "table" and item.Id then ownedTypes[item.Id] = true end
    end
    local names = {}
    for typeId in pairs(ownedTypes) do
        local name = tostring(typeId)
        pcall(function()
            local d = Data.ItemUtility.GetItemDataFromItemType("Totems", typeId)
            if d and d.Data and d.Data.Name then name = d.Data.Name end
        end)
        table.insert(names, name)
    end
    local content = #names > 0 and table.concat(names, ", ") or "No totems found"
    UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Content=content, Color=Color3.fromRGB(150,150,170), Delay=4 })
end)

UI.Window:AddToggle(S.TotemSection, "Auto Spawn Totem", "", false, function(state)
    Config.AutoSpawnTotem = state
    if state then S.startAutoSpawn() else S.stopAutoSpawn() end
end, "Toggle_Auto Spawn Totem")

UI.Window:AddButton(S.TotemSection, "Spawn Now", "", "rbxassetid://16932740082", function()
    S.spawnTotem(true)
end)

-- Helper: update paragraph text, support both old (Frame) dan new (table:Set) library
S.setParagraphText = function(para, text)
    if not para then return end
    if type(para) == "table" and para.Set then
        pcall(function() para:Set(text) end)
    else
        pcall(function()
            local label = para:FindFirstChild("ParagraphContent")
            if label then label.Text = tostring(text) end
        end)
    end
end


-- ===== ENCHANT FEATURES =====
do
    local STONE_ID = {
        ["Enchant Stone"]=10,["Runic Enchant Stone"]=929,
        ["Evolved Enchant Stone"]=558,["Super Enchant Stone"]=125,
        ["Withering Stone"]=1098,["Transcended Stone"]=246,
        ["Candy Enchant Stone"]=714,["Eggy Enchant Stone"]=873,
    }
    local STONE_LIST = {
        "Enchant Stone","Runic Enchant Stone","Evolved Enchant Stone",
        "Super Enchant Stone","Withering Stone","Transcended Stone",
        "Candy Enchant Stone","Eggy Enchant Stone",
    }
    local TARGET_LIST = {
        "Big Hunter I","Big Hunter II","Blob Hunter","Cursed I","Cursed II",
        "Dynamic Duo","Easter Spirit","Empowered I","Empowered II","Empowered III",
        "FORGOTTEN Hunter","Fairy Hunter I","Fairy Hunter II","Glistening I","Glistening II",
        "Gold Digger I","Heartbreaker","Incubator","Leprechaun I","Leprechaun II",
        "Lovestruck","More Hearts","Mutation Hunter I","Mutation Hunter II","Mutation Hunter III",
        "Perfection","Prismatic I","Reeler I","Reeler II","SECRET Hunter",
        "Shark Hunter I","Shark Hunter II","Stargazer I","Stargazer II",
        "Stormhunter I","Stormhunter II","XPerienced I","XPerienced II",
    }
    local function setPara(para, title, content)
        pcall(function()
            local t = para:FindFirstChild("ParagraphTitle")
            local c = para:FindFirstChild("ParagraphContent")
            if t then t.Text = title end
            if c then c.Text = content end
        end)
    end
    local function equipAndHold(UUID, itemType)
        local eq = Data.Player:Get("EquippedItems") or {}
        local slot = table.find(eq, tostring(UUID))
        if not slot then
            if #eq >= 5 then return false end
            pcall(function() Remote.equipItem:FireServer(UUID, itemType) end)
            local dl = os.clock() + 3
            while not slot and os.clock() < dl do
                eq = Data.Player:Get("EquippedItems") or {}
                slot = table.find(eq, tostring(UUID))
                if not slot then task.wait(0.05) end
            end
        end
        if not slot then return false end
        pcall(function() Remote.equipTool:FireServer(slot) end)
        local dl2 = os.clock() + 3
        while Data.Player:Get("EquippedType") ~= itemType and os.clock() < dl2 do
            task.wait(0.05)
        end
        return Data.Player:Get("EquippedType") == itemType
    end
    local function updateEnchantPara()
        if not S.enchantPara then return end
        local rodName,e1,e2,stoneCount = "None","None","None",0
        pcall(function()
            local eq = Data.Player:Get("EquippedItems") or {}
            local equippedSet = {}
            for _,uuid in pairs(eq) do equippedSet[tostring(uuid)] = true end
            local stoneId = STONE_ID[Config.EnchantType] or 10
            local inv = Data.Player:Get("Inventory") or Data.Player.Data.Inventory
            if not inv then return end
            for cat, items in pairs(inv) do
                if type(items) ~= "table" then continue end
                for _, item in ipairs(items) do
                    local d = Data.ItemUtility.GetItemDataFromItemType(cat, item.Id)
                    if not (d and d.Data) then continue end
                    if d.Data.Type == "Fishing Rods" and equippedSet[tostring(item.UUID)] then
                        rodName = d.Data.Name or rodName
                        local meta = item.Metadata or {}
                        if meta.EnchantId then
                            local ok2,ed = pcall(function() return Data.ItemUtility:GetEnchantData(meta.EnchantId) end)
                            if ok2 and ed and ed.Data then e1 = ed.Data.Name end
                        end
                        if meta.EnchantId2 then
                            local ok3,ed = pcall(function() return Data.ItemUtility:GetEnchantData(meta.EnchantId2) end)
                            if ok3 and ed and ed.Data then e2 = ed.Data.Name end
                        end
                    end
                    if tonumber(item.Id) == tonumber(stoneId) then
                        stoneCount = stoneCount + 1
                    end
                end
            end
        end)
        setPara(S.enchantPara,"Enchant Status",
            "Current Rod: "..rodName..
            "\nEnchant 1: "..e1..
            "\nEnchant 2: "..e2..
            "\nEnchant Stones Left: "..stoneCount)
    end
    S.enchantConns = {}
    -- Shared inventory scanner (tradeui pattern)
    local function scanInventory(filterFn)
        local result = {}
        local inv = Data.Player:Get("Inventory") or Data.Player.Data.Inventory
        if not inv then return result end
        for cat, items in pairs(inv) do
            if type(items) == "table" then
                for _, item in ipairs(items) do
                    local d = Data.ItemUtility.GetItemDataFromItemType(cat, item.Id)
                    if d and d.Data then
                        local hit = filterFn(item, d)
                        if hit then table.insert(result, hit) end
                    end
                end
            end
        end
        return result
    end
    local EnchantSection = UI.Window:AddCollapsible(UI.AutomationTab,"Enchant Features",false)
    S.enchantPara = UI.Window:AddParagraph(EnchantSection,"Enchant Status","Current Rod: None\nEnchant 1: None\nEnchant 2: None\nEnchant Stones Left: 0")
    UI.Window:AddDropdown(EnchantSection,"Enchant Type","",STONE_LIST,false,"Enchant Stone",function(v)
        Config.EnchantType = v or "Enchant Stone"
        if Config.AutoEnchantReroll then updateEnchantPara() end
    end,"Dropdown_Enchant Type")
    UI.Window:AddDropdown(EnchantSection,"Target Enchant","",TARGET_LIST,false,"Select Option",function(v)
        Config.TargetEnchant = v or "Select Option"
    end,"Dropdown_Target Enchant")
    S.enchantToggle = UI.Window:AddToggle(EnchantSection,"Auto Enchant Reroll","",false,function(state)
        for _,conn in ipairs(S.enchantConns) do pcall(function() conn:Disconnect() end) end
        S.enchantConns = {}
    -- Shared inventory scanner (tradeui pattern)
    local function scanInventory(filterFn)
        local result = {}
        local inv = Data.Player:Get("Inventory") or Data.Player.Data.Inventory
        if not inv then return result end
        for cat, items in pairs(inv) do
            if type(items) == "table" then
                for _, item in ipairs(items) do
                    local d = Data.ItemUtility.GetItemDataFromItemType(cat, item.Id)
                    if d and d.Data then
                        local hit = filterFn(item, d)
                        if hit then table.insert(result, hit) end
                    end
                end
            end
        end
        return result
    end
        S.enchantPending = false
        if S.enchantThread then pcall(task.cancel,S.enchantThread) S.enchantThread = nil end
        Config.AutoEnchantReroll = state
        if not state then return end
        table.insert(S.enchantConns,Data.Player:OnChange({"Inventory","Fishing Rods"},updateEnchantPara))
        table.insert(S.enchantConns,Data.Player:OnChange({"Inventory","Enchant Stones"},updateEnchantPara))
        table.insert(S.enchantConns,Remote.enchantRoll.OnClientEvent:Connect(function(enchantId)
            local enchantName = "Unknown"
            pcall(function()
                local d = Data.ItemUtility:GetEnchantData(enchantId)
                if d and d.Data then enchantName = d.Data.Name end
            end)
            if enchantName == Config.TargetEnchant then
                pcall(function() S.enchantToggle:Set(false) end)
                UI.Library:Notify({Title="Orvion",Subtitle="Hub",Content="Got enchant: "..enchantName})
            end
            S.enchantPending = false
        end))
        updateEnchantPara()
        if not Remote.enchantAltar1 then
            UI.Library:Notify({Title="Orvion",Subtitle="Hub",Content="Enchant remote not found"})
            pcall(function() S.enchantToggle:Set(false) end)
            return
        end
        S.enchantThread = task.spawn(function()
            while Config.AutoEnchantReroll do
                local rodUUID = nil
                pcall(function()
                    local eq = Data.Player:Get("EquippedItems") or {}
                    local equippedSet = {}
                    for _,uuid in pairs(eq) do equippedSet[tostring(uuid)]=true end
                    local inv = Data.Player:Get("Inventory") or Data.Player.Data.Inventory
                    if not inv then return end
                    for cat,items in pairs(inv) do
                        if type(items)~="table" then continue end
                        for _,item in ipairs(items) do
                            local d = Data.ItemUtility.GetItemDataFromItemType(cat,item.Id)
                            if d and d.Data and d.Data.Type=="Fishing Rods" and equippedSet[tostring(item.UUID)] then
                                rodUUID = item.UUID break
                            end
                        end
                        if rodUUID then break end
                    end
                end)
                if not rodUUID then updateEnchantPara() break end
                local stoneUUID,stoneId = nil,(STONE_ID[Config.EnchantType] or 10)
                pcall(function()
                    local inv = Data.Player:Get("Inventory") or Data.Player.Data.Inventory
                    if not inv then return end
                    for cat,items in pairs(inv) do
                        if type(items)~="table" then continue end
                        for _,s in ipairs(items) do
                            if tonumber(s.Id)==tonumber(stoneId) then stoneUUID=s.UUID break end
                        end
                        if stoneUUID then break end
                    end
                end)
                if not stoneUUID then updateEnchantPara() break end
                if not equipAndHold(stoneUUID,"Enchant Stones") then task.wait(0.3) continue end
                S.enchantPending = true
                local isSecond = (STONE_ID[Config.EnchantType] == 246)
                if isSecond then
                    pcall(function() Remote.enchantAltar2:FireServer() end)
                else
                    pcall(function() Remote.enchantAltar1:FireServer(rodUUID) end)
                end
                local dl = os.clock()+12
                while S.enchantPending and os.clock()<dl do task.wait(0.05) end
                S.enchantPending = false
                if not Config.AutoEnchantReroll then break end
                task.wait(0.3)
            end
        end)
    end,"Toggle_Auto Enchant Reroll")
    UI.Window:AddButtonGrid(EnchantSection,
        {Title="Teleport to Altar 1",Callback=function()
            local char=Service.LocalPlayer.Character
            local root=char and char:FindFirstChild("HumanoidRootPart")
            if root then pcall(function() root.CFrame=CFrame.new(3246.00122,-1300.65588,1395.11926,-0.430797249,0,0.902448714,0,1,0,-0.902448714,0,-0.430797249) end) end
        end},
        {Title="Teleport to Altar 2",Callback=function()
            local char=Service.LocalPlayer.Character
            local root=char and char:FindFirstChild("HumanoidRootPart")
            if root then pcall(function() root.CFrame=CFrame.new(1478.63489,130.679703,-609.361938,-0.996601522,2.26994281e-08,-0.0823735297,2.58843453e-08,1,-3.7596422e-08,0.0823735297,-3.96008382e-08,-0.996601522) end) end
        end}
    )
end

-- ===== CREATE TRANSCENDED STONE =====
do
    local function setPara(para, title, content)
        pcall(function()
            local t = para:FindFirstChild("ParagraphTitle")
            local c = para:FindFirstChild("ParagraphContent")
            if t then t.Text = title end
            if c then c.Text = content end
        end)
    end
    local function equipAndHold(UUID, itemType)
        local eq = Data.Player:Get("EquippedItems") or {}
        local slot = table.find(eq, tostring(UUID))
        if not slot then
            if #eq >= 5 then return false end
            pcall(function() Remote.equipItem:FireServer(UUID, itemType) end)
            local dl = os.clock()+3
            while not slot and os.clock()<dl do
                eq = Data.Player:Get("EquippedItems") or {}
                slot = table.find(eq, tostring(UUID))
                if not slot then task.wait(0.05) end
            end
        end
        if not slot then return false end
        pcall(function() Remote.equipTool:FireServer(slot) end)
        local dl2 = os.clock()+3
        while Data.Player:Get("EquippedType")~=itemType and os.clock()<dl2 do task.wait(0.05) end
        return Data.Player:Get("EquippedType")==itemType
    end
    local TranscendedSection = UI.Window:AddCollapsible(UI.AutomationTab,"Create Transcended Stone",false)
    S.transcendedPara = UI.Window:AddParagraph(TranscendedSection,"Status","Waiting")
    S.secretFishDropdown = UI.Window:AddDropdown(TranscendedSection,"Select Secret Fish","",{},false,"Select Option",function(v)
        Config.SelectedSecretFish = v or "Select Option"
    end,"Dropdown_Select Secret Fish")
    UI.Window:AddButton(TranscendedSection,"Refresh Fish List","","rbxassetid://16932740082",function()
        local counts,nameList = {},{}
        local inv=Data.Player:Get("Inventory") or Data.Player.Data.Inventory
        if inv then
            for cat,items in pairs(inv) do
                if type(items)=="table" then
                    for _,item in ipairs(items) do
                        local d=Data.ItemUtility.GetItemDataFromItemType(cat,item.Id)
                        if d and d.Data and d.Data.Type=="Fish" and tonumber(d.Data.Tier)==7 then
                            local name=d.Data.Name or tostring(item.Id)
                            if not counts[name] then counts[name]=0 table.insert(nameList,name) end
                            counts[name]=counts[name]+1
                        end
                    end
                end
            end
        end
        local list = {}
        for _,name in ipairs(nameList) do table.insert(list,"x"..counts[name].." "..name) end
        table.sort(list)
        if S.secretFishDropdown then S.secretFishDropdown:Refresh(list,nil) end
        setPara(S.transcendedPara,"Fish List",#list.." types of secret fish found")
    end)
    UI.Window:AddInput(TranscendedSection,"Amount","","Enter amount...",function(v)
        Config.TranscendedAmount = tonumber(v) or 1
    end,"Input_Transcended Amount")
    S.transcendedToggle = UI.Window:AddToggle(TranscendedSection,"Enable Auto Create","",false,function(state)
        if S.transcendedThread then pcall(task.cancel,S.transcendedThread) S.transcendedThread=nil end
        Config.AutoCreateTranscended = state
        if not state then return end
        S.transcendedThread = task.spawn(function()
            local fishName = string.match(Config.SelectedSecretFish or "","^x%d+ (.+)$")
            if not fishName then
                setPara(S.transcendedPara,"Status","Please select a fish first")
                pcall(function() S.transcendedToggle:Set(false) end)
                return
            end
            local amount = math.max(tonumber(Config.TranscendedAmount) or 1,1)
            local created = 0
            for i=1,amount do
                if not Config.AutoCreateTranscended then break end
                local fishUUID = nil
                pcall(function()
                    local invT=Data.Player:Get("Inventory") or Data.Player.Data.Inventory
                    if invT then
                        for cat,items in pairs(invT) do
                            if type(items)=="table" then
                                for _,item in ipairs(items) do
                                    local d=Data.ItemUtility.GetItemDataFromItemType(cat,item.Id)
                                    if d and d.Data and d.Data.Type=="Fish" and d.Data.Name==fishName and tonumber(d.Data.Tier)==7 then
                                        fishUUID=item.UUID break
                                    end
                                end
                            end
                            if fishUUID then break end
                        end
                    end
                end)
                if not fishUUID then
                    setPara(S.transcendedPara,"Status","No "..fishName.." found")
                    break
                end
                setPara(S.transcendedPara,"Equipping",fishName)
                if not equipAndHold(fishUUID,"Fish") then task.wait(0.5) continue end
                setPara(S.transcendedPara,"Crafting","Create "..i.."/"..amount)
                local done,result,errMsg = false,false,"Timeout"
                local worker = task.spawn(function()
                    local ok,r,m = pcall(function() return Remote.createTranscended:InvokeServer() end)
                    if ok then result=r errMsg=tostring(m or "") end
                    done = true
                end)
                local dl = os.clock()+10
                while not done and os.clock()<dl do task.wait(0.05) end
                if not done then pcall(task.cancel,worker) end
                if result then
                    created = created+1
                    UI.Library:Notify({Title="Orvion",Subtitle="Hub",Content="Transcended Stone created ("..created.."/"..amount..")"})
                else
                    setPara(S.transcendedPara,"Failed",errMsg)
                    break
                end
                task.wait(0.3)
            end
            if Config.AutoCreateTranscended and created > 0 then
                setPara(S.transcendedPara,"Complete","Create "..created.."/"..amount)
                UI.Library:Notify({Title="Orvion",Subtitle="Hub",Content="Done! Created "..created.." Transcended Stones"})
            end
            pcall(function() S.transcendedToggle:Set(false) end)
        end)
    end,"Toggle_Enable Auto Create")
end

S.ShopTab = UI.Window:CreateTab("Shop", "rbxassetid://87353934937155")

-- ==========================================
-- ROD FEATURES
-- ==========================================
S.ROD_MAP = {
    ["Starter Rod"]=1, ["Luck Rod"]=79, ["Carbon Rod"]=76, ["Grass Rod"]=85,
    ["Demascus Rod"]=77, ["Ice Rod"]=78, ["Lucky Rod"]=4, ["Midnight Rod"]=80,
    ["Seabreeze Rod"]=657, ["Eclipse Rod"]=656, ["Steampunk Rod"]=6, ["Chrome Rod"]=7,
    ["Fluorescent Rod"]=255, ["Magma Rod"]=3, ["Astral Rod"]=5, ["Ares Rod"]=126,
    ["Angler Rod"]=168, ["Bamboo Rod"]=258,
}
S.ROD_LIST = {"Starter Rod","Luck Rod","Carbon Rod","Grass Rod","Demascus Rod","Ice Rod",
    "Lucky Rod","Midnight Rod","Seabreeze Rod","Eclipse Rod","Steampunk Rod","Chrome Rod",
    "Fluorescent Rod","Magma Rod","Astral Rod","Ares Rod","Angler Rod","Bamboo Rod"}

S.RodSection = UI.Window:AddCollapsible(S.ShopTab, "Rod Features", false)

UI.Window:AddDropdown(S.RodSection, "Select Rod", "", S.ROD_LIST, false, Config.SelectedRod, function(v)
    Config.SelectedRod = v or "Starter Rod"
end, "Dropdown_Select Rod")

UI.Window:AddButton(S.RodSection, "Buy Rod", "", "rbxassetid://16932740082", function()
    local rodId = S.ROD_MAP[Config.SelectedRod]
    if not rodId or not Remote.purchaseRod then
        UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Content="Remote not found", Color=Color3.fromRGB(150,150,170), Delay=2 })
        return
    end
    local ok, success, uuid = pcall(function() return Remote.purchaseRod:InvokeServer(rodId) end)
    if ok then
        if success and uuid and Remote.equipItem then
            pcall(function() Remote.equipItem:FireServer(uuid, "Fishing Rods") end)
        end
        UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Content=Config.SelectedRod .. (success and " bought" or " failed"), Color=Color3.fromRGB(150,150,170), Delay=3 })
    else
        UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Content="Purchase failed", Color=Color3.fromRGB(150,150,170), Delay=2 })
    end
end)

-- ==========================================
-- BAIT FEATURES
-- ==========================================
S.BAIT_MAP = {
    ["Topwater Bait"]=10, ["Luck Bait"]=2, ["Midnight Bait"]=3, ["Nature Bait"]=17,
    ["Chroma Bait"]=6, ["Dark Matter Bait"]=8, ["Corrupt Bait"]=15, ["Aether Bait"]=16,
    ["Singularity Bait"]=18,
}
S.BAIT_LIST = {"Topwater Bait","Luck Bait","Midnight Bait","Nature Bait",
    "Chroma Bait","Dark Matter Bait","Corrupt Bait","Aether Bait","Singularity Bait"}

S.BaitSection = UI.Window:AddCollapsible(S.ShopTab, "Bait Features", false)

UI.Window:AddDropdown(S.BaitSection, "Select Bait", "", S.BAIT_LIST, false, Config.SelectedBait, function(v)
    Config.SelectedBait = v or "Topwater Bait"
end, "Dropdown_Select Bait")

UI.Window:AddButton(S.BaitSection, "Buy Bait", "", "rbxassetid://16932740082", function()
    local baitId = S.BAIT_MAP[Config.SelectedBait]
    if not baitId or not Remote.purchaseBait then
        UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Content="Remote not found", Color=Color3.fromRGB(150,150,170), Delay=2 })
        return
    end
    local ok, success, shouldEquip = pcall(function() return Remote.purchaseBait:InvokeServer(baitId) end)
    if ok then
        if shouldEquip and Remote.equipBait then
            pcall(function() Remote.equipBait:FireServer(baitId) end)
        end
        UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Content=Config.SelectedBait .. (success and " bought" or " failed"), Color=Color3.fromRGB(150,150,170), Delay=3 })
    else
        UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Content="Purchase failed", Color=Color3.fromRGB(150,150,170), Delay=2 })
    end
end)

-- ==========================================
-- BLACK MARKET FEATURES
-- ==========================================
S.BM_MAP = {
    ["Undersea Racer"]="undersea_racer", ["Venombone"]="venombone_skin",
    ["Phantom Tide"]="phantom_skin", ["Raging Hadalith"]="hadalith_skin",
    ["Mecha Nautical Trinket"]="trinket_skin", ["Basic Flippers"]="basic_flippers",
    ["Gilded Boots"]="gilded_boots", ["Winged Boots M"]="winged_boots_m",
    ["Winged Boots F"]="winged_boots_f", ["Luck III Potion"]="luck_3_potion",
    ["Mutation III Potion"]="mut_3_potion", ["Mutation IV Potion"]="mut_4_potion",
    ["Dark Megalodon Hunt Potion"]="wet_1_potion", ["Megalodon Hunt Potion"]="wet_2_potion",
    ["Meteor Shower Potion"]="wet_3_potion", ["Aurora Borealis Potion"]="wet_4_potion",
    ["Glacial Serpent Hunt Potion"]="wet_5_potion", ["Coin Toss Emote"]="coin_toss",
    ["Minor Fortune Ability"]="minor_fort_ability",
}
S.BM_LIST = {"Undersea Racer","Venombone","Phantom Tide","Raging Hadalith",
    "Mecha Nautical Trinket","Basic Flippers","Gilded Boots","Winged Boots M","Winged Boots F",
    "Luck III Potion","Mutation III Potion","Mutation IV Potion","Dark Megalodon Hunt Potion",
    "Megalodon Hunt Potion","Meteor Shower Potion","Aurora Borealis Potion",
    "Glacial Serpent Hunt Potion","Coin Toss Emote","Minor Fortune Ability"}

S.BM_CF = CFrame.new(-8610.20312, -66.52478, -451.74463, -0.2025885880, -0.0000000350,
    -0.9792639613, -0.0000000417, 1.0000000000, -0.0000000271, 0.9792639613, 0.0000000354, -0.2025885880)

S.autoBuyBMThread = nil

S.buyBMItem = function(itemName)
    local itemId = S.BM_MAP[itemName]
    if not itemId or not Remote.purchaseBM then return false end
    local ok, result = pcall(function() return Remote.purchaseBM:InvokeServer(itemId) end)
    return ok and result and (type(result) == "table" and result.Success or result == true)
end



S.startAutoBuyBM = function()
    if S.autoBuyBMThread then pcall(task.cancel, S.autoBuyBMThread); S.autoBuyBMThread = nil end
    Config.AutoBuyBM = true
    S.autoBuyBMThread = task.spawn(function()
        local root = Service.LocalPlayer.Character
            and Service.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local preBMCF = root and root.CFrame
        Navigation.teleportToBM(S.BM_CF)
        task.wait(1.5)
        local bought = {}
        for _, name in ipairs(Config.SelectedBMItems) do
            if S.buyBMItem(name) then
                table.insert(bought, name)
            end
        end
        task.wait(0.5)
        if preBMCF and root then root.CFrame = preBMCF end
        Config.AutoBuyBM = false
        S.autoBuyBMThread = nil
        if S.bmToggleFunc then task.defer(function() pcall(function() S.bmToggleFunc:Set(false) end) end) end
        if #bought > 0 then
            UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="Bought: " .. table.concat(bought, ", "), Color=Color3.fromRGB(150,150,170), Delay=4 })
        else
            UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="Nothing bought / out of stock", Color=Color3.fromRGB(150,150,170), Delay=3 })
        end
    end)
end

S.BMSection = UI.Window:AddCollapsible(S.ShopTab, "Black Market Features", false)

UI.Window:AddDropdown(S.BMSection, "Select Item", "", S.BM_LIST, 999, {}, function(selected)
    Config.SelectedBMItems = type(selected) == "table" and selected or {}
end, "Dropdown_Select BM Item")

UI.Window:AddButton(S.BMSection, "Refresh List", "", "rbxassetid://16932740082", function()
    local ok, BMC = pcall(function() return require(Service.ReplicatedStorage.Shared.BlackMarketConfig) end)
    if ok and BMC then
        local ok2, items = pcall(function() return BMC.GetItems() end)
        if ok2 and items then
            UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Content="Stock refreshed", Color=Color3.fromRGB(150,150,170), Delay=2 })
        end
    end
end)

S.bmToggleFunc = nil
S.bmToggleFunc = UI.Window:AddToggle(S.BMSection, "Buy Black Market Item", "", false, function(state)
    Config.AutoBuyBM = state
    if state then
        S.startAutoBuyBM()
    else
        if S.autoBuyBMThread then pcall(task.cancel, S.autoBuyBMThread); S.autoBuyBMThread = nil end
        Config.AutoBuyBM = false
    end
end, "Toggle_Buy Black Market Item")

-- ==========================================
-- BATTLEPASS SHOP FEATURES
-- ==========================================
S.BP_LIST = {
    "Slot 1 -- Star Charm [2000]", "Slot 2 -- Seven Rings [4000]",
    "Slot 3 -- Luck I Potion [5000]", "Slot 4 -- Galactic Containment [11000]",
    "Slot 5 -- Tyrian Constellation [15000]", "Slot 6 -- Stargazing [18000]",
    "Slot 7 -- Cosmic Totem [21000]", "Slot 8 -- Royal Star Lantern [23000]",
    "Slot 9 -- Orbital Lantern [26000]", "Slot 10 -- Cosmic Totem [30000]",
    "Slot 11 -- Constellatio [34000]", "Slot 12 -- 2026 Celestial Plaque [38000]",
    "Slot 13 -- TreasureCrate [45000]", "Slot 14 -- Superstar Boat [50000]",
    "Slot 15 -- Starfall Halo [53000]", "Slot 16 -- Golden Containment [55000]",
    "Slot 17 -- TreasureCrate [58000]", "Slot 18 -- Low Gravity [60000]",
}

S.bpStatusLabel = nil
S.autoBuyBPThread = nil
S.bpToggleFunc = nil

S.updateBPStatus = function(text)
    if S.bpStatusLabel then
        S.setParagraphText(S.bpStatusLabel, text)
    end
end

S.buyBPSlots = function()
    if not Remote.bpPurchase then
        UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Content="Remote not found", Color=Color3.fromRGB(150,150,170), Delay=2 })
        return
    end
    local slots = Config.SelectedBPSlots
    if not slots or #slots == 0 then
        S.updateBPStatus("No slots selected")
        return
    end
    local total = #slots
    local bought = 0
    for i, slotName in ipairs(slots) do
        if not Config.AutoBuyBP then break end
        local index = tonumber(slotName:match("^Slot (%d+)"))
        if index then
            local owned = false
            pcall(function()
                local bp = Data.Player:Get("GalaxyBP26")
                if bp and bp[tostring(index)] then owned = true end
            end)
            if not owned then
                S.updateBPStatus("Buy " .. i .. "/" .. total .. " (Slot " .. index .. ")")
                pcall(function() Remote.bpPurchase:FireServer(index) end)
                bought = bought + 1
                task.wait(0.8)
            else
                S.updateBPStatus("Slot " .. index .. " already owned, skip")
            end
        end
    end
    S.updateBPStatus("Done  bought " .. bought .. "/" .. total)
    if bought == 0 and total > 0 then
        UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Content="No Galaxy Points or all slots owned", Color=Color3.fromRGB(150,150,170), Delay=4 })
    end
    Config.AutoBuyBP = false
    if S.bpToggleFunc then task.defer(function() pcall(function() S.bpToggleFunc:Set(false) end) end) end
end

S.BPSection = UI.Window:AddCollapsible(S.ShopTab, "Battlepass Shop Features", false)

S.bpStatusLabel = UI.Window:AddParagraph(S.BPSection, "Status", "Waiting")

UI.Window:AddDropdown(S.BPSection, "Buy Item", "", S.BP_LIST, 999, {}, function(selected)
    Config.SelectedBPSlots = type(selected) == "table" and selected or {}
end, "Dropdown_Select BP Slots")

S.bpToggleFunc = UI.Window:AddToggle(S.BPSection, "Buy Battlepass Item", "", false, function(state)
    Config.AutoBuyBP = state
    if state then
        S.updateBPStatus("Starting...")
        S.autoBuyBPThread = task.spawn(function()
            S.buyBPSlots()
        end)
    else
        if S.autoBuyBPThread then pcall(task.cancel, S.autoBuyBPThread); S.autoBuyBPThread = nil end
        Config.AutoBuyBP = false
        S.updateBPStatus("Waiting")
    end
end, "Toggle_Buy Battlepass Item")

-- ==========================================
-- MERCHANT FEATURES
-- ==========================================
S.merchantItems = {}
S.merchantStatusParagraph = nil

S.updateMerchantStatus = function(bought, total)
    local itemName = Config.SelectedMerchantItem
    local price = "?"
    if S.merchantItems[itemName] then price = tostring(S.merchantItems[itemName].price or "?") end
    local buyStr = bought and (bought .. "/" .. total) or "0/1"
    local content = "Item: " .. (itemName ~= "Select Option" and itemName or "-") ..
        "\nPrice: " .. price .. " Coins" ..
        "\nBuy: " .. buyStr
    S.setParagraphText(S.merchantStatusParagraph, content)
end

S.MerchantSection = UI.Window:AddCollapsible(S.ShopTab, "Merchant Features", false)

S.merchantStatusParagraph = UI.Window:AddParagraph(S.MerchantSection, "Status", "Item: -\nPrice: ? Coins\nBuy: 0/1")

S.merchantDropdownItems = {}
S.merchantDropdown = UI.Window:AddDropdown(S.MerchantSection, "Select Item", "", S.merchantDropdownItems, false, nil, function(v)
    Config.SelectedMerchantItem = v or "Select Option"
    S.updateMerchantStatus()
end, "Dropdown_Select Merchant Item")

UI.Window:AddInput(S.MerchantSection, "Quantity", "", "Enter quantity...", function(v)
    Config.MerchantQty = tonumber(v) or 1
end, "Input_Merchant Qty")

UI.Window:AddButton(S.MerchantSection, "Refresh Item Merchant", "", "rbxassetid://16932740082", function()
    local mr = nil
    pcall(function() mr = Data.Replion.Client:WaitReplion("Merchant") end)
    if not mr then
        UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Content="Replion not found", Color=Color3.fromRGB(150,150,170), Delay=2 })
        return
    end
    local ok2, MID = pcall(function() return require(Service.ReplicatedStorage.Shared.MarketItemData) end)
    local ok3, IU  = pcall(function() return require(Service.ReplicatedStorage.Shared.ItemUtility) end)
    -- build MarketItemData map
    local midMap = {}
    if ok2 and MID then
        for _, v in ipairs(MID) do midMap[v.Id] = v end
    end
    local itemIds = {}
    pcall(function() itemIds = mr:GetExpect("Items") or {} end)
    S.merchantItems = {}
    local newList = {}
    for _, itemId in ipairs(itemIds) do
        local md = midMap[itemId]
        if not md or md.Currency ~= "Coins" then continue end
        local name = tostring(md.Identifier or itemId)
        local price = tostring(md.Price or "?")
        if ok3 and IU and md.Type and md.Identifier then
            pcall(function()
                local data = IU.GetItemDataFromItemType(md.Type, md.Identifier)
                if data and data.Data and data.Data.Name then
                    name = data.Data.Name
                end
            end)
        end
        S.merchantItems[name] = { id = itemId, price = price }
        table.insert(newList, name)
    end
    local defaultItem = newList[1] or "Select Option"
    Config.SelectedMerchantItem = defaultItem
    if S.merchantDropdown then
        pcall(function() S.merchantDropdown:Refresh(newList, defaultItem) end)
    end
    S.updateMerchantStatus()
    UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Content=tostring(#newList) .. " items found", Color=Color3.fromRGB(150,150,170), Delay=2 })
end)

S.merchantBuying = false
UI.Window:AddButton(S.MerchantSection, "Buy Manual", "", "rbxassetid://16932740082", function()
    if S.merchantBuying then return end
    S.merchantBuying = true
    local name = Config.SelectedMerchantItem
    if name == "Select Option" or not S.merchantItems[name] then
        UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="Select item first", Color=Color3.fromRGB(150,150,170), Delay=2 })
        S.merchantBuying = false
        return
    end
    local itemId = S.merchantItems[name].id
    local price = tonumber(S.merchantItems[name].price) or 0
    local coins = 0
    pcall(function() coins = Data.Player:GetExpect("Coins") or 0 end)
    if price > 0 and coins < price then
        UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="Not enough coins", Color=Color3.fromRGB(150,150,170), Delay=3 })
        S.merchantBuying = false
        return
    end
    local qty = 1
    local bought = 0
    for i = 1, qty do
        S.updateMerchantStatus(bought, qty)
        local ok, result = pcall(function() return Remote.purchaseMerchant:InvokeServer(itemId) end)
        if ok and result then
            bought = bought + 1
        else
            local c = 0
            pcall(function() c = Data.Player:GetExpect("Coins") or 0 end)
            if price > 0 and c < price then
                UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="Not enough coins", Color=Color3.fromRGB(150,150,170), Delay=3 })
                break
            end
        end
        S.updateMerchantStatus(bought, qty)
        if i < qty then task.wait(0.5) end
    end
    S.updateMerchantStatus(bought, qty)
    UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content=name .. " x" .. bought .. " bought", Color=Color3.fromRGB(150,150,170), Delay=3 })
    S.merchantBuying = false
end)

S.autoBuyMerchantThread = nil
S.merchantToggleFunc = nil
S.merchantToggleFunc = UI.Window:AddToggle(S.MerchantSection, "Buy Merchant Item", "", false, function(state)
    Config.AutoBuyMerchant = state
    if state then
        S.autoBuyMerchantThread = task.spawn(function()
            local name = Config.SelectedMerchantItem
            if name == "Select Option" or not S.merchantItems[name] or not Remote.purchaseMerchant then
                Config.AutoBuyMerchant = false
                return
            end
            local itemId = S.merchantItems[name].id
            local price = tonumber(S.merchantItems[name].price) or 0
            local qty = math.max(1, Config.MerchantQty)
            local bought = 0
            for i = 1, qty do
                if not Config.AutoBuyMerchant then break end
                local coins = 0
                pcall(function() coins = Data.Player:GetExpect("Coins") or 0 end)
                if price > 0 and coins < price then
                    UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="Not enough coins", Color=Color3.fromRGB(150,150,170), Delay=3 })
                    break
                end
                S.updateMerchantStatus(bought, qty)
                local ok, result = pcall(function() return Remote.purchaseMerchant:InvokeServer(itemId) end)
                if ok and result then bought = bought + 1 end
                S.updateMerchantStatus(bought, qty)
                if i < qty then task.wait(0.5) end
            end
            UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content=name .. " x" .. bought .. " bought", Color=Color3.fromRGB(150,150,170), Delay=3 })
            Config.AutoBuyMerchant = false
            if S.merchantToggleFunc then task.defer(function() pcall(function() S.merchantToggleFunc:Set(false) end) end) end
        end)
    else
        if S.autoBuyMerchantThread then pcall(task.cancel, S.autoBuyMerchantThread); S.autoBuyMerchantThread = nil end
        Config.AutoBuyMerchant = false
    end
end, "Toggle_Buy Merchant Item")

-- ====== STARTUP ======
SupportState.updateBigPopup()
UI.Window:SetActiveTab("Info")
UI.Window:Show()
