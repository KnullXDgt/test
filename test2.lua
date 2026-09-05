-- ====================================================================
--                 INSTANT FISHING V2 - CLEAN
--          Fishing + AutoSell + Auto Small Notification
-- Fish-tier + Quest/Trade lifecycle hardening build: 20260903-R30-TradeAFKHardening
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

-- Trading remotes
Remote.tradeSendOffer     = Remote.Resolve("RF/Trading/SendTradeOffer")
Remote.tradeAcceptOffer   = Remote.Resolve("RF/Trading/AcceptTradeOffer")
Remote.tradeDeclineOffer  = Remote.Resolve("RF/Trading/DeclineTradeOffer")
Remote.tradeAddItem       = Remote.Resolve("RF/Trading/AddItem")
Remote.tradeSetReady      = Remote.Resolve("RF/Trading/SetReady")
Remote.tradeConfirm       = Remote.Resolve("RF/Trading/ConfirmTrade")
Remote.tradeCancel        = Remote.Resolve("RF/Trading/CancelTrade")
Remote.tradeOfferReceived = Remote.Resolve("RE/Trading/TradeOfferReceived")
Remote.tradeStarted       = Remote.Resolve("RE/Trading/TradeStarted")
Remote.tradeEnded         = Remote.Resolve("RE/Trading/TradeEnded")
Remote.tradeCompleted     = Remote.Resolve("RE/Trading/TradeCompleted")

-- Trade remotes are discovered heuristically by this project.  Validate the
-- resolved Instance class before any worker can retry against a wrong sibling.
for key, expectedClass in pairs({
    tradeSendOffer="RemoteFunction", tradeAcceptOffer="RemoteFunction",
    tradeDeclineOffer="RemoteFunction", tradeAddItem="RemoteFunction",
    tradeSetReady="RemoteFunction", tradeConfirm="RemoteFunction",
    tradeCancel="RemoteFunction", tradeOfferReceived="RemoteEvent",
    tradeStarted="RemoteEvent", tradeEnded="RemoteEvent",
    tradeCompleted="RemoteEvent",
}) do
    local remote = Remote[key]
    local valid = remote ~= nil
    if valid then
        local ok, isExpected = pcall(function() return remote:IsA(expectedClass) end)
        valid = ok and isExpected == true
    end
    if not valid then
        if remote ~= nil then
            warn("[Orvion Trade] invalid resolver mapping: " .. tostring(key)
                .. " expected " .. expectedClass)
        end
        Remote[key] = nil
    end
end

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

-- Trade Offer lifecycle.  R23 keeps receiver-side connections generation-owned:
-- Auto Accept OFF restores native handling, refreshes are serialized, and a stale
-- script generation cannot disable or accept for the current generation.
local TradeEnv = (type(getgenv) == "function" and getgenv() or _G)

Remote.TradeLifecycle = TradeEnv.__OrvionTradeLifecycle
if type(Remote.TradeLifecycle) ~= "table" then
    Remote.TradeLifecycle = { Generation = 0, Connections = {} }
    TradeEnv.__OrvionTradeLifecycle = Remote.TradeLifecycle
end
-- Invalidate delayed callbacks/tasks from the previous execution first.
Remote.TradeLifecycle.Generation = (Remote.TradeLifecycle.Generation or 0) + 1
local TradeLifecycleGeneration = Remote.TradeLifecycle.Generation
for connection in pairs(Remote.TradeLifecycle.Connections or {}) do
    pcall(function() connection:Disconnect() end)
end
Remote.TradeLifecycle.Connections = {}

Remote.TrackTradeConnection = function(connection)
    if connection then Remote.TradeLifecycle.Connections[connection] = true end
    return connection
end
Remote.UntrackTradeConnection = function(connection)
    if connection then Remote.TradeLifecycle.Connections[connection] = nil end
end
Remote.TradeGenerationAlive = function(generation)
    return Remote.TradeLifecycle.Generation == (generation or TradeLifecycleGeneration)
end

Remote.TradeOfferRouter = TradeEnv.__OrvionTradeOfferRouter
if type(Remote.TradeOfferRouter) ~= "table" then
    Remote.TradeOfferRouter = {}
    TradeEnv.__OrvionTradeOfferRouter = Remote.TradeOfferRouter
end
local Router = Remote.TradeOfferRouter

-- R25 receiver ownership hardening.
-- One-time migration from R22: that build disabled every TradeOfferReceived
-- connection but did not retain the stock handles for OFF/re-execute restore.
-- Recover those disabled native handlers before disconnecting the old Orvion
-- listener so the first R23 execution does not require a rejoin.
local previousRouterConnection = Router.Connection
if Router.LifecycleVersion ~= 25 and Remote.tradeOfferReceived
    and type(getconnections) == "function"
then
    local ok, connections = pcall(getconnections, Remote.tradeOfferReceived.OnClientEvent)
    if ok and type(connections) == "table" then
        for _, connection in ipairs(connections) do
            if connection ~= previousRouterConnection then
                pcall(function() connection:Enable() end)
            end
        end
    end
end
Router.LifecycleVersion = 25

-- Clean the previous router deterministically.  Native connections disabled by
-- Orvion are restored before the new generation starts.
Router.Generation = (Router.Generation or 0) + 1
local RouterGeneration = Router.Generation
Router.Enabled = false
Router.AcceptEpoch = (Router.AcceptEpoch or 0) + 1
Router.PendingAccept = nil
if Router.RefreshWorker then
    pcall(task.cancel, Router.RefreshWorker)
    Router.RefreshWorker = nil
end
if Router.SuppressWorker then
    pcall(task.cancel, Router.SuppressWorker)
    Router.SuppressWorker = nil
end
if Router.Connection then
    pcall(function() Router.Connection:Disconnect() end)
    Router.Connection = nil
end
if Router.RespawnConnection then
    pcall(function() Router.RespawnConnection:Disconnect() end)
    Router.RespawnConnection = nil
end
for _, connection in ipairs(Router.StockConnections or {}) do
    pcall(function() connection:Enable() end)
end
Router.StockConnections = {}
-- AFK hardening: avoid retaining the exact same getconnections() wrapper
-- thousands of times during the 0.75s R25 watchdog. Weak keys do not keep
-- wrappers alive by themselves and do not rely on identity for suppression;
-- they only reduce duplicate retention when an executor returns stable wrappers.
Router.StockConnectionSeen = setmetatable({}, { __mode = "k" })
Router.RefreshRequested = 0
Router.RefreshHandled = 0
Router.RefreshAttempts = 0

local function routerAlive()
    return Router.Generation == RouterGeneration
        and Remote.TradeGenerationAlive(TradeLifecycleGeneration)
end

Remote.RestoreStockTradeOfferConnections = function()
    if Router.Generation ~= RouterGeneration then return false end
    local restored = false
    for _, connection in ipairs(Router.StockConnections or {}) do
        pcall(function() connection:Enable() end)
        restored = true
    end
    Router.StockConnections = {}
    Router.StockConnectionSeen = setmetatable({}, { __mode = "k" })
    return restored
end

