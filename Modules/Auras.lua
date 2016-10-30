local Emphasize = Grid:GetModule("GridStatus"):GetModule("GridStatusEmphasize")
local GridRoster = Grid:GetModule("GridRoster")
local GridFrame = Grid:GetModule("GridFrame")

local GridStatusEmphasize_Auras = Emphasize:NewModule("GridStatusEmphasize_Auras", "AceEvent-3.0", "AceTimer-3.0")

-- upvalues
local UnitDebuff = UnitDebuff
local UnitBuff = UnitBuff
local UnitGUID = UnitGUID

-- data
local settings

GridStatusEmphasize_Auras.defaultDB = {
	range = true,
	color = { r = 1, g = 1, b = 1 },
	auras = { },
}

local options = {
	["color"] = {
		order = 1,
		type = "color",
		hasAlpha = false,
		name = "Global color",
		desc = "Changing this color changes the color of all the auras",
		get = function ()
			local color = GridStatusEmphasize_Auras.db.profile.color
			return color.r, color.g, color.b
		end,
		set = function (_, r, g, b)
			local color = GridStatusEmphasize_Auras.db.profile.color
			color.r = r
			color.g = g
			color.b = b
			for i, aura in ipairs(settings.auras) do
				aura.color.r = r
				aura.color.g = g
				aura.color.b = b				
			end
		end,
	},
	["range"] = {
		order = 2,
		type = "toggle",
		width = "full",
		name = "Range filter",
		desc = "Don't emphasize units out of range",
		get = function () return GridStatusEmphasize_Auras.db.profile.range end,
		set = function (_, v) GridStatusEmphasize_Auras.db.profile.range = v end,
	},
	["add"] = {
		order = 3,
		type = "input",
		width = "double",
		name = "Add new aura (name or spellid)",
		set = function(_, v) GridStatusEmphasize_Auras:AddAura(v) end,
	},
	["auras"] = {
		order = 4,
		type = "group",
		name = "Auras",
		inline = true,
		args = { },
	}
}

function GridStatusEmphasize_Auras:AddAura(name)
  local updateRequired = false
	-- check for duplicates
	for i, aura in ipairs(settings.auras) do
		if aura.name == name then
			return
		end
	end
	
	-- add	
	local aura = {
		name = name,
		priority = 90,
		color = { r = settings.color.r, g = settings.color.g, b = settings.color.b },
    stacks = {
      enabled = false,
      threshold = 1,
      fewerThan = false
    },
    timeRemaining = {
      enabled = false,
      longerThan = false,
      threshold = 5
    },
	}
	
	if tonumber(name) and GetSpellInfo(name) then
		aura.spellid = tonumber(name)
		aura.name = GetSpellInfo(name)
	end
	
	table.insert(settings.auras, aura)
	
	self:UpdateOptions()
	self:UpdateAll()
end

function GridStatusEmphasize_Auras:RemoveAura(index)
	Emphasize:DeemphasizeAllUnits(settings.auras[index].name)
	table.remove(settings.auras, index)
	
	self:UpdateOptions()
	self:UpdateAll()
end

