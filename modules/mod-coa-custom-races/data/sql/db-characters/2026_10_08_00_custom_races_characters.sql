-- CoA Custom Races: extra appearance column (Highmountain/Earthen 6th byte, Haranir uint64)
ALTER TABLE `characters` ADD COLUMN IF NOT EXISTS `extraAppearance` BIGINT UNSIGNED NOT NULL DEFAULT 0;
