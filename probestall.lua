-- Orvion R19 stall probe. Observe only; no remotes, hooks, setters or GC scan.
-- Run alongside the stalled hub. Leave toggles untouched for 20 seconds.
do
    local P = { lines = {}, roots = {}, queue = {}, seen = {}, conns = {}, last = {}, start = os.clock() }
    local RS = game:GetService("ReplicatedStorage")
    local LP = game:GetService("Players").LocalPlayer
    local function fmt(v, depth, seen)
        depth = depth or 0
        if type(v) ~= "table" then
            if type(v) == "thread" then
                local ok, status = pcall(coroutine.status, v)
                return "thread:" .. (ok and status or "unknown")
            end
            return tostring(v)
        end
        if depth >= 3 then return "{...}" end
        seen = seen or {}
        if seen[v] then return "{cycle}" end
        seen[v] = true
        local out, count = {}, 0
        for k, value in next, v do
            count = count + 1
            if count > 24 then out[#out + 1] = "...truncated" break end
            if type(k) == "string" or type(k) == "number" then
                out[#out + 1] = tostring(k) .. "=" .. fmt(value, depth + 1, seen)
            end
        end
        table.sort(out)
        seen[v] = nil
        return "{" .. table.concat(out, ", ") .. "}"
    end
    local function log(k, v)
        local line = string.format("[%.2fs] %s: %s", os.clock() - P.start, k, fmt(v))
        P.lines[#P.lines + 1] = line
        print(line)
    end
    local stamp = tostring(os.time()) .. "_" .. tostring(math.floor(os.clock() * 1000))
    local output = "Orvion_StallProbe_" .. stamp .. ".txt"
    local function save()
        if type(writefile) ~= "function" then return false end
        return pcall(writefile, output, table.concat(P.lines, "\n"))
    end
    local function change(k, v)
        local text = fmt(v)
        if P.last[k] ~= text then P.last[k] = text log(k, text) end
    end
    local function enqueue(v, depth)
        if (type(v) == "function" or type(v) == "table") and not P.seen[v]
            and #P.queue < 500 and depth <= 6 then
            P.seen[v] = true
            P.queue[#P.queue + 1] = {v, depth}
        end
    end
    local function fields(t, names)
        local result = {}
        for _, k in ipairs(names) do
            if type(t) == "table" then result[k] = rawget(t, k) end
        end
        return result
    end
    local function seedSignal(signal, label)
        if type(getconnections) ~= "function" then return end
        local ok, connections = pcall(getconnections, signal)
        if not ok then return end
        local n = 0
        for _, conn in pairs(connections) do
            n = n + 1
            if n > 40 then break end
            pcall(function() enqueue(conn.Function, 0) end)
        end
        log("connections " .. label, n)
    end
    log("PROBE", "R1 / observe-only / 20 seconds / do not toggle or re-execute hub")
    log("capabilities", {getconnections=type(getconnections), upvalues=type(debug and debug.getupvalues), upvalue=type(debug and debug.getupvalue)})
    save()
    local packages = RS:FindFirstChild("Packages")
    local controllers = RS:FindFirstChild("Controllers")
    -- These are already loaded by test2; require uses the existing module cache.
    if packages and packages:FindFirstChild("Replion") then
        pcall(function()
            local replion = require(packages.Replion)
            P.data = replion.Client:GetReplion("Data")
        end)
    end
    for _, name in ipairs({"AnimationController", "FishingController"}) do
        if controllers and controllers:FindFirstChild(name) then
            local ok, value = pcall(require, controllers[name])
            if ok then
                if name == "FishingController" then P.controller = value end
                enqueue(value, 0)
            else log(name, "unavailable") end
        end
    end
    local index = packages and packages:FindFirstChild("_Index")
    local pkg = index and index:FindFirstChild("sleitnick_net@0.2.0")
    local net = pkg and pkg:FindFirstChild("net")
    if net then
        local children = net:GetChildren()
        for i, child in ipairs(children) do
            if child.Name == "RE/FishCaught" or child.Name == "RE/BaitCastVisual"
                or child.Name == "RE/EquipToolFromHotbar" or child.Name == "RF/ChargeFishingRod"
                or child.Name == "RF/CancelFishingInputs" then
                log("remote marker", {name=child.Name, class=child.ClassName,
                    nextName=children[i+1] and children[i+1].Name,
                    nextClass=children[i+1] and children[i+1].ClassName})
                if child.Name == "RE/FishCaught" or child.Name == "RE/BaitCastVisual" then
                    for j = i, math.min(i + 1, #children) do
                        if children[j]:IsA("RemoteEvent") then
                            seedSignal(children[j].OnClientEvent, children[j].Name)
                        end
                    end
                end
            end
        end
    end
    -- Bounded traversal from known hub callback upvalues only. Never getgc().
    local cursor = 1
    while cursor <= #P.queue do
        local node = P.queue[cursor]
        local value, depth = node[1], node[2]
        if type(value) == "function" then
            if debug and type(debug.getupvalues) == "function" then
                local ok, ups = pcall(debug.getupvalues, value)
                if ok and type(ups) == "table" then
                    local n = 0
                    for _, up in pairs(ups) do
                        n = n + 1 if n > 40 then break end
                        enqueue(up, depth + 1)
                    end
                end
            elseif debug and type(debug.getupvalue) == "function" then
                for i = 1, 30 do
                    local ok, a, b = pcall(debug.getupvalue, value, i)
                    if not ok or (a == nil and b == nil) then break end
                    enqueue(b ~= nil and b or a, depth + 1)
                end
            end
        else
            if type(rawget(value, "Fishing")) == "table" and type(rawget(value, "Sell")) == "table"
                and type(rawget(value, "Quest")) == "table" then P.roots.Runtime = value end
            if type(rawget(value, "V2")) == "table" and type(rawget(value, "V1")) == "table" then P.roots.Modes = value end
            if rawget(value, "AutoSellMode") ~= nil and rawget(value, "CastWait") ~= nil then P.roots.Config = value end
            if type(rawget(value, "setAutoEquipRod")) == "function" then P.roots.Support = value end
            if rawget(value, "Player") and rawget(value, "Replion") then P.data = rawget(value, "Player") end
            if rawget(value, "charge") and rawget(value, "equipTool") then P.roots.Remote = value end
            -- Follow only relevant fields, not arbitrary inventory/UI tables.
            for _, k in ipairs({"PlayAnimation", "RequestChargeFishingRod", "Start", "Stop", "V2", "V1",
                "requestConfiguredCast", "WaitReady", "IsModeActive", "HandleResult", "recheckAutoEquipRod",
                "setAutoEquipRod", "OnFishCaught", "Fishing", "Sell", "Quest", "Runners", "Element", "Execute"}) do
                enqueue(rawget(value, k), depth + 1)
            end
        end
        if cursor % 30 == 0 then task.wait() end
        cursor = cursor + 1
    end
    log("discovery", {nodes=#P.queue, Runtime=P.roots.Runtime ~= nil, Modes=P.roots.Modes ~= nil,
        Config=P.roots.Config ~= nil, Support=P.roots.Support ~= nil, Replion=P.data ~= nil})
    log("LIMIT", "Missing internals means unavailable, NOT false. Suspended thread alone does not prove a hang.")
    local function read(key)
        if not P.data then return nil end
        local ok, value = pcall(function() return P.data:Get(key) end)
        if ok then return value end
        return "READ_ERROR"
    end
    local function threadState(k, thread)
        change(k, thread)
        if type(thread) == "thread" and debug and type(debug.info) == "function" then
            local ok, source, line, name = pcall(debug.info, thread, 1, "sln")
            if ok then change(k .. ".frame", {source=source, line=line, name=name}) end
        end
    end
    local function sample()
        local char = LP.Character
        for _, attr in ipairs({"IsTrading", "SellAll", "Fishing", "IsFishing", "InCutscene"}) do
            change("Player." .. attr, LP:GetAttribute(attr))
            change("Character." .. attr, char and char:GetAttribute(attr))
        end
        local tools = {}
        if char then
            for _, item in ipairs(char:GetChildren()) do
                if item:IsA("Tool") then tools[#tools + 1] = item.Name end
            end
        end
        change("Character.Tools", tools)
        for _, key in ipairs({"EquippedId", "EquippedItems", "AutoFishing", "Level", "UnlockedTemple", "TempleLevers"}) do
            change("Replion." .. key, read(key))
        end
        local quests = read("Quests")
        change("Element.Progress", type(quests) == "table" and type(quests.Mainline) == "table" and quests.Mainline["Element Quest"] or "absent/unavailable")
        local inventory = read("Inventory")
        if type(inventory) == "table" then
            local counts, rods, selected = {}, {}, {}
            local wanted = tostring(read("EquippedId") or "")
            for category, entries in pairs(inventory) do
                if type(entries) == "table" then
                    local n = 0
                    for _, item in pairs(entries) do
                        n = n + 1
                        if type(item) == "table" then
                            if category == "Fishing Rods" and #rods < 20 then rods[#rods + 1] = fields(item, {"Id", "UUID"}) end
                            if wanted ~= "" and tostring(item.UUID) == wanted then selected = {category=category, id=item.Id, uuid=item.UUID} end
                        end
                    end
                    counts[category] = n
                end
            end
            change("Inventory.Counts", counts) change("Inventory.Rods", rods) change("EquippedId.Resolve", selected)
        end
        local R, M, C, S = P.roots.Runtime, P.roots.Modes, P.roots.Config, P.roots.Support
        if R then
            change("Fishing", fields(R.Fishing, {"Phase", "Owner", "CatchSerial", "LastCatchAt", "Failures"}))
            change("Sell", fields(R.Sell, {"Busy", "Pending", "Phase", "Reason", "Ticket"}))
            change("Quest", fields(R.Quest, {"Enabled", "Paused", "SellHold", "HoldTokens", "HoldMeta", "Action", "Sessions"}))
            threadState("Sell.Worker", R.Sell.Worker) threadState("Sell.Thread", R.Sell.Thread)
            threadState("Quest.Element.Thread", R.Quest.Threads and R.Quest.Threads.Element)
        end
        if M then
            change("Modes", {Active=M.Active, V2=fields(M.V2, {"Active", "Delay"})})
            threadState("V2.Thread", M.V2.Thread)
        end
        if C then change("Config", fields(C, {"AutoSell", "AutoSellMode", "SellDelay", "InstantFishing", "BlatantActive"})) end
        if S then
            change("AutoEquip", fields(S, {"autoEquipRodEnabled"}))
            local ok, connected = pcall(function() return S.autoEquipRodConn.Connected end)
            change("AutoEquip.Connection", ok and tostring(connected) or "not exposed")
        end
        if type(P.controller) == "table" then
            change("Controller", fields(P.controller, {"CurrentGUID", "IsFishing", "IsCharging", "Fishing", "Charging"}))
        end
    end
    for tick = 0, 20 do
        local ok, err = pcall(sample)
        if not ok then log("sample error", err) end
        if tick % 5 == 0 then log("heartbeat", tick) save() end
        if tick < 20 then task.wait(1) end
    end
    log("END", "Capture complete. No gameplay state changed. Send this entire report, not just the last line.")
    if save() then print("[Orvion Probe] Saved: workspace/" .. output)
    else warn("[Orvion Probe] File save unavailable. Copy the console output above.") end
end
