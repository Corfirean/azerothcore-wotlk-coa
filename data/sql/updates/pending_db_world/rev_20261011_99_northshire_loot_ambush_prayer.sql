DELETE FROM `conditions` WHERE `SourceTypeOrReferenceId` = 4 AND `SourceGroup` IN (2300500, 2300503, 2300504, 2300505);

INSERT INTO `conditions`
(`SourceTypeOrReferenceId`, `SourceGroup`, `SourceEntry`, `SourceId`, `ElseGroup`, `ConditionTypeOrReference`, `ConditionTarget`, `ConditionValue1`, `ConditionValue2`, `ConditionValue3`, `NegativeCondition`, `ErrorType`, `ErrorTextId`, `ScriptName`, `Comment`)
VALUES
(4, 2300500, 559130, 0, 0, 2, 0, 559130, 1, 0, 1, 0, 0, '', 'Lost Page I - withhold the item once the looter already has a copy'),
(4, 2300503, 559131, 0, 0, 2, 0, 559131, 1, 0, 1, 0, 0, '', 'Lost Page II - withhold the item once the looter already has a copy'),
(4, 2300504, 559132, 0, 0, 2, 0, 559132, 1, 0, 1, 0, 0, '', 'Lost Page III - withhold the item once the looter already has a copy'),
(4, 2300505, 559133, 0, 0, 2, 0, 559133, 1, 0, 1, 0, 0, '', 'Lost Page IV - withhold the item once the looter already has a copy');

DELETE FROM `smart_scripts` WHERE `entryorguid` IN (2300500, 2300503, 2300504, 2300505) AND `source_type` = 1;

