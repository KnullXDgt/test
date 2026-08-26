-- ====================================================================
--                 INSTANT FISHING V2 - CLEAN
--          Fishing + AutoSell + Auto Small Notification
-- ====================================================================

-- ====== SERVICES ======
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

-- ====== HEURISTIC DISCOVERY ======
local net = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net

local function GetServerRemote(targetName)
    local allRemotes = net:GetChildren()
    for i, remote in ipairs(allRemotes) do
        if remote.Name == targetName then
            return allRemotes[i + 1]
        end
    end
    return nil
end

local function GetServerRemoteReverse(targetName)
    local allRemotes = net:GetChildren()
    for i, remote in ipairs(allRemotes) do
        if remote.Name == targetName then
            return allRemotes[i - 1]
        end
    end
    return nil
end

-- ====== REMOTES ======
local Events = {
    charge   = GetServerRemote("RF/ChargeFishingRod"),
    minigame = GetServerRemote("RF/RequestFishingMinigameStarted"),
    fishing  = GetServerRemote("RE/CatchFishCompleted"),
    cancel   = GetServerRemote("RF/CancelFishingInputs"),
    sell     = GetServerRemote("RF/SellAllItems"),
}

local updateAutoFishingRemote = GetServerRemote("RF/UpdateAutoFishingState")
local markAutoFishingRemote  = GetServerRemote("RF/MarkAutoFishingUsed")
local textNotificationRemote = GetServerRemote("RE/TextNotification")
local fishCaughtRemote       = GetServerRemote("RE/FishCaught")
local bigPopupRemote         = GetServerRemote("RE/ObtainedNewFishNotification")

-- Support Features remotes
local equipToolRemote        = GetServerRemote("RE/EquipToolFromHotbar")
local cutsceneRemote         = net:WaitForChild("RE/ReplicateCutscene", 10)
local abilityVFXRemote       = net:WaitForChild("RE/PlayAbilityVFX", 10)
local changeSettingRemote    = net:WaitForChild("RE/ChangeSetting", 10)
local fishingRadarRemote     = GetServerRemote("RF/UpdateFishingRadar")
local equipOxygenRemote      = GetServerRemote("RF/EquipOxygenTank")
local unequipOxygenRemote    = GetServerRemote("RF/UnequipOxygenTank")
local weatherPurchaseRF      = GetServerRemote("RF/PurchaseWeatherEvent")
local purchaseBaitRF         = GetServerRemote("RF/PurchaseBait")
local equipBaitRE            = GetServerRemote("RE/EquipBait")
local purchaseRodRF          = GetServerRemote("RF/PurchaseFishingRod")
local equipItemRE            = GetServerRemote("RE/EquipItem")
local purchaseBMRF           = GetServerRemote("RF/PurchaseBlackMarketItem")
local bpPurchaseRE           = GetServerRemote("RE/BPPurchaseRequest")
local purchaseMerchantRF     = GetServerRemote("RF/PurchaseMarketItem")

-- Support Features state
local cutsceneConns = {}
local abilityVFXConns = { Blocked = {} }
local hidePlayersConns = {}
local skinEffectConns = {}
local weatherVFXConns = {}

-- Disable Fishing Animation
local noFishAnimActive = false
local origAnimController = nil

-- Walk on Water
local walkOnWaterConn = nil
local walkOnWaterCharConn = nil
local walkOnWaterCharConn = nil

-- ====== INVENTORY ======
local Replion    = require(ReplicatedStorage.Packages.Replion)
local PlayerData  = Replion.Client:WaitReplion("Data")
local EventsReplion = nil  -- lazy-loaded saat weather feature dipakai
local ItemUtility = require(ReplicatedStorage.Shared.ItemUtility)

local function getFishCount()
    local ok, count = pcall(function()
        local inventory = PlayerData:Get("Inventory") or PlayerData.Data.Inventory
        if not inventory then return 0 end
        local c = 0
        for categoryName, items in pairs(inventory) do
            if type(items) == "table" then
                for _, item in ipairs(items) do
                    local itemData = ItemUtility.GetItemDataFromItemType(categoryName, item.Id)
                    if itemData and itemData.Data and itemData.Data.Type == "Fish" then
                        c = c + 1
                    end
                end
            end
        end
        return c
    end)
    return ok and count or 0
end

-- ====== CONFIG ======
local Config = {
    InstantFishing  = false,
    CastWait        = 0,
    AutoSell        = false,
    AutoSellMode    = "Delay",
    SellDelay       = 10,
    SellCount       = 10,
    DisableFishNotif = false,
    TeleportLocation = "Ancient Jungle",
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

-- ====== TELEPORT LOCATIONS ======
local LOCATIONS = {
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

local function getNPCNames()
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


local SAVED_LOCATION_FILE = "OrvionFishIt/SavedLocation.json"

local function getSavedLocation()
    if not isfile(SAVED_LOCATION_FILE) then return nil end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(SAVED_LOCATION_FILE))
    end)
    if not ok or not data then return nil end
    return CFrame.new(table.unpack(data))
end

local function saveCurrentLocation()
    local char = LocalPlayer.Character
    if not char then return false end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = root.CFrame:GetComponents()
    local ok = pcall(function()
        writefile(SAVED_LOCATION_FILE, HttpService:JSONEncode({
            x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22
        }))
    end)
    return ok
end

-- ====== UTILITIES ======
local function teleportToSaved()
    local cf = getSavedLocation()
    if not cf then return false end
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        root.CFrame = cf
    end)
    return cf ~= nil
end

local autoTpSpawnConn = nil
local function setAutoTeleportOnSpawn(state)
    if autoTpSpawnConn then autoTpSpawnConn:Disconnect(); autoTpSpawnConn = nil end
    if state then
        if LocalPlayer.Character then
            task.spawn(function()
                task.wait(0.5)
                pcall(teleportToSaved)
            end)
        end
        autoTpSpawnConn = LocalPlayer.CharacterAdded:Connect(function()
            task.wait(1)
            pcall(teleportToSaved)
        end)
    end
end

local function getPlayerList()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(names, p.Name)
        end
    end
    table.sort(names)
    return names
end

local LOCATION_NAMES = {
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

local function teleportTo(name)
    local cf = LOCATIONS[name]
    if not cf then return end
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        root.CFrame = cf
    end)
end

local function teleportToBM(cf)
    local root = game:GetService("Players").LocalPlayer.Character
        and game:GetService("Players").LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if root then root.CFrame = cf end
end

-- ====== PERFECT CAST HELPER ======
local function waitForPerfectCast()
    local power = 0.7
    local waterY = -1.0
    pcall(function()
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local castDist = power * 15 + 10
        local castPos = root.CFrame.Position + root.CFrame.LookVector * castDist
        local rp = RaycastParams.new()
        rp.IgnoreWater = false
        local result = workspace:Raycast(
            Vector3.new(castPos.X, castPos.Y + 20, castPos.Z),
            Vector3.new(0, -40, 0), rp)
        if result then waterY = result.Position.Y end
    end)
    return waterY, power
end

-- ====== FISHING SYSTEM V1 ======
local fishThread = nil
-- ====== STATE ======
local isFishing = false

local function castRod()
    if Config.PerfectCast then
        pcall(function() Events.charge:InvokeServer(tick()) end)
        task.wait(0.277)
        pcall(function() Events.minigame:InvokeServer(1.2854545116425, 1) end)
    else
        pcall(function() Events.charge:InvokeServer(tick()) end)
        task.wait(0.02)
        pcall(function() Events.minigame:InvokeServer(1.2854545116425, 1) end)
    end
end

local function stopFishing()
    Config.InstantFishing = false
    isFishing = false
    if Events.cancel then
        pcall(function() Events.cancel:InvokeServer(true) end)
    end
end

local function startFishing()
    if fishThread then task.cancel(fishThread) end
    fishThread = task.spawn(function()
        while Config.InstantFishing do
            isFishing = true
            local ok, err = pcall(function()
                castRod()
                if Config.CastWait > 0 then task.wait(Config.CastWait) end
                pcall(function() Events.fishing:FireServer() end)
                task.wait(0.05)
            end)
            if not ok and Config.InstantFishing then
                pcall(function() Events.cancel:InvokeServer(true) end)
                task.wait(0.5)
            end
            isFishing = false
        end
        isFishing = false
    end)
end

-- ====== FISHING SYSTEM V2 (Snap Reel) ======
local fishV2Thread = nil
local snapReelActive = false
local Config2 = {
    Active = false,
    Delay = 0,
}

-- AdjustSpeed: FishCaught = 3
local AnimController = require(ReplicatedStorage.Controllers.AnimationController)
local origPlayAnim = AnimController.PlayAnimation
AnimController.PlayAnimation = function(self, name, ...)
    local track, b, c = origPlayAnim(self, name, ...)
    if snapReelActive and track then
        if name == "FishCaught" then
            pcall(function() track:AdjustSpeed(3) end)
        end
    end
    return track, b, c
end

local function enableBaitVisual() end
local function disableBaitVisual() end

-- hide bait via ChildAdded, duration exact dari BaitCastVisual
local baitCastRemote = net:FindFirstChild("RE/BaitCastVisual")
local cosmeticFolder = workspace:WaitForChild("CosmeticFolder", 10)
local pendingDuration = nil

if baitCastRemote then
    baitCastRemote.OnClientEvent:Connect(function(player, baitData)
        if not snapReelActive then return end
        if player ~= LocalPlayer then return end
        if not (baitData and baitData.CastPosition and baitData.Origin) then return end
        local power = baitData.Power or 0
        local dist = (baitData.Origin - baitData.CastPosition).Magnitude
        pendingDuration = dist / 40 * (1.2 - power * 0.4)
    end)
end

if cosmeticFolder then
    cosmeticFolder.ChildAdded:Connect(function(bait)
        if not snapReelActive then return end
        if bait.Name ~= tostring(LocalPlayer.UserId) then return end

        local duration = pendingDuration or 0.4
        pendingDuration = nil

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
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("Beam") and obj.Attachment1 == baitAttachment and obj.Enabled then
                    hidden[obj] = obj.Enabled
                    obj.Enabled = false
                end
            end
        end

        task.wait(duration)

        for obj, orig in pairs(hidden) do
            if type(orig) == "number" then obj.Transparency = orig
            else obj.Enabled = orig end
        end
    end)
