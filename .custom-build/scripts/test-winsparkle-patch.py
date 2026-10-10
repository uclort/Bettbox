"""固定更新器补丁的幂等与状态转换回归。"""
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('patch', Path(__file__).with_name('patch-winsparkle.py'))
patch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(patch)


class PatchTest(unittest.TestCase):
    def test_patch_is_idempotent_and_keeps_signature_validation(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'src').mkdir()
            (root / 'src/ui.cpp').write_text('    EnablePulsing(false);\n\n    HIDE(m_heading);\n    SHOW(m_progress);')
            (root / 'src/download.cpp').write_text('    InternetSetOptionW(inet, INTERNET_OPTION_ENABLE_HTTP_PROTOCOL, &dwOption, sizeof(dwOption));\n    WaitUntilSignaledWithTerminationCheck(context.eventRequestComplete, onThread);\n\n    // Check returned status code\n                             headers.c_str(),\n                             (DWORD)headers.length(),')
            (root / 'src/error.cpp').write_text('    OutputDebugStringA(err.c_str());')
            (root / 'src/signatureverifier.cpp').write_text('VerifyDSASignature();')
            (root / 'src/updatechecker.cpp').write_text('#include <winsparkle.h>\n        DownloadFile(url, &appcast_xml, this, Settings::GetHttpHeadersString(), Download_BypassProxies);')
            patch.apply(root)
            first = {path.name: path.read_text() for path in (root / 'src').iterdir()}
            patch.apply(root)
            self.assertEqual(first, {path.name: path.read_text() for path in (root / 'src').iterdir()})
            self.assertIn('m_progress->SetValue(0);', first['ui.cpp'])
            self.assertIn('INTERNET_OPTION_HTTP_DECODING', first['download.cpp'])
            self.assertIn('Accept-Encoding: gzip, deflate', first['download.cpp'])
            self.assertIn('appcast_xml.data.clear();', first['updatechecker.cpp'])
            self.assertIn('if (attempt != 0) throw;', first['updatechecker.cpp'])
            self.assertEqual(first['signatureverifier.cpp'], 'VerifyDSASignature();')
            self.assertLess(first['ui.cpp'].index('m_progress->SetValue(0);'),
                            first['ui.cpp'].index('SHOW(m_progress);'))
            self.assertIn('updater.log', first['error.cpp'])
            self.assertIn('context.lastError', first['download.cpp'])

    def test_unknown_source_fails_instead_of_silently_skipping(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'ui.cpp'
            path.write_text('unexpected source')
            with self.assertRaises(RuntimeError):
                patch.replace(path, 'missing', 'replacement')
            self.assertEqual(path.read_text(), 'unexpected source')


if __name__ == '__main__':
    unittest.main()
