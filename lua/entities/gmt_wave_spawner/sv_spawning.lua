--[[
    Gamemaster Tools - Wave Spawner
    Spawning & Formation Logic
]]

-- Formation types
local FORMATION_RANDOM = 0
local FORMATION_LINE = 1      -- Marching line formation
local FORMATION_VSHAPE = 2    -- V-shape/Wedge formation
local FORMATION_ARC = 3       -- Arc/Semi-circle formation
local FORMATION_GRID = 4      -- Grid formation (rows and columns)

-- Calculate formation positions for NPCs
function ENT:CalculateFormationPositions(count)
    local formation = self:GetSpawnFormation()
    local origin = self:GetPos()
    local radius = self:GetSpawnRadius()
    local forward = self:GetForward()
    local right = self:GetRight()
    local positions = {}

    -- NPC spacing (units between NPCs)
    local spacing = 100  -- Increased spacing

    -- Extra offset to spawn NPCs well clear of the spawner model
    local spawnerClearance = 200

    if formation == FORMATION_LINE then
        -- Line/March formation: NPCs spawn BEHIND the spawner in rows, then march forward
        local perRow = math.min(5, count)  -- Max 5 per row
        local rows = math.ceil(count / perRow)

        for i = 1, count do
            local row = math.ceil(i / perRow) - 1
            local col = ((i - 1) % perRow) - math.floor(perRow / 2)

            -- Spawn BEHIND the spawner with extra clearance to avoid getting stuck
            local offset = (-forward * (spawnerClearance + row * spacing)) + (right * col * spacing)
            local spawnPos = origin + offset

            -- Face the direction spawner is pointing (toward target)
            local faceAngle = self:GetAngles().y

            table.insert(positions, {pos = spawnPos, ang = faceAngle})
        end

    elseif formation == FORMATION_VSHAPE then
        -- V-Shape/Wedge formation: Leader at front of V, flanks spread back
        -- Spawns BEHIND spawner so they march forward
        for i = 1, count do
            local offset
            local faceAngle = self:GetAngles().y

            if i == 1 then
                -- Leader at the point of the V (closest to spawner but still clear)
                offset = -forward * spawnerClearance
            else
                -- Alternating left/right behind the leader
                local side = (i % 2 == 0) and 1 or -1
                local depth = math.ceil((i - 1) / 2)
                -- V shape opens backward (behind leader)
                offset = (-forward * (spawnerClearance + depth * spacing)) + (right * side * depth * spacing * 0.7)
            end

            local spawnPos = origin + offset
            table.insert(positions, {pos = spawnPos, ang = faceAngle})
        end

    elseif formation == FORMATION_ARC then
        -- Arc/Semi-circle formation: NPCs in a curved line
        local arcAngle = math.min(180, count * 15)  -- Max 180 degree arc
        local startAngle = -arcAngle / 2
        local angleStep = arcAngle / math.max(1, count - 1)

        for i = 1, count do
            local angle = startAngle + (i - 1) * angleStep
            local rad = math.rad(self:GetAngles().y + angle)

            local offset = Vector(
                math.cos(rad) * radius * 0.5,
                math.sin(rad) * radius * 0.5,
                0
            )

            local spawnPos = origin + offset
            -- Face inward toward spawner
            local faceAngle = self:GetAngles().y + 180

            table.insert(positions, {pos = spawnPos, ang = faceAngle})
        end

    elseif formation == FORMATION_GRID then
        -- Grid formation: Rows and columns behind spawner
        local cols = math.ceil(math.sqrt(count))
        local numRows = math.ceil(count / cols)

        for i = 1, count do
            local row = math.floor((i - 1) / cols)
            local col = (i - 1) % cols

            -- Center the grid horizontally, spawn behind spawner with clearance
            local colOffset = col - (cols - 1) / 2

            local offset = (-forward * (spawnerClearance + row * spacing)) + (right * colOffset * spacing)
            local spawnPos = origin + offset
            local faceAngle = self:GetAngles().y

            table.insert(positions, {pos = spawnPos, ang = faceAngle})
        end

    else
        -- Random formation (default/fallback)
        for i = 1, count do
            local angle = math.random() * 360
            local dist = math.random(50, radius)
            local rad = math.rad(angle)

            local offset = Vector(
                math.cos(rad) * dist,
                math.sin(rad) * dist,
                0
            )

            local spawnPos = origin + offset
            local faceAngle = math.random(0, 360)

            table.insert(positions, {pos = spawnPos, ang = faceAngle})
        end
    end

    return positions
