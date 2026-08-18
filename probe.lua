-- Probe: totem itemData full nested dump
local RS = game:GetService("ReplicatedStorage")
local out = {}
local function log(s) table.insert(out, s) print(s) end
local function dumpFull(t, depth)
    if depth > 3 then return "..." end
    if type(t) ~= "table" then return tostring(t) end
    local p = {}
    for k,v in pairs(t) do
        table.insert(p, tostring(k).."="..dumpFull(v, depth+1))
    end
    return "{"..table.concat(p,", ")"}"
end

local Replion = require(RS.Packages.Replion)
local PlayerData = Replion.Client:WaitReplion("Data")
if not PlayerData then log("No PlayerData") return end

local ok2, IU = pcall(function() return require(RS.Shared.ItemUtility) end)
local inv = nil
pcall(function() inv = PlayerData:Get("Inventory") end)
if not inv then log("No inventory") return end

local totems = inv.Totems or {}
log("Totem count in dict: " .. tostring(#totems == 0 and "dict" or #totems))

local n = 0
for itemId, itemData in pairs(totems) do
    n = n + 1
    local name = tostring(itemId)
    if ok2 and IU then
        pcall(function()
            local d = IU.GetItemDataFromItemType("Totems", itemId)
            if d and d.Data and d.Data.Name then name = d.Data.Name end
        end)
    end
    -- Show first 5 only to keep output manageable
    if n <= 5 then
        log("["..tostring(itemId).."] "..name.." = "..dumpFull(itemData, 0))
    end
end
log("Total: " .. n)

if writefile then writefile("probe.txt", table.concat(out, "\n")) end
