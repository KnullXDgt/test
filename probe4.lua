-- Orvion Probe 4
-- High-fidelity structural workflow mapper for five quest features.
--
-- The probe decompiles candidate client modules in memory for discovery, but
-- deliberately writes structural evidence instead of copying complete source.
-- It never fires/invokes a remote, hooks a metamethod, or mutates player data.

local P = {
    Version = "1.0.0",
    RootFolder = "OrvionProbe4",
    RunFolder = nil,
    ControllersFolder = nil,
    RuntimeFolder = nil,
    RemoteFolder = nil,
    RS = game:GetService("ReplicatedStorage"),
    CS = game:GetService("CollectionService"),
    Players = game:GetService("Players"),
    Report = {},
    Progress = {},
    RemoteRecords = {},
    RemoteByLogical = {},
    RemoteByBase = {},
    SourceCache = setmetatable({}, { __mode = "k" }),
    ModuleRecords = {},
    SelectedRecords = {},
}

P.SourceRoots = {
    "ReplicatedStorage.Controllers",
    "ReplicatedStorage.Observers",
    "ReplicatedStorage.Modules.Quests",
    "ReplicatedStorage.Shared",
}

P.SeedPaths = {
    "ReplicatedStorage.Controllers.MainlineQuestController",
    "ReplicatedStorage.Controllers.MainlineQuestController.Tracking",
    "ReplicatedStorage.Controllers.DialogueController",
    "ReplicatedStorage.Controllers.DialogueController.Internal.Dialogue",
    "ReplicatedStorage.Controllers.DialogueController.Internal.DialogueTree",
    "ReplicatedStorage.Controllers.PromptController",
    "ReplicatedStorage.Modules.QuestLines",
    "ReplicatedStorage.Modules.Quests.Mainline.Deep Sea Quest",
    "ReplicatedStorage.Modules.Quests.Mainline.Element Quest",
    "ReplicatedStorage.Modules.Quests.Mainline.Diamond Researcher",
    "ReplicatedStorage.Shared.NPCQuestGivers",
    "ReplicatedStorage.Shared.NPCQuestTurnIn",
    "ReplicatedStorage.Shared.QuestItemPlacements",
    "ReplicatedStorage.Observers.ClientQuestEvents",
    "ReplicatedStorage.Observers.Lever",
    "ReplicatedStorage.Observers.TempleDoor",
    "ReplicatedStorage.Observers.RuinDoor",
    "ReplicatedStorage.Observers.RuinKeySlot",
    "ReplicatedStorage.Observers.DiamondKeySlot",
    "ReplicatedStorage.Observers.ElementalForcefield",
}

P.StrongTerms = {
    "PlaceLeverItem", "TempleLevers", "UnlockedTemple", "TempleDoor",
    "PlacePressureItem", "PressurePlate", "UnlockedRuins", "RuinDoor",
    "RuinKeySlot", "Ruin Key", "Crystalline Passage",
    "Deep Sea Quest", "Sisyphus Statue", "Ghostfinn Rod",
    "Element Quest", "Sacred Temple", "Transcended Stone", "Element Rod",
    "Diamond Researcher", "Gemstone Ruby", "Lochness Monster",
    "Diamond Key", "DiamondKeySlot", "DiamondDoor", "Diamond Rod",
    "ClaimItemPrompt", "ClaimItem", "NPCQuestGivers", "NPCQuestTurnIn",
    "DialogueEnded", "QuestGiver", "QuestTurnIn",
}

P.WeakTerms = {
    "artifact", "lever", "temple", "ruin", "pressure", "passage",
    "sisyphus", "ghostfinn", "element", "sacred", "transcended",
    "diamond", "researcher", "ruby", "lochness", "quest", "claim",
}

P.RelevantRemoteBases = {
    PlaceLeverItem = true,
    PlacePressureItem = true,
    DialogueEnded = true,
    ClaimItem = true,
    EquipItem = true,
    UnequipItem = true,
    EquipToolFromHotbar = true,
    UnequipToolFromHotbar = true,
    CreateTranscendedStone = true,
    ChargeFishingRod = true,
    RequestFishingMinigameStarted = true,
    CatchFishCompleted = true,
    CancelFishingInputs = true,
}

P.StateTerms = {
    "TempleLevers", "UnlockedTemple", "UnlockedRuins", "Quests",
    "CompletedQuests", "CurrentObj", "Objectives", "EquippedType",
    "EquippedId", "EquippedItems", "Inventory", "ClaimedSearchIds",
}

P.TargetTags = {
    "Lever", "TempleDoor", "PressurePlate", "RuinDoor", "RuinKeySlot",
    "DiamondDoor", "ClaimItemPrompt", "QuestBoard", "NPC",
}

P.log = function(value)
    table.insert(P.Report, tostring(value))
end

P.progress = function(value)
    local line = os.date("!%H:%M:%S") .. " | " .. tostring(value)
    table.insert(P.Progress, line)
    print("[Orvion Probe 4] " .. tostring(value))
    if P.RunFolder and type(writefile) == "function" then
        pcall(writefile, P.RunFolder .. "/progress.txt", table.concat(P.Progress, "\n"))
    end
end

P.ensureFolder = function(path)
    if type(makefolder) ~= "function" then return false end
    if type(isfolder) == "function" then
        local ok, exists = pcall(isfolder, path)
        if ok and exists then return true end
    end
    local ok = pcall(makefolder, path)
    return ok
end

P.write = function(path, content)
    if type(writefile) ~= "function" then return false, "writefile unavailable" end
    local ok, err = pcall(writefile, path, content)
    return ok, err
