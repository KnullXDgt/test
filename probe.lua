-- Probe: list workspace models that could be events
local out = {}
local function log(s) table.insert(out, s) print(s) end

local keywords = {"event","megalodon","dark","thunderzilla","leviathan","kraken","boss","raid","treasure","hunt"}

log("=== Workspace Models (event-related) ===")
for _, obj in ipairs(workspace:GetDescendants()) do
    if obj:IsA("Model") then
        local lower = obj.Name:lower()
        for _, kw in ipairs(keywords) do
            if lower:find(kw, 1, true) then
                log(obj.Name .. " | parent=" .. tostring(obj.Parent and obj.Parent.Name))
                break
            end
        end
    end
end

log("=== All top-level Models ===")
for _, obj in ipairs(workspace:GetChildren()) do
    if obj:IsA("Model") then
        log("TOP: " .. obj.Name)
    end
end

if writefile then writefile("probe.txt", table.concat(out, "\n")) end
