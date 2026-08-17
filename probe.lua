-- Probe: listen RE/TotemSpawned, print posisi + jarak player
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local out = {}
local function log(s) table.insert(out, s); print(s) end

local net = RS.Packages._Index["sleitnick_net@0.2.0"].net
local function GetRemote(name)
    local c = net:GetChildren()
    for i, v in ipairs(c) do
        if v.Name == name then return c[i+1] end
    end
end

local totemSpawnedRE = GetRemote("RE/TotemSpawned")
local totemCreatedRE = GetRemote("RE/TotemCreated")
local spawnRE = GetRemote("RE/SpawnTotem")
log("TotemSpawned found=" .. tostring(totemSpawnedRE ~= nil))
log("TotemCreated found=" .. tostring(totemCreatedRE ~= nil))
log("SpawnTotem found=" .. tostring(spawnRE ~= nil))

-- listen events
if totemSpawnedRE then
    totemSpawnedRE.OnClientEvent:Connect(function(pos)
        local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        local playerPos = root and root.Position or Vector3.new(0,0,0)
        local dist = pos and (pos - playerPos).Magnitude or -1
        log("[TotemSpawned] pos=" .. tostring(pos) .. " playerPos=" .. tostring(playerPos) .. " dist=" .. string.format("%.1f", dist))
        if writefile then writefile("probe.txt", table.concat(out, "\n")) end
    end)
end

if totemCreatedRE then
    totemCreatedRE.OnClientEvent:Connect(function(model, totemId)
        local pivot = model and model:GetPivot()
        local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        local playerPos = root and root.Position or Vector3.new(0,0,0)
        local dist = pivot and (pivot.Position - playerPos).Magnitude or -1
        log("[TotemCreated] id=" .. tostring(totemId) .. " pos=" .. tostring(pivot and pivot.Position or "?") .. " dist=" .. string.format("%.1f", dist))
        if writefile then writefile("probe.txt", table.concat(out, "\n")) end
    end)
end

log("Listening... spawn totem now from different distances")
if writefile then writefile("probe.txt", table.concat(out, "\n")) end
