#!/bin/sh
# Startet alle Launcher-Tests: baut ein Testspiel als .pck, stellt eine falsche GitHub-API bereit
# und prüft Installation, Update, Start und Offline-Verhalten.
# Aufruf: tests/run_tests.sh [pfad/zu/godot]
set -e
GODOT="${1:-godot}"
HERE="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"
PORT=8765
trap 'kill $MOCK 2>/dev/null; rm -rf "$TMP"' EXIT

cp -r "$HERE/fake_game" "$TMP/fake_src" && rm "$TMP/fake_src/.gdignore"
"$GODOT" --headless --path "$TMP/fake_src" --import >/dev/null 2>&1 || true
mkdir -p "$TMP/mock"
for v in 0.5.0 0.6.0; do
  rm -rf "$TMP/build" && mkdir -p "$TMP/build/KapselAutomat/data"
  "$GODOT" --headless --path "$TMP/fake_src" --export-pack Linux "$TMP/build/KapselAutomat/KapselAutomat.pck" >/dev/null 2>&1
  echo "$v" > "$TMP/build/KapselAutomat/version.txt"
  head -c 3000000 /dev/urandom > "$TMP/build/KapselAutomat/data/blob.bin"
  (cd "$TMP/build" && zip -qr "$TMP/mock/kapsel-automat-v$v-game.zip" KapselAutomat)
done
echo v0.5.0 > "$TMP/mock/current_tag.txt"
"$GODOT" --headless --path "$HERE/.." --import >/dev/null 2>&1 || true
python3 "$HERE/mock_github.py" $PORT "$TMP/mock" & MOCK=$!
sleep 1
"$GODOT" --headless --path "$HERE/.." -s res://tests/test_updater.gd -- $PORT "$TMP/install" "$TMP/mock" > "$TMP/out.txt" 2>&1 || true
grep -E "^(  ok|  FAIL|[A-Z][a-z]|ERGEBNIS)" "$TMP/out.txt" | grep -v "^Godot Engine"
grep -q "ERGEBNIS: ALLES OK" "$TMP/out.txt" || { grep -E "ERROR|SCRIPT" "$TMP/out.txt" | head -20; exit 1; }
