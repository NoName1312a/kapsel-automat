# Kapsel-Automat – Prototyp v0.6 (Godot 4.4)

Kurbel drehen → Kapsel fällt → öffnen → Figur ins Album. Dazu Wirtschaft mit passivem Einkommen, 3 Automaten, Neueröffnung (Prestige), Fusion und 30 Erfolge.
**v3: mit Pixel-Art** aus dem Grafik-Thread (Ordner `art/`, Details in `art/manifest.md`): 4 Automaten-Skins, 30 Figuren, Hintergrund, Kapseln inkl. Fluch/Segen, Hamster, Upgrade-Icons, Album-Kacheln mit Silhouetten, Pokale, Set-Abzeichen, Knöpfe und Rahmen. Alles wird ×2 bzw. ×3 mit Nearest-Filter dargestellt.
Fehlt eine Grafik, zeichnet das Spiel den alten Platzhalter.
**v4: Hauptmenü, Einstellungen, Pausenmenü, echte Sounds und Musik** aus dem Sound-Thread (`audio/`). Fehlt ein Sound, erzeugt das Spiel einen Platzhalter per Code.
**v5: Welten-Update** für lange Spielzeit: 4 Welten mit je eigenem Album (192 Figuren), 12 Automaten mit eigenen Mechaniken, mehrere Automaten gleichzeitig, Automaten-Stufen, Story (Tante Gerda und Hamster Krümel), neue Kapseln und Animationen, neu geordnete Seitenleiste. Plan: `../design-v5-welten.md`.
**v0.6 (nach Leons Test):** Upgrades gelten pro Automat und haben viel mehr Stufen, Upgrade-Gruppen lassen sich auf- und zuklappen (fertige Upgrades werden zur schmalen Zeile), Story per Mausklick weiter, Auflösung 720p/900p/1080p, leisere Effekte mit Begrenzer, „Alles fusionieren“, „Willkommen zurück“ als Fenster mit Bild, **Mini-Modus** (Taste M oder Knopf „Mini“).

## Links für Steam, Discord, Reddit, X eintragen
Alle vier Links stehen in **`data/links.json`**. Dort die Platzhalter (`DEINE_APP_ID`, `DEIN_EINLADUNGSCODE` …) durch die echten Adressen ersetzen. Solange ein Link noch „DEIN“ enthält, zeigt der Knopf nur „Link kommt bald!“ statt den Browser zu öffnen.

## Mini-Modus
Knopf **Mini** oben oder Taste **M**: Das Fenster wird klein, randlos und bleibt im Vordergrund, unten rechts über der Taskleiste (wie TaskbarHero). Darin: Automat gedrückt halten zum Kurbeln (oder Leertaste), Kapseln öffnen sich von selbst, die drei günstigsten Upgrades direkt kaufen, mit ◀ ▶ zwischen aufgestellten Automaten wechseln, am Rand ziehen zum Verschieben, **Groß** (oder M) zurück. Code: `scripts/mini_mode.gd`.

## Menüs
- **Hauptmenü** (Startszene `menu.tscn`): Neues Spiel (fragt nach, wenn schon ein Spielstand existiert), Spiel laden (grau ohne Spielstand), Einstellungen, Auf Steam wunschlisten, Beenden, unten rechts Discord / Reddit / X.
- **Einstellungen** (im Hauptmenü, im Spiel über das Zahnrad oben links oder über Esc → Einstellungen): Gesamtlautstärke, Musik, Effekte, Bildschirmwackeln (0–100 %), Auflösung (720p, 900p, 1080p im Fenster; nie größer als der Bildschirm), Vollbild. Gespeichert in `user://settings.cfg`.
- **Pausenmenü** im Spiel mit **Esc** oder dem Knopf „Menü“: Weiter, Einstellungen, Hauptmenü (speichert), Spielstand löschen, Speichern & Beenden. Das Spiel läuft im Hintergrund weiter (Idle-Spiel).

## Audio
- Busse: `Master` → `Music` und `SFX` (mit leichtem Hall). Lautstärken kommen aus den Einstellungen.
- Effekte: `audio/sfx/<name>.wav|ogg`, Varianten `<name>_1`, `<name>_2` … werden zufällig gewählt. Musik: `audio/music/<name>.ogg`, läuft als Loop mit Überblendung.
- Musik je Szene: `menu` im Hauptmenü, `game` am Standard-Automaten, `glueck` und `spuk` an den anderen Automaten, `golden` nach dem Goldenen Automaten. Fehlt eine Datei, läuft `game`.
- Jeder Knopf, Regler und Tab klingt automatisch (`ui_click`, `ui_hover`, `ui_slider`, `ui_tab`, `ui_toggle_on/off`). Namen und Anlässe: `../audio-spec-fuer-spiel.md`.

