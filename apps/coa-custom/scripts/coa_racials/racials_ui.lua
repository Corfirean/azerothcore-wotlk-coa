-- Local server: CoA racials of the added races
-- CHAR_CREATE_COA_RACIALS (gen_coa_racials.py): race id -> {{active name, icon, text}, {passive name, icon, text}}.
-- The racial list of an added race (12 and up) shows its two CoA racials instead of the borrowed ones.
do
	local function RacialLines(raceID)
		local racials = CHAR_CREATE_COA_RACIALS and CHAR_CREATE_COA_RACIALS[raceID or 0]
		if not racials then
			return nil
		end
		local text = ""
		for i, racial in ipairs(racials) do
			text = text .. "|TInterface\Icons\\" .. racial[2] .. ":24:24:0:0|t |cffffd100" .. racial[1] .. "|r" ..
				(i == 1 and " (active)" or " (passive)") .. "|n" .. racial[3] .. "|n|n"
		end
		return text
	end
	if CHAR_CREATE_RACE_BONUS then
		for raceID in pairs(CHAR_CREATE_COA_RACIALS or {}) do
			CHAR_CREATE_RACE_BONUS[raceID] = nil              -- the old borrowed racial line
		end
	end
	local setCharacterRace = SetCharacterRace
	function SetCharacterRace(id, ...)
		local a, b, c, d, e = setCharacterRace(id, ...)
		local button = _G["CharCreateRaceButton" .. (id or CharacterCreate.selectedRace or 0)]
		local text = RacialLines(button and button.bonusRaceID)
		local bullets = CharCreateRaceInfoFrame and CharCreateRaceInfoFrame.scrollFrame.scrollChild.bulletText
		if text and bullets then
			bullets:SetText(text)
		end
		return a, b, c, d, e
	end
end
-- end CoA racials of the added races
