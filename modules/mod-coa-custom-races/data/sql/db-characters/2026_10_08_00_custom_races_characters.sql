-- CoA Custom Races: extra appearance column (Highmountain/Earthen 6th byte, Haranir uint64)
SET @exist := (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'characters' AND COLUMN_NAME = 'extraAppearance');
SET @sql := IF(@exist = 0, 'ALTER TABLE `characters` ADD COLUMN `extraAppearance` BIGINT UNSIGNED NOT NULL DEFAULT 0', 'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
