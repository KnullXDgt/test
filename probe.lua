-- Probe: full PlayerData Replion dump + enchant stones + secret fish
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local out = {}
local function log(s) table.insert(out, s) print(s) end
local function save() if writefile then writefile("probe.txt", table.concat(out, "\n")) end end

local function dump(v, d)
    if d > 3 then return "..." end
    if type(v) == "table" then
        local p = {}
        for k, val in pairs(v) do
            table.insert(p, tostring(k) .. "=" .. dump(val, d+1))
        end
        return "{" .. table.concat(p, ", ") .. "}"
    end
    return tostring(v)
end

local IU = require(RS.Shared.ItemUtility)
local Replion = require(RS.Packages.Replion)
local PlayerData = Replion.Client:WaitReplion("Data")
if not PlayerData then log("No PlayerData") save() return end

-- Full PlayerData dump (all keys including tables)
log("=== FULL PlayerData ===")
pcall(function()
    local all = PlayerData:Get()
    if type(all) ~= "table" then log("Get() = " .. type(all)) return end
    for k, v in pairs(all) do
        if type(v) == "table" then
            log("[TABLE] " .. tostring(k) .. " = " .. dump(v, 0):sub(1, 300))
        else
            log("[" .. tostring(k) .. "] = " .. tostring(v))
        end
    end
end)

local inventory = PlayerData:Get("Inventory") or {}

-- Secret fish (Tier 7)
log("=== SECRET FISH ===")
local secretFish = {}
for catName, items in pairs(inventory) do
    if type(items) == "table" then
        for _, item in ipairs(items) do
            local ok, data = pcall(IU.GetItemDataFromItemType, catName, item.Id)
            if ok and data and data.Data and data.Data.Type == "Fish" and tonumber(data.Data.Tier) == 7 then
                local name = data.Data.Name or tostring(item.Id)
                secretFish[name] = (secretFish[name] or 0) + 1
            end
        end
    end
end
local total = 0
for name, count in pairs(secretFish) do log("  " .. name .. " x" .. count); total = total + count end
log("Total: " .. total)

-- All enchant stone types in inventory
log("=== ENCHANT STONES IN INVENTORY ===")
local stones = inventory["Enchant Stones"] or {}
local stoneTypes = {}
for _, item in ipairs(stones) do
    local ok, data = pcall(IU.GetItemDataFromItemType, "Enchant Stones", item.Id)
    if ok and data and data.Data then
        local name = data.Data.Name or tostring(item.Id)
        stoneTypes[name] = (stoneTypes[name] or 0) + 1
    end
end
for name, count in pairs(stoneTypes) do log("  " .. name .. " x" .. count) end

save()