-- IMPORTANT: executor getconnections() wrappers are not guaranteed to compare
-- equal to the RBXScriptConnection returned by :Connect().  Therefore never try
-- to protect Orvion's receiver with `connection ~= Router.Connection`.
--
-- Instead each suppression pass temporarily disconnects Orvion's own listener,
-- scans/disables only what remains (the game's/native listeners), then reconnects
-- Orvion immediately.  Because R23+ serializes refreshes, this no longer has the
-- old overlapping-refresh race.
Remote.ConnectTradeOfferRouter = function()
    if not routerAlive() or not Remote.tradeOfferReceived then return false end
    if Router.Connection then
        pcall(function() Router.Connection:Disconnect() end)
        Router.Connection = nil
    end
    if type(Router.HandleOffer) ~= "function" then return false end
    Router.Connection = Remote.tradeOfferReceived.OnClientEvent:Connect(Router.HandleOffer)
    return Router.Connection ~= nil
end

Remote.DisableStockTradeOfferConnections = function(attempts)
    if not routerAlive() or Router.Enabled ~= true
        or not Remote.tradeOfferReceived or type(getconnections) ~= "function"
    then return false end

    local wantedAttempts = math.max(1, tonumber(attempts) or 1)
    local found = false
    for attempt = 1, wantedAttempts do
        if not routerAlive() or Router.Enabled ~= true then break end

        -- Remove our listener BEFORE getconnections().  This is the only robust
        -- way to guarantee a getconnections wrapper for Orvion itself cannot be
        -- mistaken for a stock handler on executors with wrapper identity quirks.
        if Router.Connection then
            pcall(function() Router.Connection:Disconnect() end)
            Router.Connection = nil
        end

        local ok, connections = pcall(getconnections,
            Remote.tradeOfferReceived.OnClientEvent)
        if ok and type(connections) == "table" then
            for _, connection in ipairs(connections) do
                local disabled = pcall(function() connection:Disable() end)
                if disabled then
                    -- Suppression never depends on wrapper identity.  For retention
                    -- only, skip an exact wrapper object already cached so the
                    -- long-running watchdog does not grow the restore list needlessly
                    -- on executors that return stable getconnections() wrappers.
                    local seen = Router.StockConnectionSeen
                    if type(seen) ~= "table" then
                        seen = setmetatable({}, { __mode = "k" })
                        Router.StockConnectionSeen = seen
                    end
                    if not seen[connection] then
                        seen[connection] = true
                        table.insert(Router.StockConnections, connection)
                    end
                    found = true
                end
            end
        end

        -- Reconnect immediately after every scan so the receiver is absent only
        -- for the tiny synchronous getconnections window, not the whole retry pass.
        if routerAlive() and Router.Enabled == true then
            Remote.ConnectTradeOfferRouter()
        end

        if attempt < wantedAttempts then task.wait(0.1) end
    end
    return found
end

-- All refresh requests feed one worker.  Stale startup/autoload/respawn requests
-- can queue work, but they can no longer mutate connections concurrently.
Remote.RequestTradeOfferRefresh = function(attempts)
    if not routerAlive() or Router.Enabled ~= true then return false end
    Router.RefreshRequested = (Router.RefreshRequested or 0) + 1
    Router.RefreshAttempts = math.max(Router.RefreshAttempts or 0,
        math.max(1, tonumber(attempts) or 1))
    if Router.RefreshWorker then return true end
    Router.RefreshWorker = task.spawn(function()
        while routerAlive() and Router.Enabled == true
            and (Router.RefreshHandled or 0) < (Router.RefreshRequested or 0)
        do
            local request = Router.RefreshRequested
            local scanAttempts = math.max(1, Router.RefreshAttempts or 1)
            Router.RefreshAttempts = 0
            Remote.DisableStockTradeOfferConnections(scanAttempts)
            if not routerAlive() then break end
            Router.RefreshHandled = request
            task.wait()
        end
        if routerAlive() then Router.RefreshWorker = nil end
    end)
    return true
end

-- Compatibility name used by the older UI callback.
Remote.RefreshTradeOfferRouter = Remote.RequestTradeOfferRefresh

-- R25: native TradingController may subscribe to TradeOfferReceived well after
-- the startup/autoload refresh burst. Keep ownership of that signal for the
-- entire time Auto Accept is enabled instead of assuming controller load has
-- finished within four seconds. The watchdog only suppresses TradeOfferReceived
-- handlers; it never touches TradeStarted/Ended/Completed or trade session UI.
Remote.StartTradeOfferSuppressWatchdog = function()
    if not routerAlive() or Router.Enabled ~= true then return false end
    if Router.SuppressWorker then return true end
    Router.SuppressWorker = task.spawn(function()
        while routerAlive() and Router.Enabled == true do
            Remote.RequestTradeOfferRefresh(1)
            task.wait(0.75)
        end
        if routerAlive() then Router.SuppressWorker = nil end
    end)
    return true
end

Remote.StopTradeOfferSuppressWatchdog = function()
    if Router.SuppressWorker then
        pcall(task.cancel, Router.SuppressWorker)
        Router.SuppressWorker = nil
    end
end

Remote.SetTradeOfferRouterEnabled = function(state)
    if not routerAlive() then return false end
    Router.AcceptEpoch = (Router.AcceptEpoch or 0) + 1
    Router.PendingAccept = nil
    Router.Enabled = state == true
    if Router.Enabled then
        -- Close the immediate ON race synchronously, then let the serialized
        -- worker catch subscriptions that appear during later loading frames.
        Remote.DisableStockTradeOfferConnections(1)
        Remote.RequestTradeOfferRefresh(20)
        -- Late controller subscriptions are submitted to the same serialized
        -- refresh worker instead of running competing getconnections scans.
        for _, delay in ipairs({0.5, 1, 2, 4}) do
            task.delay(delay, function()
                if routerAlive() and Router.Enabled == true then
                    Remote.RequestTradeOfferRefresh(1)
                end
            end)
        end
        -- Unlike R23/R24, suppression does not stop after the startup burst.
        -- Different clients can initialize TradingController at different times.
        Remote.StartTradeOfferSuppressWatchdog()
    else
        Remote.StopTradeOfferSuppressWatchdog()
        if Router.RefreshWorker then
            pcall(task.cancel, Router.RefreshWorker)
            Router.RefreshWorker = nil
        end
        Remote.RestoreStockTradeOfferConnections()
    end
    return true
end

Remote.InstallTradeOfferRouter = function()
    if not Remote.tradeOfferReceived or not routerAlive() then return false end

    Router.HandleOffer = function(sender)
        if not routerAlive() or Router.Enabled ~= true then return end

        -- R25 emergency pass: if a native popup listener subscribed between two
        -- watchdog ticks, suppress it synchronously as soon as Orvion observes
        -- the offer. This is a second line of defense; normal suppression is the
        -- continuous watchdog above. Disconnecting this connection while its
        -- callback is already running is safe; ConnectTradeOfferRouter recreates
        -- the receiver immediately.
        Remote.DisableStockTradeOfferConnections(1)

        if Service.LocalPlayer:GetAttribute("IsTrading") == true
            or Router.PendingAccept ~= nil
        then return end

        Router.LastOfferAt = os.clock()
        Router.LastOfferSender = sender

        -- Reserve this offer immediately.  A second incoming offer cannot wait in
        -- parallel during the fishing/sell/quest safe-point window.
        local reservation = {
            Generation = RouterGeneration,
            Epoch = Router.AcceptEpoch,
            Sender = sender,
        }
        Router.PendingAccept = reservation
        task.spawn(function()
            local coord = Remote.RuntimeCoord
            if not coord then
                Router.LastAcceptResult = "NO_RUNTIME"
                if Router.PendingAccept == reservation then Router.PendingAccept = nil end
                return
            end
            local function active()
                return routerAlive() and Router.Enabled == true
                    and Router.AcceptEpoch == reservation.Epoch
                    and Router.PendingAccept == reservation
            end
            local token = coord.beginTradeGate()
            if not token then
                Router.LastAcceptResult = "GATE_BUSY"
                if Router.PendingAccept == reservation then Router.PendingAccept = nil end
                return
            end
            local okAccept, accepted = false, false
            pcall(function()
                if coord.waitTradeSafe(active) and active() then
                    okAccept, accepted = coord.callRemote(
                        "tradeAcceptOffer", 10, active, sender)
                else
                    Router.LastAcceptResult = "SAFEPOINT_TIMEOUT"
                end
            end)
            if okAccept then
                Router.LastAcceptResult = accepted == false and "SERVER_FALSE" or "ACCEPT_SENT"
            elseif Router.LastAcceptResult ~= "SAFEPOINT_TIMEOUT" then
                Router.LastAcceptResult = "ACCEPT_CALL_FAILED"
            end

            -- If the server accepted, keep the reservation briefly until the
            -- authoritative IsTrading transition closes the pre-session race.
            if okAccept and accepted ~= false then
                local deadline = os.clock() + 3
                while active() and Service.LocalPlayer:GetAttribute("IsTrading") ~= true
                    and os.clock() < deadline
                do task.wait(0.05) end
            end
            coord.endTradeGate(token)
            if Router.PendingAccept == reservation then Router.PendingAccept = nil end
        end)
    end

    Remote.ConnectTradeOfferRouter()

    Router.RespawnConnection = Service.LocalPlayer.CharacterAdded:Connect(function()
        task.delay(1, function()
            if routerAlive() and Router.Enabled == true then
                Remote.RequestTradeOfferRefresh(10)
            end
        end)
    end)
    return true
end

Remote.InstallTradeOfferRouter()

-- The offer router is installed before player-data replication; everything
-- below may yield normally after the game UI connection has been disabled.
Data.Player = Data.Replion.Client:WaitReplion("Data")
Data.ItemUtility = require(Service.ReplicatedStorage.Shared.ItemUtility)
Data.TierUtility = require(Service.ReplicatedStorage.Shared.TierUtility)
Data.FishingConstants = require(Service.ReplicatedStorage.Shared.Constants)

-- One canonical fish catalog is shared by notifications, trading, quests,
-- Transcended creation, and the future webhook payload.  BackpackController
-- derives a Fish's displayed rarity from Probability.Chance; Data.Tier is
-- only the game's fallback for the few Fish entries without Probability.
Data.FishCatalog = {
    ById = {},
    ByName = {},
    Total = 0,
    Pictures = 0,
}

Data.getTierNumber = function(tierData)
    if type(tierData) == "table" then
        return tonumber(tierData.Tier)
            or tonumber(tierData.Id)
            or tonumber(tierData.Value)
    end
    return tonumber(tierData)
end

Data.resolveFishTier = function(raw)
    local data = type(raw) == "table" and (raw.Data or raw) or nil
    if type(data) ~= "table" or data.Type ~= "Fish" then return nil end
    local probability = type(raw) == "table"
        and (raw.Probability or data.Probability) or nil
    local chance = type(probability) == "table"
        and tonumber(probability.Chance) or nil
    if chance then
        local ok, tierData = pcall(function()
            return Data.TierUtility:GetTierFromRarity(chance)
        end)
        local tier = ok and Data.getTierNumber(tierData) or nil
        if tier then return tier end
    end
    return tonumber(data.Tier)
end

Data.normaliseFishIcon = function(icon)
    if type(icon) == "number" then
        return icon > 0 and ("rbxassetid://" .. tostring(icon)) or nil
    end
    if type(icon) ~= "string" then return nil end
    if icon:match("^%d+$") then return tonumber(icon) > 0 and ("rbxassetid://" .. icon) or nil end
    local assetId = icon:match("^rbxassetid://(%d+)$")
    if assetId then return tonumber(assetId) > 0 and icon or nil end
    if icon:match("^https?://") then return icon end
    return nil
end

Data.registerFish = function(raw)
    local data = type(raw) == "table" and raw.Data or nil
    if type(data) ~= "table" or data.Type ~= "Fish" then return nil end
    local id = tonumber(data.Id) or data.Id
    if id == nil then return nil end
    local name = tostring(data.Name or id)
    local previous = Data.FishCatalog.ById[id]
    if previous then
        if Data.FishCatalog.ByName[previous.Name] == previous then Data.FishCatalog.ByName[previous.Name] = nil end
        if previous.Icon then Data.FishCatalog.Pictures = Data.FishCatalog.Pictures - 1 end
    else Data.FishCatalog.Total = Data.FishCatalog.Total + 1 end
    local record = {Id=id, Name=name, Icon=Data.normaliseFishIcon(raw.Icon or data.Icon),
        Tier=Data.resolveFishTier(raw)}
    Data.FishCatalog.ById[id] = record
    Data.FishCatalog.ByName[name] = record
    if record.Icon then Data.FishCatalog.Pictures = Data.FishCatalog.Pictures + 1 end
    if Data.OnFishRegistered then Data.OnFishRegistered(record, previous) end
    return record
end

Data.refreshFishCatalog = function()
    local ok, fishList = pcall(function() return Data.ItemUtility:GetFish() end)
    Data.FishCatalog.LastRefresh = os.clock()
    if not ok or type(fishList) ~= "table" then
        Data.FishCatalog.LastError = tostring(fishList)
        return false
    end
    for _, raw in pairs(fishList) do Data.registerFish(raw) end
    Data.FishCatalog.LastError = nil
    return true
end

Data.getFishRecord = function(idOrName, raw)
    local key = type(idOrName) == "table"
        and (idOrName.Id or idOrName.Identifier or idOrName.Name)
        or idOrName
    local idKey = tonumber(key) or key
    local record = key ~= nil and (
        Data.FishCatalog.ById[idKey]
        or Data.FishCatalog.ByName[tostring(key)]
    ) or nil
    if type(raw) == "table" and raw.Data then return Data.registerFish(raw) end
    if record then return record end
    if os.clock() - (Data.FishCatalog.LastRefresh or -30) >= 30 then
        Data.refreshFishCatalog()
        return Data.FishCatalog.ById[idKey] or Data.FishCatalog.ByName[tostring(key)]
    end
    return nil
end

Data.getFishTier = function(idOrItem, raw)
    local record = Data.getFishRecord(idOrItem, raw)
    if record and record.Tier then return record.Tier end
    if type(raw) == "table" then return Data.resolveFishTier(raw) end
    local id = type(idOrItem) == "table"
        and (idOrItem.Id or idOrItem.Identifier) or idOrItem
    if id ~= nil then
        local ok, itemData = pcall(
            Data.ItemUtility.GetItemDataFromItemType, "Fish", id)
        if ok and itemData and itemData.Data
            and itemData.Data.Type == "Fish"
        then
            record = Data.registerFish(itemData)
            return record and record.Tier or Data.resolveFishTier(itemData)
        end
    end
    return nil
end

do
    local loaded = Data.refreshFishCatalog()
    print(loaded and ("%d fish pics loaded, all set."):format(Data.FishCatalog.Pictures)
        or "Fish pics load failed; waiting for catalogue retry.")
end

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
    LegitShakeDelay   = 0.05,
    LegitAutoShake    = false,
    SkipRarityEnabled = false,
    SkipRarityTiers   = {},
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
    RemoteCalls = {},
    Trade = { Gates={}, Serial=0, SessionId=nil },
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
        ThreadSessions = {},-- session currently owned by each thread handle
        Sessions = {},      -- generation per toggle; invalidates stale tasks
        SellHold = 0,       -- derived from HoldTokens; never force-reset
        HoldTokens = {},
        HoldMeta = {},
        HoldSerial = 0,
        Action = {
            Busy=false, Owner=nil, Ticket=0, HoldToken=nil,
            Job=nil, Session=nil,
        },
        Failures = {},
        RouteRetry = {},
        CompletionNotified = {},
        FallbackUntil = 0,
        Paused = false,

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
    Legit = { Thread = nil, Active = false },
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
Catalog.RarityTiers = {"Common","Uncommon","Rare","Epic","Legendary","Mythic","Secret","Forgotten"}
Catalog.RarityTiersNoCommon = {"Uncommon","Rare","Epic","Legendary","Mythic","Secret","Forgotten"}

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

-- Bounded local waits do not undo a request already received by the server.
Runtime.callRemote = function(key, timeout, alive, ...)
    if not Remote[key] then return false, "remote unavailable: " .. key end
    if Runtime.RemoteCalls[key] then return false, "remote busy: " .. key end
    if alive and not alive() then return false, "cancelled" end
    local args, token = table.pack(...), {}
    Runtime.RemoteCalls[key] = token
    local done, result = false, nil
    local thread = task.spawn(function()
        result = table.pack(pcall(function()
            return Remote[key]:InvokeServer(table.unpack(args, 1, args.n))
        end))
        done = true
    end)
    local deadline = os.clock() + (timeout or 8)
    task.delay((timeout or 8) + 0.05, function()
        if Runtime.RemoteCalls[key] == token then
            if not done then pcall(task.cancel, thread) end
            Runtime.RemoteCalls[key] = nil
        end
    end)
    while not done and os.clock() < deadline and (not alive or alive()) do task.wait(0.05) end
    if not done then pcall(task.cancel, thread) end
    if Runtime.RemoteCalls[key] == token then Runtime.RemoteCalls[key] = nil end
    if not done then return false, "timeout/cancelled: " .. key end
    if alive and not alive() then return false, "cancelled" end
    return table.unpack(result, 1, result.n)
end

Runtime.isTrading = function()
    local char = Service.LocalPlayer.Character
    return next(Runtime.Trade.Gates) ~= nil or Runtime.Trade.SessionId ~= nil
        or Service.LocalPlayer:GetAttribute("IsTrading") == true
        or (char and char:GetAttribute("IsTrading") == true) or false
end
Runtime.beginTradeGate = function()
    -- One local trade intent at a time.  This prevents an incoming Auto Accept
    -- from racing an outgoing SendTradeOffer before IsTrading becomes true.
    if next(Runtime.Trade.Gates) ~= nil then return nil end
    Runtime.Trade.Serial = Runtime.Trade.Serial + 1
    local token = Runtime.Trade.Serial
    Runtime.Trade.Gates[token] = true
    return token
end
Runtime.endTradeGate = function(token)
    Runtime.Trade.Gates[token] = nil
    if SupportState.recheckAutoEquipRod then SupportState.recheckAutoEquipRod(0.1) end
end
Runtime.waitTradeSafe = function(alive)
    local deadline = os.clock() + 8
    repeat
        if alive and not alive() then return false end
        if Runtime.Fishing.Owner == nil and Runtime.Fishing.Phase == "Idle"
            and not Runtime.Sell.Busy and not Runtime.Quest.Action.Busy
            and Runtime.Quest.SellHold == 0 then return true end
        task.wait(0.05)
    until os.clock() >= deadline
    return false
end

Runtime.Fishing.IsModeActive = function(mode)
    if mode == "V1" then return Config.InstantFishing end
    if mode == "V2" then return FishingModes.V2.Active end
    if mode == "Blatant" then return Config.BlatantActive end
    if mode == "Legit" then return FishingModes.Legit.Active end
    return true
end

Remote.RuntimeCoord = Runtime
Runtime.Fishing.IsBlocked = Runtime.isTrading

Runtime.Fishing.CanContinue = function(mode)
    return Runtime.Fishing.IsModeActive(mode) and Runtime.Fishing.Owner == mode
        and not Runtime.isTrading()
end
Runtime.Fishing.WaitReady = function(mode)
    while Runtime.Fishing.IsModeActive(mode) do
        local character = Service.LocalPlayer.Character
        if Runtime.Sell.Pending and Runtime.Sell.CanFlush() then Runtime.Sell.Flush() end
        if Runtime.Quest.SellHold > 0 or Runtime.Quest.Action.Busy
            or Runtime.Fishing.Owner ~= nil or Runtime.isTrading()
            or Runtime.Sell.Busy or (character and character:GetAttribute("SellAll") == true)
        then
            task.wait(0.05)
        elseif SupportState.autoEquipRodEnabled
            and tostring(Data.Player:Get("EquippedId") or "") == ""
        then
            SupportState.recheckAutoEquipRod()
            task.wait(0.1)
        else
            Runtime.Fishing.Owner = mode
            Runtime.Fishing.Phase = "Charging"
            FishingModes.Active = true
            return true
        end
    end
    return false
end

Runtime.Fishing.Recover = function(mode)
    if Runtime.Fishing.Owner == mode then
        Runtime.Fishing.Owner = nil
        Runtime.Fishing.Phase = "Idle"
        FishingModes.Active = false
    end
end
Runtime.Fishing.ResetServer = function(mode)
    Runtime.Fishing.Failures[mode] = 0
    if Runtime.Fishing.Owner and Runtime.Fishing.Owner ~= mode then return false end
    if Runtime.isTrading() or Runtime.Quest.Action.Busy then
        Runtime.Fishing.Recover(mode)
        return false
    end
    Runtime.Fishing.Owner = mode
    Runtime.Fishing.Phase = "Resetting"
    Runtime.callRemote("cancel", 2, function()
        return Runtime.Fishing.Owner == mode and not Runtime.isTrading()
    end, true)
    Runtime.Fishing.Recover(mode)
    return true
end
Runtime.Fishing.HandleResult = function(mode, ok, err)
    Runtime.Fishing.Recover(mode)
    if ok then
        Runtime.Fishing.Failures[mode] = 0
        return
    end
    Runtime.Fishing.LastError = tostring(err or "cast failed")
    Runtime.Fishing.LastErrorAt = os.clock()
    Runtime.Fishing.Failures[mode] = (Runtime.Fishing.Failures[mode] or 0) + 1
    if Runtime.Fishing.Failures[mode] >= 2 then
        Runtime.Fishing.ResetServer(mode)
        task.wait(0.15)
    end
    if SupportState.recheckAutoEquipRod then SupportState.recheckAutoEquipRod() end
    if Runtime.Sell.Pending and Runtime.Sell.CanFlush() then Runtime.Sell.Flush() end
    task.wait(0.35)
end

Runtime.Fishing.AwaitCatch = function(mode, catchSerial)
    Runtime.Fishing.Phase = "AwaitCatch"
    local deadline = os.clock() + 3
    while Runtime.Fishing.CanContinue(mode)
        and Runtime.Fishing.CatchSerial <= catchSerial
        and os.clock() < deadline
    do
        task.wait(0.03)
    end
    if not Runtime.Fishing.CanContinue(mode) or Runtime.Fishing.CatchSerial <= catchSerial then
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
    Runtime.Fishing.Recover(mode)
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
    local chargeCallOk, chargeAccepted, serverChargeStart = Runtime.callRemote(
        "charge", 5, function() return Runtime.Fishing.CanContinue(mode) end)
    if not chargeCallOk or not chargeAccepted
        or type(serverChargeStart) ~= "number"
    then
        Runtime.Fishing.Recover(mode)
        return false
    end

    local deadline = workspace:GetServerTimeNow() + 2
    while Runtime.Fishing.CanContinue(mode) and workspace:GetServerTimeNow() < deadline do
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
            local minigameCallOk, started, minigameData = Runtime.callRemote("minigame", 5,
                function() return Runtime.Fishing.CanContinue(mode) end,
                waterY, currentPower, requestTime)
            if minigameCallOk and started ~= false then
                if Config.SkipRarityEnabled and #Config.SkipRarityTiers > 0
                    and type(minigameData) == "table"
                then
                    local skip = false
                    pcall(function()
                        local tier = Data.TierUtility:GetTierFromRarity(minigameData.SelectedRarity)
                        local name = type(tier) == "table" and (tier.Name or "") or ""
                        if #Config.SkipRarityTiers > 0 and not table.find(Config.SkipRarityTiers, name) then
                            skip = true
                            pcall(function() Remote.cancel:InvokeServer(true) end)
                        end
                    end)
                    if skip then
                        Runtime.Fishing.Recover(mode)
                        return false
                    end
                end
                return true
            end
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
            local ok, err = pcall(function()
                if not Runtime.requestConfiguredCast("V1") then error("V1 cast request rejected") end
                if Config.CastWait > 0 then task.wait(Config.CastWait) end
                if not Runtime.Fishing.CanContinue("V1") then error("cast interrupted") end
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
            Runtime.Fishing.HandleResult("V1", ok, err)
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
    Config.BlatantActive = true
    FishingModes.Blatant.Generation = FishingModes.Blatant.Generation + 1
    FishingModes.Blatant.Thread = task.spawn(function()
        Runtime.Fishing.ResetServer("Blatant")
        task.wait(0.1)
        while Config.BlatantActive do
            local ok, err = pcall(function()
                if not Runtime.requestConfiguredCast("Blatant") then
                    error("Blatant cast request rejected")
                end
                if Config.BlatantDelay > 0 then task.wait(Config.BlatantDelay) end
                if not Runtime.Fishing.CanContinue("Blatant") then error("cast interrupted") end
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
            Runtime.Fishing.HandleResult("Blatant", ok, err)
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
            local ok, err = pcall(function()
                if not Runtime.requestConfiguredCast("V2") then error("V2 cast request rejected") end
                if FishingModes.V2.Delay > 0 then task.wait(FishingModes.V2.Delay) end
                if not Runtime.Fishing.CanContinue("V2") then error("cast interrupted") end
                local catchSerial = Runtime.Fishing.CatchSerial
                Runtime.Fishing.Phase = "Completing"
                local completed = pcall(function() Remote.fishing:FireServer() end)
                if not completed then error("V2 catch completion failed") end
                if not Runtime.Fishing.AwaitCatch("V2", catchSerial) then
                    error("V2 catch acknowledgement timeout")
                end
                task.wait(0.05)
            end)
            Runtime.Fishing.HandleResult("V2", ok, err)
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
    if Runtime.isTrading() then return false end
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
    if os.clock() - Runtime.Sell.LastCall < 0.25 or (Runtime.Sell.RetryAt or 0) > os.clock() then return false end
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
    local callSucceeded = false
    local epoch = Runtime.Sell.RequestEpoch
    local function finishAttempt()
        local retry = not sawSellAll and not callSucceeded and Runtime.Sell.RequestEpoch == epoch
        if retry then
            Runtime.Sell.RetryAt = os.clock() + 2
            Runtime.Sell.LastError = callDone and "Sell request rejected" or "Sell acknowledgement timeout"
        end
        Runtime.Sell.Finish(ticket)
        if retry then Runtime.Sell.Queue(Runtime.Sell.Reason) end
    end

    -- The request and its watchdog are separate so a stalled RF cannot pin
    -- every fishing loop forever on low-end/mobile executors.
    Runtime.Sell.Worker = task.spawn(function()
        local ok, result = pcall(function() return Remote.sell:InvokeServer() end)
        if ticket ~= Runtime.Sell.Ticket then return end
        callSucceeded = ok and result ~= false
        if not ok then Runtime.Sell.LastError = tostring(result) end
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
                finishAttempt()
                return
            elseif os.clock() - startedAt >= 5 then
                finishAttempt()
                return
            end
            task.wait(0.05)
        end
    end)

    return true
end

Runtime.Sell.CanFlush = function()
    if Runtime.isTrading() or Runtime.Quest.Action.Busy
        or Runtime.Quest.SellHold > 0 or Runtime.Sell.Busy then return false end
    local phase = Runtime.Fishing.Phase
    if phase ~= "Idle" and phase ~= "PostCatch" then return false end
    if Runtime.Fishing.Owner and phase ~= "PostCatch" then return false end
    if phase == "Idle" then
        local guid = nil
        pcall(function()
            local controller = FishingModes.Controller
            if controller then
                guid = controller.GetCurrentGUID and controller:GetCurrentGUID() or controller.CurrentGUID
            end
        end)
        if guid ~= nil and (Runtime.Sell.CatchWindowUntil or -math.huge) <= os.clock() then return false end
    end
    local character = Service.LocalPlayer.Character
    return not (character and character:GetAttribute("SellAll") == true)
end
Runtime.Sell.Flush = function()
    if not Runtime.Sell.Pending or not Runtime.Sell.CanFlush() then return false end
    return Runtime.Sell.Execute()
end

Runtime.Sell.Queue = function(reason)
    Runtime.Sell.RequestEpoch = (Runtime.Sell.RequestEpoch or 0) + 1
    Runtime.Sell.Pending = true
    Runtime.Sell.Reason = reason or Runtime.Sell.Reason or "Manual"
    if not Runtime.Sell.PendingWorker then
        Runtime.Sell.PendingWorker = true
        task.spawn(function()
            while Runtime.Sell.Pending do
                if Runtime.Sell.CanFlush() then Runtime.Sell.Flush() end
                task.wait(0.5)
            end
            Runtime.Sell.PendingWorker = false
        end)
    end
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
    Runtime.Sell.RequestEpoch = (Runtime.Sell.RequestEpoch or 0) + 1
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
            if Runtime.Sell.Pending and Runtime.Sell.CanFlush() then Runtime.Sell.Flush() end
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
Data.OnFishRegistered = function(record, previous)
    if previous and previous.Name ~= record.Name then FishingModes.FishNameToId[previous.Name] = nil end
    FishingModes.FishNameToId[record.Name] = record.Id
end

for name, fish in pairs(Data.FishCatalog.ByName) do
    FishingModes.FishNameToId[name] = fish.Id
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
                    Runtime.LastError = "Inventory visual refresh: " .. tostring(err)
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
            Runtime.Sell.CatchWindowUntil = os.clock() + 0.35
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
            if not fishItemId then
                local record = Data.getFishRecord(fishName)
                fishItemId = record and record.Id
            end
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

-- Skip Rarity untuk Legit: intercept SendFishingRequestToServer
do
    local origSend = FishingModes.Controller.SendFishingRequestToServer
    FishingModes.Controller.SendFishingRequestToServer = function(self, a, p134, ...)
        local success, data = origSend(self, a, p134, ...)
        if success and type(data) == "table"
            and FishingModes.Legit.Active
            and Config.SkipRarityEnabled
            and #Config.SkipRarityTiers > 0
        then
            pcall(function()
                local tier = Data.TierUtility:GetTierFromRarity(data.SelectedRarity)
                local name = type(tier) == "table" and (tier.Name or "") or ""
                if #Config.SkipRarityTiers > 0 and not table.find(Config.SkipRarityTiers, name) then
                    pcall(function() Remote.cancel:InvokeServer(true) end)
                    success = false
                    data = nil
                end
            end)
        end
        return success, data
    end
end

-- Re-invoke true kalau server matiin auto fishing (movement detection dll)
Data.Player:OnChange("AutoFishing", function(value)
    if (Runtime.StableResult or FishingModes.Legit.Active) and not value then
        task.wait(0.1)
        if not (Runtime.StableResult or FishingModes.Legit.Active) then return end
        pcall(function() Remote.cancel:InvokeServer(true) end)
        task.wait(0.3)
        if not (Runtime.StableResult or FishingModes.Legit.Active) then return end
        pcall(function() Remote.updateAutoFishing:InvokeServer(true) end)
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

-- ====== LEGIT FISHING ======
FishingModes.Legit.Stop = function()
    FishingModes.Legit.Active = false
    FishingModes.Active = false
    if FishingModes.Legit.Thread then
        pcall(task.cancel, FishingModes.Legit.Thread)
        FishingModes.Legit.Thread = nil
    end
    if FishingModes.Legit._origClickDelay ~= nil then
        Data.FishingConstants.ClickDelay = FishingModes.Legit._origClickDelay
        FishingModes.Legit._origClickDelay = nil
    end
    Runtime.Fishing.Recover("Legit")
    pcall(function()
        if Remote.updateAutoFishing then
            Remote.updateAutoFishing:InvokeServer(false)
        end
    end)
end

FishingModes.Legit.Start = function()
    if FishingModes.Legit.Thread then
        pcall(task.cancel, FishingModes.Legit.Thread)
    end
    FishingModes.Legit.Active = true
    if Config.LegitAutoShake then
        FishingModes.Legit._origClickDelay = Data.FishingConstants.ClickDelay
        Data.FishingConstants.ClickDelay = 0
    end
    pcall(function()
        if Remote.updateAutoFishing then
            Remote.updateAutoFishing:InvokeServer(true)
            if Remote.markAutoFishing then
                pcall(function() Remote.markAutoFishing:InvokeServer() end)
            end
        end
    end)
    FishingModes.Legit.Thread = task.spawn(function()
        local controller = FishingModes.Controller
        while FishingModes.Legit.Active do
            if not controller then task.wait(0.5) continue end
            local ok, guid = pcall(function() return controller:GetCurrentGUID() end)
            if ok and guid then
                if Config.LegitAutoShake then
                    pcall(function() controller:RequestFishingMinigameClick() end)
                    task.wait(Config.LegitShakeDelay)
                else
                    task.wait(0.05)
                end
            else
                task.wait(0.05)
            end
        end
        FishingModes.Legit.Active = false
        FishingModes.Active = false
    end)
end

-- The EquippedId listener intentionally ignores an empty hand while a quest
-- transaction owns it. A transaction can finish after the only EquipId change
-- has already happened, so recheck after the owner releases it.
SupportState.recheckAutoEquipRod = function(delay)
    if SupportState.autoEquipWorker or not SupportState.autoEquipRodEnabled then return end
    SupportState.autoEquipWorker = true
    task.spawn(function()
        if delay and delay > 0 then task.wait(delay) end
        local ok, err = pcall(function()
            if not SupportState.autoEquipRodEnabled or Runtime.isTrading()
                or Runtime.Quest.SellHold > 0 or Runtime.Quest.Action.Busy
                or Runtime.Sell.Busy or Runtime.Fishing.Owner
                or Runtime.Fishing.Phase ~= "Idle"
            then return end
            if tostring(Data.Player:Get("EquippedId") or "") ~= "" then return end
            Runtime.Fishing.Owner = "AutoEquip"
            Runtime.Fishing.Phase = "Equipping"
            for _ = 1, 3 do
                if not SupportState.autoEquipRodEnabled or Runtime.isTrading()
                    or Runtime.Quest.Action.Busy or Runtime.Quest.SellHold > 0 then break end
                local hotbar = Data.Player:Get("EquippedItems") or {}
                local uuid = hotbar[1]
                if not uuid then break end
                Remote.equipTool:FireServer(1)
                local deadline = os.clock() + 0.6
                repeat
                    if tostring(Data.Player:Get("EquippedId") or "") == tostring(uuid) then return end
                    if not SupportState.autoEquipRodEnabled or Runtime.isTrading() then return end
                    task.wait(0.05)
                until os.clock() >= deadline
            end
        end)
        if Runtime.Fishing.Owner == "AutoEquip" then
            Runtime.Fishing.Owner = nil
            Runtime.Fishing.Phase = "Idle"
        end
        SupportState.autoEquipWorker = false
        if not ok then Runtime.Fishing.LastError = "AutoEquip: " .. tostring(err) end
    end)
end
SupportState.setAutoEquipRod = function(state)
    SupportState.autoEquipRodEnabled = state == true
    if SupportState.autoEquipRodConn then SupportState.autoEquipRodConn:Disconnect() SupportState.autoEquipRodConn = nil end
    if state then
        SupportState.autoEquipRodConn = Data.Player:OnChange("EquippedId", function(value)
            if not value or value == "" then SupportState.recheckAutoEquipRod(0.1) end
        end)
        SupportState.recheckAutoEquipRod()
        if not SupportState.autoEquipMonitor then
            SupportState.autoEquipMonitor = true
            task.spawn(function()
                while SupportState.autoEquipRodEnabled do
                    SupportState.recheckAutoEquipRod()
                    task.wait(0.5)
                end
                SupportState.autoEquipMonitor = false
            end)
        end
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
S.createPingUI = function()
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
        S.createPingUI()
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

-- Skip Rarity Features
UI.SkipRaritySection = UI.Window:AddCollapsible(UI.FishingTab, "Skip Rarity", false)

UI.Window:AddParagraph(UI.SkipRaritySection, "Notes!",
    "this feature only works on legit fishing, instant fishing, and instant fishing v2")

UI.Window:AddDropdown(UI.SkipRaritySection, "Select Skip Rarity", "",
    Catalog.RarityTiers, true, {},
    function(v) Config.SkipRarityTiers = v end,
    "Dropdown_Skip Rarity Tiers")

UI.Window:AddToggle(UI.SkipRaritySection, "Skip Rarity", "", false, function(state)
    Config.SkipRarityEnabled = state
end, "Toggle_Skip Rarity")
UI.LegitSection = UI.Window:AddCollapsible(UI.FishingTab, "Legit Fishing", false)

local legitShakeInput = UI.Window:AddInput(UI.LegitSection, "Shake Delay", "", "Write your input here...", function(v)
    local n = tonumber(v)
    if n and n >= 0 then Config.LegitShakeDelay = n end
end, "Input_Legit Shake Delay")
legitShakeInput:Set("0.05")

UI.Window:AddToggle(UI.LegitSection, "Enable Legit Fishing", "", false, function(state)
    FishingModes.Legit.Active = state
    if state then FishingModes.Legit.Start() else FishingModes.Legit.Stop() end
end, "Toggle_Legit Fishing")

UI.Window:AddToggle(UI.LegitSection, "Auto Shake", "", false, function(state)
    Config.LegitAutoShake = state
end, "Toggle_Legit Auto Shake")

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

UI.Window:AddButton(UI.TpSection, "Teleport", "", "rbxassetid://16932740082", function()
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
    if Runtime.Quest.Paused == state then return end
    Runtime.Quest.Paused = state
    if state then

    end
    for _, job in ipairs({"DeepSea","Artifact","Element","Diamond","Crystalline"}) do
        local oldSession = Runtime.Quest.Sessions[job]
        Runtime.Quest.Sessions[job] = (oldSession or 0) + 1
        if state and S.Quest and S.Quest.scheduleSessionCleanup then
            -- The old worker may still be restoring an equipped quest item.
            -- Keep its action lock until that transaction actually returns.
            S.Quest.scheduleSessionCleanup(job, oldSession)
        end
    end
    if not state and S.Quest and S.Quest.startJobThread then
        for _, job in ipairs({"DeepSea","Artifact","Element","Diamond","Crystalline"}) do
            if Runtime.Quest.Enabled[job] and S.Quest.Runners[job] then
                local session = Runtime.Quest.Sessions[job]
                if not S.Quest.startJobThread(
                    job, S.Quest.Runners[job], session)
                then
                    task.spawn(function()
                        while S.Quest.isActive(job, session)
                            and Runtime.Quest.Threads[job]
                        do task.wait(0.05) end
                        if S.Quest.isActive(job, session) then
                            S.Quest.startJobThread(
                                job, S.Quest.Runners[job], session)
                        end
                    end)
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
    if Runtime.Quest.Action.Busy then
        -- A Quest/Enchant/Transcended item is still equipped. Retry after its
        -- bounded transaction finalizer restores the held item.
        task.delay(0.35, Navigation.scheduleEventResolve)
        return
    end
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
            -- Match the library's own 50px title/bottom envelope.  This
            -- leaves a real lower padding even after a panel shrinks.
            para.Size = UDim2.new(1, 0, 0, math.max(52, contentHeight + 50))
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
        if S.enchantActionTicket and S.Quest and S.Quest.releaseAction then
            S.Quest.releaseAction(S.enchantActionTicket)
            S.enchantActionTicket = nil
        end
        for _,conn in ipairs(S.enchantConns) do pcall(function() conn:Disconnect() end) end
        S.enchantConns = {}
        S.enchantPending = false
        S.enchantStopRequested = not state
        S.enchantExpectedStoneId = nil
        S.enchantExpectedTarget = nil
        S.enchantExpectedRodUUID = nil
        S.enchantRequestInventorySerial = nil
        if S.enchantThread then
            local oldThread = S.enchantThread
            S.enchantThread = nil
            if oldThread ~= coroutine.running() then pcall(task.cancel, oldThread) end
        end
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
            local workerSession = S.enchantSession
            local workerOk, workerErr = pcall(function()
            local equipFailures = 0
            while Config.AutoEnchantReroll and not S.enchantStopRequested
                and S.enchantSession == workerSession
            do
                local actionSession = workerSession
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
                local actionTicket = S.Quest and S.Quest.acquireAction
                    and S.Quest.acquireAction("Enchant", function()
                        return Config.AutoEnchantReroll
                            and not S.enchantStopRequested
                            and S.enchantSession == actionSession
                    end, 10, "Enchant", actionSession) or nil
                if not actionTicket then
                    if Config.AutoEnchantReroll
                        and S.enchantSession == actionSession
                    then
                        task.wait(0.3)
                        continue
                    end
                    break
                end
                S.enchantActionTicket = actionTicket
                local function releaseEnchantAction()
                    if S.enchantActionTicket == actionTicket then
                        S.enchantActionTicket = nil
                    end
                    if S.Quest and S.Quest.releaseAction then
                        S.Quest.releaseAction(actionTicket)
                    end
                end
                if not S.equipAndHold(stoneUUID,"Enchant Stones",function()
                    return Config.AutoEnchantReroll
                        and not S.enchantStopRequested
                        and S.enchantSession == actionSession
                end) then
                    releaseEnchantAction()
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
                    sent = pcall(function()
                        Remote.enchantAltar2:FireServer(rodUUID)
                    end)
                else
                    sent = pcall(function() Remote.enchantAltar1:FireServer(rodUUID) end)
                end
                if not sent then
                    releaseEnchantAction()
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
                while S.enchantPending and Config.AutoEnchantReroll
                    and S.enchantSession == actionSession and os.clock()<dl
                do task.wait(0.05) end
                if S.enchantStopRequested or not Config.AutoEnchantReroll
                    or S.enchantSession ~= actionSession
                then
                    releaseEnchantAction()
                    break
                end
                if S.enchantPending then
                    releaseEnchantAction()
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
                releaseEnchantAction()
                if remaining <= 0 then
                    updateEnchantPara()
                    UI.Library:Notify({Title="Orvion",Subtitle="Hub",Content="Enchant stones exhausted"})
                    pcall(function() S.enchantToggle:Set(false) end)
                    break
                end
                task.wait(5.5)
            end
            end)
            if S.enchantActionTicket
                and Runtime.Quest.Action.Job == "Enchant"
                and Runtime.Quest.Action.Session == workerSession
                and S.Quest and S.Quest.releaseAction
            then
                S.Quest.releaseAction(S.enchantActionTicket)
                S.enchantActionTicket = nil
            end
            if not workerOk and S.enchantSession == workerSession then
                Runtime.LastError = "Auto Enchant: " .. tostring(workerErr)
                UI.Library:Notify({Title="Orvion",Subtitle="Hub",Content="Auto Enchant stopped safely"})
                pcall(function() S.enchantToggle:Set(false) end)
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
                        if d and d.Data and d.Data.Type=="Fish"
                            and Data.getFishTier(item, d) == 7
                        then
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
        S.transcendedSession = (S.transcendedSession or 0) + 1
        if S.transcendedActionTicket and S.Quest and S.Quest.releaseAction then
            S.Quest.releaseAction(S.transcendedActionTicket)
            S.transcendedActionTicket = nil
        end
        if S.transcendedInventoryConn then
            pcall(function() S.transcendedInventoryConn:Disconnect() end)
            S.transcendedInventoryConn=nil
        end
        if S.transcendedThread then
            local oldThread = S.transcendedThread
            S.transcendedThread = nil
            if oldThread ~= coroutine.running() then pcall(task.cancel, oldThread) end
        end
        Config.AutoCreateTranscended = state
        if not state then return end
        local level = tonumber(Data.Player:Get("Level")) or 0
        if level < 200 then
            setPara(S.transcendedPara,"Unavailable","Level 200 is required")
            pcall(function() S.transcendedToggle:Set(false) end)
            return
        end
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
            local workerSession = S.transcendedSession
            local workerOk, workerErr = pcall(function()
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
            while created < amount and Config.AutoCreateTranscended
                and S.transcendedSession == workerSession
            do
                local actionTicket = S.Quest and S.Quest.acquireAction
                    and S.Quest.acquireAction("Transcended", function()
                        return Config.AutoCreateTranscended
                            and S.transcendedSession == workerSession
                    end, 10, "Transcended", workerSession) or nil
                if not actionTicket then
                    if Config.AutoCreateTranscended
                        and S.transcendedSession == workerSession
                    then
                        stopReason = "Item action unavailable"
                    end
                    break
                end
                S.transcendedActionTicket = actionTicket
                local function releaseTranscendedAction()
                    if S.transcendedActionTicket == actionTicket then
                        S.transcendedActionTicket = nil
                    end
                    if S.Quest and S.Quest.releaseAction then
                        S.Quest.releaseAction(actionTicket)
                    end
                end
                local fishUUID = nil
                pcall(function()
                    local invT=Data.Player:Get("Inventory") or Data.Player.Data.Inventory
                    if invT then
                        for cat,items in pairs(invT) do
                            if type(items)=="table" then
                                for _,item in ipairs(items) do
                                    local d=Data.ItemUtility.GetItemDataFromItemType(cat,item.Id)
                                    if d and d.Data and d.Data.Type=="Fish"
                                        and d.Data.Name==fishName
                                        and Data.getFishTier(item, d) == 7
                                    then
                                        fishUUID=item.UUID break
                                    end
                                end
                            end
                            if fishUUID then break end
                        end
                    end
                end)
                if not fishUUID then
                    releaseTranscendedAction()
                    stopReason = "No "..fishName.." found"
                    break
                end
                setPara(S.transcendedPara,"Equipping",fishName)
                if not S.equipAndHold(fishUUID,"Fish",function()
                    return Config.AutoCreateTranscended
                        and S.transcendedSession == workerSession
                end) then
                    releaseTranscendedAction()
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
                while Config.AutoCreateTranscended
                    and S.transcendedSession == workerSession
                    and not done and os.clock()<dl
                do task.wait(0.05) end
                if not done then pcall(task.cancel,worker) end
                if not Config.AutoCreateTranscended
                    or S.transcendedSession ~= workerSession
                then
                    releaseTranscendedAction()
                    break
                end
                if not result then
                    releaseTranscendedAction()
                    stopReason = errMsg ~= "" and errMsg or "Create Transcended failed"
                    break
                end

                local syncDeadline = os.clock()+3
                local observedSerial = inventorySerialBefore
                local fishStillExists = true
                while Config.AutoCreateTranscended
                    and S.transcendedSession == workerSession
                    and os.clock()<syncDeadline
                do
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
                    releaseTranscendedAction()
                    stopReason = "Inventory sync timeout"
                    break
                end
                created = created+1
                setPara(S.transcendedPara,"Sacrificing","Create "..created.."/"..amount.." - Done: "..created.." | Fail: "..failed)
                releaseTranscendedAction()
                task.wait(0.1)
            end
            if Config.AutoCreateTranscended and created >= amount then
                setPara(S.transcendedPara,"Complete","Done: "..created.." | Fail: "..failed)
                UI.Library:Notify({Title="Orvion",Subtitle="Hub",Content="Done! Created "..created.." Transcended Stones"})
            elseif Config.AutoCreateTranscended and stopReason then
                setPara(S.transcendedPara,"Stopped",stopReason.."\nDone: "..created.."/"..amount.." | Fail: "..failed)
                UI.Library:Notify({Title="Orvion",Subtitle="Hub",Content=stopReason})
            end
            S.transcendedThread = nil
            pcall(function() S.transcendedToggle:Set(false) end)
            end)
            if S.transcendedActionTicket
                and Runtime.Quest.Action.Job == "Transcended"
                and Runtime.Quest.Action.Session == workerSession
                and S.Quest and S.Quest.releaseAction
            then
                S.Quest.releaseAction(S.transcendedActionTicket)
                S.transcendedActionTicket = nil
            end
            if not workerOk and S.transcendedSession == workerSession then
                Runtime.LastError = "Transcended: " .. tostring(workerErr)
                S.transcendedThread = nil
                setPara(S.transcendedPara,"Stopped","Worker error; action lock released")
                UI.Library:Notify({Title="Orvion",Subtitle="Hub",Content="Create Transcended stopped safely"})
                pcall(function() S.transcendedToggle:Set(false) end)
            end
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

-- Latest explicit purchase of each kind supersedes its older equip request.
S.queuePurchasedEquip = function(kind, id)
    S.PurchasedEquip = S.PurchasedEquip or {}
    local pending = {Id=id}
    S.PurchasedEquip[kind] = pending
    task.spawn(function()
        local function active() return S.PurchasedEquip[kind] == pending end
        while active() do
            if S.Quest then
                local done = false
                S.Quest.withSellHold("PurchaseEquip:" .. kind, active, function()
                    for _ = 1, 3 do
                        if not active() then return end
                        if kind == "Baits" then
                            if tonumber(Data.Player:Get("EquippedBaitId")) == tonumber(id) then done=true return end
                            Remote.equipBait:FireServer(id)
                        else
                            if tostring(Data.Player:Get("EquippedId") or "") == tostring(id) then done=true return end
                            if not S.Quest.findByUUID(id) then return end
                            Remote.equipItem:FireServer(id, "Fishing Rods")
                            task.wait(0.2)
                            if not active() then return end
                            local slot = table.find(Data.Player:Get("EquippedItems") or {}, tostring(id))
                            if slot then Remote.equipTool:FireServer(slot) end
                        end
                        task.wait(0.8)
                    end
                end, 3)
                if done then if active() then S.PurchasedEquip[kind] = nil end return end
            end
            task.wait(1)
        end
    end)
end

UI.Window:AddButton(S.RodSection, "Buy Rod", "", "rbxassetid://16932740082", function()
    local rodId = S.ROD_MAP[Config.SelectedRod]
    if not rodId or not Remote.purchaseRod then
        UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Content="Remote not found", Color=Color3.fromRGB(150,150,170), Delay=2 })
        return
    end
    local selectedRod = Config.SelectedRod
    local ok, success, uuid = Runtime.callRemote("purchaseRod", 10, nil, rodId)
    if ok then
        if success and uuid and Remote.equipItem then
            S.queuePurchasedEquip("Fishing Rods", uuid)
        end
        UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Content=selectedRod .. (success and " bought" or " failed"), Color=Color3.fromRGB(150,150,170), Delay=3 })
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
    local selectedBait = Config.SelectedBait
    local ok, success, shouldEquip = Runtime.callRemote("purchaseBait", 10, nil, baitId)
    if ok then
        if shouldEquip and Remote.equipBait then
            S.queuePurchasedEquip("Baits", baitId)
        end
        UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Content=selectedBait .. (success and " bought" or " failed"), Color=Color3.fromRGB(150,150,170), Delay=3 })
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
        ItemTypes = {"Fish", "Gears", "Fishing Rods", "Enchant Stones", "Artifacts"},
        ItemDataCache = {},
        KnownIds = {
            ["Arrow Artifact"]=265, ["Crescent Artifact"]=266,
            ["Diamond Artifact"]=267, ["Hourglass Diamond Artifact"]=271,
            ["Ghostfinn Rod"]=169, ["Element Rod"]=257,
            ["Diamond Key"]=574, ["Diamond Rod"]=559,
        },
        TranscendedCooldown = {},
        Runners = {},
    }

    S.Quest.get = function(path)
        local value = nil
        pcall(function() value = Data.Player:Get(path) end)
        return value
    end

    -- Replion can expose quest state a frame before its raw Data cache.
    -- Never index Data.Player.Data directly from a worker during that gap.
    S.Quest.inventory = function()
        local inventory = S.Quest.get("Inventory")
        if type(inventory) == "table" then return inventory end
        local playerData = Data.Player and Data.Player.Data
        return type(playerData) == "table" and playerData.Inventory or nil
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

    -- Quest resolver R22: catalog identity, not name suffixes, determines type.
    S.Quest.ItemDataRetryAt = {}
    S.Quest.sameItemId = function(a, b)
        if (type(a) ~= "number" and type(a) ~= "string")
            or (type(b) ~= "number" and type(b) ~= "string")
        then return false end
        if tostring(a) == "" or tostring(b) == "" then return false end
        local na, nb = tonumber(a), tonumber(b)
        if na and nb then return na == nb end
        return tostring(a) == tostring(b)
    end

    S.Quest.resolveItemData = function(category, id)
        local key = tostring(category) .. ":" .. tostring(id)
        local function valid(raw, expectedType)
            local d = type(raw) == "table" and raw.Data
            return type(d) == "table" and S.Quest.sameItemId(d.Id, id)
                and type(d.Name) == "string" and type(d.Type) == "string"
                and (not expectedType or expectedType == "Items"
                    or d.Type == expectedType
                    or (expectedType == "Artifacts" and d.Type == "Gears"))
        end
        local cached = S.Quest.ItemDataCache[key]
        if valid(cached, category) then
            return cached, cached.Data.Type
        end
        -- A transient catalog failure must not disable a quest permanently.
        if (S.Quest.ItemDataRetryAt[key] or 0) > os.clock() then return nil, category end
        local function lookup(itemType)
            local ok, raw = pcall(function()
                return Data.ItemUtility.GetItemDataFromItemType(itemType, id)
            end)
            if ok and valid(raw, itemType) then return raw end
        end
        local raw = lookup(category)
        -- Only the mixed Items collection (and legacy Artifact alias) may
        -- cross catalog types. Typed collections must not collide by ID.
        if not raw and (category == "Items" or category == "Artifacts") then
            local ambiguous = false
            for _, itemType in ipairs(S.Quest.ItemTypes) do
                if category == "Items" or itemType == "Gears" or itemType == "Artifacts" then
                    local candidate = lookup(itemType)
                    if candidate then
                        if raw and (raw.Data.Type ~= candidate.Data.Type
                            or raw.Data.Name ~= candidate.Data.Name)
                        then
                            ambiguous = true
                            break
                        end
                        raw = candidate
                    end
                end
            end
            if ambiguous then raw = nil end
        end
        S.Quest.ItemDataCache[key] = raw
        if raw then
            S.Quest.ItemDataRetryAt[key] = nil
        else
            S.Quest.ItemDataRetryAt[key] = os.clock() + 0.5
        end
        return raw, raw and raw.Data.Type or category
    end

    S.Quest.eachInventoryItem = function(callback)
        local inventory = S.Quest.inventory()
        if type(inventory) ~= "table" then return nil end
        for category, items in pairs(inventory) do
            if type(items) == "table" then
                for _, item in pairs(items) do
                    if type(item) == "table" and item.Id ~= nil then
                        local raw, resolvedCategory = S.Quest.resolveItemData(category, item.Id)
                        local result = callback(item, resolvedCategory, raw and raw.Data)
                        if result ~= nil then return result end
                    end
                end
            end
        end
        return nil
    end

    S.Quest.findItem = function(predicate, preferHotbar)
        local selected, bestScore
        local held, hotbar = nil, {}
        if preferHotbar then
            held = S.Quest.get("EquippedId")
            local equipped = S.Quest.get("EquippedItems")
            if type(equipped) == "table" then
                for _, uuid in pairs(equipped) do hotbar[tostring(uuid)] = true end
            end
        end
        local result = S.Quest.eachInventoryItem(function(item, category, data)
            if predicate(item, category, data) then
                local entry = { Item=item, Category=category, Data=data }
                if not preferHotbar then return entry end
                local uuid = tostring(item.UUID or "")
                local score = uuid ~= "" and held ~= nil and uuid == tostring(held)
                    and 3 or (hotbar[uuid] and 2 or 1)
                if not selected or score > bestScore then
                    selected, bestScore = entry, score
                end
            end
        end)
        return result or selected
    end

    S.Quest.findById = function(id, itemType, variant)
        return S.Quest.findItem(function(item, _, data)
            if not S.Quest.sameItemId(item.Id, id) then return false end
            local metadata = type(item.Metadata) == "table" and item.Metadata or {}
            if variant and metadata.Variant ~= variant
                and metadata.VariantId ~= variant
            then return false end
            -- Never submit an unresolved item as a Fish merely because its ID matches.
            return data ~= nil and (not itemType or itemType == "Items"
                or data.Type == itemType)
        end, true)
    end

    S.Quest.findByName = function(name, expectedType)
        if type(name) ~= "string" or name == "" then return nil end
        local entry = S.Quest.findItem(function(_, _, data)
            return data ~= nil and data.Name == name
                and (not expectedType or data.Type == expectedType)
        end, true)
        if entry then S.Quest.KnownIds[name] = entry.Item.Id end
        return entry
    end

    S.Quest.findFish = function(id, variant)
        return S.Quest.findById(id, "Fish", variant)
    end

    S.Quest.findSecret = function()
        return S.Quest.findItem(function(item, _, data)
            return data and data.Type == "Fish"
                and Data.getFishTier(item) == 7
                and (tonumber(S.Quest.TranscendedCooldown[
                    tostring(item.UUID or "")]) or 0) <= os.clock()
        end)
    end

    S.Quest.hasUUID = function(uuid)
        if uuid == nil or tostring(uuid) == "" then return false end
        local inventory = S.Quest.inventory()
        if type(inventory) ~= "table" then return false end
        for _, items in pairs(inventory) do
            if type(items) == "table" then
                for _, item in pairs(items) do
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

    S.Quest.isActive = function(job, session)
        return Runtime.Quest.Enabled[job] == true
            and not Runtime.Quest.Paused
            and (session == nil or Runtime.Quest.Sessions[job] == session)
    end

    -- waitJob: poll predicate sampai true/timeout, exit kalau Enabled[job] false
    -- Every wait observes the exact toggle generation.
    S.Quest.waitJob = function(job, predicate, timeout, interval, session)
        local deadline = timeout and (os.clock() + timeout) or nil
        while S.Quest.isActive(job, session) do
            local ok, result = pcall(predicate)
            if ok and result then return true end
            if deadline and os.clock() >= deadline then return false end
            task.wait(interval or 0.1)
        end
        return false
    end

    -- All Quest panels are a read-only projection of Replion.  Action code
    -- calls this immediately after an acknowledgement, while OnChange below
    -- covers acknowledgements that arrive outside a worker.
    S.Quest.refreshFromReplion = function()
        Runtime.Quest.RefreshPanels()
    end

    -- teleport helper tanpa LastLocation tracking
    S.Quest.teleport = function(destination, job, session)
        if job then
            if not S.Quest.isActive(job, session) then return false end
            local action = Runtime.Quest.Action
            if action.Busy then
                if action.Job ~= job or action.Session ~= session then return false end
            elseif job == "Crystalline" then
                if not S.Quest.canCrystallineNavigate(session) then return false end
            elseif not S.Quest.canNavigate(job, session) then return false end
        end
        if Runtime.isTrading() or (Runtime.Quest.FallbackUntil or 0) > os.clock() then return false end
        if typeof(destination) == "CFrame" then
            local character = Service.LocalPlayer.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            return Navigation.tryMoveRoot(root, destination, true)
        else
            return Navigation.teleportTo(destination, true)
        end
    end

    S.Quest.isNear = function(destination, radius)
        local target = typeof(destination) == "CFrame"
            and destination or Catalog.Locations[destination]
        if not target then return false end
        local character = Service.LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        return root ~= nil
            and (root.Position - target.Position).Magnitude <= (radius or 80)
    end

    S.Quest.getNPC = function(name)
        local npcFolder = workspace:FindFirstChild("NPC")
        return npcFolder and npcFolder:FindFirstChild(name) or nil
    end

    S.Quest.isNearNPC = function(name, radius)
        local npc = S.Quest.getNPC(name)
        local character = Service.LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not npc or not root then return false end
        return (root.Position - npc:GetPivot().Position).Magnitude <= (radius or 12)
    end

    -- DialogueEnded is the normal controller's choice-confirmation remote.
    -- Establish actual NPC proximity first, but do not fire the prompt itself:
    -- that would open a client dialogue UI which a direct remote cannot close.
    S.Quest.approachDiamondResearcher = function(job, session)
        if not S.Quest.isActive(job, session) or Runtime.isTrading() then return false end
        local npc = S.Quest.getNPC("Diamond Researcher")
        local character = Service.LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not npc or not root then return false end
        if not S.Quest.isNearNPC("Diamond Researcher", 12) then
            Navigation.tryMoveRoot(root, npc:GetPivot() * CFrame.new(0, 0, 4), true)
        end
        local near = S.Quest.waitJob(job, function()
            return S.Quest.isNearNPC("Diamond Researcher", 12)
        end, 3, 0.05, session)
        if near then task.wait(0.2) end -- give server character replication one beat
        return near and S.Quest.isActive(job, session)
    end

    S.Quest.refreshSellHold = function()
        local count = 0
        for _ in pairs(Runtime.Quest.HoldTokens) do count = count + 1 end
        Runtime.Quest.SellHold = count
        return count
    end

    S.Quest.addHold = function(reason, job, session)
        Runtime.Quest.HoldSerial = Runtime.Quest.HoldSerial + 1
        local token = Runtime.Quest.HoldSerial
        Runtime.Quest.HoldTokens[token] = reason or true
        Runtime.Quest.HoldMeta[token] = { Job=job, Session=session }
        S.Quest.refreshSellHold()
        return token
    end

    S.Quest.removeHold = function(token)
        if not token or Runtime.Quest.HoldTokens[token] == nil then return false end
        Runtime.Quest.HoldTokens[token] = nil
        Runtime.Quest.HoldMeta[token] = nil
        if S.Quest.refreshSellHold() == 0 then
            -- The last bridge hold may outlive Quest.Action. Recheck here as
            -- well as in releaseAction so Auto Equip cannot miss the only
            -- empty-hand transition.
            if SupportState.recheckAutoEquipRod then
                SupportState.recheckAutoEquipRod(0.2)
            end
            task.defer(function()
                if Runtime.Sell.Pending and Runtime.Fishing.Phase == "Idle"
                    and not Runtime.Quest.Action.Busy
                then
                    Runtime.Sell.Flush()
                end
            end)
        end
        return true
    end

    S.Quest.acquireAction = function(
        owner, shouldContinue, timeout, job, session)
        local holdToken = nil
        local deadline = os.clock() + (timeout or 10)
        while Runtime.Quest.Action.Busy or (Runtime.Quest.RestorePending and owner ~= "Restore") or Runtime.isTrading()
            or (Runtime.Quest.FallbackUntil or 0) > os.clock() do
            if shouldContinue and not shouldContinue() then
                S.Quest.removeHold(holdToken)
                return nil
            end
            if os.clock() >= deadline then
                S.Quest.removeHold(holdToken)
                return nil
            end
            task.wait(0.05)
        end
        if shouldContinue and not shouldContinue() then return nil end
        holdToken = S.Quest.addHold(owner, job, session)
        Runtime.Quest.Action.Ticket = Runtime.Quest.Action.Ticket + 1
        local ticket = Runtime.Quest.Action.Ticket
        Runtime.Quest.Action.Busy = true
        Runtime.Quest.Action.Owner = owner
        Runtime.Quest.Action.HoldToken = holdToken
        Runtime.Quest.Action.Job = job
        Runtime.Quest.Action.Session = session
        while os.clock() < deadline do
            if shouldContinue and not shouldContinue() then break end
            local character = Service.LocalPlayer.Character
            local selling = character and character:GetAttribute("SellAll") == true
            local trading = Runtime.isTrading()
            if Runtime.Fishing.Phase == "Idle"
                and Runtime.Fishing.Owner == nil
                and not Runtime.Sell.Busy and not selling and not trading
            then
                Runtime.Fishing.Owner = "QuestAction:" .. tostring(ticket)
                return ticket
            end
            task.wait(0.05)
        end
        if Runtime.Quest.Action.Ticket == ticket then
            Runtime.Quest.Action.Busy = false
            Runtime.Quest.Action.Owner = nil
            Runtime.Quest.Action.HoldToken = nil
            Runtime.Quest.Action.Job = nil
            Runtime.Quest.Action.Session = nil
        end
        S.Quest.removeHold(holdToken)
        return nil
    end

    S.Quest.releaseAction = function(ticket)
        if not ticket or ticket ~= Runtime.Quest.Action.Ticket
            or not Runtime.Quest.Action.Busy
        then
            return false
        end
        local owner = "QuestAction:" .. tostring(ticket)
        if Runtime.Fishing.Owner == owner then Runtime.Fishing.Owner = nil end
        local holdToken = Runtime.Quest.Action.HoldToken
        Runtime.Quest.Action.Busy = false
        Runtime.Quest.Action.Owner = nil
        Runtime.Quest.Action.HoldToken = nil
        Runtime.Quest.Action.Job = nil
        Runtime.Quest.Action.Session = nil
        S.Quest.removeHold(holdToken)
        -- Auto Equip deliberately stayed quiet while Action.Busy was true.
        -- Recover once the temporary quest item has been restored/consumed.
        if SupportState.recheckAutoEquipRod then
            SupportState.recheckAutoEquipRod(0.2)
        end
        return true
    end

    S.Quest.withSellHold = function(
        owner, shouldContinue, fn, timeout, job, session)
        local ticket = S.Quest.acquireAction(
            owner, shouldContinue, timeout, job, session)
        if not ticket then return false, "action unavailable" end
        local packed = table.pack(pcall(fn))
        local restore = Runtime.Quest.Action.Restore
        if restore then
            local ok, done = pcall(S.Quest.restoreQuestItem, restore.Target,
                restore.Displaced, restore.RestoreRod, restore.Inserted)
            if not ok or not done then Runtime.Quest.RestorePending = restore end
            Runtime.Quest.Action.Restore = nil
        end
        S.Quest.releaseAction(ticket)
        if Runtime.Quest.RestorePending then S.Quest.retryRestore() end
        return table.unpack(packed, 1, packed.n)
    end

    -- A stopped generation may have acquired a sell hold just before the UI
    -- callback invalidated it. Clean only that job/session, never another
    -- concurrently enabled Quest or a standalone Enchant/Transcended action.
    S.Quest.cleanupSession = function(job, session)
        if Runtime.Quest.Action.Busy
            and Runtime.Quest.Action.Job == job
            and Runtime.Quest.Action.Session == session
        then
            S.Quest.releaseAction(Runtime.Quest.Action.Ticket)
        end
        local stale = {}
        for token, meta in pairs(Runtime.Quest.HoldMeta) do
            if meta.Job == job and meta.Session == session then
                table.insert(stale, token)
            end
        end
        for _, token in ipairs(stale) do
            S.Quest.removeHold(token)
        end
        if job == "Crystalline" and S.Quest.CrystallineBusy then
            for fishName, busySession in pairs(S.Quest.CrystallineBusy) do
                if busySession == session then
                    S.Quest.CrystallineBusy[fishName] = nil
                end
            end
        end
    end

    -- Invalidate first, then allow the old transaction to restore its item.
    -- A fixed cleanup delay could release the lock halfway through restore.
    S.Quest.scheduleSessionCleanup = function(job, session)
        task.spawn(function()
            while Runtime.Quest.Action.Busy
                and Runtime.Quest.Action.Job == job
                and Runtime.Quest.Action.Session == session
            do
                task.wait(0.05)
            end
            S.Quest.cleanupSession(job, session)
            if Runtime.Sell.Pending and Runtime.Fishing.Phase == "Idle"
                and Runtime.Quest.SellHold == 0
            then
                Runtime.Sell.Flush()
            end
        end)
    end

    -- A toggle is always allowed to stay ON. This gate only prevents its
    -- worker from executing until every connection needed by that route is
    -- available; progression prerequisites remain Replion-driven waits.
    S.Quest.getStartIssue = function(job)
        local required = {
            equipItem = "RE/EquipItem",
            equipTool = "RE/EquipToolFromHotbar",
            unequipItem = "RE/UnequipItem",
            unequipTool = "RE/UnequipToolFromHotbar",
        }
        if job == "Artifact" then
            required.placeLever = "RE/PlaceLeverItem"
        elseif job == "Crystalline" then
            required.placePressure = "RE/PlacePressureItem"
        elseif job == "Element" then
            required.createTranscended = "RF/CreateTranscendedStone"
        elseif job == "Diamond" then
            required.dialogueEnded = "RE/DialogueEnded"
            required.claimItem = "RF/ClaimItem"
        end
        for key, remoteName in pairs(required) do
            local expectedClass = remoteName:sub(1, 3) == "RF/"
                and "RemoteFunction" or "RemoteEvent"
            local function usable(remote)
                return typeof(remote) == "Instance" and remote:IsA(expectedClass)
                    and remote.Parent ~= nil and remote:IsDescendantOf(Remote.Net)
            end
            if not usable(Remote[key]) then
                local ok, resolved = pcall(Remote.Resolve, remoteName)
                Remote[key] = ok and usable(resolved) and resolved or nil
            end
            if not Remote[key] then return remoteName .. " unavailable or wrong class" end
        end
        if not Data.Player or type(Data.Player.Get) ~= "function" then
            return "player Replion unavailable"
        end
        if job == "Diamond" and type(fireproximityprompt) ~= "function" then
            return "proximity prompt support unavailable"
        end
        return nil
    end

    S.Quest.findByUUID = function(uuid)
        local wanted = tostring(uuid or "")
        if wanted == "" then return nil end
        return S.Quest.findItem(function(item)
            return tostring(item.UUID or "") == wanted
        end)
    end

    -- Smart hotbar used only while the caller owns Quest.Action.
    -- Slot 1 is never evicted because Fish It always keeps a rod there.
    S.Quest.equipQuestItem = function(job, session, uuid, itemType, fallbackTypes)
        local wanted = tostring(uuid or "")
        if wanted == "" or not Remote.equipItem or not Remote.equipTool
            or not Remote.unequipItem
        then
            return false, nil
        end
        if not S.Quest.isActive(job, session) then return false, nil end
        pcall(function() Remote.unequipTool:FireServer() end)
        local deadline = os.clock() + 1
        while os.clock() < deadline and S.Quest.isActive(job, session) do
            if tostring(Data.Player:Get("EquippedId") or "") == "" then break end
            task.wait(0.05)
        end

        local hotbar = Data.Player:Get("EquippedItems") or {}
        local slot = table.find(hotbar, wanted)
        local inserted = slot == nil
        local displaced = nil
        Runtime.Quest.Action.Restore = {Target=wanted, Inserted=inserted, RestoreRod=true}
        local function insertIntoHotbar()
            local tried = {}
            local types = {itemType}
            for _, fallback in ipairs(fallbackTypes or {}) do
                table.insert(types, fallback)
            end
            for _, candidate in ipairs(types) do
                candidate = tostring(candidate or "")
                if candidate ~= "" and not tried[candidate] then
                    tried[candidate] = true
                    pcall(function()
                        Remote.equipItem:FireServer(uuid, candidate)
                    end)
                    deadline = os.clock() + 1.2
                    while os.clock() < deadline
                        and S.Quest.isActive(job, session)
                    do
                        hotbar = Data.Player:Get("EquippedItems") or {}
                        slot = table.find(hotbar, wanted)
                        if slot then return true end
                        task.wait(0.05)
                    end
                end
            end
            return false
        end
        if not slot then
            insertIntoHotbar()
        end
        if not slot then
            hotbar = Data.Player:Get("EquippedItems") or {}
            if not displaced then
                for index = #hotbar, 2, -1 do
                    local evictUUID = hotbar[index]
                    local entry = evictUUID and S.Quest.findByUUID(evictUUID)
                    if entry and not (entry.Data
                        and entry.Data.Type == "Fishing Rods")
                    then
                        displaced = entry
                        Runtime.Quest.Action.Restore.Displaced = entry
                        pcall(function()
                            Remote.unequipItem:FireServer(evictUUID)
                        end)
                        deadline = os.clock() + 1.5
                        while os.clock() < deadline
                            and S.Quest.isActive(job, session)
                            and table.find(Data.Player:Get("EquippedItems") or {},
                                tostring(evictUUID))
                        do task.wait(0.05) end
                        break
                    end
                end
            end
            if not displaced then return false, nil, inserted end
            insertIntoHotbar()
        end
        if not slot then return false, displaced, inserted end
        for _ = 1, 3 do
            if not S.Quest.isActive(job, session) then break end
            hotbar = Data.Player:Get("EquippedItems") or {}
            slot = table.find(hotbar, wanted)
            if not slot then break end
            pcall(function() Remote.equipTool:FireServer(slot) end)
            deadline = os.clock() + 0.8
            while os.clock() < deadline and S.Quest.isActive(job, session) do
                if tostring(Data.Player:Get("EquippedId") or "") == wanted then
                    return true, displaced, inserted
                end
                task.wait(0.05)
            end
            -- Some hotbar states keep the currently held fish/stone despite
            -- a normal UnequipTool. Remove that non-rod blocker once, retry
            -- the target, then restore it in restoreQuestItem afterwards.
            local blockerUUID = tostring(Data.Player:Get("EquippedId") or "")
            if blockerUUID ~= "" and blockerUUID ~= wanted and not displaced then
                local blocker = S.Quest.findByUUID(blockerUUID)
                if blocker and not (blocker.Data
                    and blocker.Data.Type == "Fishing Rods")
                    and table.find(Data.Player:Get("EquippedItems") or {}, blockerUUID)
                then
                    displaced = blocker
                    Runtime.Quest.Action.Restore.Displaced = blocker
                    pcall(function() Remote.unequipItem:FireServer(blockerUUID) end)
                    deadline = os.clock() + 1.5
                    while os.clock() < deadline
                        and S.Quest.isActive(job, session)
                        and table.find(Data.Player:Get("EquippedItems") or {}, blockerUUID)
                    do task.wait(0.05) end
                end
            end
        end
        return false, displaced, inserted
    end

    S.Quest.getHotbarRodSlot = function()
        local hotbar = Data.Player:Get("EquippedItems") or {}
        for slot, uuid in ipairs(hotbar) do
            local entry = S.Quest.findByUUID(uuid)
            if entry and entry.Data and entry.Data.Type == "Fishing Rods" then
                return slot, tostring(uuid)
            end
        end
        -- Fish It reserves slot one for a rod; this also covers a one-frame
        -- item-data replication delay.
        return hotbar[1] and 1 or nil, hotbar[1] and tostring(hotbar[1]) or nil
    end

    S.Quest.restoreQuestItem = function(targetUUID, displaced, restoreRod, removeInserted)
        local wanted = tostring(targetUUID or "")
        local function check()
            local hotbar = Data.Player:Get("EquippedItems") or {}
            local insertedGone = not removeInserted or not table.find(hotbar, wanted)
            local displacedUUID = displaced and displaced.Item and tostring(displaced.Item.UUID)
            local displacedBack = not displacedUUID or not S.Quest.findByUUID(displacedUUID)
                or table.find(hotbar, displacedUUID) ~= nil
            local rodSlot, rodUUID = S.Quest.getHotbarRodSlot()
            local rodBack = not restoreRod or (rodUUID and tostring(Data.Player:Get("EquippedId") or "") == rodUUID)
            return insertedGone and displacedBack and rodBack, insertedGone, displacedBack, rodBack, rodSlot
        end
        for _ = 1, 3 do
            local done, insertedGone, displacedBack, rodBack, rodSlot = check()
            if done then
                Runtime.Quest.Action.Restore = nil
                return true
            end
            if not insertedGone then
                pcall(function() Remote.unequipItem:FireServer(wanted) end)
            elseif not displacedBack then
                pcall(function()
                    Remote.equipItem:FireServer(displaced.Item.UUID,
                        displaced.Data and displaced.Data.Type or displaced.Category or "Items")
                end)
            elseif not rodBack and rodSlot then
                pcall(function() Remote.equipTool:FireServer(rodSlot) end)
            end
            local deadline = os.clock() + 0.8
            repeat
                if check() then Runtime.Quest.Action.Restore = nil return true end
                task.wait(0.05)
            until os.clock() >= deadline
        end
        return false
    end

    S.Quest.retryRestore = function()
        if Runtime.Quest.RestoreWorker then return end
        Runtime.Quest.RestoreWorker = true
        task.spawn(function()
            while Runtime.Quest.RestorePending do
                local pending = Runtime.Quest.RestorePending
                local ticket = S.Quest.acquireAction("Restore", function()
                    return Runtime.Quest.RestorePending == pending
                end, 3)
                if ticket then
                    local ok, done = pcall(S.Quest.restoreQuestItem, pending.Target,
                        pending.Displaced, pending.RestoreRod, pending.Inserted)
                    if ok and done and Runtime.Quest.RestorePending == pending then
                        Runtime.Quest.RestorePending = nil
                    end
                    S.Quest.releaseAction(ticket)
                end
                task.wait(1)
            end
            Runtime.Quest.RestoreWorker = false
        end)
    end

    S.Quest.equipRodAggressive = function(job, session, uuid)
        local wanted = tostring(uuid or "")
        for _ = 1, 4 do
            if not S.Quest.isActive(job, session) then return false end
            pcall(function()
                Remote.equipItem:FireServer(uuid, "Fishing Rods")
            end)
            local deadline = os.clock() + 1
            while os.clock() < deadline do
                local hotbar = Data.Player:Get("EquippedItems") or {}
                if tostring(hotbar[1] or "") == wanted then break end
                task.wait(0.05)
            end
            if not S.Quest.isActive(job, session) then return false end
            pcall(function() Remote.equipTool:FireServer(1) end)
            deadline = os.clock() + 0.8
            while os.clock() < deadline do
                if tostring(Data.Player:Get("EquippedId") or "") == wanted then
                    return true
                end
                task.wait(0.05)
            end
        end
        return false
    end

    -- equipRodCanonical: equip progression rod agresif (mirip buy rod)
    -- Serialized through the shared equipment action lock.
    S.Quest.equipRodCanonical = function(job, session, uuid)
        local equipped = false
        S.Quest.withSellHold("Rod:" .. job, function()
            return S.Quest.isActive(job, session)
        end, function()
            equipped = S.Quest.equipRodAggressive(job, session, uuid)
        end, 10, job, session)
        return equipped
    end

    -- equipRodWithRetry: retry 5x cek Replion EquippedId dinamis
    -- Retry only while this exact Quest toggle generation is active.
    S.Quest.equipRodWithRetry = function(job, session, uuid)
        local equipped = false
        for attempt = 1, 5 do
            if not S.Quest.isActive(job, session) then break end
            local currentId = tostring(Data.Player:Get("EquippedId") or "")
            if currentId == uuid then
                equipped = true
                break
            end
            local ok = S.Quest.equipRodCanonical(job, session, uuid)
            if ok then
                equipped = true
                break
            end
            local acked = S.Quest.waitJob(job, function()
                return tostring(Data.Player:Get("EquippedId") or "") == uuid
            end, 2, 0.1, session)
            if acked then
                equipped = true
                break
            end
            if attempt < 5 then task.wait(2) end
        end
        return equipped
    end

    -- Equip the exact Artifact, place it, and treat TempleLevers as the only
    -- success acknowledgement. The action coordinator pauses fishing,
    -- Auto Equip, and Auto Sell only for the short placement transaction.
    S.Quest.placeStateItem = function(job, session, remote, stateKey, typeName)
        if not remote then return false end
        local entry = S.Quest.findByName(typeName)
        local uuid = entry and entry.Item and entry.Item.UUID
        if not uuid then return false end
        local placed = false
        S.Quest.withSellHold("Place:" .. typeName, function()
            return S.Quest.isActive(job, session)
        end, function()
            entry = S.Quest.findByUUID(uuid)
            if not entry then return end
            local itemType = entry.Data and entry.Data.Type or "Artifacts"
            local fallbackTypes = {"Artifacts", "Items"}
            if entry.Category then
                table.insert(fallbackTypes, 1, entry.Category)
            end
            local held, displaced, inserted = S.Quest.equipQuestItem(
                job, session, uuid, itemType, fallbackTypes)
            if not held then
                S.Quest.restoreQuestItem(uuid, displaced, true, inserted)
                return
            end
            local function isPlaced()
                local state = S.Quest.get(stateKey) or {}
                return state[typeName] == true
            end
            for attempt = 1, 3 do
                if not S.Quest.isActive(job, session) then break end
                if isPlaced() then
                    placed = true
                    break
                end
                pcall(function() remote:FireServer(typeName) end)
                if S.Quest.waitJob(job, isPlaced, 8, 0.1, session) then
                    placed = true
                    break
                end
                if attempt < 3 then task.wait(1) end
            end
            if placed then
                S.Quest.refreshFromReplion()
                S.Quest.waitJob(job, function()
                    return not S.Quest.hasUUID(uuid)
                end, 2, 0.05, session)
            end
            S.Quest.restoreQuestItem(uuid, displaced, true, inserted)
        end, 10, job, session)
        return placed
    end

    -- exchangeItem: dialogueEnded + waitJob progress ack, max 3 retry.
    -- prepareAction is used by Diamond turn-ins to establish physical NPC
    -- proximity before the same controller-confirmation remote is sent.
    S.Quest.exchangeItem = function(
        job, session, questName, objectiveId, args, entry, prepareAction)
        local before = S.Quest.progress(questName, objectiveId, 1)
        local ok = false
        S.Quest.withSellHold("Exchange:" .. tostring(objectiveId), function()
            return S.Quest.isActive(job, session)
        end, function()
            local heldUUID, displaced, inserted = nil, nil, false
            if entry and entry.Item and entry.Item.UUID then
                heldUUID = entry.Item.UUID
                local fresh = S.Quest.findByUUID(heldUUID)
                if not fresh then return end
                local held
                held, displaced, inserted = S.Quest.equipQuestItem(job, session,
                    heldUUID, fresh.Data and fresh.Data.Type or "Fish")
                if not held then
                    S.Quest.restoreQuestItem(
                        heldUUID, displaced, true, inserted)
                    return
                end
            end
            local function progressed()
                return S.Quest.progress(questName, objectiveId, 1) > before
                    or S.Quest.isCompleted(questName)
            end
            for attempt = 1, 3 do
                if not S.Quest.isActive(job, session) then break end
                if progressed() then
                    ok = true
                    S.Quest.refreshFromReplion()
                    break
                end
                if not Remote.dialogueEnded then break end
                if prepareAction and not prepareAction() then break end
                if not S.Quest.isActive(job, session) then break end
                pcall(function() Remote.dialogueEnded:FireServer(table.unpack(args)) end)
                local acked = S.Quest.waitJob(job, progressed, 10, 0.1, session)
                if acked then
                    ok = true
                    S.Quest.refreshFromReplion()
                    break
                end
                if attempt < 3 then task.wait(2) end
            end
            if heldUUID then
                S.Quest.restoreQuestItem(
                    heldUUID, displaced, true, inserted)
            end
        end, 10, job, session)
        return ok
    end

    S.Quest.loadDiamondDialogue = function()
        if S.Quest.DiamondDialogue and S.Quest.DiamondDialogueTree then
            return S.Quest.DiamondDialogue, S.Quest.DiamondDialogueTree
        end
        local controllers = Service.ReplicatedStorage:FindFirstChild("Controllers")
        local controller = controllers and controllers:FindFirstChild("DialogueController")
        local internal = controller and controller:FindFirstChild("Internal")
        local dialogue = internal and internal:FindFirstChild("Dialogue")
        local tree = internal and internal:FindFirstChild("DialogueTree")
        if not dialogue or not tree then return nil end
        local ok, module, data = pcall(function() return require(dialogue), require(tree) end)
        if not ok or type(module) ~= "table" or type(data) ~= "table" then return nil end
        S.Quest.DiamondDialogue, S.Quest.DiamondDialogueTree = module, data
        return module, data
    end

    -- Only a currently rendered, enabled quest option may be selected. Never
    -- invent a path/index or call DialogueEnded as an activation fallback.
    S.Quest.diamondDialogueOption = function(active, tree)
        if not active or active.dead or active.animating or active.selectionMade
            or active.name ~= "Diamond Researcher" then return nil end
        local paths = tree and tree[active.name]
        local branch = paths and paths[active.path]
        if type(branch) == "function" then
            local ok, evaluated = pcall(branch)
            if not ok then return nil end
            branch = evaluated
        end
        if type(branch) ~= "table" or type(branch.Dialogue) ~= "table" then return nil end
        local gui = active.instance
        local content = gui and gui:FindFirstChild("Content")
        local inside = content and content:FindFirstChild("Inside")
        local list = inside and inside:FindFirstChild("List")
        if not list or gui.Enabled == false or not content.Visible or not inside.Visible
            or not list.Visible then return nil end
        for index, option in pairs(branch.Dialogue) do
            if type(option) == "table" and option.Reply == "Diamond Researcher Quest"
                and not option.Blocked and not option.Void and not option.Disabled then
                local button = list:FindFirstChild(tostring(index))
                local items = button and button:FindFirstChild("Items")
                local label = items and items:FindFirstChild("QuestLabel")
                if button and button.Visible and button.Active and label
                    and label.Text == option.Reply then
                    return index, option
                end
            end
        end
        return nil
    end

    S.Quest.startDiamondQuest = function(session)
        local started, reason = false, "Dialogue unavailable"
        S.Quest.withSellHold("Dialogue:DiamondStart", function()
            return S.Quest.isActive("Diamond", session)
        end, function()
            local ownedDialogue, dialogueModule = nil, nil
            local previousDialogue, openedNPC, promptFired = nil, nil, false
            local function activeSession() return S.Quest.isActive("Diamond", session) end
            local function isStarted()
                return S.Quest.getMainline("Diamond Researcher") ~= nil
                    or S.Quest.isCompleted("Diamond Researcher")
                    or S.Quest.owns("Diamond Key") or S.Quest.owns("Diamond Rod")
            end
            local ok, err = pcall(function()
                if isStarted() then started = true return end
                if not S.Quest.approachDiamondResearcher("Diamond", session) then return end
                local tree
                dialogueModule, tree = S.Quest.loadDiamondDialogue()
                if not dialogueModule or type(fireproximityprompt) ~= "function" then return end
                local previous = dialogueModule._activeInstance
                if previous and not previous.dead then reason = "Another dialogue is open" return end
                local npc = S.Quest.getNPC("Diamond Researcher")
                local prompt = npc and npc:FindFirstChildWhichIsA("ProximityPrompt", true)
                if not prompt or not prompt.Enabled or not activeSession() then return end
                previousDialogue, openedNPC, promptFired = previous, npc, true
                fireproximityprompt(prompt)
                local opened = S.Quest.waitJob("Diamond", function()
                    local current = dialogueModule._activeInstance
                    if current and current ~= previous and not current.dead
                        and current.name == "Diamond Researcher" and current.basePart
                        and current.basePart:IsDescendantOf(npc) then
                        ownedDialogue = current
                        return true
                    end
                    return false
                end, 3, 0.05, session)
                if not opened or not activeSession() then return end
                -- Opening a UI alone is not proof of eligibility: this game's
                -- dumped dialogue exposes the quest option without a rod check.
                if not S.Quest.owns("Element Rod") then
                    reason = "Element Rod required - quest not accepted"
                    S.Quest.waitJob("Diamond", function() return ownedDialogue.dead end, 1, 0.05, session)
                    return
                end
                local available = S.Quest.waitJob("Diamond", function()
                    return dialogueModule._activeInstance ~= ownedDialogue or ownedDialogue.dead
                        or S.Quest.diamondDialogueOption(ownedDialogue, tree) ~= nil
                end, 3, 0.05, session)
                if not available or not activeSession() or not S.Quest.owns("Element Rod")
                    or dialogueModule._activeInstance ~= ownedDialogue or ownedDialogue.dead then return end
                local index, option = S.Quest.diamondDialogueOption(ownedDialogue, tree)
                if not index then reason = "Lary has no available quest option" return end
                -- Same selection method used by the game's rendered option.
                -- It displays the response and owns its own DialogueEnded event.
                ownedDialogue:confirmSelection(ownedDialogue.path, index, option)
                started = S.Quest.waitJob("Diamond", isStarted, 8, 0.1, session)
                reason = started and nil or "Quest acknowledgement not received"
            end)
            -- Close only the dialogue opened by this action, including OFF and
            -- error paths. Native stop restores camera/rod and unlocks prompts.
            if not ownedDialogue and promptFired and dialogueModule then
                local current = dialogueModule._activeInstance
                if current and current ~= previousDialogue and not current.dead
                    and current.name == "Diamond Researcher" and current.basePart
                    and current.basePart:IsDescendantOf(openedNPC) then ownedDialogue = current end
            end
            if ownedDialogue and dialogueModule._activeInstance == ownedDialogue
                and not ownedDialogue.dead then pcall(function() ownedDialogue:stop() end) end
            if not ok then Runtime.LastError = "Diamond dialogue: " .. tostring(err) end
            if started then S.Quest.refreshFromReplion() end
        end, 12, "Diamond", session)
        if not started and S.Quest.isActive("Diamond", session) then
            if Runtime.Quest.DiamondDialogueNotice ~= session then
                Runtime.Quest.DiamondDialogueNotice = session
                UI.Library:Notify({Title="Orvion", Subtitle="Hub", Content=reason})
            end
        end
        return started
    end

    -- createTranscended: wait for both consumption and, when supplied, the
    -- corresponding Replion quest-progress acknowledgement.  Consumption
    -- alone is not enough: progress can replicate a frame later.
    S.Quest.createTranscended = function(
        job, session, entry, questName, objectiveId, objectiveGoal)
        local uuid = entry and entry.Item and entry.Item.UUID
        if not uuid then return false end
        if not Remote.createTranscended then return false end
        local ok = false
        local beforeProgress = questName and objectiveId
            and S.Quest.progress(questName, objectiveId, objectiveGoal or 1)
            or nil
        S.Quest.withSellHold("Transcended:" .. job, function()
            return S.Quest.isActive(job, session)
        end, function()
            if not S.Quest.findByUUID(uuid) then return end
            local held, displaced, inserted = S.Quest.equipQuestItem(
                job, session, uuid, "Fish")
            if not held then
                S.Quest.restoreQuestItem(uuid, displaced, true, inserted)
                return
            end
            local done, result = false, false
            local invokeThread = task.spawn(function()
                local callOk, response = pcall(function()
                    return Remote.createTranscended:InvokeServer()
                end)
                result = callOk and response == true
                done = true
            end)
            local deadline = os.clock() + 10
            while S.Quest.isActive(job, session) and not done
                and os.clock() < deadline
            do
                task.wait(0.05)
            end
            if not done then pcall(task.cancel, invokeThread) end
            if not result then
                S.Quest.TranscendedCooldown[tostring(uuid)] = os.clock() + 15
                S.Quest.restoreQuestItem(uuid, displaced, true, inserted)
                return
            end
            local consumed = S.Quest.waitJob(job, function()
                return not S.Quest.hasUUID(uuid)
            end, 4, 0.05, session)
            if consumed then
                if beforeProgress == nil then
                    ok = true
                else
                    ok = S.Quest.waitJob(job, function()
                        return S.Quest.isCompleted(questName)
                            or S.Quest.progress(
                                questName, objectiveId, objectiveGoal or 1
                            ) > beforeProgress
                    end, 8, 0.05, session)
                end
                if ok then S.Quest.refreshFromReplion() end
            end
            if ok then
                S.Quest.TranscendedCooldown[tostring(uuid)] = nil
            else
                -- Avoid retrying the same rejected/unacknowledged UUID every
                -- Element loop tick. Another valid Secret can still be used.
                S.Quest.TranscendedCooldown[tostring(uuid)] = os.clock() + 15
            end
            S.Quest.restoreQuestItem(uuid, displaced, true, inserted)
        end, 10, job, session)
        return ok
    end

    -- Resolve the actual inventory entry; no dependency on the Items name alias.
    S.Quest.findPressureFish = function(fishName)
        return S.Quest.findByName(fishName, "Fish")
    end

    -- placePressureFishEntry: equip ikan + fire + waitJob ack, max 3 retry
    -- smart hotbar: evict slot ujung kalau penuh, restore setelah
    S.Quest.placePressureFishEntry = function(job, session, definition)
        local ok = false
        S.Quest.withSellHold("Pressure:" .. definition.Name, function()
            return S.Quest.isActive(job, session)
        end, function()
            local entry = S.Quest.findPressureFish(definition.Name)
            local uuid = entry and entry.Item and entry.Item.UUID
            if not uuid then return end
            local held, displaced, inserted = S.Quest.equipQuestItem(job, session,
                uuid, entry.Data and entry.Data.Type or "Fish")
            if not held then
                S.Quest.restoreQuestItem(uuid, displaced, true, inserted)
                return
            end
            local function isPlaced()
                local state = S.Quest.get("RuinPressurePlates") or {}
                return state[definition.Name] == true
            end
            for attempt = 1, 3 do
                if not S.Quest.isActive(job, session) then break end
                if isPlaced() then
                    ok = true
                    S.Quest.refreshFromReplion()
                    break
                end
                if Remote.placePressure then
                    pcall(function()
                        Remote.placePressure:FireServer(definition.Name)
                    end)
                end
                local acked = S.Quest.waitJob(job, isPlaced, 8, 0.1, session)
                if acked then
                    ok = true
                    S.Quest.refreshFromReplion()
                    break
                end
                if attempt < 3 then task.wait(1) end
            end
            if ok then
                S.Quest.waitJob(job, function()
                    return not S.Quest.hasUUID(uuid)
                end, 2, 0.05, session)
            end
            S.Quest.restoreQuestItem(uuid, displaced, true, inserted)
        end, 10, job, session)
        return ok
    end

    -- openAndClaimDiamond: teleport door + equip key + proximity + claim
    S.Quest.openAndClaimDiamond = function(job, session, keyEntry)
        local uuid = keyEntry and keyEntry.Item and keyEntry.Item.UUID
        if not uuid then return false end
        local ok = false
        S.Quest.withSellHold("DiamondKey", function()
            return S.Quest.isActive(job, session)
        end, function()
            if not S.Quest.findByUUID(uuid) then return end
            local held, displaced, inserted = S.Quest.equipQuestItem(
                job, session, uuid, "Gears")
            if not held then
                S.Quest.restoreQuestItem(uuid, displaced, true, inserted)
                return
            end
            -- Setelah key di tangan, baru teleport ke door
            if not S.Quest.teleport(S.Quest.DiamondDoor, job, session) then return end
            local prompt = nil
            local promptReady = S.Quest.waitJob(job, function()
                local doors = Service.CollectionService:GetTagged("DiamondDoor")
                local door = doors[1]
                local input = door and door:FindFirstChild("InputPart")
                prompt = input and input:FindFirstChildOfClass("ProximityPrompt")
                return prompt and prompt.Enabled
            end, 6, 0.05, session)
            if not promptReady or type(fireproximityprompt) ~= "function" then
                S.Quest.restoreQuestItem(uuid, displaced, true, inserted)
                return
            end
            pcall(fireproximityprompt, prompt)
            local opened = S.Quest.waitJob(job, function()
                return prompt.Parent == nil or prompt.Enabled == false
            end, 5, 0.05, session)
            -- The server only allows ClaimItem after the keyed door has
            -- transitioned.  A disappeared prompt is the client-side open
            -- acknowledgement; never send the claim while it is still live.
            if not opened then
                S.Quest.restoreQuestItem(uuid, displaced, true, inserted)
                return
            end
            task.wait(0.25)
            if not S.Quest.isActive(job, session) or not Remote.claimItem then
                S.Quest.restoreQuestItem(uuid, displaced, true, inserted)
                return
            end
            local done, claimed = false, false
            local claimThread = task.spawn(function()
                local callOk, result = pcall(function()
                    return Remote.claimItem:InvokeServer("Diamond Rod")
                end)
                claimed = callOk and result ~= false
                done = true
            end)
            local deadline = os.clock() + 10
            while S.Quest.isActive(job, session) and not done
                and os.clock() < deadline
            do
                task.wait(0.05)
            end
            if not done then pcall(task.cancel, claimThread) end
            if not claimed then
                S.Quest.restoreQuestItem(uuid, displaced, true, inserted)
                return
            end
            local received = S.Quest.waitJob(job, function()
                return S.Quest.owns("Diamond Rod")
            end, 8, 0.1, session)
            if received then
                ok = true
                S.Quest.refreshFromReplion()
            end
            S.Quest.restoreQuestItem(
                uuid, displaced, not received, inserted)
            if received then
                local rod = S.Quest.findByName("Diamond Rod")
                local rodUUID = rod and rod.Item and rod.Item.UUID
                if rodUUID then
                    S.Quest.equipRodAggressive(job, session, rodUUID)
                end
            end
        end, 10, job, session)
        return ok
    end

    -- ====== INDEPENDENT RUNNERS — table assignment pattern ======

    S.Quest.jobComplete = function(job)
        if job == "DeepSea" then return S.Quest.owns("Ghostfinn Rod") or S.Quest.isCompleted("Deep Sea Quest") end
        if job == "Artifact" then
            if S.Quest.get("UnlockedTemple") == true then return true end
            local levers = S.Quest.get("TempleLevers")
            if type(levers) ~= "table" then return false end
            for _, definition in ipairs(S.Quest.Artifacts) do
                if levers[definition.Type] ~= true then return false end
            end
            return true
        end
        if job == "Element" then return S.Quest.owns("Element Rod") or S.Quest.isCompleted("Element Quest") end
        if job == "Diamond" then return S.Quest.owns("Diamond Rod") or S.Quest.isCompleted("Diamond Researcher") end
        if job == "Crystalline" then
            local plates = S.Quest.get("RuinPressurePlates") or {}
            for _, definition in ipairs(S.Quest.Pressure) do
                if plates[definition.Name] ~= true then return false end
            end
            return true
        end
        return false
    end

    -- Workers may all stay enabled, but one character owns route movement at
    -- a time. Artifact precedes Element, so Element automatically takes over
    -- only after all four lever acknowledgements arrive or Artifact is OFF.
    S.Quest.MovementOrder = {"DeepSea", "Artifact", "Element", "Diamond"}
    S.Quest.routeReady = function(job)
        return Runtime.Quest.Enabled[job] == true
            and not S.Quest.jobComplete(job)
            and (Runtime.Quest.RouteRetry[job] or 0) <= os.clock()
    end

    S.Quest.canNavigate = function(job, session)
        if not S.Quest.isActive(job, session) or not S.Quest.routeReady(job)
            or Runtime.isTrading() or Runtime.Quest.Action.Busy
            or (Runtime.Quest.FallbackUntil or 0) > os.clock()
        then return false end
        local visit = Runtime.Quest.Visit
        if visit and visit.Until > os.clock()
            and S.Quest.isActive(visit.Job, visit.Session)
            and S.Quest.routeReady(visit.Job)
        then return visit.Job == job and visit.Session == session end
        for _, candidate in ipairs(S.Quest.MovementOrder) do
            if S.Quest.routeReady(candidate) then return candidate == job end
        end
        return false
    end

    S.Quest.canCrystallineNavigate = function(session)
        if not S.Quest.isActive("Crystalline", session)
            or Runtime.isTrading() or Runtime.Quest.Action.Busy
            or (Runtime.Quest.FallbackUntil or 0) > os.clock()
        then return false end
        for _, job in ipairs(S.Quest.MovementOrder) do
            if S.Quest.routeReady(job) then return false end
        end
        return true
    end

    S.Quest.completeJob = function(job, session)
        if not S.Quest.isActive(job, session) then return end
        Runtime.Quest.RouteRetry[job] = nil
        if Runtime.Quest.CompletionNotified[job] ~= session then
            Runtime.Quest.CompletionNotified[job] = session
            local labels = { Artifact="Artifact lever", DeepSea="Deep sea quest",
                Element="Element quest", Diamond="Diamond rod quest",
                Crystalline="Crystalline passage" }
            UI.Library:Notify({Title="Orvion", Subtitle="Hub",
                Content=(labels[job] or job) .. " has completed!"})
        end
        S.Quest.refreshFromReplion()
    end

    -- A new session may begin immediately after a toggle restart.  The old
    -- session is already invalid because isActive checks its generation; it
    -- must never block its replacement from starting.
    S.Quest.startJobThread = function(job, fn, session)
        local existing = Runtime.Quest.Threads[job]
        if existing and Runtime.Quest.ThreadSessions[job] == session then
            return false
        end
        local thread = nil
        thread = task.spawn(function()
            local issue = S.Quest.getStartIssue(job)
            while issue and S.Quest.isActive(job, session) do
                Runtime.Quest.RouteRetry[job] = os.clock() + 2
                task.wait(1)
                issue = S.Quest.getStartIssue(job)
            end
            while S.Quest.isActive(job, session)
                and Runtime.Quest.Action.Busy
                and Runtime.Quest.Action.Job == job
                and Runtime.Quest.Action.Session ~= session
            do
                task.wait(0.05)
            end
            if not S.Quest.isActive(job, session) then
                if Runtime.Quest.Threads[job] == thread
                    and Runtime.Quest.ThreadSessions[job] == session
                then
                    Runtime.Quest.Threads[job] = nil
                    Runtime.Quest.ThreadSessions[job] = nil
                end
                return
            end
            Runtime.Quest.RouteRetry[job] = nil
            local ok, err = pcall(fn, session)
            if Runtime.Quest.Threads[job] == thread
                and Runtime.Quest.ThreadSessions[job] == session
            then
                Runtime.Quest.Threads[job] = nil
                Runtime.Quest.ThreadSessions[job] = nil
            end
            if ok then
                Runtime.Quest.Failures[job] = 0
                return
            end
            if not S.Quest.isActive(job, session) then return end
            if Runtime.Quest.Action.Busy
                and Runtime.Quest.Action.Job == job
                and Runtime.Quest.Action.Session == session
            then
                S.Quest.releaseAction(Runtime.Quest.Action.Ticket)
            end
            local failures = (Runtime.Quest.Failures[job] or 0) + 1
            Runtime.Quest.Failures[job] = failures
            Runtime.LastError = ("%s Quest (%d): %s"):format(tostring(job), failures, tostring(err))
            if failures >= 3 then
                Runtime.Quest.Stop(job)
                local toggle = S.Quest.Toggles and S.Quest.Toggles[job]
                if toggle then pcall(function() toggle:Set(false) end) end
                UI.Library:Notify({
                    Title="Orvion", Subtitle="Hub",
                    Content=tostring(job).." Quest stopped after repeated errors",
                })
                return
            end
            task.delay(math.min(2, failures * 0.5), function()
                if S.Quest.isActive(job, session)
                    and Runtime.Quest.Threads[job] == nil
                then
                    S.Quest.startJobThread(job, fn, session)
                end
            end)
        end)
        Runtime.Quest.Threads[job] = thread
        Runtime.Quest.ThreadSessions[job] = session
        return true
    end

    -- ARTIFACT: farm at each exact location until its item exists, then own
    -- the short item-action lock while equipping and placing it. Never advance
    -- to the next definition before TempleLevers confirms the current lever.
    S.Quest.Runners.Artifact = function(session)
        local lastTeleport = nil
        while S.Quest.isActive("Artifact", session) do
            local levers = S.Quest.get("TempleLevers")
            if type(levers) == "table" then
                local allDone = true
                for _, definition in ipairs(S.Quest.Artifacts) do
                    if levers[definition.Type] ~= true then
                        allDone = false
                        if not S.Quest.canNavigate("Artifact", session) then break end
                        local entry = S.Quest.findByName(definition.Type)
                        if entry then
                            local near = S.Quest.isNear(definition.CFrame, 30)
                            if not near then
                                local moved = S.Quest.teleport(definition.CFrame, "Artifact", session)
                                if moved then
                                    near = S.Quest.waitJob("Artifact", function()
                                        return S.Quest.isNear(definition.CFrame, 30)
                                    end, 2, 0.05, session)
                                end
                            end
                            if near and S.Quest.canNavigate("Artifact", session) then
                                lastTeleport = nil
                                S.Quest.placeStateItem(
                                    "Artifact", session, Remote.placeLever,
                                    "TempleLevers", definition.Type)
                            end
                        elseif lastTeleport ~= definition.Type
                            or not S.Quest.isNear(definition.CFrame, 80)
                        then
                            if S.Quest.teleport(definition.CFrame, "Artifact", session) then
                                lastTeleport = definition.Type
                            end
                        end
                        break
                    end
                end
                if allDone then
                    S.Quest.waitJob("Artifact", function()
                        return S.Quest.get("UnlockedTemple") == true
                    end, 8, 0.1, session)
                    S.Quest.completeJob("Artifact", session)
                    break
                end
            end
            task.wait(0.4)
        end
    end

    -- DEEPSEA: activate quest di Sisyphus, loop per objective
    S.Quest.Runners.DeepSea = function(session)
        while S.Quest.isActive("DeepSea", session)
            and not S.Quest.getMainline("Deep Sea Quest")
            and not S.Quest.isCompleted("Deep Sea Quest")
            and not S.Quest.owns("Ghostfinn Rod")
        do
            if S.Quest.canNavigate("DeepSea", session) then
                S.Quest.teleport("Sisyphus Statue", "DeepSea", session)
                local accepted = S.Quest.waitJob("DeepSea", function()
                    return S.Quest.getMainline("Deep Sea Quest") ~= nil
                        or S.Quest.isCompleted("Deep Sea Quest")
                end, 8, 0.1, session)
                if not accepted then Runtime.Quest.RouteRetry.DeepSea = os.clock() + 20 end
            end
            task.wait(0.5)
        end
        local lastTeleport = nil
        while S.Quest.isActive("DeepSea", session) do
            if S.Quest.isCompleted("Deep Sea Quest") and Runtime.Quest.CompletionNotified.DeepSea ~= session then
                S.Quest.completeJob("DeepSea", session)
            end
            local ghostfinn = S.Quest.findByName("Ghostfinn Rod")
            if ghostfinn then
                local uuid = ghostfinn.Item and ghostfinn.Item.UUID
                if uuid then
                    S.Quest.equipRodWithRetry("DeepSea", session, uuid)
                end
                -- Cek dinamis: stop hanya kalau uuid valid DAN sudah terpasang
                if uuid and tostring(Data.Player:Get("EquippedId") or "") == uuid then
                    S.Quest.completeJob("DeepSea", session)
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
            if targetLoc and S.Quest.canNavigate("DeepSea", session)
                and (lastTeleport ~= targetLoc
                    or not S.Quest.isNear(targetLoc, 150))
            then
                S.Quest.teleport(targetLoc, "DeepSea", session)
                lastTeleport = targetLoc
            end
            task.wait(0.5)
        end
    end

    -- ELEMENT: user-selected route; activation and progress are server-authoritative.
    S.Quest.Runners.Element = function(session)
        while S.Quest.isActive("Element", session)
            and not S.Quest.getMainline("Element Quest")
            and not S.Quest.isCompleted("Element Quest")
            and not S.Quest.owns("Element Rod")
        do
            if S.Quest.canNavigate("Element", session) then
                S.Quest.teleport("Ancient Jungle", "Element", session)
                local accepted = S.Quest.waitJob("Element", function()
                    return S.Quest.getMainline("Element Quest") ~= nil
                        or S.Quest.isCompleted("Element Quest")
                end, 8, 0.1, session)
                if not accepted then Runtime.Quest.RouteRetry.Element = os.clock() + 20 end
            end
            task.wait(0.5)
        end

        local lastTeleport = nil
        while S.Quest.isActive("Element", session) do
            if S.Quest.isCompleted("Element Quest") and Runtime.Quest.CompletionNotified.Element ~= session then
                S.Quest.completeJob("Element", session)
            end
            if S.Quest.owns("Element Rod") then
                local rod = S.Quest.findByName("Element Rod")
                local uuid = rod and rod.Item and rod.Item.UUID
                if uuid then
                    S.Quest.equipRodWithRetry("Element", session, uuid)
                end
                -- Cek dinamis: stop hanya kalau uuid valid DAN sudah terpasang
                if uuid and tostring(Data.Player:Get("EquippedId") or "") == uuid then
                    S.Quest.completeJob("Element", session)
                    break
                end
            end
            if not S.Quest.canNavigate("Element", session) then
                task.wait(0.35)
                continue
            end
            local targetLoc = nil
            if S.Quest.progress("Element Quest", 2, 1) < 1 then
                targetLoc = "Ancient Jungle"
            elseif S.Quest.progress("Element Quest", 3, 1) < 1 then
                targetLoc = "Sacred Temple"
            elseif S.Quest.progress("Element Quest", 4, 3) < 3 then
                local level = tonumber(S.Quest.get("Level")) or 0
                targetLoc = S.Quest.get("UnlockedTemple") == true
                    and "Sacred Temple" or "Ancient Jungle"
                if level >= 200 then
                    local secret = S.Quest.findSecret()
                    if secret then
                        lastTeleport = nil  -- reset — setelah createTranscended lokasi mungkin berubah
                        S.Quest.createTranscended(
                            "Element", session, secret,
                            "Element Quest", 4, 3)
                    end
                else
                    -- Keep the intended farming location while waiting for
                    -- the level-200 gate; event/manual movement must not
                    -- strand this phase elsewhere.
                    targetLoc = S.Quest.get("UnlockedTemple") == true
                        and "Sacred Temple" or "Ancient Jungle"
                end
            end
            if targetLoc and (lastTeleport ~= targetLoc
                or not S.Quest.isNear(targetLoc, 150))
            then
                S.Quest.teleport(targetLoc, "Element", session)
                lastTeleport = targetLoc
            end
            task.wait(0.35)
        end
    end

    -- DIAMOND: attempt the NPC on request; rejected activation yields the route.
    S.Quest.Runners.Diamond = function(session)
        while S.Quest.isActive("Diamond", session)
            and not S.Quest.getMainline("Diamond Researcher")
            and not S.Quest.isCompleted("Diamond Researcher")
            and not S.Quest.owns("Diamond Key")
            and not S.Quest.owns("Diamond Rod")
        do
            if S.Quest.canNavigate("Diamond", session) then
                local accepted = S.Quest.startDiamondQuest(session)
                Runtime.Quest.Visit = nil
                if not accepted then Runtime.Quest.RouteRetry.Diamond = os.clock() + 30 end
            end
            task.wait(0.5)
        end

            local lastTeleport = nil  -- cache: cegah teleport spam tiap 0.4s ke lokasi sama
        while S.Quest.isActive("Diamond", session) do
            if S.Quest.isCompleted("Diamond Researcher") and Runtime.Quest.CompletionNotified.Diamond ~= session then
                S.Quest.completeJob("Diamond", session)
            end
            if S.Quest.owns("Diamond Rod") then
                local rod = S.Quest.findByName("Diamond Rod")
                local uuid = rod and rod.Item and rod.Item.UUID
                if uuid then
                    S.Quest.equipRodWithRetry("Diamond", session, uuid)
                end
                -- Cek dinamis: stop hanya kalau uuid valid DAN sudah terpasang
                if uuid and tostring(Data.Player:Get("EquippedId") or "") == uuid then
                    S.Quest.completeJob("Diamond", session)
                    break
                end
            end
            if not S.Quest.canNavigate("Diamond", session) then

                task.wait(0.4)
                continue
            end
            if S.Quest.owns("Diamond Key") then

                lastTeleport = nil
                local key = S.Quest.findByName("Diamond Key")
                S.Quest.openAndClaimDiamond("Diamond", session, key)
            elseif S.Quest.progress("Diamond Researcher", 2, 1) < 1 then

                if lastTeleport ~= "Coral Reefs"
                    or not S.Quest.isNear("Coral Reefs", 150)
                then
                    S.Quest.teleport("Coral Reefs", "Diamond", session)
                    lastTeleport = "Coral Reefs"
                end
            elseif S.Quest.progress("Diamond Researcher", 3, 1) < 1 then

                if lastTeleport ~= "Tropical Grove"
                    or not S.Quest.isNear("Tropical Grove", 150)
                then
                    S.Quest.teleport("Tropical Grove", "Diamond", session)
                    lastTeleport = "Tropical Grove"
                end
            elseif S.Quest.progress("Diamond Researcher", 4, 1) < 1 then

                local ruby = S.Quest.findFish(243, "Gemstone")
                if ruby then
                    lastTeleport = nil
                    S.Quest.exchangeItem("Diamond", session,
                        "Diamond Researcher", 4,
                        {"Diamond Researcher", 2, 1}, ruby,
                        function()
                            return S.Quest.approachDiamondResearcher(
                                "Diamond", session)
                        end)
                elseif lastTeleport ~= "Treasure Room"
                    or not S.Quest.isNear("Treasure Room", 150)
                then
                    S.Quest.teleport("Treasure Room", "Diamond", session)
                    lastTeleport = "Treasure Room"
                end
            elseif S.Quest.progress("Diamond Researcher", 5, 1) < 1 then

                local lochness = S.Quest.findFish(228)
                if lochness then
                    lastTeleport = nil
                    S.Quest.exchangeItem("Diamond", session,
                        "Diamond Researcher", 5,
                        {"Diamond Researcher", 2, 2}, lochness,
                        function()
                            return S.Quest.approachDiamondResearcher(
                                "Diamond", session)
                        end)
                elseif lastTeleport ~= "Kohana"
                    or not S.Quest.isNear("Kohana", 150)
                then
                    S.Quest.teleport("Kohana", "Diamond", session)
                    lastTeleport = "Kohana"
                end
            elseif S.Quest.progress("Diamond Researcher", 6, 1000) < 1000 then

                lastTeleport = nil
            else

            end
            task.wait(0.4)
        end

    end

    -- CRYSTALLINE: event-driven placement plus an Ancient Jungle fallback
    -- when it is the only active route.
    -- CrystallineBusy: guard double-attempt per fishName
    S.Quest.CrystallineBusy = {}

    Runtime.Quest.OnFishCaught = function(fishName, metadata)
        -- CRYSTALLINE: event-driven place pressure fish
        local crystallineSession = Runtime.Quest.Sessions.Crystalline
        if S.Quest.isActive("Crystalline", crystallineSession) then
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
                    S.Quest.CrystallineBusy[fishName] = crystallineSession
                    local bridgeToken = S.Quest.addHold(
                        "CrystallineCatch:" .. fishName,
                        "Crystalline", crystallineSession)
                    task.spawn(function()
                        if S.Quest.isActive("Crystalline", crystallineSession) then
                            -- FishCaught can arrive before Inventory replication.
                            -- Keep autosell/auto-equip paused until the exact
                            -- target appears, or release after a short bound.
                            S.Quest.waitJob("Crystalline", function()
                                return S.Quest.findPressureFish(fishName) ~= nil
                            end, 2, 0.05, crystallineSession)
                            pcall(function()
                                S.Quest.placePressureFishEntry(
                                    "Crystalline", crystallineSession, targetDef)
                            end)
                        end
                        if S.Quest.CrystallineBusy[fishName] == crystallineSession then
                            S.Quest.CrystallineBusy[fishName] = nil
                        end
                        S.Quest.removeHold(bridgeToken)
                        Runtime.Quest.RefreshPanels()
                    end)
                end
            end
        end

        -- DIAMOND: protect Ruby dan Lochness dari autosell
        -- Diamond loop jalan tiap 0.4s — SellHold+1 bridging gap antara
        -- FishCaught dan loop iteration berikutnya yang akan exchange via withSellHold
        local diamondSession = Runtime.Quest.Sessions.Diamond
        if S.Quest.isActive("Diamond", diamondSession) then
            local variant = type(metadata) == "table"
                and (metadata.Variant or metadata.VariantId) or nil
            local needProtect =
                (S.Quest.progress("Diamond Researcher", 4, 1) < 1
                    and fishName == "Ruby" and variant == "Gemstone")
                or (S.Quest.progress("Diamond Researcher", 5, 1) < 1
                    and fishName == "Lochness Monster")
            if needProtect then
                local bridgeToken = S.Quest.addHold(
                    "DiamondCatch", "Diamond", diamondSession)
                -- Selalu release setelah 2s — jendela bridge untuk Diamond loop 0.4s
                -- withSellHold dari loop exchange punya counter sendiri (+1/-1 net 0)
                -- Tanpa ini, SellHold stuck di 1 selamanya kalau Diamond masih ON
                task.delay(2, function()
                    S.Quest.removeHold(bridgeToken)
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

    S.Quest.Runners.Crystalline = function(session)
        local lastTeleport = nil
        while S.Quest.isActive("Crystalline", session) do
            local plates = S.Quest.get("RuinPressurePlates")
            if plates ~= nil then
                local allDone = true
                local placedOrAvailable = false
                for _, definition in ipairs(S.Quest.Pressure) do
                    if plates[definition.Name] ~= true then
                        allDone = false
                        local busy = S.Quest.CrystallineBusy[definition.Name]
                        local pressureEntry = S.Quest.findPressureFish(
                            definition.Name)
                        if busy or pressureEntry then
                            placedOrAvailable = true
                        end
                        if not busy and pressureEntry then
                            S.Quest.CrystallineBusy[definition.Name] = session
                            pcall(function()
                                S.Quest.placePressureFishEntry(
                                    "Crystalline", session, definition)
                            end)
                            if S.Quest.CrystallineBusy[definition.Name] == session then
                                S.Quest.CrystallineBusy[definition.Name] = nil
                            end
                            Runtime.Quest.RefreshPanels()
                            break
                        end
                    end
                end
                if allDone then
                    S.Quest.completeJob("Crystalline", session)
                    break
                end
                -- Alone: first consume any matching inventory fish above.
                -- If none exists, fish at Ancient Jungle; it can produce all
                -- four pressure targets, including Sacred Guardian Squid.
                if not placedOrAvailable
                    and S.Quest.canCrystallineNavigate(session)
                    and (lastTeleport ~= "Ancient Jungle"
                        or not S.Quest.isNear("Ancient Jungle", 150))
                then
                    S.Quest.teleport("Ancient Jungle", "Crystalline", session)
                    lastTeleport = "Ancient Jungle"
                end
            end
            task.wait(0.5)
        end
    end

    Runtime.Quest.Start = function(job)
        if Runtime.Quest.Enabled[job] == true then return true end
        Runtime.Quest.Sessions[job] = (Runtime.Quest.Sessions[job] or 0) + 1
        local session = Runtime.Quest.Sessions[job]
        Runtime.Quest.Enabled[job] = true
        Runtime.Quest.Failures[job] = 0
        Runtime.Quest.CompletionNotified[job] = nil
        Runtime.Quest.RouteRetry[job] = nil
        startPanelLoop()
        if S.Quest.jobComplete(job) then
            S.Quest.completeJob(job, session)
            return true
        end
        if job == "Diamond" and not S.Quest.getMainline("Diamond Researcher") then
            Runtime.Quest.Visit = {Job=job, Session=session, Until=os.clock()+15}
        end
        local runner = S.Quest.Runners[job]
        if runner then S.Quest.startJobThread(job, runner, session) end
        local issue = S.Quest.getStartIssue(job)
        if issue then
            UI.Library:Notify({
                Title="Orvion", Subtitle="Hub",
                Content=tostring(job).." Quest ON - waiting: "..issue,
                Color=Color3.fromRGB(255,170,80), Delay=4,
            })
        end
        return true
    end

    Runtime.Quest.Stop = function(job)
        if Runtime.Quest.Enabled[job] ~= true then return false end
        local endedSession = Runtime.Quest.Sessions[job]
        Runtime.Quest.Enabled[job] = false
        Runtime.Quest.RouteRetry[job] = nil
        if Runtime.Quest.Visit and Runtime.Quest.Visit.Job == job then Runtime.Quest.Visit = nil end
        Runtime.Quest.Sessions[job] = (endedSession or 0) + 1

        S.Quest.scheduleSessionCleanup(job, endedSession)
        return true
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
            table.insert(lines, definition.Type .. ": "
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
        if state == true then
            Runtime.Quest.Start(job)
        else
            Runtime.Quest.Stop(job)
        end
    end

    S.Quest.fallback = function(key, destination)
        Runtime.Quest.FallbackSerial = (Runtime.Quest.FallbackSerial or 0) + 1
        local serial = Runtime.Quest.FallbackSerial
        task.spawn(function()
            local deadline = os.clock() + 12
            while Runtime.Quest.Action.Busy or Runtime.isTrading() do
                if serial ~= Runtime.Quest.FallbackSerial or os.clock() >= deadline then return end
                task.wait(0.1)
            end
            if serial ~= Runtime.Quest.FallbackSerial then return end
            Runtime.Quest.FallbackUntil = os.clock() + 5
            Runtime.Quest.LastLocation = nil
            if typeof(destination) == "CFrame" then
                local character = Service.LocalPlayer.Character
                local root = character and character:FindFirstChild("HumanoidRootPart")
                Navigation.tryMoveRoot(root, destination, true)
            else
                Navigation.teleportTo(destination, true)
            end
        end)
    end

    S.Quest.teleportNPC = function()
        local npcFolder = workspace:FindFirstChild("NPC")
        local npc = npcFolder and npcFolder:FindFirstChild("Diamond Researcher")
        local character = Service.LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not npc or not root then return end
        local target = npc:GetPivot() * CFrame.new(0, 0, 4)
        S.Quest.fallback("DiamondNPC", target)
    end


    -- Shop is created first; Trading is placed before Quest.

    -- ====== TRADING HELPERS ======

    -- Filter: item bisa ditrade (tidak locked, tidak favorited)
    local function getTradeInventory()
        local inventory = nil
        pcall(function() inventory = Data.Player:Get("Inventory") end)
        if type(inventory) == "table" then return inventory end
        local cached = Data.Player and Data.Player.Data
        return type(cached) == "table" and cached.Inventory or nil
    end

    local function canTradeItem(item)
        if not item.Metadata then return true end
        if item.Metadata.Favorited then return false end
        if item.Metadata.TradeLock then
            local tl = item.Metadata.TradeLock
            if type(tl) == "table" then
                if tl.Type == "Untradable" then return false end
                if tl.Type == "Timestamp" then
                    -- cek apakah masih locked
                    local now = pcall(workspace.GetServerTimeNow, workspace) and workspace:GetServerTimeNow() or os.time()
                    if tl.Time and tl.Time > now then return false end
                end
            else
                return false  -- TradeLock ada tapi bukan table = locked
            end
        end
        return true
    end

    -- Build grouped display list + internal UUID map
    -- Returns: displayList ({"Name x3"}), uuidMap ({["Name"]={uuid1,uuid2,...}})
    local function buildFishDisplayList(filterFn)
        local inventory = getTradeInventory()
        local nameCount, nameOrder, uuidMap = {}, {}, {}
        if type(inventory) ~= "table" then return {}, {} end
        for category, items in pairs(inventory) do
            if type(items) == "table" then
                for _, item in ipairs(items) do
                    if type(item) == "table" and item.Id and item.UUID then
                        local ok, itemData = pcall(Data.ItemUtility.GetItemDataFromItemType, category, item.Id)
                        if itemData and itemData.Data and itemData.Data.Type == "Fish" then
                            if not filterFn or filterFn(item, itemData) then
                                local name = itemData.Data.Name or tostring(item.Id)
                                local qty = tonumber(item.Quantity) or 1
                                if not nameCount[name] then
                                    nameCount[name] = 0
                                    uuidMap[name] = {}
                                    table.insert(nameOrder, name)
                                end
                                nameCount[name] = nameCount[name] + qty
                                table.insert(uuidMap[name], {
                                    UUID=item.UUID,
                                    ItemType=itemData.Data.Type,
                                    Quantity=qty,
                                })
                            end
                        end
                    end
                end
            end
        end
        table.sort(nameOrder)
        local displayList = {}
        for _, name in ipairs(nameOrder) do
            table.insert(displayList, "x" .. nameCount[name] .. " " .. name)
        end
        return displayList, uuidMap
    end

    local function buildStoneDisplayList()
        local inventory = getTradeInventory()
        local stoneCount, stoneOrder, uuidMap = {}, {}, {}
        if type(inventory) ~= "table" then return {}, {} end
        for category, items in pairs(inventory) do
            if type(items) == "table" then
                for _, item in ipairs(items) do
                    if type(item) == "table" and item.Id and item.UUID then
                        local ok, itemData = pcall(Data.ItemUtility.GetItemDataFromItemType, category, item.Id)
                        if itemData and itemData.Data then
                            local id = tonumber(item.Id)
                            local dataName = (itemData.Data.Name or ""):lower()
                            local isStone = (id == 929) or (id == 558) or dataName:find("enchant stone", 1, true)
                            if isStone then
                                local name = itemData.Data.Name or tostring(item.Id)
                                local qty = tonumber(item.Quantity) or 1
                                if not stoneCount[name] then
                                    stoneCount[name] = 0
                                    uuidMap[name] = {}
                                    table.insert(stoneOrder, name)
                                end
                                stoneCount[name] = stoneCount[name] + qty
                                -- UUID terpisah: tiap entry 1 addItem
                                -- UUID sama (stacked): 1 entry = 1 addItem (trade 1 stack)
                                table.insert(uuidMap[name], {
                                    UUID=item.UUID,
                                    ItemType=itemData.Data.Type,
                                    Quantity=qty,
                                })
                            end
                        end
                    end
                end
            end
        end
        table.sort(stoneOrder)
        local displayList = {}
        for _, name in ipairs(stoneOrder) do
            table.insert(displayList, "x" .. stoneCount[name] .. " " .. name)
        end
        return displayList, uuidMap
    end

    -- Get items by rarity tier
    local RARITY_TIER_MAP = {
        Common=1, Uncommon=2, Rare=3, Epic=4,
        Legendary=5, Mythic=6, Secret=7, Forgotten=8
    }
    local function getItemsByRarity(rarityLabel)
        local targetTier = RARITY_TIER_MAP[rarityLabel]
        if not targetTier then return {} end
        local inventory = getTradeInventory()
        local result = {}
        if type(inventory) ~= "table" then return result end
        for category, items in pairs(inventory) do
            if type(items) == "table" then
                for _, item in ipairs(items) do
                    if type(item) == "table" and item.Id and item.UUID and canTradeItem(item) then
                        local ok, itemData = pcall(Data.ItemUtility.GetItemDataFromItemType, category, item.Id)
                        if itemData and itemData.Data and itemData.Data.Type == "Fish" then
                            if Data.getFishTier(item, itemData) == targetTier then
                                table.insert(result, {
                                    UUID=item.UUID,
                                    ItemType=itemData.Data.Type,
                                })
                            end
                        end
                    end
                end
            end
        end
        return result
    end

    -- Prefer the most valuable fish that is still relevant to the requested
    -- value.  Only when every fish exceeds the target do we use the smallest
    -- possible overshoot.  This prevents a 5M T8 fish being chosen for 10k.
    local function getItemsByCoins(targetCoins)
        local inventory = getTradeInventory()
        local allFish = {}
        if type(inventory) ~= "table" then return {} end
        for category, items in pairs(inventory) do
            if type(items) == "table" then
                for _, item in ipairs(items) do
                    if type(item) == "table" and item.Id and item.UUID and canTradeItem(item) then
                        local ok, itemData = pcall(Data.ItemUtility.GetItemDataFromItemType, category, item.Id)
                        if itemData and itemData.Data and itemData.Data.Type == "Fish" then
                            table.insert(allFish, {
                                UUID = item.UUID,
                                ItemType = itemData.Data.Type,
                                SellPrice = itemData.SellPrice or 0,
                            })
                        end
                    end
                end
            end
        end
        targetCoins = math.max(1, tonumber(targetCoins) or 1)
        table.sort(allFish, function(a, b) return a.SellPrice > b.SellPrice end)
        local result, total = {}, 0
        -- Main path: high value first, but never begin with an item whose
        -- individual price already dwarfs the target.
        for _, f in ipairs(allFish) do
            if f.SellPrice <= targetCoins then
                table.insert(result, {UUID=f.UUID, ItemType=f.ItemType})
                total = total + f.SellPrice
                if total >= targetCoins then return result end
            end
        end
        -- No combination of relevant values can reach target. Add exactly one
        -- smallest over-target fish, never the first/most expensive one.
        local smallestOvershoot = nil
        for _, f in ipairs(allFish) do
            if f.SellPrice > targetCoins
                and (not smallestOvershoot or f.SellPrice < smallestOvershoot.SellPrice)
            then
                smallestOvershoot = f
            end
        end
        if smallestOvershoot then
            table.insert(result, {
                UUID=smallestOvershoot.UUID,
                ItemType=smallestOvershoot.ItemType,
            })
        end
        return result
    end

    -- ====== TRADE SESSION HANDLER ======
    -- The server owns lock/ready/confirm state.  We react to its Replion
    -- changes once; no timed Ready/Confirm spam is used.
    local S_Trade = {
        AddingSessionId = nil,
        BlockedSessionId = nil,
        ActiveSession = nil,
        ActiveSessionId = nil,
        ActiveOtherUserId = nil,
        ActiveOwnerToken = nil,
        Managed = false,
        PendingOutgoing = nil,
        RequestReady = nil,
        LastActivityAt = nil,
        Serial = 0,
        Generation = TradeLifecycleGeneration,
    }

    local function runTradeSession(tradeReplion, sessionId, managed, owner)
        local sessionGeneration = S_Trade.Generation
        if not Remote.TradeGenerationAlive(sessionGeneration)
            or not tradeReplion or tradeReplion.Destroyed then return end
        if S_Trade.ActiveSession == tradeReplion then
            S_Trade.Managed = S_Trade.Managed or managed == true
            return
        end

        S_Trade.Serial = S_Trade.Serial + 1
        local serial = S_Trade.Serial
        local LP = Service.LocalPlayer
        local myId = tostring(LP.UserId)
        -- AddItem milik lawan tidak pernah dibaca dari remote client lawan.
        -- Server menulis hasil validasinya ke Replion bersama, tepat di
        -- Players.<otherUserId>.Items.  Cabang itu adalah sumber kebenaran
        -- untuk receiver.
        local otherId = nil
        for _, player in ipairs(tradeReplion.Data.PlayerList or {}) do
            if player ~= LP and player and player.UserId then
                otherId = tostring(player.UserId)
                break
            end
        end
        if not otherId then
            for playerId in pairs(tradeReplion.Data.Players or {}) do
                if tostring(playerId) ~= myId then
                    otherId = tostring(playerId)
                    break
                end
            end
        end

        local sessionKey = tostring(sessionId)
        if type(owner) == "table" then
            if (owner.SessionId and tostring(owner.SessionId) ~= sessionKey)
                or tostring(owner.TargetUserId or "") ~= tostring(otherId or "")
            then
                managed = false
                owner = nil
            elseif owner.RunSerial ~= S.Trading.RunSerial
                or S.Trading.ActiveMode ~= owner.StateKey
                or S.Trading[owner.StateKey] ~= true
            then
                owner.Cancelled = true
            end
        end

        local ended = false
        local otherOfferRevision = 0
        local otherOfferChangedAt = os.clock()
        local otherOfferItemCount = 0
        local readyForKey = nil
        local readyRun = 0
        local confirmLoopKey = nil
        local connections = {}

        S_Trade.ActiveSession = tradeReplion
        S_Trade.ActiveSessionId = sessionKey
        S_Trade.ActiveOtherUserId = otherId
        S_Trade.ActiveOwnerToken = owner and owner.Token or nil
        S_Trade.BlockedSessionId = owner and owner.Cancelled
            and sessionKey or nil
        S_Trade.Managed = managed == true
        S_Trade.LastActivityAt = os.clock()

        local function alive()
            return Remote.TradeGenerationAlive(sessionGeneration)
                and not ended and S_Trade.Serial == serial
                and S_Trade.ActiveSession == tradeReplion
                and not tradeReplion.Destroyed
                and LP:GetAttribute("IsTrading") == true
        end

        local function markActivity()
            if S_Trade.Serial == serial and S_Trade.ActiveSession == tradeReplion then
                S_Trade.LastActivityAt = os.clock()
            end
        end

        local function readOtherOffer()
            if not otherId then return 0 end
            local offer = tradeReplion:Get("Players." .. otherId .. ".Items") or {}
            local count = 0
            for _, categoryItems in pairs(offer) do
                if type(categoryItems) == "table" then
                    for _ in pairs(categoryItems) do
                        count = count + 1
                    end
                end
            end
            return count
        end

        local function otherOfferIsQuiet()
            return os.clock() - otherOfferChangedAt >= 5
        end


        local function sessionIsAdding()
            return S_Trade.AddingSessionId == sessionKey
        end

        local scheduleReady
        local function confirmIfReady()
            if not alive() or not S_Trade.Managed
                or sessionIsAdding()
                or S_Trade.BlockedSessionId == sessionKey
                or tradeReplion.Data.PlayersReady ~= true
            then return end
            local modified = tonumber(tradeReplion.Data.LastModifiedTime) or 0
            local confirmRevision = otherOfferRevision
            local key = tostring(modified) .. ":" .. tostring(confirmRevision)
            if confirmLoopKey == key then return end
            -- Jangan confirm ketika item offer lawan baru saja direplikasi.
            -- Bila kedua Ready sementara offer masih berubah, tunggu sampai
            -- jendela tenang yang sama dengan server selesai.
            if not otherOfferIsQuiet() then
                readyForKey = nil
                scheduleReady()
                return
            end
            confirmLoopKey = key
            task.spawn(function()
                -- Confirm has no separate client acknowledgment. Retry only
                -- while this exact final offer remains ready and unchanged;
                -- TradeCompleted/IsTrading=false terminates the loop.
                while alive() and S_Trade.Managed
                    and not sessionIsAdding()
                    and S_Trade.BlockedSessionId ~= sessionKey
                    and tradeReplion.Data.PlayersReady == true
                    and (tonumber(tradeReplion.Data.LastModifiedTime) or 0)
                        == modified
                    and otherOfferRevision == confirmRevision
                    and otherOfferIsQuiet()
                    and confirmLoopKey == key
                do
                    Runtime.callRemote("tradeConfirm", 6, function() return alive() and S_Trade.Managed end)
                    task.wait(0.35)
                end
                if confirmLoopKey == key then confirmLoopKey = nil end
            end)
        end

        scheduleReady = function()
            if not alive() or not S_Trade.Managed or sessionIsAdding()
                or S_Trade.BlockedSessionId == sessionKey
            then return end
            local modified = tonumber(tradeReplion.Data.LastModifiedTime) or 0
            local offerRevision = otherOfferRevision
            local key = tostring(modified) .. ":" .. tostring(offerRevision)
            if readyForKey == key then return end
            readyForKey = key
            readyRun = readyRun + 1
            local readyTicket = readyRun
            task.spawn(function()
                while alive() and sessionIsAdding() do task.wait(0.05) end
                if not alive() then return end
                if S_Trade.BlockedSessionId == sessionKey then return end
                if (tonumber(tradeReplion.Data.LastModifiedTime) or 0) ~= modified then return end
                -- Kedua syarat wajib terpenuhi: lock server selesai dan
                -- cabang Items milik pihak lawan tidak lagi berubah.
                local serverDelay = modified + 5 - workspace:GetServerTimeNow()
                local offerDelay = 5 - (os.clock() - otherOfferChangedAt)
                local delay = math.max(serverDelay, offerDelay, 0)
                if delay > 0 then task.wait(delay + 0.1) end
                if not alive() or not S_Trade.Managed or readyTicket ~= readyRun or sessionIsAdding()
                    or S_Trade.BlockedSessionId == sessionKey
                then return end
                if (tonumber(tradeReplion.Data.LastModifiedTime) or 0) ~= modified then return end
                if otherOfferRevision ~= offerRevision or not otherOfferIsQuiet() then return end
                local mine = tradeReplion.Data.Players and tradeReplion.Data.Players[myId]
                if mine and mine.IsReady then
                    confirmIfReady()
                else
                    -- Retry SetReady until the local Replion branch acknowledges
                    -- IsReady=true, but stop immediately if this offer changes.
                    while alive() and S_Trade.Managed and readyTicket == readyRun
                        and not sessionIsAdding()
                        and S_Trade.BlockedSessionId ~= sessionKey
                        and (tonumber(tradeReplion.Data.LastModifiedTime) or 0)
                            == modified
                        and otherOfferRevision == offerRevision
                        and otherOfferIsQuiet()
                    do
                        mine = tradeReplion.Data.Players
                            and tradeReplion.Data.Players[myId]
                        if mine and mine.IsReady then break end
                        Runtime.callRemote("tradeSetReady", 6, function() return alive() and S_Trade.Managed end, true)
                        task.wait(0.35)
                    end
                    mine = tradeReplion.Data.Players
                        and tradeReplion.Data.Players[myId]
                    if mine and mine.IsReady then confirmIfReady() end
                end
            end)
        end

        local connLastModified = tradeReplion:OnChange("LastModifiedTime", function()
            markActivity()
            readyForKey = nil
            confirmLoopKey = nil
            scheduleReady()
        end)
        table.insert(connections, Remote.TrackTradeConnection(connLastModified))
        local connMyReady = tradeReplion:OnChange("Players." .. myId .. ".IsReady", function(isReady)
            markActivity()
            if isReady then
                confirmIfReady()
            else
                readyForKey = nil
                scheduleReady()
            end
        end)
        table.insert(connections, Remote.TrackTradeConnection(connMyReady))
        local connPlayersReady = tradeReplion:OnChange("PlayersReady", function(isReady)
            markActivity()
            if isReady then confirmIfReady() end
        end)
        table.insert(connections, Remote.TrackTradeConnection(connPlayersReady))
        if otherId then
            otherOfferItemCount = readOtherOffer()
            local connOtherItems = tradeReplion:OnDescendantChange(
                "Players." .. otherId .. ".Items",
                function()
                    -- AddItem/RemoveItem lawan telah diakui server dan
                    -- direplikasi ke client ini.
                    otherOfferItemCount = readOtherOffer()
                    otherOfferRevision = otherOfferRevision + 1
                    otherOfferChangedAt = os.clock()
                    markActivity()
                    readyForKey = nil
                    confirmLoopKey = nil
                    scheduleReady()
                end
            )
            table.insert(connections, Remote.TrackTradeConnection(connOtherItems))
        end
        local function finishSession(eventSession)
            if eventSession ~= nil and type(eventSession) ~= "boolean"
                and tostring(eventSession) ~= sessionKey then return end
            ended = true
            readyForKey, confirmLoopKey = nil, nil
            if S_Trade.Serial == serial then S_Trade.Managed = false end
            if Runtime.Trade.SessionId == sessionKey then Runtime.Trade.SessionId = nil end
            SupportState.recheckAutoEquipRod(0.2)
        end
        for _, event in ipairs({Remote.tradeCompleted, Remote.tradeEnded}) do
            if event then
                table.insert(connections, Remote.TrackTradeConnection(
                    event.OnClientEvent:Connect(finishSession)))
            end
        end
        S_Trade.RequestReady = function()
            readyForKey = nil
            scheduleReady()
        end
        if owner and owner.Cancelled then
            task.defer(function()
                if alive() and S_Trade.ActiveOwnerToken == owner.Token then
                    Runtime.callRemote("tradeCancel", 5, nil)
                end
            end)
        else
            task.defer(scheduleReady)
        end

        task.spawn(function()
            while alive() do
                -- A sender can legitimately add twenty items slowly.  Only
                -- 45s without *any* authoritative Replion activity is stuck.
                local lastActivity = S_Trade.LastActivityAt or os.clock()
                if S_Trade.Managed and os.clock() - lastActivity >= 45 then
                    Runtime.callRemote("tradeCancel", 5, nil)
                    break
                end
                task.wait(0.25)
            end
            for _, connection in ipairs(connections) do
                Remote.UntrackTradeConnection(connection)
                pcall(function() connection:Disconnect() end)
            end
            if S_Trade.Serial == serial then
                if Runtime.Trade.SessionId == sessionKey then Runtime.Trade.SessionId = nil end
                SupportState.recheckAutoEquipRod(0.2)
                S_Trade.ActiveSession = nil
                S_Trade.ActiveSessionId = nil
                S_Trade.ActiveOtherUserId = nil
                S_Trade.ActiveOwnerToken = nil
                S_Trade.Managed = false
                if S_Trade.AddingSessionId == sessionKey then
                    S_Trade.AddingSessionId = nil
                end
                if S_Trade.BlockedSessionId == sessionKey then
                    S_Trade.BlockedSessionId = nil
                end
                S_Trade.RequestReady = nil
                S_Trade.LastActivityAt = nil
            end
        end)
    end

    -- ====== TRADE LOOP ======
    -- opts: { getItemsFn, statusPara, stateRunningKey, targetAmount, targetPlayer }
    local function setStatus(para, txt)
        S.setParagraphText(para, txt)
    end

    -- R26: Trade toggles are USER-OWNED. Runtime/validation/completion must never
    -- call Set(true/false) or rewrite a toggle state behind the user's back.
    -- S.Trading.*_Running reflects only the last UI callback from the user.
    -- Worker termination is tracked locally inside runTradeLoop instead.

    local function runTradeLoop(opts)
        local getItemsFn      = opts.getItemsFn
        local statusPara      = opts.statusPara
        local stateKey        = opts.stateRunningKey
        local targetAmount    = tonumber(opts.targetAmount) or 1
        local targetPlayer    = opts.targetPlayer
        local toggleControl   = opts.toggleControl
        local LP              = Service.LocalPlayer
        local workerStopRequested = false

        -- R28: every terminal/invalid/error exit owns its own UI toggle.
        -- User can still turn it OFF manually at any time; runtime never forces ON.
        local function autoOffOwnToggle(reason)
            workerStopRequested = true
            S.Trading[stateKey] = false
            if toggleControl then
                pcall(function() toggleControl:Set(false) end)
            end
            return reason
        end

        for key, remoteName in pairs({
            tradeSendOffer="RF/Trading/SendTradeOffer",
            tradeAddItem="RF/Trading/AddItem",
            tradeSetReady="RF/Trading/SetReady",
            tradeConfirm="RF/Trading/ConfirmTrade",
            tradeCancel="RF/Trading/CancelTrade",
            tradeStarted="RE/Trading/TradeStarted",
            tradeEnded="RE/Trading/TradeEnded",
            tradeCompleted="RE/Trading/TradeCompleted",
        }) do
            if not Remote[key] then
                autoOffOwnToggle("REMOTE_UNAVAILABLE")
                setStatus(statusPara, remoteName .. " unavailable. Worker stopped.")
                return
            end
        end

        -- Satu worker outgoing per account: server hanya mengizinkan satu session.
        if S.Trading.ActiveMode ~= nil and S.Trading.ActiveMode ~= stateKey then
            autoOffOwnToggle("OTHER_WORKER_ACTIVE")
            UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="Another trade worker is active. This toggle was turned OFF.", Color=Color3.fromRGB(255,80,80), Delay=3 })
            return
        end
        S.Trading.ActiveMode = stateKey
        S.Trading.RunSerial = (S.Trading.RunSerial or 0) + 1
        local runSerial = S.Trading.RunSerial
        local runGeneration = S_Trade.Generation

        local function stopOwnWorker(reason)
            if S.Trading.RunSerial == runSerial and S.Trading.ActiveMode == stateKey then
                autoOffOwnToggle(reason or "WORKER_STOPPED")
                return true
            end
            workerStopRequested = true
            return false
        end

        local function terminalAutoOff(reason)
            return stopOwnWorker(reason)
        end

        local function runActive()
            return not workerStopRequested
                and Remote.TradeGenerationAlive(runGeneration)
                and S.Trading.RunSerial == runSerial
                and S.Trading.ActiveMode == stateKey
                and S.Trading[stateKey] == true
        end

        -- A declined/cancelled offer never changes inventory.  Therefore
        -- create a fresh candidate snapshot immediately before *every* new offer.
        -- Do NOT permanently blacklist a successful UUID: stacked enchant stones
        -- keep the same UUID while Quantity decreases and the game only allows
        -- one unit of that UUID per trade. Receipt verification below already
        -- guarantees that the inventory decreased before this UUID can be planned
        -- again for the next trade.

        -- Read the authoritative local inventory once per check.  Besides
        -- being much lighter on a 4k+ inventory, Quantity makes the receipt
        -- check correct for a stacked stone whose UUID remains after one unit
        -- has been transferred.
        local function readOwnedQuantities()
            local quantities = {}
            local inventory = getTradeInventory()
            for _, items in pairs(inventory or {}) do
                if type(items) == "table" then
                    for _, item in ipairs(items) do
                        if type(item) == "table" and item.UUID then
                            local uuid = tostring(item.UUID)
                            local quantity = tonumber(item.Quantity) or 1
                            quantities[uuid] = (quantities[uuid] or 0) + math.max(quantity, 1)
                        end
                    end
                end
            end
            return quantities
        end

        -- Ready is allowed only after the local branch of the exact trade
        -- Replion contains every UUID planned for this batch.
        local function ownOfferContainsBatch(tradeReplion, batch)
            if not tradeReplion or tradeReplion.Destroyed then return false end
            local wanted, found = {}, {}
            for _, entry in ipairs(batch) do wanted[tostring(entry.UUID)] = true end
            local offer = tradeReplion:Get(
                "Players." .. tostring(LP.UserId) .. ".Items") or {}
            local function scan(node, depth)
                if type(node) ~= "table" or depth > 3 then return end
                for key, value in pairs(node) do
                    if wanted[tostring(key)] then found[tostring(key)] = true end
                    if type(value) == "table" then
                        local uuid = value.UUID or value.Uuid or value.Id
                        if uuid and wanted[tostring(uuid)] then
                            found[tostring(uuid)] = true
                        end
                        scan(value, depth + 1)
                    end
                end
            end
            scan(offer, 1)
            for uuid in pairs(wanted) do
                if not found[uuid] then return false end
            end
            return true
        end

        local function pendingPlanItems()
            local result = {}
            local owned = readOwnedQuantities()
            local seen = {}
            for _, entry in ipairs(getItemsFn() or {}) do
                local uuid = entry and entry.UUID and tostring(entry.UUID)
                if uuid and not seen[uuid]
                    and (owned[uuid] or 0) > 0
                then
                    seen[uuid] = true
                    table.insert(result, {UUID=entry.UUID, ItemType=entry.ItemType})
                end
            end
            return result
        end

        local totalSent, retryCount, success, failed = 0, 0, 0, 0
        local currentOwnerToken = nil

        setStatus(statusPara, "Retry: 0 | Success: 0 | Failed: 0 | Sent: 0")

        task.spawn(function()
            local gate = nil
            while runActive() and not gate do
                gate = Runtime.beginTradeGate()
                if not gate then task.wait(0.05) end
            end
            if not gate then
                -- runActive() became false before this worker acquired the gate.
                -- Release only our own mode lock; otherwise a dead pre-gate worker
                -- can block every other outgoing trade mode indefinitely.
                if S.Trading.RunSerial == runSerial
                    and S.Trading.ActiveMode == stateKey
                then
                    S.Trading.ActiveMode = nil
                end
                return
            end
            local batchConnections = {}
            local workerOk, workerErr = pcall(function()
            if not Runtime.waitTradeSafe(runActive) then
                stopOwnWorker("SAFEPOINT_TIMEOUT")
                setStatus(statusPara, "Waiting for item/fishing action timed out. Stopped.")
                return
            end
            while runActive() and totalSent < targetAmount do
                local target = game:GetService("Players"):FindFirstChild(targetPlayer)
                if not target then
                    stopOwnWorker("PLAYER_LEFT")
                    setStatus(statusPara, "Player not found. Stopped.")
                    break
                end

                -- Wait kalau sedang trading
                local waitClear = 0
                while (LP:GetAttribute("IsTrading") == true or target:GetAttribute("IsTrading") == true)
                    and waitClear < 10 and S.Trading[stateKey] == true
                do
                    task.wait(0.5)
                    waitClear = waitClear + 0.5
                end
                if not runActive() then break end
                if LP:GetAttribute("IsTrading") == true
                    or target:GetAttribute("IsTrading") == true
                then
                    setStatus(statusPara,
                        "Waiting for previous trade session cleanup...")
                    task.wait(1)
                    continue
                end

                local items = pendingPlanItems()
                if #items == 0 then
                    terminalAutoOff("INVENTORY_EXHAUSTED")
                    setStatus(statusPara, "Done -- Inventory empty. Sent: " .. totalSent)
                    break
                end

                local amountNeeded = targetAmount - totalSent
                local batchSize = math.min(20, amountNeeded, #items)
                local batch = {}
                local seenUUIDs = {}  -- dedup: cegah UUID sama 2x dalam 1 trade
                local addedBatch = 0
                for i = 1, #items do
                    if addedBatch >= batchSize then break end
                    local entry = items[i]
                    if not seenUUIDs[entry.UUID] then
                        seenUUIDs[entry.UUID] = true
                        table.insert(batch, entry)
                        addedBatch = addedBatch + 1
                    end
                end

                retryCount = retryCount + 1
                setStatus(statusPara, "Retry: " .. retryCount .. " | Success: " .. success .. " | Failed: " .. failed .. " | Sent: " .. totalSent)

                local batchOwner = {
                    Token = tostring(runSerial) .. ":" .. tostring(retryCount),
                    RunSerial = runSerial,
                    StateKey = stateKey,
                    TargetUserId = tostring(target.UserId),
                    SessionId = nil,
                }
                currentOwnerToken = batchOwner.Token
                local function clearPendingOwner()
                    if S_Trade.PendingOutgoing == batchOwner then
                        S_Trade.PendingOutgoing = nil
                    end
                end
                local function eventBelongsToBatch(eventSession)
                    if not batchOwner.SessionId then return false end
                    return eventSession == nil or type(eventSession) == "boolean"
                        or tostring(eventSession) == tostring(batchOwner.SessionId)
                end

                -- Subscribe before SendTradeOffer. TradeStarted can arrive in the
                -- same frame as the RemoteFunction returns.
                local tradeStarted, tradeFinished, isSuccess = false, false, false
                local startConn, endConn, compConn
                if Remote.tradeStarted then
                    startConn = Remote.tradeStarted.OnClientEvent:Connect(function(sessionId)
                        local incomingSession = tostring(sessionId)
                        if runActive() and (not batchOwner.SessionId
                            or tostring(batchOwner.SessionId) == incomingSession)
                        then
                            batchOwner.SessionId = incomingSession
                            tradeStarted = true
                        end
                    end)
                end
                if Remote.tradeEnded then
                    endConn = Remote.tradeEnded.OnClientEvent:Connect(function(sessionId)
                        if eventBelongsToBatch(sessionId) then
                            tradeFinished = true
                        end
                    end)
                end
                if Remote.tradeCompleted then
                    compConn = Remote.tradeCompleted.OnClientEvent:Connect(function(sessionId)
                        if eventBelongsToBatch(sessionId) then
                            tradeFinished = true
                            isSuccess = true
                        end
                    end)
                end

                batchConnections = {startConn, endConn, compConn}
                S_Trade.PendingOutgoing = batchOwner
                local ok, sendResult = Runtime.callRemote("tradeSendOffer", 10, runActive, target)
                if not ok then
                    clearPendingOwner()
                    if startConn then pcall(function() startConn:Disconnect() end) end
                    if endConn then pcall(function() endConn:Disconnect() end) end
                    if compConn then pcall(function() compConn:Disconnect() end) end
                    failed = failed + 1
                    stopOwnWorker("REMOTE_ERROR")
                    setStatus(statusPara, "SendTradeOffer error. Worker stopped.")
                elseif sendResult == false then
                    clearPendingOwner()
                    if startConn then pcall(function() startConn:Disconnect() end) end
                    if endConn then pcall(function() endConn:Disconnect() end) end
                    if compConn then pcall(function() compConn:Disconnect() end) end
                    failed = failed + 1
                    setStatus(statusPara, "Retry: " .. retryCount .. " | Success: " .. success .. " | Failed: " .. failed .. " | Sent: " .. totalSent)
                    task.wait(2.5)
                else
                    -- Wait TradeStarted (max 15s)
                    local waited = 0
                    while not tradeStarted and waited < 15 and runActive() do
                        task.wait(0.5)
                        waited = waited + 0.5
                    end
                    if not tradeStarted then
                        clearPendingOwner()
                        if startConn then pcall(function() startConn:Disconnect() end) end
                        if endConn then pcall(function() endConn:Disconnect() end) end
                        if compConn then pcall(function() compConn:Disconnect() end) end
                        failed = failed + 1
                        stopOwnWorker("TRADE_START_TIMEOUT")
                        setStatus(statusPara, "TradeStarted timeout. Worker stopped.")
                    else
                        clearPendingOwner()
                        -- Let Replion/session handler initialize, not a fixed delay.
                        local function exactSessionReady()
                            return S_Trade.ActiveSession ~= nil
                                and tostring(S_Trade.ActiveSessionId)
                                    == tostring(batchOwner.SessionId)
                                and tostring(S_Trade.ActiveOtherUserId)
                                    == tostring(batchOwner.TargetUserId)
                                and S_Trade.ActiveOwnerToken == batchOwner.Token
                        end
                        local sessionWait = 0
                        while not exactSessionReady()
                            and LP:GetAttribute("IsTrading") == true
                            and sessionWait < 3
                        do
                            task.wait(0.05)
                            sessionWait = sessionWait + 0.05
                        end

                        if not exactSessionReady() then
                            -- A session with a different target/owner is never
                            -- cancelled or mutated by this outgoing worker.
                            if S_Trade.ActiveOwnerToken == batchOwner.Token then
                                Runtime.callRemote("tradeCancel", 5, nil)
                            end
                            failed = failed + 1
                            if startConn then pcall(function() startConn:Disconnect() end) end
                            if endConn then pcall(function() endConn:Disconnect() end) end
                            if compConn then pcall(function() compConn:Disconnect() end) end
                            stopOwnWorker("SESSION_INIT_TIMEOUT")
                            setStatus(statusPara, "Trade session init timeout. Worker stopped.")
                        else
                        -- Add items
                        -- Quantity before AddItem is the receipt baseline.
                        -- Fish usually disappear entirely; stacked stones may
                        -- keep their UUID but their Quantity must decrease.
                        local beforeBatchQuantities = readOwnedQuantities()
                        local sessionKey = tostring(batchOwner.SessionId)
                        S_Trade.AddingSessionId = sessionKey
                        local addedCount = 0
                        for _, itemData in ipairs(batch) do
                            if not runActive()
                                or LP:GetAttribute("IsTrading") ~= true
                                or not exactSessionReady()
                            then break end
                            local ok2, added = Runtime.callRemote("tradeAddItem", 6,
                                function() return runActive() and exactSessionReady() end,
                                itemData.ItemType, itemData.UUID)
                            if not ok2 then
                                stopOwnWorker("REMOTE_ERROR")
                                setStatus(statusPara, "AddItem remote error. Worker stopped.")
                                break
                            end
                            if added == true then addedCount = addedCount + 1 end
                            task.wait(math.random(1, 3) / 8)
                        end
                        local offerVerified = addedCount == #batch
                            and exactSessionReady() and runActive()
                        local offerDeadline = os.clock() + 5
                        while offerVerified
                            and not ownOfferContainsBatch(S_Trade.ActiveSession, batch)
                            and os.clock() < offerDeadline
                            and exactSessionReady() and runActive()
                        do
                            task.wait(0.05)
                        end
                        offerVerified = offerVerified and exactSessionReady()
                            and ownOfferContainsBatch(S_Trade.ActiveSession, batch)
                        if not offerVerified then
                            S_Trade.BlockedSessionId = sessionKey
                            if exactSessionReady() then
                                Runtime.callRemote("tradeCancel", 5, nil)
                            end
                        end
                        if S_Trade.AddingSessionId == sessionKey then
                            S_Trade.AddingSessionId = nil
                        end
                        if offerVerified and S_Trade.RequestReady then
                            S_Trade.RequestReady()
                        end

                        -- A whole trade may legitimately last longer than 45s
                        -- when the counterpart is selecting/adding items.  Only
                        -- 45 seconds with no server-replicated activity means
                        -- the session is stale.  This also avoids cancelling a
                        -- valid session just because the stock UI hitches while
                        -- it cleans up a large inventory after completion.
                        local lastObservedActivity = S_Trade.LastActivityAt or os.clock()
                        while not tradeFinished and LP:GetAttribute("IsTrading") == true
                            and runActive()
                        do
                            local activityAt = S_Trade.LastActivityAt
                            if type(activityAt) == "number" and activityAt > lastObservedActivity then
                                lastObservedActivity = activityAt
                            end
                            if os.clock() - lastObservedActivity >= 45 then break end
                            task.wait(0.25)
                        end
                        -- Cancel only when the owner turned this worker off or
                        -- the authoritative session has been silent for 45s.
                        local activityAt = S_Trade.LastActivityAt
                        if type(activityAt) == "number" and activityAt > lastObservedActivity then
                            lastObservedActivity = activityAt
                        end
                        local inactiveFor = os.clock() - lastObservedActivity
                        if not tradeFinished and LP:GetAttribute("IsTrading") == true then
                            if not runActive() or inactiveFor >= 45 then
                                Runtime.callRemote("tradeCancel", 5, nil)
                            end
                            task.wait(1)
                        end

                        -- Wait IsTrading fully cleared (server cleanup)
                        local cleanWait = 0
                        while LP:GetAttribute("IsTrading") == true and cleanWait < 10 do
                            task.wait(0.5)
                            cleanWait = cleanWait + 0.5
                        end

                        if isSuccess and runActive() then
                            -- A successful remote response is not yet a safe
                            -- count. Confirm that each planned UUID was removed
                            -- or its stack Quantity decreased before another
                            -- trade may be planned; otherwise stale Replion data
                            -- can leak a Crystal Crab into the next mode.
                            local receiptDeadline = os.clock() + 8
                            local confirmed = {}
                            repeat
                                local currentQuantities = readOwnedQuantities()
                                for _, itemData in ipairs(batch) do
                                    local uuid = tostring(itemData.UUID)
                                    if (currentQuantities[uuid] or 0) < (beforeBatchQuantities[uuid] or 0) then
                                        confirmed[uuid] = true
                                    end
                                end
                                local allConfirmed = true
                                for _, itemData in ipairs(batch) do
                                    if not confirmed[tostring(itemData.UUID)] then
                                        allConfirmed = false
                                        break
                                    end
                                end
                                if allConfirmed then break end
                                task.wait(0.05)
                            until os.clock() >= receiptDeadline or not runActive()

                            local confirmedCount = 0
                            for _ in pairs(confirmed) do
                                confirmedCount = confirmedCount + 1
                            end
                            if confirmedCount ~= #batch then
                                failed = failed + 1
                                stopOwnWorker("INVENTORY_SYNC_TIMEOUT")
                                setStatus(statusPara, "Inventory sync timeout. Trade stopped safely.")
                            else
                                success = success + 1
                                totalSent = totalSent + confirmedCount
                            end
                        else
                            failed = failed + 1
                        end
                        if startConn then pcall(function() startConn:Disconnect() end) end
                        if endConn then pcall(function() endConn:Disconnect() end) end
                        if compConn then pcall(function() compConn:Disconnect() end) end

                        setStatus(statusPara, "Retry: " .. retryCount .. " | Success: " .. success .. " | Failed: " .. failed .. " | Sent: " .. totalSent)
                        task.wait(3.5)
                        end
                    end
                end
            end

            if type(S_Trade.PendingOutgoing) == "table"
                and S_Trade.PendingOutgoing.RunSerial == runSerial
            then
                S_Trade.PendingOutgoing = nil
            end
            -- User turned the worker off while its outgoing session is open.
            if Remote.TradeGenerationAlive(runGeneration)
                and LP:GetAttribute("IsTrading") == true and S_Trade.Managed
                and currentOwnerToken ~= nil
                and S_Trade.ActiveOwnerToken == currentOwnerToken
                and S.Trading.RunSerial == runSerial
            then
                Runtime.callRemote("tradeCancel", 5, nil)
            end

            if runActive() and totalSent >= targetAmount then
                terminalAutoOff("TARGET_REACHED")
                UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="Trade done! Sent: " .. totalSent, Color=Color3.fromRGB(150,150,170), Delay=4 })
            end
            if S.Trading.RunSerial == runSerial then
                S.Trading.ActiveMode = nil  -- release mode lock
            end
            setStatus(statusPara, "Done -- Retry: " .. retryCount .. " | Success: " .. success .. " | Failed: " .. failed .. " | Sent: " .. totalSent)
            end)
            for _, connection in pairs(batchConnections) do pcall(function() connection:Disconnect() end) end
            if S_Trade.PendingOutgoing and S_Trade.PendingOutgoing.RunSerial == runSerial then
                S_Trade.PendingOutgoing = nil
            end
            Runtime.endTradeGate(gate)
            if S.Trading.RunSerial == runSerial then S.Trading.ActiveMode = nil end
            if not workerOk and S.Trading.RunSerial == runSerial then
                stopOwnWorker("WORKER_ERROR")
                Runtime.LastError = "Trade: " .. tostring(workerErr)
                setStatus(statusPara, "Trade stopped after an error; local gate released.")
            end
        end)
    end

    UI.TradingTab = UI.Window:CreateTab("Trading", "rbxassetid://114581487428395")

    -- ====== TRADING STATE ======
    S.Trading = {
        TargetPlayer    = "",
        ByName_Item     = "",
        ByName_Amount   = 1,
        ByName_Running  = false,
        ByRarity_Rarity = "Common",
        ByRarity_Amount = 1,
        ByRarity_Running = false,
        ByStone_Stone   = "",
        ByStone_Amount  = 1,
        ByStone_Running = false,
        ByCoins_Target  = 1000000,
        ByCoins_Running = false,
        -- ByCoins: no item selection, greedy all fish
        AutoAccept      = false,
        ActiveMode      = nil,  -- guard: hanya 1 mode boleh jalan
        RunSerial       = 0,    -- invalidates an older worker of the same mode
    }

    -- All global Trade listeners are generation-owned.  A re-execution
    -- disconnects them at bootstrap and delayed callbacks also self-invalidate.
    local globalTradeGeneration = S_Trade.Generation
    local function globalTradeAlive()
        return Remote.TradeGenerationAlive(globalTradeGeneration)
    end

    if Remote.tradeStarted then
        Remote.TrackTradeConnection(Remote.tradeStarted.OnClientEvent:Connect(function(sessionId)
            if not globalTradeAlive() then return end
            Runtime.Trade.SessionId = tostring(sessionId)
            -- TradeStarted closes the incoming-offer reservation.  IsTrading now
            -- owns the transaction barrier instead of the pre-accept gate.
            if Router.PendingAccept and Router.Generation == RouterGeneration then
                Router.PendingAccept = nil
            end
            local owner = S_Trade.PendingOutgoing
            if type(owner) == "table" then
                owner.SessionId = tostring(sessionId)
                if owner.RunSerial ~= S.Trading.RunSerial
                    or S.Trading.ActiveMode ~= owner.StateKey
                    or S.Trading[owner.StateKey] ~= true
                then
                    owner.Cancelled = true
                end
            end
            local managed = owner ~= nil or S.Trading.AutoAccept
            task.spawn(function()
                local replion = nil
                local elapsed = 0
                while globalTradeAlive() and not replion and elapsed < 3
                    and Runtime.Trade.SessionId == tostring(sessionId)
                do
                    pcall(function() replion = Data.Replion.Client:GetReplion(sessionId) end)
                    if not replion then task.wait(0.05) elapsed = elapsed + 0.05 end
                end
                if not globalTradeAlive() then return end
                if replion and Runtime.Trade.SessionId == tostring(sessionId) then
                    local deadline = os.clock() + 2
                    while globalTradeAlive()
                        and Service.LocalPlayer:GetAttribute("IsTrading") ~= true
                        and os.clock() < deadline
                        and Runtime.Trade.SessionId == tostring(sessionId)
                    do task.wait(0.05) end
                    if globalTradeAlive()
                        and Runtime.Trade.SessionId == tostring(sessionId)
                    then
                        runTradeSession(replion, sessionId, managed, owner)
                    end
                elseif Runtime.Trade.SessionId == tostring(sessionId)
                    and Service.LocalPlayer:GetAttribute("IsTrading") ~= true
                then Runtime.Trade.SessionId = nil end
            end)
        end))
    end

    -- Register terminal events even if the session Replion arrived too late.
    for _, event in ipairs({Remote.tradeCompleted, Remote.tradeEnded}) do
        if event then
            Remote.TrackTradeConnection(event.OnClientEvent:Connect(function(sessionId)
                if not globalTradeAlive() then return end
                local current = Runtime.Trade.SessionId
                if current and (sessionId == nil or type(sessionId) == "boolean"
                    or tostring(sessionId) == current)
                then
                    Runtime.Trade.SessionId = nil
                    SupportState.recheckAutoEquipRod(0.2)
                end
            end))
        end
    end

    -- A missing TradeEnded must not leave a local session gate forever.
    Remote.TrackTradeConnection(
        Service.LocalPlayer:GetAttributeChangedSignal("IsTrading"):Connect(function()
            if not globalTradeAlive() then return end
            if Service.LocalPlayer:GetAttribute("IsTrading") ~= true then
                local current = Runtime.Trade.SessionId
                task.delay(0.5, function()
                    if globalTradeAlive() and Runtime.Trade.SessionId == current
                        and Service.LocalPlayer:GetAttribute("IsTrading") ~= true
                    then
                        Runtime.Trade.SessionId = nil
                        SupportState.recheckAutoEquipRod()
                    end
                end)
            end
        end))

    -- ====== SELECT PLAYER ======
    local TradingPlayerSection = UI.Window:AddCollapsible(UI.TradingTab, "Select Player", false)

    local TradingPlayerDropdown = UI.Window:AddDropdown(
        TradingPlayerSection, "Select Player for Trade", "", {}, false, "Select Option",
        function(v) S.Trading.TargetPlayer = v end,
        "Dropdown_Trade_TargetPlayer")

    UI.Window:AddButton(TradingPlayerSection, "Refresh Player", "", "rbxassetid://16932740082",
        function()
            local list = {}
            for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
                if p ~= game:GetService("Players").LocalPlayer then
                    table.insert(list, p.Name)
                end
            end
            TradingPlayerDropdown:Refresh(list, nil)
            UI.Library:Notify({Title="Orvion", Subtitle="Hub", Content="Player list refreshed: " .. tostring(#list)})
        end)

    -- ====== TRADE BY NAME ======
    local ByNameSection = UI.Window:AddCollapsible(UI.TradingTab, "Trade by Name", false)

    local ByNameStatusPara = UI.Window:AddParagraph(ByNameSection, "Trade Status", "Waiting...")

    local ByNameDropdown = UI.Window:AddDropdown(
        ByNameSection, "Select Item", "", {}, false, "Select Option",
        function(v) S.Trading.ByName_Item = v end,
        "Dropdown_Trade_ByName_Item")

    UI.Window:AddInput(ByNameSection, "Set Amount", "", "1",
        function(v) S.Trading.ByName_Amount = tonumber(v) or 1 end,
        "Input_Trade_ByName_Amount")

    local ByNameUUIDMap = {}
    UI.Window:AddButton(ByNameSection, "Refresh Fish Name", "", "rbxassetid://16932740082",
        function()
            local displayList, uuidMap = buildFishDisplayList()
            ByNameUUIDMap = uuidMap
            ByNameDropdown:Refresh(displayList, nil)
            UI.Library:Notify({Title="Orvion", Subtitle="Hub", Content=#displayList > 0 and ("Fish list refreshed: " .. #displayList .. " types") or "No fish found"})
        end)

    local ByNameToggle
    ByNameToggle = UI.Window:AddToggle(ByNameSection, "Start Trade by Name", "", false,
        function(state)
            S.Trading.ByName_Running = state
            if state then
                if S.Trading.TargetPlayer == "" or S.Trading.TargetPlayer == "Select Option" then
                    S.Trading.ByName_Running = false
                    pcall(function() ByNameToggle:Set(false) end)
                    UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="Select a player first!", Color=Color3.fromRGB(255,80,80), Delay=3 })
                    return
                end
                if S.Trading.ByName_Item == "" or S.Trading.ByName_Item == "Select Option" then
                    S.Trading.ByName_Running = false
                    pcall(function() ByNameToggle:Set(false) end)
                    UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="Select an item first!", Color=Color3.fromRGB(255,80,80), Delay=3 })
                    return
                end
                local cleanName = (S.Trading.ByName_Item:match("^x%d+ (.+)$") or S.Trading.ByName_Item)
                runTradeLoop({
                    getItemsFn = function()
                        -- Re-scan inventory tiap batch — cegah stale UUID
                        -- canTradeItem filter di sini (display show all, trade skip locked/fav)
                        local _, freshMap = buildFishDisplayList(function(item, _)
                            return canTradeItem(item)
                        end)
                        return freshMap[cleanName] or {}
                    end,
                    statusPara      = ByNameStatusPara,
                    stateRunningKey = "ByName_Running",
                    targetAmount    = S.Trading.ByName_Amount,
                    targetPlayer    = S.Trading.TargetPlayer,
                    toggleControl   = ByNameToggle,
                })
            end
        end, "Toggle_Trade_ByName")

    -- ====== TRADE BY COINS ======
    local ByCoinsSection = UI.Window:AddCollapsible(UI.TradingTab, "Trade by Coins", false)

    local ByCoinsStatusPara = UI.Window:AddParagraph(ByCoinsSection, "Trade Status", "Waiting...")

    UI.Window:AddInput(ByCoinsSection, "Set Amount", "", "1",
        function(v) S.Trading.ByCoins_Target = tonumber(v) or 1000000 end,
        "Input_Trade_ByCoins_Target")

    -- No dropdown: By Coins selects fish greedily by value automatically

    local ByCoinsToggle
    ByCoinsToggle = UI.Window:AddToggle(ByCoinsSection, "Start Trade by Coins", "", false,
        function(state)
            S.Trading.ByCoins_Running = state
            if state then
                if S.Trading.TargetPlayer == "" or S.Trading.TargetPlayer == "Select Option" then
                    S.Trading.ByCoins_Running = false
                    pcall(function() ByCoinsToggle:Set(false) end)
                    UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="Select a player first!", Color=Color3.fromRGB(255,80,80), Delay=3 })
                    return
                end
                -- Greedy all tradable fish sampai melebihi target coins
                local byCoinsFullList = getItemsByCoins(S.Trading.ByCoins_Target)
                if #byCoinsFullList == 0 then
                    S.Trading.ByCoins_Running = false
                    pcall(function() ByCoinsToggle:Set(false) end)
                    UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="No tradable fish for target coins!", Color=Color3.fromRGB(255,80,80), Delay=3 })
                    return
                end
                -- Freeze the chosen UUID set, then revalidate it every trade.
                -- A failed trade must not advance a cursor and silently skip fish.
                local byCoinsPlan = {}
                for _, entry in ipairs(byCoinsFullList) do
                    byCoinsPlan[tostring(entry.UUID)] = entry.ItemType
                end
                runTradeLoop({
                    getItemsFn = function()
                        local live = {}
                        local inventory = getTradeInventory()
                        for category, items in pairs(inventory or {}) do
                            if type(items) == "table" then
                                for _, item in ipairs(items) do
                                    local itemType = byCoinsPlan[tostring(item.UUID)]
                                    if itemType and canTradeItem(item) then
                                        table.insert(live, {UUID=item.UUID, ItemType=itemType})
                                    end
                                end
                            end
                        end
                        return live
                    end,
                    statusPara      = ByCoinsStatusPara,
                    stateRunningKey = "ByCoins_Running",
                    targetAmount    = #byCoinsFullList,  -- stop setelah semua item terkirim
                    targetPlayer    = S.Trading.TargetPlayer,
                    toggleControl   = ByCoinsToggle,
                })
            end
        end, "Toggle_Trade_ByCoins")


    -- ====== TRADE BY RARITIES ======
    local ByRaritySection = UI.Window:AddCollapsible(UI.TradingTab, "Trade by Rarities", false)

    local ByRarityStatusPara = UI.Window:AddParagraph(ByRaritySection, "Trade Status", "Waiting...")

    UI.Window:AddDropdown(
        ByRaritySection, "Select Rarity", "",
        Catalog.RarityTiers,
        false, "Common",
        function(v) S.Trading.ByRarity_Rarity = v end,
        "Dropdown_Trade_ByRarity_Rarity")

    UI.Window:AddInput(ByRaritySection, "Set Amount", "", "1",
        function(v) S.Trading.ByRarity_Amount = tonumber(v) or 1 end,
        "Input_Trade_ByRarity_Amount")

    local ByRarityToggle
    ByRarityToggle = UI.Window:AddToggle(ByRaritySection, "Start Trade by Rarities", "", false,
        function(state)
            S.Trading.ByRarity_Running = state
            if state then
                if S.Trading.TargetPlayer == "" or S.Trading.TargetPlayer == "Select Option" then
                    S.Trading.ByRarity_Running = false
                    pcall(function() ByRarityToggle:Set(false) end)
                    UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="Select a player first!", Color=Color3.fromRGB(255,80,80), Delay=3 })
                    return
                end
                local selectedRarity = S.Trading.ByRarity_Rarity
                runTradeLoop({
                    getItemsFn = function()
                        return getItemsByRarity(selectedRarity)
                    end,
                    statusPara      = ByRarityStatusPara,
                    stateRunningKey = "ByRarity_Running",
                    targetAmount    = S.Trading.ByRarity_Amount,
                    targetPlayer    = S.Trading.TargetPlayer,
                    toggleControl   = ByRarityToggle,
                })
            end
        end, "Toggle_Trade_ByRarity")

    -- ====== TRADE ENCHANT STONE ======
    local ByStoneSection = UI.Window:AddCollapsible(UI.TradingTab, "Trade Enchant Stone", false)

    local ByStoneStatusPara = UI.Window:AddParagraph(ByStoneSection, "Trade Status", "Waiting...")

    local ByStoneDropdown = UI.Window:AddDropdown(
        ByStoneSection, "Select Stone", "", {}, false, "Select Option",
        function(v) S.Trading.ByStone_Stone = v end,
        "Dropdown_Trade_ByStone_Stone")

    UI.Window:AddInput(ByStoneSection, "Set Amount", "", "1",
        function(v) S.Trading.ByStone_Amount = tonumber(v) or 1 end,
        "Input_Trade_ByStone_Amount")

    local ByStoneUUIDMap = {}
    UI.Window:AddButton(ByStoneSection, "Check Enchant Stones", "", "rbxassetid://16932740082",
        function()
            local displayList, uuidMap = buildStoneDisplayList()
            ByStoneUUIDMap = uuidMap
            ByStoneDropdown:Refresh(displayList, nil)
            UI.Library:Notify({Title="Orvion", Subtitle="Hub", Content=#displayList > 0 and ("Enchant stones found: " .. #displayList .. " types") or "No enchant stones found"})
        end)

    local ByStoneToggle
    ByStoneToggle = UI.Window:AddToggle(ByStoneSection, "Start Trade by Enchant Stone", "", false,
        function(state)
            S.Trading.ByStone_Running = state
            if state then
                if S.Trading.TargetPlayer == "" or S.Trading.TargetPlayer == "Select Option" then
                    S.Trading.ByStone_Running = false
                    pcall(function() ByStoneToggle:Set(false) end)
                    UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="Select a player first!", Color=Color3.fromRGB(255,80,80), Delay=3 })
                    return
                end
                if S.Trading.ByStone_Stone == "" or S.Trading.ByStone_Stone == "Select Option" then
                    S.Trading.ByStone_Running = false
                    pcall(function() ByStoneToggle:Set(false) end)
                    UI.Library:Notify({ Title="Orvion", Subtitle="Hub", Description="", Content="Select a stone first!", Color=Color3.fromRGB(255,80,80), Delay=3 })
                    return
                end
                local cleanName = (S.Trading.ByStone_Stone:match("^x%d+ (.+)$") or S.Trading.ByStone_Stone)
                runTradeLoop({
                    getItemsFn = function()
                        -- Re-scan tiap batch, filter hanya yang bisa ditrade
                        local _, freshStoneMap = buildStoneDisplayList()
                        local allEntries = freshStoneMap[cleanName] or {}
                        local entries = {}
                        for _, e in ipairs(allEntries) do
                            -- cek canTradeItem dari inventory langsung
                            local inv = getTradeInventory() or {}
                            for _, items2 in pairs(inv) do
                                if type(items2) == "table" then
                                    for _, it in ipairs(items2) do
                                        if type(it) == "table" and it.UUID == e.UUID and canTradeItem(it) then
                                            table.insert(entries, e)
                                            break
                                        end
                                    end
                                end
                            end
                        end
                        -- Sort: single UUID (qty=1) first → bisa batch 20
                        -- Stacked (qty>1) last → 1 per trade, server reject duplicate UUID
                        local singles, stackeds = {}, {}
                        for _, e in ipairs(entries) do
                            if (e.Quantity or 1) == 1 then
                                table.insert(singles, e)
                            else
                                table.insert(stackeds, e)
                            end
                        end
                        local result = {}
                        for _, e in ipairs(singles) do table.insert(result, e) end
                        for _, e in ipairs(stackeds) do table.insert(result, e) end
                        return result
                    end,
                    statusPara      = ByStoneStatusPara,
                    stateRunningKey = "ByStone_Running",
                    targetAmount    = S.Trading.ByStone_Amount,
                    targetPlayer    = S.Trading.TargetPlayer,
                    toggleControl   = ByStoneToggle,
                })
            end
        end, "Toggle_Trade_ByStone")

    -- ====== AUTO ACCEPT TRADE ======
    local AutoAcceptSection = UI.Window:AddCollapsible(UI.TradingTab, "Auto Accept Trade", false)

    UI.Window:AddToggle(AutoAcceptSection, "Auto Accept & Confirm Trade", "", false,
        function(state)
            S.Trading.AutoAccept = state
            Remote.SetTradeOfferRouterEnabled(state == true)
            if state == true then
                if S_Trade.ActiveSession and S_Trade.ActiveOwnerToken == nil then
                    S_Trade.Managed = true
                    S_Trade.BlockedSessionId = nil
                    if S_Trade.RequestReady then S_Trade.RequestReady() end
                end
                -- Router refresh is serialized by SetTradeOfferRouterEnabled.
                -- No second autoload refresh worker is created here.
            elseif S_Trade.ActiveSession
                and S_Trade.ActiveOwnerToken == nil
                and S_Trade.Managed
            then
                -- Leave the live trade under manual control; OFF revokes retries.
                S_Trade.Managed = false
            end
        end, "Toggle_Trade_AutoAccept")

    -- Shop is created first; Quest is therefore placed immediately after it.
    UI.QuestTab = UI.Window:CreateTab("Quest", "rbxassetid://13436029894")

    S.Quest.Toggles = {}
    S.Quest.ArtifactSection = UI.Window:AddCollapsible(
        UI.QuestTab, "Artifact Lever Location", false)
    Runtime.Quest.Panels.Artifact = UI.Window:AddParagraph(
        S.Quest.ArtifactSection, "Panel Progress Artifact", "Loading...")
    S.Quest.Toggles.Artifact = UI.Window:AddToggle(
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
    S.Quest.Toggles.DeepSea = UI.Window:AddToggle(
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
    S.Quest.Toggles.Element = UI.Window:AddToggle(
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
    S.Quest.Toggles.Diamond = UI.Window:AddToggle(
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
    S.Quest.Toggles.Crystalline = UI.Window:AddToggle(
        S.Quest.CrystallineSection, "Auto Ancient Ruin", "", false,
        function(state) S.Quest.toggleCallback("Crystalline", state) end)

    -- Replion may publish Inventory and quest state in the same frame.  Batch
    -- the UI writes into one deferred refresh, never a panel polling delay.
    S.Quest.ReplionRefreshQueued = false
    S.Quest.queueReplionRefresh = function()
        if S.Quest.ReplionRefreshQueued then return end
        S.Quest.ReplionRefreshQueued = true
        task.defer(function()
            S.Quest.ReplionRefreshQueued = false
            S.Quest.refreshFromReplion()
        end)
    end
    for _, path in ipairs({
        "Inventory", "Quests", "CompletedQuests", "TempleLevers",
        "RuinPressurePlates", "UnlockedTemple", "Level", "EquippedId",
    }) do
        pcall(function()
            return Data.Player:OnChange(path, function()
                S.Quest.queueReplionRefresh()
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

    -- ====== WEBHOOK ======
do
    local WORKER_URL = "https://orvion-discord.mrfajri70.workers.dev"
    local WORKER_KEY = "orvion_111ajfkksdf12325778876"

    S.Webhook = { NameDropdown = nil, MutationDropdown = nil }

    -- HTTP send — fire and forget, no yield
    local function wSend(route, body)
        local fn = type(request) == "function" and request
            or (type(http_request) == "function" and http_request)
            or (type(syn) == "table" and type(syn.request) == "function" and syn.request)
            or nil
        if not fn then return end
        local ok, encoded = pcall(function()
            return Service.HttpService:JSONEncode(body)
        end)
        if not ok or not encoded then return end
        pcall(fn, {
            Url     = WORKER_URL .. route,
            Method  = "POST",
            Headers = {
                ["Content-Type"]  = "application/json",
                ["Authorization"] = "Bearer " .. WORKER_KEY,
            },
            Body = encoded,
        })
    end

    -- Resolve fish info from catalog — all data needed for embed
    local function resolveWebhookFish(fishName, metadata)
        local record = Data.FishCatalog.ByName[fishName]
        if not record then record = Data.getFishRecord(fishName) end
        local tierNum, tierName, rarity, iconAssetId, sellPrice =
            nil, "UNKNOWN", "N/A", nil, nil
        if record then
            tierNum = Data.resolveFishTier(record)
            if tierNum then
                local ok2, td = pcall(function()
                    return Data.TierUtility:GetTier(tierNum)
                end)
                if ok2 and td and td.Name then
                    tierName = td.Name:upper()
                end
            end
            local prob = record.Probability
            if type(prob) == "table" and type(prob.Chance) == "number" and prob.Chance > 0 then
                local n = math.round(1 / prob.Chance)
                local s = tostring(n)
                local result, offset = "", #s % 3
                for i = 1, #s do
                    if i > 1 and (i - 1 - offset) % 3 == 0 then result = result .. "," end
                    result = result .. s:sub(i, i)
                end
                rarity = "1 in " .. result
            end
            local d = type(record.Data) == "table" and record.Data
            if d and type(d.Icon) == "string" and d.Icon ~= "" then
                iconAssetId = d.Icon:match("^rbxassetid://(%d+)$") or (d.Icon:match("^%d+$") and d.Icon)
            end
            if type(record.SellPrice) == "number" then sellPrice = record.SellPrice end
        end
        local meta = type(metadata) == "table" and metadata or {}
        return {
            tierNum     = tierNum,
            tierName    = tierName,
            rarity      = rarity,
            iconAssetId = iconAssetId,
            sellPrice   = sellPrice,
            weight      = type(meta.Weight) == "number" and meta.Weight or nil,
            shiny       = meta.Shiny == true,
            mutation    = type(meta.VariantId) == "string" and meta.VariantId or nil,
        }
    end

    -- Guard helpers
    local function tierMatches(tierName, filter)
        if type(filter) ~= "table" or #filter == 0 then return true end
        for _, t in ipairs(filter) do
            if t:upper() == tierName:upper() then return true end
        end
        return false
    end
    local function nameMatches(fishName, filter)
        if type(filter) ~= "table" or #filter == 0 then return true end
        for _, n in ipairs(filter) do
            if (n:match("^x%d+ (.+)$") or n) == fishName then return true end
        end
        return false
    end
    local function mutationMatches(mutation, filter)
        if type(filter) ~= "table" or #filter == 0 then return true end
        local mut = mutation or "None"
        for _, m in ipairs(filter) do
            if m == mut then return true end
        end
        return false
    end
    local function urlValid(v)
        return type(v) == "string" and v ~= "" and v ~= "Write your input here..."
    end

    -- /catch — personal webhook (own fish only)
    local function sendPersonalFish(fishName, meta, R)
        if not Config["Webhook_Send_Fish"] then return end
        if not urlValid(Config["Webhook_Fish_URL"]) then return end
        if not tierMatches(R.tierName, Config["Webhook_Fish_Tier"]) then return end
        if not nameMatches(fishName, Config["Webhook_Name_Filter"]) then return end
        if not mutationMatches(R.mutation, Config["Webhook_Mutation_Filter"]) then return end
        local name = Service.LocalPlayer.Name
        if Config["Webhook_Censored_Name"] then name = "||" .. name .. "||" end
        wSend("/catch", {
            webhookUrl = Config["Webhook_Fish_URL"],
            event = {
                name           = fishName,
                category       = "fish",
                tier           = R.tierName,
                rarity         = R.rarity,
                mutation       = R.mutation or "None",
                shiny          = R.shiny,
                weight         = R.weight,
                baseSellPrice  = R.sellPrice,
                robloxUsername = name,
                iconAssetId    = R.iconAssetId,
                caughtAt       = os.time(),
            }
        })
    end

    -- /global — SECRET & FORGOTTEN only (own fish, anonymous)
    local function sendGlobalFish(fishName, meta, R)
        if not Config["Webhook_Global_Send"] then return end
        if R.tierNum ~= 7 and R.tierNum ~= 8 then return end
        local did = Config["Webhook_Global_Discord"]
        local discordId = type(did) == "string" and did ~= "" and did ~= "Write your Discord ID here..." and did or nil
        -- eventId deduplicated per 2-minute window
        local window = math.floor(os.time() / 120)
        wSend("/global", {
            eventId       = "fish:" .. fishName .. ":" .. tostring(window),
            discordUserId = discordId,
            event = {
                name          = fishName,
                category      = "fish",
                tier          = R.tierName,
                rarity        = R.rarity,
                mutation      = R.mutation or "None",
                shiny         = R.shiny,
                weight        = R.weight,
                baseSellPrice = R.sellPrice,
                iconAssetId   = R.iconAssetId,
                caughtAt      = os.time(),
            }
        })
    end

    -- /server-event — one-server fish (other players, from CaughtFishVisual)
    local function sendOneServerFish(playerName, fishName, meta, R)
        if not urlValid(Config["Webhook_OneServer_URL"]) then return end
        local isSecret  = R.tierNum == 7 or R.tierNum == 8
        local isRubyGem = fishName == "Ruby" and R.mutation == "Gemstone"
        local send = false
        if isRubyGem and Config["Webhook_OneServer_Ruby_Gemstone"] then send = true end
        if isSecret and Config["Webhook_OneServer_Secret___Forgotten"] then send = true end
        if not send then return end
        local name = playerName
        if Config["Webhook_OneServer_Censored"] then name = "||" .. name .. "||" end
        wSend("/server-event", {
            webhookUrl = Config["Webhook_OneServer_URL"],
            event = {
                name           = fishName,
                category       = "fish",
                tier           = R.tierName,
                rarity         = R.rarity,
                mutation       = R.mutation or "None",
                shiny          = R.shiny,
                weight         = R.weight,
                baseSellPrice  = R.sellPrice,
                robloxUsername = name,
                iconAssetId    = R.iconAssetId,
                caughtAt       = os.time(),
            }
        })
    end

    -- /server-event — one-server items (Evo/Runic/Withering from ReplicateCutscene)
    local ITEM_TOGGLE = {
        ["Evolved Enchant Stone"] = "Webhook_OneServer_Evolved_Enchant_Stone",
        ["Runic Enchant Stone"]   = "Webhook_OneServer_Runic_Enchant_Stone",
        ["Withering Core"]        = "Webhook_OneServer_Withering_Core",
    }
    local ITEM_TIER = {
        ["Evolved Enchant Stone"] = "LEGENDARY",
        ["Runic Enchant Stone"]   = "SECRET",
        ["Withering Core"]        = "SECRET",
    }
    local ITEM_ICON = {
        ["Evolved Enchant Stone"] = "117432341595763",
        ["Runic Enchant Stone"]   = "139603424264761",
        ["Withering Core"]        = "116659997697473",
    }
    local function sendOneServerItem(playerName, itemName)
        if not urlValid(Config["Webhook_OneServer_URL"]) then return end
        local tkey = ITEM_TOGGLE[itemName]
        if not tkey or not Config[tkey] then return end
        local name = playerName
        if Config["Webhook_OneServer_Censored"] then name = "||" .. name .. "||" end
        wSend("/server-event", {
            webhookUrl = Config["Webhook_OneServer_URL"],
            event = {
                name           = itemName,
                category       = "item",
                tier           = ITEM_TIER[itemName] or "SECRET",
                rarity         = "N/A",
                mutation       = "None",
                shiny          = false,
                weight         = nil,
                baseSellPrice  = nil,
                robloxUsername = name,
                iconAssetId    = ITEM_ICON[itemName],
                caughtAt       = os.time(),
            }
        })
    end

    -- Hook: RE/FishCaught AdjacentCandidate (own catches) — numpang existing
    if Remote.fishCaught then
        Remote.fishCaught.OnClientEvent:Connect(function(fishName, metadata)
            task.delay(0.2, function()
                local R = resolveWebhookFish(fishName, metadata)
                sendPersonalFish(fishName, metadata, R)
                sendGlobalFish(fishName, metadata, R)
            end)
        end)
    end

    -- Hook: RE/CaughtFishVisual AdjacentCandidate (all players) — one-server fish
    local wVisual = Remote.Resolve("RE/CaughtFishVisual")
    if wVisual and wVisual:IsA("RemoteEvent") then
        wVisual.OnClientEvent:Connect(function(player, pos, fishName, metadata)
            if typeof(player) == "Instance" and player == Service.LocalPlayer then return end
            local playerName = typeof(player) == "Instance" and player.Name or "?"
            task.delay(0.1, function()
                local R = resolveWebhookFish(fishName, metadata)
                sendOneServerFish(playerName, fishName, metadata, R)
            end)
        end)
    end

    -- Hook: RE/ReplicateCutscene AdjacentCandidate (all players) — one-server items
    local wCutscene = Remote.Resolve("RE/ReplicateCutscene")
    if wCutscene and wCutscene:IsA("RemoteEvent") then
        wCutscene.OnClientEvent:Connect(function(tier, charOrPlayer, pos, itemName)
            if not ITEM_TOGGLE[itemName] then return end
            local playerName = "?"
            pcall(function()
                local p = typeof(charOrPlayer) == "Instance"
                    and (charOrPlayer:IsA("Player") and charOrPlayer
                        or Service.Players:GetPlayerFromCharacter(charOrPlayer))
                if p then playerName = p.Name end
            end)
            task.delay(0.1, function()
                sendOneServerItem(playerName, itemName)
            end)
        end)
    end

    -- Hook: PlayerAdded/Removing — one-server join/leave
    Service.Players.PlayerAdded:Connect(function(player)
        if not Config["Webhook_OneServer_JoinLeave_Send"] then return end
        if not urlValid(Config["Webhook_OneServer_JoinLeave_URL"]) then return end
        local all = Service.Players:GetPlayers()
        local players = {}
        for _, p in ipairs(all) do
            table.insert(players, { displayName = p.DisplayName, username = p.Name })
        end
        wSend("/presence", {
            webhookUrl        = Config["Webhook_OneServer_JoinLeave_URL"],
            action            = "join",
            playerDisplayName = player.DisplayName,
            playerUsername    = player.Name,
            currentPlayers    = #all,
            maxPlayers        = game.Players.MaxPlayers,
            players           = players,
            timestamp         = os.time(),
        })
    end)

    Service.Players.PlayerRemoving:Connect(function(player)
        if not Config["Webhook_OneServer_JoinLeave_Send"] then return end
        if not urlValid(Config["Webhook_OneServer_JoinLeave_URL"]) then return end
        local all = Service.Players:GetPlayers()
        local remaining = {}
        for _, p in ipairs(all) do
            if p ~= player then
                table.insert(remaining, { displayName = p.DisplayName, username = p.Name })
            end
        end
        wSend("/presence", {
            webhookUrl        = Config["Webhook_OneServer_JoinLeave_URL"],
            action            = "leave",
            playerDisplayName = player.DisplayName,
            playerUsername    = player.Name,
            currentPlayers    = math.max(0, #all - 1),
            maxPlayers        = game.Players.MaxPlayers,
            players           = remaining,
            timestamp         = os.time(),
        })
    end)

    -- UI
    UI.WebhookTab = UI.Window:CreateTab("Webhook", "rbxassetid://106168327267607")
    local FishCaught = UI.Window:AddCollapsible(UI.WebhookTab, "Webhook Fish Caught", false)

    UI.Window:AddInput(FishCaught, "Webhook URL", "", "Write your input here...",
        function(v) Config["Webhook_Fish_URL"] = v end, "Webhook_Fish_URL")

    UI.Window:AddDropdown(FishCaught, "Tier Filter", "",
        Catalog.RarityTiersNoCommon, true, {},
        function(v) Config["Webhook_Fish_Tier"] = v end, "Webhook_Fish_Tier")

    UI.Window:AddTextHeader(FishCaught, "Webhook by Name & Mutation")

    local NameFilterDropdown = UI.Window:AddDropdown(FishCaught, "Name Filter", "", {}, true, {},
        function(v) Config["Webhook_Name_Filter"] = v end, "Webhook_Name_Filter")
    S.Webhook.NameDropdown = NameFilterDropdown

    -- Mutation list from catalog
    local mutationList = {}
    pcall(function()
        local variants = Data.ItemUtility:GetVariants()
        for _, v in pairs(variants) do
            if type(v) == "table" and type(v.Data) == "table" and v.Data.Name then
                table.insert(mutationList, v.Data.Name)
            end
        end
        table.sort(mutationList)
    end)
    local MutationFilterDropdown = UI.Window:AddDropdown(FishCaught, "Mutation Filter", "",
        mutationList, true, {},
        function(v) Config["Webhook_Mutation_Filter"] = v end, "Webhook_Mutation_Filter")
    S.Webhook.MutationDropdown = MutationFilterDropdown

    UI.Window:AddToggle(FishCaught, "Censored Name", "", false,
        function(v) Config["Webhook_Censored_Name"] = v end, "Webhook_Censored_Name")

    UI.Window:AddToggle(FishCaught, "Send Fish Webhook", "", false,
        function(v) Config["Webhook_Send_Fish"] = v end, "Webhook_Send_Fish")

    UI.Window:AddButton(FishCaught, "Test Webhook Connection", "", "rbxassetid://16932740082",
        function()
            if not urlValid(Config["Webhook_Fish_URL"]) then
                UI.Library:Notify({ Title="Orvion", Subtitle="Hub",
                    Content="Fill in Webhook URL first!", Color=Color3.fromRGB(255,80,80), Delay=3 })
                return
            end
            wSend("/catch", {
                webhookUrl = Config["Webhook_Fish_URL"],
                event = {
                    name           = "Test Fish",
                    category       = "fish",
                    tier           = "SECRET",
                    rarity         = "Test",
                    mutation       = "None",
                    shiny          = false,
                    weight         = 0,
                    baseSellPrice  = 0,
                    robloxUsername = Service.LocalPlayer.Name,
                    caughtAt       = os.time(),
                }
            })
            UI.Library:Notify({ Title="Orvion", Subtitle="Hub",
                Content="Test webhook sent!", Color=Color3.fromRGB(150,150,170), Delay=3 })
        end)

    UI.Window:AddTextHeader(FishCaught, "Webhook Fish Global")

    UI.Window:AddInput(FishCaught, "Discord ID (For Tag)", "", "Write your Discord ID here...",
        function(v) Config["Webhook_Global_Discord"] = v end, "Webhook_Global_Discord")

    UI.Window:AddToggle(FishCaught, "Send Webhook Global", "Only Secret & Forgotten", false,
        function(v) Config["Webhook_Global_Send"] = v end, "Webhook_Global_Send")

    local WebhookOneServer = UI.Window:AddCollapsible(UI.WebhookTab, "Webhook One-server", false)

    UI.Window:AddTextHeader(WebhookOneServer, "Webhook Protection")

    UI.Window:AddToggle(WebhookOneServer, "Censored Name", "", false,
        function(v) Config["Webhook_OneServer_Censored"] = v end, "Webhook_OneServer_Censored")

    UI.Window:AddTextHeader(WebhookOneServer, "Webhook Fish Caught One-server")

    UI.Window:AddInput(WebhookOneServer, "One-server Webhook URL", "", "Write your input here...",
        function(v) Config["Webhook_OneServer_URL"] = v end, "Webhook_OneServer_URL")

    for _, label in ipairs({"Evolved Enchant Stone","Runic Enchant Stone","Ruby Gemstone","Withering Core","Secret & Forgotten"}) do
        local key = "Webhook_OneServer_" .. label:gsub("[^%w]", "_")
        UI.Window:AddToggle(WebhookOneServer, label, "", false,
            function(v) Config[key] = v end, key)
    end

    UI.Window:AddTextHeader(WebhookOneServer, "Webhook One-server Join / Leave")

    UI.Window:AddInput(WebhookOneServer, "Webhook One-server Join / Leave URL", "", "Write your input here...",
        function(v) Config["Webhook_OneServer_JoinLeave_URL"] = v end, "Webhook_OneServer_JoinLeave_URL")

    UI.Window:AddToggle(WebhookOneServer, "Send Webhook One-server Join / Leave", "", false,
        function(v) Config["Webhook_OneServer_JoinLeave_Send"] = v end, "Webhook_OneServer_JoinLeave_Send")

    -- Populate name filter after catalog loaded (defer so catalog is ready)
    task.defer(function()
        local names = {}
        for name in pairs(Data.FishCatalog.ByName) do
            table.insert(names, name)
        end
        table.sort(names)
        if S.Webhook.NameDropdown and #names > 0 then
            pcall(function() S.Webhook.NameDropdown:Refresh(names, nil) end)
        end
    end)
end

-- ====== STARTUP ======
SupportState.updateBigPopup()
UI.Window:SetActiveTab("Info")
UI.Window:Show()
