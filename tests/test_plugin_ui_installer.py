import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

@unittest.skipUnless(Path('/usr/share/omarchy/shell/Commons/Translations.qml').is_file(), 'requires Omarchy plugin API')
class PluginUiInstallerTests(unittest.TestCase):
    def fixture(self, directory):
        base = Path(directory); bin_dir = base/'bin'; bin_dir.mkdir()
        (bin_dir/'omarchy-shell').write_text('#!/bin/bash\n[[ "$*" == "lock isLocked" ]] && echo "${TEST_LOCK_STATE:-false}"\n')
        # Emulate only privilege escalation. Skip archive ancestors / and /tmp,
        # whose metadata an unprivileged test may not change.
        (bin_dir/'sudo').write_text("""#!/bin/bash
if [[ "$*" == 'tar -C / -xpf -' ]]; then
 exec python3 -c 'import os,sys,tarfile; prefix=os.environ["TEST_RESTORE_ROOT"].lstrip("/")+"/"; archive=tarfile.open(fileobj=sys.stdin.buffer,mode="r|"); archive.extractall("/",filter=lambda m,p: m if m.name.removeprefix("./").startswith(prefix) else None)'
fi
exec "$@"
""")
        (bin_dir/'systemctl').write_text('#!/bin/bash\nexit 0\n')
        for path in bin_dir.iterdir(): path.chmod(0o755)
        plugin = base/'config/omarchy/plugins/test.lock'; plugin.mkdir(parents=True)
        (plugin/'manifest.json').write_text(json.dumps({'id':'test.lock','version':'1.1.0','keepLoaded':True,'entryPoints':{'service':'Service.qml'}, 'omarchy':{'clonedFrom':'omarchy.lock'}}))
        (plugin/'Service.qml').write_text('previous working service')
        (plugin/'FaceAttemptPolicy.js').write_text('previous policy')
        env = os.environ | {'PATH':str(bin_dir)+':'+os.environ['PATH'], 'HOME':str(base/'home'), 'XDG_CONFIG_HOME':str(base/'config'), 'SURFACE_SETUP_BACKUP_ROOT':str(base/'backups'), 'SURFACE_SETUP_BACKUP_ID':'upgrade', 'TEST_RESTORE_ROOT':str(base)}
        return base, plugin, env

    def test_upgrade_and_restore_include_translations_and_keep_existing_clone_id(self):
        with tempfile.TemporaryDirectory() as directory:
            base, plugin, env = self.fixture(directory)
            result = subprocess.run(['bash', str(ROOT/'scripts/install-plugin-ui.sh'),'--check'],env=env,capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertFalse((plugin/'i18n').exists())
            result = subprocess.run(['bash',str(ROOT/'scripts/install-plugin-ui.sh')],input='y\n',env=env,capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stderr)
            data=json.loads((plugin/'manifest.json').read_text()); self.assertEqual(data['id'],'test.lock')
            self.assertEqual(data['version'],'2.1.0')
            self.assertIn('使用人脸',(plugin/'i18n/zh-CN.json').read_text())
            result = subprocess.run(['bash',str(ROOT/'scripts/restore.sh')],input='1\ny\n',env=env,capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertEqual((plugin/'Service.qml').read_text(),'previous working service')
            self.assertFalse((plugin/'FaceUi').exists())
            self.assertFalse((plugin/'i18n').exists())
            self.assertEqual(json.loads((plugin/'manifest.json').read_text())['version'],'1.1.0')

    def test_symlink_manifest_is_rejected_before_external_target_changes(self):
        with tempfile.TemporaryDirectory() as directory:
            base, plugin, env=self.fixture(directory)
            outside=base/'outside.json'; outside.write_bytes((plugin/'manifest.json').read_bytes())
            original=outside.read_bytes()
            (plugin/'manifest.json').unlink(); (plugin/'manifest.json').symlink_to(outside)
            result=subprocess.run(['bash',str(ROOT/'scripts/install-plugin-ui.sh')],input='y\n',env=env,capture_output=True,text=True)
            self.assertNotEqual(result.returncode,0)
            self.assertEqual(outside.read_bytes(),original)
            self.assertFalse((base/'backups').exists())

    def test_active_lock_is_rejected_before_backups_or_changes(self):
        with tempfile.TemporaryDirectory() as directory:
            base, plugin, env = self.fixture(directory); env['TEST_LOCK_STATE']='true'
            result = subprocess.run(['bash',str(ROOT/'scripts/install-plugin-ui.sh')],input='y\n',env=env,capture_output=True,text=True)
            self.assertNotEqual(result.returncode,0)
            self.assertIn('Unlock',result.stderr)
            self.assertFalse((base/'backups').exists())
            self.assertEqual((plugin/'Service.qml').read_text(),'previous working service')

if __name__ == '__main__': unittest.main()
