--[[
    Gamemaster Tools - Wave Spawner Entity
    Main server-side file - Core entity logic
]]

AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

-- Include modular server files
include("sv_arrival.lua")      -- Ship arrival animations
include("sv_spawning.lua")     -- Spawn wave, formations, NPC spawning
include("sv_npc_config.lua")   -- NPC configuration (VJ Base, DrGBase, etc.)
include("sv_behavior.lua")     -- Behavior enforcement, march orders
include("sv_hooks.lua")        -- Damage scaling, cleanup hooks

-- ═══════════════════════════════════════════════════════════════
-- GLOBAL HELPER FUNCTIONS
-- ═══════════════════════════════════════════════════════════════

-- Helper function to check if a player has "No Target" admin status
-- Made global so other files can access it
function GMT_IsPlayerNoTarget(ply)
    if not IsValid(ply) then return true end
    if ply:IsFlagSet(FL_NOTARGET) then return true end
    if ply:GetNWBool("NoTarget", false) then return true end
    if ply:GetNWBool("notarget", false) then return true end
    if ply.NoTarget then return true end
    if ply.sam_notarget then return true end
    return false
end

-- ═══════════════════════════════════════════════════════════════
-- DEBUG COMMANDS
-- ═══════════════════════════════════════════════════════════════