function GridStatusEmphasize_Auras:UpdateOptions()
	options.auras.args = { }
	
	
	for i, aura in ipairs(settings.auras) do
    if not aura.stacks then
      aura.stacks = {
        enabled = false,
        threshold = 1,
        fewerThan = false,
      }    
    end
    if not aura.timeRemaining then
      aura.timeRemaining = {
        enabled = false,
        longerThan = false,
        threshold = 5,
      }
    end
		--[[
		options.auras.args[aura.name .. i .. "_remove"] = {
			order = aura.name:byte(1) * 0xff + aura.name:byte(2),
			type = "execute",
			width = "double",
			name = aura.name,
			desc = "Remove " .. aura.name,
			func = function() return self:RemoveAura(i) end,
		}
		]]
		
		local _, _, icon = GetSpellInfo(aura.spellid or aura.name)
		local name
		if icon then
			name = string.format("|T%s:0|t %s", icon, aura.name)
		else
			name = aura.name
		end
		
		if aura.spellid then
			name = name .. string.format(" (%i)", aura.spellid)
		end
    
		options.auras.args[aura.name .. i] = {
			order = i,
      --order = string.byte(aura.name, 1, 1) * 0xff + string.byte(aura.name, 2, 2),
			type = "group",
			inline = true,
			name = name,
			args = {
				["color"] = {
					order = 1,
					type = "color",
					hasAlpha = false,
					name = "Color",
					get = function ()
						local color = aura.color
						return color.r, color.g, color.b
					end,
					set = function (_, r, g, b)
						local color = aura.color
						color.r = r
						color.g = g
						color.b = b
						self:UpdateAll()
					end,
				},
				["priority"] = {
					order = 2,
					type = "range",
					max = 99,
					min = 0,
					step = 1,
					name = "Priority",
					get = function() return aura.priority end,
					set = function(_, v)
						aura.priority = v
						self:UpdateAll()
					end,
				},
        ["timeRemaining"] = {
          order = 3,
          type = "group",
          inline = true,
          name = "Time Remaining",
          args = {
            ["enableTimeRemaining"] = {
              order = 1,
              type = "toggle",
              name = "Enabled",
              desc = "Emphasize based on time remaining.",
              get = function() return aura.timeRemaining.enabled end,
              set = function(_, v)
                aura.timeRemaining.enabled = not aura.timeRemaining.enabled
                self:UpdateAll()
              end,
            },
            ["longerThan"] = {
              order = 2,
              type = "toggle",
              name = "'Longer Than' Logic",
              desc = "If checked, will emphasize when time remaining is equal to or LONGER than time threshold.",
              get = function() return aura.timeRemaining.longerThan end,
              set = function(_, v)
                aura.timeRemaining.longerThan = not aura.timeRemaining.longerThan
                self:UpdateAll()
              end,
            },
            ["timeRemaining"] = {
              order = 3,
              type = "range",
              min = 0,          
              max = 30,
              step = 0.1,
              name = "Time Threshold",
              desc = "Time remaining, in seconds, at which to trigger emphasis.",
              get = function() return aura.timeRemaining.threshold end,
              set = function(_, v)
                aura.timeRemaining.threshold = v
                self:UpdateAll()
              end,
            },
          },
        },
        ["stacks"] = {
          order = 4,
          type = "group",
          inline = true,
          name = "Stacks",
          args = {
            ["enableStacks"] = {
              order = 5,
              type = "toggle",
              name = "Enabled",
              desc = "Emphasize based on stack size.",
              get = function() return aura.stacks.enabled end,
              set = function(_, v)
                aura.stacks.enabled = not aura.stacks.enabled
                self:UpdateAll()
              end,
            },
            ["fewerThanStacks"] = {
              order = 6,
              type = "toggle",
              name = "'Fewer Than' Logic",
              desc = "If checked, will emphasize when aura stack size is equal to or FEWER than stack threshold.",
              get = function() return aura.stacks.fewerThan end,
              set = function(_, v)
                aura.stacks.fewerThan = not aura.stacks.fewerThan
                self:UpdateAll()
              end,
            },
            ["stacks"] = {
              order = 7,
              type = "range",
              min = 1,          
              max = 30,
              step = 1,
              name = "Stack Threshold",
              desc = "Number of stacks to trigger threshold.",
              get = function() return aura.stacks.threshold end,
              set = function(_, v)
                aura.stacks.threshold = v
                self:UpdateAll()
              end,
            },
          },
        },
				["remove"] = {
					order = 20,
					type = "execute",
					width = "double",
					name = "Remove " .. aura.name,
					func = function() return self:RemoveAura(i) end,
				},
			}
		}
	end
end

