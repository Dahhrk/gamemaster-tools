--[[
    Gamemaster Tools - Configuration
]]

GM_Tools.Config = GM_Tools.Config or {}

-- Wave System Defaults
GM_Tools.Config.Wave = {
    DefaultDelay = 5,           -- Seconds between waves
    DefaultNPCsPerWave = 5,     -- Base NPCs per wave
    WaveScaling = 1.2,          -- Multiplier per wave (1.2 = 20% more each wave)
    MaxActiveNPCs = 50,         -- Maximum NPCs alive at once
    SpawnRadius = 500,          -- Spawn radius around spawn point
    AnnouncementEnabled = true, -- Announce waves to players
}

-- NPC Base Priorities (order of detection)
GM_Tools.Config.BasePriority = {
    "vj_base",      -- VJ Base SNPCs
    "droid",        -- Droid NPCs
    "lvs",          -- LVS vehicles/NPCs
    "nextbot",      -- NextBot NPCs
    "default",      -- Default Source NPCs
}

-- Team/Faction Definitions (CWRP)
GM_Tools.Config.Teams = {
    [1] = {
        name = "GAR",
        color = Color(0, 100, 255),
        models = {
            "models/blu/laat.mdl",
            "models/kingpommes/starwars/patrol_transport/main.mdl",
        },
        defaultModel = "models/blu/laat.mdl",
    },
    [2] = {
        name = "CIS",
        color = Color(100, 100, 100),
        models = {
            "models/salty/cis-hmp-gunship.mdl",
            "models/sfp_droidbomber/sfp_droidbomber.mdl",
            "models/salty/hyenaclassbomber.mdl",
            "models/props/starwars/vehicles/sbd_dispenser.mdl",
            "models/props/starwars/vehicles/droideka_dispenser.mdl",
            "models/props/starwars/vehicles/bd_dispenser.mdl",
        },
        defaultModel = "models/props/starwars/vehicles/sbd_dispenser.mdl",
    },
    [3] = {
        name = "Neutral",
        color = Color(255, 255, 0),
        models = {
            "models/props/hel105/hel105.mdl",
            "models/ehawk/ehawk1.mdl",
            "models/kimogila/sfp_kimogila.mdl",
            "models/gauntlet/sfp_gauntlet.mdl",
        },
        defaultModel = "models/props/hel105/hel105.mdl",
    },
    [4] = {
        name = "Mandalorian",
        color = Color(0, 255, 255),
        models = {
            "models/gauntlet/sfp_gauntlet.mdl",
            "models/props/hel105/hel105.mdl",
        },
        defaultModel = "models/gauntlet/sfp_gauntlet.mdl",
    },
    [5] = {
        name = "Custom",
        color = Color(255, 0, 255),
        models = {},
        defaultModel = "models/props_combine/combine_mine01.mdl",
    },
}

-- Fallback model if team model not available
GM_Tools.Config.FallbackModel = "models/props_combine/combine_mine01.mdl"

-- Debug/Test model (simple visible model for testing without custom assets)
GM_Tools.Config.DebugModel = "models/props_c17/oildrum001.mdl"

-- Spawner Health Settings (makes the spawner destructible)
GM_Tools.Config.SpawnerHealth = {
    DefaultHealth = 0,              -- 0 = invulnerable (default), >0 = destructible
    MaxHealth = 10000,              -- Maximum configurable health
    DestroyOnDeath = true,          -- Remove spawner when destroyed
    KillNPCsOnDeath = false,        -- Also kill all spawned NPCs when destroyed
    ExplosionOnDeath = true,        -- Create explosion effect when destroyed
    ExplosionDamage = 100,          -- Damage dealt by explosion
    ExplosionRadius = 200,          -- Explosion radius
}

-- Corpse/Gib cleanup settings
GM_Tools.Config.CorpseFadeTime = 3    -- Seconds before corpse fades
GM_Tools.Config.GibRemoveTime = 3     -- Seconds before gibs are removed

-- Permission level required to use tools (0 = anyone, 1 = admin, 2 = superadmin)
GM_Tools.Config.PermissionLevel = 1

-- NPC Behaviors (simplified - VJ Base handles movement naturally)
-- These set basic behavior flags for spawned NPCs
GM_Tools.Config.TacticalBehaviors = {
    [0] = {
        name = "Aggressive",
        description = "Chase and attack enemies - VJ Base handles movement",
        holdPosition = false,
        patrol = false,
    },
    [1] = {
        name = "Hold Position",
        description = "Stay near spawn, engage nearby enemies only",
        holdPosition = true,
        patrol = false,
    },
    [2] = {
        name = "Patrol",
        description = "Wander around the spawn area",
        holdPosition = false,
        patrol = true,
    },
}