end

local function castRodV2()
    if Config.PerfectCast then
        pcall(function() Events.charge:InvokeServer(tick()) end)
        task.wait(0.277)
        pcall(function() Events.minigame:InvokeServer(1.2854545116425, 1) end)
    else
        pcall(function() Events.charge:InvokeServer(tick()) end)
        pcall(function() Events.minigame:InvokeServer(1.2854545116425, 1) end)
    end
end


-- ====== BLATANT VISUAL ======
local blatantN = 1
local blatantThread = nil

local function stopBlatant()
    if blatantThread then task.cancel(blatantThread); blatantThread = nil end
    blatantN = 1
    isFishing = false
    Config.BlatantActive = false
    if Events.cancel then pcall(function() Events.cancel:InvokeServer(true) end) end
end

local function startBlatant()
    stopBlatant()
    Config.BlatantActive = true
    pcall(updateBigPopup)
    blatantThread = task.spawn(function()
        while Config.BlatantActive do
            isFishing = true
            -- Path 1 & 2: masing-masing siklus lengkap sendiri (charge->minigame->fishing)
            for i = 1, 2 do
                task.spawn(function()
                    pcall(function() Events.charge:InvokeServer(workspace:GetServerTimeNow()) end)
                    pcall(function() Events.minigame:InvokeServer(1.2854545116425, 1) end)
                    if Config.BlatantDelay > 0 then task.wait(Config.BlatantDelay) end
                    pcall(function() Events.fishing:FireServer() end)
                end)
            end
            task.wait(0.1)
            isFishing = false
        end
        isFishing = false
    end)
end

local function stopFishingV2()
    Config2.Active = false
    isFishing = false
    snapReelActive = false
    enableBaitVisual()
    if Events.cancel then
        pcall(function() Events.cancel:InvokeServer(true) end)
    end
end

local function startFishingV2()
    if fishV2Thread then task.cancel(fishV2Thread) end
    snapReelActive = true
    disableBaitVisual()
    fishV2Thread = task.spawn(function()
        while Config2.Active do
            isFishing = true
            local ok = pcall(function()
                castRodV2()
                if Config2.Delay > 0 then task.wait(Config2.Delay) end
                pcall(function() Events.fishing:FireServer() end)
                task.wait(0.05)
            end)
            if not ok then task.wait(1) end
            isFishing = false
        end
        isFishing = false
    end)
end

-- ====== AUTO SELL SYSTEM ======
local autoSellThread = nil
local baselineFishCount = 0

local function sellAll()
    if not Events.sell then return false end
    local ok = pcall(function() return Events.sell:InvokeServer() end)
    return ok
end

local function stopAutoSell()
    Config.AutoSell = false
    if autoSellThread then
        task.cancel(autoSellThread)
        autoSellThread = nil
    end
end

local function startAutoSell()
    if autoSellThread then task.cancel(autoSellThread) end
    -- baseline = inventory sekarang, jadi hanya ikan BARU yang dihitung
    baselineFishCount = getFishCount()

    -- Count mode: kalau inventory sudah >= threshold -> langsung jual sekarang
    -- (tidak nunggu ikan baru)
    if Config.AutoSellMode == "Count" and baselineFishCount >= Config.SellCount then
        sellAll()
        task.wait(2)
        baselineFishCount = getFishCount()
    end

    autoSellThread = task.spawn(function()
        local currentMode = Config.AutoSellMode
        local lastSellTick = tick()

        while Config.AutoSell do
            if currentMode ~= Config.AutoSellMode then
                currentMode = Config.AutoSellMode
                -- reset baseline dan timer saat mode switch
                baselineFishCount = getFishCount()
                lastSellTick = tick()
            end

            if Config.AutoSellMode == "Delay" then
                local elapsed = tick() - lastSellTick
                if elapsed >= Config.SellDelay then
                    sellAll()
                    lastSellTick = tick()
                end
                task.wait(0.5)

            elseif Config.AutoSellMode == "Count" then
                local currentCount = getFishCount()
                if currentCount >= Config.SellCount then
                    sellAll()
                    task.wait(2)
                end
                task.wait(0.5)
            end
        end
    end)
end

-- ====== SMALL NOTIFICATION (AUTO ON) ======
local fishNameToId = {}

for itemId = 1, 1000 do
    local fishData = ItemUtility.GetItemDataFromItemType("Fish", itemId)
    if fishData and fishData.Data and fishData.Data.Name then
        fishNameToId[fishData.Data.Name] = itemId
    end
end



do
    local _nextFireTime = {}
    if fishCaughtRemote and textNotificationRemote then
        fishCaughtRemote.OnClientEvent:Connect(function(fishName)
            local fishItemId = fishNameToId[fishName]
            if not fishItemId then return end
            Config.LastBlatantFish = fishName
            task.spawn(function()
                local now = workspace.DistributedGameTime
                local next = math.max(now, (_nextFireTime[fishItemId] or 0) + 0.35)
                _nextFireTime[fishItemId] = next
                local delay = next - now
                if delay > 0.01 then task.wait(delay) end
                pcall(function()
                    firesignal(textNotificationRemote.OnClientEvent, {
                        Type = "Item",
                        ItemId = fishItemId,
                        Text = "",
                        CustomDuration = 5
                    })
                end)
            end)
        end)
    end
end

-- ====== BIG POPUP TOGGLE ======
local FishingController = require(ReplicatedStorage.Controllers.FishingController)
local origRequestCharge = FishingController.RequestChargeFishingRod
local origRequestClick  = FishingController.RequestFishingMinigameClick
local stableResultActive = false

FishingController.RequestChargeFishingRod = function(...)
    if stableResultActive then return end
    return origRequestCharge(...)
end

FishingController.RequestFishingMinigameClick = function(...)
    if stableResultActive then return end
    return origRequestClick(...)
end

-- Re-invoke true kalau server matiin auto fishing (movement detection dll)
PlayerData:OnChange("AutoFishing", function(value)
    if stableResultActive and not value then
        task.wait(0.1)
        pcall(function()
            updateAutoFishingRemote:InvokeServer(true)
        end)
    end
end)
local _snDisplay = nil
local function updateBigPopup()
    if not _snDisplay then
        local sn = LocalPlayer.PlayerGui:FindFirstChild("Small Notification")
        _snDisplay = sn and sn:FindFirstChild("Display")
    end
    if _snDisplay then
        if Config.DisableFishNotif then
            _snDisplay.Parent = nil
        else
            local sn = LocalPlayer.PlayerGui:FindFirstChild("Small Notification")
            if sn then _snDisplay.Parent = sn end
        end
    end
end

-- ====== SUPPORT FEATURES FUNCTIONS ======

local autoEquipRodConn = nil
local function setAutoEquipRod(state)
    if autoEquipRodConn then autoEquipRodConn:Disconnect() autoEquipRodConn = nil end
    if state then
        -- cek langsung saat toggle ON
        local ok, equipped = pcall(function() return PlayerData:Get("EquippedId") end)
        if not (ok and equipped and equipped ~= "") then
            task.wait(0.2)
            pcall(function() equipToolRemote:FireServer(1) end)
        end
        -- event driven untuk unequip berikutnya
        autoEquipRodConn = PlayerData:OnChange("EquippedId", function(value)
            if not value or value == "" then
                task.wait(0.2)
                pcall(function() equipToolRemote:FireServer(1) end)
            end
        end)
    end
end

-- Disable Cutscenes - hook module Play + block connection + InCutscene watcher
local stopCutsceneRemote = net:FindFirstChild("RE/StopCutscene")
local disableCutsceneActive = false
local cutsceneHookDone = false

local function ensureCutsceneHook()
    if cutsceneHookDone then return end
    cutsceneHookDone = true
    pcall(function()
        local CutsceneCtrl = require(ReplicatedStorage.Controllers.CutsceneController)
        if not CutsceneCtrl then return end
        local origPlay = CutsceneCtrl.Play
        if type(origPlay) ~= "function" then return end
        CutsceneCtrl.Play = function(self, ...)
            if disableCutsceneActive then return end
            return origPlay(self, ...)
        end
    end)
end

local function setDisableCutscenes(state)
    if state then
        disableCutsceneActive = true
        ensureCutsceneHook()

        -- block connection yang sudah ada
        if cutsceneRemote then
            local conns = getconnections(cutsceneRemote.OnClientEvent)
            for _, conn in pairs(conns) do
                conn:Disable()
                table.insert(cutsceneConns, conn)
            end
        end

        -- re-check 3x (1s, 2s, 3s) untuk connection yang dibuat belakangan
        task.spawn(function()
            for i = 1, 3 do
                task.wait(1)
                if not disableCutsceneActive then return end
                if cutsceneRemote then
                    local conns = getconnections(cutsceneRemote.OnClientEvent)
                    for _, conn in pairs(conns) do
                        if not table.find(cutsceneConns, conn) then
                            conn:Disable()
                            table.insert(cutsceneConns, conn)
                        end
                    end
                end
            end
        end)

        -- InCutscene watcher (fire stop backup + kill attribute)
        if not cutsceneConns.AttrWatcher then
            cutsceneConns.AttrWatcher = LocalPlayer:GetAttributeChangedSignal("InCutscene"):Connect(function()
                if disableCutsceneActive and LocalPlayer:GetAttribute("InCutscene") then
                    if stopCutsceneRemote then
                        pcall(function() stopCutsceneRemote:FireServer() end)
                    end
                    LocalPlayer:SetAttribute("InCutscene", false)
                    pcall(function() LocalPlayer:SetAttribute("IgnoreFOV", false) end)
                end
            end)
        end
    else
        disableCutsceneActive = false
        for _, conn in pairs(cutsceneConns) do
            if typeof(conn) == "userdata" then conn:Enable() end
        end
        if cutsceneConns.AttrWatcher then
            cutsceneConns.AttrWatcher:Disconnect()
            cutsceneConns.AttrWatcher = nil
        end
        cutsceneConns = {}
    end
