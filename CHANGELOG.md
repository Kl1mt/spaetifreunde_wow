# Changelog

Alle nennenswerten Änderungen am Addon stehen hier.

## [Unveröffentlicht]

### Neu – M2 „Stammkunde“ (Spätipunkte)
- `/spaeti danke <Name>`: bei Gildenmitgliedern bedanken (+1 Spätipunkt). Name voll oder eindeutiger
  Anfang/Vorname, Groß-/Kleinschreibung egal; bei mehreren Treffern kommt eine Auswahl.
- Grenzen: 3 Dankeschöns pro Tag, 1 pro Person und Tag, Reset um Mitternacht Berliner Zeit. Kein Selbst-Dank.
- Ränge von Laufkundschaft bis Spätibesitzer, „Stammkunde des Monats“.
- Tab „Punkte“: eigene Punkte mit Fortschrittsbalken, Rangliste (Name anklicken → Danke-Feld),
  letzte Dankeschöns, Sync-Status.
- Offiziere (Gildenmeister + Rang `Officer`) können Dankeschöns stornieren.
- Lokale Meldung + Ton, wenn sich jemand bei dir bedankt oder du aufsteigst (abschaltbar).
- Abgleich über unsichtbare Addon-Nachrichten (Präfix `SpaetiFreunde`, Protokoll 1, siehe
  `docs/PROTOCOL.md`): neue Dankeschöns sofort, Nachholen nach dem Einloggen, eigene Sendewarteschlange
  mit Drossel, Pause während Chat-Sperren.
- `/spaeti status` zeigt jetzt auch Spätipunkte-Einträge und Warteschlange.
- Daten-Schema 2 (automatische Migration).
- Tests ohne Spiel (`tests/`, läuft in CI).

### Neu – M1 „Erster Kunde“
- Grundgerüst: TOC, Lokalisierung (`Locale/deDE.lua`), SavedVariables mit Schema-Version.
- Gildenliste mit Online/Offline-Erkennung, Offizier-Erkennung (Gildenmeister oder Rang `Officer`).
- Begrüßung beim Einloggen („Späti hat offen!“).
- Lokale Meldung, wenn ein Gildenmitglied online kommt.
- `/spruch` mit rund 40 Berliner Sprüchen (nur lokal).
- `/spaeti` bzw. `/späti` mit `status`, `spruch`, `hilfe`, `optionen`.
- Hauptfenster mit Tabs (Start, Punkte, Online, Info), Minimap-Knopf, Addon-Fach-Eintrag, Einstellungen.
