-- Probe: print current CFrame + nearby NPCs/Models
-- Jalankan saat berdiri di depan Black Market dealer
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local lp = Players.LocalPlayer
local root = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")

local out = {}
local function log(s) table.insert(out, s) end

if root then
    local cf = root.CFrame
    local x,y,z,r00,r01,r02,r10,r11,r12,r20,r21,r22 = cf:GetComponents()
    log("=== CURRENT POSITION ===")
    log(string.format("CFrame.new(%.5f, %.5f, %.5f, %.10f, %.10f, %.10f, %.10f, %.10f, %.10f, %.10f, %.10f, %.10f)",
        x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22))
    log(string.format("Pos: X=%.2f Y=%.2f Z=%.2f", x, y, z))
else
    log("[ERR] No HumanoidRootPart found")
end

-- Nearby models in workspace (radius 30 studs)
log("=== NEARBY MODELS (radius 30) ===")
if root then
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.PrimaryPart then
            local dist = (obj.PrimaryPart.Position - root.Position).Magnitude
            if dist < 30 then
                log(string.format("  [%.1f] %s", dist, obj.Name))
            end
        end
    end
end

local result = table.concat(out, "\n")
if writefile then
    writefile("cframe_probe.txt", result)
    print("[Probe] Written to cframe_probe.txt")
end
print(result)
