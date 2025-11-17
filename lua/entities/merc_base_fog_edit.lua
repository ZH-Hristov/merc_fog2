AddCSLuaFile()
DEFINE_BASECLASS( "base_edit" )

ENT.Spawnable = false
ENT.HelpTextColor = Color( 255, 100, 100 )
ENT.HelpTextDistance = 1000000

local valid_contents = { [100679695] = true, [1174421519] = true }
function ENT:TestCollision( startpos, delta, isbox, extents, mask )
	if mask == 4294967295 and input.IsKeyDown( KEY_E ) then properties.OpenEntityMenu( self, {} ) return true end
	if valid_contents[mask] then return true end
end

function ENT:AddHelpText()
    hook.Add("HUDPaint", self, function()
        if self:CreatedByMap() then return end
        local tscr = self:GetPos():ToScreen()
        if not tscr.visible then return end
        if self:GetPos():DistToSqr(LocalPlayer():GetPos()) > self.HelpTextDistance then return end
        draw.SimpleText(self.PrintName or "Uhh whoops?", "TargetID", tscr.x, tscr.y - 40, self.HelpTextColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Press E on me to edit", "TargetID", tscr.x, tscr.y - 20, self.HelpTextColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.RoundedBox( 4, tscr.x - 10, tscr.y - 10, 20, 20, self.HelpTextColor )
    end)
end

function ENT:RemoveHelpText()
    hook.Remove("HUDPaint", self)
end

hook.Add("OnContextMenuOpen", "", function()
    for _, ent in pairs(ents.FindByClass("edit_fog_*")) do
        print(ent)
        ent:AddHelpText()
    end
end)

hook.Add("OnContextMenuClose", "", function()
    for _, ent in pairs(ents.FindByClass("edit_fog_*")) do
        ent:RemoveHelpText()
    end
end)

function ENT:UpdateTransmitState()

	return TRANSMIT_ALWAYS

end

function ENT:KeyValue( key, value )

    if ( self:SetNetworkKeyValue( key, value ) ) then
        return
    end

end

function ENT:AcceptInput( name, activator, caller, data )

	if ( self:SetNetworkVarsFromMapInput( name, data ) ) then
		return true -- Accept the input so the there are no warnings in console with developer 2
	end

end