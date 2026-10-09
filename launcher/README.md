# Kapsel-Automat Launcher

Kleiner Launcher (Godot 4.4), der Kapsel-Automat aus den GitHub-Releases installiert und aktualisiert. Kein ZIP mehr von Hand entpacken.

## So sieht der Ablauf aus

1. Du änderst das Spiel und pushst es ins Repo.
2. Du setzt einen Versions-Tag: `git tag v0.6.0` und `git push origin v0.6.0`.
3. GitHub Actions baut Spiel und Launcher für Windows und Linux und legt ein Release mit den ZIPs an (dauert ein paar Minuten).
4. Beim nächsten Start zeigt der Launcher „Neue Version v0.6.0 ist da!“ mit den Änderungen. Ein Klick auf **Aktualisieren** lädt und installiert sie, danach **Spielen**.

Spielstände liegen in einem eigenen Ordner des Spiels (`%APPDATA%\KapselAutomat` unter Windows), nicht im Installationsordner. Ein Update fasst sie nie an.

## Was der Launcher kann

- Zeigt installierte und neueste Version, dazu die Release-Beschreibung als „Was ist neu“.
- Lädt das Spiel mit Fortschrittsbalken, entpackt es erst in `game_new/` und tauscht dann `game/` aus. Bricht etwas ab, bleibt die alte Version spielbar.
- Ohne Internet startet er einfach die installierte Version („Offline“-Hinweis).
- „Ohne Update spielen“, „Erneut prüfen“, „Spielordner“.
- Startparameter `-- --auto`: aktualisiert, falls nötig, und startet das Spiel sofort (z. B. für eine Desktop-Verknüpfung).

## Ordner nach der Installation

```
Kapsel-Automat\
  KapselLauncher.exe       <- diese Datei startest du
  launcher_config.json     <- optional, überschreibt die eingebaute Einstellung
  game\                    <- legt der Launcher selbst an
    KapselAutomat.exe
    .launcher_version.json
```

Den Ordner irgendwohin legen, wo man schreiben darf (z. B. `Dokumente\Spiele\Kapsel-Automat`), nicht nach `C:\Programme`. Sonst weicht der Launcher in seinen Benutzerordner aus.

Windows zeigt beim ersten Start evtl. „Der Computer wurde durch Windows geschützt“, weil die .exe nicht signiert ist: „Weitere Informationen“ → „Trotzdem ausführen“.

## Einstellungen (`launcher_config.json`)

| Schlüssel | Bedeutung |
|---|---|
| `repo` | `besitzer/repo` auf GitHub, Standard `NoName1312a/kapsel-automat` |
| `asset_prefix`, `asset_suffix` | Welche Release-Datei das Spiel ist (`kapsel-automat-…-windows.zip`) |
| `game_exe` | Name der Spiel-Datei je Betriebssystem |
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

Das Spiel hat inzwischen eine eigene `export_presets.cfg` (Preset „Windows Desktop“). Ein Linux-Build entsteht nur, wenn dort auch ein Preset „Linux“ steht; Vorlage dafür in `fuer-spiel/export_presets.cfg`.

## Testen

```
python3 tests/mock_github.py 8765 <ordner_mit_zips>          # falsche GitHub-API
godot --headless --path . -s res://tests/test_updater.gd -- 8765 <installordner> <ordner_mit_zips>
godot --path . -s res://tests/screenshot.gd -- --config=<cfg.json> bild.png
```

`test_updater.gd` prüft Versionsvergleich, Erstinstallation, Update mit Umleitung (wie bei GitHub), dass alte Dateien verschwinden, dass Dateien außerhalb von `game/` bleiben, Spielstart und Offline-Verhalten.
