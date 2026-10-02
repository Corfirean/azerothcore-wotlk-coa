-- Beauregard Boneglitter, the enchanter (601015): template, model, gear, greeting and one placement per capital.
INSERT INTO `creature_template` (`entry`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `faction`, `npcflag`,
`speed_walk`, `speed_run`, `unit_class`, `unit_flags`, `type`, `type_flags`, `RegenHealth`, `flags_extra`, `ScriptName`)
VALUES
(601015, 'Beauregard Boneglitter', 'Enchantments', 'Speak', 0, 80, 80, 35, 1, 1, 1.14286, 1, 2, 7, 0, 1, 2, 'npc_enchantment')
ON DUPLICATE KEY UPDATE `name` = VALUES(`name`), `subname` = VALUES(`subname`), `IconName` = VALUES(`IconName`),
`minlevel` = VALUES(`minlevel`), `maxlevel` = VALUES(`maxlevel`), `faction` = VALUES(`faction`),
`npcflag` = VALUES(`npcflag`), `unit_flags` = VALUES(`unit_flags`), `flags_extra` = VALUES(`flags_extra`),
`ScriptName` = VALUES(`ScriptName`);

DELETE FROM `creature_template_model` WHERE `CreatureID` = 601015;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`) VALUES
(601015, 0, 9353, 1, 1);

DELETE FROM `creature_equip_template` WHERE `CreatureID` = 601015 AND `ID` = 1;
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`) VALUES (601015, 1, 11343, 0, 0);

DELETE FROM `npc_text` WHERE `ID` = 601015;
INSERT INTO `npc_text` (`ID`, `text0_0`, `Probability0`) VALUES
(601015, 'Good day $N. Beauregard Boneglitter at your service. I offer a vast array of gear enchantments for the aspiring adventurer.', 1);

-- A few steps from the War Games organizer, who already stands on a known good spot in each capital.
DELETE FROM `creature` WHERE `guid` IN (7905410, 7905411);
INSERT INTO `creature` (`guid`, `id`, `map`, `spawnMask`, `phaseMask`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `curhealth`, `curmana`, `MovementType`, `Comment`) VALUES
(7905410, 601015, 1, 1, 1, 1505, -4430, 22.8431, 1.57, 300, 0, 42, 0, 0, 'Beauregard Boneglitter - Orgrimmar'),
(7905411, 601015, 0, 1, 1, -8815, 619.522, 94.979, 2.12171, 300, 0, 42, 0, 0, 'Beauregard Boneglitter - Stormwind');
