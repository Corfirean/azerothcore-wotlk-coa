-- Thermal Anvil (1777028) did nothing: it was bound to item_ethereal_set_cache, whose only row pointed at a missing item
-- (425924), and its summon spell 9931265 uses two gameobjects that had no template. Values from the client's own cache (#7447).
UPDATE `item_template` SET `ScriptName` = '' WHERE `entry` = 1777028 AND `ScriptName` = 'item_ethereal_set_cache';
DELETE FROM `ethereal_bazaar_set_cache` WHERE `cache_item` = 1777028;

INSERT INTO `gameobject_template` (`entry`, `type`, `displayId`, `name`, `IconName`, `castBarCaption`, `size`, `Data0`, `Data1`, `Data2`, `Data3`, `Data4`, `Data5`, `Data6`, `Data7`, `Data8`, `Data9`, `Data10`, `Data11`, `Data12`, `Data13`, `Data14`, `Data15`, `Data16`, `Data17`, `Data18`, `Data19`, `Data20`, `Data21`, `Data22`, `Data23`)
-- Forge (spell focus 3) and Anvil (spell focus 1), 20 yards
SELECT 2201000, 8, 137975, 'Thermal Anvil', '', '', 1.0, 3, 20, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
UNION ALL
SELECT 2202000, 8, 1287, 'Thermal Anvil', '', '', 0.2, 1, 20, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
ON DUPLICATE KEY UPDATE
`type` = VALUES(`type`),
`displayId` = VALUES(`displayId`),
`name` = VALUES(`name`),
`IconName` = VALUES(`IconName`),
`castBarCaption` = VALUES(`castBarCaption`),
`size` = VALUES(`size`),
`Data0` = VALUES(`Data0`),
`Data1` = VALUES(`Data1`),
`Data2` = VALUES(`Data2`),
`Data3` = VALUES(`Data3`),
`Data4` = VALUES(`Data4`),
`Data5` = VALUES(`Data5`),
`Data6` = VALUES(`Data6`),
`Data7` = VALUES(`Data7`),
`Data8` = VALUES(`Data8`),
`Data9` = VALUES(`Data9`),
`Data10` = VALUES(`Data10`),
`Data11` = VALUES(`Data11`),
`Data12` = VALUES(`Data12`),
`Data13` = VALUES(`Data13`),
`Data14` = VALUES(`Data14`),
`Data15` = VALUES(`Data15`),
`Data16` = VALUES(`Data16`),
`Data17` = VALUES(`Data17`),
`Data18` = VALUES(`Data18`),
`Data19` = VALUES(`Data19`),
`Data20` = VALUES(`Data20`),
`Data21` = VALUES(`Data21`),
`Data22` = VALUES(`Data22`),
`Data23` = VALUES(`Data23`);
