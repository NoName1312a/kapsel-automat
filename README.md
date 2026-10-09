# Kapsel-Automat

Gacha-Kapsel-Incremental in Godot 4.4.

- `game/`: das Spiel
- `launcher/`: Launcher, der das Spiel aus den GitHub-Releases installiert und aktualisiert (siehe `launcher/README.md`)
- `changelog/`: optionale Release-Texte, `changelog/v0.6.0.md` wird zur Beschreibung von Release v0.6.0

## Neue Version veröffentlichen

```
git tag v0.6.0
git push origin v0.6.0
```

Oder: Versionsnummer in der Datei `VERSION` ändern (z. B. `0.6.0`) und nach `main` pushen.

Oder ohne Git-Befehle: auf GitHub unter **Actions → Release → Run workflow** die Version (z. B. `v0.6.0`) eintragen.

GitHub Actions baut Spiel und Launcher und legt das Release an. Der Launcher bietet das Update beim nächsten Start an.

## Spielen

Aus dem neuesten Release `kapsel-launcher-windows.zip` herunterladen, in einen eigenen Ordner entpacken (z. B. `Dokumente\Spiele\Kapsel-Automat`) und `KapselLauncher.exe` starten.
