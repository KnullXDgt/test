-- Probe merchant: dump MarketItemData fields per item
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local out = {}
local function log(s) table.insert(out, s) print(s) end

local Replion = require(RS.Packages.Replion)

local mr = nil
pcall(function() mr = Replion.Client:WaitReplion("Merchant") end)
if not mr then log("Merchant replion not found") return end

local ok2, MID = pcall(function() return require(RS.Shared.MarketItemData) end)
local ok3, IU  = pcall(function() return require(RS.Shared.ItemUtility) end)
log("MID=" .. tostring(ok2) .. " IU=" .. tostring(ok3))

local midMap = {}
if ok2 and MID then
    for _, v in ipairs(MID) do midMap[v.Id] = v end
end

local itemIds = {}
pcall(function() itemIds = mr:GetExpect("Items") or {} end)
log("Item count: " .. tostring(#itemIds))

for i, itemId in ipairs(itemIds) do
    local md = midMap[itemId]
    if md then
        local line = "[" .. i .. "] id=" .. tostring(itemId)
        for k, v in pairs(md) do
            line = line .. " " .. tostring(k) .. "=" .. tostring(v)
        end
        log(line)
    else
        log("[" .. i .. "] id=" .. tostring(itemId) .. " no_md")
    end
end

if writefile then writefile("probe.txt", table.concat(out, "\n")) end
