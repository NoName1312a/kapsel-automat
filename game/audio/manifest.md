# Audio für den Kapsel-Automaten

Alle Sounds und Musikstücke sind **selbst synthetisiert** (Python/numpy, keine fremden Samples). Damit gibt es keine Lizenzfragen: frei verwendbar, auch kommerziell auf Steam. Quellcode in `_quelle/`, neu erzeugen mit `python3 _quelle/build.py` (einzelne Namen als Argumente gehen auch).

Namen und Ordner folgen `../audio-spec-fuer-spiel.md`: Effekte in `sfx/<name>.wav` (Varianten `name_1`, `name_2` …), Musik in `music/<name>.ogg`. Den ganzen Ordner nach `kapsel-prototyp/audio/` kopieren, der Loader in `scripts/sfx.gd` findet alles automatisch.

**Technik:** 44,1 kHz, 16 bit. Effekte als WAV (kein Vorlauf, sofortiger Einsatz), kurze Effekte mono, Jingles mit Hall/Panorama stereo. Lautheit pro Gruppe abgestimmt (LUFS-Spalte), Effekt-Spitzen höchstens −3 dBFS. Musik −19 LUFS, Spitzen ≤ −1 dBFS, OGG Vorbis q6.

**Loops:** Alle Musikstücke loopen nahtlos über die ganze Datei (Loop-Start 0, Loop-Ende = Dateiende; der Hall-Ausklang ist an den Anfang gefaltet). Der Loader setzt `loop = true` selbst; wer im Import-Dialog arbeitet: *Loop* an, *Loop Offset* 0. `sfx/hamster_wheel.wav` ist ebenfalls ein Loop (Import: Loop Mode *Forward*).

## Effekte aus der Spec (Bus SFX)

| Name | Dateien | Wann | Länge | LUFS |
|---|---|---|---|---|
| `tick` | `sfx/tick_1.wav`, `sfx/tick_2.wav`, `sfx/tick_3.wav` | Kurbel rastet ein (Ratsche), zufällige Variante | 0.09 s | -25.2 |
| `clunk` | `sfx/clunk_1.wav`, `sfx/clunk_2.wav`, `sfx/clunk_3.wav` | Kapsel fällt in die Schale (Aufprall bei 0,2 s passt zur Bounce-Animation) | 1.17 s | -22.2 |
| `pop` | `sfx/pop_1.wav`, `sfx/pop_2.wav` | Kapsel aufdrehen + Plopp | 0.96 s | -20.0 |
| `coin` | `sfx/coin_1.wav`, `sfx/coin_2.wav`, `sfx/coin_3.wav` | Münzen gutgeschrieben (zweitönig, Variante) | 1.03 s | -21.0 |
| `deny` | `sfx/deny.wav` | Geht nicht: zu wenig Geld, Schale voll | 0.23 s | -22.0 |
| `chime_common` | `sfx/chime_common.wav` | Figur enthüllt: gewöhnlich | 1.15 s | -20.0 |
| `chime_rare` | `sfx/chime_rare.wav` | Figur enthüllt: selten | 2.67 s | -18.0 |
| `chime_epic` | `sfx/chime_epic.wav` | Figur enthüllt: episch | 3.28 s | -17.0 |
| `chime_legendary` | `sfx/chime_legendary.wav` | Figur enthüllt: legendär (große Fanfare) | 3.86 s | -16.0 |
| `set_complete` | `sfx/set_complete.wav` | Set im Album komplett | 3.29 s | -17.0 |
| `achievement` | `sfx/achievement.wav` | Erfolg freigeschaltet | 2.87 s | -17.0 |
| `prestige` | `sfx/prestige.wav` | Neueröffnung (Prestige): Aufbau + großer Akkord | 4.71 s | -17.0 |
| `bless` | `sfx/bless.wav` | Segen-Kapsel (x3): Harfe aufwärts + Engelschor | 3.13 s | -17.0 |
| `curse` | `sfx/curse.wav` | Fluch-Kapsel (Spuk-Automat): dunkles Grollen + Geister-Glissando | 3.13 s | -17.0 |
| `empty` | `sfx/empty.wav` | Niete / leere Kapsel (kurz, weil im Glücksautomat häufig) | 1.39 s | -21.0 |
| `crit` | `sfx/crit.wav` | Glückstreffer x5: Schlag + Münz-Klirren | 1.23 s | -17.0 |
| `double` | `sfx/double.wav` | Doppelkapsel: doppeltes Plopp mit Echo | 1.23 s | -19.0 |
| `combo` | `sfx/combo.wav` | Kombo steigt (Grundton C5; das Spiel erhöht die Tonhöhe pro Stufe) | 1.05 s | -21.0 |
| `upgrade` | `sfx/upgrade.wav` | Upgrade / Automat gekauft (Kassen-Kaching) | 1.09 s | -17.0 |
| `unlock` | `sfx/unlock.wav` | Neuer Automat freigeschaltet: Motor läuft an + Lichter an | 2.43 s | -17.0 |
| `fusion` | `sfx/fusion.wav` | Fusion: drei Figuren verschmelzen zu einer | 3.68 s | -17.0 |
| `ui_click` | `sfx/ui_click.wav` | Knopf geklickt | 0.08 s | -25.2 |
| `ui_hover` | `sfx/ui_hover.wav` | Maus über Knopf (sehr leise) | 0.04 s | -23.9 |
| `ui_open` | `sfx/ui_open.wav` | Fenster/Menü öffnen (Einstellungen, Album, Erfolge) | 1.13 s | -22.0 |
| `ui_close` | `sfx/ui_close.wav` | Fenster/Menü schließen | 1.13 s | -22.0 |
| `golden` | `sfx/golden.wav` | Goldener Automat gebaut (Finale) | 6.85 s | -17.0 |

