"""将 Release 描述转换成更新框正文，不嵌入 GitHub 网页。"""

import argparse
import html
import json
import os
from pathlib import Path
import subprocess


def document(body, rendered, release_url):
    content = rendered or f"<pre>{html.escape(body or '暂未提供更新说明。')}</pre>"
    return f'''<!doctype html><html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src https:;">
<style>
:root {{ color-scheme: light dark; }}
body {{ font: 14px/1.65 -apple-system,"Microsoft YaHei",sans-serif; margin: 20px; overflow-wrap: anywhere; }}
h1,h2,h3 {{ line-height: 1.35; }} h1 {{ font-size: 22px; }} h2 {{ font-size: 18px; }} h3 {{ font-size: 16px; }}
pre {{ white-space: pre-wrap; }} code {{ font-size: .92em; }}
img,table {{ max-width: 100%; }} table {{ border-collapse: collapse; }} td,th {{ border: 1px solid #888; padding: 6px; }}
a {{ color: #1876d2; }} footer {{ margin-top: 24px; border-top: 1px solid #888; padding-top: 12px; }}
</style></head><body>{content}
<footer><a href="{html.escape(release_url, quote=True)}">查看完整发布页</a></footer></body></html>'''


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--release-json', required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    release = json.loads(Path(args.release_json).read_text(encoding='utf-8'))
    body = release.get('body') or ''
    rendered = ''
    token = os.environ.get('GH_TOKEN')
    if body and token:
        try:
            rendered = subprocess.run(
                ['gh', 'api', '--hostname', 'github.com', 'markdown', '--input', '-'],
                input=json.dumps({'text': body, 'mode': 'gfm',
                                  'context': 'uclort/Bettbox'}),
                capture_output=True, text=True, check=True, timeout=30,
            ).stdout
        except (subprocess.SubprocessError, OSError):
            print('富文本转换失败，保留完整正文作为纯文本兜底。')
    Path(args.output).write_text(
        document(body, rendered, release.get('html_url') or ''), encoding='utf-8'
    )


if __name__ == '__main__':
    main()
