# Pixel-Art Kapsel-Automat – Manifest

Stand: 9. Okt 2026. Alle Dateien sind PNG mit transparentem Hintergrund, ohne Kantenglättung, in Originalgröße (nicht vorskaliert).
In Godot: **Projekteinstellungen → Rendering → Textures → Default Texture Filter = Nearest** und nur ganzzahlig skalieren (×2, ×3, ×4).
Alle Größen und Pfade folgen `../art-spec-fuer-spiel.md`. Was dort nicht steht, ist als **Extra** markiert und optional.

Palette: 25 Farbrampen à 6 Töne, Schatten nach Lila verschoben, Lichter nach Gelb. Umriss-Farbe `#1a1024`. GIMP/Aseprite-Palette: `palette.gpl`.
Vorschauen: `preview/figuren_30.png`, `preview/automaten.png`, `preview/icons_ui.png`, `preview/mockup_ingame.png`.
Quellcode der Grafiken (Python/PIL, reproduzierbar): `_quelle/` → `python3 _quelle/build_spec.py <ausgabe> <vorschau>`.

## Laut Spec

| Pfad | Größe | Verwendung / Hinweise |
|---|---|---|
| `figures/<id>.png` (30 Stück) | 64×64 | Figur mittig, Motiv ca. 48×48 mit 8 px Rand. Legendäre haben Krone/Glitzer eingezeichnet. IDs exakt wie in `data/figures.json`. |
| `machines/standard_body.png` | 128×160 | Gehäuse ohne Kuppel und ohne Griff. Kurbel-Drehpunkt (64, 80). Ausgabeschacht unten mittig: Öffnung x 46–82, y 110–132. Preis-Display (dunkles LCD für Text): x 84–107, y 23–33. Kragen für die Kuppel: y 0–9. |
| `machines/glueck_body.png` | 128×160 | Grün/Gold, Kleeblatt-Logo, Münz-Sticker. Gleiche Koordinaten. |
| `machines/spuk_body.png` | 128×160 | Lila, Geister-Logo, Fledermäuse, grüner Schleim tropft vom Kragen, Schacht glüht grün. Gleiche Koordinaten. |
| `machines/<id>_dome.png` | 128×128 | Leere Glaskuppel, halbtransparent. Kugelmitte (64, 68), Radius 58. Glanzlichter liegen in der Datei, die Kuppel also **über** die Kapseln zeichnen (oder Kapseln zwischen zwei Zeichenschritten, dann nur Glanz drüber). Deckel oben y 0–15. Unterkante der Kuppel überlappt den Kragen des Gehäuses. |
| `machines/crank.png` | 48×48 | Kurbelgriff, Drehpunkt Bildmitte (24, 24), Knauf zeigt nach oben. |
| `capsules/top.png` | 24×12 | Obere Hälfte, reine Graustufen (inkl. Umriss) → mit `modulate` einfärben. |
| `capsules/bottom.png` | 24×12 | Untere Hälfte, weiß. |
| `capsules/gold_top.png` | 24×12 | Goldene Oberhälfte (fertig gefärbt). |
| `props/hamster_0.png`, `props/hamster_1.png` | 32×32 | Kurbel-Hamster, schaut nach links, 2 Lauf-Frames (Frame 1 mit Staubwölkchen). |
| `props/tray.png` | 144×32 | Ausgabeschale aus Metall. Kapseln liegen auf der Innenfläche, ca. y 12–22. |
| `ui/coin.png` | 16×16 | Münze. |
| `ui/goldmarke.png` | 16×16 | Prestige-Währung: goldene Siegelmarke mit Stern. |
| `ui/trophy.png` | 16×16 | Erfolge-Icon. |
| `bg/background.png` | 320×180 | Spielhalle bei Nacht: Lichterkette, Streifentapete, Holzvertäfelung, Dielen, Lichtkegel über dem Automaten (x ≈ 80), Einhorn-Poster links, Regal mit Kapseln. Rechts (ab x ≈ 217) ruhig für das UI-Panel. ×4 = 1280×720. |

## Extras (optional, gleicher Stil)

