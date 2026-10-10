"""Kleiner Ersatz für GitHub zum Testen des Launchers.
Aufruf: python3 mock_github.py <port> <ordner>

GET /repos/<owner>/<repo>/releases/latest -> Release-JSON
    Daten aus <ordner>/<repo>/ falls vorhanden, sonst aus <ordner>/:
    current_tag.txt (Tag), <prefix><tag>-game.zip (Spiel), launcher-app-*.pck (Launcher-Update)
GET /dl/<repo>/<name>  -> 302 auf /files/<repo>/<name> (wie GitHub)
GET /files/<repo>/<name> -> Datei
GET /catalog.json      -> <ordner>/catalog.json (Spieleliste)"""
import http.server, json, os, sys

PORT = int(sys.argv[1]); ROOT = sys.argv[2]


def repo_dir(repo):
    d = os.path.join(ROOT, repo)
    return d if os.path.isdir(d) else ROOT


class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass

    def send(self, code, body=b"", ctype="application/octet-stream", headers=None):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        for k, v in (headers or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        p = self.path.split("?")[0]
        parts = p.strip("/").split("/")
        if p == "/catalog.json":
            f = os.path.join(ROOT, "catalog.json")
            return self.send(200, open(f, "rb").read(), "application/json") if os.path.exists(f) else self.send(404)
        if len(parts) == 5 and parts[0] == "repos" and parts[3:] == ["releases", "latest"]:
            repo = parts[2]; d = repo_dir(repo)
            tag_file = os.path.join(d, "current_tag.txt")
            if not os.path.exists(tag_file):
                return self.send(404, b"{}", "application/json")
            tag = open(tag_file).read().strip()
            base = "http://127.0.0.1:%d/dl/%s/" % (PORT, repo)
            assets = [{"name": "kapsel-launcher-windows.zip", "size": 1, "browser_download_url": base + "x"}]
            for n in sorted(os.listdir(d)):
                if n.endswith("-game.zip") and ("-%s-" % tag) in n or (n.startswith("launcher-app-") and n.endswith(".pck")):
                    assets.append({"name": n, "size": os.path.getsize(os.path.join(d, n)), "browser_download_url": base + n})
            body = json.dumps({"tag_name": tag, "name": "%s %s" % (repo, tag), "draft": False,
                "published_at": "2026-10-10T08:00:00Z",
                "body": "## Neu in %s\n- **Neue Welt** freigeschaltet\n- Fehler im [Album](https://x) behoben\n  - Unterpunkt mit `code`" % tag,
                "assets": assets}).encode()
            return self.send(200, body, "application/json")
        if len(parts) == 3 and parts[0] == "dl":
            return self.send(302, headers={"Location": "/files/%s/%s" % (parts[1], parts[2])})
        if len(parts) == 3 and parts[0] == "files":
            f = os.path.join(repo_dir(parts[1]), os.path.basename(parts[2]))
            return self.send(200, open(f, "rb").read()) if os.path.exists(f) else self.send(404)
        self.send(404)


http.server.ThreadingHTTPServer(("127.0.0.1", PORT), H).serve_forever()
