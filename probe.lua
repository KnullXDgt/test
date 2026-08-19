-- Probe: RS.Events Thunderzilla + all hunt events coordinates
local out = {}
local function log(s) table.insert(out, s) print(s) end
local RS = game:GetService("ReplicatedStorage")

local hunts = {"Thunderzilla Hunt","Megalodon Hunt","Dark Megalodon Hunt","Glacial Serpent Hunt"}

for _, name in ipairs(hunts) do
    log("--- " .. name .. " ---")
    local ok, result = pcall(function()
        local ev = RS.Events[name]
        if not ev then log("  RS.Events: not found") return end
        log("  RS.Events: found (class=" .. ev.ClassName .. ")")
        -- Try get Coordinates
        local ok2, coords = pcall(function() return require(ev).Coordinates end)
        if ok2 and coords then
            for i, c in ipairs(coords) do
                log("  Coord[" .. i .. "]: " .. tostring(c))
            end
        else
            log("  Coordinates: " .. tostring(ok2) .. " " .. tostring(coords))
        end
    end)
    if not ok then log("  ERROR: " .. tostring(result)) end
end

-- Also check workspace for any thunderzilla model
log("--- Workspace thunderzilla scan ---")
for _, obj in ipairs(workspace:GetDescendants()) do
    if obj.Name:lower():find("thunderzilla",1,true) then
        log("WS: " .. obj.ClassName .. " | " .. obj.Name)
    end
end

if writefile then writefile("probe.txt", table.concat(out, "\n")) end
