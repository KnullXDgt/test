-- probe2.lua: enchant/equip/transcended logger (Delta-safe)
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local out = {}
local function log(s)
    local msg = "[" .. tostring(math.floor(workspace.DistributedGameTime*10)/10) .. "] " .. tostring(s)
    table.insert(out, msg)
    print(msg)
end
local function save()
    if writefile then writefile("probe2.txt", table.concat(out, "\n")) end
end

log("probe2 starting...")
save()

-- Resolve remotes using same pattern as test.lua
local net = RS.Packages._Index["sleitnick_net@0.2.0"].net
local function resolve(name)
    local all = net:GetChildren()
    for i = 1, #all do
        if all[i].Name == name then
            local next = all[i + 1]
            if next then return next end
        end
    end
    return nil
end

local remEquipItem    = resolve("RE/EquipItem")
local remEquipTool    = resolve("RE/EquipToolFromHotbar")
local remEnchant1     = resolve("RE/ActivateEnchantingAltar")
local remEnchant2     = resolve("RE/ActivateSecondEnchantingAltar")
local remRollEnchant  = resolve("RE/RollEnchant")
local remUpdateState  = resolve("RE/UpdateEnchantState")
local remTranscended  = resolve("RF/CreateTranscendedStone")

log("Remotes resolved:")
log("  EquipItem: " .. tostring(remEquipItem ~= nil))
log("  EquipToolFromHotbar: " .. tostring(remEquipTool ~= nil))
log("  ActivateEnchantingAltar: " .. tostring(remEnchant1 ~= nil))
log("  ActivateSecondEnchantingAltar: " .. tostring(remEnchant2 ~= nil))
log("  RollEnchant: " .. tostring(remRollEnchant ~= nil))
log("  UpdateEnchantState: " .. tostring(remUpdateState ~= nil))
log("  CreateTranscendedStone: " .. tostring(remTranscended ~= nil))
save()

-- Replion
local Replion = require(RS.Packages.Replion)
local PD = Replion.Client:WaitReplion("Data")
log("Replion ready")

-- Log current state
log("=== INITIAL STATE ===")
log("EquippedId = " .. tostring(PD:Get("EquippedId")))
log("EquippedType = " .. tostring(PD:Get("EquippedType")))
local eq = PD:Get("EquippedItems") or {}
if type(eq) == "table" then
    local parts = {}
    for i = 1, #eq do table.insert(parts, "[" .. i .. "]=" .. tostring(eq[i])) end
    log("EquippedItems = {" .. table.concat(parts, ", ") .. "}")
end
log("=====================")
save()

-- Watch Replion state
PD:OnChange("EquippedId", function(v)
    log("[Replion] EquippedId -> " .. tostring(v))
    save()
end)
PD:OnChange("EquippedType", function(v)
    log("[Replion] EquippedType -> " .. tostring(v))
    save()
end)
PD:OnChange("EquippedItems", function(v)
    if type(v) == "table" then
        local parts = {}
        for i = 1, #v do table.insert(parts, "[" .. i .. "]=" .. tostring(v[i])) end
        log("[Replion] EquippedItems -> {" .. table.concat(parts, ", ") .. "}")
    else
        log("[Replion] EquippedItems -> " .. tostring(v))
    end
    save()
end)

-- Hook OnClientEvent
local function hookCE(remote, name)
    if not remote then log("SKIP CE (nil): " .. name) return end
    if not remote:IsA("RemoteEvent") then log("SKIP CE (not RE): " .. name) return end
    remote.OnClientEvent:Connect(function(...)
        local args = {...}
        local parts = {}
        for i, v in ipairs(args) do
            local s = "?"
            pcall(function()
                if typeof(v) == "Instance" then s = v.ClassName .. ":" .. v.Name
                elseif type(v) == "table" then
                    local tp = {}
                    for k, val in pairs(v) do
                        if type(val) ~= "table" then
                            table.insert(tp, tostring(k) .. "=" .. tostring(val))
                        end
                    end
                    s = "{" .. table.concat(tp, ",") .. "}"
                else s = tostring(v) end
            end)
            table.insert(parts, "[" .. i .. "]=" .. s)
        end
        log("[CE] " .. name .. " | " .. table.concat(parts, " "))
        save()
    end)
    log("Hooked: " .. name)
