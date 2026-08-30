-- ====================================================================
--                 INSTANT FISHING V2 - CLEAN
--          Fishing + AutoSell + Auto Small Notification
--       Quest Planner + Elemental Event build: 20260830-R5
-- ====================================================================

-- ====== SERVICES ======
local Service = {
    Players = game:GetService("Players"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    HttpService = game:GetService("HttpService"),
    RunService = game:GetService("RunService"),
    CollectionService = game:GetService("CollectionService"),
    Lighting = game:GetService("Lighting"),
    Stats = game:GetService("Stats"),
    TextService = game:GetService("TextService"),
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
    unequipTool = "RE/UnequipToolFromHotbar",
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
    placeLever = "RE/PlaceLeverItem",
    placePressure = "RE/PlacePressureItem",
    dialogueEnded = "RE/DialogueEnded",
    claimItem = "RF/ClaimItem",
}) do
    Remote[key] = Remote.Resolve(remoteName)
end
Remote.cutscene = Remote.Net:WaitForChild("RE/ReplicateCutscene", 10)
Remote.abilityVFX = Remote.Net:WaitForChild("RE/PlayAbilityVFX", 10)
Remote.baitCast = Remote.Net:FindFirstChild("RE/BaitCastVisual")
Remote.enchantAltar1 = Remote.Resolve("RE/ActivateEnchantingAltar")
Remote.unequipItem = Remote.Resolve("RE/UnequipItem")
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
    hidePlayers = {
        Active = false,
        Session = 0,
        GlobalConnections = {},
        PlayerConnections = setmetatable({}, { __mode = "k" }),
        CharacterConnections = setmetatable({}, { __mode = "k" }),
        Characters = setmetatable({}, { __mode = "k" }),
        Original = setmetatable({}, { __mode = "k" }),
    },
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
    lockPositionActive = false,
    lockPositionSession = 0,
    lockPosConn = nil,
    lockRoot = nil,
    lockOriginalAnchored = nil,
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
    Quest = {
        Enabled = {},       -- [jobName]=true/false per toggle
        Threads = {},       -- [jobName]=thread handle
        SellHold = 0,       -- counter: >0 = hold. Bukan boolean — cegah race multi-fitur
        Panels = {},
        LastLocation = nil, -- dipakai fallback/teleportNPC
        OnFishCaught = function() end,
        RefreshPanels = function() end,
        Start = function() return false end,
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
    ["Elemental Blizzard"]       = CFrame.new(-981.890015,45.8336372,5302.85986,-0.855183363,-1.00189254e-07,0.518325567,-7.92015129e-08,1,6.26197831e-08,-0.518325567,1.24992239e-08,-0.855183363),
    ["Elemental Storm"]          = CFrame.new(-936.080017,54.3766861,5238.54004,-0.82114917,1.24735946e-08,-0.57071358,2.52029881e-08,1,-1.44062087e-08,0.57071358,-2.62133337e-08,-0.82114917),
    ["Elemental Volcano"]        = CFrame.new(-729.789978,107.056473,5347.83008,-0.639170587,2.26108412e-08,0.769065022,1.3202623e-08,1,-1.8427718e-08,-0.769065022,-1.62477964e-09,-0.639170587),
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
    eventReplionConns = {},
    eventResolveRevision = 0,
    eventTargetKey = nil,
    eventTargetUsesWater = false,
    eventTeleportActive = false,
    npcInitList = nil,
    positionLockNoticeAt = 0,
}

Navigation.notifyPositionLocked = function()
    local now = os.clock()
    if now - Navigation.positionLockNoticeAt < 2 then return end
    Navigation.positionLockNoticeAt = now
    UI.Library:Notify({
        Title = "Orvion", Subtitle = "Hub",
        Content = "Teleport blocked - Lock Position is enabled",
        Color = Color3.fromRGB(150,150,170), Delay = 2,
    })
end

-- Single position-write gate for every Orvion character teleport.
Navigation.tryMoveRoot = function(root, targetCFrame, notifyLocked)
    if SupportState.lockPositionActive then
        if notifyLocked then Navigation.notifyPositionLocked() end
        return false, "POSITION_LOCKED"
    end
    if not root or not root.Parent or typeof(targetCFrame) ~= "CFrame" then
        return false, "INVALID_TARGET"
    end
    local ok = pcall(function()
        root.CFrame = targetCFrame
    end)
    if ok then return true end
    return false, "MOVE_FAILED"
end

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
Navigation.teleportToSaved = function(notifyLocked)
    local cf = Navigation.getSavedLocation()
    if not cf then return false end
    local char = Service.LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    return Navigation.tryMoveRoot(root, cf, notifyLocked)
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
    "Elemental Blizzard", "Elemental Storm", "Elemental Volcano",
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

Navigation.teleportTo = function(name, notifyLocked)
    local cf = Catalog.Locations[name]
    if not cf then return false end
    local char = Service.LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    return Navigation.tryMoveRoot(root, cf, notifyLocked)
end

Navigation.teleportToBM = function(cf, notifyLocked)
    local root = Service.LocalPlayer.Character
        and Service.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    return Navigation.tryMoveRoot(root, cf, notifyLocked)
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
                -- Sell.Wait yields. Re-enter the coordinator gate because a
                -- Quest transaction or another fishing owner may have begun.
                continue
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

    local forcePerfect = Config.PerfectCast
    local targetPower = forcePerfect and 0.99 or 0.10
    if Config.RandomResults and not forcePerfect then
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
    if Runtime.Quest.SellHold > 0 then
        Runtime.Sell.Pending = true
        Runtime.Sell.Reason = Runtime.Sell.Reason or "QuestHold"
        return false
    end
    -- Cek langsung saat mau sell: kalau ada ikan target quest di inventory, block
    -- Lebih reliable dari OnFishCaught karena tidak ada race window
    if S.Quest then
        -- Crystalline: block kalau ada pressure fish di inventory DAN plate belum aktif
        -- Cek findPressureFish langsung — lebih reliable dari CrystallineBusy
        -- Setelah ikan di-sacrifice (dikonsumsi server), findPressureFish nil → sell lanjut
        if Runtime.Quest.Enabled.Crystalline == true and S.Quest.findPressureFish then
            local plates = S.Quest.get("RuinPressurePlates") or {}
            for _, definition in ipairs(S.Quest.Pressure or {}) do
                if plates[definition.Name] ~= true
                    and S.Quest.findPressureFish(definition.Name)
                then
                    Runtime.Sell.Pending = true
                    Runtime.Sell.Reason = "QuestHold"
                    return false
                end
            end
        end
        -- Diamond: block kalau ada Ruby Gemstone atau Lochness dan obj belum selesai
        if Runtime.Quest.Enabled.Diamond == true then
            if S.Quest.progress("Diamond Researcher", 4, 1) < 1
                and S.Quest.findFish(243, "Gemstone")
            then
                Runtime.Sell.Pending = true
                Runtime.Sell.Reason = "QuestHold"
                return false
            end
            if S.Quest.progress("Diamond Researcher", 5, 1) < 1
                and S.Quest.findFish(228)
            then
                Runtime.Sell.Pending = true
                Runtime.Sell.Reason = "QuestHold"
                return false
            end
        end
    end
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
            pcall(Runtime.Quest.OnFishCaught, fishName, fishMetadata)
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
        -- Cek sekarang dulu
        if Runtime.Quest.SellHold == 0 and not FishingModes.Active then
            pcall(function()
                local equipped = Data.Player:Get("EquippedId")
                if not equipped or equipped == "" then
                    Remote.equipTool:FireServer(1)
                end
            end)
        end
        -- Event-driven: tiap EquippedId kosong → pasang rod
        -- task.spawn+wait(0.1): debounce supaya tidak flicker saat EquippedId bounce cepat
        SupportState.autoEquipRodConn = Data.Player:OnChange("EquippedId", function(value)
            if not value or value == "" then
                if Runtime.Quest.SellHold > 0 or Runtime.Sell.Busy or FishingModes.Active then return end
                task.spawn(function()
                    task.wait(0.3)
                    if Runtime.Quest.SellHold > 0 or Runtime.Sell.Busy or FishingModes.Active then return end
                    local current = Data.Player:Get("EquippedId")
                    if not current or current == "" then
                        pcall(function() Remote.equipTool:FireServer(1) end)
                    end
                end)
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
    local bucket = SupportState.hidePlayers
    bucket.Active = false
    bucket.Session = bucket.Session + 1

    for _, conn in ipairs(bucket.GlobalConnections) do
        pcall(function() conn:Disconnect() end)
    end
    for _, conn in pairs(bucket.PlayerConnections) do
        pcall(function() conn:Disconnect() end)
    end
    for _, conn in pairs(bucket.CharacterConnections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(bucket.GlobalConnections)
    bucket.PlayerConnections = setmetatable({}, { __mode = "k" })
    bucket.CharacterConnections = setmetatable({}, { __mode = "k" })
    bucket.Characters = setmetatable({}, { __mode = "k" })

    for obj, original in pairs(bucket.Original) do
        if obj and obj.Parent then
            pcall(function()
                obj[original[1]] = original[2]
            end)
        end
    end
    bucket.Original = setmetatable({}, { __mode = "k" })
    if not state then return end

    bucket.Active = true
    local session = bucket.Session

    local function hideObject(obj)
        if not bucket.Active or bucket.Session ~= session or bucket.Original[obj] then return end
        local property, hidden
        if obj:IsA("BasePart") then
            property, hidden = "LocalTransparencyModifier", 1
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            property, hidden = "Transparency", 1
        elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam")
            or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles")
            or obj:IsA("Highlight") or obj:IsA("BillboardGui")
            or obj:IsA("SurfaceGui") or obj:IsA("PointLight")
            or obj:IsA("SpotLight") or obj:IsA("SurfaceLight")
        then
            property, hidden = "Enabled", false
        else
            return
        end
        local ok, original = pcall(function() return obj[property] end)
        if not ok then return end
        bucket.Original[obj] = { property, original }
        pcall(function() obj[property] = hidden end)
    end

    local function detachCharacter(player)
        local char = bucket.Characters[player]
        local conn = char and bucket.CharacterConnections[char]
        if conn then pcall(function() conn:Disconnect() end) end
        if char then bucket.CharacterConnections[char] = nil end
        bucket.Characters[player] = nil
    end

    local function attachCharacter(player, char)
        if player == Service.LocalPlayer or not char
            or not bucket.Active or bucket.Session ~= session
        then
            return
        end
        detachCharacter(player)
        bucket.Characters[player] = char
        for _, obj in ipairs(char:GetDescendants()) do hideObject(obj) end
        bucket.CharacterConnections[char] = char.DescendantAdded:Connect(hideObject)
    end

    local function detachPlayer(player)
        detachCharacter(player)
        local conn = bucket.PlayerConnections[player]
        if conn then pcall(function() conn:Disconnect() end) end
        bucket.PlayerConnections[player] = nil
    end

    local function attachPlayer(player)
        if player == Service.LocalPlayer or not bucket.Active
            or bucket.Session ~= session
        then
            return
        end
        detachPlayer(player)
        bucket.PlayerConnections[player] = player.CharacterAdded:Connect(function(char)
            attachCharacter(player, char)
        end)
        if player.Character then attachCharacter(player, player.Character) end
    end

    for _, player in ipairs(Service.Players:GetPlayers()) do attachPlayer(player) end
    table.insert(bucket.GlobalConnections, Service.Players.PlayerAdded:Connect(attachPlayer))
    table.insert(bucket.GlobalConnections, Service.Players.PlayerRemoving:Connect(detachPlayer))
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
SupportState.releaseLockRoot = function()
    local root = SupportState.lockRoot
    local original = SupportState.lockOriginalAnchored
    SupportState.lockRoot = nil
    SupportState.lockOriginalAnchored = nil
    if root and root.Parent and original ~= nil then
        pcall(function() root.Anchored = original end)
    end
end

SupportState.setLockPosition = function(state)
    SupportState.lockPositionActive = false
    SupportState.lockPositionSession = SupportState.lockPositionSession + 1
    if SupportState.lockPosConn then
        pcall(function() SupportState.lockPosConn:Disconnect() end)
        SupportState.lockPosConn = nil
    end
    SupportState.releaseLockRoot()
    if not state then return end

    SupportState.lockPositionActive = true
    local session = SupportState.lockPositionSession

    local function attachCharacter(char)
        task.spawn(function()
            local root = char and char:WaitForChild("HumanoidRootPart", 5)
            if not root or not SupportState.lockPositionActive
                or SupportState.lockPositionSession ~= session
                or Service.LocalPlayer.Character ~= char
                or SupportState.lockRoot == root
            then
                return
            end
            SupportState.releaseLockRoot()
            if not SupportState.lockPositionActive
                or SupportState.lockPositionSession ~= session
            then
                return
            end
            SupportState.lockRoot = root
            SupportState.lockOriginalAnchored = root.Anchored
            pcall(function() root.Anchored = true end)
        end)
    end

    SupportState.lockPosConn = Service.LocalPlayer.CharacterAdded:Connect(attachCharacter)
    if Service.LocalPlayer.Character then attachCharacter(Service.LocalPlayer.Character) end
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
    "Blizzard Elemental Event",
    "Dark Megalodon Hunt",
    "Glacial Serpent Hunt",
    "Megalodon Hunt",
    "Storm Elemental Event",
    "Thunderzilla Hunt",
    "Volcano Elemental Event",
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
    pingGui.DisplayOrder = -1  -- selalu di bawah Orvion window
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

    -- Simpan connections supaya bisa di-disconnect saat toggle OFF
    local dragging, dragStart, startPos = false, nil, nil
    local conns = {}
    pcall(function()
        table.insert(conns, frame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true; dragStart = input.Position; startPos = frame.Position
            end
        end))
    end)
    pcall(function()
        table.insert(conns, UIS.InputChanged:Connect(function(input)
            if not dragging then return end
            if input.UserInputType ~= Enum.UserInputType.MouseMovement
                and input.UserInputType ~= Enum.UserInputType.Touch then return end
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end))
    end)
    pcall(function()
        table.insert(conns, UIS.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end))
    end)
    UI.pingConns = conns
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
        if UI.pingConns then
            for _, conn in ipairs(UI.pingConns) do pcall(function() conn:Disconnect() end) end
            UI.pingConns = nil
        end
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
    if not state and Navigation.scheduleEventResolve then
        Navigation.scheduleEventResolve()
    end
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
UI.TpSection = UI.Window:AddCollapsible(UI.TpTab, "Teleport to Location", false)