-- NPC Behavior Presets (scaled for large servers, 128+ players)
GM_Tools.Config.Presets = {
    ["default"] = {
        name = "Default",
        description = "Standard balanced settings",
        health = 500,
        damage_multiplier = 1,
        weapon_difficulty = 1, -- WEAPON_PROFICIENCY_AVERAGE
        skill_preset = "assault",
        wandering = true,
        call_for_help = true,
        godmode = false,
        grenades = true,
        passive = false,
        bleeding = true,
        become_enemy = true,
    },
    ["weak"] = {
        name = "Weak",
        description = "Low HP, easy kills",
        health = 250,
        damage_multiplier = 0.5,
        weapon_difficulty = 0, -- WEAPON_PROFICIENCY_POOR
        skill_preset = "assault",
        wandering = true,
        call_for_help = false,
        godmode = false,
        grenades = false,
        passive = false,
        bleeding = true,
        become_enemy = false,
    },
    ["standard"] = {
        name = "Standard",
        description = "Regular combat NPC",
        health = 750,
        damage_multiplier = 1,
        weapon_difficulty = 1, -- WEAPON_PROFICIENCY_AVERAGE
        skill_preset = "assault",
        wandering = true,
        call_for_help = true,
        godmode = false,
        grenades = false,
        passive = false,
        bleeding = true,
        become_enemy = true,
    },
    ["heavy"] = {
        name = "Heavy",
        description = "Tanky, high damage",
        health = 2500,
        damage_multiplier = 1.5,
        weapon_difficulty = 2, -- WEAPON_PROFICIENCY_GOOD
        skill_preset = "assault",
        wandering = false,
        call_for_help = true,
        godmode = false,
        grenades = true,
        passive = false,
        bleeding = true,
        become_enemy = true,
    },
    ["elite"] = {
        name = "Elite",
        description = "Skilled, dangerous",
        health = 1500,
        damage_multiplier = 2,
        weapon_difficulty = 3, -- WEAPON_PROFICIENCY_VERY_GOOD
        skill_preset = "elite",
        wandering = true,
        call_for_help = true,
        godmode = false,
        grenades = true,
        passive = false,
        bleeding = true,
        become_enemy = true,
    },
    ["sniper"] = {
        name = "Sniper",
        description = "Long range, accurate",
        health = 500,
        damage_multiplier = 3,
        weapon_difficulty = 4, -- WEAPON_PROFICIENCY_PERFECT
        skill_preset = "sniper",
        wandering = false,
        call_for_help = false,
        godmode = false,
        grenades = false,
        passive = false,
        bleeding = true,
        become_enemy = true,
    },
    ["grenadier"] = {
        name = "Grenadier",
        description = "Explosive specialist",
        health = 1000,
        damage_multiplier = 1,
        weapon_difficulty = 1,
        skill_preset = "grenadier",
        wandering = true,
        call_for_help = true,
        godmode = false,
        grenades = true,
        passive = false,
        bleeding = true,
        become_enemy = true,
    },
    ["melee"] = {
        name = "Melee",
        description = "Close combat",
        health = 2000,
        damage_multiplier = 2,
        weapon_difficulty = 3,
        skill_preset = "lightsaber",
        wandering = true,
        call_for_help = true,
        godmode = false,
        grenades = false,
        passive = false,
        bleeding = true,
        become_enemy = true,
    },
    ["miniboss"] = {
        name = "Mini-Boss",
        description = "Tough, squad challenge",
        health = 5000,
        damage_multiplier = 2,
        weapon_difficulty = 3, -- WEAPON_PROFICIENCY_VERY_GOOD
        skill_preset = "elite",
        wandering = false,
        call_for_help = true,
        godmode = false,
        grenades = true,
        passive = false,
        bleeding = true,
        become_enemy = true,
    },
    ["boss"] = {
        name = "Boss",
        description = "Very tough, raid-level",
        health = 15000,
        damage_multiplier = 3,
        weapon_difficulty = 4, -- WEAPON_PROFICIENCY_PERFECT
        skill_preset = "elite",
        wandering = false,
        call_for_help = true,
        godmode = false,
        grenades = true,
        passive = false,
        bleeding = true,
        become_enemy = true,
    },
    ["raid_boss"] = {
        name = "Raid Boss",
        description = "Server event level",
        health = 50000,
        damage_multiplier = 4,
        weapon_difficulty = 4, -- WEAPON_PROFICIENCY_PERFECT
        skill_preset = "elite",
        wandering = false,
        call_for_help = true,
        godmode = false,
        grenades = true,
        passive = false,
        bleeding = true,
        become_enemy = true,
    },
    ["passive"] = {
        name = "Passive",
        description = "Non-combat NPC",
        health = 500,
        damage_multiplier = 0,
        weapon_difficulty = 0,
        skill_preset = "assault",
        wandering = true,
        call_for_help = false,
        godmode = false,
        grenades = false,
        passive = true,
        bleeding = true,
        become_enemy = false,
    },
}
