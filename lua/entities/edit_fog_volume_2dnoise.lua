
AddCSLuaFile()
DEFINE_BASECLASS( "base_edit" )

ENT.Spawnable = true
ENT.AdminOnly = true

ENT.PrintName = "Fog Volume (2D Noise)"
ENT.Category = "Fog 2"
ENT.Information = "Right click on this entity via the context menu (hold C by default) and select 'Edit Properties' to edit the fog."
ENT.Material = Material("mercfogvolume2dnoise")

local mat_SetFloat = FindMetaTable( "IMaterial" ).SetFloat
local mat_SetMatrix = FindMetaTable( "IMaterial" ).SetMatrix
local emtx = {0, 0, 0, 0}

function ENT:Initialize()

	BaseClass.Initialize( self )

	self:SetMaterial( "gmod/edit_fog" )

	if ( CLIENT ) then

		hook.Add( "RenderScreenspaceEffects", self, self.SetupFogVolume )

	end

end

function ENT:SetupFogVolume()

    local sp = self:GetPos()
    local ep = LocalPlayer():EyePos()
	local density = self:GetDensity()
    local fogstart = self:GetFogStart()
	local fogend = self:GetFogEnd()
	local fogcolor = self:GetFogColor()
    local wx, wy, h = self:GetWidthX(), self:GetWidthY(), self:GetHeight()
	local mat = self.Material

	-- set shader parameters
	mat_SetFloat( mat, "$c1_w", density )

	mat_SetFloat( mat, "$c0_x", ep.x )
	mat_SetFloat( mat, "$c0_y", ep.y )
    mat_SetFloat( mat, "$c0_z", ep.z )

    mat_SetFloat( mat, "$c0_w", self:GetEdgeFade() )

	mat_SetFloat( mat, "$c1_x", fogcolor.x )
	mat_SetFloat( mat, "$c1_y", fogcolor.y )
	mat_SetFloat( mat, "$c1_z", fogcolor.z )

    mat_SetFloat( mat, "$c2_x", wx )
    mat_SetFloat( mat, "$c2_y", wy )
    mat_SetFloat( mat, "$c2_z", h )

    mat_SetFloat( mat, "$c3_x", sp.x )
    mat_SetFloat( mat, "$c3_y", sp.y )
    mat_SetFloat( mat, "$c3_z", sp.z )

    mat_SetFloat( mat, "$c2_w", fogstart )
    mat_SetFloat( mat, "$c3_w", fogend )

	mat_SetMatrix( mat, "$viewprojmat", Matrix( {
		{CurTime(), self:GetNoiseSize(), self:GetNoiseMinInfluence(), self:GetNoiseMaxInfluence()},
		{self:GetScrollX(), self:GetScrollY(), 0, 0},
		emtx,
		emtx
	} ) )

	render.SetMaterial( mat )
	render.DrawScreenQuad()

end

function ENT:SetupDataTables()

	self:NetworkVar( "Float", 0, "FogStart", { KeyName = "fogstart", Edit = { type = "Float", min = 0, max = 100000, order = 1 } } )
	self:NetworkVar( "Float", 1, "FogEnd", { KeyName = "fogend", Edit = { type = "Float", min = 0, max = 100000, order = 2 } } )
	self:NetworkVar( "Float", 2, "Density", { KeyName = "density", Edit = { type = "Float", min = 0, max = 3, order = 3 } } )
    self:NetworkVar( "Float", 3, "WidthX", { KeyName = "widthx", Edit = { type = "Float", min = -10000, max = 10000, order = 4 } } )
    self:NetworkVar( "Float", 4, "WidthY", { KeyName = "widthy", Edit = { type = "Float", min = -10000, max = 10000, order = 5 } } )
    self:NetworkVar( "Float", 5, "Height", { KeyName = "height", Edit = { type = "Float", min = 0, max = 10000, order = 6 } } )
    self:NetworkVar( "Float", 6, "EdgeFade", { KeyName = "edgefade", Edit = { type = "Float", min = 0, max = 10000, order = 7 } } )
	self:NetworkVar( "Float", 7, "NoiseSize", { KeyName = "noisesize", Edit = { type = "Float", min = 0.01, max = 1000, order = 8 } } )
	self:NetworkVar( "Float", 8, "NoiseMinInfluence", { KeyName = "noisemininfluence", Edit = { type = "Float", min = 0, max = 1, order = 9 } } )
	self:NetworkVar( "Float", 9, "NoiseMaxInfluence", { KeyName = "noisemaxinfluence", Edit = { type = "Float", min = 0, max = 1, order = 10 } } )
	self:NetworkVar( "Float", 10, "ScrollX", { KeyName = "scrollx", Edit = { type = "Float", min = -100, max = 100, order = 11 } } )
	self:NetworkVar( "Float", 11, "ScrollY", { KeyName = "scrolly", Edit = { type = "Float", min = -100, max = 100, order = 12 } } )

	self:NetworkVar( "Vector", 0, "FogColor", { KeyName = "fogcolor", Edit = { type = "VectorColor", order = 3 } } )

	if ( SERVER ) then

		-- defaults
        self:SetFogStart( 0 )
		self:SetFogEnd( 100 )
		self:SetDensity( 0.9 )
		self:SetFogColor( Vector( 0.6, 0.7, 0.8 ) )

        self:SetWidthX(500)
        self:SetWidthY(500)
        self:SetHeight(250)
        self:SetEdgeFade(30)
		self:SetNoiseSize(0.1)
		self:SetNoiseMinInfluence(0)
		self:SetNoiseMaxInfluence(1)
		self:SetScrollX(0.02)
		self:SetScrollY(0.02)

	end

end

function ENT:UpdateTransmitState()

	return TRANSMIT_ALWAYS

end
