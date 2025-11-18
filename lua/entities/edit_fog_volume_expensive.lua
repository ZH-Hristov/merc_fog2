
AddCSLuaFile()
DEFINE_BASECLASS( "merc_base_fog_edit" )

ENT.Spawnable = true
ENT.AdminOnly = true

ENT.PrintName = "Fog Volume"
ENT.Category = "Fog 2"
ENT.Information = "Right click on this entity via the context menu (hold C by default) and select 'Edit Properties' to edit the fog."
ENT.Material = Material("mercfogvolumeexpensive")

local mat_SetFloat = FindMetaTable( "IMaterial" ).SetFloat

function ENT:Initialize()

	BaseClass.Initialize( self )

	self:SetMaterial( "gmod/edit_fog" )
	self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	self:EnableCustomCollisions()

	if ( CLIENT ) then

		hook.Add( "RenderScreenspaceEffects", self, self.SetupFogVolume )

	end

end

if CLIENT then
	local mat = Material("mercfogvolumeexpensive")

	function render.DrawFogVolume(pos, aabb, density, fogstart, fogend, color, edgefade)
		local ep = LocalPlayer():EyePos()
		mat_SetFloat( mat, "$c0_x", ep.x )
		mat_SetFloat( mat, "$c0_y", ep.y )
		mat_SetFloat( mat, "$c0_z", ep.z )

		mat_SetFloat( mat, "$c0_w", edgefade )

		mat_SetFloat( mat, "$c3_x", pos.x )
		mat_SetFloat( mat, "$c3_y", pos.y )
    	mat_SetFloat( mat, "$c3_z", pos.z )

		mat_SetFloat( mat, "$c1_w", density )

		mat_SetFloat( mat, "$c1_x", color.r )
		mat_SetFloat( mat, "$c1_y", color.g )
		mat_SetFloat( mat, "$c1_z", color.b )

		mat_SetFloat( mat, "$c2_x", aabb.x * 0.5 )
		mat_SetFloat( mat, "$c2_y", aabb.y * 0.5 )
		mat_SetFloat( mat, "$c2_z", aabb.z * 0.5 )

		mat_SetFloat( mat, "$c2_w", fogstart )
		mat_SetFloat( mat, "$c3_w", fogend )

		render.SetMaterial( mat )
		render.DrawScreenQuad()
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

    mat_SetFloat( mat, "$c2_x", wx * 0.5 )
    mat_SetFloat( mat, "$c2_y", wy * 0.5 )
    mat_SetFloat( mat, "$c2_z", h * 0.5 )

    mat_SetFloat( mat, "$c3_x", sp.x )
    mat_SetFloat( mat, "$c3_y", sp.y )
    mat_SetFloat( mat, "$c3_z", sp.z )

    mat_SetFloat( mat, "$c2_w", fogstart )
    mat_SetFloat( mat, "$c3_w", fogend )

	render.SetMaterial( mat )
	render.DrawScreenQuad()

end

function ENT:SetupDataTables()

	self:NetworkVar( "Float", 0, "FogStart", { KeyName = "fogstart", Edit = { type = "Float", min = 0, max = 100000, order = 1 } } )
	self:NetworkVar( "Float", 1, "FogEnd", { KeyName = "fogend", Edit = { type = "Float", min = 0, max = 100000, order = 2 } } )
	self:NetworkVar( "Float", 2, "Density", { KeyName = "density", Edit = { type = "Float", min = 0, max = 3, order = 3 } } )
    self:NetworkVar( "Float", 3, "WidthX", { KeyName = "widthx", Edit = { type = "Float", min = 0, max = 10000, order = 4 } } )
    self:NetworkVar( "Float", 4, "WidthY", { KeyName = "widthy", Edit = { type = "Float", min = 0, max = 10000, order = 5 } } )
    self:NetworkVar( "Float", 5, "Height", { KeyName = "height", Edit = { type = "Float", min = 0, max = 10000, order = 6 } } )
    self:NetworkVar( "Float", 6, "EdgeFade", { KeyName = "edgefade", Edit = { type = "Float", min = 0, max = 10000, order = 7 } } )



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

	end

end