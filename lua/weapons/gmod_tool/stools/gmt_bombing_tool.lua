--[[
    Gamemaster Tools - Bombing Tool
    Spawns a bomber entity that flies in a straight line and drops bombs
    in configurable patterns (point, line, circle).
]]

TOOL.Category = "Gamemaster Tools"
TOOL.Name = "#tool.gmt_bombing_tool.name"

TOOL.Information = {
    { name = "left" },
    { name = "right" },
}

TOOL.ClientConVar = {
    ["pattern"] = "1",                 -- 0 = Point, 1 = Line, 2 = Circle
    ["arrival_mode"] = "1",            -- 0 = Static, 1 = Fly-In, 2 = Hyperspace, 3 = Dive
    ["fire_mode"] = "0",               -- 0 = Bomber Run, 1 = Artillery, 2 = Orbital
    ["bomb_count"] = "8",              -- Number of bombs/explosions
    ["radius"] = "400",                -- Radius/half-length
    ["altitude"] = "800",              -- Altitude above target / shell height
    ["speed"] = "1600",                -- Units per second (bomber mode)
    ["bomb_damage"] = "150",           -- Damage per bomb
    ["bomb_radius"] = "250",           -- Radius per bomb
    ["projectile_class"] = "",         -- Optional projectile entity for artillery/orbital
    ["use_custom_model"] = "0",        -- Use custom bomber model path
    ["custom_model_path"] = "",        -- Custom bomber model
    ["default_model"] = "models/combine_helicopter.mdl", -- Fallback bomber
    ["faction"] = "2",                 -- 1 = GAR, 2 = CIS, 3 = Neutral, 4 = Mandalorian
}

-- Cleanup type
cleanup.Register("gmt_bombing_runs")

-- Performance protection: cooldown per player
GMT_BombingCooldowns = GMT_BombingCooldowns or {}
local COOLDOWN_TIME = 1.5 -- seconds between strikes

-- Faction names for flavor text
local FACTION_NAMES = {
    [1] = "GAR",
    [2] = "CIS",
    [3] = "Neutral",
    [4] = "Mandalorian",
}

-- Helper to resolve bomber model from convars
local function GetSelectedModel(tool)
    local useCustom = tool:GetClientNumber("use_custom_model", 0) == 1
    local customPath = tool:GetClientInfo("custom_model_path") or ""
    local defaultPath = tool:GetClientInfo("default_model") or "models/combine_helicopter.mdl"

    if useCustom and customPath ~= "" then
        return customPath
    end

    return defaultPath
end

-- Helper to create an explosion at a position (used for artillery/orbital)
local function DoStrikeExplosion(owner, pos, damage, radius, mode)
    local dmg = math.Clamp(damage or 150, 1, 2000)
    local rad = math.Clamp(radius or 250, 10, 2000)

    -- Core explosion effect
    local effectdata = EffectData()
    effectdata:SetOrigin(pos)

    if mode == 2 then
        -- Orbital: brighter, more sci-fi
        effectdata:SetScale(math.Clamp(rad / 150, 0.8, 4))
        util.Effect("cball_explode", effectdata, true, true)
    else
        -- Artillery / generic
        effectdata:SetScale(math.Clamp(rad / 200, 0.5, 3))
        util.Effect("Explosion", effectdata, true, true)
    end

    util.BlastDamage(owner or game.GetWorld(), owner or game.GetWorld(), pos, rad, dmg)

    if mode == 2 then
        sound.Play("ambient/energy/whiteflash.wav", pos, 100, 120)
    else
        sound.Play("weapons/mortar/mortar_explode1.wav", pos, 100, 100)
    end
end

-- Helper to optionally spawn a projectile entity instead of a direct explosion
local function TrySpawnStrikeProjectile(owner, projClass, startPos, targetPos)
    if not projClass or projClass == "" then return false end

    local ent = ents.Create(projClass)
    if not IsValid(ent) then return false end

    ent:SetPos(startPos)
    ent:SetAngles((targetPos - startPos):Angle())

    if ent.SetOwner and IsValid(owner) then
        ent:SetOwner(owner)
    end

    ent:Spawn()
    ent:Activate()

    -- Give basic forward velocity if it has physics
    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then
        local dir = (targetPos - startPos):GetNormalized()
        phys:SetVelocity(dir * 2000)
    end

    return true