-- Debug command to list spawned NPCs
concommand.Add("gmt_debug_npcs", function(ply)
    local count = 0
    for _, npc in ipairs(ents.GetAll()) do
        if IsValid(npc) and npc.GMT_SpawnedNPC then
            count = count + 1
            local enemy = npc.GetEnemy and npc:GetEnemy()
            print("[GMT] NPC " .. npc:EntIndex() .. ": " .. npc:GetClass() ..
                  ", HP: " .. npc:Health() ..
                  ", Enemy: " .. tostring(IsValid(enemy) and enemy:GetClass() or "none"))
        end
    end
    print("[GMT] Total GMT NPCs: " .. count)
    if ply and IsValid(ply) then
        ply:ChatPrint("[GMT] Found " .. count .. " spawned NPCs - check console")
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- MODEL & APPEARANCE
-- ═══════════════════════════════════════════════════════════════

-- Get the appropriate model for a team ID (or debug model)
function ENT:GetModelForTeam(teamID, useDebug)
    -- First check if a custom model path is provided - this takes priority
    local customPath = self:GetDebugModelPath()
    if customPath and customPath ~= "" then
        if util.IsValidModel(customPath) then
            print("[GMT] Using custom model: " .. customPath)
            return customPath
        else
            print("[GMT] Custom model not valid: " .. customPath .. " - falling back")
        end
    end

    -- Check if using default debug model (oil drum)
    if useDebug or self:GetUseDebugModel() then
        local debugModel = GM_Tools.Config.DebugModel or "models/props_c17/oildrum001.mdl"
        if util.IsValidModel(debugModel) then
            return debugModel
        end
    end

    local teamData = GM_Tools.Config.Teams[teamID]
    if teamData and teamData.defaultModel then
        -- Check if model exists
        if util.IsValidModel(teamData.defaultModel) then
            return teamData.defaultModel
        end
    end
    return GM_Tools.Config.FallbackModel or "models/props_combine/combine_mine01.mdl"
end

-- Update model when team changes (or debug mode toggles)
function ENT:UpdateModelForTeam()
    local teamID = self:GetTeamID()
    local useDebug = self:GetUseDebugModel()
    local newModel = self:GetModelForTeam(teamID, useDebug)

    if self:GetModel() ~= newModel then
        self:SetModel(newModel)
        self:PhysicsInit(SOLID_VPHYSICS)

        -- Maintain collision settings - WEAPON group lets NPCs walk through
        self:SetCollisionGroup(COLLISION_GROUP_WEAPON)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
            phys:EnableMotion(false)  -- Keep locked in place
        end
    end
end

-- Apply spawner health settings
function ENT:ApplySpawnerHealth()
    local health = self:GetSpawnerHealth()
    if health > 0 then
        self:SetHealth(health)
        self:SetMaxHealth(health)
        print("[GMT] Spawner health set to: " .. health)
    else
        -- Invulnerable - set very high health
        self:SetHealth(999999)
        self:SetMaxHealth(999999)
    end
end

-- ═══════════════════════════════════════════════════════════════
-- DAMAGE HANDLING
-- ═══════════════════════════════════════════════════════════════

-- Handle spawner taking damage (if it has health)
function ENT:OnTakeDamage(dmginfo)
    local spawnerHealth = self:GetSpawnerHealth()

    -- If health is 0, spawner is invulnerable
    if spawnerHealth <= 0 then
        return 0
    end

    local damage = dmginfo:GetDamage()
    local newHealth = self:Health() - damage

    self:SetHealth(newHealth)

    -- Visual feedback
    local effectdata = EffectData()
    effectdata:SetOrigin(self:GetPos())
    effectdata:SetMagnitude(damage)
    util.Effect("cball_bounce", effectdata)

    if newHealth <= 0 then
        self:OnSpawnerDestroyed(dmginfo:GetAttacker())
    end

    return damage
end

-- Handle spawner destruction
function ENT:OnSpawnerDestroyed(attacker)
    -- Prevent double-destruction
    if self.IsBeingDestroyed then return end
    self.IsBeingDestroyed = true

    local config = GM_Tools.Config.SpawnerHealth or {}

    -- Stop waves first
    self:SetActive(false)

    -- Clean up all timers
    local spawnerID = self:EntIndex()
    for _, npc in ipairs(self.SpawnedNPCs or {}) do
        if IsValid(npc) then
            local npcID = npc:EntIndex()
            -- Remove all timers associated with this NPC
            timer.Remove("GMT_Behavior_" .. spawnerID .. "_" .. npcID)
        end
    end

    -- Store position before any operations
    local pos = self:GetPos()

    -- Announce destruction (cache player list)
    local players = player.GetAll()
    local msg = "[GMT] Wave spawner destroyed!"
    if self.TotalNPCsSpawned and self.TotalNPCsSpawned > 0 then
        msg = msg .. " | Spawned: " .. self.TotalNPCsSpawned .. " NPCs"
    end
    for i = 1, #players do
        local ply = players[i]
        if IsValid(ply) then
            ply:ChatPrint(msg)
        end
    end

    -- Kill spawned NPCs if configured - prevent all ragdolls/corpses/weapons
    if self:GetKillNPCsOnDeath() or config.KillNPCsOnDeath then
        for _, npc in ipairs(self.SpawnedNPCs or {}) do
            if IsValid(npc) then
                -- Mark for silent removal (used by hooks)
                npc.GMT_SilentRemove = true

                -- FIRST: Remove any weapons the NPC is holding
                local weapon = npc:GetActiveWeapon()
                if IsValid(weapon) then
                    weapon:Remove()
                end

                -- Remove all weapons from inventory
                if npc.GetWeapons then
                    for _, wep in ipairs(npc:GetWeapons()) do
                        if IsValid(wep) then
                            wep:Remove()
                        end
                    end
                end

                -- For VJ Base NPCs, disable ALL death effects
                if npc.IsVJBaseSNPC or npc.VJ_NPC_Class then
                    npc.HasDeathRagdoll = false
                    npc.HasDeathCorpse = false
                    npc.HasDeathAnimation = false
                    npc.GibOnDeath = false
                    npc.HasGibOnDeath = false
                    npc.HasItemDropsOnDeath = false
                    npc.DropWeaponOnDeath = false
                    npc.HasDeathNotice = false
                    npc.Weapons = {}  -- Clear weapon table
                    -- Override corpse/death functions
                    npc.CreateDeathCorpse = function() return nil end
                    npc.CreateGibEntity = function() return nil end
                    npc.OnDeath = function() end
                    npc.OnKilled = function() end
                end

                -- Prevent death sequence from triggering
                npc:SetHealth(999999)  -- High health prevents death events
                npc:AddFlags(FL_DISSOLVING)  -- Prevents ragdoll creation
                npc:AddEFlags(EFL_NO_MEGAPHYSCANNON_RAGDOLL)  -- Extra ragdoll prevention

                -- Make invisible/non-solid before removal
                npc:SetNoDraw(true)
                npc:SetNotSolid(true)

                -- Remove immediately
                npc:Remove()
            end
        end
    end

    -- Explosion effect
    if config.ExplosionOnDeath ~= false then
        local explosionDamage = config.ExplosionDamage or 100
        local explosionRadius = config.ExplosionRadius or 200

        -- Create explosion effect
        local effectdata = EffectData()
        effectdata:SetOrigin(pos)
        effectdata:SetScale(2)
        util.Effect("Explosion", effectdata)

        -- Deal explosion damage using world as inflictor to avoid issues
        util.BlastDamage(game.GetWorld(), attacker or game.GetWorld(), pos, explosionRadius, explosionDamage)

        -- Sound
        sound.Play("ambient/explosions/explode_4.wav", pos, 100, 100)
    end

    -- Clear NPC list to prevent OnRemove from double-processing
    self.SpawnedNPCs = {}

    -- Remove spawner safely with slight delay
    if config.DestroyOnDeath ~= false then
        SafeRemoveEntity(self)
    end
end

-- ═══════════════════════════════════════════════════════════════
-- ENTITY INITIALIZATION
-- ═══════════════════════════════════════════════════════════════

function ENT:Initialize()
    self.SpawnedNPCs = {}
    
    -- Statistics tracking
    self:SetTotalNPCsSpawned(0)
    self:SetTotalNPCsKilled(0)
    self.TotalNPCsSpawned = 0 -- Keep local for faster access
    self.TotalNPCsKilled = 0
    self.WaveStartTime = 0

    -- Wave Defaults
    self:SetNPCClass("npc_combine_s")
    self:SetNPCsPerWave(5)
    self:SetWaveCount(10)
    self:SetWaveDelay(10)
    self:SetSpawnRadius(300)
    self:SetScaling(1.2)
    self:SetMaxActive(30)
    self:SetTeamID(2)
    self:SetCurrentWave(0)
    self:SetActive(false)
    self:SetAliveCount(0)

    -- NPC Stats Defaults
    self:SetNPCHealth(100)
    self:SetWeaponDifficulty(WEAPON_PROFICIENCY_AVERAGE or 1)
    self:SetDamageMultiplier(1)
    self:SetSkillPreset("assault")
    self:SetSquadName("")

    -- VJ Base Defaults
    self:SetVJWandering(true)
    self:SetVJCallForHelp(true)
    self:SetVJGodMode(false)
    self:SetVJGrenades(true)
    self:SetVJPassive(false)
    self:SetVJBleeding(true)
    self:SetVJBecomeEnemy(true)

    -- Additional VJ Base Defaults - Combat
    self:SetVJMeleeAttack(true)
    self:SetVJRangeAttack(true)
    self:SetVJLeapAttack(true)
    self:SetVJFollowPlayer(false)
    self:SetVJHasSounds(true)
    self:SetVJCanFlinch(true)
    self:SetVJDeathRagdoll(true)
    self:SetVJRunOnDamage(false)
    self:SetVJMedic(false)
    self:SetVJSightDistance(6500)
    self:SetVJHearingDistance(3000)

    -- Additional VJ Base Defaults - Movement & Behavior
    self:SetVJCanDodge(true)
    self:SetVJUseCover(true)
    self:SetVJInvestigate(true)
    self:SetVJCanCrouch(true)
    self:SetVJOpenDoors(true)
    self:SetVJPushProps(true)
    self:SetVJMoveSpeed(1.0)

    -- Spawn Formation Default (1 = Line/March)
    self:SetSpawnFormation(1)

    -- Tactical Behavior Default (0 = March & Attack)
    self:SetTacticalBehavior(0)

    -- Ship Arrival Defaults
    self:SetSpawnMode(0)        -- Static (instant appear)
    self:SetSpawnHeight(500)
    self:SetSpawnAngle(0)
    self:SetArrivalComplete(true)  -- Static mode is already complete

    -- NPC Randomization Defaults
    self:SetRandomizeSkin(false)
    self:SetRandomizeBodygroups(false)

    -- Spawner Health Defaults (0 = invulnerable)
    self:SetSpawnerHealth(0)
    self:SetKillNPCsOnDeath(false)
    self:SetUseDebugModel(false)
    self:SetDebugModelPath("")

    -- Set model based on default team (CIS)
    self:SetModel(self:GetModelForTeam(2))
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)

    -- Don't collide with NPCs or players - allows spawned NPCs to walk through
    -- COLLISION_GROUP_WEAPON is ignored by NPCs and players can walk through
    self:SetCollisionGroup(COLLISION_GROUP_WEAPON)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:EnableMotion(false)  -- Lock in place so NPCs can't push it
    end
