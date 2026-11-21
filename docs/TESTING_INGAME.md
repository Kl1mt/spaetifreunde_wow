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
| G2 | Gildenmitglied loggt ein (Mitspieler) | Innerhalb von ca. 1 Minute erscheint lokal z. B. „Kalle kommt rein. Moin!“. Andere sehen davon nichts. | |
| G3 | Allgemein | Das Addon postet **nie** etwas in den Gildenchat. | |
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
| U1 | Hauptfenster | Tabs Start, Punkte, Online, Info. Online zeigt „Kommt bald!“ (Punkte: siehe M2). | |
| U2 | Fenster verschieben, `/reload` | Fenster ist wieder an derselben Stelle. | |
| U3 | ESC | Schließt das Fenster. | |
| U4 | Start-Tab: „Spruch zeigen“ | Lokaler Spruch, nur für dich. | |
| U5 | Minimap-Knopf (Getränke-Symbol) | Linksklick: Fenster; Rechtsklick: Einstellungen; ziehen: Knopf wandert am Rand. Position bleibt nach `/reload`. | |
| U6 | Umlaute | „ä ö ü ß“ und „„…““ werden überall korrekt angezeigt (Chat, Fenster, Tooltip). | |
| U7 | Addon-Fach (Knopf an der Minimap mit allen Addons) | Eintrag „Spätifreunde Spandau“ mit Symbol, Tooltip beim Drüberfahren, Linksklick öffnet Fenster. | |
| U8 | Addon-Fach: **Rechtsklick** auf den Eintrag | Öffnet die Einstellungen (nicht das Fenster). | |

### Einstellungen
| # | Test | Erwartet | Ergebnis |
|---|---|---|---|
| O1 | Esc → Optionen → AddOns → Spätifreunde Spandau (oder `/spaeti optionen`) | Sechs Häkchen: Begrüßung, Online-Meldungen, Instanzen, Minimap-Knopf, Dankeschön-Meldungen, Ton bei Dankeschön. | |
| O2 | Häkchen ändern, ausloggen, einloggen | Einstellungen bleiben erhalten. | |
| O3 | „Begrüßung beim Einloggen“ aus, `/reload` | Keine Begrüßungszeile mehr. | |
| O4 | „Minimap-Knopf anzeigen“ aus | Knopf verschwindet sofort. | |
| O5 | Info-Tab im Fenster und Optionsmenü gleichzeitig offen, Häkchen im Info-Tab ändern | Das Optionsmenü zeigt sofort denselben Stand (und umgekehrt). | |

---

## M2 „Stammkunde“ – Spätipunkte

**Vorbereitung:** mindestens **2 Spieler** (besser 3) mit der neuen Version. Ideal: einer mit
**deutschem** und einer mit **englischem** Client (enUS), dazu ein Offizier bzw. der Gildenmeister.
Wer ist A/B/C? Bitte in den Ergebnissen notieren (Name, Client-Sprache, Rang).
Nach jedem Test-Block kurz `/spaeti status` ansehen (Zeile „Spätipunkte: … Einträge, Warteschlange …,
Drossel …“). **Drossel** sollte immer 0 bleiben.

### Bedanken
| # | Test | Erwartet | Ergebnis |
|---|---|---|---|
| P1 | A: `/spaeti danke <Vorname von B>` | A sieht „Danke an … ist raus (+1 Spätipunkt). Heute noch 2 übrig.“ B sieht **lokal** z. B. „A hat sich bei dir bedankt! +1 Spätipunkt.“ plus kurzen Ton. **Im Gildenchat erscheint nichts.** | |
| P2 | A: `/spaeti danke <voller Name von B in Kleinbuchstaben>` | „Bei B hast du dich heute schon bedankt.“ (1× pro Person und Tag) | |
| P3 | A: sich selbst danken | „Bei dir selbst bedanken? Nee …“ | |
| P4 | A: `/spaeti danke` mit nur 1–2 Buchstaben, die auf mehrere passen | Liste „Mehrere passen: …“ mit Namen | |
| P5 | A: `/spaeti danke Quatschname` | „Keen Gildenmitglied „Quatschname“ gefunden.“ | |
| P6 | A dankt zwei weiteren Leuten (auch Offline-Mitglieder gehen), dann einer vierten Person | Die vierte wird abgelehnt: „Du hast heute schon 3-mal Danke gesagt …“ | |
| P7 | Name mit Umlaut (falls vorhanden), z. B. `/spaeti danke jürgen` bzw. `JÜRGEN` | Wird gefunden | |
| P8 | Punkte-Tab bei A, B, C vergleichen | Alle sehen **dieselben** Punktzahlen in der Rangliste und denselben „Stammkunde des Monats“ | |

