-- .hidearmor: characters whose armor is hidden (mod-coa-custom-races)
CREATE TABLE IF NOT EXISTS `coa_hide_armor` (
  `guid` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