end

-- ═══════════════════════════════════════════════════════════════
-- WAVE CONTROL
-- ═══════════════════════════════════════════════════════════════

function ENT:StartWaves(forceRestart)
    if self:GetActive() then return end

    -- Can't start waves until ship has arrived
    if not self:GetArrivalComplete() then
        local owner = self:GetPlayer()
        if IsValid(owner) then
            owner:ChatPrint("[GMT] Cannot start waves - transport still arriving!")
        end
        return
    end

    local owner = self:GetPlayer()
    local currentWave = self:GetCurrentWave()

    -- Check if we should resume or restart
    if not forceRestart and currentWave > 0 and currentWave < self:GetWaveCount() and not self.WavesCompleted then
        -- Resume from where we left off
        self:SetActive(true)
        self:SetNextWaveTime(CurTime() + 1)

        self:EmitSound("buttons/button9.wav")

        if IsValid(owner) then
            owner:ChatPrint("[GMT] Wave spawner resumed - Wave " .. currentWave .. "/" .. self:GetWaveCount())
        end
    else
        -- Fresh start - reset statistics
        self:SetActive(true)
        self:SetCurrentWave(0)
        self:SetNextWaveTime(CurTime() + 1)
        self.SpawnedNPCs = self.SpawnedNPCs or {}
        self.WavesCompleted = false
        self.TotalNPCsSpawned = 0
        self.TotalNPCsKilled = 0
        self:SetTotalNPCsSpawned(0)
        self:SetTotalNPCsKilled(0)
        self.WaveStartTime = CurTime()

        self:EmitSound("buttons/button9.wav")

        if IsValid(owner) then
            owner:ChatPrint("[GMT] Wave spawner started - " .. self:GetWaveCount() .. " waves")
        end
    end
