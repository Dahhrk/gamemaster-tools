--[[
    Gamemaster Tools - Wave Spawner
    NPC Configuration (VJ Base, DrGBase, Standard NPCs)
]]

function ENT:ConfigureNPCBase(npc, isVJBase)
    local teamID = self:GetTeamID()
    local isPassive = self:GetVJPassive()
    local tactic = self:GetTacticalBehavior()
    local tacticData = GM_Tools.Config.TacticalBehaviors and GM_Tools.Config.TacticalBehaviors[tactic]
    local weaponDiff = self:GetWeaponDifficulty()

    -- ═══════════════════════════════════════════════════════════════
    -- VJ BASE NPCs - Full feature support
    -- ═══════════════════════════════════════════════════════════════
    if isVJBase or npc.IsVJBaseSNPC or npc.VJ_NPC_Class then
        -- Squad/Team setup
        local squadName = self:GetSquadName()
        if squadName and squadName ~= "" then
            npc.VJ_NPC_Class = {squadName}
        else
            npc.VJ_NPC_Class = {"GMT_TEAM_" .. teamID}
        end

        -- CRITICAL: Enable damage from players (VJ Base damage properties)
        npc.VJ_Player_CanKillMe = true
        npc.Immune_AcidPoisonRadiation = false
        npc.Immune_Bullet = false
        npc.Immune_Dissolve = false
        npc.Immune_Electricity = false
        npc.Immune_Fire = false
        npc.Immune_Melee = false
        npc.Immune_Physics = false
        npc.Immune_Radiation = false
        npc.Immune_Sonic = false

        -- Ensure NPC can take damage from all sources
        if npc.CanReceiveDamage ~= nil then
            npc.CanReceiveDamage = true
        end
        if npc.CanTakeDamage ~= nil then
            npc.CanTakeDamage = true
        end

        -- Skill Preset
        local skillPreset = self:GetSkillPreset()
        if npc.SkillPreset and skillPreset ~= "" then
            npc.SkillPreset = skillPreset
        end

        -- ═══════════════════════════════════════════════════════════════
        -- VJ BASE PROPERTIES - Combat & Weapon Settings
        -- ═══════════════════════════════════════════════════════════════

        -- Weapon Accuracy (lower = better) - scale based on weapon difficulty
        if npc.Weapon_Accuracy ~= nil then
            -- 0=Poor: 2.5, 1=Average: 1.5, 2=Good: 1.0, 3=VeryGood: 0.7, 4=Perfect: 0.4
            local accuracyMap = {[0] = 2.5, [1] = 1.5, [2] = 1.0, [3] = 0.7, [4] = 0.4}
            npc.Weapon_Accuracy = accuracyMap[weaponDiff] or 1.0
        end

        -- Fire while moving - crucial for march & attack behaviors
        if npc.Weapon_CanMoveFire ~= nil then
            local canMoveFire = (tactic == 0) or (tactic == 3) or (tactic == 5) or (tactic == 7) or (tactic == 8)
            -- March & Attack, Rush, Flank, Encircle, Seek & Destroy
            npc.Weapon_CanMoveFire = canMoveFire
        end

        -- Strafe while firing - for more dynamic combat
        if npc.Weapon_Strafe ~= nil then
            npc.Weapon_Strafe = not (tacticData and tacticData.holdPosition)
        end

        -- Retreat distance - for defensive/retreat behaviors
        if npc.Weapon_RetreatDistance ~= nil then
            if tacticData and tacticData.defensive then
                npc.Weapon_RetreatDistance = 300  -- Keep distance when defensive
            elseif tacticData and tacticData.retreat then
                npc.Weapon_RetreatDistance = 500  -- Larger retreat when in retreat mode
            else
                npc.Weapon_RetreatDistance = 100  -- Normal
            end
        end

        -- Guard mode - for hold position behavior
        if npc.IsGuard ~= nil then
            npc.IsGuard = (tacticData and tacticData.holdPosition) or false
        end

        -- Limit chase distance - for defensive/hold behaviors
        if npc.LimitChaseDistance ~= nil then
            if tacticData and (tacticData.holdPosition or tacticData.defensive) then
                npc.LimitChaseDistance = true
                if npc.LimitChaseDistance_Max ~= nil then
                    npc.LimitChaseDistance_Max = tacticData.marchDistance > 0 and tacticData.marchDistance or 500
                end
            else
                npc.LimitChaseDistance = false
            end
        end

        -- Sight distance - adjust based on behavior
        if npc.SightDistance ~= nil then
            if tacticData and tacticData.ambush then
                npc.SightDistance = tacticData.ambushRange or 400  -- Short range for ambush
            elseif skillPreset == "sniper" then
                npc.SightDistance = 10000  -- Long range for snipers
            else
                npc.SightDistance = 6500  -- Default
            end
        end

        -- ═══════════════════════════════════════════════════════════════
        -- GRENADE SETTINGS - Enhanced with frequency control
        -- ═══════════════════════════════════════════════════════════════
        local useGrenades = self:GetVJGrenades()
        if npc.HasGrenadeAttack ~= nil then
            npc.HasGrenadeAttack = useGrenades
        end
        if useGrenades then
            -- Grenadier preset throws more frequently
            if skillPreset == "grenadier" and npc.GrenadeAttackChance ~= nil then
                npc.GrenadeAttackChance = 2  -- 1 in 2 chance
            end
            -- Suppression fire behavior throws grenades more
            if tacticData and tacticData.suppression and npc.GrenadeAttackChance ~= nil then
                npc.GrenadeAttackChance = 3  -- 1 in 3 chance
            end
        end

        -- ═══════════════════════════════════════════════════════════════
        -- VJ BASE SETTINGS - Core Behaviors
        -- ═══════════════════════════════════════════════════════════════

        -- Wandering
        local wandering = self:GetVJWandering()
        npc.DisableWandering = not wandering
        npc.IdleAlwaysWander = wandering
        if npc.LastHiddenZone_CanWander ~= nil then
            npc.LastHiddenZone_CanWander = wandering
        end

        -- Call for Help - with distance based on behavior
        if npc.CallForHelp ~= nil then
            npc.CallForHelp = self:GetVJCallForHelp()
            if npc.CallForHelpDistance ~= nil and self:GetVJCallForHelp() then
                npc.CallForHelpDistance = 2500  -- Increased range
            end
        end

        -- Can receive orders from allies
        if npc.CanReceiveOrders ~= nil then
            npc.CanReceiveOrders = self:GetVJCallForHelp()
        end

        -- God Mode - explicitly set to ensure damage works
        local isGodMode = self:GetVJGodMode()
        npc.GodMode = isGodMode
        -- Also set VJ_God_Mode for some VJ Base versions
        if npc.VJ_God_Mode ~= nil then
            npc.VJ_God_Mode = isGodMode
        end

        -- Bleeding
        local bleeding = self:GetVJBleeding()
        if npc.HasBloodDecal ~= nil then
            npc.HasBloodDecal = bleeding
            npc.HasBloodPool = bleeding
        end
        if npc.Bleeds ~= nil then
            npc.Bleeds = bleeding
        end

        -- Become Enemy to Player on Death (only if NOT passive)
        if npc.BecomeEnemyToPlayer ~= nil then
            npc.BecomeEnemyToPlayer = self:GetVJBecomeEnemy() and not isPassive
        end

        -- ═══════════════════════════════════════════════════════════════
        -- ADDITIONAL VJ BASE PROPERTIES
        -- ═══════════════════════════════════════════════════════════════

        -- Melee Attack
        local hasMelee = self:GetVJMeleeAttack()
        if npc.HasMeleeAttack ~= nil then
            npc.HasMeleeAttack = hasMelee
        end

        -- Range Attack (secondary ranged attack like rockets, projectiles)
        local hasRange = self:GetVJRangeAttack()
        if npc.HasRangeAttack ~= nil then
            npc.HasRangeAttack = hasRange
        end

        -- Leap Attack
        local hasLeap = self:GetVJLeapAttack()
        if npc.HasLeapAttack ~= nil then
            npc.HasLeapAttack = hasLeap
        end

        -- Follow Player (owner of spawner)
        local followPlayer = self:GetVJFollowPlayer()
        if followPlayer then
            local owner = self:GetPlayer()
            if IsValid(owner) then
                if npc.FollowPlayer ~= nil then
                    npc.FollowPlayer = true
                end
                if npc.VJ_TheController ~= nil then
                    npc.VJ_TheController = owner
                end
                if npc.FollowingPlayer ~= nil then
                    npc.FollowingPlayer = owner
                end
                -- Use VJ Base's follow system if available
                if npc.SetFollow then
                    npc:SetFollow(owner)
                elseif npc.VJ_TASK_FOLLOW_PLAYER then
                    npc:VJ_TASK_FOLLOW_PLAYER(owner)
                end
            end
        end

        -- NPC Sounds
        local hasSounds = self:GetVJHasSounds()
        if npc.HasSounds ~= nil then
            npc.HasSounds = hasSounds
        end
        if not hasSounds then
            -- Disable specific sound types when sounds are off
            if npc.HasFootStepSound ~= nil then npc.HasFootStepSound = false end
            if npc.HasIdleSounds ~= nil then npc.HasIdleSounds = false end
            if npc.HasAlertSounds ~= nil then npc.HasAlertSounds = false end
            if npc.HasPainSounds ~= nil then npc.HasPainSounds = false end
            if npc.HasDeathSounds ~= nil then npc.HasDeathSounds = false end
            if npc.HasMeleeAttackSounds ~= nil then npc.HasMeleeAttackSounds = false end
        end

        -- Flinching
        local canFlinch = self:GetVJCanFlinch()
        if npc.CanFlinch ~= nil then
            npc.CanFlinch = canFlinch
        end
        if npc.HasHitGroupFlinching ~= nil then
            npc.HasHitGroupFlinching = canFlinch
        end

        -- Death Ragdoll
        local deathRagdoll = self:GetVJDeathRagdoll()
        if npc.HasDeathRagdoll ~= nil then
            npc.HasDeathRagdoll = deathRagdoll
        end
        if npc.HasDeathCorpse ~= nil then
            npc.HasDeathCorpse = deathRagdoll
        end
        if not deathRagdoll then
            -- Also disable gibs if no ragdoll
            if npc.AllowedToGib ~= nil then
                npc.AllowedToGib = false
            end
        end

        -- Run Away on Unknown Damage
        local runOnDamage = self:GetVJRunOnDamage()
        if npc.RunAwayOnUnknownDamage ~= nil then
            npc.RunAwayOnUnknownDamage = runOnDamage
        end

        -- Medic Behavior
        local isMedic = self:GetVJMedic()
        if isMedic then
            if npc.IsMedicSNPC ~= nil then
                npc.IsMedicSNPC = true
            end
            if npc.Medic_CanBeHealed ~= nil then
                npc.Medic_CanBeHealed = true
            end
            if npc.AnimTbl_Medic_GiveHealth ~= nil and type(npc.AnimTbl_Medic_GiveHealth) == "table" then
                -- Medic will use default heal animation
            end
        end

        -- Sight Distance (override default if set)
        local sightDist = self:GetVJSightDistance()
        if sightDist > 0 and npc.SightDistance ~= nil then
            npc.SightDistance = sightDist
        end

        -- Hearing Distance
        local hearingDist = self:GetVJHearingDistance()
        if hearingDist > 0 and npc.HearingDistance ~= nil then
            npc.HearingDistance = hearingDist
        end

        -- ═══════════════════════════════════════════════════════════════
        -- MOVEMENT & BEHAVIOR PROPERTIES
        -- ═══════════════════════════════════════════════════════════════

        -- Dodging
        local canDodge = self:GetVJCanDodge()
        if npc.CanDodge ~= nil then
            npc.CanDodge = canDodge
        end
        if npc.HasDodge ~= nil then
            npc.HasDodge = canDodge
        end

        -- Use Cover
        local useCover = self:GetVJUseCover()
        if npc.CanUseCover ~= nil then
            npc.CanUseCover = useCover
        end
        if npc.CoverEnabled ~= nil then
            npc.CoverEnabled = useCover
        end

        -- Investigate Sounds
        local investigate = self:GetVJInvestigate()
        if npc.HasInvestigate ~= nil then
            npc.HasInvestigate = investigate
        end
        if npc.CanInvestigate ~= nil then
            npc.CanInvestigate = investigate
        end

        -- Crouching
        local canCrouch = self:GetVJCanCrouch()
        if npc.CanCrouchOnWeaponAttack ~= nil then
            npc.CanCrouchOnWeaponAttack = canCrouch
        end
        if npc.AnimTbl_WeaponAttackCrouch ~= nil and not canCrouch then
            npc.AnimTbl_WeaponAttackCrouch = {}
        end

        -- Open Doors
        local openDoors = self:GetVJOpenDoors()
        if npc.CanOpenDoors ~= nil then
            npc.CanOpenDoors = openDoors
        end
        if npc.HasDoor ~= nil then
            npc.HasDoor = openDoors
        end

        -- Push Props
        local pushProps = self:GetVJPushProps()
        if npc.PushProps ~= nil then
            npc.PushProps = pushProps
        end
        if npc.AllowPushOnPath ~= nil then
            npc.AllowPushOnPath = pushProps
        end

        -- Movement Speed Multiplier
        local moveSpeed = self:GetVJMoveSpeed()
        if moveSpeed and moveSpeed ~= 1.0 then
            if npc.AnimationPlaybackRate ~= nil then
                npc.AnimationPlaybackRate = moveSpeed
            end
            -- Apply to actual movement speeds
            if npc.WalkSpeed and type(npc.WalkSpeed) == "number" then
                npc.WalkSpeed = npc.WalkSpeed * moveSpeed
            end
            if npc.RunSpeed and type(npc.RunSpeed) == "number" then
                npc.RunSpeed = npc.RunSpeed * moveSpeed
            end
        end

        -- ═══════════════════════════════════════════════════════════════
        -- MOVEMENT SETTINGS - Enhanced for tactical behaviors
        -- ═══════════════════════════════════════════════════════════════

        -- Can turn while moving - essential for combat
        if npc.CanTurnWhileMoving ~= nil then
            npc.CanTurnWhileMoving = true
        end

        -- Face enemy constantly - varies by behavior
        if npc.ConstantlyFaceEnemy ~= nil then
            -- Don't face enemy during retreat (look where you're going)
            npc.ConstantlyFaceEnemy = not (tacticData and tacticData.retreat)
        end
        if npc.ConstantlyFaceEnemy_IfVisible ~= nil then
            npc.ConstantlyFaceEnemy_IfVisible = true
        end
        if npc.ConstantlyFaceEnemy_IfAttacking ~= nil then
            npc.ConstantlyFaceEnemy_IfAttacking = true
        end

        -- Disable chasing for hold position
        if npc.DisableChasingEnemy ~= nil then
            npc.DisableChasingEnemy = (tacticData and tacticData.holdPosition and tacticData.marchDistance == 0)
        end

        -- ═══════════════════════════════════════════════════════════════
        -- PASSIVE MODE & PLAYER RELATIONS
        -- ═══════════════════════════════════════════════════════════════

        -- Passive Mode - Apply FIRST before any enemy targeting
        if isPassive then
            self:SetVJPassiveMode(npc, true)
        end

        -- VJ Base friendly to players if passive, friendly team, or neutral
        if isPassive or teamID == 1 or teamID == 3 then
            if npc.VJ_FriendlyWithPlayers ~= nil then
                npc.VJ_FriendlyWithPlayers = true
            end
            if npc.PlayerFriendly ~= nil then
                npc.PlayerFriendly = true
            end
        end

        -- No Target players handling (cache player list)
        if npc.VJ_NoTarget == nil then
            npc.VJ_NoTarget = {}
        end

        local players = player.GetAll()
        for i = 1, #players do
            local ply = players[i]
            if IsValid(ply) and GMT_IsPlayerNoTarget(ply) then
                npc.VJ_NoTarget[ply] = true
                if npc.VJ_AddFriendlyEntity then
                    npc:VJ_AddFriendlyEntity(ply)
                end
            end
        end

        -- Hook into VJ Base's enemy selection to skip No Target players
        local oldOnFoundEnemy = npc.OnFoundEnemy
        npc.OnFoundEnemy = function(self, ent, ...)
            if IsValid(ent) and ent:IsPlayer() and GMT_IsPlayerNoTarget(ent) then
                return true  -- Return true to skip this enemy
            end
            if oldOnFoundEnemy then
                return oldOnFoundEnemy(self, ent, ...)
            end
        end
    end

    -- ═══════════════════════════════════════════════════════════════
    -- DrGBase / DROID NPCs
    -- ═══════════════════════════════════════════════════════════════
    if npc.IsDrGNextbot then
        local squadName = self:GetSquadName()
        if npc.SetFaction then
            if squadName and squadName ~= "" then
                npc:SetFaction(squadName)
            else
                npc:SetFaction("GMT_TEAM_" .. teamID)
            end
        end

        -- Health scaling
        if npc.SetMaxHealth then
            local health = self:GetNPCHealth()
            npc:SetMaxHealth(health)
            npc:SetHealth(health)
        end

        -- Enable damage for DrGBase
        if npc.SetGodMode then
            npc:SetGodMode(self:GetVJGodMode())
        end
        if npc.CanTakeDamage ~= nil then
            npc.CanTakeDamage = true
        end

        -- Aggressive behavior
        if npc.SetAggressive ~= nil then
            npc:SetAggressive(not isPassive and teamID == 2)
        end

        -- DrGBase movement speed
        if npc.SetRunSpeed and tacticData then
            if tacticData.sprint then
                npc:SetRunSpeed(300)
            end
        end

        -- DrGBase wandering
        if npc.SetWander then
            npc:SetWander(self:GetVJWandering())
        end
    end

    -- ═══════════════════════════════════════════════════════════════
    -- SIMFPHYS / LVS VEHICLE NPCs
    -- ═══════════════════════════════════════════════════════════════
    if npc.LVS or npc.simfphys then
        -- Apply team/faction for vehicle NPCs
        if npc.SetTeam then
            npc:SetTeam(teamID)
        end
        -- Health for vehicles
        local health = self:GetNPCHealth()
        if npc.SetMaxHealth then
            npc:SetMaxHealth(health)
            npc:SetHealth(health)
        end
    end

    -- ═══════════════════════════════════════════════════════════════
    -- GENERIC NEXTBOT NPCs (non-DrGBase, non-VJ)
    -- ═══════════════════════════════════════════════════════════════
    if npc:IsNextBot() and not npc.IsDrGNextbot and not isVJBase then
        local health = self:GetNPCHealth()
        if health > 0 then
            npc:SetHealth(health)
            if npc.SetMaxHealth then
                npc:SetMaxHealth(health)
            end
        end

        if npc.SetSquad then
            local squadName = self:GetSquadName()
            if squadName and squadName ~= "" then
                npc:SetSquad(squadName)
            else
                npc:SetSquad("GMT_TEAM_" .. teamID)
            end
        end

        -- NextBot-specific settings
        if npc.SetRunSpeed and tacticData and tacticData.sprint then
            local currentSpeed = npc:GetRunSpeed() or 200
            npc:SetRunSpeed(currentSpeed * 1.5)
        end

        -- Enemy handling (cache player list)
        if npc.SetEnemy and teamID == 2 and not isPassive then
            local players = player.GetAll()
            for i = 1, #players do
                local ply = players[i]
                if IsValid(ply) and not GMT_IsPlayerNoTarget(ply) then
                    npc:SetEnemy(ply)
                    break
                end
            end
        end
    end

    -- ═══════════════════════════════════════════════════════════════
    -- STANDARD SOURCE NPCs (npc_combine_s, npc_metropolice, etc.)
    -- ═══════════════════════════════════════════════════════════════
    if npc:IsNPC() and not isVJBase and not npc.IsDrGNextbot then
        -- Clamp health once more on the server for safety
        local clampedHealth = math.Clamp(self:GetNPCHealth(), 1, 100000)
        if self:GetNPCHealth() ~= clampedHealth then
            self:SetNPCHealth(clampedHealth)
        end

        -- Weapon proficiency mapping
        local proficiencyMap = {
            [0] = WEAPON_PROFICIENCY_POOR,
            [1] = WEAPON_PROFICIENCY_AVERAGE,
            [2] = WEAPON_PROFICIENCY_GOOD,
            [3] = WEAPON_PROFICIENCY_VERY_GOOD,
            [4] = WEAPON_PROFICIENCY_PERFECT,
        }
        if npc.SetCurrentWeaponProficiency then
            npc:SetCurrentWeaponProficiency(proficiencyMap[weaponDiff] or WEAPON_PROFICIENCY_AVERAGE)
        end

        -- Squad setup for standard NPCs
        local squadName = self:GetSquadName()
        if npc.SetSquad then
            if squadName and squadName ~= "" then
                npc:SetSquad(squadName)
            else
                npc:SetSquad("GMT_TEAM_" .. teamID)
            end
        end

        -- Capabilities - ensure they can use weapons
        if npc.CapabilitiesAdd then
            npc:CapabilitiesAdd(CAP_USE_WEAPONS)
            npc:CapabilitiesAdd(CAP_MOVE_GROUND)
            npc:CapabilitiesAdd(CAP_MOVE_SHOOT)  -- Fire while moving
            if tacticData and tacticData.sprint then
                npc:CapabilitiesAdd(CAP_MOVE_JUMP)
            end
        end
    end

    -- ═══════════════════════════════════════════════════════════════
    -- DISPOSITION SETUP (All NPC Types)
    -- ═══════════════════════════════════════════════════════════════
    if npc.AddEntityRelationship then
        -- Cache player list
        local players = player.GetAll()
        for i = 1, #players do
            local ply = players[i]
            if IsValid(ply) then
                if GMT_IsPlayerNoTarget(ply) then
                    npc:AddEntityRelationship(ply, D_LI, 99)
                elseif isPassive then
                    npc:AddEntityRelationship(ply, D_NU, 99)
                elseif teamID == 1 then -- Friendly (GAR)
                    npc:AddEntityRelationship(ply, D_LI, 99)
                elseif teamID == 2 then -- Enemy (CIS)
                    npc:AddEntityRelationship(ply, D_HT, 99)
                else -- Neutral
                    npc:AddEntityRelationship(ply, D_NU, 99)
                end
            end
        end

        -- Make NPCs of same team allies (use cached NPC list)
        for j = 1, #GMT_CachedNPCs do
            local otherNPC = GMT_CachedNPCs[j]
            if IsValid(otherNPC) and otherNPC ~= npc and otherNPC.GMT_TeamID == teamID then
                npc:AddEntityRelationship(otherNPC, D_LI, 99)
            end
        end
    end

    -- Store team ID on NPC for later reference
    npc.GMT_TeamID = teamID
    npc.GMT_IsPassive = isPassive
    npc.GMT_TacticData = tacticData
    
    -- Debug print only if debug mode enabled (reduce console spam)
    local debugCvar = GetConVar("gmt_debug")
    if debugCvar and debugCvar:GetBool() then
        print("[GMT] NPC behavior configured - Hostile: " .. tostring(isPassive == false and teamID == 2) .. ", VJ: " .. tostring(isVJBase))
    end
end

-- Helper function to set VJ passive mode
function ENT:SetVJPassiveMode(npc, makePassive)
    if not IsValid(npc) then return end

    if makePassive then
        npc.Behavior = VJ_BEHAVIOR_PASSIVE or 3
        if npc.StopCurrentSchedule then npc:StopCurrentSchedule() end
        if npc.ResetEnemy then npc:ResetEnemy(false, false) end
        if IsValid(npc:GetActiveWeapon()) then
            npc:GetActiveWeapon().NPC_TimeUntilFire = 999999999999999
        end
    else
        npc.Behavior = VJ_BEHAVIOR_AGGRESSIVE or 1
        if npc.ResetEnemy then npc:ResetEnemy(true, true) end
        if IsValid(npc:GetActiveWeapon()) then
            npc:GetActiveWeapon().NPC_TimeUntilFire = 0
        end
    end
end
