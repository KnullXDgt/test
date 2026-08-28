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
