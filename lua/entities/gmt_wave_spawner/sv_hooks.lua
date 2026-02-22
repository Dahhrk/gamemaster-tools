--[[
    Gamemaster Tools - Wave Spawner
    Server-side Hooks (Damage, Cleanup, Corpse Management)
]]

-- Damage scaling and death handling hook for NPCs spawned by wave spawner
hook.Add("EntityTakeDamage", "GMT_WaveSpawner_DamageScale", function(target, dmginfo)
    -- Scale damage from GMT NPCs
    local attacker = dmginfo:GetAttacker()
    if IsValid(attacker) and attacker:IsNPC() and attacker.GMT_DamageScale then
        dmginfo:ScaleDamage(attacker.GMT_DamageScale)
    end

    -- Handle GMT NPC death when health reaches 0
    if IsValid(target) and target:IsNPC() and target.GMT_SpawnedNPC then
        local damage = dmginfo:GetDamage()
        local health = target:Health()

        -- Check if this damage will kill the NPC
        if health - damage <= 0 then
            -- Force NPC to die properly
            timer.Simple(0, function()
                if IsValid(target) and target:Health() <= 0 then
                    -- For VJ Base NPCs
                    if target.VJ_BeenKilledByPlayer ~= nil then
                        target.VJ_BeenKilledByPlayer = true
                    end
                    -- Kill the NPC properly
                    if target.TakeDamageOnServer then
                        target:TakeDamageOnServer(9999, dmginfo:GetAttacker(), dmginfo:GetInflictor())
                    elseif target:GetClass():find("npc_") then
                        -- Standard NPC - use SetSchedule to trigger death
                        target:SetHealth(0)
                        target:Fire("Kill", "", 0)
                    end
                end
            end)
        end
    end
end)

-- Cache GMT NPCs to avoid expensive FindByClass calls
GMT_CachedNPCs = GMT_CachedNPCs or {}

-- Additional think hook to kill NPCs with 0 or negative health
hook.Add("Think", "GMT_WaveSpawner_NPCDeathCheck", function()
    -- Only run every 0.5 seconds to save performance
    if not GMT_NextDeathCheck or CurTime() > GMT_NextDeathCheck then
        GMT_NextDeathCheck = CurTime() + 0.5

        -- Use cached NPC list instead of FindByClass
        for i = #GMT_CachedNPCs, 1, -1 do
            local npc = GMT_CachedNPCs[i]
            if not IsValid(npc) then
                table.remove(GMT_CachedNPCs, i)
            elseif npc:Health() <= 0 then
                -- NPC should be dead but isn't - force kill
                npc:Fire("Kill", "", 0)
            end
        end
    end
end)

-- Anti-ragdoll hook - fade out or remove corpses from wave spawner NPCs
hook.Add("CreateClientsideRagdoll", "GMT_WaveSpawner_CorpseFade", function(ent, ragdoll)
    if not IsValid(ent) then return end
    if not ent.GMT_SpawnedNPC then return end
    if not IsValid(ragdoll) then return end

    -- If NPC was marked for silent removal, remove ragdoll immediately
    if ent.GMT_SilentRemove then
        ragdoll:Remove()
        return
    end

    -- Fade out corpse after configured time
    local fadeTime = (GM_Tools and GM_Tools.Config and GM_Tools.Config.CorpseFadeTime) or 3
    timer.Simple(fadeTime, function()
        if IsValid(ragdoll) then
            ragdoll:SetSaveValue("m_bFadingOut", true)
        end
    end)
end)

-- Track NPCs being silently removed for ragdoll cleanup
GMT_SilentRemoveNPCs = GMT_SilentRemoveNPCs or {}
GMT_SilentRemoveWeapons = GMT_SilentRemoveWeapons or {}

-- Hook to catch NPCs marked for silent removal before they create ragdolls
hook.Add("EntityRemoved", "GMT_WaveSpawner_TrackSilentRemove", function(ent)
    if not IsValid(ent) then return end
    if ent.GMT_SilentRemove and ent.GMT_SpawnedNPC then
        local now = CurTime()
        local pos = ent:GetPos()

        -- Store the NPC's model and position so we can identify its ragdoll/weapons
        local model = ent:GetModel()
        if model then
            GMT_SilentRemoveNPCs[model] = {
                time = now + 2,
                pos = pos
            }
        end

        -- Also track weapon classes the NPC might have had
        local activeWep = ent:GetActiveWeapon()
        if IsValid(activeWep) then
            local wepClass = activeWep:GetClass()
            GMT_SilentRemoveWeapons[wepClass] = {
                time = now + 2,
                pos = pos
            }
        end

        -- Track all weapons in inventory
        if ent.GetWeapons then
            for _, wep in ipairs(ent:GetWeapons()) do
                if IsValid(wep) then
                    GMT_SilentRemoveWeapons[wep:GetClass()] = {
                        time = now + 2,
                        pos = pos
                    }
                end
            end
        end
    end
end)

