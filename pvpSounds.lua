--[[ Afterlife Crowd Control — PvP sound paths ]]

AfterlifePvPSoundPaths = AfterlifePvPSoundPaths or {}
local paths = AfterlifePvPSoundPaths
local pvp = "Interface\\AddOns\\Afterlife\\assets\\sounds\\pvp"

-- Killing blow voicepack sounds (play order: firstblood -> dominating -> monsterkill -> killingspree -> unstoppable -> godlike)
paths.killingBlowVoicepack1 = {
	pvp .. "\\voicepack1\\firstblood.ogg",
	pvp .. "\\voicepack1\\dominating.ogg",
	pvp .. "\\voicepack1\\monsterkill.ogg",
	pvp .. "\\voicepack1\\killingspree.ogg",
	pvp .. "\\voicepack1\\unstoppable.ogg",
	pvp .. "\\voicepack1\\godlike.ogg",
}
paths.killingBlowVoicepack2 = {
	pvp .. "\\voicepack2\\firstblood.ogg",
	pvp .. "\\voicepack2\\dominating.ogg",
	pvp .. "\\voicepack2\\monsterkill.ogg",
	pvp .. "\\voicepack2\\killingspree.ogg",
	pvp .. "\\voicepack2\\unstoppable.ogg",
	pvp .. "\\voicepack2\\godlike.ogg",
}
