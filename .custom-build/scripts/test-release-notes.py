"""更新说明正文、转换兜底及 appcast CDATA 回归。"""

import importlib.util
import json
import os
from pathlib import Path
import sys
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

spec = importlib.util.spec_from_file_location(
    'release_notes', Path(__file__).with_name('render-release-notes.py')
)
notes = importlib.util.module_from_spec(spec)
spec.loader.exec_module(notes)


class ReleaseNotesTest(unittest.TestCase):
    def render(self, body):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'release.json'
            output = Path(directory) / 'notes.html'
            source.write_text(json.dumps({
                'body': body,
                'html_url': 'https://github.com/uclort/Bettbox/releases/tag/test',
            }), encoding='utf-8')
            with patch.object(sys, 'argv', [
                'render-release-notes.py', '--release-json', str(source),
                '--output', str(output),
            ]):
                notes.main()
            return output.read_text(encoding='utf-8')

    def test_markdown_html_and_cdata(self):
        with patch.dict(os.environ, {'GH_TOKEN': 'test'}), \
                patch.object(notes.subprocess, 'run') as run:
            run.return_value.stdout = (
                '<h2>更新内容</h2><ul><li>测速保持菜单</li></ul><!-- ]]> -->'
            )
            result = self.render('## 更新内容\n- 测速保持菜单')
        self.assertIn('<h2>更新内容</h2>', result)
        self.assertIn('查看完整发布页', result)
        self.assertNotIn('<iframe', result)
        self.assertIn("default-src 'none'", result)
        xml = '<item><description><![CDATA[' + result.replace(
            ']]>', ']]]]><![CDATA[>'
        ) + ']]></description></item>'
        self.assertEqual(ET.fromstring(xml).findtext('description'), result)

    def test_network_failure_preserves_full_escaped_body(self):
        body = '## 第一段\n<script>unsafe</script>\n\n最后一段'
        with patch.dict(os.environ, {'GH_TOKEN': 'test'}), \
                patch.object(notes.subprocess, 'run',
                             side_effect=subprocess.TimeoutExpired('gh', 30)):
            result = self.render(body)
        self.assertIn('&lt;script&gt;unsafe&lt;/script&gt;', result)
        self.assertIn('最后一段', result)

    def test_empty_body(self):
        self.assertIn('暂未提供更新说明', self.render(''))


if __name__ == '__main__':
    unittest.main()
