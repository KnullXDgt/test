-- probe2.lua: enchant/equip/transcended state logger (Delta-safe, no hooks)
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local out = {}
local function log(s)
    local ts = string.format("[%.2f] %s", workspace.DistributedGameTime, tostring(s))
    table.insert(out, ts)
    print(ts)
end
local function save()
    if writefile then writefile("probe2.txt", table.concat(out, "\n")) end
end
local function dumpVal(v)
    if v == nil then return "nil" end
    local ok, s = pcall(function()
        if typeof(v) == "Instance" then return v.ClassName..":"..v.Name end
        if type(v) == "table" then
            local parts = {}
            for k,val in pairs(v) do
                if type(val) ~= "table" then
                    table.insert(parts, tostring(k).."="..tostring(val))
                end
            end
            return "{"..table.concat(parts,",").."}"
        end
        return tostring(v)
    end)
    return ok and s or "?"
end

-- Resolve remotes
local net = RS.Packages._Index["sleitnick_net@0.2.0"].net
local R = {}
local children = net:GetChildren()
for i = 1, #children - 1 do
    local a, b = children[i], children[i+1]
    if a and b and #b.Name == 67 then
        local la = a.Name:lower()
        if la:sub(1,3)=="rf/" or la:sub(1,3)=="re/" then
            R[a.Name] = b
        end
    end
end
local rCount=0; for _ in pairs(R) do rCount=rCount+1 end; log("Resolved "..rCount.." remotes")

-- Replion state listener
local Replion = require(RS.Packages.Replion)
local PlayerData = Replion.Client:WaitReplion("Data")
log("Replion ready")

-- Watch equip state changes
PlayerData:OnChange("EquippedId", function(v)
    log("[Replion] EquippedId = "..tostring(v))
    save()
end)
PlayerData:OnChange("EquippedType", function(v)
    log("[Replion] EquippedType = "..tostring(v))
    save()
end)
PlayerData:OnChange("EquippedItems", function(v)
    if type(v) == "table" then
        local parts = {}
        for i, uuid in ipairs(v) do
            table.insert(parts, "["..i.."]="..tostring(uuid))
        end
        log("[Replion] EquippedItems = {"..table.concat(parts,", ").."}")
    else
        log("[Replion] EquippedItems = "..tostring(v))
    end
    save()
end)
PlayerData:OnChange("EquippedBaitId", function(v)
    log("[Replion] EquippedBaitId = "..tostring(v))
    save()
end)

-- Log initial state
local function logCurrentState()
    log("--- CURRENT STATE ---")
    log("  EquippedId = "..tostring(PlayerData:Get("EquippedId")))
    log("  EquippedType = "..tostring(PlayerData:Get("EquippedType")))
    local eq = PlayerData:Get("EquippedItems") or {}
    if type(eq) == "table" then
        local parts = {}
        for i,uuid in ipairs(eq) do table.insert(parts, "["..i.."]="..tostring(uuid)) end
        log("  EquippedItems = {"..table.concat(parts,", ").."}")
    end
    log("---------------------")
    save()
end
logCurrentState()

-- OnClientEvent listeners
local targets = {
    "RE/RollEnchant",
    "RE/UpdateEnchantState",
    "RE/ActivateEnchantingAltar",
    "RE/ActivateSecondEnchantingAltar",
    "RE/FishCaught",
    "RE/EquipToolFromHotbar",
    "RE/EquipItem",
}
for _, name in ipairs(targets) do
    local remote = R[name]
    if remote and remote:IsA("RemoteEvent") then
        remote.OnClientEvent:Connect(function(...)
            local args = {...}
            local parts = {}
            for i, v in ipairs(args) do
                table.insert(parts, "["..i.."]="..dumpVal(v))
            end
            log("[CE] "..name.." | "..table.concat(parts," "))
            save()
        end)
        log("Hooked OnClientEvent: "..name)
    else
        log("NOT FOUND or not RE: "..name)
    end
end

-- Poll EquippedId every 0.5s for 60 seconds (catch fast changes)
task.spawn(function()
    local lastId = PlayerData:Get("EquippedId")
    local lastType = PlayerData:Get("EquippedType")
    for _ = 1, 120 do
        task.wait(0.5)
        local id = PlayerData:Get("EquippedId")
        local tp = PlayerData:Get("EquippedType")
        if id ~= lastId or tp ~= lastType then
            log("[POLL] EquippedId="..tostring(id).." EquippedType="..tostring(tp))
            save()
            lastId = id
            lastType = tp
        end
    end
    log("Poll ended (60s)")
    save()
end)

log("probe2 ready — now manually: equip stone, activate altar, equip fish, create transcended")
save()
