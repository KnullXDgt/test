-- Probe: exact match test for EVENT_LIST vs workspace
local out = {}
local function log(s) table.insert(out, s) print(s) end

local EVENT_LIST = {
    "Admin - 1x1x1 Rage","Admin - 2025 Anniversary","Admin - 2025 Christmas",
    "Admin - 2026 Valentines","Admin - 3RR0R 3V3NT","Admin - Bermuda Triangle",
    "Admin - Black Hole","Admin - Bloodmoon","Admin - Frostmoon",
    "Admin - Ghost Worm","Admin - Leviathan Awakening","Admin - Meteor Rain",
    "Admin - Purple Bloodmoon","Admin - Volcano Eruption",
    "Dark Megalodon Hunt","Glacial Serpent Hunt","Megalodon Hunt","Thunderzilla Hunt"
}

log("=== EXACT MATCH test ===")
for _, eventName in ipairs(EVENT_LIST) do
    local lowerName = eventName:lower()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name:lower() == lowerName then
            log("EXACT: " .. eventName .. " => " .. obj.Name .. " @ " .. tostring(obj:GetPivot().Position))
        end
    end
end

log("=== All Models in Props ===")
local props = workspace:FindFirstChild("Props")
if props then
    for _, obj in ipairs(props:GetDescendants()) do
        if obj:IsA("Model") then
            log("Props/" .. tostring(obj.Parent and obj.Parent.Name) .. "/" .. obj.Name)
        end
    end
end

if writefile then writefile("probe.txt", table.concat(out, "\n")) end
