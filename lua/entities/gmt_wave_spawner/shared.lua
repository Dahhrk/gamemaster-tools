ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "Wave Spawner"
ENT.Author = "Gamemaster Tools"
ENT.Category = "Gamemaster Tools"
ENT.Spawnable = true
ENT.AdminOnly = true

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "NPCClass")
    self:NetworkVar("String", 1, "Weapon")
    self:NetworkVar("String", 2, "SkillPreset")
    self:NetworkVar("String", 3, "SquadName")

    self:NetworkVar("Int", 0, "NPCsPerWave")
    self:NetworkVar("Int", 1, "WaveCount")
    self:NetworkVar("Int", 2, "CurrentWave")
    self:NetworkVar("Int", 3, "SpawnRadius")
    self:NetworkVar("Int", 4, "MaxActive")
    self:NetworkVar("Int", 5, "TeamID")
    self:NetworkVar("Int", 6, "AliveCount")
    self:NetworkVar("Int", 7, "NPCHealth")
    self:NetworkVar("Int", 8, "WeaponDifficulty")
    self:NetworkVar("Int", 9, "SpawnFormation")  -- 0=Random, 1=Line, 2=V-Formation, 3=Arc, 4=Grid
    self:NetworkVar("Int", 10, "TacticalBehavior") -- 0=March&Attack, 1=Hold, 2=Patrol, 3=Rush, 4=Defensive, 5=Flank
    self:NetworkVar("Int", 11, "SpawnMode")     -- 0=Static, 1=Fly-In, 2=Hyperspace, 3=Landing
    self:NetworkVar("Int", 12, "SpawnHeight")   -- Height for arrival animation
    self:NetworkVar("Int", 13, "SpawnAngle")    -- Approach angle for arrival
    self:NetworkVar("Int", 14, "SpawnerHealth") -- Spawner health (0 = invulnerable)

    self:NetworkVar("Float", 0, "WaveDelay")
    self:NetworkVar("Float", 1, "Scaling")
    self:NetworkVar("Float", 2, "NextWaveTime")
    self:NetworkVar("Float", 3, "DamageMultiplier")

    self:NetworkVar("Bool", 0, "Active")
    self:NetworkVar("Bool", 1, "VJWandering")
    self:NetworkVar("Bool", 2, "VJCallForHelp")
    self:NetworkVar("Bool", 3, "VJGodMode")
    self:NetworkVar("Bool", 4, "VJGrenades")
    self:NetworkVar("Bool", 5, "VJPassive")
    self:NetworkVar("Bool", 6, "VJBleeding")
    self:NetworkVar("Bool", 7, "VJBecomeEnemy")
    self:NetworkVar("Bool", 8, "RandomizeSkin")
    self:NetworkVar("Bool", 9, "RandomizeBodygroups")
    self:NetworkVar("Bool", 10, "ArrivalComplete")  -- True when ship has finished arriving
    self:NetworkVar("Bool", 11, "UseDebugModel")   -- Use simple debug model for testing
    self:NetworkVar("String", 4, "DebugModelPath") -- Custom debug model path
    self:NetworkVar("Bool", 12, "KillNPCsOnDeath") -- Kill all spawned NPCs when spawner destroyed

    -- Additional VJ Base Properties - Combat
    self:NetworkVar("Bool", 13, "VJMeleeAttack")    -- Enable melee attacks
    self:NetworkVar("Bool", 14, "VJRangeAttack")    -- Enable ranged attacks
    self:NetworkVar("Bool", 15, "VJLeapAttack")     -- Enable leap attacks
    self:NetworkVar("Bool", 16, "VJFollowPlayer")   -- NPCs follow the spawner owner
    self:NetworkVar("Bool", 17, "VJHasSounds")      -- Enable NPC sounds
    self:NetworkVar("Bool", 18, "VJCanFlinch")      -- Enable flinching when hit
    self:NetworkVar("Bool", 19, "VJDeathRagdoll")   -- Create ragdoll on death
    self:NetworkVar("Bool", 20, "VJRunOnDamage")    -- Run away when damaged by unknown source
    self:NetworkVar("Bool", 21, "VJMedic")          -- Act as medic (heal allies)
    self:NetworkVar("Int", 15, "VJSightDistance")   -- How far NPC can see (units)
    self:NetworkVar("Int", 16, "VJHearingDistance") -- How far NPC can hear (units)

    -- Additional VJ Base Properties - Movement & Behavior
    self:NetworkVar("Bool", 22, "VJCanDodge")       -- Can dodge attacks
    self:NetworkVar("Bool", 23, "VJUseCover")       -- Use cover in combat
    self:NetworkVar("Bool", 24, "VJInvestigate")    -- Investigate sounds
    self:NetworkVar("Bool", 25, "VJCanCrouch")      -- Can crouch when shooting
    self:NetworkVar("Bool", 26, "VJOpenDoors")      -- Can open doors
    self:NetworkVar("Bool", 27, "VJPushProps")      -- Push props out of way
    self:NetworkVar("Float", 4, "VJMoveSpeed")      -- Movement speed multiplier

    self:NetworkVar("Entity", 0, "Player")
    
    -- Statistics (for display)
    self:NetworkVar("Int", 17, "TotalNPCsSpawned")
    self:NetworkVar("Int", 18, "TotalNPCsKilled")
end
