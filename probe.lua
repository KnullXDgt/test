-- Probe: secret fish inventory + equipped rod/enchants
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local out = {}
local function log(s) table.insert(out, s) print(s) end
local function save() if writefile then writefile("probe.txt", table.concat(out, "\n")) end end

local IU = require(RS.Shared.ItemUtility)
local Replion = require(RS.Packages.Replion)
local PlayerData = Replion.Client:WaitReplion("Data")
if not PlayerData then log("No PlayerData") save() return end

-- ====== SECRET FISH (Tier 7) ======
log("=== SECRET FISH IN INVENTORY ===")
local inv = PlayerData:Get("Inventory") or {}
local secretFish = {}
for catName, items in pairs(inv) do
    if type(items) == "table" then
        for _, item in ipairs(items) do
            if type(item) == "table" and item.Id and item.UUID then
                pcall(function()
                    local data = IU.GetItemDataFromItemType(catName, item.Id)
                    if data and data.Data and data.Data.Type == "Fish" and data.Probability then
                        local tier = IU:GetTierFromRarity(data.Probability.Chance)
                        if tier and tier.Tier == 7 then
                            local name = data.Data.Name or tostring(item.Id)
                            secretFish[name] = (secretFish[name] or 0) + 1
                        end
                    end
                end)
            end
        end
    end
end
local total = 0
for name, count in pairs(secretFish) do
    log("  " .. name .. ": " .. count)
    total = total + count
end
log("Total secret fish: " .. total)

-- ====== EQUIPPED ROD ======
log("=== EQUIPPED ROD ===")
pcall(function()
    local equippedId = PlayerData:Get("EquippedFishingRod")
    if equippedId then
        log("  EquippedFishingRod UUID: " .. tostring(equippedId))
        -- Find in inventory
        local rods = inv["Fishing Rods"] or {}
        for _, item in ipairs(rods) do
            if item.UUID == equippedId then
                local data = IU.GetItemDataFromItemType("Fishing Rods", item.Id)
                local name = data and data.Data and data.Data.Name or tostring(item.Id)
                log("  Rod Name: " .. name)
            end
        end
    else
        log("  EquippedFishingRod: not found, trying other keys...")
        -- Dump equipped-related keys
        for _, key in ipairs({"EquippedId","EquippedType","EquippedRod","Equipped","EquippedItem"}) do
            local v = PlayerData:Get(key)
            if v ~= nil then log("  [" .. key .. "] = " .. tostring(v)) end
        end
    end
end)

-- ====== ENCHANT 1 & 2 ======
log("=== ENCHANT STONES EQUIPPED ===")
pcall(function()
    -- Try common keys for enchant slots
    for _, key in ipairs({"EquippedId","EquippedEnchantStone","EquippedEnchant1","EquippedEnchant2","EquippedSecondEnchantStone"}) do
        local v = PlayerData:Get(key)
        if v ~= nil then
            log("  [" .. key .. "] = " .. tostring(v))
        end
    end
    -- Also check EquippedId with EquippedType
    local eId = PlayerData:Get("EquippedId")
    local eType = PlayerData:Get("EquippedType")
    if eId and eType then
        log("  EquippedId=" .. tostring(eId) .. " Type=" .. tostring(eType))
        local stones = inv[eType] or {}
        for _, item in ipairs(stones) do
            if item.UUID == eId then
                local data = IU.GetItemDataFromItemType(eType, item.Id)
                local name = data and data.Data and data.Data.Name or tostring(item.Id)
                log("  Enchant Stone: " .. name)
            end
        end
    end
    -- Check SecondEquippedId
    local se = PlayerData:Get("SecondEquippedId")
    if se then log("  SecondEquippedId=" .. tostring(se)) end
end)

-- Dump ALL PlayerData keys for discovery
log("=== ALL PlayerData Keys ===")
pcall(function()
    local all = PlayerData:Get()
    if type(all) == "table" then
        for k, v in pairs(all) do
            if type(v) ~= "table" then
                log("  [" .. tostring(k) .. "] = " .. tostring(v))
            else
                log("  [" .. tostring(k) .. "] = table")
            end
        end
    end
end)

save()
