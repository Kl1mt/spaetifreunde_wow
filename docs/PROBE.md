# SpaetiProbe – Anleitung für den Probe-Lauf

SpaetiProbe ist ein kleines **Diagnose-Addon**. Es spielt nichts automatisch und verändert nichts am Spiel. Es schreibt nur auf, wie sich WoW: Forever verhält: welche Addon-Schnittstellen es gibt, wie Namen und GUIDs aussehen, ob Addon-Nachrichten ankommen und wann der Chat gesperrt ist. Mit diesen Ergebnissen bauen wir danach das richtige Gildenaddon „Spätifreunde Spandau“.

Du brauchst dafür etwa **30–45 Minuten** und **ein zweites Gildenmitglied**, das SpaetiProbe ebenfalls installiert.

## 1. Installieren

1. `SpaetiProbe.zip` entpacken (oder den Ordner `tools/SpaetiProbe` aus diesem Repository kopieren; den Unterordner `tests` braucht das Spiel nicht).
2. Einfügen nach:
   `World of Warcraft\_forever_\Interface\AddOns\`
   Danach muss es diese Datei geben:
   `World of Warcraft\_forever_\Interface\AddOns\SpaetiProbe\SpaetiProbe.toc`
   Falls dein Forever-Ordner anders heißt (z. B. nicht `_forever_`), bitte den echten Pfad notieren – das ist selbst schon ein Ergebnis.
3. Spiel starten. Im Charakterauswahl-Bildschirm unter **AddOns** prüfen, dass „SpaetiProbe“ aktiviert ist. Steht dort „veraltet“, bitte „Veraltete AddOns laden“ anhaken und das notieren.
4. Einloggen und einmal im Chat eingeben: `/console scriptErrors 1`
   Damit zeigt das Spiel Lua-Fehler an. Wenn ein Fehlerfenster auftaucht: Screenshot machen.

## 2. Hinweis

Die Probe schreibt **nichts** in den Gildenchat. Sie verschickt nur unsichtbare Addon-Nachrichten, die andere Spieler nicht sehen.

## 3. Befehle – in dieser Reihenfolge

Am besten in einer Hauptstadt anfangen. Nach dem Einloggen **10 Minuten im Spiel bleiben**: So lange zeichnet SpaetiProbe Systemmeldungen auf (z. B. „… ist jetzt online.“). Ideal ist, wenn in dieser Zeit jemand aus der Gilde ein- oder ausloggt und jemand `/würfeln` benutzt.

| Schritt | Befehl | Was passiert |
|---|---|---|
| 1 | `/sfprobe` | Öffnet den Bericht. Kurz anschauen, wieder schließen. |
| 2 | `/spätiprobe` | Gleicher Bericht, testet den Befehl **mit Umlaut**. |
| 3 | `/SPÄTIPROBE` | Testet den Befehl in **Großbuchstaben mit Ä**. |
| 4 | `/spaetiprobe` | Testet die ASCII-Schreibweise. |
| | | Wenn bei 2–4 nichts passiert oder „Unbekannter Befehl“ kommt: bitte notieren. |
| 5 | `/sfprobe font` | Schreibt `äöüß ÄÖÜ „Späti“` in den Chat. **Screenshot** vom Chat und vom Berichtsfenster (oben steht dort derselbe Schrifttest). |
| 6 | `/sfprobe ping` | Schickt **eine** unsichtbare Addon-Nachricht an die Gilde. Am besten machen das beide Testpersonen. |
| 7 | `/sfprobe burst` | Schickt 12 Addon-Nachrichten auf einmal, um die Drosselung zu messen. **Nur EINMAL ausführen, nicht wiederholen!** |
| 8 | Echo-Test (siehe unten) | Misst, ob Addon-Nachrichten beim Betreten/Verlassen eines Dungeons verloren gehen. |
| 9 | Dungeon-Test (siehe unten) | Zeichnet auf, wann der Chat gesperrt ist. |
| 10 | `/sfprobe` bzw. `/sfprobe anon` | Endbericht kopieren und zurückschicken (siehe Abschnitt 5). |

Alle Befehle auf einen Blick: `/sfprobe hilfe`.

### Echo-Test (mit dem zweiten Gildenmitglied)

1. Beide haben SpaetiProbe installiert und sind online.
2. **Person A** gibt `/sfprobe echo` ein. Ab jetzt schickt A **2 Minuten lang alle 2 Sekunden** eine nummerierte Addon-Nachricht. **Person B** muss nichts eingeben, B zeichnet automatisch auf, welche Nummern ankommen und welche fehlen.
3. Während das Echo läuft, **betritt Person A einen Dungeon** (oder steht am Eingang und geht rein), wartet ca. 30 Sekunden und **verlässt ihn wieder**. Wer möchte, macht das zusätzlich auch mit Person B (B geht rein, A bleibt draußen).
4. Danach die Rollen tauschen: B startet `/sfprobe echo`, A beobachtet.
5. Abbrechen geht mit `/sfprobe echo stop`.

### Dungeon-Test (Chat-Sperre)

SpaetiProbe schreibt automatisch eine Zeitleiste: bei jedem Zonenwechsel, Kampfbeginn/-ende, Bossbeginn/-ende und zusätzlich alle 5 Sekunden, wenn sich etwas geändert hat. Du musst dafür nur spielen:

1. In der Stadt stehen (Ausgangszustand).
2. In die offene Welt gehen und einen Kampf machen.
3. Einen Dungeon betreten, **außerhalb eines Bosskampfs** kurz warten, dann `/sfprobe ping` eingeben.
4. Einen **Bosskampf** machen und **während** des Kampfs `/sfprobe ping` eingeben.
5. Dungeon verlassen.

Optional: Falls jemand in der Gilde einen **Test- oder Veteranen-Account** hat, bitte dort einmal `/sfprobe ping` ausführen und den Bericht schicken.

## 4. Was steht im Bericht?

- Spielversion, Sprache und Projekt-ID
- welche Addon-Schnittstellen es in Forever gibt (oder nicht gibt)
- dein Name, voller Name und deine GUID (Spieler-ID) und die ersten 5 Zeilen der Gildenliste
- welcher Slash-Befehl funktioniert hat
- Systemmeldungen aus den ersten 10 Minuten
- gesendete und empfangene Addon-Nachrichten, Echo-Lücken
- die Zeitleiste der Chat-Sperre
- blockierte Aktionen (falls welche auftreten)

Ein `||` im Bericht bedeutet ein einzelnes `|`-Zeichen.

## 5. Bericht zurückschicken

**Variante A – Kopieren (empfohlen):**
1. `/sfprobe` eingeben (oder `/sfprobe anon`, siehe unten).
2. Ins Textfeld klicken, **Strg+A** (alles markieren), **Strg+C** (kopieren).
3. In eine Textdatei oder direkt in die Nachricht an den Entwickler einfügen (Strg+V).

**Variante B – Datei schicken:**
Nach dem Ausloggen (oder `/reload`) liegt alles in
`World of Warcraft\_forever_\WTF\Account\<DEIN-ACCOUNT>\SavedVariables\SpaetiProbe.lua`
Diese Datei kann man auch schicken. **Achtung:** Sie enthält die echten Namen und GUIDs. Wer das nicht möchte, nimmt Variante A mit `/sfprobe anon`.

**Anonymisieren:** `/sfprobe anon` ersetzt Charakternamen durch `Member1`, `Member2` … und kürzt GUIDs. Die Form der Namen bleibt sichtbar (z. B. `Member1{xxxxx}-{xxxxxxx}`), weil genau das für uns wichtig ist. Bitte vor dem Verschicken trotzdem einmal drüberlesen: Namen von Freunden außerhalb der Gilde in Systemmeldungen werden eventuell nicht ersetzt.

Bitte von **beiden** Testpersonen den Bericht schicken, dazu die Screenshots (Schrifttest, eventuelle Fehlerfenster) und eine kurze Notiz, welche Schritte ihr gemacht habt.

## 6. Aufräumen

- `/sfprobe reset` löscht alle aufgezeichneten Daten (z. B. vor einem zweiten Durchgang).
- Nach dem Test kann der Ordner `SpaetiProbe` einfach wieder aus `Interface\AddOns` gelöscht werden.
