AddCSLuaFile()
DEFINE_BASECLASS( "merc_base_fog_edit" )

ENT.Spawnable = true
ENT.AdminOnly = true

ENT.PrintName = "Cubemap Fog Editor"
ENT.Category = "Fog 2"
ENT.Information = "Right click on this entity via the context menu (hold C by default) and select 'Edit Properties' to edit the fog."
ENT.Material = Material("merccubemapfog")

local mat_SetFloat = FindMetaTable( "IMaterial" ).SetFloat

ENT.Size = 16
ENT.Offsets = {
    up = Vector(0, 0, 8),
    dn = Vector(0, 0, -8),
    ft = Vector(0, 8, 0),
    bk = Vector(0, -8, 0),
    rt = Vector(8, 0, 0),
    lf = Vector(-8, 0, 0)
}

ENT.Normals = {
    up = Vector(0, 0, -1),
    dn = Vector(0, 0, 1),
    ft = Vector(0, -1, 0),
    bk = Vector(0, 1, 0),
    rt = Vector(-1, 0, 0),
    lf = Vector(1, 0, 0)
}

if CLIENT then
    ENT.sky_rt = GetRenderTargetEx("_rt_sky2d", ScrW()*0.05, ScrH()*0.05,
        RT_SIZE_HDR,
        MATERIAL_RT_DEPTH_NONE,
        bit.bor(4,8,16,512),
        0,
        IMAGE_FORMAT_RGB888
    )
end

function ENT:SpawnFunction( ply, tr, className )

    if GetConVar("sv_skyname"):GetString() == "painted" then
        ply:ChatPrint( "Cubemap fog does not work with the 'painted' skybox!" )
        ply:ChatPrint( "You can change the sky to a traditional skybox with sv_skyname" )
        ply:ChatPrint( "For example - 'sv_skyname sky_day02_03'" )
        return
    end

	if not tr.Hit then return end
	
	local SpawnPos = tr.HitPos + tr.HitNormal * 10
	local SpawnAng = ply:EyeAngles()
	SpawnAng.p = 0
	SpawnAng.y = SpawnAng.y + 180
	
	local ent = ents.Create( ClassName )
	ent:SetPos( SpawnPos )
	ent:SetAngles( SpawnAng )
	ent:Spawn()
	ent:Activate()
	
	return ent

end

function ENT:Draw2DSkybox()
    cam.Start3D(vector_origin)
    render.PushRenderTarget( self.sky_rt )
    render.SetMaterial(self.upMat)
    render.DrawQuadEasy( vector_origin + self.Offsets.up, self.Normals.up, self.Size, self.Size )
    render.SetMaterial(self.dnMat)
    render.DrawQuadEasy( vector_origin + self.Offsets.dn, self.Normals.dn, self.Size, self.Size )
    
    render.SetMaterial(self.rtMat)
    render.DrawQuadEasy( vector_origin + self.Offsets.rt, self.Normals.rt, self.Size, self.Size, nil, 180)
    render.SetMaterial(self.lfMat)
    render.DrawQuadEasy( vector_origin + self.Offsets.lf, self.Normals.lf, self.Size, self.Size, nil, 180)
    render.SetMaterial(self.ftMat)
    render.DrawQuadEasy( vector_origin + self.Offsets.bk, self.Normals.bk, self.Size, self.Size, nil, 180)
    render.SetMaterial(self.bkMat)
    render.DrawQuadEasy( vector_origin + self.Offsets.ft, self.Normals.ft, self.Size, self.Size, nil, 180)
    render.PopRenderTarget()
    cam.End3D()
end

function ENT:Update2DSkybox()
    self.skyName = GetConVar("sv_skyname"):GetString()

    self.upMat = Material("skybox/"..self.skyName.."up")
    self.rtMat = Material("skybox/"..self.skyName.."rt")
    self.lfMat = Material("skybox/"..self.skyName.."lf")
    self.ftMat = Material("skybox/"..self.skyName.."ft")
    self.bkMat = Material("skybox/"..self.skyName.."bk")
    self.dnMat = Material("skybox/"..self.skyName.."dn")
end

function ENT:Initialize()

	BaseClass.Initialize( self )

	self:SetMaterial( "gmod/edit_fog" )
    self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	self:EnableCustomCollisions()

	if ( CLIENT ) then

        self:Update2DSkybox()

        hook.Add( "PreRender", self, self.Draw2DSkybox )
		hook.Add( "RenderScreenspaceEffects", self, self.SetupCubemapFog )

	end

end

function ENT:SetupCubemapFog()

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
    mat_SetFloat( mat, "$c0_w", self:GetBlurRadius() )
	mat_SetFloat( mat, "$c2_x", LocalPlayer():EyePos().x )
	mat_SetFloat( mat, "$c2_y", LocalPlayer():EyePos().y )
	mat_SetFloat( mat, "$c2_z", LocalPlayer():EyePos().z )
    mat_SetFloat( mat, "$c3_x", ScrW() * 0.5 ) -- skybox width
    mat_SetFloat( mat, "$c3_y", ScrH() * 0.5 ) -- skybox height
    mat_SetFloat( mat, "$c3_z", self:GetSkyBlend() ) -- skybox blend factor

	render.SetMaterial( mat )
	render.DrawScreenQuad()

end

function ENT:SetupDataTables()

	self:NetworkVar( "Float", 0, "FogStart", { KeyName = "fogstart", Edit = { type = "Float", min = 0, max = 1000000, order = 1 } } )
	self:NetworkVar( "Float", 1, "FogEnd", { KeyName = "fogend", Edit = { type = "Float", min = 0, max = 1000000, order = 2 } } )
	self:NetworkVar( "Float", 2, "Density", { KeyName = "density", Edit = { type = "Float", min = 0, max = 10, order = 3 } } )
    self:NetworkVar( "Float", 3, "BlurRadius", { KeyName = "blurradius", Edit = { type = "Float", min = 0, max = 100, order = 4 } } )
    self:NetworkVar( "Float", 4, "SkyBlend", { KeyName = "skyblend", Edit = { type = "Float", min = 0, max = 1, order = 5 } } )

	self:NetworkVar( "Vector", 0, "FogColor", { KeyName = "fogcolor", Edit = { type = "VectorColor", order = 3 } } )

	if ( SERVER ) then

		-- defaults
		self:SetFogStart( 1000 )
		self:SetFogEnd( 5000 )
		self:SetDensity( 2 )
		self:SetFogColor( Vector( 1, 1, 1 ) )
        self:SetBlurRadius( 6 )
        self:SetSkyBlend( 1 )

	end

end