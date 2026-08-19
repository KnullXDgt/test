-- Probe: watch until thunderzilla found (60s max)
local out = {}
local function log(s) table.insert(out, s) print(s) end
local function save() if writefile then writefile("probe.txt", table.concat(out, "\n")) end end

local function checkObj(obj)
    local lower = obj.Name:lower()
    if lower:find("thunder", 1, true) or lower:find("thunderzilla", 1, true) then
        log("FOUND: " .. obj.ClassName .. " | " .. obj.Name .. " | parent=" .. tostring(obj.Parent and obj.Parent.Name))
        pcall(function()
            if obj:IsA("Model") then
                log("  POS: " .. tostring(obj:GetPivot().Position))
            elseif obj:IsA("BasePart") then
                log("  POS: " .. tostring(obj.Position))
            end
        end)
        save()
        return true
    end
    return false
end

-- Immediate scan
log("=== Immediate scan ===")
local found = false
for _, obj in ipairs(workspace:GetDescendants()) do
    if checkObj(obj) then found = true end
end
if not found then log("Nothing yet, watching...") end
save()

-- Watch DescendantAdded
local conn = workspace.DescendantAdded:Connect(function(obj)
    checkObj(obj)
end)

-- Periodic rescan every 5s for 60s
local elapsed = 0
local function rescan()
    elapsed = elapsed + 5
    log("=== Rescan t=" .. elapsed .. "s ===")
    for _, obj in ipairs(workspace:GetDescendants()) do
        checkObj(obj)
    end
    save()
    if elapsed < 60 then
        task.delay(5, rescan)
    else
        conn:Disconnect()
        log("DONE (60s)")
        save()
    end
end
task.delay(5, rescan)
