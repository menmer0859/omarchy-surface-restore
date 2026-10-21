import importlib.util
from importlib.machinery import SourceFileLoader
import os
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
loader = SourceFileLoader('face_locale', str(ROOT / 'scripts/omarchy-face-auth-locale'))

class FaceLocaleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_loader(loader.name, loader)
        cls.module = importlib.util.module_from_spec(spec)
        loader.exec_module(cls.module)

    def test_selected_omarchy_language_overrides_process_locale(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / '.config/omarchy/language'
            path.parent.mkdir(parents=True)
            path.write_text('zh-CN\n')
            self.assertEqual(self.module.language_for_home(Path(directory), 'en_US.UTF-8'), 'zh-CN')
            path.write_text('fr\n')
            self.assertEqual(self.module.language_for_home(Path(directory), 'zh_CN.UTF-8'), 'en')

    def test_missing_language_uses_safe_locale_fallback(self):
        with tempfile.TemporaryDirectory() as directory:
            self.assertEqual(self.module.language_for_home(Path(directory), 'zh_CN.UTF-8'), 'zh-CN')
            self.assertEqual(self.module.language_for_home(Path(directory), 'fr_FR.UTF-8'), 'en')

    def test_malformed_symlink_fifo_and_oversized_language_files_cannot_execute(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / '.config/omarchy/language'
            path.parent.mkdir(parents=True)
            for raw in ('$(touch /tmp/surface-locale-must-not-exist)', '../zh-CN', 'zh-CN\n' * 200):
                path.write_text(raw)
                self.assertEqual(self.module.language_for_home(Path(directory), 'en_US'), 'en')
            path.unlink()
            os.mkfifo(path)
            self.assertEqual(self.module.language_for_home(Path(directory), 'en_US'), 'en')
            path.unlink()
            other = Path(directory) / 'other'; other.write_text('zh-CN')
            path.symlink_to(other)
            self.assertEqual(self.module.language_for_home(Path(directory), 'en_US'), 'en')

    def test_chinese_and_english_prompts_preserve_the_consent_protocol(self):
        self.assertEqual(self.module.translate('en', 'terminal.prompt'), 'Use face authentication? [y/N] ')
        self.assertEqual(self.module.translate('zh-CN', 'terminal.prompt'), '使用人脸识别？[y/N] ')
        self.assertIn('笔记本', self.module.translate('zh-CN', 'face.hint'))

if __name__ == '__main__': unittest.main()
