-- Probe: event model names + cleanName test
local out = {}
local function log(s) table.insert(out, s) print(s) end

local function cleanName(n)
    n = n:lower():gsub("^[^%a]*", "")
    n = n:gsub("%s*hunt%s*$", "")
    n = n:gsub("%s*event%s*$", "")
    n = n:match("^%s*(.-)%s*$") or n
    return n
end

-- Find models in Props (where events live based on probe)
local props = workspace:FindFirstChild("Props")
if props then
    log("=== Models in Props ===")
    for _, obj in ipairs(props:GetChildren()) do
        if obj:IsA("Model") then
            log(obj.Name .. " => clean: " .. cleanName(obj.Name))
        end
    end
end

-- Check WorldSetup for event markers
local worldSetup = workspace:FindFirstChild("WorldSetup")
if worldSetup then
    log("=== WorldSetup children ===")
    for _, obj in ipairs(worldSetup:GetChildren()) do
        if obj:IsA("Model") then
            log(obj.Name .. " => clean: " .. cleanName(obj.Name))
        end
    end
end

-- Test EVENT_LIST items vs current workspace
local EVENT_LIST = {
    "Megalodon", "Dark Megalodon", "Thunderzilla",
    "Leviathan", "Void Kraken", "Treasure Hunt"
}
log("=== EVENT_LIST match test ===")
for _, eventName in ipairs(EVENT_LIST) do
    local cleanEvent = cleanName(eventName)
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") then
            local cleanModel = cleanName(obj.Name)
            if cleanModel == cleanEvent then
                log("MATCH: " .. eventName .. " => " .. obj.Name .. " (parent: " .. tostring(obj.Parent and obj.Parent.Name) .. ")")
            end
        end
    end
end

if writefile then writefile("probe.txt", table.concat(out, "\n")) end