## Zusätzliche Effekte (Bus SFX, noch nicht im Spiel verdrahtet)

| Name | Datei | Vorschlag, wann |
|---|---|---|
| `clunk_gold` | `sfx/clunk_gold.wav` | Goldene (legendäre) Kapsel fällt: Aufprall + Glitzern |
| `pop_gold` | `sfx/pop_gold.wav` | Goldene Kapsel öffnen: kurzer Glitzer-Aufzug vor dem Plopp |
| `new_figure` | `sfx/new_figure.wav` | "NEU!"-Stempel bei einer neuen Figur |
| `coin_big` | `sfx/coin_big.wav` | Münzregen (großer Gewinn, Offline-Einnahmen, Verkauf) |
| `combo_break` | `sfx/combo_break.wav` | Kombo bricht ab |
| `machine_switch` | `sfx/machine_switch.wav` | Automat wechseln |
| `offline_welcome` | `sfx/offline_welcome.wav` | Begrüßung mit Offline-Einnahmen |
| `hamster_squeak` | `sfx/hamster_squeak.wav` | Hamster quiekt (ab und zu, wenn der Kurbel-Hamster läuft) |
| `hamster_wheel` | `sfx/hamster_wheel.wav` | Hamsterrad rattert leise (nahtloser Loop, 2 s, leise mischen) |
| `ui_back` | `sfx/ui_back.wav` | Zurück / Abbrechen / Schließen-Knopf |
| `ui_confirm` | `sfx/ui_confirm.wav` | Bestätigen ("Neues Spiel", "Spiel laden", Kauf bestätigt) |
| `ui_tab` | `sfx/ui_tab.wav` | Tab wechseln (Upgrades / Automaten / Neueröffnung / Album) |
| `ui_toggle_on` | `sfx/ui_toggle_on.wav` | Schalter an (Einstellungen) |
| `ui_toggle_off` | `sfx/ui_toggle_off.wav` | Schalter aus (Einstellungen) |
| `ui_slider` | `sfx/ui_slider.wav` | Lautstärke-Regler (Vorhörton beim Ziehen, max. alle 80 ms abspielen) |
| `album_page` | `sfx/album_page.wav` | Album umblättern / Album öffnen |
| `toast` | `sfx/toast.wav` | Hinweis-Popup ("Neues Upgrade" usw.) |
| `menu_start` | `sfx/menu_start.wav` | "Neues Spiel" gestartet: kurzer Start-Jingle |

## Musik (Bus Music)

| Name | Datei | Wofür | Länge |
|---|---|---|---|
| `menu` | `music/menu.ogg` | Hauptmenü (F-Dur, 88 BPM, gemütlich) | 87.27 s |
| `game` | `music/game.ogg` | Im Spiel / Standard-Automat (C-Dur, 100 BPM, entspannt, 64 Takte) | 153.6 s |
| `spuk` | `music/spuk.ogg` | Spuk-Automat: dieselbe Spielmusik in c-Moll mit Cembalo, Orgel, Theremin | 83.48 s |
| `glueck` | `music/glueck.ogg` | Extra: Glücksautomat (G-Dur Swing, 120 BPM, Lounge/Weltraum) | 64.0 s |
| `golden` | `music/golden.ogg` | Extra: Goldener Automat / nach dem Finale (D-Dur, 124 BPM, triumphal) | 61.94 s |
| `spuk_walzer` | `music/spuk_walzer.ogg` | Extra: eigenständiger Spuk-Walzer (d-Moll, 3/4, Theremin), Alternative zu spuk | 41.74 s |

## Hinweise für den Einbau
- `combo` ist ein einzelner Ton (C5); das Spiel erhöht wie geplant die Tonhöhe pro Kombo-Stufe. Bei `pitch_scale = 2^(stufe/12)` klingt es wie eine Tonleiter.
- `clunk` hat den Hauptaufprall bei 0,2 s und zwei kleine Nachhüpfer bei 0,4 s und 0,5 s, passend zur Bounce-Animation (0,55 s).
- `pop` hat das Plopp bei ca. 0,06 s, passend zum Stauchen der Kapsel in `capsule.gd`.
- Für goldene Kapseln gibt es `clunk_gold` und `pop_gold` (mit Glitzern), z. B. `Sfx.play("clunk_gold" if c.gold else "clunk")`.
- `ui_slider` passt besser zum Lautstärkeregler als das bisherige `tick` mit Pitch 1.4.
- Musik für Glücks- und Goldenen Automaten (`glueck`, `golden`) liegt bereit; aktuell spielt das Spiel nur `menu`, `game` und `spuk`. `spuk_walzer` ist eine eigenständige Alternative zu `spuk`.
