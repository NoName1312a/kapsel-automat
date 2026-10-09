"""Kleiner Ersatz für die GitHub-API zum Testen des Launchers.
Aufruf: python3 mock_github.py <port> <ordner_mit_zips>
GET /repos/<owner>/<repo>/releases/latest  -> Release-JSON (Tag aus <ordner>/current_tag.txt)
GET /dl/<name>                             -> 302 auf /files/<name> (wie GitHub)
GET /files/<name>                          -> Datei"""
import http.server, json, os, sys

PORT = int(sys.argv[1]); ROOT = sys.argv[2]

class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        if self.path.startswith("/repos/") and self.path.endswith("/releases/latest"):
            tag = open(os.path.join(ROOT, "current_tag.txt")).read().strip()
            name = f"kapsel-automat-{tag}-linux.zip"
            size = os.path.getsize(os.path.join(ROOT, name))
            body = json.dumps({"tag_name": tag, "name": f"Kapsel-Automat {tag}", "draft": False,
                "published_at": "2026-10-09T17:00:00Z",
                "body": f"## Neu in {tag}\n- **Neue Welt** freigeschaltet\n- Fehler im [Album](https://x) behoben\n  - Unterpunkt mit `code`",
                "assets": [{"name": "kapsel-launcher-linux.zip", "size": 1, "browser_download_url": "http://127.0.0.1:%d/dl/x" % PORT},
                           {"name": f"kapsel-automat-{tag}-windows.zip", "size": 1, "browser_download_url": "http://127.0.0.1:%d/dl/x" % PORT},
                           {"name": name, "size": size, "browser_download_url": "http://127.0.0.1:%d/dl/%s" % (PORT, name)}]}).encode()
            self.send_response(200); self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body))); self.end_headers(); self.wfile.write(body)
        elif self.path.startswith("/dl/"):
            self.send_response(302); self.send_header("Location", "/files/" + self.path[4:])
            self.send_header("Content-Length", "0"); self.end_headers()
        elif self.path.startswith("/files/"):
            p = os.path.join(ROOT, os.path.basename(self.path))
            if not os.path.exists(p):
                self.send_response(404); self.end_headers(); return
            data = open(p, "rb").read()
            self.send_response(200); self.send_header("Content-Length", str(len(data))); self.end_headers(); self.wfile.write(data)
        else:
            self.send_response(404); self.end_headers()

http.server.ThreadingHTTPServer(("127.0.0.1", PORT), H).serve_forever()
