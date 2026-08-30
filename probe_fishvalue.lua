-- probe_fishvalue.lua: dump ALL fields dari fish itemData untuk cari coin value
local RS = game:GetService("ReplicatedStorage")
local out = {}
local function log(s) table.insert(out, tostring(s)) print(s) end
local function save() if writefile then writefile("probe_fishvalue.txt", table.concat(out, "\n")) end end

local IU = require(RS.Shared.ItemUtility)

-- Recursive dump semua field
local function dumpAll(t, prefix, depth)
    if depth > 4 or type(t) ~= "table" then
        log(prefix .. " = " .. tostring(t))
        return
    end
    for k, v in pairs(t) do
        local key = prefix .. "." .. tostring(k)
        if type(v) == "table" then
            dumpAll(v, key, depth + 1)
        elseif type(v) ~= "function" then
            log(key .. " = " .. tostring(v))
        end
    end
end

-- Ambil 3 fish pertama dari IU:GetFish() dan dump semua fieldnya
log("=== FISH ITEMDATA FULL STRUCTURE ===")
pcall(function()
    local fish = IU:GetFish()
    log("Total fish: " .. tostring(#fish))
    -- Dump fish pertama dari tiap tier
    local seen = {}
    for _, f in ipairs(fish) do
        if f and f.Data then
            local tier = tostring(f.Data.Tier or "?")
            if not seen[tier] then
                seen[tier] = true
                log("\n--- Fish T" .. tier .. ": " .. tostring(f.Data.Name or "?") .. " ---")
                dumpAll(f, "itemData", 0)
            end
        end
        -- Hanya ambil 5 tier pertama
        local count = 0
        for _ in pairs(seen) do count = count + 1 end
        if count >= 5 then break end
    end
end)
save()

-- Cek PlayerStatsUtility methods
log("\n=== PLAYERSTATUTILITY METHODS ===")
pcall(function()
    local PSU = require(RS.Shared.PlayerStatsUtility)
    for k, v in pairs(PSU) do
        if type(v) == "function" then
            log("  " .. tostring(k))
        end
    end
end)
save()

-- Cek Constants — kemungkinan ada fish value table
log("\n=== CONSTANTS FIELDS ===")
pcall(function()
    local C = require(RS.Shared.Constants)
    for k, v in pairs(C) do
        if type(v) ~= "function" then
            if type(v) == "table" then
                log("  " .. tostring(k) .. " = table(" .. #v .. ")")
            else
                log("  " .. tostring(k) .. " = " .. tostring(v))
            end
        end
    end
end)
save()

log("DONE")
save()