UI.Window:AddDropdown(UI.TpSection, "Select Location", "", Catalog.LocationNames, false, "Ancient Jungle", function(value)
    Config.TeleportLocation = value
end, "Dropdown_Select Map")

UI.Window:AddButton(UI.TpSection, "Teleport", "", "", function()
    if Navigation.teleportTo(Config.TeleportLocation, true) then
        UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="Teleported to " .. Config.TeleportLocation, Color=Color3.fromRGB(150,150,170), Delay=2 })
    end
end)


-- Teleport to Event
Catalog.ElementalEventRoutes = {
    ["Blizzard Elemental Event"] = "Elemental Blizzard",
    ["Storm Elemental Event"] = "Elemental Storm",
    ["Volcano Elemental Event"] = "Elemental Volcano",
}

Navigation.ensureEventsReplion = function()
    if Data.Events and not Data.Events.Destroyed then return Data.Events end
    local ok, replion = pcall(function()
        return Data.Replion.Client:WaitReplion("Events")
    end)
    if ok then Data.Events = replion end
    return Data.Events
end

Navigation.isElementalEventActive = function(eventName)
    if not Catalog.ElementalEventRoutes[eventName] then return false end
    local events = Navigation.ensureEventsReplion()
    if not events or events.Destroyed then return false end
    local ok, found = pcall(function()
        return events:Find("Events", eventName)
    end)
    return ok and found ~= nil
end

Navigation.getEventTarget = function(eventName, source)
    if not eventName or eventName == "Select Option" then return nil end
    local locationName = Catalog.ElementalEventRoutes[eventName]
    if locationName then
        if not Navigation.isElementalEventActive(eventName) then return nil end
        return {
            CFrame = Catalog.Locations[locationName],
            Key = source .. ":elemental:" .. eventName,
            UsesWater = false,
        }
    end
    local pos = Navigation.findEventPosition(eventName)
    if not pos then return nil end
    return {
        CFrame = CFrame.new(pos + Vector3.new(0, 6, 0)),
        Key = source .. ":world:" .. eventName,
        UsesWater = true,
    }
end

Navigation.getBestEventTarget = function()
    local target = Navigation.getEventTarget(Config.PriorityEvent, "priority")
    if target then return target end
    return Navigation.getEventTarget(Config.SelectEvent, "select")
end

Navigation.pauseQuestForEvent = function(state)
    -- Refactored: stop/resume semua quest thread saat event pause
    if state then
        for _, job in ipairs({"Artifact","DeepSea","Element","Diamond"}) do
            if Runtime.Quest.Enabled[job] then
                local thread = Runtime.Quest.Threads[job]
                if thread then
                    pcall(task.cancel, thread)
                    Runtime.Quest.Threads[job] = nil
                end
            end
        end
        Runtime.Quest.SellHold = 0
        if Runtime.Fishing.Owner == "Quest" then
            Runtime.Fishing.Owner = nil
        end
    else
        -- Resume: restart semua yang masih Enabled
        if S.Quest and S.Quest.startJobThread then
            for _, job in ipairs({"Artifact","DeepSea","Element","Diamond"}) do
                if Runtime.Quest.Enabled[job] and S.Quest.Runners[job] then
                    S.Quest.startJobThread(job, S.Quest.Runners[job])
                end
            end
        end
    end
end

Navigation.applyEventTarget = function(target)
    if not Navigation.eventTeleportActive then return end
    if target and Navigation.eventTargetKey == target.Key then return end

    local character = Service.LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    if not target then
        if not Navigation.eventTargetKey then return end
        Navigation.eventTargetKey = nil
        Navigation.eventTargetUsesWater = false
        Navigation.stopEventWalkOnWater()
        local returnCFrame = Navigation.preEventCFrame
        Navigation.preEventCFrame = nil
        if returnCFrame then Navigation.tryMoveRoot(root, returnCFrame) end
        Navigation.pauseQuestForEvent(false)
        return
    end

    -- Lock Position owns movement. Keep the event listener alive and retry
    -- only when the lock is released; do not repeatedly cancel Quest jobs.
    if SupportState.lockPositionActive then return end

    if not Navigation.preEventCFrame then
        Navigation.preEventCFrame = root.CFrame
    end
    Navigation.pauseQuestForEvent(true)
    local moved = Navigation.tryMoveRoot(root, target.CFrame)
    if not moved then
        if not Navigation.eventTargetKey then
            Navigation.preEventCFrame = nil
            Navigation.pauseQuestForEvent(false)
        end
        return
    end

    Navigation.eventTargetKey = target.Key
    Navigation.eventTargetUsesWater = target.UsesWater == true
    if Navigation.eventTargetUsesWater then
        Navigation.startEventWalkOnWater()
    else
        Navigation.stopEventWalkOnWater()
    end
end

Navigation.scheduleEventResolve = function()
    if not Navigation.eventTeleportActive then return end
    Navigation.eventResolveRevision = Navigation.eventResolveRevision + 1
    local revision = Navigation.eventResolveRevision
    task.defer(function()
        if not Navigation.eventTeleportActive
            or revision ~= Navigation.eventResolveRevision
        then
            return
        end
        Navigation.applyEventTarget(Navigation.getBestEventTarget())
    end)
end

Navigation.clearEventListeners = function()
    if Navigation.eventWatcherConn then
        pcall(function() Navigation.eventWatcherConn:Disconnect() end)
        Navigation.eventWatcherConn = nil
    end
    for _, connection in ipairs(Navigation.eventReplionConns) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(Navigation.eventReplionConns)
end

Navigation.startEventListeners = function()
    Navigation.clearEventListeners()
    table.insert(Navigation.eventReplionConns,
        Service.LocalPlayer.CharacterAdded:Connect(function()
            Navigation.eventTargetKey = nil
            Navigation.preEventCFrame = nil
            task.wait(1)
            Navigation.scheduleEventResolve()
        end))
    local events = Navigation.ensureEventsReplion()
    if events and not events.Destroyed then
        local function onElementalChanged(_, eventName)
            if Catalog.ElementalEventRoutes[eventName] then
                Navigation.scheduleEventResolve()
            end
        end
        local okInsert, insertConnection = pcall(function()
            return events:OnArrayInsert("Events", onElementalChanged)
        end)
        if okInsert and insertConnection then
            table.insert(Navigation.eventReplionConns, insertConnection)
        end
        local okRemove, removeConnection = pcall(function()
            return events:OnArrayRemove("Events", onElementalChanged)
        end)
        if okRemove and removeConnection then
            table.insert(Navigation.eventReplionConns, removeConnection)
        end
    end

    -- Normal hunt/admin events still expose workspace models. Elemental
    -- events are resolved exclusively by the Replion listeners above.
    Navigation.eventWatcherConn = workspace.DescendantRemoving:Connect(function(obj)
        if obj:IsA("Model") then Navigation.scheduleEventResolve() end
    end)
    task.spawn(function()
        while Navigation.eventTeleportActive do
            task.wait(2)
            if not Navigation.eventTeleportActive then break end
            local priorityNormal = Config.PriorityEvent
                and Config.PriorityEvent ~= "Select Option"
                and not Catalog.ElementalEventRoutes[Config.PriorityEvent]
            local selectedNormal = Config.SelectEvent
                and Config.SelectEvent ~= "Select Option"
                and not Catalog.ElementalEventRoutes[Config.SelectEvent]
            if priorityNormal or selectedNormal then
                Navigation.scheduleEventResolve()
            end
        end
    end)
end

Navigation.stopAutoEvent = function(returnToOrigin)
    Navigation.eventTeleportActive = false
    Navigation.eventResolveRevision = Navigation.eventResolveRevision + 1
    Navigation.clearEventListeners()
    Navigation.stopEventWalkOnWater()
    local returnCFrame = Navigation.preEventCFrame
    Navigation.preEventCFrame = nil
    Navigation.eventTargetKey = nil
    Navigation.eventTargetUsesWater = false
    if returnToOrigin and returnCFrame then
        local character = Service.LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        Navigation.tryMoveRoot(root, returnCFrame)
    end
    Navigation.pauseQuestForEvent(false)
end

UI.TpEventSection = UI.Window:AddCollapsible(UI.TpTab, "Teleport to Event", false)

