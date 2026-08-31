-- probe_fishvalue.lua: dump fish itemData fields + inventory fish dengan SellPrice
local RS = game:GetService("ReplicatedStorage")
local out = {}
local function log(s) table.insert(out, tostring(s)) print(s) end
local function save() if writefile then writefile("probe_fishvalue.txt", table.concat(out, "\n")) end end

local IU = require(RS.Shared.ItemUtility)
local Replion = require(RS.Packages.Replion)
local PlayerData = Replion.Client:WaitReplion("Data")

-- ====== FISH ITEMDATA STRUCTURE (per tier) ======
log("=== FISH ITEMDATA FULL STRUCTURE (sample per tier) ===")
pcall(function()
    local fish = IU:GetFish()
    log("Total fish in game: " .. tostring(#fish))
    local seen = {}
    for _, f in ipairs(fish) do
        if f and f.Data then
            local tier = tostring(f.Data.Tier or "?")
            if not seen[tier] then
                seen[tier] = true
                log("\n--- T" .. tier .. ": " .. tostring(f.Data.Name or "?") .. " ---")
                log("  SellPrice = " .. tostring(f.SellPrice or "nil"))
                log("  Probability.Chance = " .. tostring(f.Probability and f.Probability.Chance or "nil"))
                log("  Data.Id = " .. tostring(f.Data.Id or "nil"))
                log("  Data.Tier = " .. tostring(f.Data.Tier or "nil"))
            end
        end
    end
end)
save()

-- ====== INVENTORY FISH DENGAN HARGA ======
log("\n=== INVENTORY FISH + SELL PRICE ===")
pcall(function()
    local inventory = PlayerData:Get("Inventory") or {}
    local fishList = {}

    for category, items in pairs(inventory) do
        if type(items) == "table" then
            for _, item in ipairs(items) do
                if type(item) == "table" and item.Id then
                    local ok, itemData = pcall(IU.GetItemDataFromItemType, IU, category, item.Id)
                    if not ok or not itemData then
                        ok, itemData = pcall(IU.GetItemDataFromItemType, category, item.Id)
                    end
                    if itemData and itemData.Data and itemData.Data.Type == "Fish" then
                        local name = itemData.Data.Name or tostring(item.Id)
                        local tier = itemData.Data.Tier or 0
                        local sellPrice = itemData.SellPrice or 0
                        -- Dump ALL metadata fields
                        local metaStr = "nil"
                        if item.Metadata and type(item.Metadata) == "table" then
                            local parts = {}
                            for k, v in pairs(item.Metadata) do
                                table.insert(parts, tostring(k) .. "=" .. tostring(v))
                            end
                            metaStr = "{" .. table.concat(parts, ", ") .. "}"
                        end
                        table.insert(fishList, {
                            name = name,
                            tier = tier,
                            sellPrice = sellPrice,
                            uuid = item.UUID or "?",
                            meta = metaStr,
                        })
                    end
                end
            end
        end
    end

    -- Sort by SellPrice desc
    table.sort(fishList, function(a, b) return a.sellPrice > b.sellPrice end)

    log("Total fish in inventory: " .. tostring(#fishList))
    log(string.format("%-40s | %-5s | %-12s | %s", "Name", "Tier", "SellPrice", "Metadata"))
    log(string.rep("-", 100))

    local totalValue = 0
    for _, f in ipairs(fishList) do
        totalValue = totalValue + f.sellPrice
        log(string.format("%-40s | T%-4s | %-12s | %s",
            f.name, tostring(f.tier), tostring(f.sellPrice), f.meta))
    end

    log(string.rep("-", 90))
    log("TOTAL INVENTORY FISH VALUE: " .. tostring(totalValue) .. " coins")
    log("(if all sold)")
end)
save()


-- ====== TRADEDATA FOLLOW TRADE RULES ======
log("\n=== TRADEDATA MODULE ===")
pcall(function()
    local TradeData = require(RS.Shared.Trading.TradeData)
    -- Dump semua keys di TradeData
    for k, v in pairs(TradeData) do
        if type(v) ~= "function" and type(v) ~= "table" then
            log("  " .. tostring(k) .. " = " .. tostring(v))
        elseif type(v) == "table" then
            log("  " .. tostring(k) .. " = table")
        else
            log("  " .. tostring(k) .. " = function")
        end
    end
end)
save()

-- Cek apakah FollowTradeRules bisa dipanggil dengan item dari inventory
log("\n=== FOLLOWTRADERULES TEST ===")
pcall(function()
    local TradeData = require(RS.Shared.Trading.TradeData)
    local IU = require(RS.Shared.ItemUtility)
    local inventory = PlayerData:Get("Inventory") or {}
    local now = workspace:GetServerTimeNow()
    log("ServerTimeNow = " .. tostring(now))
    -- Test dengan beberapa ikan
    for category, items in pairs(inventory) do
        if type(items) == "table" then
            for _, item in ipairs(items) do
                if type(item) == "table" and item.Id then
                    local ok, itemData = pcall(IU.GetItemDataFromItemType, IU, category, item.Id)
                    if not ok then ok, itemData = pcall(IU.GetItemDataFromItemType, category, item.Id) end
                    if itemData and itemData.Data and itemData.Data.Type == "Fish" then
                        local canTrade = false
                        local ok2, result = pcall(TradeData.FollowTradeRules, itemData.Data, item)
                        if ok2 then canTrade = result end
                        local meta = ""
                        if item.Metadata then
                            local parts = {}
                            for k, v in pairs(item.Metadata) do
                                table.insert(parts, k .. "=" .. tostring(v))
                            end
                            meta = table.concat(parts, ", ")
                        end
                        log(string.format("  %-35s | canTrade=%-5s | meta={%s}",
                            tostring(itemData.Data.Name or "?"), tostring(canTrade), meta))
                        -- Hanya test 10 ikan saja
                        break
                    end
                end
            end
        end
    end
end)
save()

log("\nDONE")
save()