| Pfad | Größe | Verwendung |
|---|---|---|
| `machines/golden_body.png`, `golden_dome.png` | 128×160, 128×128 | Der **Goldene Automat** (Spielziel), gleiche Koordinaten wie die anderen. |
| `machines/crank_glueck.png`, `crank_spuk.png`, `crank_golden.png` | 48×48 | Kurbel passend zum Automaten (Knauf gold / grün / rot). |
| `capsules/curse_top.png`, `bless_top.png` | 24×12 | Fluch-Kapsel (lila mit Totenkopf) und Segen-Kapsel (creme mit Heiligenschein) für den Spuk-Automaten. Mit `bottom.png` kombinieren. |
| `figures/silhouettes/<id>.png` | 64×64 | Dunkle Silhouette für noch nicht gefundene Figuren im Album („???“). |
| `icons/upgrades/<id>.png` (21 Stück) | 32×32 | Ein Icon pro Upgrade-ID aus `data/upgrades.json`: speed (Ölkanne), luck (Feder), value (Politur), tray (Schale +), hamster, combo (Glocke), passive (Vitrine), autoopen (Öffner), double (×2-Kapseln), crit (Zielscheibe), bulk (Alle öffnen), discount (Preisschild), offline (Mond), p_value (Goldprägung), p_start (Sparschwein), p_luck (Kleeblatt-Talisman), p_hamster (Hamster mit Krone), p_fusion (3 Kapseln), p_offline (Laterne), p_spuk (Spuk-Lizenz), p_keep (Buch mit Lesezeichen). |
| `icons/trophy_bronze.png`, `trophy_silver.png`, `trophy_gold.png` | 32×32 | Erfolge in 3 Stufen. |
| `icons/lock.png`, `clock.png`, `gem.png`, `lightning.png`, `magnet.png`, `ticket.png` | 32×32 | Allzweck-Icons (gesperrt, Offline, Prestige, Boost …). |
| `ui/set_badge_<set>.png` (6 Stück) | 16×16 | Set-Symbol: obst, tiere, snacks, weltraum, meer, spuk. |
| `ui/album_slot_<seltenheit>.png`, `..._locked.png` | 40×40 | Album-Kachel mit Seltenheitsfarbe und Edelstein oben rechts. 9-Slice-Ränder: 6 px. |
| `ui/panel_9slice.png`, `panel_dark_9slice.png` | 48×48 | Panel (Goldrahmen) und Listen-Eintrag (dunkel). 9-Slice-Ränder: 6 px (`StyleBoxTexture`, Ränder je 6). |
| `ui/button_<state>.png`, `button_green_<state>.png` | 48×20 | normal / hover / pressed / disabled. 9-Slice-Ränder: 5 px. |
| `ui/progress_bar_bg.png`, `progress_bar_fill.png`, `progress_bar_fill_gold.png` | 64×10 | Fortschrittsbalken (`TextureProgressBar`, 9-Slice 3 px). |
| `ui/new_stamp.png` | 44×22 | „NEU!“-Stempel. |
| `ui/reveal_rays.png` | 128×128 | Weiße Strahlen hinter der Figur, mit Seltenheitsfarbe `modulate`n und langsam drehen. |
| `ui/glow.png` | 64×64 | Weicher Lichtfleck (weiß, zum Einfärben). |
| `ui/coin_spin_sheet.png` | 128×16 | Münze dreht sich, 8 Frames à 16×16. |
| `props/hamster_wheel_sheet.png` | 144×36 | Hamsterrad, 4 Frames à 36×36 (Alternative zum freien Hamster). |
| `particles/sparkle_sheet.png` | 55×11 | Funkeln, 5 Frames à 11×11. |
| `particles/star.png` | 9×9 | Stern-Partikel. |
| `particles/confetti_sheet.png` | 60×5 | 12 Konfetti-Schnipsel à 5×5 (6 Farben × 2 Formen). |
| `particles/puff_sheet.png` | 64×16 | Staubwolke, 4 Frames à 16×16. |

`manifest.json` listet alle Dateien (`{"version": 1, "files": [...]}`).

## Hauptmenü (Nachtrag)

| Pfad | Größe | Verwendung |
|---|---|---|
| `ui/logo.png` | 200×80 | Schriftzug „Kapsel-Automat“ in Gold mit roter 3D-Kante, rote und goldene Kapsel, Glitzer. Gedacht für ×3. |
| `bg/menu_background.png` | 320×180 | Abgedunkelte Spielhalle mit schwebenden Legendär-Figuren und Kapseln an den Rändern. Mitte (x 100–220, y 70–170) bleibt ruhig, dezenter Lichtschein hinter Logo/Knöpfen. ×4. |
| `ui/menu_button_<normal\|hover\|pressed\|disabled>.png` | 96×24 | Goldener Menüknopf, 9-Slice 6 px. Dunkler Text (z. B. `#3c1c14`) liest sich am besten. |
| `icons/settings.png`, `play.png`, `load.png`, `quit.png` | 32×32 | Zahnrad, Play-Pfeil, Ordner, Tür mit Pfeil. |
| `icons/social/steam.png`, `discord.png`, `reddit.png`, `x.png` | 16×16 | Eigene Pixel-Interpretationen der Symbole. Extra: `<name>_24.png` in 24×24. |
| `ui/slider_track.png` | 64×8 | Reglerspur, 9-Slice 3 px. Extra: `ui/slider_fill.png` (goldene Füllung, gleiche Maße) für `TextureProgressBar`/`HSlider`-Füllung. |
| `ui/slider_grabber.png` | 12×12 | Reglerknopf. |
| `ui/checkbox_on.png`, `checkbox_off.png` | 16×16 | Häkchen grün / leer. |
| Extra: `ui/button_steam_<state>.png` | 48×20 | Steam-blauer Knopf für „Auf die Wunschliste“, 9-Slice 5 px. |
| Extra: `icons/ui16/<settings\|sound_on\|sound_off\|music\|fullscreen\|back\|play\|load\|quit\|new>.png` | 16×16 | Kleine Icons für das Einstellungsmenü (Musik, Effekte, stumm, Vollbild, zurück). |

Vorschauen: `preview/hauptmenue.png`, `preview/einstellungen.png`.
