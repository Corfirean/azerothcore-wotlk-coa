-- CoA Custom 1.3.1: race ids > 32 share their race-mask bit with id - 32, so each race needs a twin of its own
-- faction (Alliance Dracthyr at 52 shared Horde Pandaren's bit and was hostile to the Alliance). Moves:
-- Dracthyr (Alliance) 52 -> 54, Illidari Night Elf 60 -> 61, Illidari Blood Elf 61 -> 60.
-- Runs once (marker in coa_custom_migrations): running the installer again must not swap them back.
CREATE TABLE IF NOT EXISTS coa_custom_migrations (name VARCHAR(64) NOT NULL PRIMARY KEY);
SET @todo = (SELECT COUNT(*) = 0 FROM coa_custom_migrations WHERE name = '1.3.1-race-ids');
UPDATE characters SET race = 254 WHERE race = 60 AND @todo;
UPDATE characters SET race = 60 WHERE race = 61 AND @todo;
UPDATE characters SET race = 61 WHERE race = 254 AND @todo;
UPDATE characters SET race = 54 WHERE race = 52 AND @todo;
INSERT IGNORE INTO coa_custom_migrations VALUES ('1.3.1-race-ids');
DELETE FROM playercreateinfo WHERE race = 52;
DELETE FROM playercreateinfo_item WHERE race = 52;
DELETE FROM playercreateinfo_action WHERE race = 52;
DELETE FROM player_race_stats WHERE Race = 52;
DELETE FROM ascension_custom_class_race WHERE race = 52;
