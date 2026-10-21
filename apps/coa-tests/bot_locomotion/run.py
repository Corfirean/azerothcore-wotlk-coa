from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]


def main():
    module = ROOT / "modules/mod-coa-playerbots"
    with tempfile.TemporaryDirectory(prefix="coa-locomotion-") as directory:
        target = Path(directory) / "locomotion.exe"
        command = ["cl", "/nologo", "/std:c++20", "/EHsc", "/O2",
                   "/I" + str(module / "tests/stub"), "/I" + str(module / "src"),
                   str(module / "tests/locomotion_tests.cpp"), "/Fe:" + str(target),
                   "/Fo:" + str(Path(directory) / "locomotion.obj")]
        subprocess.run(command, cwd=directory, check=True)
        subprocess.run([str(target)], cwd=directory, check=True)


if __name__ == "__main__":
    main()
