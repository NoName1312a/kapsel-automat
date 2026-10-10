# Spielebibliothek (Launcher)

Kleiner Launcher im Stil von Steam (Godot 4.4). Er zeigt links alle Spiele aus einer Spieleliste, installiert und aktualisiert sie aus den GitHub-Releases und startet sie. Beim Spielstart verkleinert er sich, nach dem Spiel kommt er wieder nach vorn.

## Was die Bibliothek kann

- Spieleliste links mit Bild, Name und Status (nicht installiert, Version, Update verfügbar, läuft).
- Pro Spiel: großes Titelbild, Beschreibung, **Installieren / Aktualisieren / Spielen**, „Was ist neu“ aus der Release-Beschreibung, installierte und neueste Version, Spielzeit, zuletzt gespielt, Spielordner öffnen, Deinstallieren.
- Spielstart: Das Spiel läuft als eigener Prozess. Die Bibliothek minimiert sich (`minimize_on_play`), merkt, wann das Spiel beendet ist, zählt die Spielzeit und holt sich wieder in den Vordergrund.
- Updates laden mit Fortschrittsbalken, erst in `<spiel>.neu/`, dann wird getauscht. Bricht etwas ab, bleibt die alte Version spielbar. Ohne Internet startet die installierte Version („Ohne Update spielen“).
- Selbst-Update: Ist im neuesten Release eine `launcher-app-<version>.pck` mit höherer Version, lädt die Bibliothek sie herunter und zeigt oben „Launcher-Update …: neu starten“.

## Ein neues Spiel hinzufügen

1. Das Spiel bekommt ein eigenes, öffentliches GitHub-Repo mit dem Godot-Projekt in `game/`.
2. `vorlagen/spiel-release.yml` dorthin nach `.github/workflows/release.yml` kopieren und oben `SPIEL_ID` und `PACK` eintragen. Eine Zahl in `VERSION` pushen baut das Release `<id>-v<version>-game.zip`.
3. Einen Eintrag in `launcher/games.json` (in diesem Repo) ergänzen und nach main pushen. Die Bibliothek lädt die Liste bei jedem Start von GitHub, ein neues Launcher-Release braucht es dafür nicht.

```json
{
  "id": "mein-spiel",
  "name": "Mein Spiel",
  "repo": "NoName1312a/mein-spiel",
  "pack": "MeinSpiel.pck",
  "description": "Ein Satz, worum es geht.",
  "cover_url": "https://raw.githubusercontent.com/NoName1312a/mein-spiel/main/cover.png"
}
```

| Schlüssel | Bedeutung |
|---|---|
| `id` | Eindeutiger Name, zugleich Ordner `games/<id>` und Anfang der Release-Datei |
| `name`, `description` | Was in der Bibliothek steht |
| `repo` | `besitzer/repo` auf GitHub |
| `pack` | Spieldaten (.pck), die mit der Launcher-.exe gestartet werden |
| `cover` / `cover_url` | Titelbild aus dem Launcher (`res://…`) oder aus dem Netz (wird zwischengespeichert), sonst ein Platzhalter |
| `asset_prefix`, `asset_suffix` | Welche Release-Datei das Spiel ist, Standard `<id>-` und `game.zip` |
| `game_args` | Zusätzliche Startparameter |
| `game_exe` | Nur falls `pack` leer ist: eigene Spiel-.exe starten (Achtung Smart App Control, siehe unten) |
| `include_prereleases` | Auch Tags wie `v0.7.0-beta` anbieten |

Wichtig: Jedes Spiel läuft mit der .exe des Launchers und muss deshalb mit derselben Godot-Version gebaut werden (`GODOT_VERSION`, zurzeit 4.4.1). Spielstände gehören in einen eigenen Benutzerordner des Spiels, nie in den Installationsordner.

## Nur eine EXE, und die ist signiert

`KapselLauncher.exe` ist die offizielle, digital signierte Godot-.exe von godotengine.org, nur umbenannt. Godot lädt automatisch die gleichnamige `KapselLauncher.pck` daneben, das ist der Launcher. Spiele kommen nur als Daten (`.pck`) und laufen über dieselbe .exe (`--main-pack`).

Warum so: Windows Smart App Control blockiert jede unsignierte .exe. Die signierte Godot-.exe wird zugelassen. Sie darf deshalb nie verändert werden (kein eingebettetes .pck, kein Icon-Tausch), sonst ist die Signatur ungültig. Der Workflow prüft das bei jedem Release.

## Launcher ändern und verteilen

1. Code in `launcher/` ändern und `const VERSION` in `scripts/version.gd` erhöhen (sonst bekommt niemand das Update).
2. Wie gewohnt ein Release auslösen (`VERSION` im Repo-Hauptordner erhöhen). Der Workflow hängt `launcher-app-<version>.pck` ans Release.
3. Installierte Launcher finden es beim nächsten Start, laden es nach `launcher/app-<version>.pck` und nutzen es nach dem Neustart. `boot.gd` (die Startszene) lädt das Paket; sie selbst wird nie per Update ersetzt und sollte möglichst unverändert bleiben.

Nicht über das Selbst-Update verteilbar: ein Wechsel der Godot-Version und neue `class_name`-Klassen (deshalb nutzt der Code `preload` statt `class_name`). Dann muss jeder die ZIP einmal neu herunterladen.

## Ordner nach der Installation

```
Bibliothek\
  KapselLauncher.exe       <- diese Datei startest du (offizielle Godot-.exe)
  KapselLauncher.pck       <- der Launcher
  launcher_config.json     <- optional, überschreibt die eingebaute Einstellung
  launcher\                <- Selbst-Updates (app-<version>.pck, app.json)
  games\
    kapsel-automat\
      KapselAutomat.pck
      .launcher_version.json
```

Ein alter `game\`-Ordner vom Launcher 1.2 wird beim ersten Start nach `games\kapsel-automat\` verschoben. Den Ordner irgendwohin legen, wo man schreiben darf (z. B. `Dokumente\Spiele\Bibliothek`), nicht nach `C:\Programme`. Sonst weicht der Launcher in seinen Benutzerordner aus. Spielzeit und zwischengespeicherte Spieleliste liegen im Benutzerordner des Launchers (`%APPDATA%\Godot\app_userdata\Spielebibliothek`).

## Einstellungen (`launcher_config.json`)

| Schlüssel | Bedeutung |
|---|---|
| `catalog_url` | Wo die Spieleliste liegt, Standard `launcher/games.json` in diesem Repo |
| `launcher_repo` | Repo, in dessen Releases das Launcher-Update liegt |
| `minimize_on_play` | Beim Spielstart minimieren (Standard `true`) |
| `api_base` | Nur zum Testen (Mock-Server) |
| `token` | Nur für private Repos. Nicht weitergeben, der Token steckt dann in der Datei. |

## Testen

```
tests/run_tests.sh [pfad/zu/godot]
```

Baut ein Testspiel als .pck, startet eine falsche GitHub-API (`tests/mock_github.py`) und prüft die Spieleliste, Versionsvergleich, Erstinstallation und Update mit Umleitung (wie bei GitHub), den Spielstart über `--main-pack` samt Erkennen des Spielendes, Offline-Verhalten und Deinstallieren. Der Workflow führt die Tests vor jedem Release aus.
