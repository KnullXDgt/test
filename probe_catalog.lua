-- Probe: dump actual .Id field dari GetFishingRods + GetBaits
local RS = game:GetService("ReplicatedStorage")
local out = {}
local function log(s) table.insert(out, s) end

local ok, IU = pcall(function() return require(RS.Shared.ItemUtility) end)
if not ok then log("[ERR] " .. tostring(IU)) return end

-- RODS
log("=== RODS (GetFishingRods) ===")
local ok2, rods = pcall(function() return IU:GetFishingRods() end)
if not ok2 then ok2, rods = pcall(function() return IU.GetFishingRods() end) end
if ok2 and rods then
    for _, rod in ipairs(rods) do
        local id = tostring(rod.Id or rod.Data and rod.Data.Id or "?")
        local name = tostring(rod.Data and rod.Data.Name or rod.Name or "?")
        log("  Id=" .. id .. " Name=" .. name)
    end
else
    log("  [ERR] " .. tostring(rods))
end

-- BAITS
log("=== BAITS (GetBaits) ===")
local ok3, baits = pcall(function() return IU:GetBaits() end)
if not ok3 then ok3, baits = pcall(function() return IU.GetBaits() end) end
if ok3 and baits then
    for _, bait in ipairs(baits) do
        local id = tostring(bait.Id or bait.Data and bait.Data.Id or "?")
        local name = tostring(bait.Data and bait.Data.Name or bait.Name or "?")
        log("  Id=" .. id .. " Name=" .. name)
    end
else
    log("  [ERR] " .. tostring(baits))
end

-- BP Config path
log("=== BP CONFIG ===")
local ok4, BPC = pcall(function() return require(RS.Modules.BattlepassConfig) end)
if not ok4 then ok4, BPC = pcall(function() return require(RS.Packages.BattlepassConfig) end) end
if ok4 and BPC then
    for k, v in pairs(BPC) do
        if type(v) ~= "table" and type(v) ~= "function" then
            log("  " .. tostring(k) .. "=" .. tostring(v))
        end
    end
else
    log("  [ERR] " .. tostring(BPC))
    -- try find in workspace
    for _, v in ipairs(RS:GetDescendants()) do
        if v.Name:lower():find("battlepass") and v.Name:lower():find("config") then
            log("  Found: " .. v:GetFullName())
        end
    end
end

local result = table.concat(out, "\n")
if writefile then writefile("catalog_probe.txt", result) end
print(result)
