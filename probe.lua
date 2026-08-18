-- Probe: totem types owned (ipairs + item.Id)
local RS = game:GetService("ReplicatedStorage")
local out = {}
local function log(s) table.insert(out, s) print(s) end

local Replion = require(RS.Packages.Replion)
local PlayerData = Replion.Client:WaitReplion("Data")
if not PlayerData then log("No PlayerData") return end

local ok2, IU = pcall(function() return require(RS.Shared.ItemUtility) end)
log("IU=" .. tostring(ok2))

local inv = nil
pcall(function() inv = PlayerData:Get("Inventory") end)
if not inv then log("No inventory") return end

local totems = inv.Totems or {}
log("Totems type=" .. type(totems))

-- Collect unique totem type IDs
local ownedTypes = {}
for _, item in ipairs(totems) do
    if type(item) == "table" and item.Id then
        ownedTypes[item.Id] = true
    end
end

log("Unique totem types: " .. tostring(#ownedTypes))
local names = {}
for typeId in pairs(ownedTypes) do
    local name = tostring(typeId)
    if ok2 and IU then
        pcall(function()
            local d = IU.GetItemDataFromItemType("Totems", typeId)
            if d and d.Data and d.Data.Name then name = d.Data.Name end
        end)
    end
    log("typeId=" .. tostring(typeId) .. " name=" .. name)
    table.insert(names, name)
end
log("Owned: " .. table.concat(names, ", "))

if writefile then writefile("probe.txt", table.concat(out, "\n")) end