UI.Window:AddDropdown(UI.TpEventSection, "Priority Event", "", Catalog.EventList, false, "Select Option", function(value)
    Config.PriorityEvent = value
    Navigation.scheduleEventResolve()
end)
UI.Window:AddDropdown(UI.TpEventSection, "Select Event", "", Catalog.EventList, false, "Select Option", function(value)
    Config.SelectEvent = value
    Navigation.scheduleEventResolve()
end)
UI.Window:AddToggle(UI.TpEventSection, "Start Auto Event", "", false, function(state)
    if state then
        Navigation.eventTeleportActive = true
        Navigation.startEventListeners()
        Navigation.scheduleEventResolve()
    else
        Navigation.stopAutoEvent(true)
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
    if SupportState.lockPositionActive then Navigation.notifyPositionLocked() return end
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
                teleported = Navigation.tryMoveRoot(
                    root, model:GetPivot() * CFrame.new(0, 0, 4), true
                )
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
        if SupportState.lockPositionActive then Navigation.notifyPositionLocked() return end
        local teleported = false
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
            teleported = Navigation.tryMoveRoot(root, tr.CFrame + Vector3.new(3, 0, 0), true)
        end)
        if teleported then
            UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="Teleported to " .. tostring(Config.TeleportPlayer), Color=Color3.fromRGB(150,150,170), Delay=2 })
        end
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
    local ok, result, reason = pcall(function()
        return Navigation.teleportToSaved(true)
    end)
    if ok and result then
        UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="Teleported to saved!", Color=Color3.fromRGB(150,150,170), Delay=2 })
    elseif reason ~= "POSITION_LOCKED" then
        UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="No saved location.", Color=Color3.fromRGB(150,150,170), Delay=2 })
    end
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
    text = tostring(text or "")
    if type(para) == "table" and para.Set then
        pcall(function() para:Set(text) end)
    else
        pcall(function()
            local label = para:FindFirstChild("ParagraphContent")
            if not label then return end
            label.Text = text

            -- CreateParagraph measures only its initial content. Recalculate
            -- after every dynamic update so multiline Quest panels keep a
            -- real bottom gap instead of clipping against the background.
            local width = label.AbsoluteSize.X
            if width <= 0 then
                width = math.max(220, para.AbsoluteSize.X - 20)
            end
            local bounds = Service.TextService:GetTextSize(
                text, label.TextSize, label.Font,
                Vector2.new(width, 10000))
            local contentHeight = math.max(16, math.ceil(bounds.Y) + 2)
            label.AutomaticSize = Enum.AutomaticSize.None
            label.Size = UDim2.new(1, -20, 0, contentHeight)
            para.AutomaticSize = Enum.AutomaticSize.None
            para.Size = UDim2.new(1, 0, 0, math.max(52, 29 + contentHeight + 14))
        end)
    end
end

