-- Groot Coin command permissions: 1005 issues awards, 1006 reads the audit (history, inspect, status).
-- 1001 stays Command: resettalents. 1002 and 1003 are left open for jealous-sound permissions.
-- Grants already stored on 1003/1004 move with the rows. An unrelated permission on 1005 or 1006
-- makes the guard evaluate a two-row subquery, which fails this file before anything changes.
SELECT IF(EXISTS (SELECT 1 FROM `rbac_permissions` WHERE `id` IN (1005, 1006) AND `name` NOT LIKE 'Command: groot %'),
    (SELECT 1 UNION SELECT 2), 1) INTO @groot_coin_rbac_ids_free;
INSERT IGNORE INTO `rbac_permissions` (`id`, `name`) VALUES
(1005, 'Command: groot award'),
(1006, 'Command: groot audit');
UPDATE `rbac_account_permissions` SET `permissionId` = 1005 WHERE `permissionId` = 1003
    AND EXISTS (SELECT 1 FROM `rbac_permissions` WHERE `id` = 1003 AND `name` = 'Command: groot award');
UPDATE `rbac_linked_permissions` SET `linkedId` = 1005 WHERE `linkedId` = 1003
    AND EXISTS (SELECT 1 FROM `rbac_permissions` WHERE `id` = 1003 AND `name` = 'Command: groot award');
UPDATE `rbac_default_permissions` SET `permissionId` = 1005 WHERE `permissionId` = 1003
    AND EXISTS (SELECT 1 FROM `rbac_permissions` WHERE `id` = 1003 AND `name` = 'Command: groot award');
DELETE FROM `rbac_permissions` WHERE `id` = 1003 AND `name` = 'Command: groot award';
UPDATE `rbac_account_permissions` SET `permissionId` = 1006 WHERE `permissionId` = 1004
    AND EXISTS (SELECT 1 FROM `rbac_permissions` WHERE `id` = 1004 AND `name` = 'Command: groot audit');
UPDATE `rbac_linked_permissions` SET `linkedId` = 1006 WHERE `linkedId` = 1004
    AND EXISTS (SELECT 1 FROM `rbac_permissions` WHERE `id` = 1004 AND `name` = 'Command: groot audit');
UPDATE `rbac_default_permissions` SET `permissionId` = 1006 WHERE `permissionId` = 1004
    AND EXISTS (SELECT 1 FROM `rbac_permissions` WHERE `id` = 1004 AND `name` = 'Command: groot audit');
DELETE FROM `rbac_permissions` WHERE `id` = 1004 AND `name` = 'Command: groot audit';
