-- Probe: BP currency path + test fire slot 1
local RS = game:GetService("ReplicatedStorage")
local out = {}
local function log(s) table.insert(out, s) end

-- cari BattlepassCurrency path dari RewardInfo
local ok1, RI = pcall(function() return require(RS.Shared.RewardInfo) end)
if ok1 then
    log("RewardInfo keys:")
    for k, v in pairs(RI) do
        local t = type(v)
        if t == "table" then
            log("  " .. k .. " = table:")
            for k2, v2 in pairs(v) do
                if type(v2) ~= "table" and type(v2) ~= "function" then
                    log("    " .. tostring(k2) .. "=" .. tostring(v2))
                end
            end
        elseif t ~= "function" then
            log("  " .. k .. "=" .. tostring(v))
        end
    end
end

-- cek PlayerData path untuk BP currency
local ok2, PlayerData = pcall(function()
    return require(RS.Packages.Replion).Client:WaitReplion("Data")
end)
if ok2 then
    -- try common paths
    for _, path in ipairs({"GalaxyPoints", "BattlepassCurrency", "GalaxyCurrency", "GP", "StarCoins"}) do
        local ok3, val = pcall(function() return PlayerData:Get(path) end)
        if ok3 and val ~= nil then
            log("PlayerData." .. path .. "=" .. tostring(val))
        end
    end
end

-- test fire slot 1 directly
log("=== TEST FIRE SLOT 1 ===")
local ok4, Net = pcall(function() return require(RS.Packages.Net) end)
if ok4 then
    local re = Net:RemoteEvent("BPPurchaseRequest")
    if re then
        local ok5 = pcall(function() re:FireServer(1) end)
        log("FireServer(1) ok=" .. tostring(ok5))
    end
end

local result = table.concat(out, "\n")
if writefile then writefile("probe.txt", result) end
print(result)
