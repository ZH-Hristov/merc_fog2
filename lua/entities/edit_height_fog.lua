
AddCSLuaFile()
DEFINE_BASECLASS( "base_edit" )

ENT.Spawnable = true
ENT.AdminOnly = true

ENT.PrintName = "Height Fog Editor"
ENT.Category = "Fog 2"
ENT.Information = "Right click on this entity via the context menu (hold C by default) and select 'Edit Properties' to edit the fog."
ENT.Material = Material("mercheightfog")

local mat_SetFloat = FindMetaTable( "IMaterial" ).SetFloat

function ENT:Initialize()

	BaseClass.Initialize( self )

	self:SetMaterial( "gmod/edit_fog" )

	if ( CLIENT ) then

		hook.Add( "RenderScreenspaceEffects", self, self.SetupHeightFog )

	end

end

function ENT:NeedsDepthPass()

	return true

end

function ENT:SetupHeightFog( start, endd )

	local density = self:GetDensity()
	local fogend = self:GetFogEndHeight()
	local fogcolor = self:GetFogColor()
	local depthfade = self:GetDepthFade()
	local mat = self.Material

	-- set shader parameters
	mat_SetFloat( mat, "$c0_z", density )
	mat_SetFloat( mat, "$c0_x", self:GetPos().z + fogend )
	mat_SetFloat( mat, "$c0_y", self:GetPos().z )
	mat_SetFloat( mat, "$c0_w", depthfade )
	mat_SetFloat( mat, "$c1_x", fogcolor.x )
	mat_SetFloat( mat, "$c1_y", fogcolor.y )
	mat_SetFloat( mat, "$c1_z", fogcolor.z )

	render.SetMaterial( mat )
	render.DrawScreenQuad()

end

function ENT:SetupDataTables()

	self:NetworkVar( "Float", 0, "DepthFade", { KeyName = "depthfade", Edit = { type = "Float", min = 0, max = 100000, order = 1 } } )
	self:NetworkVar( "Float", 1, "FogEndHeight", { KeyName = "fogendheight", Edit = { type = "Float", min = 0, max = 100000, order = 2 } } )
	self:NetworkVar( "Float", 2, "Density", { KeyName = "density", Edit = { type = "Float", min = 0, max = 3, order = 3 } } )

	self:NetworkVar( "Vector", 0, "FogColor", { KeyName = "fogcolor", Edit = { type = "VectorColor", order = 3 } } )

	if ( SERVER ) then

		-- defaults
		self:SetDepthFade( 1024 )
		self:SetFogEndHeight( 100 )
		self:SetDensity( 0.9 )
		self:SetFogColor( Vector( 0.6, 0.7, 0.8 ) )

	end

end

function ENT:UpdateTransmitState()

	return TRANSMIT_ALWAYS

end
