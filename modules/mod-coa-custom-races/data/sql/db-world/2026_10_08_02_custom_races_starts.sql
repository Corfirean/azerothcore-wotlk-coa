-- CoA Custom 1.4: the added races start in the starting zone that fits them, spread over the six classic ones
-- (until now every Alliance one started in Northshire and every Horde one in the Valley of Trials).
-- Each race takes the start of a template race, class by class; the Death Knight start (map 609) is not touched.
-- Only new characters are affected.

DROP TEMPORARY TABLE IF EXISTS coa_race_start;
CREATE TEMPORARY TABLE coa_race_start (race TINYINT UNSIGNED PRIMARY KEY, template TINYINT UNSIGNED NOT NULL);
INSERT INTO coa_race_start (race, template) VALUES
-- Alliance: Northshire (Human 1)
(13, 1), (16, 1), (29, 1), (32, 1), (47, 1), (54, 1), (65, 1),
-- Alliance: Coldridge Valley (Dwarf 3)
(15, 3), (18, 3), (27, 3), (30, 3), (48, 3), (67, 3), (68, 3),
-- Alliance: Shadowglen (Night Elf 4)
(14, 4), (22, 4), (50, 4), (59, 4), (61, 4), (62, 4), (71, 4),
-- Horde: Valley of Trials (Orc 2)
(12, 2), (19, 2), (23, 2), (24, 2), (25, 2), (28, 2), (49, 2), (57, 2), (74, 2),
-- Horde: Mulgore (Tauren 6)
(17, 6), (20, 6), (31, 6), (53, 6), (56, 6), (66, 6), (69, 6), (70, 6),
-- Horde: Deathknell (Undead 5)
(21, 5), (26, 5), (51, 5), (55, 5), (58, 5), (60, 5), (63, 5);

UPDATE playercreateinfo p
JOIN coa_race_start r ON r.race = p.race
JOIN playercreateinfo t ON t.race = r.template AND t.class = p.class AND t.map <> 609
SET p.map = t.map, p.zone = t.zone, p.position_x = t.position_x, p.position_y = t.position_y,
    p.position_z = t.position_z, p.orientation = t.orientation
WHERE p.map <> 609;

DROP TEMPORARY TABLE coa_race_start;
