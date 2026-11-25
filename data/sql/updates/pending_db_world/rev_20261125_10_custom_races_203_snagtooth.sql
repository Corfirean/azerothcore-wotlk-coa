-- Custom Races 2.0.3, 62_snagtooth.sql of the release's server archive.
-- Snagtooth race 94, Alliance (from CoA Custom Races 2.0.3). Classes + start kit of the Human (CharBaseInfo = Human's), start point
-- Dun Morogh like the Gnome, Gnome stats. Display 999401 (one body for both sexes). Idempotent.
START TRANSACTION;
DELETE FROM `playercreateinfo` WHERE `race` = 94;
INSERT INTO `playercreateinfo` (`race`,`class`,`map`,`zone`,`position_x`,`position_y`,`position_z`,`orientation`)
  SELECT 94,h.`class`,g.`map`,g.`zone`,g.`position_x`,g.`position_y`,g.`position_z`,g.`orientation`
  FROM `playercreateinfo` h JOIN (SELECT * FROM `playercreateinfo` WHERE `race` = 7 AND `class` = 1) g WHERE h.`race` = 1;
DELETE FROM `playercreateinfo_item` WHERE `race` = 94;
INSERT INTO `playercreateinfo_item` (`race`,`class`,`itemid`,`amount`,`Note`) SELECT 94,`class`,`itemid`,`amount`,`Note` FROM `playercreateinfo_item` WHERE `race` = 1;
DELETE FROM `playercreateinfo_action` WHERE `race` = 94;
INSERT INTO `playercreateinfo_action` (`race`,`class`,`button`,`action`,`type`) SELECT 94,`class`,`button`,`action`,`type` FROM `playercreateinfo_action` WHERE `race` = 1;
DELETE FROM `player_race_stats` WHERE `Race` = 94;
INSERT INTO `player_race_stats` (`Race`,`Strength`,`Agility`,`Stamina`,`Intellect`,`Spirit`) SELECT 94,`Strength`,`Agility`,`Stamina`,`Intellect`,`Spirit` FROM `player_race_stats` WHERE `Race` = 7;
DELETE FROM `ascension_custom_class_race` WHERE `race` = 94;
INSERT INTO `ascension_custom_class_race` (`class`,`race`) SELECT `class`,94 FROM `ascension_custom_class_race` WHERE `race` = 1;
DELETE FROM `player_totem_model` WHERE `RaceID` = 94;
INSERT INTO `player_totem_model` (`TotemID`,`RaceID`,`ModelID`) SELECT `TotemID`,94,`ModelID` FROM `player_totem_model` WHERE `RaceID` = 7;
DELETE FROM `creature_model_info` WHERE `DisplayID` = 999401;
INSERT INTO `creature_model_info` (`DisplayID`,`BoundingRadius`,`CombatReach`,`Gender`,`DisplayID_Other_Gender`) VALUES (999401, 0.45, 1.5, 2, 0);
COMMIT;
