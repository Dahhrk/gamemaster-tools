ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "Bombing Run"
ENT.Author = "Gamemaster Tools"
ENT.Category = "Gamemaster Tools"
ENT.Spawnable = false
ENT.AdminOnly = true

function ENT:SetupDataTables()
    -- Core bombing parameters
    self:NetworkVar("Vector", 0, "TargetPos")      -- Center of bombing pattern
    self:NetworkVar("Int",    0, "Pattern")        -- 0 = Point, 1 = Line, 2 = Circle
    self:NetworkVar("Int",    1, "BombCount")      -- How many bombs/explosions to create
    self:NetworkVar("Int",    2, "ArrivalMode")    -- 0 = Static, 1 = Fly-In, 2 = Hyperspace, 3 = Dive
    self:NetworkVar("Float",  0, "Radius")         -- Radius/half-length for patterns
    self:NetworkVar("Float",  1, "Altitude")       -- Flight altitude above target
    self:NetworkVar("Float",  2, "Speed")          -- Flight speed (units per second)
    self:NetworkVar("Float",  3, "BombDamage")     -- Explosion damage
    self:NetworkVar("Float",  4, "BombRadius")     -- Explosion radius

    -- Model override from tool
    self:NetworkVar("String", 0, "BomberModel")

    -- Owning player (for cleanup, damage attribution, permissions)
    self:NetworkVar("Entity", 0, "Owner")
end

