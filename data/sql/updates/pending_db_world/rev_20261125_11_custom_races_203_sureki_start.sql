-- Custom Races 2.0.3, 64_sureki_start.sql of the release's server archive.
-- V2.0.3: Sureki (86, Alliance) starts at the Night Elf start point, class by class (it started in Durotar). Repeatable.
UPDATE playercreateinfo p JOIN playercreateinfo n ON n.race = 4 AND n.class = p.class
SET p.map = n.map, p.zone = n.zone, p.position_x = n.position_x, p.position_y = n.position_y,
    p.position_z = n.position_z, p.orientation = n.orientation WHERE p.race = 86;