end

-- Disable Ability VFX - block remote + destroy attribute (tanpa hook module)
local function setDisableAbilityVFX(state)
    if state then
        if not abilityVFXConns.Active then
            abilityVFXConns.Active = true

            -- block RE/PlayAbilityVFX connection + re-check 3x
            if abilityVFXRemote then
                for _, conn in pairs(getconnections(abilityVFXRemote.OnClientEvent)) do
                    conn:Disable()
                    table.insert(abilityVFXConns.Blocked, conn)
                end
                task.spawn(function()
                    for i = 1, 3 do
                        task.wait(1)
                        if not abilityVFXConns.Active then return end
                        local conns = getconnections(abilityVFXRemote.OnClientEvent)
                        for _, conn in pairs(conns) do
                            if not table.find(abilityVFXConns.Blocked, conn) then
                                conn:Disable()
                                table.insert(abilityVFXConns.Blocked, conn)
                            end
                        end
                    end
                end)
            end

            -- destroy existing + watch baru
            local function destroyAbilityVFX(v)
                if not v then return end
                if v:GetAttribute("AbilityVFX") == true or v:GetAttribute("AbilityAuraVFX") == true
                or v.Name == "AbilityCharacterAura" then
                    pcall(function() v:Destroy() end)
                end
            end

            local function watchDescendant(v)
                if not abilityVFXConns.Active then return end
                if v:GetAttribute("AbilityVFX") == true or v:GetAttribute("AbilityAuraVFX") == true
                or v.Name == "AbilityCharacterAura" then
                    pcall(function() v:Destroy() end)
                else
                    pcall(function()
                        v:GetAttributeChangedSignal("AbilityVFX"):Connect(function()
                            if abilityVFXConns.Active and v:GetAttribute("AbilityVFX") == true then
                                pcall(function() v:Destroy() end)
                            end
                        end)
                    end)
                end
            end

            local targets = { LocalPlayer.Character }
            for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
                if p ~= LocalPlayer then table.insert(targets, p.Character) end
            end
            table.insert(targets, workspace)

            for _, target in ipairs(targets) do
                if target then
                    for _, v in ipairs(target:GetDescendants()) do
                        destroyAbilityVFX(v)
                    end
                    target.DescendantAdded:Connect(watchDescendant)
                end
            end

            abilityVFXConns.CharacterAdded = game:GetService("Players").PlayerAdded:Connect(function(p)
                p.CharacterAdded:Connect(function(c)
                    for _, v in ipairs(c:GetDescendants()) do destroyAbilityVFX(v) end
                    c.DescendantAdded:Connect(watchDescendant)
                end)
            end)
            abilityVFXConns.SelfCharacterAdded = LocalPlayer.CharacterAdded:Connect(function(c)
                for _, v in ipairs(c:GetDescendants()) do destroyAbilityVFX(v) end
                c.DescendantAdded:Connect(watchDescendant)
            end)
        end
    else
        abilityVFXConns.Active = false
        for _, conn in pairs(abilityVFXConns.Blocked) do
            if typeof(conn) == "userdata" then conn:Enable() end
        end
        abilityVFXConns.Blocked = {}
        if abilityVFXConns.CharacterAdded then
            abilityVFXConns.CharacterAdded:Disconnect()
            abilityVFXConns.CharacterAdded = nil
        end
        if abilityVFXConns.SelfCharacterAdded then
            abilityVFXConns.SelfCharacterAdded:Disconnect()
            abilityVFXConns.SelfCharacterAdded = nil
        end
    end
end

-- Disable Skin Effect - disable PE/Beam/Trail di tool (tiru SettingsController AddCharacterTrove) - SEMUA PLAYER
local function setDisableSkinEffect(state)
    if state then
        if not skinEffectConns.Active then
            skinEffectConns.Active = true

            local function attach(char)
                if not char then return end
                local tool = char:FindFirstChild("!!!FISHING_VIEW_MODEL!!!") or char:FindFirstChild("!!!EQUIPPED_TOOL!!!")
                if tool then
                    for _, v in ipairs(tool:GetDescendants()) do
                        if v:IsA("ParticleEmitter") or v:IsA("Beam") or v:IsA("Trail") then
                            v.Enabled = false
                        end
                    end
                    char.DescendantAdded:Connect(function(obj)
                        if skinEffectConns.Active and obj:IsDescendantOf(tool) then
                            if obj:IsA("ParticleEmitter") or obj:IsA("Beam") or obj:IsA("Trail") then
                                obj.Enabled = false
                            end
                        end
                    end)
                end
            end

            -- semua player
            for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
                attach(p.Character)
            end
            skinEffectConns.CharacterAdded = game:GetService("Players").PlayerAdded:Connect(function(p)
                p.CharacterAdded:Connect(attach)
            end)
            attach(LocalPlayer.Character)
            skinEffectConns.SelfCharacterAdded = LocalPlayer.CharacterAdded:Connect(attach)
        end
    else
        skinEffectConns.Active = false
        if skinEffectConns.CharacterAdded then
            skinEffectConns.CharacterAdded:Disconnect()
            skinEffectConns.CharacterAdded = nil
        end
        if skinEffectConns.SelfCharacterAdded then
            skinEffectConns.SelfCharacterAdded:Disconnect()
            skinEffectConns.SelfCharacterAdded = nil
        end
    end
end

-- Disable Weather VFX - disable PE/Beam di instance weather di character
local WEATHER_NAMES = { "Fog", "Wind", "Radiant", "Storm", "Snow", "Galaxy Storm", "Galaxy", "Meteor Shower", "Admin - Frostmoon" }
local function setDisableWeatherVFX(state)
    if state then
        if not weatherVFXConns.Active then
            weatherVFXConns.Active = true

            local function disableWeatherInstance(instance)
                for _, v in ipairs(instance:GetDescendants()) do
                    if v:IsA("ParticleEmitter") or v:IsA("Beam") then
                        v.Enabled = false
                    end
                end
                if instance:IsA("ParticleEmitter") or instance:IsA("Beam") then
                    instance.Enabled = false
                end
            end

            local char = LocalPlayer.Character
            if char then
                -- disable yang sudah ada (scan semua descendants, bukan cuma langsung)
                for _, obj in ipairs(char:GetDescendants()) do
                    if table.find(WEATHER_NAMES, obj.Name) then
                        disableWeatherInstance(obj)
                    end
                end
                -- disable yang baru muncul
                char.DescendantAdded:Connect(function(obj)
                    if weatherVFXConns.Active and table.find(WEATHER_NAMES, obj.Name) then
                        disableWeatherInstance(obj)
                    end
                end)
            end
        end
    else
        weatherVFXConns.Active = false
    end
end

-- Hide Other Players
local function setHideOtherPlayers(state)
    for _, conn in pairs(hidePlayersConns) do conn:Disconnect() end
    hidePlayersConns = {}

    local function hidePlayer(player)
        if player == LocalPlayer then return end
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
        for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
            hidePlayer(p)
        end
        table.insert(hidePlayersConns, game:GetService("Players").PlayerAdded:Connect(function(p)
            p.CharacterAdded:Connect(function() task.wait(0.5) hidePlayer(p) end)
        end))
    else
        for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
            hidePlayer(p)  -- state = false -> transparencyModifier = 0 = show
        end
    end
end

local walkPlatform = nil
local function setWalkOnWater(state)
    if walkOnWaterConn then walkOnWaterConn:Disconnect() walkOnWaterConn = nil end
    if walkOnWaterCharConn then walkOnWaterCharConn:Disconnect() walkOnWaterCharConn = nil end
    if walkPlatform then walkPlatform:Destroy() walkPlatform = nil end

    if not state then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildWhichIsA("Humanoid")
        if hum then pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, true) end) end
        return
    end

    walkPlatform = Instance.new("Part")
    walkPlatform.Anchored = true
    walkPlatform.CanCollide = false  -- off dulu
    walkPlatform.Transparency = 1
    walkPlatform.Size = Vector3.new(10, 0.5, 10)
    walkPlatform.Name = "WalkOnWaterPlatform"
    walkPlatform.CFrame = CFrame.new(0, -9999, 0)  -- jauh di bawah
    walkPlatform.Parent = workspace

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

        if walkOnWaterConn then walkOnWaterConn:Disconnect() end
        walkOnWaterConn = game:GetService("RunService").Stepped:Connect(function()
            if not root.Parent then return end
            local pos = root.Position
            local feetPos = pos - Vector3.new(0, 3, 0)  -- posisi kaki

            local isWaterNow = checkWaterAt(feetPos)

            if isWaterNow and not inWater then
                -- baru masuk air -> raycast untuk dapat exact surface Y
                inWater = true
                waterSurfaceY = getWaterSurfaceY(pos) or (pos.Y - 2)
                walkPlatform.CFrame = CFrame.new(pos.X, waterSurfaceY, pos.Z)
                walkPlatform.CanCollide = true
            elseif not isWaterNow and inWater then
                inWater = false
                waterSurfaceY = nil
                walkPlatform.CanCollide = false
                walkPlatform.CFrame = CFrame.new(0, -9999, 0)
            end

            -- platform ikut XZ, Y = exact water surface (tidak berubah saat loncat)
            if inWater and waterSurfaceY then
                walkPlatform.CFrame = CFrame.new(pos.X, waterSurfaceY, pos.Z)
            end
        end)
    end

    local char = LocalPlayer.Character
    if char then attachToChar(char) end
    walkOnWaterCharConn = LocalPlayer.CharacterAdded:Connect(attachToChar)
end

-- Lock Position
local lockPosConn = nil
local lockedCFrame = nil
local function setLockPosition(state)
    if lockPosConn then lockPosConn:Disconnect() lockPosConn = nil end
    if state then
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            lockedCFrame = root.CFrame
            -- Anchored = true -> tidak bisa di-fling, tidak BAC (pure client)
            pcall(function() root.Anchored = true end)
        end
    else
        lockedCFrame = nil
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            pcall(function() root.Anchored = false end)
        end
    end
