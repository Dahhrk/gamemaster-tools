--[[
    Gamemaster Tools - Bombing Run Entity
    Server-side logic: straight-line flight + bombing patterns
]]

AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

-- How far past the target we continue flying before despawn
local EXTRA_FLIGHT_DISTANCE = 1500

-- Initialize bomber defaults
function ENT:Initialize()
    self:SetModel(self:GetBomberModel() ~= "" and self:GetBomberModel() or "models/combine_helicopter.mdl")

    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_FLY)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_WEAPON) -- don't block players/NPCs

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:EnableGravity(false)
        phys:EnableDrag(false)
    end

    -- Runtime state
    self.StartPos = self:GetPos()
    self.TargetReached = false
    self.FlightStartTime = CurTime()

    -- Precompute distance to target for nicer arrival curves
    local target = self:GetTargetPos()
    self.FlightLengthToTarget = (target - self.StartPos):Length()
    if self.FlightLengthToTarget <= 0 then
        self.FlightLengthToTarget = 1
    end

    -- Hyperspace-style arrival: appear with flash and shake after short delay
    if self:GetArrivalMode() == 2 then
        self:SetNoDraw(true)
        timer.Simple(0.35, function()
            if not IsValid(self) then return end

            self:SetNoDraw(false)

            local pos = self:GetPos()
            local effectdata = EffectData()
            effectdata:SetOrigin(pos)
            effectdata:SetScale(2)
            util.Effect("cball_explode", effectdata, true, true)
            sound.Play("ambient/atmosphere/thunder1.wav", pos, 90, 150)

            -- Cache player list and use squared distance
            local players = player.GetAll()
            local maxDistSqr = 2500 * 2500
            for i = 1, #players do
                local ply = players[i]
                if IsValid(ply) and ply:GetPos():DistToSqr(pos) < maxDistSqr then
                    util.ScreenShake(ply:GetPos(), 8, 4, 1.5, 800)
                end
            end
        end)
    end

    -- Line pattern timing
    self.NextDropTime = 0
    self.DropsDone = 0
end

-- Helper to create an explosion at a position
function ENT:CreateBombExplosion(pos)
    -- Safety: Server-side clamps
    local dmg = math.Clamp(self:GetBombDamage(), 1, 2000)
    local radius = math.Clamp(self:GetBombRadius(), 10, 2000)

    -- Visual effect
    local effectdata = EffectData()
    effectdata:SetOrigin(pos)
    effectdata:SetScale(math.Clamp(radius / 200, 0.5, 4))
    util.Effect("Explosion", effectdata, true, true)

    -- Damage
    util.BlastDamage(self, self:GetOwner() or self, pos, radius, dmg)

    sound.Play("ambient/explosions/explode_4.wav", pos, 100, 100)
end

-- Circle pattern: single pass, many explosions around center
function ENT:DoCirclePattern()
    if self.CircleDone then return end
    self.CircleDone = true

    local center = self:GetTargetPos()
    local count = math.max(self:GetBombCount(), 1)
    local radius = self:GetRadius()

    for i = 0, count - 1 do
        local ang = (i / count) * math.pi * 2
        local offset = Vector(math.cos(ang), math.sin(ang), 0) * radius
        local pos = center + offset
        self:CreateBombExplosion(pos)
    end
end

-- Point pattern: single explosion at center
function ENT:DoPointPattern()
    if self.PointDone then return end
    self.PointDone = true
    self:CreateBombExplosion(self:GetTargetPos())
end

-- Line pattern: drop bombs along flight path as we pass over target
function ENT:HandleLinePattern()
    local total = math.max(self:GetBombCount(), 1)
    local speed = math.max(self:GetSpeed(), 1)

    -- Set up timing the first time we run
    if self.NextDropTime == 0 then
        -- Spread drops over the time it takes to fly across 2 * radius
        local radius = self:GetRadius()
        local travelTime = (radius * 2) / speed
        local interval = travelTime / total

        self.DropInterval = math.max(interval, 0.1)
        self.NextDropTime = CurTime() - 0.01 -- drop immediately
    end

    if self.DropsDone >= total then return end
    if CurTime() < self.NextDropTime then return end

    self.DropsDone = self.DropsDone + 1
    self.NextDropTime = CurTime() + (self.DropInterval or 0.5)

    -- Drop directly beneath current bomber position
    local pos = self:GetPos()
    pos.z = self:GetTargetPos().z
    self:CreateBombExplosion(pos)
end

function ENT:Think()
    -- Safety: Server-side clamp for speed
    local speed = math.Clamp(self:GetSpeed(), 1, 6000)
    local dir = self:GetForward()
    local newPos = self:GetPos() + dir * speed * FrameTime()
    local target = self:GetTargetPos() -- Cache target pos

    -- Dive-bomb style arrival: gradually adjust altitude toward target altitude
    if self:GetArrivalMode() == 3 then
        local distFromStart = (newPos - self.StartPos):Length()
        local frac = math.Clamp(distFromStart / self.FlightLengthToTarget, 0, 1)

        local startZ = self.StartPos.z
        local targetZ = target.z + self:GetAltitude()

        -- Ease-out curve for smoother pull-up near target
        local eased = 1 - math.pow(1 - frac, 3)
        newPos.z = Lerp(eased, startZ, targetZ)
    end

    self:SetPos(newPos)

    -- Determine distance to target horizontally (use squared distance for performance)
    local flatPos = Vector(newPos.x, newPos.y, target.z)
    local distToTargetSqr = flatPos:DistToSqr(target)
    local radiusSqr = self:GetRadius() * self:GetRadius()

    -- Trigger patterns when near target (using squared distance)
    if not self.TargetReached and distToTargetSqr <= radiusSqr then
        self.TargetReached = true

        local pattern = self:GetPattern()
        if pattern == 0 then
            self:DoPointPattern()
        elseif pattern == 2 then
            self:DoCirclePattern()
        end
    end

    -- Line pattern drops while flying over
    if self:GetPattern() == 1 then
        self:HandleLinePattern()
    end

    -- Despawn after flying past the target by EXTRA_FLIGHT_DISTANCE
    local totalFlight = self.FlightLengthToTarget + EXTRA_FLIGHT_DISTANCE
    local flown = (self:GetPos() - self.StartPos):Length()
    if flown >= totalFlight then
        self:Remove()
        return
    end

    self:NextThink(CurTime())
    return true
end

