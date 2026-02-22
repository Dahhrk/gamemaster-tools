--[[
    Gamemaster Tools - NPC Detector
    Automatically detects and registers NPCs from various bases
]]

GM_Tools.Detector = GM_Tools.Detector or {}

-- Check if VJ Base is installed
function GM_Tools.Detector:HasVJBase()
    return VJ_CVAR_AI_ENABLED ~= nil or istable(VJ)
end

-- Check if Droids base is installed
function GM_Tools.Detector:HasDroids()
    return istable(DrGBase) or scripted_ents.GetStored("drgbase_nextbot") ~= nil
end

-- Detect the base type of an NPC class
function GM_Tools.Detector:GetBaseType(class)
    local stored = scripted_ents.GetStored(class)
    if not stored then return GM_Tools.BaseType.DEFAULT end

    local tbl = stored.t

    -- Check for VJ Base
    if tbl.IsVJBaseSNPC or tbl.IsVJBaseNPC then
        return GM_Tools.BaseType.VJ_BASE
    end

    -- Check for DrGBase/Droids
    if tbl.IsDrGNextbot or tbl.Base == "drgbase_nextbot" then
        return GM_Tools.BaseType.DROID
    end

    -- Check inheritance chain (with loop guard to prevent infinite loops from circular inheritance)
    local base = tbl.Base
    local maxIterations = 20
    local iteration = 0
    while base and iteration < maxIterations do
        iteration = iteration + 1

        if base == "npc_vj_creature_base" or base == "npc_vj_human_base" then
            return GM_Tools.BaseType.VJ_BASE
        elseif base == "drgbase_nextbot" then
            return GM_Tools.BaseType.DROID
        elseif base == "base_nextbot" then
            return GM_Tools.BaseType.NEXTBOT
        end

        local parentStored = scripted_ents.GetStored(base)
        if parentStored and parentStored.t then
            base = parentStored.t.Base
        else
            break
        end
    end

    return GM_Tools.BaseType.DEFAULT
end

-- Scan the NPC list and register all found NPCs
function GM_Tools.Detector:ScanNPCs()
    local count = 0

    -- Get all NPCs from the spawn menu list
    local npcList = list.Get("NPC")

    if not npcList then
        local debugCvar = GetConVar("gmt_debug")
        if debugCvar and debugCvar:GetBool() then
            print("[Gamemaster Tools] Warning: NPC list not available")
        end
        return 0
    end

    for class, data in pairs(npcList) do
        local baseType = self:GetBaseType(class)

        GM_Tools.NPCRegistry:Register(class, {
            Name = data.Name or class,
            Category = data.Category or "Other",
            BaseType = baseType,
            SpawnFlags = data.SpawnFlags or 0,
            KeyValues = data.KeyValues or {},
            Weapons = data.Weapons or {},
            Model = data.Model,
        })

        count = count + 1
    end

    -- Also scan scripted_ents for any VJ/Droid NPCs not in the list
    for class, data in pairs(scripted_ents.GetList()) do
        if not GM_Tools.NPCRegistry:Get(class) then
            local baseType = self:GetBaseType(class)

            if baseType == GM_Tools.BaseType.VJ_BASE or baseType == GM_Tools.BaseType.DROID then
                GM_Tools.NPCRegistry:Register(class, {
                    Name = data.t.PrintName or class,
                    Category = data.t.Category or (GM_Tools.BaseTypeNames[baseType] or "Other"),
                    BaseType = baseType,
                })
                count = count + 1
            end
        end
    end

    local debugCvar = GetConVar("gmt_debug")
    if debugCvar and debugCvar:GetBool() then
        print("[Gamemaster Tools] Detected " .. count .. " NPCs")
        print("  - VJ Base installed: " .. tostring(self:HasVJBase()))
        print("  - Droids installed: " .. tostring(self:HasDroids()))
    end

    return count
end

-- Run detection after all addons load
hook.Add("InitPostEntity", "GM_Tools_DetectNPCs", function()
    timer.Simple(1, function()
        GM_Tools.Detector:ScanNPCs()

        -- Sync to all connected players
        GM_Tools.NPCRegistry:SyncToAll()
    end)
end)

-- Sync to players when they join
hook.Add("PlayerInitialSpawn", "GM_Tools_SyncRegistry", function(ply)
    timer.Simple(3, function()
        if IsValid(ply) then
            GM_Tools.NPCRegistry:SyncToClient(ply)
        end
    end)
end)

-- Console command to rescan
concommand.Add("gmt_rescan", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsAdmin() then return end

    GM_Tools.Detector:ScanNPCs()
    GM_Tools.NPCRegistry:SyncToAll()

    if IsValid(ply) then
        ply:ChatPrint("[Gamemaster Tools] NPC registry rescanned")
    end
end)
