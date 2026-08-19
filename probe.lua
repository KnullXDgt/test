-- Probe: EquippedItems resolve + enchant stones inventory
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local out = {}
local function log(s) table.insert(out, s) print(s) end
local function save() if writefile then writefile("probe.txt", table.concat(out, "\n")) end end

local IU = require(RS.Shared.ItemUtility)
local Replion = require(RS.Packages.Replion)
local PlayerData = Replion.Client:WaitReplion("Data")
if not PlayerData then log("No PlayerData") save() return end

local inventory = PlayerData:Get("Inventory") or {}

-- ====== Resolve UUID to item name ======
local function resolveUUID(uuid)
    for catName, items in pairs(inventory) do
        if type(items) == "table" then
            for _, item in ipairs(items) do
                if item.UUID == uuid then
                    local ok, data = pcall(IU.GetItemDataFromItemType, catName, item.Id)
                    if ok and data and data.Data and data.Data.Name then
                        return data.Data.Name, catName, item.Id
                    end
                    return "id=" .. tostring(item.Id), catName, item.Id
                end
            end
        end
    end
    return "NOT FOUND", "?", "?"
end

-- ====== EquippedItems ======
log("=== EQUIPPED ITEMS ===")
pcall(function()
    local eq = PlayerData:Get("EquippedItems")
    if type(eq) == "table" then
        for slot, uuid in pairs(eq) do
            local name, cat, id = resolveUUID(tostring(uuid))
            log("  Slot " .. tostring(slot) .. ": " .. name .. " [" .. cat .. "] id=" .. tostring(id))
        end
    else
        log("  EquippedItems = " .. tostring(eq))
    end
end)

-- ====== ENCHANT STONES (tradeui pattern) ======
log("=== ENCHANT STONES IN INVENTORY ===")
local stoneCount = 0
for catName, items in pairs(inventory) do
    if type(items) == "table" then
        for _, item in ipairs(items) do
            local ok, data = pcall(IU.GetItemDataFromItemType, catName, item.Id)
            if ok and data and data.Data then
                local id = tonumber(item.Id)
                local dataName = (data.Data.Name or ""):lower()
                local isStone = (id == 929) or (id == 558) or dataName:find("enchant stone", 1, true)
                if isStone then
                    stoneCount = stoneCount + 1
                    log("  " .. (data.Data.Name or tostring(item.Id)) .. " UUID=" .. tostring(item.UUID):sub(1,8) .. "...")
                end
            end
        end
    end
end
log("Total stones: " .. stoneCount)

-- ====== SECRET FISH ======
log("=== SECRET FISH ===")
local secretTotal = 0
local secretTypes = {}
for catName, items in pairs(inventory) do
    if type(items) == "table" then
        for _, item in ipairs(items) do
            local ok, data = pcall(IU.GetItemDataFromItemType, catName, item.Id)
            if ok and data and data.Data and data.Data.Type == "Fish" and tonumber(data.Data.Tier) == 7 then
                local name = data.Data.Name or tostring(item.Id)
                secretTypes[name] = (secretTypes[name] or 0) + 1
                secretTotal = secretTotal + 1
            end
        end
    end
end
for name, count in pairs(secretTypes) do log("  " .. name .. " x" .. count) end
log("Total: " .. secretTotal)

save()
