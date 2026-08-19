-- Probe: check RS.Events coordinates + workspace model pos for all events
local out = {}
local function log(s) table.insert(out, s) print(s) end
local RS = game:GetService("ReplicatedStorage")

local EVENT_LIST = {
    "Dark Megalodon Hunt","Glacial Serpent Hunt","Megalodon Hunt","Thunderzilla Hunt"
}

for _, eventName in ipairs(EVENT_LIST) do
    log("--- " .. eventName .. " ---")
    -- Check RS.Events coordinates
    pcall(function()
        local ev = RS.Events[eventName]
        if ev then
            local coords = ev.Coordinates
            if coords and #coords > 0 then
                for i, c in ipairs(coords) do
                    log("  RS.Events coord[" .. i .. "]: " .. tostring(c))
                end
            else
                log("  RS.Events: Coordinates nil or empty")
            end
        else
            log("  RS.Events: not found")
        end
    end)
    -- Check workspace model position
    local lowerName = eventName:lower():gsub(" hunt", "")
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name:lower():find(lowerName, 1, true) then
            log("  Workspace model: " .. obj.Name .. " @ " .. tostring(obj:GetPivot().Position))
        end
    end
end

if writefile then writefile("probe.txt", table.concat(out, "\n")) end
