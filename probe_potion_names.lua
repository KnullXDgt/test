-- Probe: resolve potion names via ItemUtility
local RS = game:GetService("ReplicatedStorage")
local out = {}
local function log(s) table.insert(out, s) end

local ok, IU = pcall(function() return require(RS.Shared.ItemUtility) end)
if not ok then log("[ERR] " .. tostring(IU)) else
    local potionIds = {18, 27, 28, 32, 33, 34, 36, 38}
    for _, id in ipairs(potionIds) do
        local ok2, data = pcall(function() return IU.GetItemDataFromItemType("Potions", id) end)
        local name = (ok2 and data and data.Data and data.Data.Name) or "?"
        log("PotionId=" .. id .. " Name=" .. name)
    end
    -- emote id 28
    local ok3, emote = pcall(function() return IU.GetItemDataFromItemType("Emotes", 28) end)
    local emoteName = (ok3 and emote and emote.Data and emote.Data.Name) or "?"
    log("EmoteId=28 Name=" .. emoteName)
end

local result = table.concat(out, "\n")
if writefile then writefile("potion_names.txt", result) end
print(result)