end

-- Bypass Radar
local function setBypassRadar(state)
    if fishingRadarRemote then
        pcall(function() fishingRadarRemote:InvokeServer(state) end)
    end
end

-- Auto Equip Diving Gear
local function setAutoEquipDivingGear(state)
    local diveData = ItemUtility.GetItemDataFromItemType("Gears", "Diving Gear")
    if not diveData then return end
    local itemId = diveData.Data and diveData.Data.Id
    if not itemId then return end

    local currentEquipped = PlayerData:Get("EquippedOxygenTankId")
    if state then
        if currentEquipped ~= itemId then
            pcall(function() equipOxygenRemote:InvokeServer(itemId) end)
        end
    else
        if currentEquipped == itemId then
            pcall(function() unequipOxygenRemote:InvokeServer() end)
        end
    end
end

-- Disable Fishing Animation
local function setNoFishingAnimation(state)
    noFishAnimActive = state
    pcall(function()
        local AnimCtrl = require(ReplicatedStorage.Controllers.AnimationController)
        if state then
            AnimCtrl:DestroyActiveAnimationTracks()
        end
    end)
end

-- patch AnimController untuk Disable Fishing Animation (jalan bersama V2)
local _animCtrlPatched = false
local function ensureAnimPatch()
    if _animCtrlPatched then return end
    _animCtrlPatched = true
    local AnimCtrl = require(ReplicatedStorage.Controllers.AnimationController)
    local orig = AnimCtrl.PlayAnimation
    local FISHING_ANIMS = {
        StartRodCharge=true, LoopedRodCharge=true, RodThrow=true,
        ReelStart=true, ReelIntermission=true, FishCaught=true,
        FishingFailure=true, EquipIdle=true, EquipIdleFake=true,
        ReelingIdle=true, HoldFish1=true, HoldFish2=true, HoldFish3=true
    }
    AnimCtrl.PlayAnimation = function(self, name, ...)
        -- Disable Fishing Animation: block BEFORE orig runs
        if noFishAnimActive and FISHING_ANIMS[name] then
            return nil, nil, nil
        end
        local track, b, c = orig(self, name, ...)
        -- V2 AdjustSpeed FishCaught
        if snapReelActive and track and name == "FishCaught" then
            pcall(function() track:AdjustSpeed(3) end)
        end
        return track, b, c
    end
end
ensureAnimPatch()

-- ====== UI (NEW LIBRARY) ======

-- ====== CONSTANTS ======
local EVENT_LIST = {
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

local TOTEM_LIST = {
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

local Orvion = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/KnullXDgt/Orvion-UI-Library-Gen2/main/source.luau?t=" .. os.time()
))()

local _execName = "Unknown"
pcall(function() _execName = getexecutorname() end)

local Window = Orvion:CreateWindow({
    Title          = "Orvion Hub",
    Icon           = "rbxassetid://95126399202412",
    TitleImage     = "rbxassetid://138517423977481",
    Subtitle       = "",
    Badges         = {"v0.1", "Executor: " .. _execName},
    Center       = true,
    Draggable    = true,
    Resizable    = true,
    ToggleButton = true,
    ConfigFolder = "OrvionFishIt",
})

-- ====== FISHING TAB ======
-- ====== INFO TAB ======
local InfoTab = Window:CreateTab("Info", "rbxassetid://94529541997278")
Window:AddWelcomeCard(InfoTab)
local InfoSection = Window:AddCollapsible(InfoTab, "Information", true)
Window:AddParagraph(InfoSection, "What is Orvion Hub?", "Orvion Hub is a reflection of my coding journey  built through trial, error, and a lot of iteration. It shows how much I have grown as a developer, and how much I still have left to learn.\nLowkey started this just for myself, no cap. Somewhere along the way it turned into something worth sharing.")

local FishingTab = Window:CreateTab("Main", "rbxassetid://117906088481880")

local SupportSection = Window:AddCollapsible(FishingTab, "Support Features", false)

Window:AddToggle(SupportSection, "Disable Obtained Fish", "", false, function(state)
    Config.DisableFishNotif = state
    updateBigPopup()
end, "Toggle_Disable Obtained Fish")

Window:AddToggle(SupportSection, "Disable Fishing Animation", "", false, function(state)
    setNoFishingAnimation(state)
end, "Toggle_Disable Fishing Animation")

Window:AddToggle(SupportSection, "Disable Cutscenes", "", false, function(state)
    setDisableCutscenes(state)
end, "Toggle_Disable Cutscenes")

Window:AddToggle(SupportSection, "Disable Skin Effect", "", false, function(state)
    setDisableSkinEffect(state)
end, "Toggle_Disable Skin Effect")

Window:AddToggle(SupportSection, "Disable Ability VFX", "", false, function(state)
    setDisableAbilityVFX(state)
end, "Toggle_Disable Ability VFX")

Window:AddToggle(SupportSection, "Disable Weather VFX", "", false, function(state)
    setDisableWeatherVFX(state)
end, "Toggle_Disable Weather VFX")

Window:AddToggle(SupportSection, "Auto Equip Rod", "", false, function(state)
    setAutoEquipRod(state)
end, "Toggle_Auto Equip Rod")

Window:AddToggle(SupportSection, "Hide Other Players", "", false, function(state)
    setHideOtherPlayers(state)
end, "Toggle_Hide Other Players")

Window:AddToggle(SupportSection, "Walk On Water", "", false, function(state)
    setWalkOnWater(state)
end, "Toggle_Walk On Water")

Window:AddToggle(SupportSection, "Bypass Radar", "", false, function(state)
    setBypassRadar(state)
end, "Toggle_Bypass Radar")

Window:AddToggle(SupportSection, "Auto Equip Diving Gear", "", false, function(state)
    setAutoEquipDivingGear(state)
end, "Toggle_Auto Equip Diving Gear")

Window:AddToggle(SupportSection, "Lock Position", "", false, function(state)
    setLockPosition(state)
end, "Toggle_Lock Position")
-- Instant Fishing v1
local FishingSection = Window:AddCollapsible(FishingTab, "Instant Fishing", false)

Window:AddInput(FishingSection, "Delay Complete", "", "Write your input here...", function(v)
    local n = tonumber(v)
    if n and n >= 0 then Config.CastWait = n end
end, "Input_Delay Complete")

Window:AddToggle(FishingSection, "Instant Fishing", "", false, function(state)
    Config.InstantFishing = state
    if state then startFishing() else stopFishing() end
end, "Toggle_Instant Fishing")

-- Instant Fishing v2
local FishingV2Section = Window:AddCollapsible(FishingTab, "Instant Fishing V2", false)

Window:AddInput(FishingV2Section, "Delay Complete V2", "", "Write your input here...", function(v)
    local n = tonumber(v)
    if n and n >= 0 then Config2.Delay = n end
end, "Input_Delay Complete V2")

Window:AddToggle(FishingV2Section, "Instant Fishing V2", "", false, function(state)
    Config2.Active = state
    if state then startFishingV2() else stopFishingV2() end
end, "Toggle_Instant Fishing v2")

-- Blatant (Visual)
local BlatantSection = Window:AddCollapsible(FishingTab, "Blatant (Visual)", false)
Window:AddInput(BlatantSection, "Delay Blatant", "", "Write your input here...", function(v)
    local n = tonumber(v)
    if n and n >= 0 then Config.BlatantDelay = n end
end, "Input_Blatant Delay")
Window:AddToggle(BlatantSection, "Blatant (Visual)", "", false, function(state)
    Config.BlatantActive = state
    if state then startBlatant() else stopBlatant() end
end, "Toggle_Blatant Visual")

-- Stable Results
local StableSection = Window:AddCollapsible(FishingTab, "Stable Results", false)

Window:AddToggle(StableSection, "Stable Result", "", false, function(state)
    if updateAutoFishingRemote then
        pcall(function()
            if state then
                stableResultActive = true
                updateAutoFishingRemote:InvokeServer(true)
                if markAutoFishingRemote then
                    pcall(function() markAutoFishingRemote:InvokeServer() end)
                end
            else
                stableResultActive = false
                updateAutoFishingRemote:InvokeServer(false)
            end
        end)
    end
end, "Toggle_Stable Result")
Window:AddToggle(StableSection, "Auto Perfect", "", false, function(state)
    Config.PerfectCast = state
end, "Toggle_Auto Perfect")

-- ====== SELL FEATURES (under Main tab) ======
local SellSection = Window:AddCollapsible(FishingTab, "Sell Features", false)

Window:AddDropdown(SellSection, "Select Sell Mode", "", {"Delay", "Count"}, false, "Delay", function(value)
    Config.AutoSellMode = value
end, "Dropdown_Sell Mode")

Window:AddInput(SellSection, "Set Value", "", "Write your input here...", function(v)
    local n = tonumber(v)
    if n and n >= 1 then
        Config.SellDelay = n
        Config.SellCount = n
    end
end, "Input_Sell Delay")

Window:AddToggle(SellSection, "Start Sell", "", false, function(state)
    Config.AutoSell = state
    if state then startAutoSell() else stopAutoSell() end
end, "Toggle_Auto Sell")

Window:AddButton(SellSection, "Sell All Now", "", "rbxassetid://16932740082", function()
    sellAll()
    Orvion:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="Sold!", Color=Color3.fromRGB(150,150,170), Delay=2 })
end)

-- ====== TELEPORT TAB ======

-- ====== EVENT TELEPORT LOGIC ======
local preEventCFrame = nil
local eventWaterPlatform = nil
local eventWaterConn = nil
local eventWaterCharConn = nil

local function stopEventWalkOnWater()
    if eventWaterConn then eventWaterConn:Disconnect(); eventWaterConn = nil end
    if eventWaterCharConn then eventWaterCharConn:Disconnect(); eventWaterCharConn = nil end
    if eventWaterPlatform then eventWaterPlatform:Destroy(); eventWaterPlatform = nil end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildWhichIsA("Humanoid")
    if hum then pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, true) end) end
end

