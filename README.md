# Spätifreunde Spandau – Gildenaddon

**Späti hat offen!** Das Addon der Gilde *Spätifreunde Spandau* für **World of Warcraft: Forever**.

> Nur für Gildenmitglieder. Siehe [LICENSE](LICENSE).

## Was kann es (Version M1 „Erster Kunde“)?

- **Begrüßung beim Einloggen** – ein zufälliger Berliner Spruch im eigenen Chatfenster.
- **Online-Meldung** – wenn jemand aus der Gilde reinkommt, siehst du es lokal.
- **`/spruch`** – rund 40 Berliner Sprüche. Werden nur dir angezeigt.
- **Hauptfenster** mit Tabs (Start, Punkte, Online, Info), Minimap-Knopf und Eintrag im Addon-Fach.
- **Einstellungen** im Spielmenü (Optionen → AddOns → Spätifreunde Spandau).

## Installation

1. Neuestes Release herunterladen: GitHub → **Releases** → `SpaetiFreunde-x.y.z.zip`.
2. WoW komplett beenden.
3. Zip entpacken, sodass dieser Ordner entsteht:

   ```
   World of Warcraft\_forever_\Interface\AddOns\SpaetiFreunde\SpaetiFreunde.toc
   ```

   Wichtig: Der Ordner muss genau `SpaetiFreunde` heißen und die `.toc` muss direkt darin liegen
   (nicht `SpaetiFreunde\SpaetiFreunde\...`).
   *Hinweis: Den Pfad `_forever_` bitte im eigenen Spielordner prüfen – er ist noch nicht im Spiel bestätigt.*
4. WoW starten, im Charakterauswahl-Bildschirm unten links auf **AddOns** klicken
   und **Spätifreunde Spandau** aktivieren. Falls „veraltet“ angezeigt wird:
   **Veraltete AddOns laden** anhaken.
5. Einloggen – im Chat sollte „Späti hat offen!“ o. Ä. erscheinen.

## Befehle

| Befehl | Wirkung |
|---|---|
| `/spaeti` oder `/späti` | Hauptfenster öffnen/schließen |
| `/spaeti spruch` bzw. `/spruch` | Spruch lokal anzeigen |
| `/spaeti status` | Version, Interface, Gilde, Offizier, Chat-Sperre |
| `/spaeti optionen` | Einstellungen öffnen |
| `/spaeti hilfe` | Hilfe anzeigen |

## Regeln, an die sich das Addon hält

- Es postet **nie** etwas in Gilde, Sagen oder Schreien – alles erscheint nur in deinem eigenen Chatfenster.
- Keine Kampflog-Auswertung, keine Automatisierung.
- Während einer Chat-Sperre (z. B. in Instanzen/Bosskämpfen) wird nichts gesendet; stattdessen kommt ein lokaler Hinweis.

## Fehler melden

Bitte `/console scriptErrors 1` einschalten, Fehlertext kopieren und zusammen mit der Ausgabe von
`/spaeti status` an die Gildenleitung bzw. als GitHub-Issue schicken.

## Für Entwickler

- Lint: `luacheck .`
- Paket bauen: `scripts/build.sh 0.1.0` → `build/SpaetiFreunde-0.1.0.zip`
- Release: Tag `v0.1.0` pushen → GitHub Actions erstellt ein Release mit Zip.
- Test im Spiel: [docs/TESTING_INGAME.md](docs/TESTING_INGAME.md)