end

-- Validate and adjust spawn position to ground, avoiding props
-- Optimized with early exits and smarter offset pattern
function ENT:ValidateSpawnPosition(pos)
    local testPos = pos + Vector(0, 0, 100)

    -- First, find the ground
    local groundTrace = util.TraceLine({
        start = testPos,
        endpos = testPos - Vector(0, 0, 300),
        mask = MASK_NPCSOLID_BRUSHONLY
    })

    if not groundTrace.Hit or groundTrace.StartSolid then
        return pos + Vector(0, 0, 20)
    end

    local groundPos = groundTrace.HitPos + Vector(0, 0, 5)

    -- Check if there's enough space for NPC hull (including props)
    local hullCheck = util.TraceHull({
        start = groundPos + Vector(0, 0, 36),  -- Start from middle of hull
        endpos = groundPos + Vector(0, 0, 36),
        mins = Vector(-18, -18, -36),
        maxs = Vector(18, 18, 36),
        mask = MASK_NPCSOLID,
        filter = self  -- Ignore the spawner
    })

    if not hullCheck.Hit then
        return groundPos -- Early exit if position is clear
    end

    -- Position is blocked, try to find a clear spot nearby
    -- Optimized: Try closer offsets first, spiral outward
    local offsets = {
        Vector(50, 0, 0), Vector(-50, 0, 0), Vector(0, 50, 0), Vector(0, -50, 0),  -- Cardinal
        Vector(35, 35, 0), Vector(-35, 35, 0), Vector(35, -35, 0), Vector(-35, -35, 0),  -- Diagonal
        Vector(70, 0, 0), Vector(-70, 0, 0), Vector(0, 70, 0), Vector(0, -70, 0),  -- Extended cardinal
    }

    local maxRetries = 8 -- Limit retries for performance
    for i = 1, math.min(maxRetries, #offsets) do
        local offset = offsets[i]
        local altPos = pos + offset
        local altGround = util.TraceLine({
            start = altPos + Vector(0, 0, 100),
            endpos = altPos - Vector(0, 0, 200),
            mask = MASK_SOLID_BRUSHONLY
        })

        if altGround.Hit and not altGround.StartSolid then
            local altGroundPos = altGround.HitPos + Vector(0, 0, 5)
            local altHull = util.TraceHull({
                start = altGroundPos + Vector(0, 0, 36),
                endpos = altGroundPos + Vector(0, 0, 36),
                mins = Vector(-18, -18, -36),
                maxs = Vector(18, 18, 36),
                mask = MASK_NPCSOLID,
                filter = self
            })

            if not altHull.Hit then
                return altGroundPos -- Early exit on first valid position
            end
        end
    end

    -- Fallback: return original ground position even if blocked (NPC will try to move)
    return groundPos
end

function ENT:SpawnWave()
    local wave = self:GetCurrentWave() + 1

    -- Safety clamps for dangerous values (server-side authority)
    local clampedWaves = math.Clamp(self:GetWaveCount(), 1, 1000)
    if self:GetWaveCount() ~= clampedWaves then
        self:SetWaveCount(clampedWaves)
    end

    local baseCount = math.Clamp(self:GetNPCsPerWave(), 1, 200)
    if self:GetNPCsPerWave() ~= baseCount then
        self:SetNPCsPerWave(baseCount)
    end

    local maxActive = math.Clamp(self:GetMaxActive(), 1, 200)
    if self:GetMaxActive() ~= maxActive then
        self:SetMaxActive(maxActive)
    end

    local waveDelay = math.max(self:GetWaveDelay(), 0.1)
    if self:GetWaveDelay() ~= waveDelay then
        self:SetWaveDelay(waveDelay)
    end

    local scaling = math.Clamp(self:GetScaling(), 0.25, 5)
    if self:GetScaling() ~= scaling then
        self:SetScaling(scaling)
    end

    local radius = math.Clamp(self:GetSpawnRadius(), 50, 5000)
    if self:GetSpawnRadius() ~= radius then
        self:SetSpawnRadius(radius)
    end

    -- Update wave index after clamps
    self:SetCurrentWave(wave)

    -- Calculate NPCs for this wave with scaling
    local npcCount = math.floor(baseCount * math.pow(scaling, wave - 1))

    -- Cap by max active (limits total NPCs alive at once, prevents server overload)
    local currentAlive = self:GetAliveCount()
    local roomForMore = maxActive - currentAlive
    local canSpawn = math.max(0, math.min(npcCount, roomForMore))

    -- Announce wave (cache player list)
    local players = player.GetAll()
    local waveMsg = "[GMT] Wave " .. wave .. "/" .. clampedWaves
    if canSpawn < npcCount then
        waveMsg = waveMsg .. " - " .. canSpawn .. "/" .. npcCount .. " NPCs (max active reached)"
    else
        waveMsg = waveMsg .. " - " .. canSpawn .. " NPCs"
    end

    for i = 1, #players do
        local ply = players[i]
        if IsValid(ply) then
            ply:ChatPrint(waveMsg)
        end
    end

    self:EmitSound("ambient/alarms/warningbell1.wav")

    -- Calculate formation positions for this wave
    local formationPositions = self:CalculateFormationPositions(canSpawn)

    -- Spawn the NPCs with staggered timing to avoid lag spikes
    for i = 1, canSpawn do
        local formationData = formationPositions[i]
        timer.Simple(i * 0.15, function()
            if IsValid(self) and formationData then
                self:SpawnSingleNPC(formationData.pos, formationData.ang)
            end
        end)
    end

    -- Set next wave time (wait for delay before spawning next wave)
    self:SetNextWaveTime(CurTime() + waveDelay)
end

function ENT:SpawnSingleNPC(formationPos, formationAngle)
    local class = self:GetNPCClass()

    -- Validate NPC class exists
    if not class or class == "" then
        print("[GMT] Warning: Invalid NPC class on spawner " .. self:EntIndex())
        return
    end

    -- Check if NPC class is registered
    local npcData = list.Get("NPC")[class]
    local entTable = scripted_ents.Get(class)
    if not npcData and not entTable then
        print("[GMT] Warning: NPC class '" .. class .. "' not found, skipping spawn")
        return
    end

    -- Validate the formation position to find ground
    local pos = self:ValidateSpawnPosition(formationPos or self:GetPos())
    local angle = formationAngle or math.random(0, 360)

    -- Check for external spawn limit (ShouldBlockSpawn from other addons)
    if ShouldBlockSpawn and ShouldBlockSpawn(self:GetPlayer(), class) then
        if NotifyBlocked then NotifyBlocked(self:GetPlayer(), class) end

        local npcData = list.Get("NPC")[class]
        local fallbackClass = SpawnLimit and SpawnLimit.GetFallbackNPCClass and SpawnLimit.GetFallbackNPCClass(npcData and npcData.Category, class)

        if fallbackClass then
            local owner = self:GetPlayer()
            if IsValid(owner) then
                owner:ChatPrint("[GMT] Falling back to legacy NPC " .. fallbackClass)
            end
            class = fallbackClass
        else
            return -- No fallback available, don't spawn
        end
    end

    -- Detect if this is a VJ Base NPC (check entity table first)
    local entTable = scripted_ents.Get(class)
    local isVJBase = false
    if entTable then
        isVJBase = entTable.IsVJBaseSNPC or entTable.IsVJBaseNPC or
                   (entTable.VJ_NPC_Class ~= nil) or (entTable.Weapon_StartingAmmoAmount ~= nil)
    end

    local npc = ents.Create(class)
    if not IsValid(npc) then return end

    npc:SetPos(pos)
    npc:SetAngles(Angle(0, angle, 0))

    -- Set weapon if specified
    local weapon = self:GetWeapon()
    if weapon and weapon ~= "" then
        npc:SetKeyValue("additionalequipment", weapon)
    end

    -- Set spawnflags for standard NPCs (VJ Base handles these differently)
    -- SF_NPC_NO_WEAPON_DROP (8192) + SF_NPC_LONG_RANGE (131072) + SF_NPC_FADE_CORPSE (262144)
    if not isVJBase then
        npc:SetKeyValue("spawnflags", bit.bor(8192, 131072, 262144))
    end

    -- Store damage multiplier for damage scaling hook
    local damageMultiplier = math.Clamp(self:GetDamageMultiplier(), 0, 25)
    self:SetDamageMultiplier(damageMultiplier)
    npc.GMT_DamageScale = damageMultiplier

    -- Apply weapon proficiency for VJ Base before spawning
    local weaponProf = self:GetWeaponDifficulty()
    if isVJBase then
        local spreadMap = {
            [WEAPON_PROFICIENCY_POOR] = 0.6,
            [WEAPON_PROFICIENCY_AVERAGE] = 0.3,
            [WEAPON_PROFICIENCY_GOOD] = 0.15,
            [WEAPON_PROFICIENCY_VERY_GOOD] = 0.05,
            [WEAPON_PROFICIENCY_PERFECT] = 0.01
        }
        npc.NPC_CustomSpread = spreadMap[weaponProf] or 0.3
    end

    npc:Spawn()
    npc:Activate()

    -- Apply skin/bodygroup randomization
    if self:GetRandomizeSkin() then
        local numSkins = npc:SkinCount()
        if numSkins > 1 then
            npc:SetSkin(math.random(0, numSkins - 1))
        end
    end

    if self:GetRandomizeBodygroups() then
        local numBodygroups = npc:GetNumBodyGroups()

        -- Skip bodygroup 0 (index 0 is usually main body - NEVER randomize)
        for bg = 1, numBodygroups - 1 do
            local count = npc:GetBodygroupCount(bg)
            if count > 1 then
                local bgName = string.lower(npc:GetBodygroupName(bg) or "")

                -- SKIP bodygroups that could make NPC invisible
                -- These typically control major body parts
                local skipBodygroup = false
                local skipNames = {"body", "torso", "chest", "legs", "arms", "studio", "model", "mesh"}
                for _, skipName in ipairs(skipNames) do
                    if string.find(bgName, skipName) then
                        skipBodygroup = true
                        break
                    end
                end

                if not skipBodygroup then
                    -- Safe to randomize (helmets, pauldrons, visors, backpacks, etc.)
                    -- Strategy: Avoid last option (often "none/invisible")
                    local maxVal
                    if count == 2 then
                        -- Only 2 options - pick either (both likely visible)
                        maxVal = 1
                    elseif count > 2 then
                        -- 3+ options - skip last one (often "none")
                        maxVal = count - 2
                    else
                        maxVal = 0
                    end
                    local newVal = math.random(0, maxVal)
                    npc:SetBodygroup(bg, newVal)
                end
            end
        end
    end

    -- Apply weapon proficiency for standard NPCs after spawn
    if npc.SetCurrentWeaponProficiency then
        npc:SetCurrentWeaponProficiency(weaponProf)
    end

    -- Re-check VJ Base status after spawn (some properties set during Spawn/Activate)
    if not isVJBase then
        isVJBase = npc.IsVJBaseSNPC or npc.IsVJBaseNPC or npc.VJ_NPC_Class or
                   (npc.Weapon_StartingAmmoAmount ~= nil) or (npc.VJ_TheController ~= nil)
    end

    -- Store VJ Base status on NPC for later use
    npc.GMT_IsVJBaseNPC = isVJBase

    print("[GMT] Spawned NPC: " .. class .. ", IsVJBase: " .. tostring(isVJBase))

    -- Handle different NPC bases
    self:ConfigureNPCBase(npc, isVJBase)

    -- For VJ Base NPCs, give weapon using their method (they handle it differently)
    if isVJBase and weapon and weapon ~= "" then
        npc:Give(weapon)
        timer.Simple(0.15, function()
            if IsValid(npc) then
                npc:Give(weapon)
            end
        end)
    end

    -- Apply health IMMEDIATELY after spawn
    local npcHealth = self:GetNPCHealth()
    if npcHealth > 0 then
        npc:SetHealth(npcHealth)
        npc:SetMaxHealth(npcHealth)
    end

    -- Set network variables immediately for client-side health bar HUD
    npc:SetNWBool("GMT_SpawnedNPC", true)
    npc:SetNWInt("GMT_MaxHealth", npcHealth > 0 and npcHealth or 100)
    npc:SetNWString("GMT_NPCName", list.Get("NPC")[class] and list.Get("NPC")[class].Name or class)

    -- Re-apply health in timer to ensure it sticks (some NPCs override health on spawn)
    local spawner = self
    timer.Simple(0.1, function()
        if not IsValid(npc) then return end
        if not IsValid(spawner) then return end

        local health = spawner:GetNPCHealth()
        if health > 0 then
            npc:SetHealth(health)
            npc:SetMaxHealth(health)
        end

        -- Update network variables
        npc:SetNWInt("GMT_MaxHealth", health > 0 and health or 100)
    end)

    -- Third health application at 0.5s (some NPCs reset health during late initialization)
    timer.Simple(0.5, function()
        if not IsValid(npc) then return end
        if not IsValid(spawner) then return end

        local health = spawner:GetNPCHealth()
        if health > 0 and npc:Health() ~= health then
            npc:SetHealth(health)
            npc:SetMaxHealth(health)
            print("[GMT] Health re-applied at 0.5s: " .. health)
        end
    end)

    -- Track this NPC
    table.insert(self.SpawnedNPCs, npc)
    table.insert(GMT_CachedNPCs, npc) -- Add to global cache for hooks
    self:SetAliveCount(self:GetAliveCount() + 1)
    self.TotalNPCsSpawned = (self.TotalNPCsSpawned or 0) + 1
    self:SetTotalNPCsSpawned(self.TotalNPCsSpawned) -- Update network var

    -- Link to spawner for cleanup
    npc.GMT_Spawner = self
    npc.GMT_TeamID = self:GetTeamID()
    npc.GMT_SpawnedNPC = true  -- Mark as spawned by wave spawner for corpse cleanup

    -- Ensure NPC drops to ground properly
    local spawnerRef = self
    timer.Simple(0.1, function()
        if IsValid(npc) then
            npc:DropToFloor()

            -- Make sure NPC has proper movement type
            if npc:GetMoveType() == MOVETYPE_NONE then
                npc:SetMoveType(MOVETYPE_STEP)
            end
        end
    end)

    -- Set up NPC behavior after spawn
    timer.Simple(0.5, function()
        if IsValid(npc) and IsValid(spawnerRef) then
            -- Configure enemy targeting and basic behavior
            spawnerRef:GiveMarchOrders(npc, 0)
            -- Start periodic enemy re-acquisition
            spawnerRef:StartBehaviorEnforcement(npc)
        end
    end)
end
