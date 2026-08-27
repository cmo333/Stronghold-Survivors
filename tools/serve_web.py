#!/usr/bin/env python3
"""Local test server for the exported Godot 4 web build.

Godot 4 HTML5 exports need the cross-origin isolation headers (COOP/COEP) so the
browser will enable SharedArrayBuffer. A plain `python -m http.server` will load
the page but the game will fail to start. This server adds those headers.

Usage:
    python3 tools/serve_web.py            # serves build/web on http://localhost:8060
    python3 tools/serve_web.py 9000       # custom port
"""
import http.server
import os
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build", "web")
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8060


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=os.path.abspath(ROOT), **kwargs)

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


if __name__ == "__main__":
    os.chdir(os.path.abspath(ROOT))
    with http.server.ThreadingHTTPServer(("0.0.0.0", PORT), Handler) as httpd:
        print(f"Serving {os.path.abspath(ROOT)}")
        print(f"Open: http://localhost:{PORT}/index.html")
        print("Press Ctrl+C to stop.")
        httpd.serve_forever()
