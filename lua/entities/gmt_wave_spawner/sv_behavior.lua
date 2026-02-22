--[[
    Gamemaster Tools - Wave Spawner
    NPC Behavior Enforcement & Orders
]]

-- Simplified behavior enforcement - periodically re-acquire enemies for hostile NPCs
function ENT:StartBehaviorEnforcement(npc)
    if not IsValid(npc) then return end

    local behaviorTimerName = "GMT_Behavior_" .. self:EntIndex() .. "_" .. npc:EntIndex()
    local isVJBase = npc.GMT_IsVJBaseNPC or npc.IsVJBaseSNPC or npc.VJ_NPC_Class
    local teamID = self:GetTeamID()
    local isPassive = self:GetVJPassive()
    local isHostile = (teamID == 2) and not isPassive

    -- Simple behavior enforcement - just re-acquire enemies every 3 seconds
    timer.Create(behaviorTimerName, 3, 0, function()
        if not IsValid(npc) then
            timer.Remove(behaviorTimerName)
            return
        end

        -- Re-acquire enemy for hostile NPCs that have lost their target
        if isHostile then
            local hasEnemy = npc.GetEnemy and IsValid(npc:GetEnemy())
            if not hasEnemy then
                local npcPos = npc:GetPos()
                local players = player.GetAll() -- Cache player list
                local maxDistSqr = 3000 * 3000 -- Use squared distance for performance
                for i = 1, #players do
                    local ply = players[i]
                    if IsValid(ply) and ply:Alive() and not GMT_IsPlayerNoTarget(ply) then
                        local distSqr = ply:GetPos():DistToSqr(npcPos)
                        if distSqr < maxDistSqr then
                            if isVJBase then
                                if npc.ForceSetEnemy then
                                    npc:ForceSetEnemy(ply, true)
                                elseif npc.SetEnemy then
                                    npc:SetEnemy(ply)
                                end
                            else
                                if npc.UpdateEnemyMemory then
                                    npc:UpdateEnemyMemory(ply, ply:GetPos())
                                end
                                if npc.SetEnemy then
                                    npc:SetEnemy(ply)
                                end
                            end
                            break
                        end
                    end
                end
            end
        end
    end)
end

-- Give NPCs behavior orders based on tactical setting
-- Simplified behavior setup - Let VJ Base's natural AI handle movement
-- We only set enemy relationships and basic behavior flags
function ENT:GiveMarchOrders(npc, faceAngle)
    if not IsValid(npc) then return end

    local tactic = self:GetTacticalBehavior()
    local tacticData = GM_Tools.Config.TacticalBehaviors and GM_Tools.Config.TacticalBehaviors[tactic]

    -- Check if this is a VJ Base NPC
    local isVJBase = npc.GMT_IsVJBaseNPC or npc.IsVJBaseSNPC or npc.VJ_NPC_Class or npc.IsVJBaseNPC or
                     (npc.VJ_TheController ~= nil) or (npc.Weapon_StartingAmmoAmount ~= nil)

    -- Check if NPC should be passive (not targeting players)
    local isPassive = self:GetVJPassive()
    local teamID = self:GetTeamID()
    local isHostile = (teamID == 2) and not isPassive  -- CIS = hostile, unless passive mode

    -- Store basic flags on NPC
    npc.GMT_IsVJBase = isVJBase
    npc.GMT_IsHostile = isHostile
    npc.GMT_IsPassive = isPassive
    npc.GMT_TeamID = teamID

    -- Find nearest targetable player for enemy targeting (cache player list)
    local nearestPly = nil
    local nearestDistSqr = math.huge
    local players = player.GetAll()
    local npcPos = npc:GetPos()
    for i = 1, #players do
        local ply = players[i]
        if IsValid(ply) and ply:Alive() and not GMT_IsPlayerNoTarget(ply) then
            local distSqr = ply:GetPos():DistToSqr(npcPos)
            if distSqr < nearestDistSqr then
                nearestDistSqr = distSqr
                nearestPly = ply
            end
        end
    end

    -- Configure basic VJ Base behavior
    if isVJBase then
        -- Wandering behavior based on tactic
        local doPatrol = tacticData and tacticData.patrol or false
        local holdPosition = tacticData and tacticData.holdPosition or false

        npc.DisableWandering = holdPosition and not doPatrol
        npc.IdleAlwaysWander = doPatrol

        -- Always face enemies in combat
        npc.ConstantlyFaceEnemy = true
        if npc.CanTurnWhileMoving ~= nil then
            npc.CanTurnWhileMoving = true
        end

        -- Set enemy for hostile NPCs - VJ Base will handle chasing
        if isHostile and nearestPly then
            if npc.ForceSetEnemy then
                npc:ForceSetEnemy(nearestPly, true)
            elseif npc.SetEnemy then
                npc:SetEnemy(nearestPly)
            end
        end
    end

    -- Configure DrGBase NPCs
    if npc.IsDrGNextbot then
        if npc.SetAggressive and isHostile then
            npc:SetAggressive(true)
        end
        if isHostile and nearestPly and npc.SetEnemy then
            npc:SetEnemy(nearestPly)
        end
    end

    -- Configure standard NPCs
    if npc:IsNPC() and not isVJBase and not npc.IsDrGNextbot then
        if isHostile and nearestPly then
            if npc.UpdateEnemyMemory then
                npc:UpdateEnemyMemory(nearestPly, nearestPly:GetPos())
            end
            if npc.SetEnemy then
                npc:SetEnemy(nearestPly)
            end
        end
    end

    print("[GMT] NPC behavior configured - Hostile: " .. tostring(isHostile) .. ", VJ: " .. tostring(isVJBase))
end
