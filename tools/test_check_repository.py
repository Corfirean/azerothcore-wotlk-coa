import unittest
from pathlib import Path
import check_repository


class ShippedAssetsTests(unittest.TestCase):
    def test_exact_public_module_assets_are_recognized(self):
        for filename in check_repository.SHIPPED_DBC_HASHES:
            name = check_repository.SHIPPED_DBC_DIR + filename
            raw = (check_repository.ROOT / name).read_bytes()
            self.assertTrue(check_repository.is_shipped_dbc(name, raw))
            self.assertFalse(check_repository.is_shipped_dbc(name, raw + b"modified"))
            self.assertFalse(check_repository.is_shipped_dbc("personal/" + Path(name).name, raw))


if __name__ == "__main__":
    unittest.main()
