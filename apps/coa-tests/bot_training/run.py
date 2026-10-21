from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]


def main():
    module = ROOT / "modules/mod-coa-playerbots"
    subprocess.run([sys.executable, "-B", str(module / "tools/run_training_tests.py"),
                    "--module", str(module)], check=True)


if __name__ == "__main__":
    main()
