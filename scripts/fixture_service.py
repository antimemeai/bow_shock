"""Owned immutable catalog server for the native POC; standard library only."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import threading

ROOT = Path(__file__).resolve().parents[1]


class Catalog(BaseHTTPRequestHandler):
    def do_GET(self):
        page = {'/': 'amber', '/amber': 'amber', '/birch': 'birch'}.get(self.path)
        if page is None:
            self.send_error(404)
            return
        data = self.server.pages[page]
        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.send_header('Content-Length', str(len(data)))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Content-Security-Policy', "default-src 'none'; style-src 'unsafe-inline'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'")
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *_):
        pass


def serve(port):
    server = ThreadingHTTPServer(('127.0.0.1', port), Catalog)
    server.daemon_threads = True
    server.pages = {name: (ROOT / 'fixtures/products' / f'{name}.html').read_bytes()
                    for name in ['amber', 'birch']}
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def arguments(app, data, origin, page='amber'):
    return [str(app), f'--bs-profile={data / "profile"}',
            f'--bs-table-db={data / "tables.sqlite"}', f'--bs-table-origin={origin}',
            f'--bs-url={origin}/{page}']