-- Equip an inventory item and work around hotbar slots that refuse to switch.
S.equipAndHold = function(UUID, itemType, shouldContinue)
    local uuid = tostring(UUID or "")
    if uuid == "" or not Remote.equipItem or not Remote.equipTool or not Remote.unequipItem then
        return false
    end

    local equippedItems = Data.Player:Get("EquippedItems") or {}
    local slot = table.find(equippedItems, uuid)
    if not slot then
        if shouldContinue and not shouldContinue() then return false end
        local sent = pcall(function()
            Remote.equipItem:FireServer(UUID, itemType)
        end)
        if not sent then return false end

        local equipDeadline = os.clock() + 3
        while not slot and os.clock() < equipDeadline do
            if shouldContinue and not shouldContinue() then return false end
            task.wait(0.05)
            equippedItems = Data.Player:Get("EquippedItems") or {}
            slot = table.find(equippedItems, uuid)
        end
    end
    if not slot then return false end

    for _ = 1, 3 do
        if shouldContinue and not shouldContinue() then return false end
        equippedItems = Data.Player:Get("EquippedItems") or {}
        slot = table.find(equippedItems, uuid)
        if not slot then return false end

        local sent = pcall(function()
            Remote.equipTool:FireServer(slot)
        end)
        if not sent then return false end

        -- Allow normal replication first; only remove a blocker that persists.
        local graceDeadline = os.clock() + 0.35
        while os.clock() < graceDeadline do
            if shouldContinue and not shouldContinue() then return false end
            local equippedType = Data.Player:Get("EquippedType")
            local equippedId = tostring(Data.Player:Get("EquippedId") or "")
            if equippedType == itemType and equippedId == uuid then
                return true
            end
            task.wait(0.05)
        end

        local blockingId = tostring(Data.Player:Get("EquippedId") or "")
        if blockingId ~= "" and blockingId ~= uuid then
            pcall(function()
                Remote.unequipItem:FireServer(blockingId)
            end)

            local removalDeadline = os.clock() + 1.5
            while os.clock() < removalDeadline do
                if shouldContinue and not shouldContinue() then return false end
                equippedItems = Data.Player:Get("EquippedItems") or {}
                if not table.find(equippedItems, blockingId) then break end
                task.wait(0.05)
            end
        else
            task.wait(0.1)
        end
    end
    return false
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
    local function findEnchantStone(stoneId)
        local firstUUID, total = nil, 0
        pcall(function()
            local inv = Data.Player:Get("Inventory") or Data.Player.Data.Inventory
            if not inv then return end
            for cat, items in pairs(inv) do
                if type(items) ~= "table" then continue end
                for _, item in ipairs(items) do
                    local rawId = item.Id or item.Identifier
                    if tonumber(rawId) == tonumber(stoneId) then
                        local itemData = Data.ItemUtility.GetItemDataFromItemType(cat, rawId)
                        local quantity = tonumber(item.Quantity) or 1
                        if itemData and itemData.Data
                            and itemData.Data.Type == "Enchant Stones"
                            and quantity > 0
                        then
                            firstUUID = firstUUID or item.UUID
                            total = total + quantity
                        end
                    end
                end
            end
        end)
        return firstUUID, total
    end
    S.rodHasEnchant = function(rodUUID, enchantId)
        local matched = false
        pcall(function()
            local inv = Data.Player:Get("Inventory") or Data.Player.Data.Inventory
            if not inv then return end
            for _, items in pairs(inv) do
                if type(items) ~= "table" then continue end
                for _, item in ipairs(items) do
                    if tostring(item.UUID or "") == tostring(rodUUID or "") then
                        local meta = item.Metadata or {}
                        matched = tostring(meta.EnchantId or "") == tostring(enchantId or "")
                            or tostring(meta.EnchantId2 or "") == tostring(enchantId or "")
                        return
                    end
                end
            end
        end)
        return matched
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
                    -- use item data for reliable type detection
                    local rawId = item.Id or item.Identifier
                    local d = Data.ItemUtility.GetItemDataFromItemType(cat, rawId)
                    if not (d and d.Data) then continue end
                    if d.Data.Type == "Enchant Stones" and tonumber(rawId)==tonumber(stoneId) then
                        stoneCount = stoneCount+(tonumber(item.Quantity) or 1)
                    end
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
    local EnchantSection = UI.Window:AddCollapsible(UI.AutomationTab,"Enchant Features",false)
    S.enchantPara = UI.Window:AddParagraph(EnchantSection,"Enchant Status","Current Rod: None\nEnchant 1: None\nEnchant 2: None\nEnchant Stones Left: 0")
    UI.Window:AddDropdown(EnchantSection,"Enchant Type","",STONE_LIST,false,"Select Option",function(v)
        Config.EnchantType = v or "Select Option"
        if Config.AutoEnchantReroll then updateEnchantPara() end
    end,"Dropdown_Enchant Type")
    UI.Window:AddDropdown(EnchantSection,"Target Enchant","",TARGET_LIST,false,"Select Option",function(v)
        Config.TargetEnchant = v or "Select Option"
    end,"Dropdown_Target Enchant")
    S.enchantToggle = UI.Window:AddToggle(EnchantSection,"Auto Enchant Reroll","",false,function(state)
        S.enchantSession = (S.enchantSession or 0) + 1
        for _,conn in ipairs(S.enchantConns) do pcall(function() conn:Disconnect() end) end
        S.enchantConns = {}
        S.enchantPending = false
        S.enchantStopRequested = not state
        S.enchantExpectedStoneId = nil
        S.enchantExpectedTarget = nil
        S.enchantExpectedRodUUID = nil
        S.enchantRequestInventorySerial = nil
        if S.enchantThread then pcall(task.cancel,S.enchantThread) S.enchantThread = nil end
        Config.AutoEnchantReroll = state
        if not state then return end
        if not Remote.enchantAltar1 or not Remote.enchantAltar2 or not Remote.enchantRoll then
            UI.Library:Notify({Title="Orvion",Subtitle="Hub",Content="Enchant remote not found"})
            pcall(function() S.enchantToggle:Set(false) end)
            return
        end
        S.enchantInventorySerial = 0
        table.insert(S.enchantConns,Data.Player:OnChange({"Inventory","Items"},function()
            S.enchantInventorySerial = S.enchantInventorySerial + 1
            updateEnchantPara()
        end))
        table.insert(S.enchantConns,Remote.enchantRoll.OnClientEvent:Connect(function(_, enchantId, eventStoneId)
            if not S.enchantPending or S.enchantStopRequested then return end
            local eventSession = S.enchantSession
            if eventStoneId ~= nil and S.enchantExpectedStoneId ~= nil
                and tonumber(eventStoneId) ~= tonumber(S.enchantExpectedStoneId)
            then
                return
            end
            local enchantName = "Unknown"
            pcall(function()
                local d = Data.ItemUtility:GetEnchantData(enchantId)
                if d and d.Data then enchantName = d.Data.Name end
            end)
            if enchantName == S.enchantExpectedTarget then
                -- Stop permission is revoked immediately; UI turns off only
                -- after the final rod metadata has reached the paragraph.
                S.enchantStopRequested = true
                S.enchantPending = false
                local targetRodUUID = S.enchantExpectedRodUUID
                local targetEnchantId = enchantId
                local observedSerial = S.enchantRequestInventorySerial or S.enchantInventorySerial
                S.enchantExpectedStoneId = nil
                S.enchantExpectedTarget = nil
                S.enchantExpectedRodUUID = nil
                S.enchantRequestInventorySerial = nil

                task.spawn(function()
                    local replicated = S.rodHasEnchant(targetRodUUID,targetEnchantId)
                    local deadline = os.clock()+1.5
                    while Config.AutoEnchantReroll and S.enchantSession == eventSession
                        and not replicated and os.clock()<deadline
                    do
                        local currentSerial = S.enchantInventorySerial
                        if currentSerial ~= observedSerial then
                            observedSerial = currentSerial
                            replicated = S.rodHasEnchant(targetRodUUID,targetEnchantId)
                        end
                        task.wait(0.05)
                    end
                    if not Config.AutoEnchantReroll or S.enchantSession ~= eventSession then return end
                    updateEnchantPara()
                    if S.enchantSession ~= eventSession then return end
                    pcall(function() S.enchantToggle:Set(false) end)
                    UI.Library:Notify({Title="Orvion",Subtitle="Hub",Content="Enchant Completed - "..enchantName})
                end)
                return
            end
            task.delay(0.2, function()
                if Config.AutoEnchantReroll and S.enchantSession == eventSession then
                    updateEnchantPara()
                end
            end)
            S.enchantPending = false
            S.enchantExpectedStoneId = nil
            S.enchantExpectedTarget = nil
            S.enchantExpectedRodUUID = nil
            S.enchantRequestInventorySerial = nil
        end))
        updateEnchantPara()
        S.enchantThread = task.spawn(function()
            local equipFailures = 0
            while Config.AutoEnchantReroll and not S.enchantStopRequested do
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
                if not rodUUID then
                    updateEnchantPara()
                    UI.Library:Notify({Title="Orvion",Subtitle="Hub",Content="No rod equipped"})
                    pcall(function() S.enchantToggle:Set(false) end)
                    break
                end
                local stoneId = STONE_ID[Config.EnchantType] or 10
                local stoneUUID, stoneCountBefore = findEnchantStone(stoneId)
                if not stoneUUID then
                    updateEnchantPara()
                    UI.Library:Notify({Title="Orvion",Subtitle="Hub",Content="Enchant stones exhausted"})
                    pcall(function() S.enchantToggle:Set(false) end)
                    break
                end
                if not S.equipAndHold(stoneUUID,"Enchant Stones") then
                    equipFailures = equipFailures + 1
                    if equipFailures >= 3 then
                        UI.Library:Notify({Title="Orvion",Subtitle="Hub",Content="Unable to equip enchant stone"})
                        pcall(function() S.enchantToggle:Set(false) end)
                        break
                    end
                    task.wait(0.3)
                    continue
                end
                equipFailures = 0
                S.enchantPending = true
                S.enchantExpectedStoneId = stoneId
                S.enchantExpectedTarget = Config.TargetEnchant
                S.enchantExpectedRodUUID = rodUUID
                local inventorySerialBefore = S.enchantInventorySerial
                S.enchantRequestInventorySerial = inventorySerialBefore
                local sent
                if stoneId == 246 or stoneId == 1098 then
                    sent = pcall(function() Remote.enchantAltar2:FireServer() end)
                else
                    sent = pcall(function() Remote.enchantAltar1:FireServer(rodUUID) end)
                end
                if not sent then
                    S.enchantPending = false
                    S.enchantExpectedStoneId = nil
                    S.enchantExpectedTarget = nil
                    S.enchantExpectedRodUUID = nil
                    S.enchantRequestInventorySerial = nil
                    UI.Library:Notify({Title="Orvion",Subtitle="Hub",Content="Failed to start enchant"})
                    pcall(function() S.enchantToggle:Set(false) end)
                    break
                end
                local dl = os.clock()+12
                while S.enchantPending and os.clock()<dl do task.wait(0.05) end
                if S.enchantStopRequested then break end
                if S.enchantPending then
                    S.enchantPending = false
                    S.enchantExpectedStoneId = nil
                    S.enchantExpectedTarget = nil
                    S.enchantExpectedRodUUID = nil
                    S.enchantRequestInventorySerial = nil
                    UI.Library:Notify({Title="Orvion",Subtitle="Hub",Content="Enchant response timeout"})
                    pcall(function() S.enchantToggle:Set(false) end)
                    break
                end
                if not Config.AutoEnchantReroll then break end

                local remaining = stoneCountBefore
                local syncDeadline = os.clock()+1.5
                local observedSerial = inventorySerialBefore
                while Config.AutoEnchantReroll and os.clock()<syncDeadline do
                    local currentSerial = S.enchantInventorySerial
                    if currentSerial ~= observedSerial then
                        observedSerial = currentSerial
                        local _, currentCount = findEnchantStone(stoneId)
                        remaining = currentCount
                        if currentCount < stoneCountBefore then break end
                    end
                    task.wait(0.05)
                end
                if remaining == stoneCountBefore then
                    local _, currentCount = findEnchantStone(stoneId)
                    remaining = currentCount
                end
                if remaining <= 0 then
                    updateEnchantPara()
                    UI.Library:Notify({Title="Orvion",Subtitle="Hub",Content="Enchant stones exhausted"})
                    pcall(function() S.enchantToggle:Set(false) end)
                    break
                end
                task.wait(5.5)
            end
        end)
    end,"Toggle_Auto Enchant Reroll")
    UI.Window:AddButtonGrid(EnchantSection,
        {Title="Teleport to Altar 1",Callback=function()
            local char=Service.LocalPlayer.Character
            local root=char and char:FindFirstChild("HumanoidRootPart")
            Navigation.tryMoveRoot(root,CFrame.new(3246.00122,-1300.65588,1395.11926,-0.430797249,0,0.902448714,0,1,0,-0.902448714,0,-0.430797249),true)
        end},
        {Title="Teleport to Altar 2",Callback=function()
            local char=Service.LocalPlayer.Character
            local root=char and char:FindFirstChild("HumanoidRootPart")
            Navigation.tryMoveRoot(root,CFrame.new(1478.63489,130.679703,-609.361938,-0.996601522,2.26994281e-08,-0.0823735297,2.58843453e-08,1,-3.7596422e-08,0.0823735297,-3.96008382e-08,-0.996601522),true)
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
    local function inventoryHasFishUUID(UUID)
        local found = false
        local ok = pcall(function()
            local inv = Data.Player:Get("Inventory") or Data.Player.Data.Inventory
            if not inv then return end
            for cat, items in pairs(inv) do
                if type(items) ~= "table" then continue end
                for _, item in ipairs(items) do
                    if tostring(item.UUID or "") == tostring(UUID) then
                        local itemData = Data.ItemUtility.GetItemDataFromItemType(cat,item.Id or item.Identifier)
                        found = itemData and itemData.Data and itemData.Data.Type == "Fish" or false
                        return
                    end
                end
                if found then return end
            end
        end)
        return not ok or found
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
        Config.TranscendedAmount = math.max(1,math.floor(tonumber(v) or 1))
    end,"Input_Transcended Amount")
    S.transcendedToggle = UI.Window:AddToggle(TranscendedSection,"Enable Auto Create","",false,function(state)
        if S.transcendedInventoryConn then
            pcall(function() S.transcendedInventoryConn:Disconnect() end)
            S.transcendedInventoryConn=nil
        end
        if S.transcendedThread then pcall(task.cancel,S.transcendedThread) S.transcendedThread=nil end
        Config.AutoCreateTranscended = state
        if not state then return end
        if not Remote.createTranscended then
            setPara(S.transcendedPara,"Failed","Create Transcended remote not found")
            pcall(function() S.transcendedToggle:Set(false) end)
            return
        end
        S.transcendedInventorySerial = 0
        S.transcendedInventoryConn = Data.Player:OnChange({"Inventory","Items"},function()
            S.transcendedInventorySerial = S.transcendedInventorySerial + 1
        end)
        S.transcendedThread = task.spawn(function()
            local fishName = string.match(Config.SelectedSecretFish or "","^x%d+ (.+)$")
            if not fishName then
                setPara(S.transcendedPara,"Status","Please select a fish first")
                pcall(function() S.transcendedToggle:Set(false) end)
                return
            end
            local amount = math.max(1,math.floor(tonumber(Config.TranscendedAmount) or 1))
            local created = 0
            local failed = 0
            local stopReason = nil
            local equipFailures = 0
            while created < amount and Config.AutoCreateTranscended do
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
                    stopReason = "No "..fishName.." found"
                    break
                end
                setPara(S.transcendedPara,"Equipping",fishName)
                if not S.equipAndHold(fishUUID,"Fish") then
                    failed=failed+1
                    equipFailures=equipFailures+1
                    if equipFailures >= 3 then
                        stopReason = "Unable to equip "..fishName
                        break
                    end
                    task.wait(0.5)
                    continue
                end
                equipFailures=0
                setPara(S.transcendedPara,"Sacrificing","Create "..(created+1).."/"..amount.." - Done: "..created.." | Fail: "..failed)
                local inventorySerialBefore = S.transcendedInventorySerial
                local done,result,errMsg = false,false,"Timeout"
                local worker = task.spawn(function()
                    local ok,r,m = pcall(function() return Remote.createTranscended:InvokeServer() end)
                    if ok then
                        result=r
                        errMsg=tostring(m or "")
                    else
                        errMsg=tostring(r or "Create Transcended failed")
                    end
                    done = true
                end)
                local dl = os.clock()+10
                while not done and os.clock()<dl do task.wait(0.05) end
                if not done then pcall(task.cancel,worker) end
                if result then
                    created = created+1
                    setPara(S.transcendedPara,"Sacrificing","Create "..created.."/"..amount.." - Done: "..created.." | Fail: "..failed)
                else
                    stopReason = errMsg ~= "" and errMsg or "Create Transcended failed"
                    break
                end

                local syncDeadline = os.clock()+3
                local observedSerial = inventorySerialBefore
                local fishStillExists = true
                while Config.AutoCreateTranscended and os.clock()<syncDeadline do
                    local currentSerial = S.transcendedInventorySerial
                    if currentSerial ~= observedSerial then
                        observedSerial = currentSerial
                        fishStillExists = inventoryHasFishUUID(fishUUID)
                        if not fishStillExists then break end
                    end
                    task.wait(0.05)
                end
                if fishStillExists then
                    fishStillExists = inventoryHasFishUUID(fishUUID)
                end
                if fishStillExists then
                    stopReason = "Inventory sync timeout"
                    break
                end
                task.wait(0.1)
            end
            if Config.AutoCreateTranscended and created >= amount then
                setPara(S.transcendedPara,"Complete","Done: "..created.." | Fail: "..failed)
                UI.Library:Notify({Title="Orvion",Subtitle="Hub",Content="Done! Created "..created.." Transcended Stones"})
            elseif Config.AutoCreateTranscended and stopReason then
                setPara(S.transcendedPara,"Stopped",stopReason.."\nDone: "..created.."/"..amount.." | Fail: "..failed)
                UI.Library:Notify({Title="Orvion",Subtitle="Hub",Content=stopReason})
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
        local moved = Navigation.teleportToBM(S.BM_CF, true)
        if not moved then
            Config.AutoBuyBM = false
            S.autoBuyBMThread = nil
            if S.bmToggleFunc then task.defer(function() pcall(function() S.bmToggleFunc:Set(false) end) end) end
            return
        end
        task.wait(1.5)
        local bought = {}
        for _, name in ipairs(Config.SelectedBMItems) do
            if S.buyBMItem(name) then
                table.insert(bought, name)
            end
        end
        task.wait(0.5)
        if preBMCF and root then Navigation.tryMoveRoot(root, preBMCF) end
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

-- ==========================================
-- QUEST FEATURES
-- One coordinator owns all temporary listeners and fishing/sell holds.
-- Quest toggles are intentionally not persisted: executing the script only
-- reads progress and never starts movement or remote calls by itself.
-- ==========================================
do
    S.Quest = {
        Goals = {
            DeepSea = {
                { Goal=300, Text="Catch 300 Rare/Epic fish at Treasure Room" },
                { Goal=3, Text="Catch 3 Mythic fish at Sisyphus Statue" },
                { Goal=1, Text="Catch 1 SECRET fish at Sisyphus Statue" },
                { Goal=1000000, Text="Earn 1M Coins" },
            },
            Element = {
                { Goal=1, Text="Own Ghostfinn Rod" },
                { Goal=1, Text="Catch 1 SECRET fish at Ancient Jungle" },
                { Goal=1, Text="Catch 1 SECRET fish at Sacred Temple" },
                { Goal=3, Text="Create 3 Transcended Stones" },
            },
            Diamond = {
                { Goal=1, Text="Own an Element Rod" },
                { Goal=1, Text="Catch a SECRET fish at Coral Reefs" },
                { Goal=1, Text="Catch a SECRET fish at Tropical Grove" },
                { Goal=1, Text="Bring Lary a mutated Gemstone Ruby" },
                { Goal=1, Text="Bring Lary a Lochness Monster" },
                { Goal=1000, Text="Catch 1,000 fish using PERFECT! throw" },
            },
        },
        Artifacts = {
            { Type="Arrow Artifact", CFrame=CFrame.new(875,3.58514142,-368,-4.37113883e-08,0,1,0,1,0,-1,0,-4.37113883e-08) },
            { Type="Hourglass Diamond Artifact", CFrame=CFrame.new(1487,2.85159993,-842,-1,0,-8.74227766e-08,0,1,0,8.74227766e-08,0,-1) },
            { Type="Crescent Artifact", CFrame=CFrame.new(1403,3.16851091,123,-1,0,-8.74227766e-08,0,1,0,8.74227766e-08,0,-1) },
            { Type="Diamond Artifact", CFrame=CFrame.new(1844,2.85966992,-287,-4.37113883e-08,0,-1,0,1,0,1,0,-4.37113883e-08) },
        },
        Pressure = {
            { Type="Rare", Name="Freshwater Piranha" },
            { Type="Epic", Name="Goliath Tiger" },
            { Type="Legendary", Name="Sacred Guardian Squid" },
            { Type="Mythic", Name="Crocodile" },
        },
        DiamondDoor = CFrame.new(
            -1766.77087,-222.635422,23936.8965,
            -0.703928888,-9.02597677e-08,0.710270464,
            -9.39578726e-08,1,3.39590471e-08,
            -0.710270464,-4.28307452e-08,-0.703928888),
        ItemTypes = {"Fish", "Gears", "Fishing Rods", "Enchant Stones"},
        ItemDataCache = {},
        KnownIds = {
            ["Arrow Artifact"]=265, ["Crescent Artifact"]=266,
            ["Diamond Artifact"]=267, ["Hourglass Diamond Artifact"]=271,
            ["Ghostfinn Rod"]=169, ["Element Rod"]=257,
            ["Diamond Key"]=574, ["Diamond Rod"]=559,
        },
        Runners = {},
    }

    S.Quest.get = function(path)
        local value = nil
        pcall(function() value = Data.Player:Get(path) end)
        return value
    end

    S.Quest.getMainline = function(name)
        local state = S.Quest.get({"Quests","Mainline",name})
        if state ~= nil then return state end
        local quests = S.Quest.get("Quests")
        return quests and quests.Mainline and quests.Mainline[name] or nil
    end

    S.Quest.isCompleted = function(name)
        local completed = S.Quest.get("CompletedQuests") or {}
        if table.find(completed, name) then return true end
        return completed[name] == true
    end

    S.Quest.progress = function(name, index, goal)
        if S.Quest.isCompleted(name) then return goal end
        local state = S.Quest.getMainline(name)
        local objective = state and state.Objectives and state.Objectives[index]
        return math.clamp(tonumber(objective and objective.Progress) or 0, 0, goal)
    end

    S.Quest.eachInventoryItem = function(callback)
        local inventory = S.Quest.get("Inventory") or Data.Player.Data.Inventory
        if type(inventory) ~= "table" then return nil end
        for category, items in pairs(inventory) do
            if type(items) == "table" then
                for _, item in ipairs(items) do
                    if type(item) == "table" and item.Id ~= nil then
                        local cacheKey = tostring(item.Id)
                        local itemData = S.Quest.ItemDataCache[cacheKey]
                        local resolvedCategory = category
                        if itemData == nil then
                            pcall(function()
                                itemData = Data.ItemUtility.GetItemDataFromItemType(category, item.Id)
                            end)
                            for _, itemType in ipairs(S.Quest.ItemTypes) do
                                if itemData then break end
                                pcall(function()
                                    itemData = Data.ItemUtility.GetItemDataFromItemType(itemType, item.Id)
                                end)
                                if itemData then
                                    resolvedCategory = itemType
                                end
                            end
                            S.Quest.ItemDataCache[cacheKey] = itemData or false
                        elseif itemData == false then
                            itemData = nil
                        end
                        local data = itemData and itemData.Data or nil
                        local result = callback(item, resolvedCategory, data)
                        if result ~= nil then return result end
                    end
                end
            end
        end
        return nil
    end

    S.Quest.findItem = function(predicate)
        return S.Quest.eachInventoryItem(function(item, category, data)
            if predicate(item, category, data) then
                return { Item=item, Category=category, Data=data }
            end
        end)
    end

    S.Quest.findById = function(id, category, variant)
        local inventory = S.Quest.get("Inventory") or Data.Player.Data.Inventory
        if type(inventory) ~= "table" then return nil end
        local function checkItems(items, cat)
            for _, item in ipairs(items or {}) do
                if type(item) == "table" and tonumber(item.Id) == tonumber(id) then
                    local metadata = item.Metadata or {}
                    if not variant or metadata.Variant == variant
                        or metadata.VariantId == variant
                    then
                        return { Item=item, Category=cat }
                    end
                end
            end
            return nil
        end
        if category then
            return checkItems(inventory[category], category)
        end
        for cat, items in pairs(inventory) do
            if type(items) == "table" then
                local result = checkItems(items, cat)
                if result then return result end
            end
        end
        return nil
    end

    S.Quest.findByName = function(name)
        local id = S.Quest.KnownIds[name]
        local resolvedType = nil
        if not id then
            for _, itemType in ipairs(S.Quest.ItemTypes) do
                local itemData = nil
                pcall(function()
                    itemData = Data.ItemUtility.GetItemDataFromItemType(itemType, name)
                end)
                if itemData and itemData.Data then
                    id = itemData.Data.Id
                    resolvedType = itemType
                    S.Quest.KnownIds[name] = id
                    break
                end
            end
        end
        return id and S.Quest.findById(id, resolvedType) or nil
    end

    S.Quest.findFish = function(id, variant)
        return S.Quest.findById(id, "Fish", variant)
    end

    S.Quest.findSecret = function()
        return S.Quest.findItem(function(_, _, data)
            return data and data.Type == "Fish" and tonumber(data.Tier) == 7
        end)
    end

    S.Quest.hasUUID = function(uuid)
        local inventory = S.Quest.get("Inventory") or Data.Player.Data.Inventory
        if type(inventory) ~= "table" then return false end
        for _, items in pairs(inventory) do
            if type(items) == "table" then
                for _, item in ipairs(items) do
                    if type(item) == "table"
                        and tostring(item.UUID or "") == tostring(uuid or "")
                    then
                        return true
                    end
                end
            end
        end
        return false
    end

    S.Quest.owns = function(name)
        return S.Quest.findByName(name) ~= nil
    end

    S.Quest.isActive = function(job)
        return Runtime.Quest.Enabled[job] == true
    end

    -- waitJob: poll predicate sampai true/timeout, exit kalau Enabled[job] false
    -- Tidak pakai job/generation — cukup cek Enabled[job]
    S.Quest.waitJob = function(job, predicate, timeout, interval)
        local deadline = timeout and (os.clock() + timeout) or nil
        while Runtime.Quest.Enabled[job] == true do
            local ok, result = pcall(predicate)
            if ok and result then return true end
            if deadline and os.clock() >= deadline then return false end
            task.wait(interval or 0.1)
        end
        return false
    end

    -- teleport helper tanpa LastLocation tracking
    S.Quest.teleport = function(destination)
        if typeof(destination) == "CFrame" then
            local character = Service.LocalPlayer.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            return Navigation.tryMoveRoot(root, destination, false)
        else
            return Navigation.teleportTo(destination, false)
        end
    end

    -- withSellHold: counter-based + fishing cycle guard
    -- 1. SellHold+1 → block autosell + auto equip rod
    -- 2. Tunggu fishing phase idle + owner nil (max 3s)
    -- 3. Set Owner="Quest" → block cycle BARU dimulai (WaitReady cek Owner)
    -- 4. Jalankan fn (equip ikan/key, fire remote, dll)
    -- 5. Release Owner + SellHold
    S.Quest.withSellHold = function(fn)
        Runtime.Quest.SellHold = Runtime.Quest.SellHold + 1
        -- Tunggu cycle yang sedang jalan selesai (max 8s)
        -- Re-check setelah timeout supaya 2 caller tidak concurrent equip
        local waitDeadline = os.clock() + 8
        while (Runtime.Fishing.Phase ~= "Idle" or Runtime.Fishing.Owner ~= nil)
            and os.clock() < waitDeadline
        do
            task.wait(0.05)
        end
        -- Block cycle baru dimulai
        Runtime.Fishing.Owner = "Quest"
        local ok, err = pcall(fn)
        -- Release fishing owner kalau masih milik kita
        if Runtime.Fishing.Owner == "Quest" then
            Runtime.Fishing.Owner = nil
        end
        Runtime.Quest.SellHold = Runtime.Quest.SellHold - 1
        if Runtime.Quest.SellHold < 0 then Runtime.Quest.SellHold = 0 end
        if Runtime.Quest.SellHold == 0 then
            task.defer(function()
                if Runtime.Sell.Pending and Runtime.Fishing.Phase == "Idle" then
                    Runtime.Sell.Flush()
                end
            end)
        end
        return ok, err
    end

    -- equipRodCanonical: equip progression rod agresif (mirip buy rod)
    -- Tidak pakai withSellHold — rod bukan ikan yang bisa kejual
    S.Quest.equipRodCanonical = function(job, uuid)
        return S.equipAndHold(uuid, "Fishing Rods", function()
            return Runtime.Quest.Enabled[job] == true
        end)
    end

    -- equipRodWithRetry: retry 5x cek Replion EquippedId dinamis
    -- Tidak pakai withSellHold — rod tidak perlu lindungi dari autosell
    S.Quest.equipRodWithRetry = function(job, uuid)
        local equipped = false
        for attempt = 1, 5 do
            if Runtime.Quest.Enabled[job] ~= true then break end
            local currentId = tostring(Data.Player:Get("EquippedId") or "")
            if currentId == uuid then
                equipped = true
                break
            end
            local ok = S.equipAndHold(uuid, "Fishing Rods", function()
                return Runtime.Quest.Enabled[job] == true
            end)
            if ok then
                equipped = true
                break
            end
            local acked = S.Quest.waitJob(job, function()
                return tostring(Data.Player:Get("EquippedId") or "") == uuid
            end, 2, 0.1)
            if acked then
                equipped = true
                break
            end
            if attempt < 5 then task.wait(2) end
        end
        return equipped
    end

    -- placeStateItem: fire remote + waitJob Replion ack, max 3 retry jeda 1s
    -- Tidak pakai withSellHold — artifact items tidak bisa di-sell
    -- Caller yang butuh SellHold (Crystalline dll) sudah wrap sendiri
    S.Quest.placeStateItem = function(job, remote, stateKey, typeName)
        if not remote then return false end
        local ok = false
        for attempt = 1, 3 do
            if Runtime.Quest.Enabled[job] ~= true then break end
            local state = S.Quest.get(stateKey) or {}
            if state[typeName] == true then ok = true; break end
            pcall(function() remote:FireServer(typeName) end)
            local acked = S.Quest.waitJob(job, function()
                local s = S.Quest.get(stateKey) or {}
                return s[typeName] == true
            end, 8, 0.1)
            if acked then ok = true; break end
            if attempt < 3 then task.wait(2) end
        end
        return ok
    end

    -- exchangeItem: dialogueEnded + waitJob progress ack, max 3 retry
    -- double-fire guard: cek progress sebelum fire
    S.Quest.exchangeItem = function(job, questName, objectiveId, args)
        local before = S.Quest.progress(questName, objectiveId, 1)
        local ok = false
        S.Quest.withSellHold(function()
            for attempt = 1, 3 do
                if Runtime.Quest.Enabled[job] ~= true then break end
                if S.Quest.progress(questName, objectiveId, 1) > before
                    or S.Quest.isCompleted(questName)
                then ok = true; break end
                if not Remote.dialogueEnded then break end
                pcall(function() Remote.dialogueEnded:FireServer(table.unpack(args)) end)
                local acked = S.Quest.waitJob(job, function()
                    return S.Quest.progress(questName, objectiveId, 1) > before
                        or S.Quest.isCompleted(questName)
                end, 10, 0.1)
                if acked then ok = true; break end
                if attempt < 3 then task.wait(2) end
            end
        end)
        return ok
    end

    -- createTranscended: equip secret fish (tier 7) + InvokeServer + wait consumed
    S.Quest.createTranscended = function(job, entry)
        local uuid = entry and entry.Item and entry.Item.UUID
        if not uuid then return false end
        if not Remote.createTranscended then return false end
        local ok = false
        S.Quest.withSellHold(function()
            -- Lepas rod dari tangan dulu sebelum equip secret fish
            pcall(function() Remote.unequipTool:FireServer() end)
            local dropDeadline = os.clock() + 1
            while os.clock() < dropDeadline do
                if tostring(Data.Player:Get("EquippedId") or "") == "" then break end
                task.wait(0.05)
            end
            if not S.equipAndHold(uuid, "Fish", function()
                return Runtime.Quest.Enabled[job] == true
            end) then return end
            local done, result = false, false
            local invokeThread = task.spawn(function()
                local callOk, response = pcall(function()
                    return Remote.createTranscended:InvokeServer()
                end)
                result = callOk and response == true
                done = true
            end)
            local deadline = os.clock() + 10
            while Runtime.Quest.Enabled[job] == true and not done
                and os.clock() < deadline
            do
                task.wait(0.05)
            end
            if not done then pcall(task.cancel, invokeThread) end
            if not result then return end
            local consumed = S.Quest.waitJob(job, function()
                return not S.Quest.hasUUID(uuid)
            end, 4, 0.05)
            if consumed then ok = true end
        end)
        return ok
    end

    -- findPressureFish: lookup via category "Items" (confirmed dari probe4 controller)
    S.Quest.findPressureFish = function(fishName)
        local inventory = S.Quest.get("Inventory") or Data.Player.Data.Inventory
        if type(inventory) ~= "table" then return nil end
        local itemData = nil
        pcall(function()
            itemData = Data.ItemUtility.GetItemDataFromItemType("Items", fishName)
        end)
        if not itemData or not itemData.Data then return nil end
        local targetId = itemData.Data.Id
        local items = inventory.Items or {}
        for _, item in ipairs(items) do
            if type(item) == "table" and tonumber(item.Id) == tonumber(targetId) then
                return { Item = item, Category = "Items", Data = itemData.Data }
            end
        end
        return nil
    end

    -- placePressureFishEntry: equip ikan + fire + waitJob ack, max 3 retry
    -- smart hotbar: evict slot ujung kalau penuh, restore setelah
    S.Quest.placePressureFishEntry = function(job, definition)
        local ok = false
        S.Quest.withSellHold(function()
            -- Lepas rod dari tangan dulu (bukan dari hotbar)
            -- supaya slot tangan kosong dan bisa pegang ikan
            -- SellHold > 0 sudah block Auto Equip Rod
            pcall(function() Remote.unequipTool:FireServer() end)
            -- Tunggu EquippedId kosong (max 1s)
            local dropDeadline = os.clock() + 1
            while os.clock() < dropDeadline do
                local eid = tostring(Data.Player:Get("EquippedId") or "")
                if eid == "" then break end
                task.wait(0.05)
            end
            for attempt = 1, 3 do
                if Runtime.Quest.Enabled[job] ~= true then break end
                -- cek plate sudah aktif (awal tiap attempt)
                local plates = S.Quest.get("RuinPressurePlates") or {}
                if plates[definition.Name] == true then ok = true; break end
                local entry = S.Quest.findPressureFish(definition.Name)
                if not entry then
                    -- Replion mungkin belum sync, retry di attempt berikutnya
                    if attempt < 3 then task.wait(2) end
                else
                local uuid = entry.Item.UUID
                local itemType = (entry.Data and entry.Data.Type) or "Items"
                -- smart hotbar evict
                local restoredEntry = nil
                local equippedItems = Data.Player:Get("EquippedItems") or {}
                if not table.find(equippedItems, uuid) and #equippedItems >= 5 then
                    for slotIdx = #equippedItems, 2, -1 do
                        local evictUUID = equippedItems[slotIdx]
                        if evictUUID and evictUUID ~= uuid then
                            -- Set restoredEntry DULU sebelum unequip + wait
                            -- supaya bisa restore meski job di-cancel saat menunggu
                            local evictEntry = { UUID = evictUUID, ItemType = "Items" }
                            S.Quest.eachInventoryItem(function(item, category, data)
                                if tostring(item.UUID or "") == tostring(evictUUID) then
                                    evictEntry.ItemType = (data and data.Type) or category or "Items"
                                    return true
                                end
                            end)
                            pcall(function() Remote.unequipItem:FireServer(evictUUID) end)
                            local removeDeadline = os.clock() + 2
                            while os.clock() < removeDeadline do
                                if Runtime.Quest.Enabled[job] ~= true then
                                    -- Job di-cancel: restore item yang sudah di-unequip
                                    pcall(function() Remote.equipItem:FireServer(evictEntry.UUID, evictEntry.ItemType) end)
                                    return
                                end
                                local eq = Data.Player:Get("EquippedItems") or {}
                                if not table.find(eq, evictUUID) then break end
                                task.wait(0.05)
                            end
                            restoredEntry = evictEntry
                            break
                        end
                    end
                end
                local held = S.equipAndHold(uuid, itemType, function()
                    return Runtime.Quest.Enabled[job] == true
                end)
                if not held then
                    if restoredEntry then
                        pcall(function() Remote.equipItem:FireServer(restoredEntry.UUID, restoredEntry.ItemType) end)
                    end
                    if attempt < 3 then task.wait(2) end
                else
                    if Remote.placePressure then
                        pcall(function() Remote.placePressure:FireServer(definition.Name) end)
                    end
                    local acked = S.Quest.waitJob(job, function()
                        local state = S.Quest.get("RuinPressurePlates") or {}
                        return state[definition.Name] == true
                    end, 8, 0.1)
                    if restoredEntry then
                        pcall(function() Remote.equipItem:FireServer(restoredEntry.UUID, restoredEntry.ItemType) end)
                    end
                    pcall(function() Remote.equipTool:FireServer(1) end)
                    if acked then ok = true; break end
                    if attempt < 3 then task.wait(2) end
                end
                end -- end else entry
            end
        end)
        return ok
    end

    -- openAndClaimDiamond: teleport door + equip key + proximity + claim
    S.Quest.openAndClaimDiamond = function(job, keyEntry)
        local uuid = keyEntry and keyEntry.Item and keyEntry.Item.UUID
        if not uuid then return false end
        local ok = false
        S.Quest.withSellHold(function()
            -- KRITIS: equip key DULU sebelum teleport ke door
            -- Lepas rod dari tangan dulu supaya bisa pegang key
            pcall(function() Remote.unequipTool:FireServer() end)
            local dropDeadline = os.clock() + 1
            while os.clock() < dropDeadline do
                if tostring(Data.Player:Get("EquippedId") or "") == "" then break end
                task.wait(0.05)
            end
            if not S.equipAndHold(uuid, "Gears", function()
                return Runtime.Quest.Enabled[job] == true
            end) then return end
            -- Setelah key di tangan, baru teleport ke door
            S.Quest.teleport(S.Quest.DiamondDoor)
            local prompt = nil
            local promptReady = S.Quest.waitJob(job, function()
                local doors = Service.CollectionService:GetTagged("DiamondDoor")
                local door = doors[1]
                local input = door and door:FindFirstChild("InputPart")
                prompt = input and input:FindFirstChildOfClass("ProximityPrompt")
                return prompt and prompt.Enabled
            end, 6, 0.05)
            if not promptReady or type(fireproximityprompt) ~= "function" then return end
            pcall(fireproximityprompt, prompt)
            S.Quest.waitJob(job, function()
                return prompt.Parent == nil or prompt.Enabled == false
            end, 3, 0.05)
            if not Remote.claimItem then return end
            local done, claimed = false, false
            local claimThread = task.spawn(function()
                local callOk, result = pcall(function()
                    return Remote.claimItem:InvokeServer("Diamond Rod")
                end)
                claimed = callOk and result ~= false
                done = true
            end)
            local deadline = os.clock() + 10
            while Runtime.Quest.Enabled[job] == true and not done
                and os.clock() < deadline
            do
                task.wait(0.05)
            end
            if not done then pcall(task.cancel, claimThread) end
            if not claimed then return end
            local received = S.Quest.waitJob(job, function()
                return S.Quest.owns("Diamond Rod")
            end, 8, 0.1)
            if received then ok = true end
        end)
        return ok
    end

    S.Quest.isRuinFishingLocation = function()
        local locationName = nil
        pcall(function()
            locationName = Service.LocalPlayer:GetAttribute("LocationName")
            local character = Service.LocalPlayer.Character
            locationName = locationName or (character
                and character:GetAttribute("LocationName"))
        end)
        if locationName == "Ancient Jungle"
            or locationName == "Sacred Temple"
        then
            return true
        end
        local character = Service.LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not root then return false end
        local ancient = Catalog.Locations["Ancient Jungle"]
        local sacred = Catalog.Locations["Sacred Temple"]
        return (ancient
                and (root.Position - ancient.Position).Magnitude <= 900)
            or (sacred
                and (root.Position - sacred.Position).Magnitude <= 900)
            or false
    end

    -- ====== INDEPENDENT RUNNERS — table assignment pattern ======

    -- startJobThread: cancel existing thread, spawn new one
    S.Quest.startJobThread = function(job, fn)
        local existing = Runtime.Quest.Threads[job]
        if existing then
            pcall(task.cancel, existing)
            Runtime.Quest.Threads[job] = nil
            -- Reset SellHold + Owner — thread lama yang di-cancel tidak bisa release sendiri
            Runtime.Quest.SellHold = 0
            if Runtime.Fishing.Owner == "Quest" then
                Runtime.Fishing.Owner = nil
            end
            task.defer(function()
                if Runtime.Sell.Pending and Runtime.Fishing.Phase == "Idle" then
                    Runtime.Sell.Flush()
                end
            end)
        end
        Runtime.Quest.Threads[job] = task.spawn(function()
            pcall(fn)
            Runtime.Quest.Threads[job] = nil
        end)
    end

    -- ARTIFACT: teleport ke tiap CFrame, place lever jika item ada, max 3 retry
    S.Quest.Runners.Artifact = function()
        local lastTeleport = nil  -- cache by definition.Type
        while Runtime.Quest.Enabled.Artifact == true do
            local rawLevers = S.Quest.get("TempleLevers")
            if rawLevers ~= nil then
                -- Replion sudah load — proses normal
                local allDone = true
                for _, definition in ipairs(S.Quest.Artifacts) do
                    if rawLevers[definition.Type] ~= true then
                        allDone = false
                        local item = S.Quest.findByName(definition.Type)
                        if item then
                            -- item ada → teleport dan place
                            if lastTeleport ~= definition.Type then
                                S.Quest.teleport(definition.CFrame)
                                lastTeleport = definition.Type
                            end
                            lastTeleport = nil
                            S.Quest.placeStateItem(
                                "Artifact", Remote.placeLever,
                                "TempleLevers", definition.Type)
                        else
                            -- item belum ada → teleport nunggu fishing dapat item
                            if lastTeleport ~= definition.Type then
                                S.Quest.teleport(definition.CFrame)
                                lastTeleport = definition.Type
                            end
                        end
                        break
                    end
                end
                if allDone then
                    Runtime.Quest.Enabled.Artifact = false
                    break
                end
            end
            -- rawLevers nil: Replion belum load, retry 0.4s
            task.wait(0.4)
        end
    end

    -- DEEPSEA: activate quest di Sisyphus, loop per objective
    S.Quest.Runners.DeepSea = function()
        if not S.Quest.getMainline("Deep Sea Quest")
            and not S.Quest.isCompleted("Deep Sea Quest")
            and not S.Quest.owns("Ghostfinn Rod")
        then
            S.Quest.teleport("Sisyphus Statue")
            S.Quest.waitJob("DeepSea", function()
                return S.Quest.getMainline("Deep Sea Quest") ~= nil
                    or S.Quest.isCompleted("Deep Sea Quest")
            end, 8, 0.1)
        end
        local lastTeleport = nil
        while Runtime.Quest.Enabled.DeepSea == true do
            local ghostfinn = S.Quest.findByName("Ghostfinn Rod")
            if ghostfinn then
                local uuid = ghostfinn.Item and ghostfinn.Item.UUID
                if uuid then
                    S.Quest.equipRodWithRetry("DeepSea", uuid)
                end
                -- Cek dinamis: stop hanya kalau uuid valid DAN sudah terpasang
                if uuid and tostring(Data.Player:Get("EquippedId") or "") == uuid then
                    Runtime.Quest.Enabled.DeepSea = false
                    break
                end
            end
            local objective = nil
            for index, definition in ipairs(S.Quest.Goals.DeepSea) do
                if S.Quest.progress("Deep Sea Quest", index, definition.Goal) < definition.Goal then
                    objective = index
                    break
                end
            end
            local targetLoc = nil
            if objective == 1 then
                targetLoc = "Treasure Room"
            elseif objective == 2 or objective == 3 then
                targetLoc = "Sisyphus Statue"
            end
            if targetLoc and lastTeleport ~= targetLoc then
                S.Quest.teleport(targetLoc)
                lastTeleport = targetLoc
            end
            task.wait(0.5)
        end
    end

    -- ELEMENT: silent wait eligibility (Ghostfinn), activate di AJ, loop per objective
    S.Quest.Runners.Element = function()
        -- Silent eligibility: tunggu Ghostfinn Rod via Replion, tidak update panel
        while Runtime.Quest.Enabled.Element == true do
            if S.Quest.owns("Ghostfinn Rod") then break end
            task.wait(2)
        end
        if Runtime.Quest.Enabled.Element ~= true then return end
        if not S.Quest.getMainline("Element Quest")
            and not S.Quest.isCompleted("Element Quest")
            and not S.Quest.owns("Element Rod")
        then
            S.Quest.teleport("Ancient Jungle")
            S.Quest.waitJob("Element", function()
                return S.Quest.getMainline("Element Quest") ~= nil
                    or S.Quest.isCompleted("Element Quest")
            end, 8, 0.1)
        end
        local lastTeleport = nil
        while Runtime.Quest.Enabled.Element == true do
            if S.Quest.owns("Element Rod") then
                local rod = S.Quest.findByName("Element Rod")
                local uuid = rod and rod.Item and rod.Item.UUID
                if uuid then
                    S.Quest.equipRodWithRetry("Element", uuid)
                end
                -- Cek dinamis: stop hanya kalau uuid valid DAN sudah terpasang
                if uuid and tostring(Data.Player:Get("EquippedId") or "") == uuid then
                    Runtime.Quest.Enabled.Element = false
                    break
                end
            end
            local targetLoc = nil
            if S.Quest.progress("Element Quest", 2, 1) < 1 then
                -- Kalau Artifact ON, skip teleport — Artifact navigasi di AJ sudah cukup
                -- karakter di lever spot (AJ) bisa catch AJ secret fish juga
                if not Runtime.Quest.Enabled.Artifact then
                    targetLoc = "Ancient Jungle"
                end
            elseif S.Quest.progress("Element Quest", 3, 1) < 1 then
                if S.Quest.get("UnlockedTemple") == true then
                    targetLoc = "Sacred Temple"
                end
                -- else: STAY — UnlockedTemple false, loop 0.35s sampai Replion update
            elseif S.Quest.progress("Element Quest", 4, 3) < 3 then
                local level = tonumber(S.Quest.get("Level")) or 0
                if level >= 200 then
                    local secret = S.Quest.findSecret()
                    if secret then
                        lastTeleport = nil  -- reset — setelah createTranscended lokasi mungkin berubah
                        S.Quest.createTranscended("Element", secret)
                    end
                end
            end
            if targetLoc and lastTeleport ~= targetLoc then
                S.Quest.teleport(targetLoc)
                lastTeleport = targetLoc
            end
            task.wait(0.35)
        end
    end

    -- DIAMOND: silent wait eligibility, activate quest, loop per objective
    S.Quest.Runners.Diamond = function()
        -- Silent eligibility
        while Runtime.Quest.Enabled.Diamond == true do
            if S.Quest.owns("Element Rod")
                or S.Quest.progress("Diamond Researcher", 1, 1) >= 1
                or S.Quest.owns("Diamond Key")
                or S.Quest.owns("Diamond Rod")
            then break end
            task.wait(2)
        end
        if Runtime.Quest.Enabled.Diamond ~= true then return end
        if not S.Quest.getMainline("Diamond Researcher")
            and not S.Quest.isCompleted("Diamond Researcher")
            and not S.Quest.owns("Diamond Key")
            and not S.Quest.owns("Diamond Rod")
        then
            if Remote.dialogueEnded then
                pcall(function()
                    Remote.dialogueEnded:FireServer("Diamond Researcher", 1, 2)
                end)
                S.Quest.waitJob("Diamond", function()
                    return S.Quest.getMainline("Diamond Researcher") ~= nil
                        or S.Quest.owns("Diamond Key")
                end, 6, 0.1)
            end
        end
        local lastTeleport = nil  -- cache: cegah teleport spam tiap 0.4s ke lokasi sama
        while Runtime.Quest.Enabled.Diamond == true do
            if S.Quest.owns("Diamond Rod") then
                local rod = S.Quest.findByName("Diamond Rod")
                local uuid = rod and rod.Item and rod.Item.UUID
                if uuid then
                    S.Quest.equipRodWithRetry("Diamond", uuid)
                end
                -- Cek dinamis: stop hanya kalau uuid valid DAN sudah terpasang
                if uuid and tostring(Data.Player:Get("EquippedId") or "") == uuid then
                    Runtime.Quest.Enabled.Diamond = false
                    break
                end
            end
            if S.Quest.owns("Diamond Key") then
                lastTeleport = nil
                local key = S.Quest.findByName("Diamond Key")
                S.Quest.openAndClaimDiamond("Diamond", key)
            elseif S.Quest.progress("Diamond Researcher", 2, 1) < 1 then
                if lastTeleport ~= "Coral Reefs" then
                    S.Quest.teleport("Coral Reefs")
                    lastTeleport = "Coral Reefs"
                end
            elseif S.Quest.progress("Diamond Researcher", 3, 1) < 1 then
                if lastTeleport ~= "Tropical Grove" then
                    S.Quest.teleport("Tropical Grove")
                    lastTeleport = "Tropical Grove"
                end
            elseif S.Quest.progress("Diamond Researcher", 4, 1) < 1 then
                local ruby = S.Quest.findFish(243, "Gemstone")
                if ruby then
                    lastTeleport = nil
                    S.Quest.exchangeItem("Diamond", "Diamond Researcher", 4,
                        {"Diamond Researcher", 2, 1})
                elseif lastTeleport ~= "Treasure Room" then
                    S.Quest.teleport("Treasure Room")
                    lastTeleport = "Treasure Room"
                end
            elseif S.Quest.progress("Diamond Researcher", 5, 1) < 1 then
                local lochness = S.Quest.findFish(228)
                if lochness then
                    lastTeleport = nil
                    S.Quest.exchangeItem("Diamond", "Diamond Researcher", 5,
                        {"Diamond Researcher", 2, 2})
                elseif lastTeleport ~= "Kohana" then
                    S.Quest.teleport("Kohana")
                    lastTeleport = "Kohana"
                end
            else
                -- obj6 (1000 perfect): diam, panel update via Replion OnChange("Quests")
                lastTeleport = nil
            end
            task.wait(0.4)
        end
    end

    -- CRYSTALLINE (pure event-driven via OnFishCaught)
    -- CrystallineBusy: guard double-attempt per fishName
    S.Quest.CrystallineBusy = {}

    Runtime.Quest.OnFishCaught = function(fishName, metadata)
        -- CRYSTALLINE: event-driven place pressure fish
        if Runtime.Quest.Enabled.Crystalline == true then
            local plates = S.Quest.get("RuinPressurePlates") or {}
            local targetDef = nil
            for _, definition in ipairs(S.Quest.Pressure) do
                if definition.Name == fishName and plates[definition.Name] ~= true then
                    targetDef = definition
                    break
                end
            end
            if targetDef then
                if not S.Quest.CrystallineBusy[fishName] then
                    S.Quest.CrystallineBusy[fishName] = true
                    -- SellHold+1 SYNCHRONOUS sebelum task.spawn
                    -- supaya autosell tidak bisa fire di gap antara FishCaught dan spawn
                    Runtime.Quest.SellHold = Runtime.Quest.SellHold + 1
                    task.spawn(function()
                        pcall(function()
                            S.Quest.placePressureFishEntry("Crystalline", targetDef)
                        end)
                        S.Quest.CrystallineBusy[fishName] = nil
                        -- Release SellHold setelah selesai (placePressureFishEntry punya withSellHold sendiri)
                        -- tapi kita sudah +1 di sini jadi perlu -1 juga
                        Runtime.Quest.SellHold = Runtime.Quest.SellHold - 1
                        if Runtime.Quest.SellHold < 0 then Runtime.Quest.SellHold = 0 end
                        if Runtime.Quest.SellHold == 0 then
                            task.defer(function()
                                if Runtime.Sell.Pending and Runtime.Fishing.Phase == "Idle" then
                                    Runtime.Sell.Flush()
                                end
                            end)
                        end
                        Runtime.Quest.RefreshPanels()
                    end)
                end
            end
        end

        -- DIAMOND: protect Ruby dan Lochness dari autosell
        -- Diamond loop jalan tiap 0.4s — SellHold+1 bridging gap antara
        -- FishCaught dan loop iteration berikutnya yang akan exchange via withSellHold
        if Runtime.Quest.Enabled.Diamond == true then
            local variant = type(metadata) == "table"
                and (metadata.Variant or metadata.VariantId) or nil
            local needProtect =
                (S.Quest.progress("Diamond Researcher", 4, 1) < 1
                    and fishName == "Ruby" and variant == "Gemstone")
                or (S.Quest.progress("Diamond Researcher", 5, 1) < 1
                    and fishName == "Lochness Monster")
            if needProtect then
                Runtime.Quest.SellHold = Runtime.Quest.SellHold + 1
                -- Selalu release setelah 2s — jendela bridge untuk Diamond loop 0.4s
                -- withSellHold dari loop exchange punya counter sendiri (+1/-1 net 0)
                -- Tanpa ini, SellHold stuck di 1 selamanya kalau Diamond masih ON
                task.delay(2, function()
                    Runtime.Quest.SellHold = Runtime.Quest.SellHold - 1
                    if Runtime.Quest.SellHold < 0 then Runtime.Quest.SellHold = 0 end
                    if Runtime.Quest.SellHold == 0 then
                        task.defer(function()
                            if Runtime.Sell.Pending
                                and Runtime.Fishing.Phase == "Idle"
                            then
                                Runtime.Sell.Flush()
                            end
                        end)
                    end
                end)
            end
        end
    end

    -- Panel refresh loop: jalan saat ada quest aktif, stop saat semua OFF
    -- Cek apakah minimal 1 quest masih ON
    Runtime.Quest.anyEnabled = function()
        for _, job in ipairs({"Artifact","DeepSea","Element","Diamond","Crystalline"}) do
            if Runtime.Quest.Enabled[job] then return true end
        end
        return false
    end

    local function startPanelLoop()
        if Runtime.Quest.PanelThread then return end
        Runtime.Quest.PanelThread = task.spawn(function()
            while Runtime.Quest.anyEnabled() do
                task.wait(0.5)
                Runtime.Quest.RefreshPanels()
            end
            Runtime.Quest.PanelThread = nil
        end)
    end

    -- ====== START / STOP ======

    Runtime.Quest.Start = function(job)
        Runtime.Quest.Enabled[job] = true
        startPanelLoop()
        if job == "Artifact" or job == "DeepSea"
            or job == "Element" or job == "Diamond"
        then
            S.Quest.startJobThread(job, S.Quest.Runners[job])
        elseif job == "Crystalline" then
            -- Startup scan: sequential satu per satu, retry per ikan jeda 2s
            task.spawn(function()
                if Runtime.Quest.Enabled.Crystalline ~= true then return end
                local plates = S.Quest.get("RuinPressurePlates") or {}
                for _, definition in ipairs(S.Quest.Pressure) do
                    if Runtime.Quest.Enabled.Crystalline ~= true then break end
                    if plates[definition.Name] ~= true then
                        -- Retry per ikan sampai berhasil atau toggle OFF
                        while Runtime.Quest.Enabled.Crystalline == true do
                            plates = S.Quest.get("RuinPressurePlates") or {}
                            if plates[definition.Name] == true then break end
                            if not S.Quest.CrystallineBusy[definition.Name]
                                and S.Quest.findPressureFish(definition.Name)
                            then
                                S.Quest.CrystallineBusy[definition.Name] = true
                                Runtime.Quest.SellHold = Runtime.Quest.SellHold + 1
                                pcall(function()
                                    S.Quest.placePressureFishEntry("Crystalline", definition)
                                end)
                                S.Quest.CrystallineBusy[definition.Name] = nil
                                Runtime.Quest.SellHold = Runtime.Quest.SellHold - 1
                                if Runtime.Quest.SellHold < 0 then Runtime.Quest.SellHold = 0 end
                                Runtime.Quest.RefreshPanels()
                                plates = S.Quest.get("RuinPressurePlates") or {}
                                if plates[definition.Name] == true then break end
                            else
                                -- Ikan belum ada di inventory, tidak perlu retry
                                break
                            end
                            task.wait(2)
                        end
                    end
                end
                if Runtime.Quest.SellHold == 0 then
                    task.defer(function()
                        if Runtime.Sell.Pending and Runtime.Fishing.Phase == "Idle" then
                            Runtime.Sell.Flush()
                        end
                    end)
                end
            end)
        end
    end

    Runtime.Quest.Stop = function(job)
        Runtime.Quest.Enabled[job] = false
        local thread = Runtime.Quest.Threads[job]
        if thread then
            pcall(task.cancel, thread)
            Runtime.Quest.Threads[job] = nil
        end
        -- Force SellHold=0 + release Owner — task.cancel tidak di-catch pcall
        Runtime.Quest.SellHold = 0
        if Runtime.Fishing.Owner == "Quest" then
            Runtime.Fishing.Owner = nil
        end
        task.defer(function()
            if Runtime.Sell.Pending and Runtime.Fishing.Phase == "Idle" then
                Runtime.Sell.Flush()
            end
        end)
    end

    S.Quest.formatQuestPanel = function(questName, goals, rewardName, completedText)
        if S.Quest.isCompleted(questName) or S.Quest.owns(rewardName) then
            return "✅ " .. completedText
        end
        local lines = {}
        for index, definition in ipairs(goals) do
            local current = S.Quest.progress(questName, index, definition.Goal)
            table.insert(lines, string.format(
                "%d. %s: %s/%s", index, definition.Text,
                tostring(current), tostring(definition.Goal)))
        end
        return table.concat(lines, "\n")
    end

    S.Quest.refreshArtifactPanel = function()
        local state = S.Quest.get("TempleLevers") or {}
        local lines, allActive = {}, true
        for _, definition in ipairs(S.Quest.Artifacts) do
            local active = state[definition.Type] == true
            allActive = allActive and active
            table.insert(lines, definition.Type .. ": " .. (active and "Active" or "Inactive"))
        end
        S.setParagraphText(Runtime.Quest.Panels.Artifact,
            allActive and "✅ ALL ARTIFACTS ACTIVE\n" .. table.concat(lines, "\n")
                or table.concat(lines, "\n"))
    end

    S.Quest.refreshRuinPanel = function()
        local state = S.Quest.get("RuinPressurePlates") or {}
        local lines, allActive = {}, true
        for _, definition in ipairs(S.Quest.Pressure) do
            local active = state[definition.Name] == true
            allActive = allActive and active
            table.insert(lines, definition.Type .. " (" .. definition.Name .. "): "
                .. (active and "Enabled" or "Disabled"))
        end
        S.setParagraphText(Runtime.Quest.Panels.Crystalline,
            allActive and "✅ ALL ANCIENT RUIN PLATES ACTIVE\n" .. table.concat(lines, "\n")
                or table.concat(lines, "\n"))
    end

    Runtime.Quest.RefreshPanels = function()
        S.Quest.refreshArtifactPanel()
        S.setParagraphText(Runtime.Quest.Panels.DeepSea, S.Quest.formatQuestPanel(
            "Deep Sea Quest", S.Quest.Goals.DeepSea, "Ghostfinn Rod",
            "All Deep Sea Quest Completed..."))
        S.setParagraphText(Runtime.Quest.Panels.Element, S.Quest.formatQuestPanel(
            "Element Quest", S.Quest.Goals.Element, "Element Rod",
            "All Quest Element Completed..."))
        S.setParagraphText(Runtime.Quest.Panels.Diamond, S.Quest.formatQuestPanel(
            "Diamond Researcher", S.Quest.Goals.Diamond, "Diamond Rod",
            "All Quest Diamond Rod Completed..."))
        S.Quest.refreshRuinPanel()
    end

    S.Quest.toggleCallback = function(job, state)
        if state then
            Runtime.Quest.Start(job)
        else
            Runtime.Quest.Stop(job)
        end
    end

    S.Quest.fallback = function(key, destination)
        Runtime.Quest.LastLocation = nil
        if typeof(destination) == "CFrame" then
            local character = Service.LocalPlayer.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            Navigation.tryMoveRoot(root, destination, true)
        else
            Navigation.teleportTo(destination, true)
        end
        Runtime.Quest.LastLocation = nil
    end

    S.Quest.teleportNPC = function()
        local npcFolder = workspace:FindFirstChild("NPC")
        local npc = npcFolder and npcFolder:FindFirstChild("Diamond Researcher")
        local character = Service.LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not npc or not root then return end
        local target = npc:GetPivot() * CFrame.new(0, 0, 4)
        Navigation.tryMoveRoot(root, target, true)
    end


    -- Shop is created first; Quest is therefore placed immediately after it.
    UI.QuestTab = UI.Window:CreateTab("Quest", "rbxassetid://13436029894")

    S.Quest.ArtifactSection = UI.Window:AddCollapsible(
        UI.QuestTab, "Artifact Lever Location", false)
    Runtime.Quest.Panels.Artifact = UI.Window:AddParagraph(
        S.Quest.ArtifactSection, "Panel Progress Artifact", "Loading...")
    UI.Window:AddToggle(
        S.Quest.ArtifactSection, "Auto Artifact Lever", "", false,
        function(state) S.Quest.toggleCallback("Artifact", state) end)
    UI.Window:AddButtonGrid(S.Quest.ArtifactSection,
        {Title="Arrow Artifact",Callback=function()
            S.Quest.fallback("Arrow Artifact", S.Quest.Artifacts[1].CFrame)
        end},
        {Title="Hourglass Diamond Artifact",Callback=function()
            S.Quest.fallback("Hourglass Diamond Artifact", S.Quest.Artifacts[2].CFrame)
        end})
    UI.Window:AddButtonGrid(S.Quest.ArtifactSection,
        {Title="Crescent Artifact",Callback=function()
            S.Quest.fallback("Crescent Artifact", S.Quest.Artifacts[3].CFrame)
        end},
        {Title="Diamond Artifact",Callback=function()
            S.Quest.fallback("Diamond Artifact", S.Quest.Artifacts[4].CFrame)
        end})

    S.Quest.DeepSeaSection = UI.Window:AddCollapsible(
        UI.QuestTab, "Sisyphus Statue Quest", false)
    Runtime.Quest.Panels.DeepSea = UI.Window:AddParagraph(
        S.Quest.DeepSeaSection, "Deep Sea Panel", "Loading...")
    UI.Window:AddToggle(
        S.Quest.DeepSeaSection, "Auto Deep Sea Quest", "", false,
        function(state) S.Quest.toggleCallback("DeepSea", state) end)
    UI.Window:AddButtonGrid(S.Quest.DeepSeaSection,
        {Title="Treasure Room",Callback=function()
            S.Quest.fallback("Treasure Room", "Treasure Room")
        end},
        {Title="Sisyphus Statue",Callback=function()
            S.Quest.fallback("Sisyphus Statue", "Sisyphus Statue")
        end})

    S.Quest.ElementSection = UI.Window:AddCollapsible(
        UI.QuestTab, "Element Quest", false)
    Runtime.Quest.Panels.Element = UI.Window:AddParagraph(
        S.Quest.ElementSection, "Element Panel", "Loading...")
    UI.Window:AddToggle(
        S.Quest.ElementSection, "Auto Element Quest", "", false,
        function(state) S.Quest.toggleCallback("Element", state) end)
    UI.Window:AddButtonGrid(S.Quest.ElementSection,
        {Title="Ancient Jungle",Callback=function()
            S.Quest.fallback("Ancient Jungle", "Ancient Jungle")
        end},
        {Title="Sacred Temple",Callback=function()
            S.Quest.fallback("Sacred Temple", "Sacred Temple")
        end})

    S.Quest.DiamondSection = UI.Window:AddCollapsible(
        UI.QuestTab, "Diamond Rod Quest", false)
    Runtime.Quest.Panels.Diamond = UI.Window:AddParagraph(
        S.Quest.DiamondSection, "Diamond Rod Panel", "Loading...")
    UI.Window:AddToggle(
        S.Quest.DiamondSection, "Auto Diamond Rod Quest", "", false,
        function(state) S.Quest.toggleCallback("Diamond", state) end)
    UI.Window:AddButtonGrid(S.Quest.DiamondSection,
        {Title="Coral Reefs",Callback=function()
            S.Quest.fallback("Coral Reefs", "Coral Reefs")
        end},
        {Title="Tropical Grove",Callback=function()
            S.Quest.fallback("Tropical Grove", "Tropical Grove")
        end})
    UI.Window:AddButtonGrid(S.Quest.DiamondSection,
        {Title="Kohana (Lochness Monster)",Callback=function()
            S.Quest.fallback("Kohana", "Kohana")
        end},
        {Title="NPC Lary",Callback=S.Quest.teleportNPC})

    S.Quest.CrystallineSection = UI.Window:AddCollapsible(
        UI.QuestTab, "Auto Crystalline Passage", false)
    Runtime.Quest.Panels.Crystalline = UI.Window:AddParagraph(
        S.Quest.CrystallineSection, "Ancient Ruin Panel", "Loading...")
    UI.Window:AddToggle(
        S.Quest.CrystallineSection, "Auto Ancient Ruin", "", false,
        function(state) S.Quest.toggleCallback("Crystalline", state) end)

    for _, path in ipairs({
        "Quests", "CompletedQuests", "TempleLevers", "RuinPressurePlates", "UnlockedTemple",
    }) do
        pcall(function()
            return Data.Player:OnChange(path, function()
                task.defer(Runtime.Quest.RefreshPanels)
            end)
        end)
    end
    Runtime.Quest.RefreshPanels()

    -- Replion startup poller: retry baca semua data quest sampai semua loaded
    -- Read-only — tidak ada equip/teleport, hanya update panel
    task.spawn(function()
        for _ = 1, 20 do
            task.wait(0.5)
            local inv       = S.Quest.get("Inventory")
            local quests    = S.Quest.get("Quests")
            local levers    = S.Quest.get("TempleLevers")
            local plates    = S.Quest.get("RuinPressurePlates")
            local completed = S.Quest.get("CompletedQuests")
            -- Refresh panel tiap attempt agar panel terupdate begitu data masuk
            Runtime.Quest.RefreshPanels()
            -- Stop kalau semua data sudah ada
            if inv and quests and levers ~= nil and plates ~= nil and completed ~= nil then
                break
            end
        end
    end)
end

-- ====== STARTUP ======
SupportState.updateBigPopup()
UI.Window:SetActiveTab("Info")
UI.Window:Show()
