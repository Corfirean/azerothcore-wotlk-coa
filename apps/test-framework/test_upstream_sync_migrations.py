import argparse
import importlib.util
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]


def run(mysql_bin):
    spec = importlib.util.spec_from_file_location(
        'isolated_mysql', ROOT / 'apps/test-framework/test_enchantment_migrations.py')
    fixture = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(fixture)
    database = fixture.EnchantmentMigrations
    database.mysql_bin = mysql_bin
    try:
        database.setUpClass()
        query = database.query
        query('CREATE TABLE rbac_permissions (id INT PRIMARY KEY, name VARCHAR(100));'
              'CREATE TABLE rbac_account_permissions (accountId INT, permissionId INT,'
              ' PRIMARY KEY(accountId,permissionId), FOREIGN KEY(permissionId) REFERENCES rbac_permissions(id)'
              ' ON DELETE CASCADE);'
              "INSERT INTO rbac_permissions VALUES (1001,'Command: resettalents');"
              'INSERT INTO rbac_account_permissions VALUES (7,1001);')
        migration = (ROOT / 'data/sql/updates/pending_db_auth/rev_20261012_60_groot_coin_rbac.sql').read_text()
        query(migration)
        query('INSERT INTO rbac_account_permissions VALUES (7,1002),(7,1003);')
        query(migration)
        assert query('SELECT permissionId FROM rbac_account_permissions ORDER BY permissionId;') == [
            ('1001',), ('1002',), ('1003',)]
        assert query('SELECT name FROM rbac_permissions WHERE id=1001;') == [('Command: resettalents',)]
        header = (ROOT / 'src/server/game/Accounts/RBAC.h').read_text()
        for command, name in [('AWARD', 'award'), ('AUDIT', 'audit')]:
            permission = re.search(rf'RBAC_PERM_COMMAND_GROOT_{command}\s*=\s*(\d+)', header)[1]
            assert query(f'SELECT name FROM rbac_permissions WHERE id={permission};') == [(f'Command: groot {name}',)]
        query("UPDATE rbac_permissions SET name='Unrelated command' WHERE id=1003;")
        query(migration, expected_error='ERROR 1242')
        assert query('SELECT COUNT(*) FROM rbac_account_permissions;') == [('3',)]
        query('CREATE TABLE ethereal_bazaar_set_cache (cache_item INT PRIMARY KEY);'
              "INSERT INTO item_template (entry,ScriptName) VALUES (1777028,'item_ethereal_set_cache');"
              'INSERT INTO ethereal_bazaar_set_cache VALUES (1777028);')
        base = (ROOT / 'data/sql/base/db_world/gameobject_template.sql').read_text()
        query(re.search(r'CREATE TABLE.*?;', base, re.S)[0])
        query("ALTER TABLE gameobject_template ADD COLUMN local_note VARCHAR(100) DEFAULT 'kept';"
              "INSERT INTO gameobject_template (entry,name) VALUES (2201000,'Old template');"
              'CREATE TABLE template_reference (entry INT UNSIGNED PRIMARY KEY,'
              ' FOREIGN KEY(entry) REFERENCES gameobject_template(entry));'
              'INSERT INTO template_reference VALUES (2201000);')
        thermal = (ROOT / 'data/sql/updates/pending_db_world/rev_20261012_30_thermal_anvil_fix.sql').read_text()
        query(thermal)
        query(thermal)
        assert query('SELECT entry,Data0,Data1,local_note FROM gameobject_template ORDER BY entry;') == [
            ('2201000', '3', '20', 'kept'), ('2202000', '1', '20', 'kept')]
        assert query('SELECT COUNT(*) FROM template_reference;') == [('1',)]
        assert query('SELECT ScriptName FROM item_template WHERE entry=1777028;') == [('',)]
        assert query('SELECT COUNT(*) FROM ethereal_bazaar_set_cache;') == [('0',)]
        print('PASS: RBAC collision guards and replay preserve grants; Thermal Anvil preserves references and local fields')
    finally:
        database.doClassCleanups()
        if database.tearDown_exceptions:
            raise database.tearDown_exceptions[0][1]


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--mysql-bin', type=Path, required=True)
    run(parser.parse_args().mysql_bin)
