-- Probe: totem itemData structure
local RS = game:GetService("ReplicatedStorage")
local out = {}
local function log(s) table.insert(out, s) print(s) end
local function dumpT(t)
    if type(t)~="table" then return tostring(t) end
    local p={}
    for k,v in pairs(t) do
        if type(v)~="table" then table.insert(p, tostring(k).."="..tostring(v)) end
    end
    return table.concat(p,", ")
end

local Replion = require(RS.Packages.Replion)
local PlayerData = Replion.Client:WaitReplion("Data")
if not PlayerData then log("No PlayerData") return end

local ok2, IU = pcall(function() return require(RS.Shared.ItemUtility) end)
local inv = nil
pcall(function() inv = PlayerData:Get("Inventory") end)
if not inv then log("No inventory") return end

local totems = inv.Totems or {}
log("Totem slots: " .. tostring(#totems == 0 and "dict" or #totems))

for itemId, itemData in pairs(totems) do
    local name = tostring(itemId)
    if ok2 and IU then
        pcall(function()
            local d = IU.GetItemDataFromItemType("Totems", itemId)
            if d and d.Data and d.Data.Name then name = d.Data.Name end
        end)
    end
    log("id=" .. tostring(itemId) .. " name=" .. name .. " data={" .. dumpT(itemData) .. "}")
end

if writefile then writefile("probe.txt", table.concat(out, "\n")) end
