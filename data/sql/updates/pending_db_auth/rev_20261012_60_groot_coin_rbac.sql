-- Groot Coin command permissions: 1003 issues awards, 1004 reads the audit (history, inspect, status).
-- 1001 and 1002 are already taken on this fork (Command: resettalents). Neither Groot permission is
-- linked to a role; an administrator grants them to designated staff accounts per realm.
-- Non-destructive on replay: existing rows are kept (a DELETE would cascade to rbac_account_permissions and drop
-- every grant). An unrelated permission already using 1003 or 1004 makes the guard evaluate a two-row subquery,
-- which fails this file before anything changes.
SELECT IF(EXISTS (SELECT 1 FROM `rbac_permissions` WHERE `id` IN (1003, 1004) AND `name` NOT LIKE 'Command: groot %'),
    (SELECT 1 UNION SELECT 2), 1) INTO @groot_coin_rbac_ids_free;
INSERT IGNORE INTO `rbac_permissions` (`id`, `name`) VALUES
(1003, 'Command: groot award'),
(1004, 'Command: groot audit');
