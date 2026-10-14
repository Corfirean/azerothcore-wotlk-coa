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
    "CharBaseInfo.dbc": "062954da4b5402500b10665ce7efe680b7f6d24e3a8fdf2d88280d12fe0a91a3",
    "CharHairGeosets.dbc": "3169ef91b721cc5bd9ebb2ee594547b3486bdf7c3bc5d3ab2650ded512dac9e5",
    "CharSections.dbc": "e5ea5a7a64243728f9d1f11dc455fed8562719add94686f20faf2d258506a56a",
    "CharStartOutfit.dbc": "d2834f12dac5c0a836d6dd4d1f20dd993330cf046106bdd537ba8939289b4daa",
    "CharacterCreationArchetypeDetails.dbc": "9e8f6a27f39b1e1045f2814aac03000d4a7aceb1368e2fb64aaf1bbb052dd8c2",
    "CharacterCreationClassDetails.dbc": "31642ca622c301f2240f00726d35a832bd6cb39da8f146a66c9b41695fccdb03",
    "CharacterCreationPetDetails.dbc": "fbca248ed9654c100f0ae072e862f47b60ff969de1f414865ce94e17456c205b",
    "CharacterCreationShapeshiftDetails.dbc": "d1d906c1711e83edb77f2a79027c8f650d588b350015152cbc431d7e8d28e2d8",
    "CharacterFacialHairStyles.dbc": "51727a58649de5d2e537b3d7e18fdba94bb12398b496fc2746acbea198faf36b",
    "ChrRaces.dbc": "9a49163b9a330d844f0add5a2023f538b828bd5c57d6ecbb3cd5b4196930c5da",
    "CreatureDisplayInfo.dbc": "928fcc43b5dadb55694aac0bbd0ab31268fd4a8fdb508165e64ca272a4e7f801",
    "CreatureDisplayInfoGeosetData.dbc": "a5864d2505b150d745037dc3f2a85db84e9027238500665bcb7a36004bf7baf0",
    "CreatureModelData.dbc": "1ad5af420c92fbbe18f38f37f404aaf7491411fdad23e312bd0312ab6a692706",
    "EmotesTextSound.dbc": "d917d960b80cc41ee89f2a5b23b8c86ba2a45c9cbda4d72af6e8edcc62e9fdec",
    "Faction.dbc": "31c53fe7efa27484c7cbcfe818c7237b90dcf7a5de9e0336fddf148678bb9c7c",
    "HDCharSections.dbc": "92ec4f9d0e2cbf33a2ca99128e05a2bdf560d8fcedd3417d21a2022235244be6",
    "NameGen.dbc": "fc560ee101cdb9733bc64ac9c7f027c25fa3b72cd1375527273d8bb985436717",
    "NamesProfanity.dbc": "95907fe85af598465a785437fd8c5d4a2441e18c7109bfa2112d98b7faa23a0b",
    "NamesReserved.dbc": "95907fe85af598465a785437fd8c5d4a2441e18c7109bfa2112d98b7faa23a0b",
    "SkillLineAbility.dbc": "42f8f25bb8ed382ce11db560458fa303b9de80c093e0c98a8be8f1f9a80ce724",
    "SkillRaceClassInfo.dbc": "75fb54625ce0e54940e7029d77e5927eb3f25c842da20649933503328f5aa9dd",
    "Talent.dbc": "b11369fc16b208507ef75f9201fac939fca090380c2eb7a3f5d0cca70500a7a1",
    "UICameraAppearanceChrRaces.dbc": "d29ee068d46dfb36a247f9dba77694b41401a8ea6323dd63bf3997054754ea27"
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
