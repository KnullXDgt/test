-- Probe: FULL GAME DATA using proper IU methods
local RS = game:GetService("ReplicatedStorage")
local out = {}
local function log(s) table.insert(out, s) print(s) end
local function save() if writefile then writefile("probe.txt", table.concat(out, "\n")) end end

local IU = require(RS.Shared.ItemUtility)
local Replion = require(RS.Packages.Replion)
local PlayerData = Replion.Client:WaitReplion("Data")
local inventory = PlayerData and PlayerData:Get("Inventory") or {}

-- Helper: dump array of items
local function dumpItems(label, items)
    if not items or #items == 0 then log(label.." = empty") return end
    log("=== "..label.." ("..#items..") ===")
    for _, item in ipairs(items) do
        if item and item.Data then
            local name = item.Data.Name or "?"
            local id = item.Id or "?"
            local tier = item.Data.Tier or ""
            local extra = tier ~= "" and " [Tier "..tostring(tier).."]" or ""
            -- Check if player owns it
            local owned = 0
            pcall(function()
                local catItems = inventory[item.Data.Type or ""] or {}
                for _, inv in ipairs(catItems) do
                    if inv.Id == id then owned = owned + 1 end
                end
            end)
            local ownedStr = owned > 0 and " [OWNED x"..owned.."]" or ""
            log("  id="..tostring(id).." "..name..extra..ownedStr)
        end
    end
end

-- ====== ROD ENCHANTS (resolve from Metadata) ======
log("=== MY EQUIPPED ROD ENCHANTS ===")
pcall(function()
    local eq = PlayerData:Get("EquippedItems") or {}
    for slot, uuid in pairs(eq) do
        local rods = inventory["Fishing Rods"] or {}
        for _, item in ipairs(rods) do
            if tostring(item.UUID) == tostring(uuid) then
                local ok, data = pcall(IU.GetItemDataFromItemType, "Fishing Rods", item.Id)
                local name = ok and data and data.Data and data.Data.Name or "id="..tostring(item.Id)
                local meta = item.Metadata or {}
                local e1 = meta.EnchantId and IU:GetEnchantData(meta.EnchantId) or nil
                local e2 = meta.EnchantId2 and IU:GetEnchantData(meta.EnchantId2) or nil
                log("  Slot "..slot..": "..name)
                log("    Enchant 1: "..(e1 and e1.Data and e1.Data.Name or "none"))
                log("    Enchant 2: "..(e2 and e2.Data and e2.Data.Name or "none"))
            end
        end
    end
end)

-- ====== ALL GAME ITEMS VIA IU METHODS ======
pcall(function() dumpItems("ALL FISHING RODS", IU:GetFishingRods()) end)
pcall(function() dumpItems("ALL BAITS", IU:GetBaits()) end)
pcall(function() dumpItems("ALL HALOS", IU:GetHalos()) end)
pcall(function() dumpItems("ALL LANTERNS", IU:GetLanterns()) end)
pcall(function() dumpItems("ALL CHARMS", IU:GetCharms()) end)
pcall(function() dumpItems("ALL POTIONS", IU:GetPotions()) end)
pcall(function() dumpItems("ALL TOTEMS", IU:GetTotems()) end)
pcall(function() dumpItems("ALL PETS", IU:GetPets()) end)
pcall(function() dumpItems("ALL BOATS", IU:GetBoats()) end)
pcall(function() dumpItems("ALL EMOTES", IU:GetEmotes()) end)
pcall(function() dumpItems("ALL ABILITIES/GEARS", IU:GetAbilities()) end)
pcall(function() dumpItems("ALL GEARS", IU:GetGears()) end)
pcall(function() dumpItems("ALL TROPHIES", IU:GetTrophies()) end)
pcall(function() dumpItems("ALL PET EGGS", IU:GetPetEggs()) end)

-- ====== ENCHANT STONES + POOLS ======
log("=== ENCHANT STONES + POOLS ===")
pcall(function()
    local stones = IU:GetEnchantStones()
    for _, stone in ipairs(stones) do
        if stone and stone.Data then
            log("-- "..tostring(stone.Data.Name).." --")
            if stone.Enchants then
                for ename, prob in pairs(stone.Enchants) do
                    log("  "..tostring(ename).." "..tostring(prob).."%")
                end
            end
        end
    end
end)

-- ====== ALL FISH ======
log("=== ALL FISH (first 50) ===")
pcall(function()
    local fish = IU:GetFish()
    for i, f in ipairs(fish) do
        if i > 50 then log("  ...(+"..#fish-50.." more)"); break end
        if f and f.Data then
            log("  id="..tostring(f.Id).." "..tostring(f.Data.Name).." T"..tostring(f.Data.Tier or "?"))
        end
    end
end)

save()
log("DONE")
save()
