--[[
    Gamemaster Tools - Wave Spawner
    Ship Arrival Animations
]]

-- Spawn mode constants
local SPAWN_MODE_STATIC = 0
local SPAWN_MODE_FLYIN = 1
local SPAWN_MODE_HYPERSPACE = 2
local SPAWN_MODE_LANDING = 3

-- Begin the ship arrival animation based on spawn mode
function ENT:BeginArrival(targetPos, targetAng)
    local mode = self:GetSpawnMode()
    local height = self:GetSpawnHeight()
    local approachAngle = self:GetSpawnAngle()

    self.TargetPos = targetPos
    self.TargetAng = targetAng

    if mode == SPAWN_MODE_STATIC then
        -- Static: Just appear at target position
        self:SetPos(targetPos)
        self:SetAngles(targetAng)
        self:SetArrivalComplete(true)
        return
    end

    self:SetArrivalComplete(false)

    if mode == SPAWN_MODE_FLYIN then
        -- Fly-In: Start far away and approach
        local approachDir = Angle(0, approachAngle, 0):Forward()
        local startPos = targetPos + (approachDir * -3000) + Vector(0, 0, height)
        self:SetPos(startPos)
        self:SetAngles(Angle(0, approachAngle, 0))

        -- Smooth approach over time
        self.ArrivalStartTime = CurTime()
        self.ArrivalDuration = 5  -- 5 seconds to arrive
        self.ArrivalStartPos = startPos

    elseif mode == SPAWN_MODE_HYPERSPACE then
        -- Hyperspace: Start invisible, play effect, then appear and slow down
        local approachDir = Angle(0, approachAngle, 0):Forward()
        local startPos = targetPos + (approachDir * -2000) + Vector(0, 0, height * 0.5)
        self:SetPos(startPos)
        self:SetAngles(Angle(0, approachAngle, 0))
        self:SetNoDraw(true)

        -- Hyperspace jump-in effect after delay
        timer.Simple(0.5, function()
            if not IsValid(self) then return end
            self:SetNoDraw(false)

            -- Play hyperspace sound
            self:EmitSound("ambient/atmosphere/thunder1.wav", 100, 150)

            -- Screen shake for nearby players
            for _, ply in ipairs(player.GetAll()) do
                if IsValid(ply) and ply:GetPos():Distance(self:GetPos()) < 3000 then
                    util.ScreenShake(ply:GetPos(), 10, 5, 2, 1000)
                end
            end

            -- Start approach
            self.ArrivalStartTime = CurTime()
            self.ArrivalDuration = 3
            self.ArrivalStartPos = startPos
        end)

    elseif mode == SPAWN_MODE_LANDING then
        -- Landing: Start high above and descend
        local startPos = targetPos + Vector(0, 0, height + 500)
        self:SetPos(startPos)
        self:SetAngles(targetAng)

        -- Descend over time
        self.ArrivalStartTime = CurTime()
        self.ArrivalDuration = 4
        self.ArrivalStartPos = startPos
    end
end

-- Update arrival animation
function ENT:UpdateArrival()
    if self:GetArrivalComplete() then return end
    if not self.ArrivalStartTime then return end

    local elapsed = CurTime() - self.ArrivalStartTime
    local progress = math.Clamp(elapsed / self.ArrivalDuration, 0, 1)

    -- Ease out for smooth deceleration
    local easedProgress = 1 - math.pow(1 - progress, 3)

    local mode = self:GetSpawnMode()

    if mode == SPAWN_MODE_FLYIN then
        -- Smooth interpolation to target
        local newPos = LerpVector(easedProgress, self.ArrivalStartPos, self.TargetPos)
        self:SetPos(newPos)

        -- Gradually rotate to target angle
        local currentAng = self:GetAngles()
        local targetYaw = self.TargetAng.y
        local newYaw = Lerp(easedProgress, currentAng.y, targetYaw)
        self:SetAngles(Angle(0, newYaw, 0))

    elseif mode == SPAWN_MODE_HYPERSPACE then
        -- Fast initial approach, then slow down dramatically
        local newPos = LerpVector(easedProgress, self.ArrivalStartPos, self.TargetPos)
        self:SetPos(newPos)

    elseif mode == SPAWN_MODE_LANDING then
        -- Vertical descent
        local newPos = LerpVector(easedProgress, self.ArrivalStartPos, self.TargetPos)
        self:SetPos(newPos)

        -- Slight wobble during descent
        if progress < 0.8 then
            local wobble = math.sin(elapsed * 3) * 2
            self:SetAngles(self.TargetAng + Angle(wobble * 0.5, 0, wobble))
        else
            self:SetAngles(self.TargetAng)
        end
    end

    -- Check if arrival complete
    if progress >= 1 then
        self:SetPos(self.TargetPos)
        self:SetAngles(self.TargetAng)
        self:SetArrivalComplete(true)

        -- Play landing sound
        if mode == SPAWN_MODE_LANDING then
            self:EmitSound("physics/concrete/concrete_impact_hard3.wav", 80, 80)
            for _, ply in ipairs(player.GetAll()) do
                if IsValid(ply) and ply:GetPos():Distance(self:GetPos()) < 1000 then
                    util.ScreenShake(ply:GetPos(), 5, 3, 1, 500)
                end
            end
        elseif mode == SPAWN_MODE_FLYIN or mode == SPAWN_MODE_HYPERSPACE then
            self:EmitSound("ambient/machines/thumper_shutdown1.wav", 70, 100)
        end

        -- Announce arrival
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) then
                ply:ChatPrint("[GMT] Transport has arrived!")
            end
        end
    end
end
