-- CoA: Esteria native races keep extra appearance data (Highmountain/Earthen 6th byte, Haranir uint64)
USE acore_characters;
SET @has := (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = 'acore_characters'
             AND TABLE_NAME = 'characters' AND COLUMN_NAME = 'extraAppearance');
SET @sql := IF(@has = 0, 'ALTER TABLE characters ADD COLUMN extraAppearance BIGINT UNSIGNED NOT NULL DEFAULT 0', 'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
