"""用 gzip 与首次连接失败验证实际 WinSparkle DLL，禁止依赖外部网络。"""
import gzip
import http.server
from pathlib import Path
import sys
import zlib

FEED = b'''<?xml version="1.0"?><rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><item><title>Bettbox 1.0+2</title><sparkle:version>2</sparkle:version><sparkle:shortVersionString>1.0+2</sparkle:shortVersionString><enclosure url="https://example.com/Bettbox.exe" length="3" type="application/octet-stream" /></item></channel></rss>'''


class Handler(http.server.BaseHTTPRequestHandler):
    failures = 0

    def do_GET(self):
        if self.path == '/flaky' and Handler.failures == 0:
            Handler.failures += 1
            self.send_error(503)
            return
        encoding = 'deflate' if self.path == '/deflate' else 'gzip'
        # WinINet 的 deflate 解码器使用无 zlib 包装的原始 DEFLATE 流。
        data = zlib.compress(FEED, wbits=-zlib.MAX_WBITS) if encoding == 'deflate' else gzip.compress(FEED)
        self.send_response(200)
        self.send_header('Content-Type', 'application/xml')
        self.send_header('Content-Encoding', encoding)
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)


if __name__ == '__main__':
    server = http.server.HTTPServer(('127.0.0.1', 0), Handler)
    Path(sys.argv[1]).write_text(str(server.server_port), encoding='ascii')
    server.serve_forever()