end

hookCE(remRollEnchant, "RE/RollEnchant")
hookCE(remUpdateState, "RE/UpdateEnchantState")

save()
log("=== probe2 ready ===")
log("Now manually: equip stone -> activate altar -> equip fish -> create transcended")
save()
-- === EXTRA LISTENERS ===

-- Watch rod enchant changes (E1/E2)
local IU = require(RS.Shared.ItemUtility)
local function getRodEnchants()
    local inv = PD:Get("Inventory") or {}
    local eq = PD:Get("EquippedItems") or {}
    local equippedSet = {}
    for i = 1, #eq do equippedSet[tostring(eq[i])] = true end
    for cat, items in pairs(inv) do
        if type(items) == "table" then
            for _, item in ipairs(items) do
                if equippedSet[tostring(item.UUID)] then
                    local d = IU.GetItemDataFromItemType(cat, item.Id)
                    if d and d.Data and d.Data.Type == "Fishing Rods" then
                        local e1, e2 = "none", "none"
                        local meta = item.Metadata or {}
                        if meta.EnchantId then
                            local ok, ed = pcall(function() return IU:GetEnchantData(meta.EnchantId) end)
                            if ok and ed and ed.Data then e1 = ed.Data.Name.." (id="..tostring(meta.EnchantId)..")" end
                        end
                        if meta.EnchantId2 then
                            local ok, ed = pcall(function() return IU:GetEnchantData(meta.EnchantId2) end)
                            if ok and ed and ed.Data then e2 = ed.Data.Name.." (id="..tostring(meta.EnchantId2)..")" end
                        end
                        return d.Data.Name, e1, e2
                    end
                end
            end
        end
    end
    return "?", "none", "none"
end

-- Log current rod state
local rodName, e1, e2 = getRodEnchants()
log("=== ROD STATE ===")
log("Rod: "..rodName)
log("E1: "..e1)
log("E2: "..e2)
log("=================")
save()

-- Watch Fishing Rods inventory changes
PD:OnChange({"Inventory", "Fishing Rods"}, function()
    local rn, re1, re2 = getRodEnchants()
    log("[ROD CHANGE] " .. rn .. " | E1=" .. re1 .. " | E2=" .. re2)
    save()
end)

-- Watch Enchant Stones inventory changes
PD:OnChange({"Inventory", "Enchant Stones"}, function()
    local inv = PD:Get("Inventory") or {}
    local stones = inv["Enchant Stones"] or {}
    local counts = {}
    for _, s in ipairs(stones) do
        local key = tostring(s.Id)
        counts[key] = (counts[key] or 0) + 1
    end
    local parts = {}
    for id, cnt in pairs(counts) do table.insert(parts, "id="..id.."x"..cnt) end
    log("[STONE CHANGE] " .. table.concat(parts, ", "))
    save()
end)

-- Watch Fish inventory changes  
PD:OnChange({"Inventory", "Fish"}, function()
    log("[FISH CHANGE] fish inventory updated")
    save()
end)

-- Fix RollEnchant listener - capture ALL args correctly
-- arg[1]=extra, arg[2]=enchantId, arg[3]=stoneId, arg[4]=isSpecial
if remRollEnchant then
    remRollEnchant.OnClientEvent:Connect(function(a1, a2, a3, a4)
        local enchName = "?"
        pcall(function()
            local d = IU:GetEnchantData(a2)
            if d and d.Data then enchName = d.Data.Name end
        end)
        log("[ROLL] extra="..tostring(a1).." enchantId="..tostring(a2).."("..enchName..") stoneId="..tostring(a3).." special="..tostring(a4))
        save()
    end)
    log("Hooked RollEnchant (full args)")
end

log("Extra listeners active")
save()

