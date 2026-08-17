-- Probe: dump BlackMarketConfig.GetItems() + item IDs
local RS = game:GetService("ReplicatedStorage")
local out = {}
local function log(s) table.insert(out, s) end

local ok, BMC = pcall(function() return require(RS.Shared.BlackMarketConfig) end)
if not ok then
    log("[ERR] BlackMarketConfig: " .. tostring(BMC))
else
    log("PurchaseRemoteName=" .. tostring(BMC.PurchaseRemoteName))
    log("RequiredLocationName=" .. tostring(BMC.RequiredLocationName))
    log("=== GetItems() ===")
    local ok2, items = pcall(function() return BMC.GetItems() end)
    if ok2 and items then
        for _, item in ipairs(items) do
            local id = tostring(item.Id or "?")
            local name = tostring(item.Name or (item.RewardInfo and item.RewardInfo.Name) or "?")
            local price = tostring(item.Price or "?")
            local currency = tostring(item.Currency or "?")
            log("  id=" .. id .. " name=" .. name .. " price=" .. price .. " currency=" .. currency)
        end
    else
        log("[ERR] GetItems: " .. tostring(items))
        -- try method syntax
        local ok3, items2 = pcall(function() return BMC:GetItems() end)
        if ok3 and items2 then
            for _, item in ipairs(items2) do
                local id = tostring(item.Id or "?")
                local name = tostring(item.Name or (item.RewardInfo and item.RewardInfo.Name) or "?")
                log("  id=" .. id .. " name=" .. name)
            end
        else
            -- dump full BMC table
            log("Full BMC keys:")
            for k, v in pairs(BMC) do
                local t = type(v)
                if t == "function" then
                    log("  [fn] " .. tostring(k))
                elseif t ~= "table" then
                    log("  " .. tostring(k) .. "=" .. tostring(v))
                end
            end
        end
    end
end

local result = table.concat(out, "\n")
if writefile then
    writefile("bm_items_dump.txt", result)
    print("[Probe] Written to bm_items_dump.txt")
else
    print(result)
end