end

function ENT:RestartWaves()
    -- Force a complete restart
    self:SetActive(false)
    self:SetCurrentWave(0)
    self.WavesCompleted = false
    self.SpawnedNPCs = {}
    self:SetAliveCount(0)

    -- Start fresh
    self:StartWaves(true)

    local owner = self:GetPlayer()
    if IsValid(owner) then
        owner:ChatPrint("[GMT] Wave spawner restarted from wave 1")
    end
end

function ENT:StopWaves()
    self:SetActive(false)
    self:EmitSound("buttons/button10.wav")

    local owner = self:GetPlayer()
    local currentWave = self:GetCurrentWave()
    if IsValid(owner) and currentWave > 0 then
        owner:ChatPrint("[GMT] Wave spawner paused at wave " .. currentWave .. "/" .. self:GetWaveCount())
    end
end

-- ═══════════════════════════════════════════════════════════════
-- THINK & LIFECYCLE
-- ═══════════════════════════════════════════════════════════════

function ENT:Think()
    if not IsValid(self) then return end

    -- Update ship arrival animation
    if not self:GetArrivalComplete() then
        self:UpdateArrival()
        self:NextThink(CurTime() + 0.05)  -- Faster updates during arrival
        return true
    end

    if not self:GetActive() then return end

    -- Clean up dead NPCs from tracking
    self:CleanupDeadNPCs()

    -- Check if time for next wave (true wave-based spawning, not dispenser-style)
    if CurTime() >= self:GetNextWaveTime() then
        if self:GetCurrentWave() < self:GetWaveCount() then
            -- Spawn the next wave regardless of alive count
            -- MaxActive only limits how many spawn per wave, not continuous refilling
            self:SpawnWave()
        elseif not self.WavesCompleted then
            -- All waves complete (only trigger once)
            self.WavesCompleted = true
            self:OnWavesComplete()
        end
    end

    self:NextThink(CurTime() + 0.5)
    return true
end

function ENT:CleanupDeadNPCs()
    local alive = 0
    local previousAlive = self:GetAliveCount()
    
    for i = #self.SpawnedNPCs, 1, -1 do
        if not IsValid(self.SpawnedNPCs[i]) then
            table.remove(self.SpawnedNPCs, i)
            -- Track killed NPCs
            self.TotalNPCsKilled = (self.TotalNPCsKilled or 0) + 1
            self:SetTotalNPCsKilled(self.TotalNPCsKilled) -- Update network var
        else
            alive = alive + 1
        end
    end
    
    self:SetAliveCount(alive)
end

function ENT:OnWavesComplete()
    self:SetActive(false)

    -- Calculate statistics
    local duration = CurTime() - (self.WaveStartTime or CurTime())
    local totalSpawned = self.TotalNPCsSpawned or 0
    local totalKilled = self.TotalNPCsKilled or (totalSpawned - self:GetAliveCount())
    local survivalRate = totalSpawned > 0 and math.floor((totalKilled / totalSpawned) * 100) or 0

    -- Cache player list
    local players = player.GetAll()
    local msg = "[GMT] All waves complete! | Spawned: " .. totalSpawned .. " | Eliminated: " .. totalKilled .. " | Time: " .. string.format("%.1f", duration) .. "s"
    for i = 1, #players do
        local ply = players[i]
        if IsValid(ply) then
            ply:ChatPrint(msg)
        end
    end

    self:EmitSound("buttons/bell1.wav")
end

function ENT:OnRemove()
    -- Clean up spawned NPCs and remove from cache
    local npcs = self.SpawnedNPCs or {}
    for i = 1, #npcs do
        local npc = npcs[i]
        if IsValid(npc) then
            -- Remove from global cache
            for j = #GMT_CachedNPCs, 1, -1 do
                if GMT_CachedNPCs[j] == npc then
                    table.remove(GMT_CachedNPCs, j)
                    break
                end
            end
            npc:Remove()
        end
    end
end