### Punkte-Tab
| # | Test | Erwartet | Ergebnis |
|---|---|---|---|
| T1 | `/spaeti punkte` bzw. Tab „Punkte“ | Eigene Punkte + Rang (z. B. „Laufkundschaft“), Balken + „Noch X bis …“, Stammkunde des Monats, Rangliste (alle Mitglieder), letzte Dankeschöns, Sync-Zeile unten | |
| T2 | Name in der Rangliste anklicken, dann „Danke!“ (oder Enter) | Name steht im Eingabefeld; Danke wird wie per Befehl verschickt | |
| T3 | Mausrad / Pfeile über der Rangliste und den letzten Dankeschöns | Liste scrollt; keine Lua-Fehler. Falls die Pfeile fehlen oder komisch aussehen: Screenshot | |
| T4 | Sync-Zeile nach ca. 1 Minute | „Sync: bereit · N Einträge · zuletzt …“ | |
| T5 | Optionen: „Dankeschön-Meldungen“ / „Ton bei Dankeschön“ aus, B dankt dir | Keine Chatzeile bzw. kein Ton; Punkte zählen trotzdem | |
| T6 | Fenstergröße, Umlaute, Texte | Alles lesbar, nichts abgeschnitten (sonst Screenshot) | |

### Offline-Mitglied holt auf (Sync)
| # | Test | Erwartet | Ergebnis |
|---|---|---|---|
| Y1 | C ist **offline**. A und B danken C (und sich gegenseitig – am nächsten Tag geht's wieder) | – | |
| Y2 | C loggt ein, ca. **1 Minute** warten | C sieht „X hat sich bei dir bedankt“ (bzw. „Während du weg warst: N neue Dankeschöns“). Rangliste bei C = Rangliste bei A und B | |
| Y3 | A loggt aus, B dankt jemandem, A loggt wieder ein (1 Minute warten) | A hat den neuen Eintrag (Einträge-Zahl in `/spaeti status` bei allen gleich) | |
| Y4 | `/reload` bei allen | Punkte bleiben erhalten | |
| Y5 | Jemand mit der **alten** Addon-Version (M1) online | Keine Fehler bei irgendwem | |

### Offiziere
| # | Test | Erwartet | Ergebnis |
|---|---|---|---|
| V1 | Normales Mitglied: Punkte-Tab | Keine „Storno“-Knöpfe bei den letzten Dankeschöns | |
| V2 | Offizier/Gildenmeister: Punkte-Tab | „Storno“-Knopf je Zeile. Einmal klicken → „Sicher?“, nochmal klicken → „Dankeschön von X an Y storniert.“ | |
| V3 | Nach dem Storno (ca. 5 Sekunden) | Bei **allen** zählt der Punkt nicht mehr; der Eintrag verschwindet aus „Letzte Dankeschöns“ | |
| V4 | Wer storniert hat, verliert den Offiziersrang (nur wenn ihr das testen wollt) | Das Storno zählt dann nicht mehr (Punkt ist wieder da) – so gewollt | |

### Tagesgrenze, Sperren, Sprachen
| # | Test | Erwartet | Ergebnis |
|---|---|---|---|
| D1 | Nach **Mitternacht (Berliner Zeit)** | Wieder 3 Dankeschöns möglich, auch an dieselbe Person wie gestern | |
| D2 | In einem **Dungeon** (und wenn möglich im Bosskampf) jemandem danken | Entweder sofort verschickt, oder Hinweis „Chat-Sperre aktiv – wird verschickt, sobald es wieder geht“ und nach dem Kampf/Dungeon kommt es an. **Bitte notieren, was passiert** (und `/spaeti status` → „Chat-Sperre: ja/nein“ im Dungeon/Bosskampf) | |
| D3 | enUS-Client bedankt sich bei deDE-Client und umgekehrt | Funktioniert in beide Richtungen; Texte bleiben deutsch | |
| D4 | Allgemein | Das Addon postet **nie** etwas in Gilde/Sagen/Schreien | |
| D5 | Ende: `/spaeti status` bei allen | Zeile „Spätipunkte: …“ – bitte kopieren. „Drossel“ sollte 0 sein | |

---

## Was die Probe (S1) bestätigen soll
Diese Punkte sind im Code mit `VERIFY IN-GAME` markiert:
- Interface-Nummer `16001` und AddOns-Pfad `_forever_`.
- `C_ChatInfo.InChatMessagingLockdown` vorhanden? Wann ist sie `true` (ganze Instanz oder nur Bosskampf)?
- `issecretvalue` vorhanden?
- Slash-Befehl mit Umlaut (`/späti`).
- Namensformat in der Gildenliste (Nachname, Realm-Suffix?) und ob `Ambiguate` den Namen verändert.
- `C_GuildInfo.GuildRoster`, Felder von `GetGuildRosterInfo` (GUID an Position 17, `isMobile`).
- Settings-API (`RegisterVerticalLayoutCategory`, `RegisterAddOnSetting`, `CreateCheckbox`, `OpenToCategory`).
- Addon-Fach (`AddonCompartmentFunc` in der TOC), Vorlage `BasicFrameTemplateWithInset`, Symbol `INV_Drink_05`.