local function startEventWalkOnWater()
    stopEventWalkOnWater()
    eventWaterPlatform = Instance.new("Part")
    eventWaterPlatform.Anchored = true
    eventWaterPlatform.CanCollide = false
    eventWaterPlatform.Transparency = 1
    eventWaterPlatform.Size = Vector3.new(10, 0.5, 10)
    eventWaterPlatform.CFrame = CFrame.new(0, -9999, 0)
    eventWaterPlatform.Parent = workspace

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

        if eventWaterConn then eventWaterConn:Disconnect() end
        eventWaterConn = game:GetService("RunService").Stepped:Connect(function()
            if not root.Parent then return end
            local pos = root.Position
            local feetPos = pos - Vector3.new(0, 3, 0)
            local isWaterNow = checkWaterAt(feetPos)
            if isWaterNow and not inWater then
                inWater = true
                waterSurfaceY = getWaterSurfaceY(pos) or (pos.Y - 2)
                eventWaterPlatform.CFrame = CFrame.new(pos.X, waterSurfaceY, pos.Z)
                eventWaterPlatform.CanCollide = true
                pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, false) end)
            elseif not isWaterNow and inWater then
                inWater = false
                waterSurfaceY = nil
                eventWaterPlatform.CanCollide = false
                eventWaterPlatform.CFrame = CFrame.new(0, -9999, 0)
                pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, true) end)
            end
            if inWater and waterSurfaceY then
                eventWaterPlatform.CFrame = CFrame.new(pos.X, waterSurfaceY, pos.Z)
            end
        end)
    end

    local char = LocalPlayer.Character
    if char then attachEventChar(char) end
    eventWaterCharConn = LocalPlayer.CharacterAdded:Connect(attachEventChar)
end

local function findEventPosition(eventName)
    -- 1. EventSpawnLocations (exact, works for Thunderzilla too)
    if not EventsReplion then
        pcall(function() EventsReplion = Replion.Client:WaitReplion("Events") end)
    end
    local pos = nil
    pcall(function()
        if EventsReplion then
            local locs = EventsReplion:GetExpect("EventSpawnLocations")
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


local TpTab = Window:CreateTab("Teleport", "rbxassetid://6723742952")
local TpSection = Window:AddCollapsible(TpTab, "Teleport to Island", false)

Window:AddDropdown(TpSection, "Select Island", "", LOCATION_NAMES, false, "Ancient Jungle", function(value)
    Config.TeleportLocation = value
end, "Dropdown_Select Map")

Window:AddButton(TpSection, "Teleport", "", "", function()
    teleportTo(Config.TeleportLocation)
    Orvion:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="Teleported to " .. Config.TeleportLocation, Color=Color3.fromRGB(150,150,170), Delay=2 })
end)


-- Teleport to Event
local function getBestEventPos()
    local priority = Config.PriorityEvent
    local selectEv = Config.SelectEvent
    if priority and priority ~= "Select Option" then
        local pos = findEventPosition(priority)
        if pos then return pos, "priority" end
    end
    if selectEv and selectEv ~= "Select Option" then
        local pos = findEventPosition(selectEv)
        if pos then return pos, "select" end
    end
    return nil, nil
end

local TpEventSection = Window:AddCollapsible(TpTab, "Teleport to Event", false)




















local eventWatcherConn = nil
local eventTeleportActive = false
Window:AddDropdown(TpEventSection, "Priority Event", "", EVENT_LIST, false, "Select Option", function(value)
    Config.PriorityEvent = value
    if eventTeleportActive then
        local pos = getBestEventPos()
        if pos then
            pcall(function()
                local ch = LocalPlayer.Character
                local rt = ch and ch:FindFirstChild("HumanoidRootPart")
                if rt then rt.CFrame = CFrame.new(pos + Vector3.new(0, 6, 0)) end
            end)
            startEventWalkOnWater()
        end
    end
end)
Window:AddDropdown(TpEventSection, "Select Event", "", EVENT_LIST, false, "Select Option", function(value)
    Config.SelectEvent = value
    if eventTeleportActive then
        local pos = getBestEventPos()
        if pos then
            pcall(function()
                local ch = LocalPlayer.Character
                local rt = ch and ch:FindFirstChild("HumanoidRootPart")
                if rt then rt.CFrame = CFrame.new(pos + Vector3.new(0, 6, 0)) end
            end)
            startEventWalkOnWater()
        end
    end
end)
Window:AddToggle(TpEventSection, "Start Auto Event", "", false, function(state)
    if state then
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        preEventCFrame = root.CFrame
        eventTeleportActive = true
        local initPos, initSource = getBestEventPos()
        local wasFound = initPos ~= nil
        local currentSource = initSource
        if initPos then
            pcall(function() root.CFrame = CFrame.new(initPos + Vector3.new(0, 6, 0)) end)
            startEventWalkOnWater()
        end
        eventWatcherConn = workspace.DescendantRemoving:Connect(function(removed)
            if not eventTeleportActive or not wasFound then return end
            if not removed:IsA("Model") then return end
            local eventName = (currentSource == "priority") and Config.PriorityEvent or Config.SelectEvent
            if not eventName or eventName == "Select Option" then return end
            local lowerName = eventName:lower()
            local strippedName = lowerName:gsub("%s*hunt%s*$", "")
            local removedLower = removed.Name:lower()
            if removedLower ~= lowerName and removedLower ~= strippedName then return end
            task.defer(function()
                    if not eventTeleportActive then return end
                    local pos, source = getBestEventPos()
                    if pos then
                        if currentSource ~= source then
                            wasFound = true
                            currentSource = source
                            pcall(function()
                                local ch = LocalPlayer.Character
                                local rt = ch and ch:FindFirstChild("HumanoidRootPart")
                                if rt then rt.CFrame = CFrame.new(pos + Vector3.new(0, 6, 0)) end
                            end)
                            startEventWalkOnWater()
                        end
                    else
                        wasFound = false
                        currentSource = nil
                        stopEventWalkOnWater()
                        if preEventCFrame then
                            pcall(function()
                                local ch = LocalPlayer.Character
                                local rt = ch and ch:FindFirstChild("HumanoidRootPart")
                                if rt then rt.CFrame = preEventCFrame end
                            end)
                        end
                    end
                end)
        end)
        task.spawn(function()
            while eventTeleportActive do
                task.wait(2)
                if not eventTeleportActive then break end
                local pos, source = getBestEventPos()
                if pos then
                    if not wasFound or currentSource ~= source then
                        wasFound = true
                        currentSource = source
                        pcall(function()
                            local ch = LocalPlayer.Character
                            local rt = ch and ch:FindFirstChild("HumanoidRootPart")
                            if rt then rt.CFrame = CFrame.new(pos + Vector3.new(0, 6, 0)) end
                        end)
                        startEventWalkOnWater()
                    end
                else
                    if wasFound then
                        wasFound = false
                        currentSource = nil
                        stopEventWalkOnWater()
                        if preEventCFrame then
                            pcall(function()
                                local ch = LocalPlayer.Character
                                local rt = ch and ch:FindFirstChild("HumanoidRootPart")
                                if rt then rt.CFrame = preEventCFrame end
                            end)
                        end
                    end
                end
            end
        end)
    else
        eventTeleportActive = false
        if eventWatcherConn then eventWatcherConn:Disconnect(); eventWatcherConn = nil end
        stopEventWalkOnWater()
        if preEventCFrame then
            pcall(function()
                local char = LocalPlayer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root then root.CFrame = preEventCFrame end
            end)
            preEventCFrame = nil
        end
    end
end, "Toggle_Start Auto Event")



-- Teleport to NPC
local TpNpcSection = Window:AddCollapsible(TpTab, "Teleport to NPC", false)
local npcInitList = getNPCNames()
local SelectNpcDropdown = Window:AddDropdown(TpNpcSection, "Select NPC", "", npcInitList, false, npcInitList[1] or "Select NPC", function(value)
    Config.TeleportNPC = value
end, "Dropdown_Select NPC")
Window:AddButtonGrid(TpNpcSection,
    { Title = "Teleport", Callback = function()
    local name = Config.TeleportNPC
    if not name or name == "" then return end
    local teleported = false
    pcall(function()
        local char = LocalPlayer.Character
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
        Orvion:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="Teleported to " .. name, Color=Color3.fromRGB(150,150,170), Delay=2 })
    else
        Orvion:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="NPC not found: " .. name, Color=Color3.fromRGB(150,150,170), Delay=2 })
    end
    end},
    { Title = "Refresh", Callback = function()
        local nl = getNPCNames()
        SelectNpcDropdown:Refresh(nl, nl[1] or "Select NPC")
        Orvion:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="Refreshed " .. #nl .. " NPCs!", Color=Color3.fromRGB(150,150,170), Delay=2 })
    end}
)

-- Teleport to Player
local TpPlayerSection = Window:AddCollapsible(TpTab, "Teleport to Player", false)
local SelectPlayerDropdown = Window:AddDropdown(TpPlayerSection, "Pick Player", "", getPlayerList(), false, "Select Option", function(value)
    Config.TeleportPlayer = value
end)
Window:AddButtonGrid(TpPlayerSection,
    { Title = "Teleport", Callback = function()
        local target = Config.TeleportPlayer
        if not target or target == "" then return end
        pcall(function()
            local char = LocalPlayer.Character
            if not char then return end
            local root = char:FindFirstChild("HumanoidRootPart")
            if not root then return end
            local tp = Players:FindFirstChild(target)
            if not tp then return end
            local tc = tp.Character
            if not tc then return end
            local tr = tc:FindFirstChild("HumanoidRootPart")
            if not tr then return end
            root.CFrame = tr.CFrame + Vector3.new(3, 0, 0)
        end)
        Orvion:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="Teleported to " .. tostring(Config.TeleportPlayer), Color=Color3.fromRGB(150,150,170), Delay=2 })
    end},
    { Title = "Refresh", Callback = function()
        local pl = getPlayerList(); SelectPlayerDropdown:Refresh(pl, pl[1] or "Select Player")
    end}
)

