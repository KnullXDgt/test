-- Probe: FULL GAME DATA - fixed nil checks
local RS = game:GetService("ReplicatedStorage")
local out = {}
local function log(s) table.insert(out, s) print(s) end
local function save() if writefile then writefile("probe.txt", table.concat(out, "\n")) end end

local ok0, IU = pcall(require, RS.Shared.ItemUtility)
if not ok0 then log("IU fail: "..tostring(IU)) save() return end
local Replion = require(RS.Packages.Replion)
local PlayerData = Replion.Client:WaitReplion("Data")
local inventory = PlayerData and PlayerData:Get("Inventory") or {}

local function safeCall(fn, ...)
    local ok, r = pcall(fn, ...)
    return ok and type(r) == "table" and r or nil
end

local function dumpItems(label, items)
    if type(items) ~= "table" then log("=== "..label.." = nil/invalid ===") return end
    local n = 0; for _ in pairs(items) do n=n+1 end
    if n == 0 then log("=== "..label.." = empty ===") return end
    log("=== "..label.." ("..n..") ===")
    local arr = {}
    for _, item in pairs(items) do table.insert(arr, item) end
    for _, item in ipairs(arr) do
        if type(item) == "table" and item.Data then
            local name = tostring(item.Data.Name or "?")
            local id = tostring(item.Id or "?")
            local tier = item.Data.Tier and (" T"..item.Data.Tier) or ""
            log("  id="..id.." "..name..tier)
        end
    end
end

-- ROD ENCHANTS
log("=== MY ROD ENCHANTS ===")
pcall(function()
    local eq = PlayerData:Get("EquippedItems") or {}
    for slot, uuid in pairs(eq) do
        local rods = inventory["Fishing Rods"] or {}
        for _, item in ipairs(rods) do
            if tostring(item.UUID) == tostring(uuid) then
                local ok1, data = pcall(IU.GetItemDataFromItemType, "Fishing Rods", item.Id)
                local rodName = ok1 and data and data.Data and data.Data.Name or "id="..tostring(item.Id)
                log("  Slot "..slot..": "..rodName)
                local meta = item.Metadata or {}
                if meta.EnchantId then
                    local ok2, e1 = pcall(function() return IU:GetEnchantData(meta.EnchantId) end)
                    log("    E1 id="..tostring(meta.EnchantId)..": "..(ok2 and e1 and e1.Data and e1.Data.Name or "?"))
                end
                if meta.EnchantId2 then
                    local ok3, e2 = pcall(function() return IU:GetEnchantData(meta.EnchantId2) end)
                    log("    E2 id="..tostring(meta.EnchantId2)..": "..(ok3 and e2 and e2.Data and e2.Data.Name or "?"))
                end
            end
        end
    end
end)

-- ALL GAME ITEMS via IU methods (try both : and . syntax)
local methods = {
    {"ALL FISHING RODS", function() return IU:GetFishingRods() end},
    {"ALL BAITS", function() return IU:GetBaits() end},
    {"ALL HALOS", function() return IU:GetHalos() end},
    {"ALL LANTERNS", function() return IU:GetLanterns() end},
    {"ALL CHARMS", function() return IU:GetCharms() end},
    {"ALL POTIONS", function() return IU:GetPotions() end},
    {"ALL TOTEMS", function() return IU:GetTotems() end},
    {"ALL PETS", function() return IU:GetPets() end},
    {"ALL BOATS", function() return IU:GetBoats() end},
    {"ALL EMOTES", function() return IU:GetEmotes() end},
    {"ALL ABILITIES", function() return IU:GetAbilities() end},
    {"ALL GEARS", function() return IU:GetGears() end},
    {"ALL TROPHIES", function() return IU:GetTrophies() end},
    {"ALL PET EGGS", function() return IU:GetPetEggs() end},
}
for _, m in ipairs(methods) do
    pcall(function()
        local ok, result = pcall(m[2])
        if ok then dumpItems(m[1], result) else log("=== "..m[1].." ERROR: "..tostring(result).." ===") end
    end)
    save()
end

-- ENCHANT STONE POOLS
log("=== ENCHANT STONE POOLS ===")
pcall(function()
    local ok, stones = pcall(function() return IU:GetEnchantStones() end)
    if not ok or type(stones) ~= "table" then log("  error: "..tostring(stones)) return end
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

-- ALL FISH (first 100)
log("=== ALL FISH ===")
pcall(function()
    local ok, fish = pcall(function() return IU:GetFish() end)
    if not ok or type(fish) ~= "table" then log("error: "..tostring(fish)) return end
    for i, f in ipairs(fish) do
        if i > 100 then log("  ...("..#fish-100.." more)"); break end
        if f and f.Data then
            log("  id="..tostring(f.Id or"?").." "..tostring(f.Data.Name or"?").." T"..tostring(f.Data.Tier or"?"))
        end
    end
end)

save(); log("DONE"); save()
