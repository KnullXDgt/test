-- Probe: EventsReplion data for active events + position
local out = {}
local function log(s) table.insert(out, s) print(s) end
local function save() if writefile then writefile("probe.txt", table.concat(out, "\n")) end end

local function dumpVal(v, depth)
    if depth > 3 then return "..." end
    if type(v) == "table" then
        local p = {}
        for k, val in pairs(v) do
            table.insert(p, tostring(k) .. "=" .. dumpVal(val, depth+1))
        end
        return "{" .. table.concat(p, ", ") .. "}"
    end
    return tostring(v)
end

local RS = game:GetService("ReplicatedStorage")
local Replion = require(RS.Packages.Replion)

local er = nil
pcall(function() er = Replion.Client:WaitReplion("Events") end)
if not er then log("EventsReplion not found") save() return end

log("EventsReplion found")

-- Dump all top-level keys
local data = nil
pcall(function() data = er:Get() end)
if data then
    log("Top keys:")
    for k, v in pairs(data) do
        log("  [" .. tostring(k) .. "] type=" .. type(v) .. " val=" .. dumpVal(v, 0):sub(1, 200))
    end
else
    log("Get() returned nil")
end

-- Try common event-related paths
local paths = {"Active", "Events", "CurrentEvents", "ActiveEvents", "Hunts", "WeatherMachine"}
for _, p in ipairs(paths) do
    local ok, val = pcall(function() return er:Get(p) end)
    if ok and val ~= nil then
        log("Path [" .. p .. "]: " .. dumpVal(val, 0):sub(1, 300))
    end
end

save()
