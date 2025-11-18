
AddCSLuaFile()
DEFINE_BASECLASS( "merc_base_fog_edit" )

ENT.Spawnable = true
ENT.AdminOnly = true

ENT.PrintName = "Radial Fog Editor"
ENT.Category = "Fog 2"
ENT.Information = "Right click on this entity via the context menu (hold C by default) and select 'Edit Properties' to edit the fog."
ENT.Material = Material("mercradialfog")

local mat_SetFloat = FindMetaTable( "IMaterial" ).SetFloat

function ENT:Initialize()

	BaseClass.Initialize( self )

	self:SetMaterial( "gmod/edit_fog" )
	self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	self:EnableCustomCollisions()

	if ( CLIENT ) then

		hook.Add( "RenderScreenspaceEffects", self, self.SetupRadialFog )

	end

end

function ENT:SetupRadialFog()

	local density = self:GetDensity()
	local fogstart = self:GetFogStart()
	local fogend = self:GetFogEnd()
	local fogcolor = self:GetFogColor()
	local mat = self.Material

	-- set shader parameters
	mat_SetFloat( mat, "$c0_z", density )
	mat_SetFloat( mat, "$c0_x", fogstart )
	mat_SetFloat( mat, "$c0_y", fogend )
	mat_SetFloat( mat, "$c1_x", fogcolor.x )
	mat_SetFloat( mat, "$c1_y", fogcolor.y )
	mat_SetFloat( mat, "$c1_z", fogcolor.z )
	mat_SetFloat( mat, "$c2_x", LocalPlayer():EyePos().x )
	mat_SetFloat( mat, "$c2_y", LocalPlayer():EyePos().y )
	mat_SetFloat( mat, "$c2_z", LocalPlayer():EyePos().z )
	mat_SetFloat( mat, "$c0_w", self:GetSkyBlend() ) -- skybox blend factor

	render.SetMaterial( mat )
	render.DrawScreenQuad()

end

function ENT:SetupDataTables()

	self:NetworkVar( "Float", 0, "FogStart", { KeyName = "fogstart", Edit = { type = "Float", min = 0, max = 1000000, order = 1 } } )
	self:NetworkVar( "Float", 1, "FogEnd", { KeyName = "fogend", Edit = { type = "Float", min = 0, max = 1000000, order = 2 } } )
	self:NetworkVar( "Float", 2, "Density", { KeyName = "density", Edit = { type = "Float", min = 0, max = 10, order = 3 } } )
	self:NetworkVar( "Float", 3, "SkyBlend", { KeyName = "skyblend", Edit = { type = "Float", min = 0, max = 1, order = 4 } } )

	self:NetworkVar( "Vector", 0, "FogColor", { KeyName = "fogcolor", Edit = { type = "VectorColor", order = 3 } } )

	if ( SERVER ) then

		-- defaults
		self:SetFogStart( 0.0 )
		self:SetFogEnd( 10000 )
		self:SetDensity( 0.9 )
		self:SetFogColor( Vector( 0.6, 0.7, 0.8 ) )
		self:SetSkyBlend( 1.0 )

	end

end