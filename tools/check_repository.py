import ast
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
FORBIDDEN = {'.mpq', '.dbc', '.wtf', '.wdb', '.pdb', '.dmp', '.pfx', '.pem'}
PATTERN = re.compile(rb'(?:github_pat_|gh[pousr]_|sk-proj-)[A-Za-z0-9_]{20,}')
ACCOUNT = re.compile(rb'(?i)WTF[/\\]+Account[/\\]+[^/\\\s"\x27]+@')
SYNTAX_EXCEPTIONS = {
    '.devcontainer/devcontainer.json': 'Upstream JSON-with-comments configuration',
    '.vscode/extensions.json': 'Upstream JSON-with-comments configuration',
    '.vscode/settings.json': 'Upstream JSON-with-comments configuration',
    'deps/libmpq/bindings/python/mpq.py': 'Preserved upstream Python 2 binding',
}


SHIPPED_DBC_DIR = 'modules/mod-coa-custom-races/data/dbc/'
SHIPPED_DBC_HASHES = {
    "CharBaseInfo.dbc": "65e61ac98b46e67b948c1e94d6ee6f93358197ddaaf393e77ce3db027b500a99",
    "CharHairGeosets.dbc": "dc814c82b6e078e9b709eef3e1735a9f194bc46b3038cbc797b0251e1e6c8dec",
    "CharSections.dbc": "4287a2a43eba7f9a0780fe21f87f57554dacbce37d50d0d4f62c794e960aa3fa",
    "CharStartOutfit.dbc": "0ea5eb0bb300db469ad82369b2012dbbe4d26e0b5b09a6a1d7715876e2dd3001",
    "CharacterCreationArchetypeDetails.dbc": "9e8f6a27f39b1e1045f2814aac03000d4a7aceb1368e2fb64aaf1bbb052dd8c2",
    "CharacterCreationClassDetails.dbc": "e51269696febc483e0c0851682e6af77ef4fc87b212fa6e2610a7cca2641ea30",
    "CharacterCreationPetDetails.dbc": "fbca248ed9654c100f0ae072e862f47b60ff969de1f414865ce94e17456c205b",
    "CharacterCreationShapeshiftDetails.dbc": "d1d906c1711e83edb77f2a79027c8f650d588b350015152cbc431d7e8d28e2d8",
    "CharacterFacialHairStyles.dbc": "08ca28159852110b2cc3302ff2ab5f8afcb78c3aa8dd02fa22a8b65b64a1f883",
    "ChrRaces.dbc": "358503359af5b05d16a76f61bab77b5c6221c792bcb0e11793eba8e279689ff7",
    "CreatureDisplayInfo.dbc": "ba1b04bcbcb04161c92cc352a2e84a61e5ce6780c162023db1e0aab31bf883df",
    "CreatureDisplayInfoGeosetData.dbc": "a5864d2505b150d745037dc3f2a85db84e9027238500665bcb7a36004bf7baf0",
    "CreatureModelData.dbc": "8503fff50a8f6abdd6973f68fd55ddb3f81340e425df4c8f17189bb9f73605d7",
    "EmotesTextSound.dbc": "d917d960b80cc41ee89f2a5b23b8c86ba2a45c9cbda4d72af6e8edcc62e9fdec",
    "Faction.dbc": "31c53fe7efa27484c7cbcfe818c7237b90dcf7a5de9e0336fddf148678bb9c7c",
    "HDCharSections.dbc": "48bca2e5b4311a5210ebf4da497be6b775791684c5354c74f335475d42380c2b",
    "NameGen.dbc": "316d1ac29a3cae477a2b858d3efdaa6593c62efcc4140f2ee6a53a4ef2bcb2e1",
    "NamesProfanity.dbc": "95907fe85af598465a785437fd8c5d4a2441e18c7109bfa2112d98b7faa23a0b",
    "NamesReserved.dbc": "95907fe85af598465a785437fd8c5d4a2441e18c7109bfa2112d98b7faa23a0b",
    "SkillLineAbility.dbc": "2143f0294371c058ee38a067a5713c09c04c2a466a87f46b8a0802f321679cbc",
    "SkillRaceClassInfo.dbc": "75fb54625ce0e54940e7029d77e5927eb3f25c842da20649933503328f5aa9dd",
    "Talent.dbc": "b11369fc16b208507ef75f9201fac939fca090380c2eb7a3f5d0cca70500a7a1",
    "UICameraAppearanceChrRaces.dbc": "aed779a4709be47fac5d4b41ddefa2fd46932af75de4bd9c7365dbe625b3eccf"
}


def is_shipped_dbc(name, raw):
    if not name.startswith(SHIPPED_DBC_DIR):
        return False
    return SHIPPED_DBC_HASHES.get(name.removeprefix(SHIPPED_DBC_DIR)) == hashlib.sha256(raw).hexdigest()


def main():
    git = subprocess.run(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'], cwd=ROOT, capture_output=True)
    if git.returncode == 0:
        paths = [ROOT / p.decode('utf-8') for p in git.stdout.split(b'\0') if p]
    else:
        paths = [p for p in ROOT.rglob('*') if p.is_file() and not {'.git', '.local', '__pycache__'} & set(p.relative_to(ROOT).parts)]
    issues = []
    checked = 0
    for path in paths:
        name = path.relative_to(ROOT).as_posix()
        if path.is_symlink():
            raw = os.readlink(path).encode('utf-8')
            target = path.resolve()
            if not target.is_relative_to(ROOT) or not target.exists():
                issues.append((name, 'broken or external symbolic link'))
        elif not path.is_file():
            issues.append((name, 'tracked file missing'))
            continue
        else:
            raw = path.read_bytes()
        if (path.suffix.lower() in FORBIDDEN and not is_shipped_dbc(name, raw)) or path.name == '.env' or '/WTF/' in '/' + name:
            issues.append((name, 'private/generated artifact'))
        if PATTERN.search(raw):
            issues.append((name, 'credential pattern'))
        if ACCOUNT.search(raw):
            issues.append((name, 'personal account path'))
        if path.suffix == '.ps1':
            lines = raw.decode('utf-8-sig').splitlines()
            for index, line in enumerate(lines):
                if re.search(r'(?i)password', line):
                    for follow in lines[index + 1:index + 4]:
                        if re.search(r'\.WriteLine\(\s*[\x27\x22][^\x27\x22]+[\x27\x22]\s*\)', follow):
                            issues.append((name, 'literal administrator credential after password prompt'))
                            break
        if path.suffix == '.py' and name not in SYNTAX_EXCEPTIONS:
            try:
                ast.parse(raw.decode('utf-8-sig'), filename=name)
            except (SyntaxError, UnicodeError) as error:
                issues.append((name, 'Python syntax: ' + type(error).__name__))
        if path.suffix == '.json' and name not in SYNTAX_EXCEPTIONS:
            try:
                json.loads(raw.decode('utf-8-sig'))
            except (ValueError, UnicodeError):
                issues.append((name, 'invalid JSON'))
        checked += 1
    print(json.dumps({'checkedFiles': checked, 'issues': issues,
                      'reviewedShippedDbc': [SHIPPED_DBC_DIR + name for name in sorted(SHIPPED_DBC_HASHES)],
                      'reviewedSyntaxExceptions': {name: reason for name, reason in SYNTAX_EXCEPTIONS.items() if (ROOT / name).is_file()},
                      'scope': 'tracked source artifact/credential patterns and Python/JSON syntax; not a complete secret/license audit'}, indent=2))
    return bool(issues)


if __name__ == '__main__':
    sys.exit(main())