end

P.resolve = function(path)
    local cursor = game
    local first = true
    for segment in string.gmatch(path, "[^%.]+") do
        if first then
            first = false
            if segment == "ReplicatedStorage" then
                cursor = P.RS
            elseif segment == "Workspace" then
                cursor = workspace
            else
                cursor = game:FindFirstChild(segment)
            end
        else
            cursor = cursor and cursor:FindFirstChild(segment)
        end
        if not cursor then return nil end
    end
    return cursor
end

P.fingerprint = function(text)
    local hash = 5381
    for index = 1, #text do
        hash = (hash * 33 + string.byte(text, index)) % 4294967296
    end
    return string.format("%08x", hash)
end

P.sanitizeFileName = function(path)
    local sanitized = string.gsub(path, "[^%w%-%._]", "_")
    if #sanitized > 170 then
        sanitized = string.sub(sanitized, 1, 155) .. "_" .. P.fingerprint(path)
    end
    return sanitized
end

P.compact = function(value, limit)
    value = tostring(value or "")
    value = string.gsub(value, "%-%-[^\n]*", "")
    value = string.gsub(value, "%s+", " ")
    value = string.gsub(value, "^%s+", "")
    value = string.gsub(value, "%s+$", "")
    limit = limit or 700
    if #value > limit then value = string.sub(value, 1, limit) .. "..." end
    return value
end

P.safeScalar = function(value)
    local valueType = typeof(value)
    if valueType == "string" then return string.format("%q", P.compact(value, 180)) end
    if valueType == "number" or valueType == "boolean" or valueType == "nil" then
        return tostring(value)
    end
    if valueType == "Instance" then
        local ok, fullName = pcall(function() return value:GetFullName() end)
        return ok and ("<Instance " .. fullName .. ">") or "<Instance>"
    end
    if valueType == "CFrame" or valueType == "Vector3" or valueType == "Vector2"
        or valueType == "Color3" or valueType == "EnumItem"
    then
        return tostring(value)
    end
    return "<" .. valueType .. ">"
end