-- Saved Location
local SavedLocSection = Window:AddCollapsible(TpTab, "Saved Location", false)
Window:AddButton(SavedLocSection, "Save Current Location", "", "rbxassetid://16932740082", function()
    local ok = saveCurrentLocation()
    local msg = ok and "Location saved!" or "Failed to save location."
    Orvion:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content=msg, Color=Color3.fromRGB(150,150,170), Delay=2 })
end)
Window:AddButton(SavedLocSection, "Teleport to Saved", "", "rbxassetid://16932740082", function()
    local ok, result = pcall(teleportToSaved)
    local msg = (ok and result) and "Teleported to saved!" or "No saved location."
    Orvion:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content=msg, Color=Color3.fromRGB(150,150,170), Delay=2 })
end)
Window:AddButton(SavedLocSection, "Reset Saved Location", "", "rbxassetid://16932740082", function()
    pcall(function()
        if isfile(SAVED_LOCATION_FILE) then delfile(SAVED_LOCATION_FILE) end
    end)
    Orvion:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="Saved location cleared.", Color=Color3.fromRGB(150,150,170), Delay=2 })
end)
Window:AddToggle(SavedLocSection, "Auto Teleport on Spawn", "", false, function(state)
    setAutoTeleportOnSpawn(state)
end, "Toggle_Auto Teleport on Spawn")


-- ====== SHOP: AUTO BUY WEATHER ======
local WEATHER_LIST = {"Fog", "Radiant", "Storm", "Treasure Hunt", "Wind"}
local weatherWatchConn = nil

local function stopWeatherWatcher()
    if weatherWatchConn then
        pcall(function() weatherWatchConn:Disconnect() end)
        weatherWatchConn = nil
    end
    Config.BuyWeatherActive = false
end

local function buyWeatherEvent(eventName, silent)
    local ok, result = pcall(function()
        return weatherPurchaseRF:InvokeServer(eventName)
    end)
    if ok and result == true then
        if not silent then
            Orvion:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content=eventName, Color=Color3.fromRGB(150,150,170), Delay=3 })
        end
        return true
    end
    return false
end

local function startWeatherWatcher()
    -- Lazy-load EventsReplion
    if not EventsReplion then
        pcall(function()
            EventsReplion = Replion.Client:WaitReplion("Events")
        end)
    end
    if not EventsReplion then return end
    -- Connect watcher langsung (jangan terlambat detect event selesai)
    weatherWatchConn = EventsReplion:OnArrayRemove("WeatherMachine", function(_, removedEvent)
        if not Config.BuyWeatherActive then return end
        if not table.find(Config.SelectedWeatherEvents, removedEvent) then return end
        task.spawn(function()
            task.wait(0.5)
            if not Config.BuyWeatherActive then return end
            local success = buyWeatherEvent(removedEvent)
            if not success then
                stopWeatherWatcher()
            end
        end)
    end)
    -- Initial buy di-defer: tunggu dropdown autoload selesai dulu
    task.defer(function()
        if not Config.BuyWeatherActive then return end
        local activeList = {}
        pcall(function() activeList = EventsReplion:GetExpect("WeatherMachine") or {} end)
        local bought = {}
        for _, ev in ipairs(Config.SelectedWeatherEvents) do
            if ev ~= "Select Option" and not table.find(activeList, ev) then
                if buyWeatherEvent(ev, true) then
                    table.insert(bought, ev)
                end
                task.wait(0.3)
            end
        end
        if #bought > 0 then
            Orvion:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content=table.concat(bought, ", "), Color=Color3.fromRGB(150,150,170), Delay=4 })
        end
    end)
end

local AutomationTab = Window:CreateTab("Automation", "rbxassetid://102105242487044")

local WeatherSection = Window:AddCollapsible(AutomationTab, "Weather Features", false)

Window:AddDropdown(WeatherSection, "Select Weather", "", WEATHER_LIST, 3, {}, function(selected)
    Config.SelectedWeatherEvents = (type(selected) == "table") and selected or {}
end, "Dropdown_Select Weather")

Window:AddToggle(WeatherSection, "Buy Weather", "", false, function(state)
    Config.BuyWeatherActive = state
    if state then
        startWeatherWatcher()
    else
        stopWeatherWatcher()
    end
end, "Toggle_Buy Weather")

local TotemSection = Window:AddCollapsible(AutomationTab, "Totem Features", false)














local autoSpawnThread = nil
local totemWatchConn = nil
local totemCreatedConn = nil
local totemDistMonitor = nil
local totemWorldPos = nil  -- posisi totem aktif di world

local spawnTotemRemote   = GetServerRemote("RE/SpawnTotem")
local totemCreatedRemote = GetServerRemote("RE/TotemCreated")
local totemSpawnedRemote = GetServerRemote("RE/TotemSpawned")

-- listen RE/TotemSpawned untuk dapat posisi totem
if totemSpawnedRemote then
    totemSpawnedRemote.OnClientEvent:Connect(function(pos)
        totemWorldPos = pos
    end)
end

local function findTotemUUID(totemName)
    local uuid = nil
    pcall(function()
        local inv = PlayerData:GetExpect("Inventory")
        for catName, items in pairs(inv) do
            if type(items) == "table" then
                for _, item in pairs(items) do
                    if type(item) == "table" and item.UUID and item.Id then
                        local ok2, data = pcall(ItemUtility.GetItemDataFromItemType, catName, item.Id)
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

local spawnTotem -- forward declare
local lastSpawnedUUID = nil  -- track UUID milik kita

local function scheduleRespawn()
    if not Config.AutoSpawnTotem then return end
    if totemWatchConn then totemWatchConn:Disconnect(); totemWatchConn = nil end
    if totemCreatedConn then totemCreatedConn:Disconnect(); totemCreatedConn = nil end
    if autoSpawnThread then pcall(task.cancel, autoSpawnThread); autoSpawnThread = nil end

    if totemCreatedRemote then
        totemCreatedConn = totemCreatedRemote.OnClientEvent:Connect(function(model, totemId)
            -- filter: hanya model yang di-spawn oleh kita (cek posisi dekat player)
            if not model then return end
            local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local ok, pivot = pcall(function() return model:GetPivot() end)
                if ok and pivot then
                    local dist = (pivot.Position - root.Position).Magnitude
                    if dist > 50 then return end  -- bukan totem kita
                end
            end
            if totemCreatedConn then totemCreatedConn:Disconnect(); totemCreatedConn = nil end
            if autoSpawnThread then pcall(task.cancel, autoSpawnThread); autoSpawnThread = nil end
            totemWatchConn = model.AncestryChanged:Connect(function()
                if model.Parent ~= nil then return end
                if totemWatchConn then totemWatchConn:Disconnect(); totemWatchConn = nil end
                if Config.AutoSpawnTotem then
                    task.wait(2)
                    spawnTotem()
                end
            end)

            -- monitor jarak: jika player jauh > 100 studs dari totem -> re-spawn
            if totemDistMonitor then pcall(task.cancel, totemDistMonitor); totemDistMonitor = nil end
            totemDistMonitor = task.spawn(function()
                while Config.AutoSpawnTotem and model.Parent ~= nil do
                    task.wait(10)
                    if not Config.AutoSpawnTotem or model.Parent == nil then break end
                    if totemWorldPos then
                        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        if root then
                            local dist = (totemWorldPos - root.Position).Magnitude
                            if dist > 100 then
                                -- player jauh -> disconnect watcher lama, re-spawn
                                if totemWatchConn then totemWatchConn:Disconnect(); totemWatchConn = nil end
                                totemDistMonitor = nil
                                task.wait(1)
                                spawnTotem()
                                break
                            end
                        end
                    end
                end
            end)
        end)
    end
end

spawnTotem = function(isManual)
    local totemName = Config.SelectedTotem
    if not totemName or totemName == "" then return false end
    local uuid = findTotemUUID(totemName)
    if not uuid then
        Orvion:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="Not found in inventory", Color=Color3.fromRGB(150,150,170), Delay=3 })
        return false
    end
    local rf = spawnTotemRemote
    if not rf then return false end
    local ok = pcall(function() rf:FireServer(uuid) end)
    if ok then
        if isManual then
            Orvion:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content=totemName .. " spawned", Color=Color3.fromRGB(150,150,170), Delay=3 })
        end
        if Config.AutoSpawnTotem then scheduleRespawn() end
        return true
    end
    return false
end

local function stopAutoSpawn()
    if autoSpawnThread then pcall(task.cancel, autoSpawnThread); autoSpawnThread = nil end
    if totemWatchConn then totemWatchConn:Disconnect(); totemWatchConn = nil end
    if totemCreatedConn then totemCreatedConn:Disconnect(); totemCreatedConn = nil end
    Config.AutoSpawnTotem = false
end

local function startAutoSpawn()
    stopAutoSpawn()
    Config.AutoSpawnTotem = true
    task.spawn(spawnTotem)
end

Window:AddDropdown(TotemSection, "Select Totem", "", TOTEM_LIST, false, Config.SelectedTotem, function(value)
    Config.SelectedTotem = value or "Luck Totem"
end, "Dropdown_Select Totem")

Window:AddButton(TotemSection, "Refresh Totem List", "", "rbxassetid://16932740082", function()
    local inv = nil
    pcall(function() inv = PlayerData:Get("Inventory") end)
    if not inv or not inv.Totems then
        Orvion:Notify({ Title="Orvion", Subtitle="Hub", Content="Inventory not found", Color=Color3.fromRGB(150,150,170), Delay=2 })
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
            local d = ItemUtility.GetItemDataFromItemType("Totems", typeId)
            if d and d.Data and d.Data.Name then name = d.Data.Name end
        end)
        table.insert(names, name)
    end
    local content = #names > 0 and table.concat(names, ", ") or "No totems found"
    Orvion:Notify({ Title="Orvion", Subtitle="Hub", Content=content, Color=Color3.fromRGB(150,150,170), Delay=4 })
end)

Window:AddToggle(TotemSection, "Auto Spawn Totem", "", false, function(state)
    Config.AutoSpawnTotem = state
    if state then startAutoSpawn() else stopAutoSpawn() end
end, "Toggle_Auto Spawn Totem")

