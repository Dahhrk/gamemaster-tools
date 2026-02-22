include("shared.lua")

-- Star Wars Clone Wars themed colors
local SW_COLORS = {
    -- Republic (GAR) colors
    republicBlue = Color(60, 140, 220),
    republicGold = Color(255, 180, 50),
    republicLight = Color(120, 180, 255),

    -- CIS colors
    cisGray = Color(140, 140, 150),
    cisRed = Color(180, 60, 60),

    -- UI colors
    panelBg = Color(15, 25, 40, 240),
    panelBorder = Color(60, 120, 180),
    headerBg = Color(20, 40, 70),
    textPrimary = Color(220, 230, 255),
    textSecondary = Color(150, 170, 200),
    textAccent = Color(255, 200, 80),

    -- Health colors
    healthHigh = Color(80, 180, 255),      -- Blue for high health
    healthMid = Color(255, 200, 80),       -- Gold/orange for mid
    healthLow = Color(255, 80, 80),        -- Red for low
    healthBg = Color(20, 30, 50),

    -- Status colors
    active = Color(80, 255, 120),
    inactive = Color(255, 100, 100),
}

-- Create custom fonts for health bars
surface.CreateFont("GMT_HealthBar", {
    font = "Trebuchet MS",
    size = 14,
    weight = 700,
    antialias = true,
})

surface.CreateFont("GMT_HealthBarSmall", {
    font = "Trebuchet MS",
    size = 12,
    weight = 600,
    antialias = true,
})

surface.CreateFont("GMT_NameTag", {
    font = "Trebuchet MS",
    size = 14,
    weight = 800,
    antialias = true,
})

surface.CreateFont("GMT_Title", {
    font = "Trebuchet MS",
    size = 24,
    weight = 800,
    antialias = true,
})

surface.CreateFont("GMT_Status", {
    font = "Trebuchet MS",
    size = 12,
    weight = 700,
    antialias = true,
})

-- Smooth health interpolation cache
local healthCache = {}

-- Get interpolated health for smooth animations
local function GetSmoothHealth(ent, currentHealth)
    local entIndex = ent:EntIndex()
    if not healthCache[entIndex] then
        healthCache[entIndex] = currentHealth
    end

    healthCache[entIndex] = Lerp(FrameTime() * 8, healthCache[entIndex], currentHealth)
    return healthCache[entIndex]
end

-- Clean up cache for removed entities
hook.Add("EntityRemoved", "GMT_HealthCacheCleanup", function(ent)
    if healthCache[ent:EntIndex()] then
        healthCache[ent:EntIndex()] = nil
    end
end)

-- Draw angular/hexagonal box (Star Wars style)
local function DrawAngularBox(x, y, w, h, color, cutSize)
    cutSize = cutSize or 8
    local poly = {
        { x = x + cutSize, y = y },
        { x = x + w - cutSize, y = y },
        { x = x + w, y = y + cutSize },
        { x = x + w, y = y + h - cutSize },
        { x = x + w - cutSize, y = y + h },
        { x = x + cutSize, y = y + h },
        { x = x, y = y + h - cutSize },
        { x = x, y = y + cutSize },
    }
    surface.SetDrawColor(color)
    draw.NoTexture()
    surface.DrawPoly(poly)
end

-- Draw angular outline
local function DrawAngularOutline(x, y, w, h, color, cutSize)
    cutSize = cutSize or 8
    surface.SetDrawColor(color)
    -- Top edge
    surface.DrawLine(x + cutSize, y, x + w - cutSize, y)
    -- Top-right corner
    surface.DrawLine(x + w - cutSize, y, x + w, y + cutSize)
    -- Right edge
    surface.DrawLine(x + w, y + cutSize, x + w, y + h - cutSize)
    -- Bottom-right corner
    surface.DrawLine(x + w, y + h - cutSize, x + w - cutSize, y + h)
    -- Bottom edge
    surface.DrawLine(x + w - cutSize, y + h, x + cutSize, y + h)
    -- Bottom-left corner
    surface.DrawLine(x + cutSize, y + h, x, y + h - cutSize)
    -- Left edge
    surface.DrawLine(x, y + h - cutSize, x, y + cutSize)
    -- Top-left corner
    surface.DrawLine(x, y + cutSize, x + cutSize, y)
end