-- Anti-gib, anti-ragdoll, and anti-weapon-drop hook
hook.Add("OnEntityCreated", "GMT_WaveSpawner_GibCleanup", function(ent)
    if not SERVER then return end
    if not IsValid(ent) then return end

    local class = ent:GetClass()

    -- Handle gibs
    if class == "gib" or class == "raggib" then
        local removeTime = (GM_Tools and GM_Tools.Config and GM_Tools.Config.GibRemoveTime) or 3
        timer.Simple(removeTime, function()
            if IsValid(ent) then
                ent:Remove()
            end
        end)
        return
    end

    -- Handle ragdolls from silently removed NPCs
    if class == "prop_ragdoll" then
        timer.Simple(0, function()
            if not IsValid(ent) then return end

            local model = ent:GetModel()
            if model and GMT_SilentRemoveNPCs[model] then
                local data = GMT_SilentRemoveNPCs[model]
                local expireTime = type(data) == "table" and data.time or data
                if expireTime > CurTime() then
                    ent:Remove()
                    return
                end
            end

            -- Also check if parent/owner was a GMT NPC marked for silent removal
            local owner = ent:GetOwner()
            if IsValid(owner) and owner.GMT_SilentRemove then
                ent:Remove()
            end
        end)
        return
    end

    -- Handle dropped weapons from silently removed NPCs
    if ent:IsWeapon() or class:find("^weapon_") or class:find("^item_") then
        timer.Simple(0, function()
            if not IsValid(ent) then return end

            -- Check if this weapon was just dropped (no owner, on ground)
            local owner = ent:GetOwner()
            if not IsValid(owner) then
                local now = CurTime()
                local pos = ent:GetPos()

                -- Check if this weapon class was tracked from a silently removed NPC
                local wepData = GMT_SilentRemoveWeapons[class]
                if wepData and wepData.time > now then
                    if wepData.pos and pos:DistToSqr(wepData.pos) < 90000 then  -- Within 300 units
                        ent:Remove()
                        return
                    end
                end

                -- Also check proximity to any recently removed NPC positions (optimized: break early)
                for trackedModel, data in pairs(GMT_SilentRemoveNPCs) do
                    if type(data) == "table" and data.time > now and data.pos and pos:DistToSqr(data.pos) < 90000 then
                        ent:Remove()
                        return
                    end
                end
            end
        end)
    end
end)

-- Clean up old silent remove tracking entries periodically
timer.Create("GMT_CleanupSilentRemoveTracking", 5, 0, function()
    local now = CurTime()

    -- Clean up NPC tracking
    for model, data in pairs(GMT_SilentRemoveNPCs) do
        local expireTime = type(data) == "table" and data.time or data
        if expireTime < now then
            GMT_SilentRemoveNPCs[model] = nil
        end
    end

    -- Clean up weapon tracking
    for wepClass, data in pairs(GMT_SilentRemoveWeapons) do
        if data.time < now then
            GMT_SilentRemoveWeapons[wepClass] = nil
        end
    end
end)

-- Hook to refresh NPC relationships when a player's No Target status changes
-- This watches for changes to the common No Target networked variables
hook.Add("EntityNetworkedVarChanged", "GMT_WaveSpawner_NoTargetRefresh", function(ent, name, oldValue, newValue)
    if not IsValid(ent) or not ent:IsPlayer() then return end

    -- Check if this is a No Target variable change
    local noTargetVars = {"NoTarget", "notarget", "NoTargeted", "AdminNoTarget"}
    local isNoTargetChange = false
    for _, varName in ipairs(noTargetVars) do
        if name == varName then
            isNoTargetChange = true
            break
        end
    end

    if not isNoTargetChange then return end

    local ply = ent
    local isNoTarget = newValue == true

    -- Update all GMT spawned NPCs (use cached list)
    for _, npc in ipairs(GMT_CachedNPCs) do
        if IsValid(npc) and npc.GMT_SpawnedNPC then
            if npc.AddEntityRelationship then
                if isNoTarget then
                    -- Player is now No Target - make NPC friendly
                    npc:AddEntityRelationship(ply, D_LI, 99)
                else
                    -- Player is no longer No Target - restore based on team
                    local teamID = npc.GMT_TeamID or 2
                    local isPassive = npc.GMT_IsPassive
                    if isPassive then
                        npc:AddEntityRelationship(ply, D_NU, 99)
                    elseif teamID == 1 then
                        npc:AddEntityRelationship(ply, D_LI, 99)
                    elseif teamID == 2 then
                        npc:AddEntityRelationship(ply, D_HT, 99)
                    else
                        npc:AddEntityRelationship(ply, D_NU, 99)
                    end
                end
            end

            -- Clear enemy if current enemy is now No Target
            if isNoTarget and npc.GetEnemy and IsValid(npc:GetEnemy()) and npc:GetEnemy() == ply then
                if npc.ResetEnemy then
                    npc:ResetEnemy(false, false)
                elseif npc.SetEnemy then
                    npc:SetEnemy(nil)
                end
            end

            -- Update VJ Base tracking
            if npc.VJ_NoTarget then
                if isNoTarget then
                    npc.VJ_NoTarget[ply] = true
                else
                    npc.VJ_NoTarget[ply] = nil
                end
            end
        end
    end

    print("[GMT] Updated NPC relationships for " .. ply:Nick() .. " - No Target: " .. tostring(isNoTarget))
end)

-- Cleanup hook when GMT NPCs are removed
hook.Add("EntityRemoved", "GMT_WaveSpawner_NPCCleanup", function(ent)
    if not IsValid(ent) then return end
    if not ent.GMT_SpawnedNPC then return end
    
    -- Remove from global cache
    for i = #GMT_CachedNPCs, 1, -1 do
        if GMT_CachedNPCs[i] == ent then
            table.remove(GMT_CachedNPCs, i)
            break
        end
    end
    
    -- No additional cleanup needed - VJ Base handles its own AI
end)

-- VJ Base specific hook to prevent corpse creation for silently removed NPCs
hook.Add("VJ_CreateSNPCCorpse", "GMT_WaveSpawner_PreventVJCorpse", function(npc, corpse)
    if not IsValid(npc) then return end

    -- If NPC was marked for silent removal, remove the corpse
    if npc.GMT_SilentRemove then
        if IsValid(corpse) then
            corpse:Remove()
        end
        return true  -- Returning true tells VJ Base we handled it
    end
end)
