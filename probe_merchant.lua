-- Probe: dump Merchant.Items + MarketItemData structure
local RS = game:GetService("ReplicatedStorage")
local out = {}
local function log(s) table.insert(out, s) end

local ok, Replion = pcall(function() return require(RS.Packages.Replion) end)
if not ok then log("[ERR] Replion: " .. tostring(Replion)) else
    local ok2, mr = pcall(function() return Replion.Client:WaitReplion("Merchant") end)
    if not ok2 then log("[ERR] Merchant replion: " .. tostring(mr)) else
        local ok3, items = pcall(function() return mr:GetExpect("Items") end)
        if ok3 and items then
            log("Merchant.Items count=" .. tostring(#items))
            -- dump raw items
            for i, v in ipairs(items) do
                log("  [" .. i .. "] type=" .. type(v) .. " value=" .. tostring(v))
            end
            -- try to get MarketItemData for each
            log("=== MarketItemData ===")
            for i, itemId in ipairs(items) do
                -- dump all fields
                log("  Item[" .. i .. "] id=" .. tostring(itemId))
            end
        else
            log("[ERR] Items: " .. tostring(items))
        end
    end
end

-- Also try via Net directly
log("=== NET RF CHECK ===")
local ok4, Net = pcall(function() return require(RS.Packages.Net) end)
if ok4 then
    local rf = Net:RemoteFunction("PurchaseMarketItem")
    log("RF found: " .. tostring(rf ~= nil) .. " class=" .. tostring(rf and rf.ClassName or "nil"))
end

local result = table.concat(out, "\n")
if writefile then writefile("merchant_probe.txt", result) end
print(result)
