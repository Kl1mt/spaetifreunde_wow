# In-Game-Test – Checkliste

Das Addon kann im Container nicht im Spiel getestet werden. Bitte diese Liste im Spiel abarbeiten
und Ergebnisse (✅ / ❌ + Notiz, Screenshot oder Fehlertext) zurückmelden.

**Vorbereitung**
- Neuestes Zip aus GitHub (Release oder CI-Artefakt) nach
  `World of Warcraft\_forever_\Interface\AddOns\SpaetiFreunde\` entpacken.
  Die Datei `SpaetiFreunde.toc` muss direkt in diesem Ordner liegen.
- Im Chat einmal `/console scriptErrors 1` eingeben (zeigt Lua-Fehler an).
- Am besten zu zweit testen: eine Person bleibt online, die andere loggt sich aus und wieder ein.

---

## M1 „Erster Kunde“

### Installation & Laden
| # | Test | Erwartet | Ergebnis |
|---|---|---|---|
| I1 | Charakterauswahl → AddOns | „Spätifreunde Spandau“ (orange) erscheint, ggf. als „veraltet“. Bitte notieren, ob „veraltet“ steht. | |
| I2 | Einloggen | Keine Lua-Fehler. | |
| I3 | `/reload` | Keine Lua-Fehler, Fenster-Position und Einstellungen bleiben erhalten. | |
| I4 | Echter Pfad | Heißt der Ordner wirklich `_forever_`? Wenn nicht: richtigen Pfad notieren. | |

### Begrüßung
| # | Test | Erwartet | Ergebnis |
|---|---|---|---|
| G1 | Einloggen, ca. 6 Sekunden warten | Genau **eine** Zeile „Späti hat offen! …“ plus Anzahl der Leute im Laden. Kein Spam. | |
| G2 | Gildenmitglied loggt ein (Mitspieler) | Innerhalb von ca. 1 Minute erscheint lokal z. B. „Kalle kommt rein. Moin!“ mit **[Willkommen sagen]**. Andere sehen davon nichts. | |
| G3 | Auf **[Willkommen sagen]** klicken | Ein Gruß erscheint im **Gildenchat**. Kein „Aktion blockiert“-Fenster. | |
| G4 | Nicht klicken | Es wird **nichts** automatisch in die Gilde gepostet. | |
| G5 | `/spaeti willkommen` | Begrüßt das zuletzt eingeloggte Mitglied im Gildenchat. | |
| G6 | In einem Dungeon jemand loggt ein | Keine Online-Meldung (Standard: in Instanzen stumm). | |
| G7 | Name mit Nachname (Forever) | Name wird vollständig und korrekt angezeigt (z. B. „Vorname Nachname“). Bitte genaue Schreibweise notieren. | |

### Sprüche
| # | Test | Erwartet | Ergebnis |
|---|---|---|---|
| S1 | `/spruch` und `/spaeti spruch` | Ein Berliner Spruch in Anführungszeichen, nur lokal. Mehrmals: keine direkte Wiederholung. | |
| S2 | `/spruch` | Niemand sonst in der Gilde sieht den Spruch. | |

### Befehle
| # | Test | Erwartet | Ergebnis |
|---|---|---|---|
| C1 | `/spaeti` | Hauptfenster öffnet/schließt sich. | |
| C2 | `/späti` (mit ä) | Funktioniert genauso wie `/spaeti`. Falls nicht: notieren! | |
| C3 | `/spaeti hilfe` | Liste aller Befehle auf Deutsch. | |
| C4 | `/spaeti status` | Version, Interface, Gilde, Rang, Offizier ja/nein, Chat-Sperre, Secret-Values-Schutz, Einstellungsmenü. **Bitte komplette Ausgabe kopieren/screenshotten.** | |
| C5 | `/spaeti quatsch` | Hinweis „Unbekannter Befehl …“. | |
| C6 | Offizier-Check | Gildenmeister und Rang „Officer“ → „Offizier: ja“, alle anderen → „nein“. | |

### Fenster, Minimap, Addon-Fach
| # | Test | Erwartet | Ergebnis |
|---|---|---|---|
| U1 | Hauptfenster | Tabs Start, Punkte, Online, Info. Punkte/Online zeigen „Kommt bald!“. | |
| U2 | Fenster verschieben, `/reload` | Fenster ist wieder an derselben Stelle. | |
| U3 | ESC | Schließt das Fenster. | |
| U4 | Start-Tab: „Spruch zeigen“ | Lokaler Spruch, nur für dich. | |
| U5 | Minimap-Knopf (Getränke-Symbol) | Linksklick: Fenster; Rechtsklick: Einstellungen; ziehen: Knopf wandert am Rand. Position bleibt nach `/reload`. | |
| U6 | Umlaute | „ä ö ü ß“ und „„…““ werden überall korrekt angezeigt (Chat, Fenster, Tooltip). | |
| U7 | Addon-Fach (Knopf an der Minimap mit allen Addons) | Eintrag „Spätifreunde Spandau“ mit Symbol, Tooltip beim Drüberfahren, Klick öffnet Fenster. | |

### Einstellungen
| # | Test | Erwartet | Ergebnis |
|---|---|---|---|
| O1 | Esc → Optionen → AddOns → Spätifreunde Spandau (oder `/spaeti optionen`) | Fünf Häkchen: Begrüßung, Online-Meldungen, Willkommen-Link, Instanzen, Minimap-Knopf. | |
| O2 | Häkchen ändern, ausloggen, einloggen | Einstellungen bleiben erhalten. | |
| O3 | „Begrüßung beim Einloggen“ aus, `/reload` | Keine Begrüßungszeile mehr. | |
| O4 | „Minimap-Knopf anzeigen“ aus | Knopf verschwindet sofort. | |
| O5 | Info-Tab im Fenster | Dieselben Häkchen, synchron mit dem Optionsmenü. | |

---

## Was die Probe (S1) bestätigen soll
Diese Punkte sind im Code mit `VERIFY IN-GAME` markiert:
- Interface-Nummer `16001` und AddOns-Pfad `_forever_`.
- `C_ChatInfo.InChatMessagingLockdown` vorhanden? Wann ist sie `true` (ganze Instanz oder nur Bosskampf)?
- `C_ChatInfo.SendChatMessage` vs. `SendChatMessage`: Gildenpost aus Slash-Befehl, Button-Klick **und** Chat-Link-Klick erlaubt?
- `issecretvalue` vorhanden?
- Slash-Befehl mit Umlaut (`/späti`).
- Namensformat in der Gildenliste (Nachname, Realm-Suffix?) und ob `Ambiguate` den Namen verändert.
- `C_GuildInfo.GuildRoster`, Felder von `GetGuildRosterInfo` (GUID an Position 17, `isMobile`).
- Settings-API (`RegisterVerticalLayoutCategory`, `RegisterAddOnSetting`, `CreateCheckbox`, `OpenToCategory`).
- Addon-Fach (`AddonCompartmentFunc` in der TOC), Vorlage `BasicFrameTemplateWithInset`, Symbol `INV_Drink_05`.
- `addon:`-Chatlinks über `EventRegistry` „SetItemRef“.
