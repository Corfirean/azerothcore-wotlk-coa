-- Built from Ascension's combat logs and client data. Regenerate rather than edit by hand.
--
-- Molten Core boss schedules, measured from combat logs.
--
-- 42 logs from August 2026, 89 pulls, 31 kills. The difficulty of each pull is
-- read from the spell variants the boss uses; every spell in a pull agrees.
--
-- What the logs settled:
--   Intervals are the same on every difficulty. Golemagg's Lava Burst is 12.1s
--   on Heroic, Mythic and Ascended alike; Geddon's Inferno 60s on all three.
--   Only the numbers change, and those come from SpellDifficulty.dbc, which the
--   core resolves by itself. One cast id per row is therefore enough.
--
--   Ascension's casts are mostly dummies (effect 3). Living Bomb 2105701 does
--   nothing on its own; a server script then cast 2105702. The `effect_d0..d3` columns
--   carry that second spell, read off the logs as whatever lands right after
--   the cast finishes.
--
--   Sulfuron's Conflagrate is a health trigger, not a timer: its first cast
--   came anywhere between 125s and 235s, but always at 49-50% health.
--
-- What stays as it was:
--   Ragnaros and Majordomo keep their stock scripts. They carry choreography
--   that no log records as a spell.
--   Magmadar goes back to his stock script. In the logs he never casts; two
--   heads do (80642, 80643), and those creatures do not exist here. Giving
--   their spells to the body would be invented.

