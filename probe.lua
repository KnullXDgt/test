-- Probe: FULL GAME DATA DUMP
local RS = game:GetService("ReplicatedStorage")
local out = {}
local function log(s) table.insert(out, s) print(s) end
local function save() if writefile then writefile("probe.txt", table.concat(out, "\n")) end end

local IU = require(RS.Shared.ItemUtility)
local Replion = require(RS.Packages.Replion)
local PlayerData = Replion.Client:WaitReplion("Data")
local inventory = PlayerData and PlayerData:Get("Inventory") or {}

-- ====== RESOLVE ROD ENCHANTS ======
log("=== ROD ENCHANT ID RESOLVE ===")
pcall(function()
    -- Try numeric ID
    for _, eid in ipairs({19, 1, 8}) do
        local ok, data = pcall(function() return IU:GetEnchantData(eid) end)
        if ok and data then log("  GetEnchantData("..eid..")="..tostring(data.Data and data.Data.Name or data)) end
        local ok2, data2 = pcall(function() return IU.GetEnchantData(IU, eid) end)
        if ok2 and data2 then log("  GetEnchantData(IU,"..eid..")="..tostring(data2.Data and data2.Data.Name or data2)) end
    end
end)

-- Try enchant modules at various paths
log("=== ENCHANT MODULES ===")
for _, path in ipairs({"Enchants","EnchantData","EnchantDatabase","EnchantIds"}) do
    pcall(function()
        local m = require(RS.Shared[path])
        local t = type(m)
        if t == "table" then
            local count = 0
            for k in pairs(m) do count = count + 1 end
            log("  RS.Shared."..path.." = table("..count.." keys)")
            local i = 0
            for k,v in pairs(m) do
                i = i + 1
                if i <= 5 then log("    ["..tostring(k).."] = "..type(v)) end
            end
        end
    end)
end

-- ====== ALL ENCHANT STONES + THEIR POOLS ======
log("=== ENCHANT STONE POOLS ===")
pcall(function()
    local stones = IU:GetEnchantStones()
    if type(stones) == "table" then
        for _, stone in ipairs(stones) do
            if stone and stone.Data then
                local name = stone.Data.Name or "?"
                local id = stone.Id or "?"
                log("--- Stone: "..name.." (id="..tostring(id)..") ---")
                if stone.Enchants then
                    for ename, prob in pairs(stone.Enchants) do
                        log("  "..tostring(ename).." "..tostring(prob).."%")
                    end
                end
            end
        end
    end
end)

-- ====== ALL CHARMS ======
log("=== ALL CHARMS ===")
pcall(function()
    for id = 1, 100 do
        local ok, data = pcall(IU.GetItemDataFromItemType, "Charms", id)
        if ok and data and data.Data and data.Data.Name then
            log("  id="..id.." "..data.Data.Name)
        end
    end
end)

-- ====== ALL ABILITIES/ORBS ======
log("=== ALL ABILITIES ===")
pcall(function()
    for id = 1, 50 do
        local ok, data = pcall(IU.GetItemDataFromItemType, "Abilities", id)
        if ok and data and data.Data and data.Data.Name then
            log("  id="..id.." "..data.Data.Name)
        end
    end
end)

-- ====== ALL POTIONS ======
log("=== ALL POTIONS ===")
pcall(function()
    for id = 1, 100 do
        local ok, data = pcall(IU.GetItemDataFromItemType, "Potions", id)
        if ok and data and data.Data and data.Data.Name then
            log("  id="..id.." "..data.Data.Name)
        end
    end
end)

-- ====== ALL HALOS ======
log("=== ALL HALOS ===")
pcall(function()
    for id = 1, 100 do
        local ok, data = pcall(IU.GetItemDataFromItemType, "Halos", id)
        if ok and data and data.Data and data.Data.Name then
            log("  id="..id.." "..data.Data.Name)
        end
    end
end)

-- ====== ALL PETS ======
log("=== ALL PETS ===")
pcall(function()
    for id = 1, 200 do
        local ok, data = pcall(IU.GetItemDataFromItemType, "Pets", id)
        if ok and data and data.Data and data.Data.Name then
            log("  id="..id.." "..data.Data.Name)
        end
    end
end)

-- ====== FISHING RODS PROPER ======
log("=== FISHING RODS (IU proper) ===")
pcall(function()
    -- Try IU:GetAllFishingRods or similar
    for _, method in ipairs({"GetFishingRods","GetAllFishingRods","GetRods"}) do
        local ok, result = pcall(function() return IU[method](IU) end)
        if ok and type(result) == "table" then
            log("  IU:"..method.."() = "..#result.." rods")
            for _, rod in ipairs(result) do
                if rod.Data then log("  "..tostring(rod.Data.Name)) end
            end
        end
    end
end)

-- ====== CHECK ITEMUTILITY METHODS ======
log("=== ITEMUTILITY METHODS ===")
pcall(function()
    for k, v in pairs(IU) do
        if type(v) == "function" then log("  IU."..tostring(k)) end
    end
end)

save()
log("DONE")
save()
