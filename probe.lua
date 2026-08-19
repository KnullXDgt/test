-- Probe: secret fish (Tier 7) + equipped rod/enchants
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

local inventory = PlayerData:Get("Inventory") or {}

-- ====== SECRET FISH (Tier 7) via Data.Tier pattern from tradeui.lua ======
log("=== SECRET FISH ===")
local secretFish = {}
for categoryName, items in pairs(inventory) do
    if type(items) == "table" then
        for _, item in ipairs(items) do
            local ok, itemData = pcall(IU.GetItemDataFromItemType, categoryName, item.Id)
            if ok and itemData and itemData.Data and itemData.Data.Type == "Fish" then
                local tier = tonumber(itemData.Data.Tier)
                if tier == 7 then
                    local name = itemData.Data.Name or tostring(item.Id)
                    secretFish[name] = (secretFish[name] or 0) + 1
                end
            end
        end
    end
end
local total = 0
for name, count in pairs(secretFish) do
    log("  " .. name .. " x" .. count)
    total = total + count
end
log("Total: " .. total)

-- ====== DUMP ALL PlayerData KEYS ======
log("=== PlayerData Keys ===")
pcall(function()
    local all = PlayerData:Get()
    if type(all) == "table" then
        for k, v in pairs(all) do
            if type(v) ~= "table" then
                log("  [" .. tostring(k) .. "] = " .. tostring(v))
            end
        end
    end
end)

-- ====== EQUIPPED ROD ======
log("=== EQUIPPED ROD ===")
pcall(function()
    local rods = inventory["Fishing Rods"] or {}
    for _, key in ipairs({"EquippedFishingRod","EquippedRod","EquippedId"}) do
        local eId = PlayerData:Get(key)
        if eId and eId ~= "" then
            for _, item in ipairs(rods) do
                if item.UUID == eId then
                    local ok, data = pcall(IU.GetItemDataFromItemType, "Fishing Rods", item.Id)
                    local name = ok and data and data.Data and data.Data.Name or tostring(item.Id)
                    log("  [" .. key .. "] " .. name)
                end
            end
        end
    end
end)

save()