function GridStatusEmphasize_Auras:OnInitialize()
	self.super.OnInitialize(self)
	
	self:RegisterOptions("Auras", options)
	settings = self.db.profile

	-- convert auras from old format
	for i, aura in ipairs(settings.auras) do
		if type(aura) == "string" then
			local newaura = {
				name = aura,
				priority = 90,
				color = { r = 1, g = 1, b = 1 }
			}
			settings.auras[i] = newaura
		end
	end

	self:RegisterEvent("Grid_UnitJoined")
  
  self.updateTimer = self:ScheduleRepeatingTimer('UpdateAllUnits', 0.1)
	
	self:UpdateOptions()
end

function GridStatusEmphasize_Auras:Grid_UnitJoined(event, guid, unitid)
	self:UpdateUnit("Grid_UnitJoined", unitid)
end

function GridStatusEmphasize_Auras:UpdateAll()
	Emphasize:Pause()
	
	for _, aura in ipairs(settings.auras) do
		Emphasize:DeemphasizeAllUnits(aura.name)
	end
	
	for guid, unitid in GridRoster:IterateRoster() do
		self:ScanUnit(guid, unitid)
	end
	
	Emphasize:Resume()
end

function GridStatusEmphasize_Auras:UpdateAllUnits()
	for guid, unitid in GridRoster:IterateRoster() do
    self:ScanUnit(guid, unitid)
	end
end

function GridStatusEmphasize_Auras:UpdateUnit(guid, unitID)
	unitguid = unitguid or UnitGUID(unitid)
	if not GridRoster:IsGUIDInRaid(unitguid) then
		return
	end
	
	for _, aura in ipairs(settings.auras) do
		if self:ShouldEmphasize(unitid, aura) then
			Emphasize:EmphasizeUnit(unitguid, aura.name, aura.priority, aura.color)
		else
			Emphasize:DeemphasizeUnit(unitguid, aura.name)
		end
	end  
end

function GridStatusEmphasize_Auras:ShouldEmphasize(unit, aura)
  if not aura or not aura.name then return end

  local name, _, _, stack, debuffType, duration, expirationTime, unitCaster, _, _, spellid = UnitDebuff(unit, aura.name)		
		
  if not name then
    name, _, _, stack, debuffType, duration, expirationTime, unitCaster, _, _, spellid = UnitBuff(unit, aura.name)
  end
      
  -- No name, aura not found on unit.
  if not name then
    return
  end
  -- Not in range.
  if not (not settings.range or UnitInRange(unit)) then
    return
  end
  -- Not a valid spellId.
  if not (not aura.spellid or aura.spellid == spellid) then
    return
  end
  -- Stacks.
  if aura.stacks and aura.stacks.enabled then
    if stack == 0 then stack = 1 end
    if aura.stacks.fewerThan then
      if stack > aura.stacks.threshold then
        return
      end
    else
      if stack < aura.stacks.threshold then
        return
      end
    end
  end  
  -- Time remaining.
  if aura.timeRemaining and aura.timeRemaining.enabled then
    local timeRemaining = expirationTime - GetTime()
    if aura.timeRemaining.longerThan then
      if timeRemaining < aura.timeRemaining.threshold then
        return
      end    
    else
      if timeRemaining > aura.timeRemaining.threshold then
        return
      end    
    end
  end
  
  return true
end

function GridStatusEmphasize_Auras:ScanUnit(guid, unitid)
	guid = guid or UnitGUID(unitid)
	if not GridRoster:IsGUIDInRaid(guid) then
		return
	end
	
	for _, aura in ipairs(settings.auras) do
    -- Get emphasized status.
    local emphasized = Emphasize:IsEmphasized(guid, aura.name)  
    -- Should be emphasized.
    local shouldEmphasize = self:ShouldEmphasize(unitid, aura)
    -- If should differs from current, update
    if shouldEmphasize ~= emphasized then
      if shouldEmphasize then
        Emphasize:EmphasizeUnit(guid, aura.name, aura.priority, aura.color)
      else
        Emphasize:DeemphasizeUnit(guid, aura.name)
      end
    end
	end
end