## Starten
1. Godot 4.4 (Standard-Version, nicht .NET) von https://godotengine.org/download laden.
2. Im Projektmanager **Importieren** → `project.godot` in diesem Ordner wählen.
3. **F5** drücken: startet im Hauptmenü. (`main.tscn` mit F6 startet direkt im Spiel mit dem letzten Spielstand.)

## Steuerung
- **Kurbel gedrückt halten** oder **Leertaste**: dreht gleichmäßig. **Im Uhrzeigersinn ziehen** dreht schneller.
- **Kapsel anklicken** oder **E**: öffnen. **A**: alle öffnen (nach Upgrade „Sammelöffner“).
- **Esc**: Menü (bzw. offenes Fenster schließen).
- **F1**: Münzen verdoppeln (+1000), nur zum Testen.

## Spielsysteme
**Wirtschaft**
- Jede Figur im Album bringt **passives Einkommen**. Duplikate erhöhen ihre Stufe (1, 2, 4, 8 … Stück).
- Multiplikatoren: Upgrades, komplette Sets (+15 % je Set), Erfolge (+2 % je Erfolg), Goldmarken (+3 % je jemals verdienter Marke).
- **Kombo**: Wer schnell hintereinander öffnet, bekommt +5 % pro Treffer (Obergrenze über „Kombo-Glocke“). Eine Niete bricht die Kombo.
- **Offline-Einnahmen**: 50 % des Album-Einkommens für bis zu 2 h (mehr über Upgrades). Begrüßung beim Start.
- Große Zahlen werden als K, Mio, Mrd, Bio … angezeigt.

**Welten** (Knopf oben links oder Tab „Welten“): Spielhalle → Tropeninsel → Eisgipfel → Sternenstation. Reisen kostet Münzen und braucht 4 komplette Sets der aktuellen Welt. Freigeschaltete Welten bleiben nach einer Neueröffnung. Jede Welt hat Hintergrund, Musik, Kapsel-Design und ein Album mit 6 Sets × 8 Figuren (3 gewöhnlich, 2 selten, 2 episch, 1 legendär).

**12 Automaten**, je 3 pro Welt:
| Welt | Automaten |
|---|---|
| Spielhalle | Standard, Glück (Nieten, viel Seltenes), Spuk (Fluch/Segen, braucht Spuk-Lizenz) |
| Tropeninsel | Muschel, Schatz (Nieten + Jackpot x25), Vulkan (Ausbruch: 3 Gratis-Kapseln) |
| Eisgipfel | Schneekugel, Frost (gefrorene Kapseln: 3 Klicks, Wert x2), Nordlicht (viel Segen) |
| Sternenstation | Roboter (Doppelkapseln), Schwerkraft (lange Kombos), Quanten (Chaos) |

**Mehrere Automaten**: Aufstellplätze (Start 1, über „Anbau“ und „Filiale“ bis 6). Der gezeigte Automat wird gekurbelt, die anderen laufen nebenbei von allein (Leiste links, Tab „Automaten“). So füllt man alte Alben weiter, während man in neuen Welten spielt.
**Automaten-Stufen**: Jeder Automat bis Stufe 10 (+30 % Münzen, +25 % Tempo nebenbei je Stufe), Sterne am Sockel und Aufwertungs-Animation.

**Upgrades** in 4 Gruppen, werden nach und nach sichtbar. Kurbel & Schale, Glück & Kombo und Münzen gelten **nur für den gezeigten Automaten** (jeder Automat hat eigene Stufen, Preise wachsen mit dem Wert des Automaten). „Laden“ (Vitrine, Nachtschicht, Anbau, Aushilfe) gilt für alle. Mit „Max“ kauft man so viele Stufen wie möglich.

**Neueröffnung (Prestige)**: Münzen, Upgrades, Automaten und ihre Stufen werden zurückgesetzt, Album, Erfolge und Welten bleiben. Goldmarken kaufen dauerhafte Upgrades, z. B. Fusion, Spuk-Lizenz, Filiale (+1 Platz), Stammpersonal (schnellere Nebenautomaten).

**Fusion** (nach Freischaltung im Album): 3 gewöhnliche Duplikate → 1 seltene Figur, 3 seltene → 1 epische, 4 epische → 1 legendäre.

