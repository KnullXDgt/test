-- Probe: FULL GAME DUMP v4 - fixed IDs + skins + completed quests
local RS = game:GetService("ReplicatedStorage")
local out = {}
local function log(s) table.insert(out, s) print(s) end
local function save() if writefile then writefile("probe.txt", table.concat(out, "\n")) end end
local function dumpStruct(t, d)
    if d > 2 or type(t) ~= "table" then return tostring(t) end
    local p = {}
    for k,v in pairs(t) do
        if type(v) ~= "table" then table.insert(p, tostring(k).."="..tostring(v)) end
    end
    return "{"..table.concat(p,", ").."}"
end

local ok0, IU = pcall(require, RS.Shared.ItemUtility)
if not ok0 then log("IU fail"); save() return end
local Replion = require(RS.Packages.Replion)
local PlayerData = Replion.Client:WaitReplion("Data")
local inventory = PlayerData and PlayerData:Get("Inventory") or {}

-- Debug: show first rod structure
log("=== DEBUG FIRST ROD STRUCTURE ===")
pcall(function()
    local rods = IU:GetFishingRods()
    if rods and rods[1] then
        log("  First item keys (non-table): "..dumpStruct(rods[1], 0))
        if rods[1].Data then log("  .Data keys: "..dumpStruct(rods[1].Data, 0)) end
    end
end)
save()

local function getItemId(item)
    if not item then return "?" end
    if item.Id then return tostring(item.Id) end
    if item.Identifier then return tostring(item.Identifier) end
    if item.RodId then return tostring(item.RodId) end
    if item.ItemId then return tostring(item.ItemId) end
    if item.Data then
        if item.Data.Id then return tostring(item.Data.Id) end
        if item.Data.Identifier then return tostring(item.Data.Identifier) end
    end
    return "?"
end

local function dumpItems(label, getFn, typeFilter, skinFilter)
    pcall(function()
        local ok, items = pcall(getFn)
        if not ok or type(items) ~= "table" then log("=== "..label.." = ERROR ===") return end
        local filtered = {}
        for _, item in ipairs(items) do
            if type(item)=="table" and item.Data then
                local t = item.Data.Type or item.Data.ItemType or ""
                local isSkin = item.IsSkin == true
                local skinOk = skinFilter == nil or (skinFilter == false and not isSkin) or (skinFilter == true and isSkin)
                if skinOk and (not typeFilter or t == typeFilter or t:lower():find(typeFilter:lower(),1,true)) then
                    table.insert(filtered, item)
                end
            end
        end
        log("=== "..label.." ("..#filtered..") ===")
        for _, item in ipairs(filtered) do
            local name = tostring(item.Data.Name or "?")
            local id = getItemId(item)
            local tier = item.Data.Tier and " T"..tostring(item.Data.Tier) or ""
            log("  id="..id.." "..name..tier)
        end
        save()
    end)
end

-- RARITY
log("=== RARITY TIERS ===")
log("  1=Common, 2=Uncommon, 3=Rare, 4=Epic, 5=Legendary, 6=Mythic, 7=Secret, 8=Forgotten")

-- MY ROD ENCHANTS
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
                    log("    E1: "..(ok2 and e1 and e1.Data and e1.Data.Name or "?").." (id="..tostring(meta.EnchantId)..")")
                end
                if meta.EnchantId2 then
                    local ok3,e2=pcall(function() return IU:GetEnchantData(meta.EnchantId2) end)
                    log("    E2: "..(ok3 and e2 and e2.Data and e2.Data.Name or "?").." (id="..tostring(meta.EnchantId2)..")")
                end
            end
        end
    end
end)

-- GAME ITEMS
dumpItems("ALL FISHING RODS (no skins)", function() return IU:GetFishingRods() end, nil, false)
dumpItems("ALL ROD SKINS", function() return IU:GetFishingRods() end, nil, true)
dumpItems("ALL BAITS (no skins)", function() return IU:GetBaits() end, nil, false)
dumpItems("ALL BAIT SKINS", function() return IU:GetBaits() end, nil, true)
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
dumpItems("ALL PET EGGS", function() return IU:GetPetEggs() end)

-- ENCHANT STONE POOLS
log("=== ENCHANT STONE POOLS ===")
pcall(function()
    local stones = IU:GetEnchantStones()
    for _, stone in ipairs(stones) do
        if stone and stone.Data then
            log("-- "..tostring(stone.Data.Name).." id="..getItemId(stone).." --")
            if stone.Enchants then
                for ename,prob in pairs(stone.Enchants) do
                    log("  "..tostring(ename).." "..tostring(prob).."%")
                end
            end
        end
    end
end)
save()