Window:AddButton(TotemSection, "Spawn Now", "", "rbxassetid://16932740082", function()
    spawnTotem(true)
end)

-- Helper: update paragraph text, support both old (Frame) dan new (table:Set) library
local function setParagraphText(para, text)
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
    local EnchantSection = Window:AddCollapsible(AutomationTab, "Enchant Features", false)
    Window:AddParagraph(EnchantSection, "Enchant Status", "Current Rod: None\nEnchant 1: None\nEnchant 2: None\nEnchant Stones Left: 0")
    local EST = {"Normal Enchant Stone", "Runic Enchant Stone", "Evolved Enchant Stone"}
    Window:AddDropdown(EnchantSection, "Enchant Type", "", EST, false, "Normal Enchant Stone", function(v)
        Config.EnchantType = v or "Normal Enchant Stone"
    end, "Dropdown_Enchant Type")
    Window:AddDropdown(EnchantSection, "Target Enchant", "", {}, false, "Select Option", function(v)
        Config.TargetEnchant = v or "Select Option"
    end, "Dropdown_Target Enchant")
    Window:AddToggle(EnchantSection, "Auto Enchant Reroll", "", false, function(state)
        Config.AutoEnchantReroll = state
    end, "Toggle_Auto Enchant Reroll")
    Window:AddButtonGrid(EnchantSection,
        { Title = "Teleport to Altar 1", Callback = function()
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then pcall(function() root.CFrame = CFrame.new(3246.00122, -1300.65588, 1395.11926, -0.430797249, 0, 0.902448714, 0, 1, 0, -0.902448714, 0, -0.430797249) end) end
        end },
        { Title = "Teleport to Altar 2", Callback = function()
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then pcall(function() root.CFrame = CFrame.new(1478.63489, 130.679703, -609.361938, -0.996601522, 2.26994281e-08, -0.0823735297, 2.58843453e-08, 1, -3.7596422e-08, 0.0823735297, -3.96008382e-08, -0.996601522) end) end
        end }
    )
end

-- ===== CREATE TRANSCENDED STONE =====
do
    local TranscendedSection = Window:AddCollapsible(AutomationTab, "Create Transcended Stone", false)
    Window:AddParagraph(TranscendedSection, "Status", "Waiting")
    Window:AddDropdown(TranscendedSection, "Select Secret Fish", "", {}, false, "Select Option", function(v)
        Config.SelectedSecretFish = v or "Select Option"
    end, "Dropdown_Select Secret Fish")
Window:AddButton(TranscendedSection, "Refresh Fish List", "", "rbxassetid://16932740082", function() end)
    Window:AddInput(TranscendedSection, "Amount", "", "Enter amount...", function(v)
        Config.TranscendedAmount = tonumber(v) or 1
    end, "Input_Transcended Amount")
    Window:AddToggle(TranscendedSection, "Enable Auto Create", "", false, function(state)
        Config.AutoCreateTranscended = state
    end, "Toggle_Enable Auto Create")
end

local ShopTab = Window:CreateTab("Shop", "rbxassetid://87353934937155")

-- ==========================================
-- ROD FEATURES
-- ==========================================
local ROD_MAP = {
    ["Starter Rod"]=1, ["Luck Rod"]=79, ["Carbon Rod"]=76, ["Grass Rod"]=85,
    ["Demascus Rod"]=77, ["Ice Rod"]=78, ["Lucky Rod"]=4, ["Midnight Rod"]=80,
    ["Seabreeze Rod"]=657, ["Eclipse Rod"]=656, ["Steampunk Rod"]=6, ["Chrome Rod"]=7,
    ["Fluorescent Rod"]=255, ["Magma Rod"]=3, ["Astral Rod"]=5, ["Ares Rod"]=126,
    ["Angler Rod"]=168, ["Bamboo Rod"]=258,
}
local ROD_LIST = {"Starter Rod","Luck Rod","Carbon Rod","Grass Rod","Demascus Rod","Ice Rod",
    "Lucky Rod","Midnight Rod","Seabreeze Rod","Eclipse Rod","Steampunk Rod","Chrome Rod",
    "Fluorescent Rod","Magma Rod","Astral Rod","Ares Rod","Angler Rod","Bamboo Rod"}

local RodSection = Window:AddCollapsible(ShopTab, "Rod Features", false)

Window:AddDropdown(RodSection, "Select Rod", "", ROD_LIST, false, Config.SelectedRod, function(v)
    Config.SelectedRod = v or "Starter Rod"
end, "Dropdown_Select Rod")

Window:AddButton(RodSection, "Buy Rod", "", "rbxassetid://16932740082", function()
    local rodId = ROD_MAP[Config.SelectedRod]
    if not rodId or not purchaseRodRF then
        Orvion:Notify({ Title="Orvion", Subtitle="Hub", Content="Remote not found", Color=Color3.fromRGB(150,150,170), Delay=2 })
        return
    end
    local ok, success, uuid = pcall(function() return purchaseRodRF:InvokeServer(rodId) end)
    if ok then
        if success and uuid and equipItemRE then
            pcall(function() equipItemRE:FireServer(uuid, "Fishing Rods") end)
        end
        Orvion:Notify({ Title="Orvion", Subtitle="Hub", Content=Config.SelectedRod .. (success and " bought" or " failed"), Color=Color3.fromRGB(150,150,170), Delay=3 })
    else
        Orvion:Notify({ Title="Orvion", Subtitle="Hub", Content="Purchase failed", Color=Color3.fromRGB(150,150,170), Delay=2 })
    end
end)

-- ==========================================
-- BAIT FEATURES
-- ==========================================
local BAIT_MAP = {
    ["Topwater Bait"]=10, ["Luck Bait"]=2, ["Midnight Bait"]=3, ["Nature Bait"]=17,
    ["Chroma Bait"]=6, ["Dark Matter Bait"]=8, ["Corrupt Bait"]=15, ["Aether Bait"]=16,
    ["Singularity Bait"]=18,
}
local BAIT_LIST = {"Topwater Bait","Luck Bait","Midnight Bait","Nature Bait",
    "Chroma Bait","Dark Matter Bait","Corrupt Bait","Aether Bait","Singularity Bait"}

local BaitSection = Window:AddCollapsible(ShopTab, "Bait Features", false)

Window:AddDropdown(BaitSection, "Select Bait", "", BAIT_LIST, false, Config.SelectedBait, function(v)
    Config.SelectedBait = v or "Topwater Bait"
end, "Dropdown_Select Bait")

Window:AddButton(BaitSection, "Buy Bait", "", "rbxassetid://16932740082", function()
    local baitId = BAIT_MAP[Config.SelectedBait]
    if not baitId or not purchaseBaitRF then
        Orvion:Notify({ Title="Orvion", Subtitle="Hub", Content="Remote not found", Color=Color3.fromRGB(150,150,170), Delay=2 })
        return
    end
    local ok, success, shouldEquip = pcall(function() return purchaseBaitRF:InvokeServer(baitId) end)
    if ok then
        if shouldEquip and equipBaitRE then
            pcall(function() equipBaitRE:FireServer(baitId) end)
        end
        Orvion:Notify({ Title="Orvion", Subtitle="Hub", Content=Config.SelectedBait .. (success and " bought" or " failed"), Color=Color3.fromRGB(150,150,170), Delay=3 })
    else
        Orvion:Notify({ Title="Orvion", Subtitle="Hub", Content="Purchase failed", Color=Color3.fromRGB(150,150,170), Delay=2 })
    end
end)

-- ==========================================
-- BLACK MARKET FEATURES
-- ==========================================
local BM_MAP = {
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
local BM_LIST = {"Undersea Racer","Venombone","Phantom Tide","Raging Hadalith",
    "Mecha Nautical Trinket","Basic Flippers","Gilded Boots","Winged Boots M","Winged Boots F",
    "Luck III Potion","Mutation III Potion","Mutation IV Potion","Dark Megalodon Hunt Potion",
    "Megalodon Hunt Potion","Meteor Shower Potion","Aurora Borealis Potion",
    "Glacial Serpent Hunt Potion","Coin Toss Emote","Minor Fortune Ability"}

local BM_CF = CFrame.new(-8610.20312, -66.52478, -451.74463, -0.2025885880, -0.0000000350,
    -0.9792639613, -0.0000000417, 1.0000000000, -0.0000000271, 0.9792639613, 0.0000000354, -0.2025885880)

local autoBuyBMThread = nil

local function buyBMItem(itemName)
    local itemId = BM_MAP[itemName]
    if not itemId or not purchaseBMRF then return false end
    local ok, result = pcall(function() return purchaseBMRF:InvokeServer(itemId) end)
    return ok and result and (type(result) == "table" and result.Success or result == true)
end



local function startAutoBuyBM()
    if autoBuyBMThread then pcall(task.cancel, autoBuyBMThread); autoBuyBMThread = nil end
    Config.AutoBuyBM = true
    autoBuyBMThread = task.spawn(function()
        local root = game:GetService("Players").LocalPlayer.Character
            and game:GetService("Players").LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local preBMCF = root and root.CFrame
        teleportToBM(BM_CF)
        task.wait(1.5)
        local bought = {}
        for _, name in ipairs(Config.SelectedBMItems) do
            if buyBMItem(name) then
                table.insert(bought, name)
            end
        end
        task.wait(0.5)
        if preBMCF and root then root.CFrame = preBMCF end
        Config.AutoBuyBM = false
        autoBuyBMThread = nil
        if bmToggleFunc then task.defer(function() pcall(function() bmToggleFunc:Set(false) end) end) end
        if #bought > 0 then
            Orvion:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="Bought: " .. table.concat(bought, ", "), Color=Color3.fromRGB(150,150,170), Delay=4 })
        else
            Orvion:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="Nothing bought / out of stock", Color=Color3.fromRGB(150,150,170), Delay=3 })
        end
    end)
end

local BMSection = Window:AddCollapsible(ShopTab, "Black Market Features", false)