P.serialize = function(value, depth, seen)
    depth = depth or 0
    seen = seen or {}
    if type(value) ~= "table" then return P.safeScalar(value) end
    if seen[value] then return "<cycle>" end
    if depth >= 7 then return "<max-depth>" end
    seen[value] = true
    local keys = {}
    for key in pairs(value) do table.insert(keys, key) end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    local limit = math.min(#keys, 400)
    for index = 1, limit do
        local key = keys[index]
        table.insert(parts, "[" .. P.safeScalar(key) .. "]="
            .. P.serialize(value[key], depth + 1, seen))
    end
    if #keys > limit then
        table.insert(parts, "<truncated " .. tostring(#keys - limit) .. " entries>")
    end
    seen[value] = nil
    return "{" .. table.concat(parts, ", ") .. "}"
end

P.initOutput = function()
    local runName = "run_" .. tostring(os.time()) .. "_" .. tostring(game.PlaceId)
    P.RunFolder = P.RootFolder .. "/" .. runName
    P.ControllersFolder = P.RunFolder .. "/controllers"
    P.RuntimeFolder = P.RunFolder .. "/runtime"
    P.RemoteFolder = P.RunFolder .. "/remotes"
    P.ensureFolder(P.RootFolder)
    P.ensureFolder(P.RunFolder)
    P.ensureFolder(P.ControllersFolder)
    P.ensureFolder(P.RuntimeFolder)
    P.ensureFolder(P.RemoteFolder)
end

P.isRemote = function(instance)
    return instance and (instance:IsA("RemoteEvent")
        or instance:IsA("RemoteFunction")
        or instance:IsA("UnreliableRemoteEvent"))
end

P.remoteParts = function(name)
    local kind, base = string.match(tostring(name), "^(RE)/(.+)$")
    if not kind then kind, base = string.match(tostring(name), "^(RF)/(.+)$") end
    if not kind then kind, base = string.match(tostring(name), "^(URE)/(.+)$") end
    return kind, base
end

P.isHashToken = function(value)
    return type(value) == "string" and #value >= 32
        and string.match(value, "^[%da-fA-F]+$") ~= nil
end

P.findNet = function()
    local packages = P.RS:FindFirstChild("Packages")
    local indexFolder = packages and packages:FindFirstChild("_Index")
    if indexFolder then
        for _, package in ipairs(indexFolder:GetChildren()) do
            if string.find(package.Name, "sleitnick_net@", 1, true) == 1 then
                local net = package:FindFirstChild("net")
                if net then return net, "package-path:" .. package.Name end
            end
        end
    end
    for _, instance in ipairs(P.RS:GetDescendants()) do
        if instance.Name == "net" then
            local logicalCount = 0
            for _, child in ipairs(instance:GetChildren()) do
                local kind = P.remoteParts(child.Name)
                if kind and P.isRemote(child) then logicalCount = logicalCount + 1 end
            end
            if logicalCount >= 10 then return instance, "descendant-heuristic" end
        end
    end
    return nil, "missing"
end

P.remoteRecordLine = function(record)
    return table.concat({
        "logical=" .. record.Logical,
        "markerClass=" .. record.MarkerClass,
        "markerIndex=" .. tostring(record.MarkerIndex),
        "resolvedName=" .. record.ResolvedName,
        "resolvedClass=" .. record.ResolvedClass,
        "resolvedIndex=" .. tostring(record.ResolvedIndex or "?"),
        "hashToken=" .. record.HashToken,
        "strategy=" .. record.Strategy,
        "confidence=" .. record.Confidence,
    }, " | ")
end

P.discoverRemotes = function()
    P.progress("Phase 1/5: resolving the complete remote table")
    local net, netReason = P.findNet()
    P.Net = net
    local lines = {
        "=== ORVION PROBE 4: COMPLETE REMOTE RESOLUTION ===",
        "net=" .. (net and net:GetFullName() or "<missing>"),
        "netDiscovery=" .. netReason,
        "method=logical marker followed by next sibling; hashed sibling is preferred when class/kind agree",
        "",
    }
    if not net then
        P.write(P.RunFolder .. "/01_all_remote_resolution.txt", table.concat(lines, "\n"))
        return
    end

    local children = net:GetChildren()
    for index, marker in ipairs(children) do
        local kind, base = P.remoteParts(marker.Name)
        if kind and base and P.isRemote(marker) and not P.isHashToken(base) then
            local nextSibling = children[index + 1]
            local nextKind, nextBase = nextSibling and P.remoteParts(nextSibling.Name)
            local sameShape = P.isRemote(nextSibling)
                and nextSibling.ClassName == marker.ClassName
                and nextKind == kind
            local resolved = marker
            local strategy = "direct-logical"
            local confidence = "LOW"
            if sameShape and P.isHashToken(nextBase) then
                resolved = nextSibling
                strategy = "next-sibling-hash"
                confidence = "HIGH"
            elseif sameShape then
                resolved = nextSibling
                strategy = "next-sibling-compatible"
                confidence = "MEDIUM"
            end
            local _, resolvedBase = P.remoteParts(resolved.Name)
            local record = {
                Logical = kind .. "/" .. base,
                Kind = kind,
                Base = base,
                Marker = marker,
                MarkerClass = marker.ClassName,
                MarkerIndex = index,
                Resolved = resolved,
                ResolvedName = resolved.Name,
                ResolvedClass = resolved.ClassName,
                ResolvedIndex = table.find(children, resolved),
                HashToken = P.isHashToken(resolvedBase) and resolvedBase or "<unhashed>",
                Strategy = strategy,
                Confidence = confidence,
            }
            table.insert(P.RemoteRecords, record)
            P.RemoteByLogical[record.Logical] = record
            P.RemoteByBase[base] = P.RemoteByBase[base] or {}
            table.insert(P.RemoteByBase[base], record)
        end
    end
    table.sort(P.RemoteRecords, function(a, b) return a.Logical < b.Logical end)
    for _, record in ipairs(P.RemoteRecords) do
        table.insert(lines, P.remoteRecordLine(record))
    end
    table.insert(lines, "")
    table.insert(lines, "TOTAL_LOGICAL_REMOTES=" .. tostring(#P.RemoteRecords))
    P.write(P.RunFolder .. "/01_all_remote_resolution.txt", table.concat(lines, "\n"))
    P.progress("Remote resolution complete: " .. tostring(#P.RemoteRecords) .. " logical entries")
end

P.dumpRelevantWorldState = function()
    P.progress("Phase 2/5: capturing quest state and tagged interaction endpoints")
    local stateLines = {
        "=== TARGET QUEST STATE ===",
        "placeId=" .. tostring(game.PlaceId),
        "jobId=" .. tostring(game.JobId),
        "player=" .. tostring(P.Players.LocalPlayer and P.Players.LocalPlayer.Name or "?"),
        "",
    }
    local okReplion, replion = pcall(function() return require(P.RS.Packages.Replion) end)
    if okReplion and replion and replion.Client then
        local okData, data = pcall(function() return replion.Client:WaitReplion("Data") end)
        if okData and data then
            for _, key in ipairs({
                "TempleLevers", "UnlockedTemple", "UnlockedRuins", "Quests",
                "CompletedQuests", "EquippedType", "EquippedId", "EquippedItems",
                "Inventory", "Locations", "ClaimedSearchIds",
            }) do
                local ok, value = pcall(function() return data:Get(key) end)
                table.insert(stateLines, key .. "=" .. (ok and P.serialize(value)
                    or ("<error " .. tostring(value) .. ">")))
            end
        else
            table.insert(stateLines, "PlayerData=<unavailable>")
        end
    else
        table.insert(stateLines, "Replion=<unavailable>")
    end

    table.insert(stateLines, "\n=== TAGGED INTERACTION ENDPOINTS ===")
    for _, tag in ipairs(P.TargetTags) do
        local objects = P.CS:GetTagged(tag)
        table.sort(objects, function(a, b) return a:GetFullName() < b:GetFullName() end)
        table.insert(stateLines, "[" .. tag .. "] count=" .. tostring(#objects))
        for _, object in ipairs(objects) do
            local attributes = {}
            local okAttrs, attrs = pcall(function() return object:GetAttributes() end)
            if okAttrs then attributes = attrs end
            table.insert(stateLines, "  " .. object:GetFullName() .. " [" .. object.ClassName
                .. "] attrs=" .. P.serialize(attributes))
            for _, child in ipairs(object:GetDescendants()) do
                if child:IsA("ProximityPrompt") then
                    table.insert(stateLines, "    PROMPT " .. child:GetFullName()
                        .. " action=" .. string.format("%q", child.ActionText)
                        .. " object=" .. string.format("%q", child.ObjectText)
                        .. " enabled=" .. tostring(child.Enabled)
                        .. " distance=" .. tostring(child.MaxActivationDistance)
                        .. " hold=" .. tostring(child.HoldDuration))
                end
            end
        end
    end
    P.write(P.RunFolder .. "/02_quest_state_and_endpoints.txt", table.concat(stateLines, "\n"))
end

P.getDecompiler = function()
    if type(decompile) == "function" then return decompile, "decompile" end
    return nil, "unavailable"
end

P.isSeedPath = function(path)
    for _, seed in ipairs(P.SeedPaths) do
        if path == seed or string.find(path, seed .. ".", 1, true) == 1 then return true end
    end
    return false
end

P.termHits = function(text, terms)
    local lower = string.lower(text)
    local hits = {}
    for _, term in ipairs(terms) do
        if string.find(lower, string.lower(term), 1, true) then table.insert(hits, term) end
    end
    return hits
end

P.collectModules = function()
    local seen = setmetatable({}, { __mode = "k" })
    local modules = {}
    for _, rootPath in ipairs(P.SourceRoots) do
        local root = P.resolve(rootPath)
        if root then
            local candidates = { root }
            for _, descendant in ipairs(root:GetDescendants()) do table.insert(candidates, descendant) end
            for _, candidate in ipairs(candidates) do
                if candidate:IsA("ModuleScript") and not seen[candidate] then
                    seen[candidate] = true
                    table.insert(modules, candidate)
                end
            end
        end
    end
    for _, seedPath in ipairs(P.SeedPaths) do
        local seed = P.resolve(seedPath)
        if seed and seed:IsA("ModuleScript") and not seen[seed] then
            seen[seed] = true
            table.insert(modules, seed)
        end
    end
    table.sort(modules, function(a, b) return a:GetFullName() < b:GetFullName() end)
    return modules
end

P.decompileWithRetry = function(decompiler, module)
    local lastError = "unknown"
    for attempt = 1, 3 do
        local ok, source = pcall(decompiler, module)
        if ok and type(source) == "string" and #source > 0 then return source, attempt end
        lastError = tostring(source)
        task.wait(0.12 * attempt)
    end
    return nil, lastError
end

P.scoreSource = function(path, source)
    local score = 0
    local reasons = {}
    if P.isSeedPath(path) then
        score = score + 120
        table.insert(reasons, "seed")
    end
    local pathStrong = P.termHits(path, P.StrongTerms)
    local pathWeak = P.termHits(path, P.WeakTerms)
    local sourceStrong = P.termHits(source, P.StrongTerms)
    local sourceWeak = P.termHits(source, P.WeakTerms)
    score = score + (#pathStrong * 35) + (#pathWeak * 5)
    score = score + (#sourceStrong * 22) + math.min(#sourceWeak, 8) * 2
    if #pathStrong > 0 then table.insert(reasons, "path:" .. table.concat(pathStrong, ",")) end
    if #sourceStrong > 0 then table.insert(reasons, "source:" .. table.concat(sourceStrong, ",")) end
    for remoteBase in pairs(P.RelevantRemoteBases) do
        if string.find(source, remoteBase, 1, true) then
            score = score + 45
            table.insert(reasons, "remote:" .. remoteBase)
        end
    end
    return score, reasons
end

P.scanControllers = function()
    P.progress("Phase 3/5: decompiling controller candidates in memory")
    local decompiler, decompilerName = P.getDecompiler()
    P.DecompilerName = decompilerName
    if not decompiler then
        P.progress("Decompiler unavailable; structural source analysis cannot continue")
        return
    end
    local modules = P.collectModules()
    P.progress("Candidate modules: " .. tostring(#modules))
    local indexLines = {
        "=== CONTROLLER DISCOVERY INDEX ===",
        "decompiler=" .. decompilerName,
        "candidateCount=" .. tostring(#modules),
        "",
    }
    for index, module in ipairs(modules) do
        local path = module:GetFullName()
        local source, attemptOrError = P.decompileWithRetry(decompiler, module)
        if source then
            P.SourceCache[module] = source
            local score, reasons = P.scoreSource(path, source)
            local record = {
                Script = module,
                Path = path,
                Source = source,
                SourceBytes = #source,
                SourceHash = P.fingerprint(source),
                Score = score,
                Reasons = reasons,
                Attempts = attemptOrError,
            }
            table.insert(P.ModuleRecords, record)
            if score >= 22 then table.insert(P.SelectedRecords, record) end
            table.insert(indexLines, table.concat({
                "path=" .. path,
                "bytes=" .. tostring(#source),
                "fingerprint=" .. record.SourceHash,
                "score=" .. tostring(score),
                "selected=" .. tostring(score >= 22),
                "reason=" .. table.concat(reasons, ";"),
            }, " | "))
        else
            table.insert(indexLines, "path=" .. path .. " | DECOMPILE_FAILED=" .. tostring(attemptOrError))
        end
        if index % 8 == 0 then
            P.write(P.RunFolder .. "/03_controller_discovery_index.txt", table.concat(indexLines, "\n"))
            P.progress("Discovery " .. tostring(index) .. "/" .. tostring(#modules)
                .. " selected=" .. tostring(#P.SelectedRecords))
            task.wait()
        end
    end
    table.sort(P.SelectedRecords, function(a, b) return a.Path < b.Path end)
    table.insert(indexLines, "")
    table.insert(indexLines, "DECOMPILED=" .. tostring(#P.ModuleRecords))
    table.insert(indexLines, "SELECTED=" .. tostring(#P.SelectedRecords))
    P.write(P.RunFolder .. "/03_controller_discovery_index.txt", table.concat(indexLines, "\n"))
end

P.sourceSnippet = function(lines, index, maxExtra)
    local snippet = lines[index] or ""
    local openCount = select(2, string.gsub(snippet, "%(", ""))
    local closeCount = select(2, string.gsub(snippet, "%)", ""))
    local cursor = index + 1
    maxExtra = maxExtra or 8
    while openCount > closeCount and cursor <= #lines and cursor <= index + maxExtra do
        snippet = snippet .. " " .. lines[cursor]
        openCount = openCount + select(2, string.gsub(lines[cursor], "%(", ""))
        closeCount = closeCount + select(2, string.gsub(lines[cursor], "%)", ""))
        cursor = cursor + 1
    end
    return P.compact(snippet, 900)
end

P.remoteDeclarations = function(line)
    local declarations = {}
    local patterns = {
        { Kind = "RE", Pattern = ":RemoteEvent%s*%(%s*[\"']([^\"']+)[\"']" },
        { Kind = "RF", Pattern = ":RemoteFunction%s*%(%s*[\"']([^\"']+)[\"']" },
        { Kind = "URE", Pattern = ":UnreliableRemoteEvent%s*%(%s*[\"']([^\"']+)[\"']" },
    }
    for _, entry in ipairs(patterns) do
        for base in string.gmatch(line, entry.Pattern) do
            table.insert(declarations, { Kind = entry.Kind, Base = base })
        end
    end
    for _, kind in ipairs({ "RE", "RF", "URE" }) do
        local directPattern = "[\"']" .. kind .. "/([^\"']+)[\"']"
        for base in string.gmatch(line, directPattern) do
            table.insert(declarations, { Kind = kind, Base = base })
        end
    end
    return declarations
end

P.lineCategory = function(line)
    local compact = P.compact(line, 900)
    if compact == "" then return nil end
    if string.match(compact, "^local%s+function%s+")
        or string.match(compact, "^function%s+")
        or string.find(compact, "= function(", 1, true)
    then return "FUNCTION" end
    if string.find(compact, ":RemoteEvent", 1, true)
        or string.find(compact, ":RemoteFunction", 1, true)
        or string.find(compact, ":UnreliableRemoteEvent", 1, true)
    then return "REMOTE_DECL" end
    if string.find(compact, ":FireServer", 1, true)
        or string.find(compact, ":InvokeServer", 1, true)
    then return "REMOTE_CALL" end
    if string.find(compact, "ProximityPrompt", 1, true)
        or string.find(compact, ".Triggered", 1, true)
        or string.find(compact, "PromptShown", 1, true)
    then return "PROMPT" end
    if string.find(compact, "OnClientEvent", 1, true)
        or string.find(compact, ":Connect", 1, true)
        or string.find(compact, "GetPropertyChangedSignal", 1, true)
        or string.find(compact, ":Observe", 1, true)
        or string.find(compact, ":OnChange", 1, true)
    then return "EVENT" end
    if string.match(compact, "^if%s+") or string.match(compact, "^elseif%s+")
        or compact == "else" or string.match(compact, "^for%s+")
        or string.match(compact, "^while%s+") or compact == "repeat"
        or string.match(compact, "^until%s+")
    then return "BRANCH" end
    if string.match(compact, "^return[%s%(%{%\"']") or compact == "return" then
        return "RETURN"
    end
    if string.find(compact, "require(", 1, true) then return "DEPENDENCY" end
    for _, stateTerm in ipairs(P.StateTerms) do
        if string.find(compact, stateTerm, 1, true) then
            if string.find(compact, "Set", 1, true) or string.find(compact, "=", 1, true) then
                return "STATE_TOUCH"
            end
            return "STATE_READ"
        end
    end
    for _, term in ipairs(P.StrongTerms) do
        if string.find(string.lower(compact), string.lower(term), 1, true) then
            return "QUEST_EVIDENCE"
        end
    end
    return nil
end

P.extractRemoteUsage = function(record, lines)
    local usages = {}
    local seen = {}
    local variableMap = {}
    for lineNumber, line in ipairs(lines) do
        local declarations = P.remoteDeclarations(line)
        local localVariable = string.match(line, "local%s+([%w_]+)%s*=")
        for _, declaration in ipairs(declarations) do
            local logical = declaration.Kind .. "/" .. declaration.Base
            if localVariable then variableMap[localVariable] = logical end
            local key = logical .. "@decl@" .. tostring(lineNumber)
            if not seen[key] then
                seen[key] = true
                table.insert(usages, {
                    Type = "DECLARATION",
                    Logical = logical,
                    Line = lineNumber,
                    Statement = P.sourceSnippet(lines, lineNumber),
                })
            end
        end
        local callVariable, method = string.match(line, "([%w_]+):(%a+Server)%s*%(")
        if callVariable and (method == "FireServer" or method == "InvokeServer") then
            local logical = variableMap[callVariable] or "<unresolved-variable:" .. callVariable .. ">"
            local statement = P.sourceSnippet(lines, lineNumber)
            local arguments = string.match(statement,
                callVariable .. ":" .. method .. "%s*%((.*)%)") or ""
            table.insert(usages, {
                Type = method,
                Logical = logical,
                Line = lineNumber,
                Statement = statement,
                CallVariable = callVariable,
                Arguments = arguments,
            })
        end
    end
    return usages
end

P.identifierBlacklist = {
    ["and"] = true, ["break"] = true, ["continue"] = true, ["do"] = true,
    ["else"] = true, ["elseif"] = true, ["end"] = true, ["false"] = true,
    ["for"] = true, ["function"] = true, ["if"] = true, ["in"] = true,
    ["local"] = true, ["nil"] = true, ["not"] = true, ["or"] = true,
    ["repeat"] = true, ["return"] = true, ["then"] = true, ["true"] = true,
    ["until"] = true, ["while"] = true,
    ["FireServer"] = true, ["InvokeServer"] = true, ["GetAttribute"] = true,
    ["GetFullName"] = true, ["FindFirstChild"] = true, ["WaitForChild"] = true,
    ["tostring"] = true, ["tonumber"] = true, ["type"] = true, ["typeof"] = true,
    ["pairs"] = true, ["ipairs"] = true, ["pcall"] = true, ["task"] = true,
    ["table"] = true, ["string"] = true, ["math"] = true, ["game"] = true,
    ["workspace"] = true, ["script"] = true,
}

P.escapePattern = function(value)
    return (string.gsub(value, "([^%w])", "%%%1"))
end

P.identifiers = function(expression)
    expression = tostring(expression or "")
    expression = string.gsub(expression, "\"[^\"]*\"", " ")
    expression = string.gsub(expression, "'[^']*'", " ")
    local result = {}
    local seen = {}
    local cursor = 1
    while cursor <= #expression do
        local startAt, endAt, identifier = string.find(expression, "([%a_][%w_]*)", cursor)
        if not startAt then break end
        local previous = startAt > 1 and string.sub(expression, startAt - 1, startAt - 1) or ""
        if not P.identifierBlacklist[identifier]
            and not seen[identifier]
            and previous ~= "."
            and previous ~= ":"
            and not string.match(identifier, "^Enum$")
        then
            seen[identifier] = true
            table.insert(result, identifier)
        end
        cursor = endAt + 1
    end
    return result
end

P.traceRemoteArguments = function(lines, usage)
    if not usage.Arguments or usage.Arguments == "" then return {} end
    local output = {}
    local visited = {}
    local queue = {}
    for _, identifier in ipairs(P.identifiers(usage.Arguments)) do
        if identifier ~= usage.CallVariable then
            table.insert(queue, { Name = identifier, Before = usage.Line, Depth = 0 })
        end
    end
    local cursor = 1
    while cursor <= #queue and #output < 80 do
        local entry = queue[cursor]
        cursor = cursor + 1
        local visitKey = entry.Name .. "@" .. tostring(entry.Before)
        if not visited[visitKey] and entry.Depth <= 5 then
            visited[visitKey] = true
            local escaped = P.escapePattern(entry.Name)
            local foundLine = nil
            local foundStatement = nil
            local lowerBound = math.max(1, entry.Before - 260)
            for lineNumber = entry.Before - 1, lowerBound, -1 do
                local line = lines[lineNumber]
                local localAssignment = string.match(line,
                    "^%s*local%s+" .. escaped .. "%s*=")
                local assignment = string.match(line,
                    "^%s*" .. escaped .. "%s*=")
                if localAssignment or assignment then
                    foundLine = lineNumber
                    foundStatement = P.sourceSnippet(lines, lineNumber, 7)
                    break
                end
                if string.find(line, "function", 1, true)
                    and string.match(line, "%([^%)]*%f[%w_]" .. escaped .. "%f[^%w_][^%)]*%)")
                then
                    foundLine = lineNumber
                    foundStatement = "PARAMETER OF " .. P.compact(line, 650)
                    break
                end
            end
            if foundLine then
                table.insert(output, string.rep("  ", entry.Depth)
                    .. entry.Name .. " <= L" .. tostring(foundLine) .. " " .. foundStatement)
                local rightHand = string.match(foundStatement, "=(.*)") or ""
                for _, dependency in ipairs(P.identifiers(rightHand)) do
                    if dependency ~= entry.Name and dependency ~= usage.CallVariable then
                        table.insert(queue, {
                            Name = dependency,
                            Before = foundLine,
                            Depth = entry.Depth + 1,
                        })
                    end
                end
            else
                table.insert(output, string.rep("  ", entry.Depth)
                    .. entry.Name .. " <= <assignment not found in previous 260 lines>")
            end
        end
    end
    if cursor <= #queue then table.insert(output, "<argument trace truncated>") end
    return output
end

P.remoteUsageLine = function(usage)
    local mapping = P.RemoteByLogical[usage.Logical]
    return table.concat({
        "L" .. tostring(usage.Line),
        "type=" .. usage.Type,
        "logical=" .. usage.Logical,
        "resolved=" .. (mapping and mapping.ResolvedName or "<not-resolved>"),
        "hash=" .. (mapping and mapping.HashToken or "<not-resolved>"),
        "strategy=" .. (mapping and mapping.Strategy or "<none>"),
        "statement=" .. usage.Statement,
    }, " | ")
end

P.runtimeFunctions = function(module)
    local closureGetter = nil
    if type(getscriptclosure) == "function" then closureGetter = getscriptclosure end
    if not closureGetter and type(getscriptfunction) == "function" then closureGetter = getscriptfunction end
    if not closureGetter then return nil, "closure getter unavailable" end
    local ok, closure = pcall(closureGetter, module)
    if not ok or type(closure) ~= "function" then return nil, tostring(closure) end
    return closure, "ok"
end

P.dumpRuntimeMetadata = function(record)
    local output = {
        "=== RUNTIME FUNCTION METADATA ===",
        "controller=" .. record.Path,
        "note=Only scalar/relevant constants and metadata are recorded; functions are never executed.",
        "",
    }
    local closure, reason = P.runtimeFunctions(record.Script)
    if not closure then
        table.insert(output, "status=" .. reason)
        return table.concat(output, "\n")
    end
    local constantsGetter = nil
    local protosGetter = nil
    local upvaluesGetter = nil
    if type(debug) == "table" then
        if type(debug.getconstants) == "function" then constantsGetter = debug.getconstants end
        if type(debug.getprotos) == "function" then protosGetter = debug.getprotos end
        if type(debug.getupvalues) == "function" then upvaluesGetter = debug.getupvalues end
    end
    if not constantsGetter and type(getconstants) == "function" then constantsGetter = getconstants end
    if not protosGetter and type(getprotos) == "function" then protosGetter = getprotos end
    if not upvaluesGetter and type(getupvalues) == "function" then upvaluesGetter = getupvalues end

    local queue = { { Fn = closure, Depth = 0, Label = "root" } }
    local cursor = 1
    local visited = setmetatable({}, { __mode = "k" })
    local dumped = 0
    while cursor <= #queue and dumped < 240 do
        local entry = queue[cursor]
        cursor = cursor + 1
        if not visited[entry.Fn] then
            visited[entry.Fn] = true
            dumped = dumped + 1
            local info = ""
            if type(debug) == "table" and type(debug.info) == "function" then
                local okInfo, name, sourceName, lineDefined = pcall(debug.info, entry.Fn, "nsl")
                if okInfo then
                    info = "name=" .. tostring(name)
                        .. " source=" .. tostring(sourceName)
                        .. " line=" .. tostring(lineDefined)
                end
            end
            table.insert(output, string.rep("  ", entry.Depth) .. "PROTO " .. entry.Label
                .. " info=" .. P.compact(info, 240))
            if constantsGetter then
                local okConstants, constants = pcall(constantsGetter, entry.Fn)
                if okConstants and type(constants) == "table" then
                    for constantIndex, constant in pairs(constants) do
                        local constantType = typeof(constant)
                        local keep = constantType == "number" or constantType == "boolean"
                        if constantType == "string" then
                            keep = #P.termHits(constant, P.StrongTerms) > 0
                                or P.remoteParts(constant) ~= nil
                        end
                        if keep then
                            table.insert(output, string.rep("  ", entry.Depth + 1)
                                .. "CONST[" .. tostring(constantIndex) .. "]=" .. P.safeScalar(constant))
                        end
                    end
                end
            end
            if upvaluesGetter then
                local okUpvalues, upvalues = pcall(upvaluesGetter, entry.Fn)
                if okUpvalues and type(upvalues) == "table" then
                    for upvalueIndex, upvalue in pairs(upvalues) do
                        local upvalueType = typeof(upvalue)
                        if upvalueType ~= "function" and upvalueType ~= "table" then
                            table.insert(output, string.rep("  ", entry.Depth + 1)
                                .. "UPVALUE[" .. tostring(upvalueIndex) .. "]=" .. P.safeScalar(upvalue))
                        end
                    end
                end
            end
            if protosGetter and entry.Depth < 8 then
                local okProtos, protos = pcall(protosGetter, entry.Fn)
                if okProtos and type(protos) == "table" then
                    for protoIndex, proto in pairs(protos) do
                        if type(proto) == "function" then
                            table.insert(queue, {
                                Fn = proto,
                                Depth = entry.Depth + 1,
                                Label = entry.Label .. "." .. tostring(protoIndex),
                            })
                        end
                    end
                end
            end
        end
    end
    table.insert(output, "")
    table.insert(output, "PROTO_COUNT=" .. tostring(dumped))
    if cursor <= #queue then table.insert(output, "PROTO_TRUNCATED=true") end
    return table.concat(output, "\n")
end

P.analyzeController = function(record)
    local lines = string.split(record.Source, "\n")
    local usages = P.extractRemoteUsage(record, lines)
    local output = {
        "=== CONTROLLER STRUCTURAL WORKFLOW ===",
        "path=" .. record.Path,
        "sourceBytes=" .. tostring(record.SourceBytes),
        "sourceFingerprint=" .. record.SourceHash,
        "discoveryScore=" .. tostring(record.Score),
        "discoveryReasons=" .. table.concat(record.Reasons, ";"),
        "rawSourceSaved=false",
        "",
        "=== REMOTE RESOLUTION AND ARGUMENT CALLS ===",
    }
    if #usages == 0 then table.insert(output, "<no remote declaration/call recognized>") end
    for _, usage in ipairs(usages) do
        table.insert(output, P.remoteUsageLine(usage))
        if usage.Type == "FireServer" or usage.Type == "InvokeServer" then
            local traces = P.traceRemoteArguments(lines, usage)
            if #traces > 0 then
                table.insert(output, "  ARGUMENT_DATAFLOW:")
                for _, trace in ipairs(traces) do table.insert(output, "    " .. trace) end
            end
        end
    end

    table.insert(output, "\n=== STRUCTURAL FLOW ===")
    local currentFunction = "<chunk>"
    local emitted = 0
    local lastKey = ""
    for lineNumber, line in ipairs(lines) do
        local category = P.lineCategory(line)
        if category then
            local statement = P.sourceSnippet(lines, lineNumber, 5)
            if category == "FUNCTION" then currentFunction = statement end
            local key = category .. "|" .. statement
            if key ~= lastKey then
                lastKey = key
                emitted = emitted + 1
                table.insert(output, "L" .. tostring(lineNumber)
                    .. " [" .. category .. "] owner=" .. P.compact(currentFunction, 260)
                    .. " | " .. statement)
            end
        end
    end
    table.insert(output, "")
    table.insert(output, "STRUCTURAL_STATEMENTS=" .. tostring(emitted))
    table.insert(output, "REMOTE_USAGE_RECORDS=" .. tostring(#usages))

    local runtimeText = P.dumpRuntimeMetadata(record)
    local fileBase = P.sanitizeFileName(record.Path)
    P.write(P.RuntimeFolder .. "/" .. fileBase .. ".txt", runtimeText)
    table.insert(output, "runtimeMetadataFile=runtime/" .. fileBase .. ".txt")
    table.insert(output, "\n" .. runtimeText)

    local remoteLines = {
        "=== CONTROLLER REMOTE MANIFEST ===",
        "controller=" .. record.Path,
        "sourceFingerprint=" .. record.SourceHash,
        "",
    }
    for _, usage in ipairs(usages) do
        table.insert(remoteLines, P.remoteUsageLine(usage))
        if usage.Type == "FireServer" or usage.Type == "InvokeServer" then
            for _, trace in ipairs(P.traceRemoteArguments(lines, usage)) do
                table.insert(remoteLines, "  ARG_TRACE " .. trace)
            end
        end
    end
    P.write(P.RemoteFolder .. "/" .. fileBase .. ".txt", table.concat(remoteLines, "\n"))
    return table.concat(output, "\n")
end

P.analyzeSelectedControllers = function()
    P.progress("Phase 4/5: building per-controller structural workflows")
    local combined = {
        "=== ORVION PROBE 4 COMBINED WORKFLOW REPORT ===",
        "version=" .. P.Version,
        "placeId=" .. tostring(game.PlaceId),
        "decompiler=" .. tostring(P.DecompilerName),
        "selectedControllers=" .. tostring(#P.SelectedRecords),
        "remoteMappings=" .. tostring(#P.RemoteRecords),
        "passive=true",
        "rawSourceSaved=false",
        "",
    }
    local manifest = {
        "=== SELECTED CONTROLLER MANIFEST ===",
        "",
    }
    for index, record in ipairs(P.SelectedRecords) do
        local analysis = P.analyzeController(record)
        local fileName = P.sanitizeFileName(record.Path) .. ".txt"
        P.write(P.ControllersFolder .. "/" .. fileName, analysis)
        table.insert(combined, "\n\n" .. analysis)
        table.insert(manifest, table.concat({
            "path=" .. record.Path,
            "file=controllers/" .. fileName,
            "bytes=" .. tostring(record.SourceBytes),
            "fingerprint=" .. record.SourceHash,
            "score=" .. tostring(record.Score),
        }, " | "))
        if index % 3 == 0 then
            P.write("probe4.txt", table.concat(combined, "\n"))
            P.write(P.RunFolder .. "/04_selected_controller_manifest.txt", table.concat(manifest, "\n"))
            P.progress("Workflow " .. tostring(index) .. "/" .. tostring(#P.SelectedRecords))
            task.wait()
        end
    end
    P.write(P.RunFolder .. "/04_selected_controller_manifest.txt", table.concat(manifest, "\n"))
    P.write(P.RunFolder .. "/probe4_combined_workflows.txt", table.concat(combined, "\n"))
    P.write("probe4.txt", table.concat(combined, "\n"))
end

P.writeRelevantRemoteSummary = function()
    local lines = {
        "=== REMOTES USED BY SELECTED QUEST CONTROLLERS ===",
        "",
    }
    local found = {}
    for _, record in ipairs(P.SelectedRecords) do
        local sourceLines = string.split(record.Source, "\n")
        for _, usage in ipairs(P.extractRemoteUsage(record, sourceLines)) do
            local key = record.Path .. "|" .. usage.Logical .. "|" .. tostring(usage.Line)
            if not found[key] then
                found[key] = true
                table.insert(lines, "controller=" .. record.Path .. " | " .. P.remoteUsageLine(usage))
            end
        end
    end
    P.write(P.RunFolder .. "/05_relevant_remote_hashes.txt", table.concat(lines, "\n"))
end

P.run = function()
    P.initOutput()
    P.progress("Starting Probe 4 v" .. P.Version)
    P.log("=== ORVION PROBE 4 ===")
    P.log("VERSION=" .. P.Version)
    P.log("PASSIVE=true")
    P.log("RAW_SOURCE_SAVED=false")
    P.log("PLACE_ID=" .. tostring(game.PlaceId))
    P.log("RUN_FOLDER=" .. P.RunFolder)
    P.log("NOTE=No remote is fired/invoked; no hook or player-state mutation is installed.")
    P.discoverRemotes()
    P.dumpRelevantWorldState()
    P.scanControllers()
    P.analyzeSelectedControllers()
    P.writeRelevantRemoteSummary()
    P.progress("Phase 5/5: finalizing manifests")
    P.log("REMOTE_MAPPINGS=" .. tostring(#P.RemoteRecords))
    P.log("DECOMPILED_CANDIDATES=" .. tostring(#P.ModuleRecords))
    P.log("SELECTED_CONTROLLERS=" .. tostring(#P.SelectedRecords))
    P.log("DONE=true")
    P.write(P.RunFolder .. "/00_manifest.txt", table.concat(P.Report, "\n"))
    P.write(P.RootFolder .. "/latest_run.txt", P.RunFolder)
    P.progress("DONE - upload probe4.txt; keep the run folder if split controller files are needed")
end

P.traceback = function(err)
    if type(debug) == "table" and type(debug.traceback) == "function" then
        return debug.traceback(tostring(err), 2)
    end
    return tostring(err)
end

local ok, err = xpcall(P.run, P.traceback)
if not ok then
    P.log("FATAL_ERROR=" .. tostring(err))
    if P.RunFolder then P.write(P.RunFolder .. "/00_manifest.txt", table.concat(P.Report, "\n")) end
    P.write("probe4_error.txt", tostring(err))
    warn("[Orvion Probe 4] " .. tostring(err))
end