-- ALL FISH BY TIER
log("=== ALL FISH BY TIER ===")
pcall(function()
    local fish = IU:GetFish()
    log("Total: "..tostring(#fish))
    local byTier = {}
    for _,f in ipairs(fish) do
        if f and f.Data then
            local t = tostring(f.Data.Tier or "?")
            byTier[t] = byTier[t] or {}
            table.insert(byTier[t], (f.Data.Name or "?").."(id="..getItemId(f)..")")
        end
    end
    for tier=1,10 do
        local names = byTier[tostring(tier)]
        if names then log("  T"..tier.." ("..#names.."): "..table.concat(names,", "):sub(1,500)) end
    end
    if byTier["?"] then log("  T? ("..#byTier["?"]..")") end
end)
save()

-- ACTIVE QUESTS
log("=== ACTIVE QUESTS (full) ===")
pcall(function()
    local q = PlayerData:Get("Quests") or {}
    for qtype,qdata in pairs(q) do
        if type(qdata)=="table" then
            for qname,qinfo in pairs(qdata) do
                log("  ["..qtype.."] "..tostring(qname))
                if type(qinfo)=="table" then
                    log("    Step: "..tostring(qinfo.CurrentObj or"?").." | Timestamp: "..tostring(qinfo.Timestamp or"?"))
                    local obj = qinfo.Objectives or {}
                    if type(obj)=="table" then
                        for step,odata in pairs(obj) do
                            if type(odata)=="table" then
                                local p={}
                                for k,v in pairs(odata) do
                                    if type(v)~="table" then table.insert(p, tostring(k).."="..tostring(v)) end
                                end
                                log("    Obj "..step..": "..table.concat(p,", "))
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- COMPLETED QUESTS
log("=== COMPLETED QUESTS ===")
pcall(function()
    local cq = PlayerData:Get("CompletedQuests") or {}
    if type(cq)=="table" then
        log("  Total completed: "..tostring(#cq))
        for _,qname in ipairs(cq) do log("  "..tostring(qname)) end
    end
end)

-- EXPIRED QUESTS
log("=== EXPIRED QUESTS ===")
pcall(function()
    local eq = PlayerData:Get("ExpiredQuests") or {}
    if type(eq)=="table" then
        for _,qname in pairs(eq) do log("  "..tostring(qname)) end
    end
end)

-- ALL GAME QUESTS (from module)
log("=== ALL GAME QUESTS (from module) ===")
pcall(function()
    local QM = require(RS.Modules.Quests)
    if type(QM) ~= "table" then log("  QM load fail") return end
    for _, qtype in ipairs({"Mainline","Event","Side"}) do
        local section = QM[qtype]
        if type(section)=="table" then
            local count=0; for _ in pairs(section) do count=count+1 end
            log("-- "..qtype.." ("..count..") --")
            for qname, qdata in pairs(section) do
                if type(qdata)=="table" then
                    log("  ["..qname.."]")
                    log("    Desc: "..tostring(qdata.Description or "?"))
                    if qdata.AssociatedTier then log("    Tier: "..tostring(qdata.AssociatedTier)) end
                    if qdata.Ordered then log("    Ordered: true") end
                    -- Objectives
                    if type(qdata.Objectives)=="table" then
                        for i, obj in ipairs(qdata.Objectives) do
                            local parts = {}
                            for k,v in pairs(obj) do
                                if type(v)~="table" then table.insert(parts, k.."="..tostring(v)) end
                            end
                            log("    Obj"..i..": "..table.concat(parts,", "))
                        end
                    end
                    -- Reward
                    if type(qdata.Reward)=="table" then
                        local rewards = (type(qdata.Reward[1])=="table") and qdata.Reward or {qdata.Reward}
                        for _, r in ipairs(rewards) do
                            if type(r)=="table" then
                                local rparts={}
                                for k,v in pairs(r) do
                                    if type(v)~="table" then table.insert(rparts, k.."="..tostring(v)) end
                                end
                                log("    Reward: "..table.concat(rparts,", "))
                            end
                        end
                    end
                end
            end
        else
            log("  "..qtype.." = nil")
        end
    end
end)
save()

-- STATS
log("=== STATS ===")
for _,k in ipairs({"Level","XP","Coins","Tix","Tokens","RAP","LoginStreak"}) do
    pcall(function() local v=PlayerData:Get(k); if v~=nil then log("  "..k.."="..tostring(v)) end end)
end
pcall(function()
    local s=PlayerData:Get("Statistics") or {}
    for k,v in pairs(s) do if type(v)~="table" then log("  Stat."..k.."="..tostring(v)) end end
end)

save(); log("DONE"); save()