**Story**: kurze Szenen bei Spielstart, neuen Welten und Automaten, kompletten Sets und Alben, erster legendärer Figur, Neueröffnung und am Ende. Texte in `data/story.json` (vom Story-Thread, lesbar in `../story/story.md`). Krümel meldet sich ab und zu mit einem Spruch, im Album zeigt der Tooltip einen Satz zu jeder Figur.

**Ziel**: Der **Goldene Automat** in der Sternenstation (braucht 150 verschiedene Figuren). Danach weiter Alben füllen und Erfolge sammeln.

**63 Erfolge** mit Popup, Fortschrittsanzeige und Statistik.

## Balancing
Alle Werte stehen in `data/`: `figures.json`, `machines.json`, `upgrades.json` (inkl. Prestige-Shop), `achievements.json`.
`tests/balance_sim.gd` lässt einen Bot spielen (60 % selbst kurbeln, kauft immer das günstigste Upgrade) und meldet die Meilensteine:

| Meilenstein | Bot |
|---|---|
| Album Spielhalle komplett | ~2,4 h |
| Reise Tropeninsel | ~2,9 h |
| Reise Eisgipfel | ~6,9 h |
| Reise Sternenstation | ~13,7 h |
| alle 192 Figuren | ~17,6 h |
| Goldener Automat (Ende) | ~19,6 h |

Der Bot kauft ohne Pause immer optimal; ein Mensch braucht etwa das 1,5- bis 2-Fache, also grob 30–45 Stunden bis zum Ende (v4: 5–8 h).
Stellschrauben: `cost`/`value_mult` in `machines.json`, `travel_cost` und `value_scale` in `worlds.json`, `MACHINE_LEVEL_*` und `PRESTIGE_*` oben in `game_state.gd`.

## Tests
```
godot --headless --path . -s res://tests/smoke_test.gd    # 50 Prüfungen: Spiellogik, Welten, Automaten, Menüs, Sounds
godot --headless --path . -s res://tests/balance_sim.gd   # Balancing-Simulation
godot --path . -s res://tests/screenshots.gd              # Screenshots (Ausgabepfad oben im Skript anpassen)
```

## Dateien
| Datei | Inhalt |
|---|---|
| `scripts/game_state.gd` | Autoload `Game`: Wirtschaft, Upgrades, Automaten, Prestige, Fusion, Erfolge, Speichern |
| `scripts/main.gd` | Automat, Kapseln, Eingabe, Effekte |
| `scripts/ui.gd` | Seitenleiste mit Tabs, Album, Erfolge, Popups |
| `scripts/art.gd` | Autoload `Art`: lädt Pixel-Art (auch hochskaliert und als 9-Slice), sonst Platzhalter |
| `art/` | Pixel-Art (Kopie aus `../art/`, ohne Quellen und Vorschauen) |
| `scripts/menu.gd`, `menu.tscn` | Hauptmenü |
| `scripts/settings.gd` | Autoload `Settings`: Lautstärken, Vollbild, Bildschirmwackeln, Audio-Busse |
| `scripts/settings_panel.gd` | Einstellungs-Fenster (Hauptmenü und Spiel) |
| `scripts/links.gd`, `data/links.json` | Externe Links (Steam, Discord, Reddit, X) |
| `scripts/sfx.gd` | Autoload `Sfx`: lädt Sounds und Musik aus `audio/`, sonst Platzhalter per Code |
| `scripts/procedural_music.gd` | Platzhalter-Musik, falls keine Musikdatei da ist |
| `audio/` | Sounds und Musik (Kopie aus `../audio/`, ohne Quellen) |
| `scripts/fmt.gd` | Zahlenformat |
| `scripts/story.gd`, `data/story.json` | Autoload `Story`: Szenen, Sprecher, Sprüche, Figurentexte |
| `scripts/fx.gd` | Animationen (Legendär, Aufwertung, Jackpot, Ausbruch) aus `art/fx/`, sonst gezeichnet |
| `data/worlds.json` | Welten: Reisekosten, Hintergrund, Musik, Farbe |
| `scripts/machine.gd`, `capsule.gd`, `figure_view.gd` | Zeichnen von Automat, Kapsel, Figur |

Speichern: Autosave alle 10 s und beim Beenden, atomar mit Backup (`save.json` / `save.bak`). Alte Spielstände aus v1–v4 werden übernommen.

Für einen Export im Export-Dialog unter „Ressourcen → Filter für Nicht-Ressourcen-Dateien“ `*.json` eintragen, falls die Daten im Export fehlen.