INSERT INTO `smart_scripts`
(`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`)
VALUES
(2300500, 1, 0, 0, 70, 0, 100, 0, 2, 0, 0, 0, 0, 0, 67, 1, 30000, 30000, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lost Page I - On Loot Opened - Start 30 second spawn cooldown'),
(2300500, 1, 1, 0, 70, 0, 100, 0, 2, 0, 0, 0, 0, 0, 45, 1, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lost Page I - On Loot Opened - Set cooldown flag'),
(2300500, 1, 2, 0, 70, 0, 40, 0, 2, 0, 0, 0, 0, 0, 12, 161711, 7, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lost Page I - On Loot Opened - Summon Living Heresy (40% ambush chance)'),
(2300500, 1, 3, 0, 59, 0, 100, 0, 1, 0, 0, 0, 0, 0, 45, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lost Page I - Cooldown expired - Clear cooldown flag'),
(2300503, 1, 0, 0, 70, 0, 100, 0, 2, 0, 0, 0, 0, 0, 67, 1, 30000, 30000, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lost Page II - On Loot Opened - Start 30 second spawn cooldown'),
(2300503, 1, 1, 0, 70, 0, 100, 0, 2, 0, 0, 0, 0, 0, 45, 1, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lost Page II - On Loot Opened - Set cooldown flag'),
(2300503, 1, 2, 0, 70, 0, 40, 0, 2, 0, 0, 0, 0, 0, 12, 161711, 7, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lost Page II - On Loot Opened - Summon Living Heresy (40% ambush chance)'),
(2300503, 1, 3, 0, 59, 0, 100, 0, 1, 0, 0, 0, 0, 0, 45, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lost Page II - Cooldown expired - Clear cooldown flag'),
(2300504, 1, 0, 0, 70, 0, 100, 0, 2, 0, 0, 0, 0, 0, 67, 1, 30000, 30000, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lost Page III - On Loot Opened - Start 30 second spawn cooldown'),
(2300504, 1, 1, 0, 70, 0, 100, 0, 2, 0, 0, 0, 0, 0, 45, 1, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lost Page III - On Loot Opened - Set cooldown flag'),
(2300504, 1, 2, 0, 70, 0, 40, 0, 2, 0, 0, 0, 0, 0, 12, 161711, 7, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lost Page III - On Loot Opened - Summon Living Heresy (40% ambush chance)'),
(2300504, 1, 3, 0, 59, 0, 100, 0, 1, 0, 0, 0, 0, 0, 45, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lost Page III - Cooldown expired - Clear cooldown flag'),
(2300505, 1, 0, 0, 70, 0, 100, 0, 2, 0, 0, 0, 0, 0, 67, 1, 30000, 30000, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lost Page IV - On Loot Opened - Start 30 second spawn cooldown'),
(2300505, 1, 1, 0, 70, 0, 100, 0, 2, 0, 0, 0, 0, 0, 45, 1, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lost Page IV - On Loot Opened - Set cooldown flag'),
(2300505, 1, 2, 0, 70, 0, 40, 0, 2, 0, 0, 0, 0, 0, 12, 161711, 7, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lost Page IV - On Loot Opened - Summon Living Heresy (40% ambush chance)'),
(2300505, 1, 3, 0, 59, 0, 100, 0, 1, 0, 0, 0, 0, 0, 45, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Lost Page IV - Cooldown expired - Clear cooldown flag');

DELETE FROM `conditions` WHERE `SourceTypeOrReferenceId` = 22 AND `SourceEntry` IN (2300500, 2300503, 2300504, 2300505) AND `SourceId` = 1;

INSERT INTO `conditions`
(`SourceTypeOrReferenceId`, `SourceGroup`, `SourceEntry`, `SourceId`, `ElseGroup`, `ConditionTypeOrReference`, `ConditionTarget`, `ConditionValue1`, `ConditionValue2`, `ConditionValue3`, `NegativeCondition`, `ErrorType`, `ErrorTextId`, `ScriptName`, `Comment`)
VALUES
(22, 1, 2300500, 1, 0, 29, 1, 161711, 20, 0, 1, 0, 0, '', 'Lost Page I - no Living Heresy within 20 yards (id 0)'),
(22, 1, 2300500, 1, 0, 104, 1, 1, 0, 0, 0, 0, 0, '', 'Lost Page I - spawn cooldown flag not set (id 0)'),
(22, 1, 2300500, 1, 0, 2, 0, 559130, 1, 0, 1, 0, 0, '', 'Lost Page I - looter does not already have the page (id 0)'),
(22, 2, 2300500, 1, 0, 29, 1, 161711, 20, 0, 1, 0, 0, '', 'Lost Page I - no Living Heresy within 20 yards (id 1)'),
(22, 2, 2300500, 1, 0, 104, 1, 1, 0, 0, 0, 0, 0, '', 'Lost Page I - spawn cooldown flag not set (id 1)'),
(22, 2, 2300500, 1, 0, 2, 0, 559130, 1, 0, 1, 0, 0, '', 'Lost Page I - looter does not already have the page (id 1)'),
(22, 3, 2300500, 1, 0, 29, 1, 161711, 20, 0, 1, 0, 0, '', 'Lost Page I - no Living Heresy within 20 yards (id 2)'),
(22, 3, 2300500, 1, 0, 2, 0, 559130, 1, 0, 1, 0, 0, '', 'Lost Page I - looter does not already have the page (id 2)'),
(22, 1, 2300503, 1, 0, 29, 1, 161711, 20, 0, 1, 0, 0, '', 'Lost Page II - no Living Heresy within 20 yards (id 0)'),
(22, 1, 2300503, 1, 0, 104, 1, 1, 0, 0, 0, 0, 0, '', 'Lost Page II - spawn cooldown flag not set (id 0)'),
(22, 1, 2300503, 1, 0, 2, 0, 559131, 1, 0, 1, 0, 0, '', 'Lost Page II - looter does not already have the page (id 0)'),
(22, 2, 2300503, 1, 0, 29, 1, 161711, 20, 0, 1, 0, 0, '', 'Lost Page II - no Living Heresy within 20 yards (id 1)'),
(22, 2, 2300503, 1, 0, 104, 1, 1, 0, 0, 0, 0, 0, '', 'Lost Page II - spawn cooldown flag not set (id 1)'),
(22, 2, 2300503, 1, 0, 2, 0, 559131, 1, 0, 1, 0, 0, '', 'Lost Page II - looter does not already have the page (id 1)'),
(22, 3, 2300503, 1, 0, 29, 1, 161711, 20, 0, 1, 0, 0, '', 'Lost Page II - no Living Heresy within 20 yards (id 2)'),
(22, 3, 2300503, 1, 0, 2, 0, 559131, 1, 0, 1, 0, 0, '', 'Lost Page II - looter does not already have the page (id 2)'),
(22, 1, 2300504, 1, 0, 29, 1, 161711, 20, 0, 1, 0, 0, '', 'Lost Page III - no Living Heresy within 20 yards (id 0)'),
(22, 1, 2300504, 1, 0, 104, 1, 1, 0, 0, 0, 0, 0, '', 'Lost Page III - spawn cooldown flag not set (id 0)'),
(22, 1, 2300504, 1, 0, 2, 0, 559132, 1, 0, 1, 0, 0, '', 'Lost Page III - looter does not already have the page (id 0)'),
(22, 2, 2300504, 1, 0, 29, 1, 161711, 20, 0, 1, 0, 0, '', 'Lost Page III - no Living Heresy within 20 yards (id 1)'),
(22, 2, 2300504, 1, 0, 104, 1, 1, 0, 0, 0, 0, 0, '', 'Lost Page III - spawn cooldown flag not set (id 1)'),
(22, 2, 2300504, 1, 0, 2, 0, 559132, 1, 0, 1, 0, 0, '', 'Lost Page III - looter does not already have the page (id 1)'),
(22, 3, 2300504, 1, 0, 29, 1, 161711, 20, 0, 1, 0, 0, '', 'Lost Page III - no Living Heresy within 20 yards (id 2)'),
(22, 3, 2300504, 1, 0, 2, 0, 559132, 1, 0, 1, 0, 0, '', 'Lost Page III - looter does not already have the page (id 2)'),
(22, 1, 2300505, 1, 0, 29, 1, 161711, 20, 0, 1, 0, 0, '', 'Lost Page IV - no Living Heresy within 20 yards (id 0)'),
(22, 1, 2300505, 1, 0, 104, 1, 1, 0, 0, 0, 0, 0, '', 'Lost Page IV - spawn cooldown flag not set (id 0)'),
(22, 1, 2300505, 1, 0, 2, 0, 559133, 1, 0, 1, 0, 0, '', 'Lost Page IV - looter does not already have the page (id 0)'),
(22, 2, 2300505, 1, 0, 29, 1, 161711, 20, 0, 1, 0, 0, '', 'Lost Page IV - no Living Heresy within 20 yards (id 1)'),
(22, 2, 2300505, 1, 0, 104, 1, 1, 0, 0, 0, 0, 0, '', 'Lost Page IV - spawn cooldown flag not set (id 1)'),
(22, 2, 2300505, 1, 0, 2, 0, 559133, 1, 0, 1, 0, 0, '', 'Lost Page IV - looter does not already have the page (id 1)'),
(22, 3, 2300505, 1, 0, 29, 1, 161711, 20, 0, 1, 0, 0, '', 'Lost Page IV - no Living Heresy within 20 yards (id 2)'),
(22, 3, 2300505, 1, 0, 2, 0, 559133, 1, 0, 1, 0, 0, '', 'Lost Page IV - looter does not already have the page (id 2)');

DELETE FROM `conditions` WHERE `SourceTypeOrReferenceId` = 22 AND `SourceEntry` IN (2300520, 2300521, 2300522, 2300523) AND `SourceId` = 1;

INSERT INTO `conditions`
(`SourceTypeOrReferenceId`, `SourceGroup`, `SourceEntry`, `SourceId`, `ElseGroup`, `ConditionTypeOrReference`, `ConditionTarget`, `ConditionValue1`, `ConditionValue2`, `ConditionValue3`, `NegativeCondition`, `ErrorType`, `ErrorTextId`, `ScriptName`, `Comment`)
VALUES
(22, 1, 2300520, 1, 0, 47, 0, 1660003, 8, 0, 0, 0, 0, '', 'Abbess Journal - the prayer only casts while quest 1660003 is in progress'),
(22, 1, 2300520, 1, 0, 48, 0, 1660003, 0, 1, 1, 0, 0, '', 'Abbess Journal - only while its own objective (slot 0) is not yet complete'),
(22, 1, 2300521, 1, 0, 47, 0, 1660003, 8, 0, 0, 0, 0, '', 'Abbess Staff - the prayer only casts while quest 1660003 is in progress'),
(22, 1, 2300521, 1, 0, 48, 0, 1660003, 1, 1, 1, 0, 0, '', 'Abbess Staff - only while its own objective (slot 1) is not yet complete'),
(22, 1, 2300522, 1, 0, 47, 0, 1660003, 8, 0, 0, 0, 0, '', 'Heretical Idol - the prayer only casts while quest 1660003 is in progress'),
(22, 1, 2300522, 1, 0, 48, 0, 1660003, 2, 1, 1, 0, 0, '', 'Heretical Idol - only while its own objective (slot 2) is not yet complete'),
(22, 1, 2300523, 1, 0, 47, 0, 1660003, 8, 0, 0, 0, 0, '', 'Jewel - the prayer only casts while quest 1660003 is in progress'),
(22, 1, 2300523, 1, 0, 48, 0, 1660003, 3, 1, 1, 0, 0, '', 'Jewel - only while its own objective (slot 3) is not yet complete');

DELETE FROM `smart_scripts` WHERE `entryorguid` IN (2300579, 2300546) AND `source_type` = 1;

INSERT INTO `smart_scripts`
(`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`)
VALUES
(2300579, 1, 0, 0, 8, 0, 100, 0, 267031, 0, 0, 0, 0, 0, 33, 162940, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 'Kobold Warren - Destroy completed: credit 162940'),
(2300579, 1, 1, 0, 8, 0, 75, 0, 267031, 0, 0, 0, 0, 0, 12, 162915, 4, 30000, 2, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Kobold Warren - Destroy completed: 75% Kobold Prospector ambush at the warren'),
(2300579, 1, 2, 0, 8, 0, 100, 0, 267031, 0, 0, 0, 0, 0, 41, 0, 60, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Kobold Warren - destroyed, back in 60 s'),
(2300546, 1, 0, 0, 8, 0, 100, 0, 256702, 0, 0, 0, 0, 0, 33, 162920, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 'Mirror Shard - Inspecting completed: credit 162920'),
(2300546, 1, 1, 0, 8, 0, 40, 0, 256702, 0, 0, 0, 0, 0, 12, 162919, 4, 30000, 2, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Mirror Shard - Inspecting completed: Curse Shard at the shard (40% ambush chance)'),
(2300546, 1, 2, 0, 8, 0, 100, 0, 256702, 0, 0, 0, 0, 0, 41, 0, 60, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Mirror Shard - inspected, back in 60 s');
