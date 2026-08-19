-- Probe: FULL inventory dump - all categories, all items
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

-- Resolve UUID helper
local function resolveUUID(uuid)
    for catName, items in pairs(inventory) do
        if type(items) == "table" then
            for _, item in ipairs(items) do
                if tostring(item.UUID) == tostring(uuid) then
                    local ok, data = pcall(IU.GetItemDataFromItemType, catName, item.Id)
                    local name = ok and data and data.Data and data.Data.Name or ("id="..tostring(item.Id))
                    return name, catName, item.Id
                end
            end
        end
    end
    return "UNKNOWN", "?", "?"
end

-- ====== EQUIPPED ITEMS ======
log("=== EQUIPPED ITEMS ===")
pcall(function()
    local eq = PlayerData:Get("EquippedItems") or {}
    for slot, uuid in pairs(eq) do
        local name, cat, id = resolveUUID(tostring(uuid))
        log("  ["..tostring(slot).."] "..name.." ("..cat..") id="..tostring(id).." uuid="..tostring(uuid):sub(1,8))
    end
end)

-- ====== FULL INVENTORY BY CATEGORY ======
log("=== FULL INVENTORY ===")
local catOrder = {"Fishing Rods","Baits","Bait Skins","Fish","Enchant Stones","Items","Totems","Pets","Pet Eggs","Potions","Emotes","Boats","Lanterns","Halos","Charms","Booths","Abilities"}
local seen = {}
local function dumpCat(catName)
    if seen[catName] then return end
    seen[catName] = true
    local items = inventory[catName]
    if not items or type(items) ~= "table" then return end
    if #items == 0 then return end
    log("--- " .. catName .. " (" .. #items .. " items) ---")
    local counts = {}
    for _, item in ipairs(items) do
        local ok, data = pcall(IU.GetItemDataFromItemType, catName, item.Id)
        local name = ok and data and data.Data and data.Data.Name or ("id="..tostring(item.Id))
        counts[name] = (counts[name] or 0) + 1
    end
    for name, count in pairs(counts) do
        log("  "..name.." x"..count)
    end
end
-- Dump in order
for _, cat in ipairs(catOrder) do dumpCat(cat) end
-- Dump remaining categories
for catName in pairs(inventory) do dumpCat(catName) end

-- ====== STATS ======
log("=== KEY STATS ===")
for _, k in ipairs({"Level","XP","Coins","Tix","Tokens","RAP","Enchants","LoginStreak","TotalSessionTime"}) do
    local v = PlayerData:Get(k)
    if v ~= nil then log("  "..k.." = "..tostring(v)) end
end

-- ====== SETTINGS ======
log("=== SETTINGS ===")
pcall(function()
    local s = PlayerData:Get("Settings") or {}
    for k,v in pairs(s) do log("  "..tostring(k).." = "..tostring(v)) end
end)

save()
log("DONE - saved to probe.txt")
save()