CREATE TABLE IF NOT EXISTS `coa_boss_schedule` (
  `entry`     INT UNSIGNED NOT NULL COMMENT 'base creature entry, all four difficulties',
  `idx`       INT UNSIGNED NOT NULL,
  `spell_d0`  INT UNSIGNED NOT NULL DEFAULT 0,
  `spell_d1`  INT UNSIGNED NOT NULL DEFAULT 0,
  `spell_d2`  INT UNSIGNED NOT NULL DEFAULT 0,
  `spell_d3`  INT UNSIGNED NOT NULL DEFAULT 0,
  `effect_d0` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'cast when the dummy completes, 0 none',
  `effect_d1` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'cast when the dummy completes, 0 none',
  `effect_d2` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'cast when the dummy completes, 0 none',
  `effect_d3` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'cast when the dummy completes, 0 none',
  `first_ms`  INT UNSIGNED NOT NULL DEFAULT 0,
  `period_ms` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0 casts once',
  `hp_pct`    TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '>0 casts once below this health instead of on a clock',
  `target`    TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0 tank, 1 random non-tank, 2 self, 3 area',
  `comment`   VARCHAR(128) NOT NULL DEFAULT '',
  PRIMARY KEY (`entry`, `idx`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `coa_boss` (
  `entry`      INT UNSIGNED NOT NULL,
  `boss_id`    INT UNSIGNED NOT NULL COMMENT 'encounter index in the instance script',
  `berserk_ms` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0 never',
  `comment`    VARCHAR(128) NOT NULL DEFAULT '',
  PRIMARY KEY (`entry`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4;

SELECT IF(
    NOT EXISTS (SELECT 1 FROM `information_schema`.`COLUMNS`
        WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'coa_boss_schedule' AND `COLUMN_NAME` = 'effect_d0'),
    "ALTER TABLE `coa_boss_schedule` "
        "CHANGE COLUMN `effect` `effect_d0` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'cast when the dummy completes, 0 none', "
        "ADD COLUMN `effect_d1` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'cast when the dummy completes, 0 none' AFTER `effect_d0`, "
        "ADD COLUMN `effect_d2` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'cast when the dummy completes, 0 none' AFTER `effect_d1`, "
        "ADD COLUMN `effect_d3` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'cast when the dummy completes, 0 none' AFTER `effect_d2`",
    'DO 0') INTO @coa_boss_schedule_effect_split;
PREPARE `coa_boss_schedule_effect_split` FROM @coa_boss_schedule_effect_split;
EXECUTE `coa_boss_schedule_effect_split`;
DEALLOCATE PREPARE `coa_boss_schedule_effect_split`;

UPDATE `coa_boss_schedule` SET `effect_d1` = `effect_d0`, `effect_d2` = `effect_d0`, `effect_d3` = `effect_d0`
    WHERE `effect_d0` != 0 AND `effect_d1` = 0 AND `effect_d2` = 0 AND `effect_d3` = 0;

DELETE FROM `coa_boss` WHERE `entry` IN (12118,12259,12057,12264,12056,12098,11988);
DELETE FROM `coa_boss_schedule` WHERE `entry` IN (12118,12259,12057,12264,12056,12098,11988);

INSERT INTO `coa_boss`
(
    `entry`, `boss_id`, `berserk_ms`, `comment`
) VALUES
(12118, 0, 0, 'Lucifron');
INSERT INTO `coa_boss`
(
    `entry`, `boss_id`, `berserk_ms`, `comment`
) VALUES
(12259, 2, 0, 'Gehennas');
INSERT INTO `coa_boss`
(
    `entry`, `boss_id`, `berserk_ms`, `comment`
) VALUES
(12057, 3, 0, 'Garr');
INSERT INTO `coa_boss`
(
    `entry`, `boss_id`, `berserk_ms`, `comment`
) VALUES
(12264, 4, 0, 'Shazzrah');
INSERT INTO `coa_boss`
(
    `entry`, `boss_id`, `berserk_ms`, `comment`
) VALUES
(12056, 5, 0, 'Baron Geddon');
INSERT INTO `coa_boss`
(
    `entry`, `boss_id`, `berserk_ms`, `comment`
) VALUES
(12098, 6, 0, 'Sulfuron Harbinger');
INSERT INTO `coa_boss`
(
    `entry`, `boss_id`, `berserk_ms`, `comment`
) VALUES
(11988, 7, 0, 'Golemagg the Incinerator');

INSERT INTO `coa_boss_schedule`
(
    `entry`, `idx`, `spell_d0`, `spell_d1`, `spell_d2`,
    `spell_d3`, `effect_d0`, `effect_d1`, `effect_d2`, `effect_d3`,
    `first_ms`, `period_ms`, `hp_pct`, `target`, `comment`
) VALUES
(12118, 0, 2105212, 2105212, 2105212, 2105212, 2105213, 2105213, 2105213, 2105213, 5300, 15100, 0, 3, 'Shadow Bolt');
INSERT INTO `coa_boss_schedule`
(
    `entry`, `idx`, `spell_d0`, `spell_d1`, `spell_d2`,
    `spell_d3`, `effect_d0`, `effect_d1`, `effect_d2`, `effect_d3`,
    `first_ms`, `period_ms`, `hp_pct`, `target`, `comment`
) VALUES
(12118, 1, 975011, 975011, 975011, 975011, 0, 0, 0, 0, 8400, 7800, 0, 0, 'Fierce Blow');
INSERT INTO `coa_boss_schedule`
(
    `entry`, `idx`, `spell_d0`, `spell_d1`, `spell_d2`,
    `spell_d3`, `effect_d0`, `effect_d1`, `effect_d2`, `effect_d3`,
    `first_ms`, `period_ms`, `hp_pct`, `target`, `comment`
) VALUES
(12118, 2, 2105206, 2105206, 2105206, 2105206, 2105207, 2105207, 2105207, 2105207, 18800, 79900, 0, 3, 'Curse of Lucifron');
INSERT INTO `coa_boss_schedule`
(
    `entry`, `idx`, `spell_d0`, `spell_d1`, `spell_d2`,
    `spell_d3`, `effect_d0`, `effect_d1`, `effect_d2`, `effect_d3`,
    `first_ms`, `period_ms`, `hp_pct`, `target`, `comment`
) VALUES
(12118, 3, 2105218, 2105218, 2105218, 2105218, 0, 0, 0, 0, 29200, 25100, 0, 3, 'Suppressing Shadows');
INSERT INTO `coa_boss_schedule`
(
    `entry`, `idx`, `spell_d0`, `spell_d1`, `spell_d2`,
    `spell_d3`, `effect_d0`, `effect_d1`, `effect_d2`, `effect_d3`,
    `first_ms`, `period_ms`, `hp_pct`, `target`, `comment`
) VALUES
(12259, 0, 975011, 975011, 975011, 975011, 0, 0, 0, 0, 7000, 8500, 0, 0, 'Fierce Blow');
INSERT INTO `coa_boss_schedule`
(
    `entry`, `idx`, `spell_d0`, `spell_d1`, `spell_d2`,
    `spell_d3`, `effect_d0`, `effect_d1`, `effect_d2`, `effect_d3`,
    `first_ms`, `period_ms`, `hp_pct`, `target`, `comment`
) VALUES
(12259, 1, 2105407, 2105407, 2105407, 2105407, 0, 0, 0, 0, 8500, 30000, 0, 3, 'Rain of Fire');
INSERT INTO `coa_boss_schedule`
(
    `entry`, `idx`, `spell_d0`, `spell_d1`, `spell_d2`,
    `spell_d3`, `effect_d0`, `effect_d1`, `effect_d2`, `effect_d3`,
    `first_ms`, `period_ms`, `hp_pct`, `target`, `comment`
) VALUES
(12259, 2, 2105405, 2105405, 2105405, 2105405, 2105406, 2105406, 2105406, 2105406, 9500, 15100, 0, 3, 'Incinerate');
INSERT INTO `coa_boss_schedule`
(
    `entry`, `idx`, `spell_d0`, `spell_d1`, `spell_d2`,
    `spell_d3`, `effect_d0`, `effect_d1`, `effect_d2`, `effect_d3`,
    `first_ms`, `period_ms`, `hp_pct`, `target`, `comment`
) VALUES
(12259, 3, 2105415, 2105415, 2105415, 2105415, 2105416, 2105416, 2105416, 2105416, 11100, 39900, 0, 3, 'Curse of Gehennas');
INSERT INTO `coa_boss_schedule`
(
    `entry`, `idx`, `spell_d0`, `spell_d1`, `spell_d2`,
    `spell_d3`, `effect_d0`, `effect_d1`, `effect_d2`, `effect_d3`,
    `first_ms`, `period_ms`, `hp_pct`, `target`, `comment`
) VALUES
(12259, 4, 2105429, 2105429, 2105429, 2105429, 2105430, 2105430, 2105430, 2105430, 15400, 20000, 0, 1, 'Immolate');
INSERT INTO `coa_boss_schedule`
(
    `entry`, `idx`, `spell_d0`, `spell_d1`, `spell_d2`,
    `spell_d3`, `effect_d0`, `effect_d1`, `effect_d2`, `effect_d3`,
    `first_ms`, `period_ms`, `hp_pct`, `target`, `comment`
) VALUES
(12259, 5, 2105417, 2105417, 2105417, 2105417, 0, 0, 0, 0, 50700, 78100, 0, 0, 'Conjure Flame Orb');
INSERT INTO `coa_boss_schedule`
(
    `entry`, `idx`, `spell_d0`, `spell_d1`, `spell_d2`,
    `spell_d3`, `effect_d0`, `effect_d1`, `effect_d2`, `effect_d3`,
    `first_ms`, `period_ms`, `hp_pct`, `target`, `comment`
) VALUES
(12057, 0, 975011, 975011, 975011, 975011, 0, 0, 0, 0, 12000, 8200, 0, 0, 'Fierce Blow');
INSERT INTO `coa_boss_schedule`
(
    `entry`, `idx`, `spell_d0`, `spell_d1`, `spell_d2`,
    `spell_d3`, `effect_d0`, `effect_d1`, `effect_d2`, `effect_d3`,
    `first_ms`, `period_ms`, `hp_pct`, `target`, `comment`
) VALUES
(12264, 0, 2105601, 2105601, 2105601, 2105601, 0, 0, 0, 0, 3600, 8400, 0, 0, 'Arcane Explosion');
INSERT INTO `coa_boss_schedule`
(
    `entry`, `idx`, `spell_d0`, `spell_d1`, `spell_d2`,
    `spell_d3`, `effect_d0`, `effect_d1`, `effect_d2`, `effect_d3`,
    `first_ms`, `period_ms`, `hp_pct`, `target`, `comment`
) VALUES
(12264, 1, 975011, 975011, 975011, 975011, 0, 0, 0, 0, 6600, 9200, 0, 0, 'Fierce Blow');
INSERT INTO `coa_boss_schedule`
(
    `entry`, `idx`, `spell_d0`, `spell_d1`, `spell_d2`,
    `spell_d3`, `effect_d0`, `effect_d1`, `effect_d2`, `effect_d3`,
    `first_ms`, `period_ms`, `hp_pct`, `target`, `comment`
) VALUES
(12264, 2, 2105607, 2105607, 2105607, 2105607, 2105608, 2105608, 2105608, 2105608, 14100, 30200, 0, 2, 'Dampen Magic');
INSERT INTO `coa_boss_schedule`
(
    `entry`, `idx`, `spell_d0`, `spell_d1`, `spell_d2`,
    `spell_d3`, `effect_d0`, `effect_d1`, `effect_d2`, `effect_d3`,
    `first_ms`, `period_ms`, `hp_pct`, `target`, `comment`
) VALUES
(12264, 3, 2105611, 2105611, 2105611, 2105611, 0, 0, 0, 0, 14600, 16400, 0, 3, 'Blink');
INSERT INTO `coa_boss_schedule`
(
    `entry`, `idx`, `spell_d0`, `spell_d1`, `spell_d2`,
    `spell_d3`, `effect_d0`, `effect_d1`, `effect_d2`, `effect_d3`,
    `first_ms`, `period_ms`, `hp_pct`, `target`, `comment`
) VALUES
(12264, 4, 2105605, 2105605, 2105605, 2105605, 2105606, 2105606, 2105606, 2105606, 18400, 65200, 0, 3, 'Arcane Instability');
INSERT INTO `coa_boss_schedule`
(
    `entry`, `idx`, `spell_d0`, `spell_d1`, `spell_d2`,
    `spell_d3`, `effect_d0`, `effect_d1`, `effect_d2`, `effect_d3`,
    `first_ms`, `period_ms`, `hp_pct`, `target`, `comment`
) VALUES
(12264, 5, 2105609, 2105609, 2105609, 2105609, 2105610, 2105610, 2105610, 2105610, 23600, 34800, 0, 2, 'Mass Counterspell');
INSERT INTO `coa_boss_schedule`
(
    `entry`, `idx`, `spell_d0`, `spell_d1`, `spell_d2`,
    `spell_d3`, `effect_d0`, `effect_d1`, `effect_d2`, `effect_d3`,
    `first_ms`, `period_ms`, `hp_pct`, `target`, `comment`
) VALUES
(12264, 6, 2105612, 2105612, 2105612, 2105612, 2105613, 2105614, 2105615, 2105616, 44300, 64599, 0, 3, 'Arcane Force Nova');
INSERT INTO `coa_boss_schedule`
(
    `entry`, `idx`, `spell_d0`, `spell_d1`, `spell_d2`,
    `spell_d3`, `effect_d0`, `effect_d1`, `effect_d2`, `effect_d3`,
    `first_ms`, `period_ms`, `hp_pct`, `target`, `comment`
) VALUES
(12056, 0, 2105749, 2105749, 2105749, 2105749, 0, 0, 0, 0, 1500, 3000, 0, 0, 'Fire Strike');
INSERT INTO `coa_boss_schedule`
(
    `entry`, `idx`, `spell_d0`, `spell_d1`, `spell_d2`,
    `spell_d3`, `effect_d0`, `effect_d1`, `effect_d2`, `effect_d3`,
    `first_ms`, `period_ms`, `hp_pct`, `target`, `comment`
) VALUES
(12056, 1, 2105750, 2105750, 2105750, 2105750, 0, 0, 0, 0, 2300, 7300, 0, 0, 'Fierce Fire Strike');
INSERT INTO `coa_boss_schedule`
(
    `entry`, `idx`, `spell_d0`, `spell_d1`, `spell_d2`,
    `spell_d3`, `effect_d0`, `effect_d1`, `effect_d2`, `effect_d3`,
    `first_ms`, `period_ms`, `hp_pct`, `target`, `comment`
) VALUES
(12056, 2, 2105717, 2105717, 2105717, 2105717, 2105718, 2105718, 2105718, 2105718, 9100, 39900, 0, 3, 'Ignite Powers');
INSERT INTO `coa_boss_schedule`
(
    `entry`, `idx`, `spell_d0`, `spell_d1`, `spell_d2`,
    `spell_d3`, `effect_d0`, `effect_d1`, `effect_d2`, `effect_d3`,
    `first_ms`, `period_ms`, `hp_pct`, `target`, `comment`
) VALUES
(12056, 3, 2105751, 2105751, 2105751, 2105751, 2105752, 2105752, 2105752, 2105752, 11100, 24600, 0, 0, 'Engulf in Flames');
INSERT INTO `coa_boss_schedule`
(
    `entry`, `idx`, `spell_d0`, `spell_d1`, `spell_d2`,
    `spell_d3`, `effect_d0`, `effect_d1`, `effect_d2`, `effect_d3`,
    `first_ms`, `period_ms`, `hp_pct`, `target`, `comment`
) VALUES
(12056, 4, 2105701, 2105701, 2105701, 2105701, 2105702, 2105702, 2105702, 2105702, 14200, 49000, 0, 1, 'Living Bomb');
INSERT INTO `coa_boss_schedule`
(
    `entry`, `idx`, `spell_d0`, `spell_d1`, `spell_d2`,
    `spell_d3`, `effect_d0`, `effect_d1`, `effect_d2`, `effect_d3`,
    `first_ms`, `period_ms`, `hp_pct`, `target`, `comment`
) VALUES
(12056, 5, 2105756, 2105756, 2105756, 2105756, 0, 0, 0, 0, 15300, 27600, 0, 1, 'Melt Through');
INSERT INTO `coa_boss_schedule`
(
    `entry`, `idx`, `spell_d0`, `spell_d1`, `spell_d2`,
    `spell_d3`, `effect_d0`, `effect_d1`, `effect_d2`, `effect_d3`,
    `first_ms`, `period_ms`, `hp_pct`, `target`, `comment`
) VALUES
(12056, 6, 2105740, 2105740, 2105740, 2105740, 0, 0, 0, 0, 29100, 60100, 0, 0, 'Inferno');
INSERT INTO `coa_boss_schedule`
(
    `entry`, `idx`, `spell_d0`, `spell_d1`, `spell_d2`,
    `spell_d3`, `effect_d0`, `effect_d1`, `effect_d2`, `effect_d3`,
    `first_ms`, `period_ms`, `hp_pct`, `target`, `comment`
) VALUES
(12056, 7, 2105747, 2105747, 2105747, 2105747, 0, 0, 0, 0, 0, 0, 4, 3, 'Armageddon [below 4%]');
INSERT INTO `coa_boss_schedule`
(
    `entry`, `idx`, `spell_d0`, `spell_d1`, `spell_d2`,
    `spell_d3`, `effect_d0`, `effect_d1`, `effect_d2`, `effect_d3`,
    `first_ms`, `period_ms`, `hp_pct`, `target`, `comment`
) VALUES
(12098, 0, 19781, 19781, 19781, 19781, 0, 0, 0, 0, 1400, 12700, 0, 0, 'Flame Spear');
INSERT INTO `coa_boss_schedule`
(
    `entry`, `idx`, `spell_d0`, `spell_d1`, `spell_d2`,
    `spell_d3`, `effect_d0`, `effect_d1`, `effect_d2`, `effect_d3`,
    `first_ms`, `period_ms`, `hp_pct`, `target`, `comment`
) VALUES
(12098, 1, 19780, 19780, 19780, 19780, 0, 0, 0, 0, 4500, 13000, 0, 0, 'Hand of Ragnaros');
INSERT INTO `coa_boss_schedule`
(
    `entry`, `idx`, `spell_d0`, `spell_d1`, `spell_d2`,
    `spell_d3`, `effect_d0`, `effect_d1`, `effect_d2`, `effect_d3`,
    `first_ms`, `period_ms`, `hp_pct`, `target`, `comment`
) VALUES
(12098, 2, 19777, 19777, 19777, 19777, 0, 0, 0, 0, 6600, 8200, 0, 0, 'Dark Strike');
INSERT INTO `coa_boss_schedule`
(
    `entry`, `idx`, `spell_d0`, `spell_d1`, `spell_d2`,
    `spell_d3`, `effect_d0`, `effect_d1`, `effect_d2`, `effect_d3`,
    `first_ms`, `period_ms`, `hp_pct`, `target`, `comment`
) VALUES
(12098, 3, 19779, 19779, 19779, 19779, 0, 0, 0, 0, 11500, 22800, 0, 0, 'Inspire');
INSERT INTO `coa_boss_schedule`
(
    `entry`, `idx`, `spell_d0`, `spell_d1`, `spell_d2`,
    `spell_d3`, `effect_d0`, `effect_d1`, `effect_d2`, `effect_d3`,
    `first_ms`, `period_ms`, `hp_pct`, `target`, `comment`
) VALUES
(12098, 4, 19778, 19778, 19778, 19778, 0, 0, 0, 0, 11900, 15100, 0, 0, 'Demoralizing Shout');
INSERT INTO `coa_boss_schedule`
(
    `entry`, `idx`, `spell_d0`, `spell_d1`, `spell_d2`,
    `spell_d3`, `effect_d0`, `effect_d1`, `effect_d2`, `effect_d3`,
    `first_ms`, `period_ms`, `hp_pct`, `target`, `comment`
) VALUES
(12098, 5, 975011, 975011, 975011, 975011, 0, 0, 0, 0, 18800, 8400, 0, 0, 'Fierce Blow');
INSERT INTO `coa_boss_schedule`
(
    `entry`, `idx`, `spell_d0`, `spell_d1`, `spell_d2`,
    `spell_d3`, `effect_d0`, `effect_d1`, `effect_d2`, `effect_d3`,
    `first_ms`, `period_ms`, `hp_pct`, `target`, `comment`
) VALUES
(12098, 6, 2105905, 2105905, 2105905, 2105905, 2105906, 2105906, 2105906, 2105906, 0, 0, 50, 1, 'Conflagrate [below 50%]');
INSERT INTO `coa_boss_schedule`
(
    `entry`, `idx`, `spell_d0`, `spell_d1`, `spell_d2`,
    `spell_d3`, `effect_d0`, `effect_d1`, `effect_d2`, `effect_d3`,
    `first_ms`, `period_ms`, `hp_pct`, `target`, `comment`
) VALUES
(11988, 0, 975011, 975011, 975011, 975011, 0, 0, 0, 0, 6700, 8300, 0, 0, 'Fierce Blow');
INSERT INTO `coa_boss_schedule`
(
    `entry`, `idx`, `spell_d0`, `spell_d1`, `spell_d2`,
    `spell_d3`, `effect_d0`, `effect_d1`, `effect_d2`, `effect_d3`,
    `first_ms`, `period_ms`, `hp_pct`, `target`, `comment`
) VALUES
(11988, 1, 2105812, 2105812, 2105812, 2105812, 2105814, 2105814, 2105814, 2105814, 6900, 12100, 0, 3, 'Lava Burst');
INSERT INTO `coa_boss_schedule`
(
    `entry`, `idx`, `spell_d0`, `spell_d1`, `spell_d2`,
    `spell_d3`, `effect_d0`, `effect_d1`, `effect_d2`, `effect_d3`,
    `first_ms`, `period_ms`, `hp_pct`, `target`, `comment`
) VALUES
(11988, 2, 2105817, 2105817, 2105817, 2105817, 0, 0, 0, 0, 9000, 45100, 0, 0, 'Massive Stomp');

-- ------------------------------------------------------------------- script
UPDATE `creature_template` SET `ScriptName` = 'coa_boss_ai'
 WHERE `entry` IN (12118,12259,12057,12264,12056,12098,11988)
    OR `entry` IN (112118,212118,312118,112259,212259,312259,112057,212057,312057,112264,212264,312264,112056,212056,312056,112098,212098,312098,111988,211988,311988);

-- Variants carry the same script name as their base, like everywhere else.
UPDATE `creature_template` SET `ScriptName` = 'boss_magmadar'
 WHERE `entry` IN (11982,111982,211982,311982);
