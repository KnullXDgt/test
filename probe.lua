-- Probe: scan inventory for Totem items
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local out = {}
local function log(s) table.insert(out, s) print(s) end

local Replion = require(RS.Packages.Replion)
local PlayerData = Replion.Client:WaitReplion("Data")
if not PlayerData then log("PlayerData not found") return end

local ok2, IU = pcall(function() return require(RS.Shared.ItemUtility) end)
log("IU=" .. tostring(ok2))

local inv = nil
pcall(function() inv = PlayerData:Get("Inventory") end)
if not inv then log("Inventory not found") return end

log("Inventory categories: " .. tostring(type(inv)))
for catName, catItems in pairs(inv) do
    log("Category: " .. tostring(catName) .. " count=" .. tostring(type(catItems)))
    if type(catItems) == "table" then
        local n = 0
        for itemId, itemData in pairs(catItems) do
            n = n + 1
            local name = tostring(itemId)
            local itemType = tostring(catName)
            if ok2 and IU then
                pcall(function()
                    local data = IU.GetItemDataFromItemType(catName, itemId)
                    if data and data.Data then
                        name = tostring(data.Data.Name or itemId)
                        itemType = tostring(data.Data.Type or catName)
                    end
                end)
            end
            if itemType == "Totem" or catName == "Totems" or string.find(tostring(catName):lower(), "totem") then
                local qty = 1
                pcall(function() qty = itemData.Quantity or itemData.Count or 1 end)
                log("TOTEM id=" .. tostring(itemId) .. " name=" .. name .. " qty=" .. tostring(qty) .. " cat=" .. tostring(catName))
            end
            if n <= 3 then
                log("  sample [" .. tostring(itemId) .. "]=" .. tostring(type(itemData)))
            end
        end
    end
end

if writefile then writefile("probe.txt", table.concat(out, "\n")) end
