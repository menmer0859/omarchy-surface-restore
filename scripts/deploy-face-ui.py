#!/usr/bin/env python3
"""Copy a complete, self-contained plugin UI, without following destination symlinks."""
import argparse
import os
from pathlib import Path
import shutil
import tempfile


def resources(repo: Path, kind: str) -> dict:
    if kind not in ('lock', 'polkit'):
        raise ValueError('unknown plugin kind')
    names = ('Service.qml', 'LockView.qml', 'FaceAttemptPolicy.js', 'DisplayWakePolicy.js', 'LockActivityPolicy.js', 'qmldir') if kind == 'lock' else ('PolkitAgent.qml', 'PolkitModel.js', 'AuthorizationView.qml', 'qmldir')
    result = {name: repo/'assets'/('omarchy-' + kind)/name for name in names}
    for source in sorted((repo/'assets/face-ui').iterdir()):
        if source.is_file() and (source.suffix == '.qml' or source.name == 'qmldir'):
            result['FaceUi/' + source.name] = source
    for source in sorted((repo/'assets/face-ui/i18n').glob('*.json')):
        result['i18n/' + source.name] = source
    return result


def validate(destination: Path, paths: dict):
    if (destination/'manifest.json').is_symlink():
        raise ValueError('plugin manifest must be a regular non-symlink file')
    if destination.is_symlink() or (destination.exists() and not destination.is_dir()):
        raise ValueError('plugin destination must be a regular directory')
    for relative, source in paths.items():
        if not source.is_file():
            raise ValueError('missing plugin resource: ' + relative)
        target = destination/relative
        for part in [target, *list(target.parents)[:len(Path(relative).parts)-1]]:
            if part != target and part.exists() and not part.is_dir():
                raise ValueError('component parent is not a directory: ' + str(part))
            if part.is_symlink():
                raise ValueError('refusing symlink destination: ' + str(part))
        if target.exists() and not target.is_file():
            raise ValueError('resource destination is not a file: ' + str(target))


def deploy(repo: Path, destination: Path, kind: str):
    paths = resources(repo, kind)
    validate(destination, paths)
    destination.mkdir(parents=True, exist_ok=True)
    for relative, source in paths.items():
        target = destination/relative
        target.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(dir=target.parent, delete=False) as stream:
            staged = Path(stream.name)
            try:
                stream.write(source.read_bytes()); stream.flush()
                os.chmod(staged, 0o644)
                os.replace(staged, target)
            finally:
                staged.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('kind', choices=('lock', 'polkit'))
    parser.add_argument('destination', type=Path)
    parser.add_argument('--list', action='store_true')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    paths = resources(repo, args.kind)
    validate(args.destination, paths)
    if args.list:
        print('\n'.join(['FaceUi', 'i18n', *paths]))
    elif not args.check:
        deploy(repo, args.destination, args.kind)


if __name__ == '__main__': main()
