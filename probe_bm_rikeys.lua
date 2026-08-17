-- Probe: dump all RewardInfo fields + resolve name via ItemUtility
local RS = game:GetService("ReplicatedStorage")
local out = {}
local function log(s) table.insert(out, s) end

local ok, BMC = pcall(function() return require(RS.Shared.BlackMarketConfig) end)
local ok2, IU = pcall(function() return require(RS.Shared.ItemUtility) end)

if ok then
    local ok3, items = pcall(function() return BMC.GetItems() end)
    if ok3 and items then
        for _, item in ipairs(items) do
            log("--- " .. tostring(item.Id) .. " ---")
            local ri = item.RewardInfo or {}
            -- dump all RewardInfo keys
            for k, v in pairs(ri) do
                log("  RI." .. tostring(k) .. "=" .. tostring(v))
            end
            -- try resolve name via ItemUtility
            if ok2 and IU and ri.Type then
                for _, keyname in ipairs({"Id","ItemId","Name","ItemType","index"}) do
                    local rid = ri[keyname]
                    if rid then
                        local ok4, data = pcall(function()
                            return IU.GetItemDataFromItemType(ri.Type, rid)
                        end)
                        if ok4 and data and data.Data then
                            log("  -> Name=" .. tostring(data.Data.Name or "?"))
                            break
                        end
                    end
                end
            end
        end
    end
end

local result = table.concat(out, "\n")
if writefile then writefile("bm_rikeys.txt", result) end
print(result)
