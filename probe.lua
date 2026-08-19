-- Probe: FULL GAME DUMP v3
local RS = game:GetService("ReplicatedStorage")
local out = {}
local function log(s) table.insert(out, s) print(s) end
local function save() if writefile then writefile("probe.txt", table.concat(out, "\n")) end end

local ok0, IU = pcall(require, RS.Shared.ItemUtility)
if not ok0 then log("IU fail"); save() return end
local Replion = require(RS.Packages.Replion)
local PlayerData = Replion.Client:WaitReplion("Data")
local inventory = PlayerData and PlayerData:Get("Inventory") or {}

local function dumpItems(label, getFn)
    pcall(function()
        local ok, items = pcall(getFn)
        if not ok or type(items) ~= "table" then log("=== "..label.." = ERROR ===") return end
        log("=== "..label.." ("..tostring(#items)..") ===")
        for _, item in ipairs(items) do
            if type(item)=="table" and item.Data then
                local name = tostring(item.Data.Name or "?")
                local id = tostring(item.Id or "?")
                local tier = item.Data.Tier and (" T"..tostring(item.Data.Tier)) or ""
                local prob = item.Probability and (" "..string.format("1/%d",math.floor(1/item.Probability.Chance+0.5))) or ""
                log("  id="..id.." "..name..tier..prob)
            end
        end
        save()
    end)
end

-- RARITY TABLE
log("=== RARITY TIERS ===")
log("  1=Common 2=Uncommon 3=Rare 4=Epic 5=Legendary 6=Mythic 7=Secret 8=Forgotten")
pcall(function()
    local tiers = IU:GetTierFromRarity and {} or nil
    local RARITY = {Common=1,Uncommon=2,Rare=3,Epic=4,Legendary=5,Mythic=6,Secret=7,Forgotten=8}
    for name,tier in pairs(RARITY) do log("  "..tier.."="..name) end
end)

-- ROD ENCHANTS
log("=== MY ROD ENCHANTS ===")
pcall(function()
    local eq = PlayerData:Get("EquippedItems") or {}
    for slot, uuid in pairs(eq) do
        local rods = inventory["Fishing Rods"] or {}
        for _, item in ipairs(rods) do
            if tostring(item.UUID)==tostring(uuid) then
                local ok1,data=pcall(IU.GetItemDataFromItemType,"Fishing Rods",item.Id)
                local rodName = ok1 and data and data.Data and data.Data.Name or "id="..tostring(item.Id)
                log("  Slot "..slot..": "..rodName)
                local meta = item.Metadata or {}
                if meta.EnchantId then
                    local ok2,e1=pcall(function() return IU:GetEnchantData(meta.EnchantId) end)
                    log("    E1("..meta.EnchantId.."): "..(ok2 and e1 and e1.Data and e1.Data.Name or "?"))
                end
                if meta.EnchantId2 then
                    local ok3,e2=pcall(function() return IU:GetEnchantData(meta.EnchantId2) end)
                    log("    E2("..meta.EnchantId2.."): "..(ok3 and e2 and e2.Data and e2.Data.Name or "?"))
                end
            end
        end
    end
end)

-- ALL GAME ITEMS
dumpItems("ALL FISHING RODS", function() return IU:GetFishingRods() end)
dumpItems("ALL BAITS", function() return IU:GetBaits() end)
dumpItems("ALL HALOS", function() return IU:GetHalos() end)
dumpItems("ALL LANTERNS", function() return IU:GetLanterns() end)
dumpItems("ALL CHARMS", function() return IU:GetCharms() end)
dumpItems("ALL POTIONS", function() return IU:GetPotions() end)
dumpItems("ALL TOTEMS", function() return IU:GetTotems() end)
dumpItems("ALL PETS", function() return IU:GetPets() end)
dumpItems("ALL BOATS", function() return IU:GetBoats() end)
dumpItems("ALL EMOTES", function() return IU:GetEmotes() end)
dumpItems("ALL ABILITIES", function() return IU:GetAbilities() end)
dumpItems("ALL GEARS", function() return IU:GetGears() end)
dumpItems("ALL TROPHIES", function() return IU:GetTrophies() end)
dumpItems("ALL PET EGGS", function() return IU:GetPetEggs() end)

-- ENCHANT STONE POOLS
log("=== ENCHANT STONE POOLS ===")
pcall(function()
    local stones = IU:GetEnchantStones()
    for _, stone in ipairs(stones) do
        if stone and stone.Data then
            log("-- "..tostring(stone.Data.Name).." id="..tostring(stone.Id or"?").." --")
            if stone.Enchants then
                for ename,prob in pairs(stone.Enchants) do
                    log("  "..tostring(ename).." "..tostring(prob).."%")
                end
            end
        end
    end
end)
save()

-- ALL FISH
log("=== ALL FISH (by tier) ===")
pcall(function()
    local fish = IU:GetFish()
    log("Total fish: "..tostring(#fish))
    local byTier = {}
    for _,f in ipairs(fish) do
        if f and f.Data then
            local t = tostring(f.Data.Tier or "?")
            byTier[t] = byTier[t] or {}
            table.insert(byTier[t], f.Data.Name or "?")
        end
    end
    for tier,names in pairs(byTier) do
        log("  Tier "..tier..": "..table.concat(names,", "):sub(1,200))
    end
end)
save()

-- QUESTS
log("=== QUESTS ===")
pcall(function()
    local quests = PlayerData:Get("Quests")
    if type(quests)=="table" then
        for qtype, qdata in pairs(quests) do
            log("  ["..qtype.."]")
            if type(qdata)=="table" then
                for qname, qinfo in pairs(qdata) do
                    log("    "..tostring(qname))
                    if type(qinfo)=="table" then
                        local obj = qinfo.Objectives or {}
                        if type(obj)=="table" then
                            local total = 0
                            for _ in pairs(obj) do total=total+1 end
                            log("      Objectives: "..total.." | Step: "..tostring(qinfo.CurrentObj or"?"))
                        end
                    end
                end
            end
        end
    end
end)

-- KEY STATS
log("=== KEY STATS ===")
for _,k in ipairs({"Level","XP","Coins","Tix","Tokens","RAP","LoginStreak","Statistics"}) do
    pcall(function()
        local v = PlayerData:Get(k)
        if type(v)=="table" then
            local p={}; for k2,v2 in pairs(v) do table.insert(p,k2.."="..tostring(v2)) end
            log("  "..k.."="..table.concat(p,", "):sub(1,300))
        elseif v~=nil then log("  "..k.."="..tostring(v)) end
    end)
end

save(); log("DONE"); save()