Window:AddDropdown(BMSection, "Select Item", "", BM_LIST, 999, {}, function(selected)
    Config.SelectedBMItems = type(selected) == "table" and selected or {}
end, "Dropdown_Select BM Item")

Window:AddButton(BMSection, "Refresh List", "", "rbxassetid://16932740082", function()
    local ok, BMC = pcall(function() return require(game:GetService("ReplicatedStorage").Shared.BlackMarketConfig) end)
    if ok and BMC then
        local ok2, items = pcall(function() return BMC.GetItems() end)
        if ok2 and items then
            Orvion:Notify({ Title="Orvion", Subtitle="Hub", Content="Stock refreshed", Color=Color3.fromRGB(150,150,170), Delay=2 })
        end
    end
end)

local bmToggleFunc = nil
bmToggleFunc = Window:AddToggle(BMSection, "Buy Black Market Item", "", false, function(state)
    Config.AutoBuyBM = state
    if state then
        startAutoBuyBM()
    else
        if autoBuyBMThread then pcall(task.cancel, autoBuyBMThread); autoBuyBMThread = nil end
        Config.AutoBuyBM = false
    end
end, "Toggle_Buy Black Market Item")

-- ==========================================
-- BATTLEPASS SHOP FEATURES
-- ==========================================
local BP_LIST = {
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

local bpStatusLabel = nil
local autoBuyBPThread = nil
local bpToggleFunc = nil

local function updateBPStatus(text)
    if bpStatusLabel then
        setParagraphText(bpStatusLabel, text)
    end
end

local function buyBPSlots()
    if not bpPurchaseRE then
        Orvion:Notify({ Title="Orvion", Subtitle="Hub", Content="Remote not found", Color=Color3.fromRGB(150,150,170), Delay=2 })
        return
    end
    local slots = Config.SelectedBPSlots
    if not slots or #slots == 0 then
        updateBPStatus("No slots selected")
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
                local bp = PlayerData:Get("GalaxyBP26")
                if bp and bp[tostring(index)] then owned = true end
            end)
            if not owned then
                updateBPStatus("Buy " .. i .. "/" .. total .. " (Slot " .. index .. ")")
                pcall(function() bpPurchaseRE:FireServer(index) end)
                bought = bought + 1
                task.wait(0.8)
            else
                updateBPStatus("Slot " .. index .. " already owned, skip")
            end
        end
    end
    updateBPStatus("Done  bought " .. bought .. "/" .. total)
    if bought == 0 and total > 0 then
        Orvion:Notify({ Title="Orvion", Subtitle="Hub", Content="No Galaxy Points or all slots owned", Color=Color3.fromRGB(150,150,170), Delay=4 })
    end
    Config.AutoBuyBP = false
    if bpToggleFunc then task.defer(function() pcall(function() bpToggleFunc:Set(false) end) end) end
end

local BPSection = Window:AddCollapsible(ShopTab, "Battlepass Shop Features", false)

bpStatusLabel = Window:AddParagraph(BPSection, "Status", "Waiting")

Window:AddDropdown(BPSection, "Buy Item", "", BP_LIST, 999, {}, function(selected)
    Config.SelectedBPSlots = type(selected) == "table" and selected or {}
end, "Dropdown_Select BP Slots")

bpToggleFunc = Window:AddToggle(BPSection, "Buy Battlepass Item", "", false, function(state)
    Config.AutoBuyBP = state
    if state then
        updateBPStatus("Starting...")
        autoBuyBPThread = task.spawn(function()
            buyBPSlots()
        end)
    else
        if autoBuyBPThread then pcall(task.cancel, autoBuyBPThread); autoBuyBPThread = nil end
        Config.AutoBuyBP = false
        updateBPStatus("Waiting")
    end
end, "Toggle_Buy Battlepass Item")

-- ==========================================
-- MERCHANT FEATURES
-- ==========================================
local merchantItems = {}
local merchantStatusParagraph = nil

local function updateMerchantStatus(bought, total)
    local itemName = Config.SelectedMerchantItem
    local price = "?"
    if merchantItems[itemName] then price = tostring(merchantItems[itemName].price or "?") end
    local buyStr = bought and (bought .. "/" .. total) or "0/1"
    local content = "Item: " .. (itemName ~= "Select Option" and itemName or "-") ..
        "\nPrice: " .. price .. " Coins" ..
        "\nBuy: " .. buyStr
    setParagraphText(merchantStatusParagraph, content)
end

local MerchantSection = Window:AddCollapsible(ShopTab, "Merchant Features", false)

merchantStatusParagraph = Window:AddParagraph(MerchantSection, "Status", "Item: -\nPrice: ? Coins\nBuy: 0/1")

local merchantDropdownItems = {}
local merchantDropdown = Window:AddDropdown(MerchantSection, "Select Item", "", merchantDropdownItems, false, nil, function(v)
    Config.SelectedMerchantItem = v or "Select Option"
    updateMerchantStatus()
end, "Dropdown_Select Merchant Item")

Window:AddInput(MerchantSection, "Quantity", "", "Enter quantity...", function(v)
    Config.MerchantQty = tonumber(v) or 1
end, "Input_Merchant Qty")

Window:AddButton(MerchantSection, "Refresh Item Merchant", "", "rbxassetid://16932740082", function()
    local mr = nil
    pcall(function() mr = Replion.Client:WaitReplion("Merchant") end)
    if not mr then
        Orvion:Notify({ Title="Orvion", Subtitle="Hub", Content="Replion not found", Color=Color3.fromRGB(150,150,170), Delay=2 })
        return
    end
    local ok2, MID = pcall(function() return require(game:GetService("ReplicatedStorage").Shared.MarketItemData) end)
    local ok3, IU  = pcall(function() return require(game:GetService("ReplicatedStorage").Shared.ItemUtility) end)
    -- build MarketItemData map
    local midMap = {}
    if ok2 and MID then
        for _, v in ipairs(MID) do midMap[v.Id] = v end
    end
    local itemIds = {}
    pcall(function() itemIds = mr:GetExpect("Items") or {} end)
    merchantItems = {}
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
        merchantItems[name] = { id = itemId, price = price }
        table.insert(newList, name)
    end
    local defaultItem = newList[1] or "Select Option"
    Config.SelectedMerchantItem = defaultItem
    if merchantDropdown then
        pcall(function() merchantDropdown:Refresh(newList, defaultItem) end)
    end
    updateMerchantStatus()
    Orvion:Notify({ Title="Orvion", Subtitle="Hub", Content=tostring(#newList) .. " items found", Color=Color3.fromRGB(150,150,170), Delay=2 })
end)

local merchantBuying = false
Window:AddButton(MerchantSection, "Buy Manual", "", "rbxassetid://16932740082", function()
    if merchantBuying then return end
    merchantBuying = true
    local name = Config.SelectedMerchantItem
    if name == "Select Option" or not merchantItems[name] then
        Orvion:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="Select item first", Color=Color3.fromRGB(150,150,170), Delay=2 })
        merchantBuying = false
        return
    end
    local itemId = merchantItems[name].id
    local price = tonumber(merchantItems[name].price) or 0
    local coins = 0
    pcall(function() coins = PlayerData:GetExpect("Coins") or 0 end)
    if price > 0 and coins < price then
        Orvion:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="Not enough coins", Color=Color3.fromRGB(150,150,170), Delay=3 })
        merchantBuying = false
        return
    end
    local qty = 1
    local bought = 0
    for i = 1, qty do
        updateMerchantStatus(bought, qty)
        local ok, result = pcall(function() return purchaseMerchantRF:InvokeServer(itemId) end)
        if ok and result then
            bought = bought + 1
        else
            local c = 0
            pcall(function() c = PlayerData:GetExpect("Coins") or 0 end)
            if price > 0 and c < price then
                Orvion:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="Not enough coins", Color=Color3.fromRGB(150,150,170), Delay=3 })
                break
            end
        end
        updateMerchantStatus(bought, qty)
        if i < qty then task.wait(0.5) end
    end
    updateMerchantStatus(bought, qty)
    Orvion:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content=name .. " x" .. bought .. " bought", Color=Color3.fromRGB(150,150,170), Delay=3 })
    merchantBuying = false
end)

local autoBuyMerchantThread = nil
local merchantToggleFunc = nil
merchantToggleFunc = Window:AddToggle(MerchantSection, "Buy Merchant Item", "", false, function(state)
    Config.AutoBuyMerchant = state
    if state then
        autoBuyMerchantThread = task.spawn(function()
            local name = Config.SelectedMerchantItem
            if name == "Select Option" or not merchantItems[name] or not purchaseMerchantRF then
                Config.AutoBuyMerchant = false
                return
            end
            local itemId = merchantItems[name].id
            local price = tonumber(merchantItems[name].price) or 0
            local qty = math.max(1, Config.MerchantQty)
            local bought = 0
            for i = 1, qty do
                if not Config.AutoBuyMerchant then break end
                local coins = 0
                pcall(function() coins = PlayerData:GetExpect("Coins") or 0 end)
                if price > 0 and coins < price then
                    Orvion:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="Not enough coins", Color=Color3.fromRGB(150,150,170), Delay=3 })
                    break
                end
                updateMerchantStatus(bought, qty)
                local ok, result = pcall(function() return purchaseMerchantRF:InvokeServer(itemId) end)
                if ok and result then bought = bought + 1 end
                updateMerchantStatus(bought, qty)
                if i < qty then task.wait(0.5) end
            end
            Orvion:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content=name .. " x" .. bought .. " bought", Color=Color3.fromRGB(150,150,170), Delay=3 })
            Config.AutoBuyMerchant = false
            if merchantToggleFunc then task.defer(function() pcall(function() merchantToggleFunc:Set(false) end) end) end
        end)
    else
        if autoBuyMerchantThread then pcall(task.cancel, autoBuyMerchantThread); autoBuyMerchantThread = nil end
        Config.AutoBuyMerchant = false
    end
end, "Toggle_Buy Merchant Item")

-- ====== STARTUP ======
updateBigPopup()
Window:SetActiveTab("Info")
Window:Show()

