-- Local server: Esteria native appearance controls
-- Esteria's extra options (EsteriaAppearance.dll, "EA_" calls of CycleCharCustomization), only for the Esteria races
-- (our ids 66+). Every other race keeps our customization exactly as it was. Ported from Esteria's CharacterCreate.lua.
do
	local ESTERIA = {[66] = 46, [67] = 47, [68] = 48, [69] = 49, [70] = 51, [71] = 50, [72] = 53, [77] = 52, [74] = 20}
	local NAMED = {[20] = true, [46] = true, [48] = true, [49] = true, [50] = true, [51] = true}
	local RANDOM = NAMED
	local LABELS = {"Skin Color", "Face", "Hair Style", "Hair Color", "Eye Color", "Eyebrow Style",
		"Feathers", "Feather Color", "Facial Hair", "Ears"}
	local MECH_LABELS = {"Skin Color", "Face", "Hair Style", "Hair Color", "Facial Hair", "Arm Upgrade", "Leg Upgrade",
		"Modification", "Eye Color", "Paint", "Eyesight", "Eye Style"}
	local MAX = 29
	local saved, wasActive, lastRace

	local function EsteriaRace()
		local button = CharacterCreate.selectedRace and _G["CharCreateRaceButton" .. CharacterCreate.selectedRace]
		return button and ESTERIA[button.bonusRaceID or 0]
	end

	local function Get(i)
		local ok, value, count, label = pcall(CycleCharCustomization, "EA_GET", i)
		if ok then
			return value, count, label
		end
	end

	local function Refresh()
		local first = CharacterCustomizationButtonFrame1
		if not first then
			return
		end
		if not saved then
			saved = {}
			for i = 1, 5 do
				local frame = _G["CharacterCustomizationButtonFrame" .. i]
				if frame and frame:GetNumPoints() > 0 then
					saved[i] = {frame:GetPoint(1)}
				end
			end
		end
		local parent = first:GetParent()
		for i = 6, MAX do
			if not _G["CharacterCustomizationButtonFrame" .. i] then
				local frame = CreateFrame("Frame", "CharacterCustomizationButtonFrame" .. i, parent,
					"CharacterCustomizationFrameTemplate")
				frame:SetID(i)
				frame:Hide()
			end
		end
		local race = EsteriaRace()
		if race and race ~= lastRace then
			-- their default choices are bald: start from a random look (as Esteria's screen does), else apply the
			-- native hair mesh by stepping the hair style once and back
			if RANDOM[race] then
				pcall(CycleCharCustomization, "EA_RANDOM", 1)
			else
				pcall(CycleCharCustomization, "EA_CYCLE", 3, 1)
				pcall(CycleCharCustomization, "EA_CYCLE", 3, -1)
			end
		end
		lastRace = race
		if race and saved[1] then
			wasActive = true
			local point, relative, relativePoint, x, y = unpack(saved[1])
			local row = 0
			for i = 1, MAX do
				local frame = _G["CharacterCustomizationButtonFrame" .. i]
				local value, count, label = Get(i)
				if count and count > 1 then
					local column = math.floor(row / 12)
					frame:ClearAllPoints()
					frame:SetPoint(point, relative, relativePoint, x - column * 260, y - (row % 12) * 36)
					local name = NAMED[race] and (label or "") or race == 47 and MECH_LABELS[i] or LABELS[i] or ""
					if (race == 48 or race == 49) and label == "Belt" then
						_G["CharacterCustomizationButtonFrame" .. i .. "Text"]:SetText(name .. (value == 0 and "  None" or "  Gem"))
					else
						_G["CharacterCustomizationButtonFrame" .. i .. "Text"]:SetText(name .. "  " .. (value + 1) .. "/" .. count)
					end
					if first:IsShown() or i == 1 then
						frame:Show()
					end
					row = row + 1
				else
					frame:Hide()
				end
			end
		elseif wasActive then
			wasActive = nil
			for i = 6, MAX do
				_G["CharacterCustomizationButtonFrame" .. i]:Hide()
			end
			for i = 1, 5 do
				local frame = _G["CharacterCustomizationButtonFrame" .. i]
				if frame and saved[i] then
					frame:ClearAllPoints()
					frame:SetPoint(unpack(saved[i]))
				end
			end
			CharacterCustomizationButtonFrame1Text:SetText(CHAR_CUSTOMIZATION1_DESC)
			CharacterCustomizationButtonFrame2Text:SetText(CHAR_CUSTOMIZATION2_DESC)
			CharacterCreate_UpdateHairCustomization()
		end
	end

	local left, right, randomize = CharacterCustomization_Left, CharacterCustomization_Right, CharacterCreate_Randomize
	function CharacterCustomization_Left(id)
		if EsteriaRace() then
			PlaySound("gsCharacterCreationLook")
			pcall(CycleCharCustomization, "EA_CYCLE", id, -1)
			Refresh()
		else
			left(id)
		end
	end
	function CharacterCustomization_Right(id)
		if EsteriaRace() then
			PlaySound("gsCharacterCreationLook")
			pcall(CycleCharCustomization, "EA_CYCLE", id, 1)
			Refresh()
		else
			right(id)
		end
	end
	function CharacterCreate_Randomize()
		local race = EsteriaRace()
		if race and RANDOM[race] then
			PlaySound("gsCharacterCreationLook")
			pcall(CycleCharCustomization, "EA_RANDOM", 1)
			Refresh()
		else
			randomize()
		end
	end

	-- Highmountain keeps its real size: the Customize camera (set again on every option) steps back for it
	local ZOOM = {[46] = 1.3}
	local zoomAt
	if SetFaceCustomizeCamera then
		local setFace = SetFaceCustomizeCamera
		function SetFaceCustomizeCamera(...)
			local a, b, c = setFace(...)
			if ZOOM[EsteriaRace() or 0] then
				zoomAt = 0.35
			end
			return a, b, c
		end
	end
	local function Zoom(elapsed)
		if not zoomAt then
			return
		end
		zoomAt = zoomAt - elapsed
		if zoomAt > 0 then
			return
		end
		zoomAt = nil
		local k = ZOOM[EsteriaRace() or 0]
		if k and C_CharacterCreate and C_CharacterCreate.GetCameraPosition then
			pcall(function()
				local x, y, z = C_CharacterCreate.GetCameraPosition()
				C_CharacterCreate.SetCameraPosition(x * k, y * k, z * (1 + (k - 1) * 0.6))
			end)
		end
	end

	local ticker = CreateFrame("Frame")
	ticker:SetScript("OnUpdate", function(self, elapsed)
		Zoom(elapsed)
		self.elapsed = (self.elapsed or 0) + elapsed
		if self.elapsed > 0.15 then
			self.elapsed = 0
			if CharacterCreate and CharacterCreate:IsShown() then
				Refresh()
			end
		end
	end)
end
