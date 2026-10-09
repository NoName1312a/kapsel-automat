# Kapsel-Automat Launcher

Kleiner Launcher (Godot 4.4), der Kapsel-Automat aus den GitHub-Releases installiert und aktualisiert. Kein ZIP mehr von Hand entpacken.

## So sieht der Ablauf aus

1. Du änderst das Spiel und pushst es ins Repo.
2. Du trägst die neue Nummer in `VERSION` ein (z. B. `0.6.0`) und pushst, oder setzt einen Tag `v0.6.0`.
3. GitHub Actions baut die Spieldaten (`KapselAutomat.pck`) und den Launcher und legt ein Release an (dauert ein paar Minuten).
4. Beim nächsten Start zeigt der Launcher „Neue Version v0.6.0 ist da!“ mit den Änderungen. Ein Klick auf **Aktualisieren** lädt und installiert sie, danach **Spielen**.

Spielstände liegen in einem eigenen Ordner des Spiels (`%APPDATA%\KapselAutomat` unter Windows), nicht im Installationsordner. Ein Update fasst sie nie an.

## Nur eine EXE, und die ist signiert

`KapselLauncher.exe` ist die offizielle, digital signierte Godot-.exe von godotengine.org, nur umbenannt. Godot lädt automatisch die gleichnamige `KapselLauncher.pck` daneben, das ist unser Launcher. Das Spiel selbst kommt nur als Daten (`game/KapselAutomat.pck`) und läuft über dieselbe .exe (`--main-pack`).

Warum so: Windows Smart App Control blockiert jede unsignierte .exe, und jede neu gebaute .exe wäre wieder neu und unbekannt. Die signierte Godot-.exe wird zugelassen. Sie darf deshalb nie verändert werden (kein eingebettetes .pck, kein Icon-Tausch), sonst ist die Signatur ungültig. Der Workflow prüft das bei jedem Release.

Wichtig: Launcher, Spiel und .exe müssen dieselbe Godot-Version haben (`GODOT_VERSION` im Workflow). Wechselt ihr die Godot-Version, muss jeder den Launcher einmal neu herunterladen.

## Was der Launcher kann

- Zeigt installierte und neueste Version, dazu die Release-Beschreibung als „Was ist neu“.
- Lädt das Spiel mit Fortschrittsbalken, entpackt es erst in `game_new/` und tauscht dann `game/` aus. Bricht etwas ab, bleibt die alte Version spielbar.
- Ohne Internet startet er einfach die installierte Version („Offline“-Hinweis).
- „Ohne Update spielen“, „Erneut prüfen“, „Spielordner“.
- Startparameter `-- --auto`: aktualisiert, falls nötig, und startet das Spiel sofort (z. B. für eine Desktop-Verknüpfung).

## Ordner nach der Installation

```
Kapsel-Automat\
  KapselLauncher.exe       <- diese Datei startest du (offizielle Godot-.exe)
  KapselLauncher.pck       <- der Launcher selbst
  launcher_config.json     <- optional, überschreibt die eingebaute Einstellung
  game\                    <- legt der Launcher selbst an
    KapselAutomat.pck
    .launcher_version.json
```

Den Ordner irgendwohin legen, wo man schreiben darf (z. B. `Dokumente\Spiele\Kapsel-Automat`), nicht nach `C:\Programme`. Sonst weicht der Launcher in seinen Benutzerordner aus.

Die Datei `LIES MICH.txt` im Launcher-ZIP erklärt Testern die Installation.

## Einstellungen (`launcher_config.json`)

| Schlüssel | Bedeutung |
|---|---|
| `repo` | `besitzer/repo` auf GitHub, Standard `NoName1312a/kapsel-automat` |
| `asset_prefix`, `asset_suffix` | Welche Release-Datei das Spiel ist (`kapsel-automat-…-game.zip`) |
| `game_pack` | Spieldaten, die der Launcher mit seiner eigenen .exe startet |
| `game_args` | Zusätzliche Startparameter fürs Spiel |
| `game_exe` | Nur falls `game_pack` leer ist: eigene Spiel-.exe starten |
| `close_on_play` | Launcher nach dem Start schließen |
| `include_prereleases` | Auch Tags wie `v0.7.0-beta` anbieten |
| `api_base` | Nur zum Testen (Mock-Server) |
| `token` | Nur für private Repos. Nicht weitergeben, der Token steckt dann in der Datei. |

Das Repo sollte **öffentlich** sein (oder zumindest die Releases), sonst sieht der Launcher ohne Token nichts.

## Repo-Struktur, die der Workflow erwartet

```
kapsel-automat/
  .github/workflows/release.yml
  game/                           <- Inhalt von kapsel-prototyp/ (mit export_presets.cfg)
  launcher/                       <- dieser Ordner
  changelog/v0.6.0.md             <- optional: Text für „Was ist neu“
```

Gibt es keine `changelog/<tag>.md`, nimmt der Workflow die Commit-Nachrichten seit dem letzten Tag. Der Workflow schreibt die Tag-Version außerdem in `game/project.godot` (`application/config/version`), damit das Spiel sie anzeigen kann.

Das Spiel braucht in seiner `export_presets.cfg` ein Preset „Windows Desktop“; daraus baut der Workflow die `KapselAutomat.pck`.

## Testen

```
tests/run_tests.sh [pfad/zu/godot]
```

Baut ein Testspiel als .pck, startet eine falsche GitHub-API (`tests/mock_github.py`) und prüft Versionsvergleich, Erstinstallation, Update mit Umleitung (wie bei GitHub), dass alte Dateien verschwinden und Dateien außerhalb von `game/` bleiben, den Spielstart über `--main-pack` und das Offline-Verhalten. Der Workflow führt die Tests vor jedem Release aus.

Bildschirmfoto der Oberfläche: `godot --path . -s res://tests/screenshot.gd -- --config=<cfg.json> bild.png`