-- Draw Star Wars style health bar
local function DrawSWHealthBar(x, y, width, height, health, maxHealth, showText, teamID)
    local healthPercent = math.Clamp(health / maxHealth, 0, 1)

    -- Determine color based on health and team
    local barColor
    if teamID == 1 then  -- Republic
        barColor = SW_COLORS.republicBlue
    elseif teamID == 2 then  -- CIS
        barColor = SW_COLORS.cisGray
    else
        -- Color based on health percentage
        if healthPercent > 0.6 then
            barColor = SW_COLORS.healthHigh
        elseif healthPercent > 0.3 then
            barColor = SW_COLORS.healthMid
        else
            barColor = SW_COLORS.healthLow
        end
    end

    -- Background
    DrawAngularBox(x, y, width, height, SW_COLORS.healthBg, 4)

    -- Health fill
    local fillWidth = math.max(0, (width - 4) * healthPercent)
    if fillWidth > 0 then
        DrawAngularBox(x + 2, y + 2, fillWidth, height - 4, barColor, 3)

        -- Scanline effect
        for i = 0, fillWidth, 4 do
            surface.SetDrawColor(255, 255, 255, 15)
            surface.DrawLine(x + 2 + i, y + 2, x + 2 + i, y + height - 2)
        end

        -- Top highlight
        surface.SetDrawColor(255, 255, 255, 50)
        surface.DrawRect(x + 2, y + 2, fillWidth, 2)

        -- Critical health pulse
        if healthPercent <= 0.25 then
            local pulse = math.abs(math.sin(CurTime() * 5)) * 0.5
            DrawAngularBox(x + 2, y + 2, fillWidth, height - 4, Color(255, 50, 50, pulse * 150), 3)
        end
    end

    -- Border
    DrawAngularOutline(x, y, width, height, SW_COLORS.panelBorder, 4)

    -- Health text
    if showText then
        local healthText = math.floor(health) .. " / " .. math.floor(maxHealth)
        draw.SimpleText(healthText, "GMT_HealthBarSmall", x + width / 2 + 1, y + height / 2 + 1, Color(0, 0, 0, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(healthText, "GMT_HealthBarSmall", x + width / 2, y + height / 2, SW_COLORS.textPrimary, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

function ENT:Draw()
    self:DrawModel()

    local pos = self:GetPos() + Vector(0, 0, 60)
    local ang = LocalPlayer():EyeAngles()
    ang:RotateAroundAxis(ang:Forward(), 90)
    ang:RotateAroundAxis(ang:Right(), 90)

    local spawnerHealth = self:GetSpawnerHealth()
    local hasHealth = spawnerHealth and spawnerHealth > 0
    local hasStats = self:GetTotalNPCsSpawned() > 0
    local panelHeight = hasHealth and 240 or (hasStats and 200 or 180)
    local teamID = self:GetTeamID()

    -- Get team-specific accent color
    local accentColor = teamID == 1 and SW_COLORS.republicBlue or
                        teamID == 2 and SW_COLORS.cisGray or
                        SW_COLORS.republicGold

    cam.Start3D2D(pos, ang, 0.1)
        -- Main panel background
        DrawAngularBox(-170, -95, 340, panelHeight, SW_COLORS.panelBg, 12)
        DrawAngularOutline(-170, -95, 340, panelHeight, accentColor, 12)

        -- Header bar with accent
        DrawAngularBox(-165, -90, 330, 35, SW_COLORS.headerBg, 8)
        surface.SetDrawColor(accentColor)
        surface.DrawRect(-165, -90, 4, 35)  -- Left accent bar

        -- Title
        draw.SimpleText("WAVE SPAWNER", "GMT_Title", 0, -72, SW_COLORS.textAccent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Status indicator
        local status = self:GetActive() and "ONLINE" or "OFFLINE"
        local statusCol = self:GetActive() and SW_COLORS.active or SW_COLORS.inactive

        -- Status box
        DrawAngularBox(-50, -50, 100, 22, Color(20, 30, 45), 4)
        if self:GetActive() then
            local glow = math.abs(math.sin(CurTime() * 3)) * 0.3 + 0.7
            DrawAngularBox(-48, -48, 96, 18, Color(statusCol.r, statusCol.g, statusCol.b, glow * 80), 3)
        end
        draw.SimpleText(status, "GMT_Status", 0, -39, statusCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Wave progress section
        local waveProgress = self:GetCurrentWave() / math.max(1, self:GetWaveCount())

        -- Wave progress bar background
        DrawAngularBox(-120, -20, 240, 12, SW_COLORS.healthBg, 3)
        -- Wave progress fill
        if waveProgress > 0 then
            DrawAngularBox(-118, -18, 236 * waveProgress, 8, accentColor, 2)
        end
        DrawAngularOutline(-120, -20, 240, 12, Color(accentColor.r, accentColor.g, accentColor.b, 150), 3)

        -- Wave text
        draw.SimpleText("WAVE " .. self:GetCurrentWave() .. " / " .. self:GetWaveCount(), "GMT_Status", 0, -3, SW_COLORS.textPrimary, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- NPC info
        local npcName = self:GetNPCClass()
        if string.len(npcName) > 28 then
            npcName = string.sub(npcName, 1, 25) .. "..."
        end
        draw.SimpleText("TARGET: " .. npcName:upper(), "GMT_HealthBarSmall", 0, 18, SW_COLORS.textSecondary, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Alive count
        local aliveRatio = self:GetAliveCount() / math.max(1, self:GetMaxActive())
        local aliveColor = aliveRatio > 0.7 and SW_COLORS.healthMid or SW_COLORS.textPrimary
        draw.SimpleText("ACTIVE UNITS: " .. self:GetAliveCount() .. " / " .. self:GetMaxActive(), "GMT_HealthBarSmall", 0, 38, aliveColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        
        -- Statistics (if waves have started)
        if self:GetTotalNPCsSpawned() > 0 then
            local totalSpawned = self:GetTotalNPCsSpawned()
            local totalKilled = self:GetTotalNPCsKilled()
            local statsText = "STATS: " .. totalKilled .. " / " .. totalSpawned .. " eliminated"
            draw.SimpleText(statsText, "GMT_HealthBarSmall", 0, 58, SW_COLORS.textSecondary, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        -- Next wave countdown
        if self:GetActive() and self:GetCurrentWave() < self:GetWaveCount() then
            local timeLeft = math.max(0, self:GetNextWaveTime() - CurTime())
            local timeProgress = 1 - (timeLeft / math.max(1, self:GetWaveDelay()))

            -- Timer bar
            DrawAngularBox(-100, 55, 200, 8, SW_COLORS.healthBg, 2)
            if timeProgress > 0 then
                DrawAngularBox(-98, 57, 196 * timeProgress, 4, SW_COLORS.republicLight, 1)
            end

            draw.SimpleText("NEXT WAVE: " .. string.format("%.1f", timeLeft) .. "s", "GMT_HealthBarSmall", 0, 72, SW_COLORS.republicLight, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        -- Health bar (if spawner is destructible)
        if hasHealth then
            draw.SimpleText("SPAWNER INTEGRITY", "GMT_HealthBarSmall", 0, 92, SW_COLORS.textAccent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            DrawSWHealthBar(-130, 105, 260, 22, self:Health(), spawnerHealth, true, teamID)
        end
    cam.End3D2D()
end

-- Improved NPC Health Bar HUD with Star Wars styling
local function DrawNPCHealthBar()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local trace = ply:GetEyeTrace()
    local ent = trace.Entity

    if not IsValid(ent) then return end

    local isGMTNPC = ent:GetNWBool("GMT_SpawnedNPC", false)
    local isSpawner = ent:GetClass() == "gmt_wave_spawner"

    if not isGMTNPC and not isSpawner then return end

    -- Use squared distance for performance
    local distSqr = ply:GetPos():DistToSqr(ent:GetPos())
    if distSqr > 2250000 then return end -- 1500^2
    
    local dist = math.sqrt(distSqr)

    local health = ent:Health()
    local maxHealth = ent:GetMaxHealth()

    if isSpawner then
        maxHealth = ent:GetSpawnerHealth()
        if not maxHealth or maxHealth <= 0 then return end
    end

    if isGMTNPC then
        local nwMaxHealth = ent:GetNWInt("GMT_MaxHealth", 0)
        if nwMaxHealth > 0 then
            maxHealth = nwMaxHealth
        end
    end

    if maxHealth <= 0 then maxHealth = 100 end

    local smoothHealth = GetSmoothHealth(ent, health)
    local headPos = ent:GetPos() + Vector(0, 0, ent:OBBMaxs().z + 15)
    local screenPos = headPos:ToScreen()

    if not screenPos.visible then return end

    local scale = math.Clamp(1.2 - (dist / 1500), 0.6, 1.2)
    local barWidth = 160 * scale
    local barHeight = 18 * scale
    local x = screenPos.x - barWidth / 2
    local y = screenPos.y

    local alpha = math.Clamp((1500 - dist) / 300, 0.3, 1)

    -- Get team ID for color
    local teamID = ent:GetNWInt("GMT_TeamID", 0)

    -- Draw name tag with Star Wars styling
    local name = isSpawner and "WAVE SPAWNER" or (ent:GetNWString("GMT_NPCName", ent:GetClass())):upper()

    surface.SetFont("GMT_NameTag")
    local nameWidth = surface.GetTextSize(name)

    -- Name background
    local nameBgX = screenPos.x - nameWidth / 2 - 12
    local nameBgY = y - 26 * scale
    local nameBgW = nameWidth + 24
    local nameBgH = 20 * scale

    DrawAngularBox(nameBgX, nameBgY, nameBgW, nameBgH, Color(15, 25, 40, 220 * alpha), 4)

    -- Team accent bar on name
    local accentColor = teamID == 1 and SW_COLORS.republicBlue or
                        teamID == 2 and SW_COLORS.cisGray or
                        SW_COLORS.republicGold
    surface.SetDrawColor(accentColor.r, accentColor.g, accentColor.b, 255 * alpha)
    surface.DrawRect(nameBgX, nameBgY, 3, nameBgH)

    -- Name text
    draw.SimpleText(name, "GMT_NameTag", screenPos.x + 1, y - 16 * scale + 1, Color(0, 0, 0, 200 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText(name, "GMT_NameTag", screenPos.x, y - 16 * scale, Color(SW_COLORS.textPrimary.r, SW_COLORS.textPrimary.g, SW_COLORS.textPrimary.b, 255 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- Health bar
    local healthPercent = math.Clamp(smoothHealth / maxHealth, 0, 1)

    -- Determine bar color
    local barColor
    if teamID == 1 then
        barColor = SW_COLORS.republicBlue
    elseif teamID == 2 then
        barColor = SW_COLORS.cisGray
    else
        if healthPercent > 0.6 then
            barColor = SW_COLORS.healthHigh
        elseif healthPercent > 0.3 then
            barColor = SW_COLORS.healthMid
        else
            barColor = SW_COLORS.healthLow
        end
    end

    -- Health bar background
    DrawAngularBox(x, y, barWidth, barHeight, Color(15, 25, 40, 230 * alpha), 4)

    -- Health fill
    local fillWidth = math.max(0, (barWidth - 4) * healthPercent)
    if fillWidth > 0 then
        DrawAngularBox(x + 2, y + 2, fillWidth, barHeight - 4, Color(barColor.r, barColor.g, barColor.b, 255 * alpha), 3)

        -- Scanlines
        for i = 0, fillWidth, 6 do
            surface.SetDrawColor(255, 255, 255, 20 * alpha)
            surface.DrawLine(x + 2 + i, y + 2, x + 2 + i, y + barHeight - 2)
        end

        -- Highlight
        surface.SetDrawColor(255, 255, 255, 60 * alpha)
        surface.DrawRect(x + 2, y + 2, fillWidth, 2)

        -- Critical pulse
        if healthPercent <= 0.25 then
            local pulse = math.abs(math.sin(CurTime() * 5)) * 0.5
            DrawAngularBox(x + 2, y + 2, fillWidth, barHeight - 4, Color(255, 50, 50, pulse * 150 * alpha), 3)
        end
    end

    -- Border
    DrawAngularOutline(x, y, barWidth, barHeight, Color(accentColor.r, accentColor.g, accentColor.b, 180 * alpha), 4)

    -- Health text
    local healthText = math.floor(smoothHealth) .. " / " .. math.floor(maxHealth)
    draw.SimpleText(healthText, "GMT_HealthBarSmall", screenPos.x + 1, y + barHeight / 2 + 1, Color(0, 0, 0, 200 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText(healthText, "GMT_HealthBarSmall", screenPos.x, y + barHeight / 2, Color(255, 255, 255, 255 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- Health percentage below
    local percentText = math.floor(healthPercent * 100) .. "%"
    draw.SimpleText(percentText, "GMT_HealthBarSmall", screenPos.x, y + barHeight + 10 * scale, Color(SW_COLORS.textSecondary.r, SW_COLORS.textSecondary.g, SW_COLORS.textSecondary.b, 180 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

hook.Add("HUDPaint", "GMT_NPCHealthBar", DrawNPCHealthBar)