end

-- Fire artillery / orbital strikes (no visible bomber entity)
local function FireSupportStrike(tool, ply, targetPos, fireMode, pattern, bombCount, radius, altitude, bombDamage, bombRadius, factionName)
    local owner = ply

    -- Generate target positions based on pattern
    local positions = {}

    if pattern == 0 then
        -- Point strike
        positions[1] = targetPos
    elseif pattern == 1 then
        -- Line / creeping barrage along view direction
        local aimDir = ply:GetAimVector()
        local forward2D = Vector(aimDir.x, aimDir.y, 0)
        if forward2D:Length() < 0.1 then
            forward2D = Vector(ply:GetForward().x, ply:GetForward().y, 0)
        end
        forward2D:Normalize()

        local totalLength = radius * 2
        for i = 0, bombCount - 1 do
            local t = (bombCount == 1) and 0.5 or (i / (bombCount - 1))
            local offset = (t - 0.5) * totalLength
            local pos = targetPos + forward2D * offset
            positions[#positions + 1] = pos
        end
    else
        -- Circle / random barrage around target
        for i = 1, bombCount do
            local angle = math.Rand(0, math.pi * 2)
            local dist = math.Rand(radius * 0.3, radius)
            local pos = targetPos + Vector(math.cos(angle) * dist, math.sin(angle) * dist, 0)
            positions[#positions + 1] = pos
        end
    end

    local projClass = tool:GetClientInfo("projectile_class") or ""

    -- Schedule explosions/projectiles with a bit of randomness for artillery feel
    local baseDelay = 0.2
    for i, pos in ipairs(positions) do
        local shellTime = (i - 1) * baseDelay + math.Rand(0, 0.15)
        timer.Simple(shellTime, function()
            if not IsValid(owner) then return end

            local impactPos = pos
            -- Drop shells from above for sound/FX accuracy
            local traceData = {
                start = pos + Vector(0, 0, altitude + 2000),
                endpos = pos,
                mask = MASK_SOLID_BRUSHONLY,
            }
            local tr = util.TraceLine(traceData)
            if tr.Hit then
                impactPos = tr.HitPos + Vector(0, 0, 5)
            end

            -- If a projectile class is configured, try to spawn that instead of direct explosion
            if projClass ~= "" then
                local startPos = impactPos + Vector(0, 0, altitude + 1000)
                if TrySpawnStrikeProjectile(owner, projClass, startPos, impactPos) then
                    return
                end
            end

            -- Whistle / ion charge sounds before impact (direct fire mode)
            if fireMode == 1 then
                sound.Play("weapons/mortar/mortar_shell_incomming1.wav", impactPos + Vector(0, 0, 200), 90, 100)
            else
                sound.Play("ambient/energy/zap9.wav", impactPos + Vector(0, 0, 500), 90, 130)
            end

            DoStrikeExplosion(owner, impactPos, bombDamage, bombRadius, fireMode)
        end)
    end

    -- CWRP flavor: Announce strike (cache player list)
    local modeName = (fireMode == 1) and "Artillery" or "Orbital"
    local players = player.GetAll()
    local msg = "[GMT] " .. factionName .. " " .. modeName .. " strike incoming!"
    for i = 1, #players do
        local p = players[i]
        if IsValid(p) then
            p:ChatPrint(msg)
        end
    end

    return true
end

-- Fire classic bomber run (visible entity)
local function FireBomberRun(tool, ply, targetPos, pattern, radius, altitude, speed, bombDamage, bombRadius, factionName)
    -- Determine flight direction from player's view (flattened to horizontal by default)
    local aimDir = ply:GetAimVector()
    local forward2D = Vector(aimDir.x, aimDir.y, 0)
    if forward2D:Length() < 0.1 then
        forward2D = Vector(ply:GetForward().x, ply:GetForward().y, 0)
    end
    forward2D:Normalize()

    local arrivalMode = tool:GetClientNumber("arrival_mode", 1)

    local startPos
    local angles

    if arrivalMode == 0 then
        -- Static / simple fly-through: start a short distance before target
        local preDist = radius + 800
        startPos = targetPos - forward2D * preDist + Vector(0, 0, altitude)
        angles = forward2D:Angle()
    elseif arrivalMode == 1 then
        -- Long fly-in: start far away for a more cinematic approach
        local preDist = radius + 3000
        startPos = targetPos - forward2D * preDist + Vector(0, 0, altitude)
        angles = forward2D:Angle()
    elseif arrivalMode == 2 then
        -- Hyperspace-style: appear closer with a dramatic entry effect
        local preDist = radius + 1500
        startPos = targetPos - forward2D * preDist + Vector(0, 0, altitude * 0.7)
        angles = forward2D:Angle()
    else
        -- Dive-bomb: start high and slightly behind, with a downward pitch
        local preDist = radius + 1200
        startPos = targetPos - forward2D * preDist + Vector(0, 0, altitude * 1.5)
        angles = forward2D:Angle()
        angles.p = -20
    end

    local ent = ents.Create("gmt_bombing_run")
    if not IsValid(ent) then return false end

    ent:SetPos(startPos)
    ent:SetAngles(angles)

    ent:SetTargetPos(targetPos)
    ent:SetPattern(pattern)
    ent:SetBombCount(bombCount)
    ent:SetArrivalMode(arrivalMode)
    ent:SetRadius(radius)
    ent:SetAltitude(altitude)
    ent:SetSpeed(speed)
    ent:SetBombDamage(bombDamage)
    ent:SetBombRadius(bombRadius)
    ent:SetBomberModel(GetSelectedModel(tool))
    ent:SetOwner(ply)

    ent:Spawn()
    ent:Activate()

    ply:AddCleanup("gmt_bombing_runs", ent)

    undo.Create("Bombing Run")
        undo.AddEntity(ent)
        undo.SetPlayer(ply)
    undo.Finish()

    -- CWRP flavor: Announce bomber run (cache player list)
    local players = player.GetAll()
    local msg = "[GMT] " .. factionName .. " bomber run incoming!"
    for i = 1, #players do
        local p = players[i]
        if IsValid(p) then
            p:ChatPrint(msg)
        end
    end

    return true
end

-- Left click: start a bombing run over the aimed position
function TOOL:LeftClick(trace)
    if not trace.Hit then return false end
    if CLIENT then return true end

    local ply = self:GetOwner()
    if not IsValid(ply) then return false end

    -- Safety: Admin check (can be overridden by hook)
    if not hook.Call("GMT_CanUseBombingTool", nil, ply) then
        if not ply:IsAdmin() then
            ply:ChatPrint("[GMT] Only admins can use the Bombing Tool")
            return false
        end
    end

    -- Performance: Cooldown check
    local plyID = ply:SteamID64() or ply:EntIndex()
    local lastUse = GMT_BombingCooldowns[plyID] or 0
    if CurTime() - lastUse < COOLDOWN_TIME then
        ply:ChatPrint("[GMT] Please wait " .. math.ceil(COOLDOWN_TIME - (CurTime() - lastUse)) .. " seconds before firing again")
        return false
    end
    GMT_BombingCooldowns[plyID] = CurTime()

    local targetPos = trace.HitPos

    local fireMode = self:GetClientNumber("fire_mode", 0)
    local pattern = self:GetClientNumber("pattern", 1)
    
    -- Safety: Server-side clamps for artillery/orbital (more restrictive than bomber)
    local maxBombs = (fireMode ~= 0) and 32 or 128 -- Artillery/orbital capped lower
    local bombCount = math.Clamp(self:GetClientNumber("bomb_count", 8), 1, maxBombs)
    local radius = math.Clamp(self:GetClientNumber("radius", 400), 50, 5000)
    local altitude = math.Clamp(self:GetClientNumber("altitude", 800), 200, 4000)
    local speed = math.Clamp(self:GetClientNumber("speed", 1600), 500, 6000)
    local bombDamage = math.Clamp(self:GetClientNumber("bomb_damage", 150), 1, 2000)
    local bombRadius = math.Clamp(self:GetClientNumber("bomb_radius", 250), 10, 2000)
    
    local faction = self:GetClientNumber("faction", 2)
    local factionName = FACTION_NAMES[faction] or "Unknown"

    -- Artillery / orbital fire support: no visible bomber entity
    if fireMode ~= 0 then
        return FireSupportStrike(self, ply, targetPos, fireMode, pattern, bombCount, radius, altitude, bombDamage, bombRadius, factionName)
    end

    -- Bomber mode: spawn the bomber entity and let it handle the run
    return FireBomberRun(self, ply, targetPos, pattern, radius, altitude, speed, bombDamage, bombRadius, factionName)
end

-- Right click: mirror last placement, but from behind player (quick re-use)
function TOOL:RightClick(trace)
    if CLIENT then return true end

    local ply = self:GetOwner()
    if not IsValid(ply) then return false end

    -- Use the same core logic as left click but aim at a point further away
    local aimTrace = ply:GetEyeTrace()
    if not aimTrace.Hit then return false end

    return self:LeftClick(aimTrace)
end

-- Preset definitions for CWRP
local FIRE_SUPPORT_PRESETS = {
    ["light_artillery"] = {
        name = "Light Artillery",
        fire_mode = 1,
        pattern = 1,
        bomb_count = 6,
        radius = 300,
        bomb_damage = 100,
        bomb_radius = 200,
        projectile_class = "",
    },
    ["heavy_artillery"] = {
        name = "Heavy Artillery",
        fire_mode = 1,
        pattern = 2,
        bomb_count = 12,
        radius = 600,
        bomb_damage = 250,
        bomb_radius = 350,
        projectile_class = "",
    },
    ["precision_orbital"] = {
        name = "Precision Orbital",
        fire_mode = 2,
        pattern = 0,
        bomb_count = 1,
        radius = 200,
        bomb_damage = 500,
        bomb_radius = 300,
        projectile_class = "",
    },
    ["area_denial"] = {
        name = "Area Denial",
        fire_mode = 1,
        pattern = 2,
        bomb_count = 20,
        radius = 800,
        bomb_damage = 150,
        bomb_radius = 250,
        projectile_class = "",
    },
    ["atap_barrage"] = {
        name = "AT-AP Barrage",
        fire_mode = 1,
        pattern = 1,
        bomb_count = 8,
        radius = 400,
        bomb_damage = 200,
        bomb_radius = 300,
        projectile_class = "lvs_atap_cannon",
    },
    ["hmp_missile_run"] = {
        name = "HMP Missile Run",
        fire_mode = 0,
        pattern = 1,
        bomb_count = 6,
        radius = 500,
        bomb_damage = 300,
        bomb_radius = 400,
        projectile_class = "hmp_concussionmissile",
    },
    ["proton_torpedo_volley"] = {
        name = "Proton Torpedo Volley",
        fire_mode = 2,
        pattern = 2,
        bomb_count = 5,
        radius = 600,
        bomb_damage = 400,
        bomb_radius = 350,
        projectile_class = "lvs_protontorpedo",
    },
    ["lvs_concussion_barrage"] = {
        name = "LVS Concussion Barrage",
        fire_mode = 1,
        pattern = 1,
        bomb_count = 10,
        radius = 450,
        bomb_damage = 250,
        bomb_radius = 300,
        projectile_class = "lvs_concussionmissile",
    },
}

-- Control panel
function TOOL.BuildCPanel(panel)
    panel:Help("Configure and fire cinematic bombing runs, artillery, or orbital strikes.")

    -- Presets
    local presetCat = vgui.Create("DCollapsibleCategory", panel)
    presetCat:SetLabel("Quick Presets")
    presetCat:SetExpanded(true)
    local presetContent = vgui.Create("DPanelList")
    presetContent:SetAutoSize(true)
    presetContent:SetSpacing(4)
    presetContent:SetPadding(8)
    presetCat:SetContents(presetContent)
    panel:AddItem(presetCat)

    local presetCombo = vgui.Create("DComboBox")
    presetCombo:SetSortItems(false)
    for id, preset in pairs(FIRE_SUPPORT_PRESETS) do
        presetCombo:AddChoice(preset.name, id)
    end
    presetCombo.OnSelect = function(_, _, _, presetID)
        local preset = FIRE_SUPPORT_PRESETS[presetID]
        if not preset then return end

        RunConsoleCommand("gmt_bombing_tool_fire_mode", tostring(preset.fire_mode))
        RunConsoleCommand("gmt_bombing_tool_pattern", tostring(preset.pattern))
        RunConsoleCommand("gmt_bombing_tool_bomb_count", tostring(preset.bomb_count))
        RunConsoleCommand("gmt_bombing_tool_radius", tostring(preset.radius))
        RunConsoleCommand("gmt_bombing_tool_bomb_damage", tostring(preset.bomb_damage))
        RunConsoleCommand("gmt_bombing_tool_bomb_radius", tostring(preset.bomb_radius))
        RunConsoleCommand("gmt_bombing_tool_projectile_class", preset.projectile_class or "")

        chat.AddText(
            Color(100, 200, 100), "[GMT] ",
            Color(255, 255, 255), "Applied preset: ",
            Color(255, 200, 100), preset.name
        )
    end
    presetContent:AddItem(presetCombo)

    -- Pattern
    local patternCombo = vgui.Create("DComboBox", panel)
    patternCombo:SetSortItems(false)
    patternCombo:AddChoice("Point Strike (single impact)", "0")
    patternCombo:AddChoice("Line (carpet bombing)", "1")
    patternCombo:AddChoice("Circle (encirclement)", "2")
    patternCombo.OnSelect = function(_, _, _, data)
        RunConsoleCommand("gmt_bombing_tool_pattern", data)
    end
    panel:AddItem(patternCombo)

    -- Fire mode (bomber vs artillery vs orbital)
    local fireModeCombo = vgui.Create("DComboBox", panel)
    fireModeCombo:SetSortItems(false)
    fireModeCombo:AddChoice("Bomber Run (visible ship)", "0")
    fireModeCombo:AddChoice("Artillery Strike (shells from sky)", "1")
    fireModeCombo:AddChoice("Orbital Strike (space cannon)", "2")
    fireModeCombo.OnSelect = function(_, _, _, data)
        RunConsoleCommand("gmt_bombing_tool_fire_mode", data)
    end
    panel:AddItem(fireModeCombo)

    -- Projectile class (optional, for artillery/orbital)
    local projLabel = vgui.Create("DLabel", panel)
    projLabel:SetText("Projectile (optional)")
    projLabel:SetTextColor(Color(0, 0, 0))
    projLabel:SizeToContents()
    panel:AddItem(projLabel)

    local projCombo = vgui.Create("DComboBox", panel)
    projCombo:SetSortItems(false)
    projCombo:AddChoice("Default Explosion", "")
    projCombo:AddChoice("AT-AP Cannon (LVS)", "lvs_atap_cannon")
    projCombo:AddChoice("Concussion Missile (LVS)", "lvs_concussionmissile")
    projCombo:AddChoice("Concussion Missile (HMP)", "hmp_concussionmissile")
    projCombo:AddChoice("Pink Bomb (LVS)", "lvs_pinkbomb")
    projCombo:AddChoice("Proton Torpedo (LVS)", "lvs_protontorpedo")
    projCombo.OnSelect = function(_, _, _, data)
        RunConsoleCommand("gmt_bombing_tool_projectile_class", data or "")
    end
    panel:AddItem(projCombo)

    -- Arrival mode (mirrors the wave spawner's feel)
    local arrivalCombo = vgui.Create("DComboBox", panel)
    arrivalCombo:SetSortItems(false)
    arrivalCombo:AddChoice("Static (instant fly-through)", "0")
    arrivalCombo:AddChoice("Fly-In (long approach)", "1")
    arrivalCombo:AddChoice("Hyperspace (jump in)", "2")
    arrivalCombo:AddChoice("Dive-Bomb (steep attack)", "3")
    arrivalCombo.OnSelect = function(_, _, _, data)
        RunConsoleCommand("gmt_bombing_tool_arrival_mode", data)
    end
    panel:AddItem(arrivalCombo)

    -- Bombing parameters
    local countSlider = vgui.Create("DNumSlider", panel)
    countSlider:SetText("Bomb Count")
    countSlider:SetMin(1)
    countSlider:SetMax(64)
    countSlider:SetDecimals(0)
    countSlider:SetConVar("gmt_bombing_tool_bomb_count")
    panel:AddItem(countSlider)

    local radiusSlider = vgui.Create("DNumSlider", panel)
    radiusSlider:SetText("Radius / Half-Length")
    radiusSlider:SetMin(100)
    radiusSlider:SetMax(3000)
    radiusSlider:SetDecimals(0)
    radiusSlider:SetConVar("gmt_bombing_tool_radius")
    panel:AddItem(radiusSlider)

    local altSlider = vgui.Create("DNumSlider", panel)
    altSlider:SetText("Altitude")
    altSlider:SetMin(200)
    altSlider:SetMax(4000)
    altSlider:SetDecimals(0)
    altSlider:SetConVar("gmt_bombing_tool_altitude")
    panel:AddItem(altSlider)

    local speedSlider = vgui.Create("DNumSlider", panel)
    speedSlider:SetText("Flight Speed")
    speedSlider:SetMin(500)
    speedSlider:SetMax(6000)
    speedSlider:SetDecimals(0)
    speedSlider:SetConVar("gmt_bombing_tool_speed")
    panel:AddItem(speedSlider)

    local dmgSlider = vgui.Create("DNumSlider", panel)
    dmgSlider:SetText("Bomb Damage")
    dmgSlider:SetMin(1)
    dmgSlider:SetMax(1000)
    dmgSlider:SetDecimals(0)
    dmgSlider:SetConVar("gmt_bombing_tool_bomb_damage")
    panel:AddItem(dmgSlider)

    local radSlider = vgui.Create("DNumSlider", panel)
    radSlider:SetText("Bomb Radius")
    radSlider:SetMin(50)
    radSlider:SetMax(1000)
    radSlider:SetDecimals(0)
    radSlider:SetConVar("gmt_bombing_tool_bomb_radius")
    panel:AddItem(radSlider)

    -- Model controls
    panel:Help("Bomber Model")

    local defaultModelEntry = vgui.Create("DTextEntry", panel)
    defaultModelEntry:SetConVar("gmt_bombing_tool_default_model")
    defaultModelEntry:SetPlaceholderText("models/combine_helicopter.mdl")
    panel:AddItem(defaultModelEntry)

    local customCheck = vgui.Create("DCheckBoxLabel", panel)
    customCheck:SetText("Use Custom Model Path")
    customCheck:SetConVar("gmt_bombing_tool_use_custom_model")
    customCheck:SizeToContents()
    panel:AddItem(customCheck)

    local customEntry = vgui.Create("DTextEntry", panel)
    customEntry:SetConVar("gmt_bombing_tool_custom_model_path")
    customEntry:SetPlaceholderText("models/your/custom/ship.mdl")
    panel:AddItem(customEntry)

    -- Faction selector (CWRP flavor)
    panel:Help("Faction (for flavor text)")
    local factionCombo = vgui.Create("DComboBox", panel)
    factionCombo:SetSortItems(false)
    factionCombo:AddChoice("GAR (Republic)", "1")
    factionCombo:AddChoice("CIS (Droids)", "2")
    factionCombo:AddChoice("Neutral", "3")
    factionCombo:AddChoice("Mandalorian", "4")
    factionCombo.OnSelect = function(_, _, _, data)
        RunConsoleCommand("gmt_bombing_tool_faction", data)
    end
    panel:AddItem(factionCombo)
end

-- Language strings
if CLIENT then
    language.Add("tool.gmt_bombing_tool.name", "Bombing Tool")
    language.Add("tool.gmt_bombing_tool.desc", "Call in configurable bombing runs over a target area")
    language.Add("tool.gmt_bombing_tool.left", "Fire bombing run at crosshair")
    language.Add("tool.gmt_bombing_tool.right", "Repeat last bombing direction")
end

