-- Locale/deDE.lua: ALL user-facing strings of SpaetiFreunde.
-- UTF-8 without BOM. Format placeholders (%s, %d) must stay intact.
local _, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- Allgemein
---------------------------------------------------------------------------
L.ADDON_NAME = "Spätifreunde Spandau"
L.CHAT_PREFIX = "|cffe8a33dSpäti:|r"
L.YES = "ja"
L.NO = "nein"
L.UNKNOWN = "unbekannt"
L.NOT_AVAILABLE = "nicht vorhanden"

---------------------------------------------------------------------------
-- Begrüßung beim Einloggen (eine zufällige Zeile pro Sitzung)
---------------------------------------------------------------------------
L.LOGIN_GREETINGS = {
    "Späti hat offen! Komm rin, wa?",
    "Späti hat offen! Kalte Mate steht im Kühlschrank.",
    "Späti hat offen! Wat darf's denn sein?",
    "Späti hat offen! Pfandflaschen bitte hinten abgeben.",
    "Späti hat offen! Heute im Angebot: jute Laune.",
    "Späti hat offen! Rinspaziert, Leute, hier wird keener bedient, der draußen steht.",
    "Späti hat offen! Spandau grüßt den Rest der Welt.",
    "Späti hat offen! Licht is an, Kasse is offen, Kiez is wach.",
    "Späti hat offen! Schön, dass de da bist.",
    "Späti hat offen! Een Wegbier für unterwegs?",
}
L.LOGIN_ONLINE_COUNT_ONE = "Een Stammkunde is grad im Laden."
L.LOGIN_ONLINE_COUNT = "%d Stammkunden sind grad im Laden."
L.LOGIN_ONLINE_ALONE = "Noch keener da – du schließt heute uff."
L.LOGIN_NO_GUILD = "Du bist in keiner Gilde – der Späti hat trotzdem offen."

---------------------------------------------------------------------------
-- Online-Meldungen (nur lokal; %s = Name)
---------------------------------------------------------------------------
L.ONLINE_LINES = {
    "%s kommt rein. Moin!",
    "%s steht an der Theke. Na, wat solls sein?",
    "%s is wieder da. Allet jut?",
    "Kiek ma, %s is da!",
    "%s schlendert rin. Eene Mate, wie immer?",
}
L.ONLINE_MANY = "%s und %d weitere sind reingekommen."

---------------------------------------------------------------------------
-- Sprüche (/spruch). Kurze, gängige Berliner Sprüche und Berlinerisch.
---------------------------------------------------------------------------
L.SPRUECHE = {
    "Da kiekste, wa?",
    "Icke, dette, kieke mal, Oogen, Fleesch und Beene!",
    "Ick gloob, mein Schwein pfeift!",
    "Ick gloob, ick steh im Wald!",
    "Ick gloob, et hackt!",
    "Det is ja knorke!",
    "Dit is Berlin!",
    "Allet jut!",
    "Allet Banane?",
    "Mach ma halblang!",
    "Nu mach ma 'nen Punkt!",
    "Nu hab dich ma nich so!",
    "Immer mit de Ruhe!",
    "Keene Panik!",
    "Kein Ding!",
    "Weeßte Bescheid.",
    "Uff jeden Fall!",
    "Det jeht klar.",
    "Wat denn, wat denn?",
    "Wat 'n Jedöns!",
    "Kiek ma eener an!",
    "Ooch dit noch!",
    "Da haste den Salat!",
    "Det kannste dir abschminken.",
    "Da kriegste ja 'n Föhn!",
    "Mir kann keener.",
    "Nüscht Jenaues weeß man nich.",
    "Det wird schon wieder.",
    "Mach keene Fisimatenten!",
    "Ick hab Kohldampf!",
    "Lass ma jut sein.",
    "Zieh Leine!",
    "Mach 'nen Abflug!",
    "Haste ma 'ne Mark?",
    "Eene Molle und 'n Korn, bitte!",
    "Schrippe, Bulette, Molle – mehr braucht keener.",
    "Spandau is jwd – janz weit draußen!",
    "Berliner Schnauze mit Herz.",
    "Mensch, Meier!",
    "Bis denne!",
    "Tschüssikowski!",
    "Dit Leben is keen Ponyhof.",
}
L.SPRUCH_LOCAL = "„%s“"

---------------------------------------------------------------------------
-- Slash-Befehle
---------------------------------------------------------------------------
L.HELP_HEADER = "Befehle:"
L.HELP_LINES = {
    "/spaeti oder /späti – Fenster öffnen/schließen",
    "/spaeti spruch – Spruch anzeigen (auch: /spruch)",
    "/spaeti danke <Name> – bei einem Gildenmitglied bedanken (+1 Spätipunkt)",
    "/spaeti punkte – deine Spätipunkte und die Rangliste",
    "/spaeti status – Version, Gilde, Offizier, Chat-Sperre",
    "/spaeti optionen – Einstellungen öffnen",
    "/spaeti hilfe – diese Hilfe",
}
L.UNKNOWN_COMMAND = "Unbekannter Befehl „%s“. Tipp: /spaeti hilfe"

-- Status
L.STATUS_HEADER = "Status:"
L.STATUS_VERSION = "Version: %s (Daten-Schema %d)"
L.STATUS_INTERFACE = "Interface: %s, Client %s (Build %s)"
L.STATUS_GUILD = "Gilde: %s"
L.STATUS_NO_GUILD = "keine"
L.STATUS_RANK = "Dein Rang: %s"
L.STATUS_OFFICER = "Offizier: %s"
L.STATUS_MEMBERS = "Mitglieder: %d online / %d gesamt"
L.STATUS_LOCKDOWN = "Chat-Sperre: %s"
L.STATUS_SECRETS = "Secret-Values-Schutz: %s"
L.STATUS_SETTINGS = "Einstellungsmenü: %s"
L.STATUS_READONLY = "Achtung: Daten im Nur-Lesen-Modus (Migration fehlgeschlagen)."
L.STATUS_MISSING_KEYS = "Fehlende Texte: %s"

---------------------------------------------------------------------------
-- Datenbank
---------------------------------------------------------------------------
L.DB_MIGRATION_FAILED = "Gespeicherte Daten konnten nicht aktualisiert werden – Änderungen werden diese Sitzung nicht gespeichert."
L.DB_NEWER_SCHEMA = "Deine gespeicherten Daten stammen aus einer neueren Addon-Version. Bitte Addon aktualisieren."

---------------------------------------------------------------------------
-- Hauptfenster
---------------------------------------------------------------------------
L.WINDOW_TITLE = "Spätifreunde Spandau"
L.TAB_START = "Start"
L.TAB_POINTS = "Punkte"
L.TAB_ONLINE = "Online"
L.TAB_INFO = "Info"
L.COMING_SOON = "Kommt bald!"

L.START_HEADLINE = "Späti hat offen!"
L.START_TEXT = "Willkommen bei den Spätifreunden Spandau. Hier gibt's Sprüche, Grüße und Spätipunkte."
L.START_ONLINE = "Grad im Laden: %d von %d"
L.START_ONLINE_NO_GUILD = "Du bist in keiner Gilde."
L.START_BTN_SPRUCH = "Spruch zeigen"

L.ONLINE_TEXT = "Hier siehst du bald, wer grad im Laden ist."

L.INFO_VERSION = "Version %s"
L.INFO_TEXT = "Befehle: /spaeti, /späti, /spruch, /spaeti danke <Name>. Mehr mit /spaeti hilfe.\nNur für Mitglieder der Gilde Spätifreunde Spandau."
L.INFO_SETTINGS = "Einstellungen"

---------------------------------------------------------------------------
-- Minimap-Knopf / Addon-Fach
---------------------------------------------------------------------------
L.TOOLTIP_LEFT = "Linksklick: Fenster öffnen/schließen"
L.TOOLTIP_RIGHT = "Rechtsklick: Einstellungen"
L.TOOLTIP_DRAG = "Ziehen: Knopf verschieben"

---------------------------------------------------------------------------
-- Einstellungen
---------------------------------------------------------------------------
L.OPT_LOGIN = "Begrüßung beim Einloggen"
L.OPT_LOGIN_TT = "Zeigt beim Einloggen einen Späti-Spruch in deinem Chatfenster."
L.OPT_ONLINE = "Online-Meldungen"
L.OPT_ONLINE_TT = "Zeigt lokal an, wenn ein Gildenmitglied online kommt."
L.OPT_INSTANCE = "Meldungen auch in Instanzen"
L.OPT_INSTANCE_TT = "Online-Meldungen auch in Dungeons und Schlachtzügen anzeigen."
L.OPT_MINIMAP = "Minimap-Knopf anzeigen"
L.OPT_MINIMAP_TT = "Zeigt den Späti-Knopf am Rand der Minimap."
L.OPT_THANKS = "Dankeschön-Meldungen"
L.OPT_THANKS_TT = "Zeigt lokal an, wenn sich jemand bei dir bedankt oder du einen neuen Rang erreichst."
L.OPT_THANKS_SOUND = "Ton bei Dankeschön"
L.OPT_THANKS_SOUND_TT = "Spielt einen kurzen Ton, wenn sich jemand bei dir bedankt oder du aufsteigst."
L.SETTINGS_UNAVAILABLE = "Einstellungsmenü nicht verfügbar – nutze den Info-Tab im Späti-Fenster."

---------------------------------------------------------------------------
-- Spätipunkte
---------------------------------------------------------------------------
-- Rangnamen in Reihenfolge der Schwellen 0, 5, 20, 50, 100, 250 (Modules/PointsData.lua)
L.RANKS = {
    "Laufkundschaft",
    "Gelegenheitskunde",
    "Stammkunde",
    "Kiezgröße",
    "Spätiverkäufer",
    "Spätibesitzer",
}
L.POINTS_UNKNOWN_MEMBER = "Ehemaliger Kunde"

-- /spaeti danke
L.THANKS_USAGE = "So geht's: /spaeti danke <Name> – z. B. /spaeti danke Lava Lorenz (Vorname reicht, wenn eindeutig)."
L.THANKS_NO_GUILD = "Ohne Gilde keene Spätipunkte."
L.THANKS_NOT_READY = "Die Gildenliste lädt noch – versuch's gleich nochmal."
L.THANKS_NOT_FOUND = "Keen Gildenmitglied „%s“ gefunden."
L.THANKS_AMBIGUOUS = "Mehrere passen: %s – bitte genauer."
L.THANKS_SELF = "Bei dir selbst bedanken? Nee, so läuft dit nich."
L.THANKS_LIMIT_DAY = "Du hast heute schon %d-mal Danke gesagt. Morgen wieder (Reset um Mitternacht)."
L.THANKS_LIMIT_PAIR = "Bei %s hast du dich heute schon bedankt. Morgen wieder!"
L.THANKS_FAILED = "Hat nicht geklappt – bitte nochmal versuchen."
L.THANKS_DONE = "Danke an %s ist raus (+1 Spätipunkt). Heute noch %d übrig."
L.SYNC_QUEUED = "Chat-Sperre aktiv – wird verschickt, sobald es wieder geht."

-- Lokale Meldungen beim Empfänger (%s = Name)
L.POINTS_NOTICE_LINES = {
    "%s hat sich bei dir bedankt! +1 Spätipunkt.",
    "%s sagt Danke! Ab in die Kasse: +1 Spätipunkt.",
    "Jut jemacht! %s bedankt sich bei dir. +1 Spätipunkt.",
}
L.POINTS_NOTICE_MANY = "Während du weg warst: %d neue Dankeschöns für dich!"
L.POINTS_RANK_UP = "Uffjestiegen! Du bist jetzt „%s“."

-- Offiziere
L.VOID_NOT_OFFICER = "Nur Offiziere können Dankeschöns stornieren."
L.VOID_NOT_FOUND = "Dieses Dankeschön gibt's nicht (mehr)."
L.VOID_ALREADY = "Ist schon storniert."
L.VOID_DONE = "Dankeschön von %s an %s storniert."

-- Punkte-Tab
L.POINTS_MINE = "Deine Spätipunkte: %d – %s"
L.POINTS_NEXT = "Noch %d bis „%s“"
L.POINTS_TOP = "Höchster Rang erreicht. Respekt!"
L.POINTS_MONTH = "Stammkunde des Monats: %s (%d)"
L.POINTS_MONTH_NONE = "Stammkunde des Monats: noch keener – sag ma Danke!"
L.POINTS_LEADERBOARD = "Rangliste"
L.POINTS_RECENT = "Letzte Dankeschöns"
L.POINTS_RECENT_LINE = "%s → %s"
L.POINTS_RECENT_EMPTY = "Noch keene Dankeschöns."
L.POINTS_ROW = "%d. %s – %d"
L.POINTS_THANK_LABEL = "Danke an:"
L.POINTS_THANK_BUTTON = "Danke!"
L.POINTS_LEFT_TODAY = "Heute noch %d"
L.POINTS_PICK_HINT = "Tipp: Namen in der Rangliste anklicken."
L.POINTS_VOID = "Storno"
L.POINTS_VOID_CONFIRM = "Sicher?"
L.POINTS_VOID_TT = "Offiziere: Dankeschön stornieren (zählt dann bei niemandem mehr). Zweimal klicken."
L.POINTS_NO_GUILD = "Du bist in keiner Gilde."

-- Sync-Status
L.SYNC_STATUS = "Sync: %s · %d Einträge"
L.SYNC_OK = "bereit"
L.SYNC_PAUSED = "pausiert (Chat-Sperre)"
L.SYNC_QUEUE = "sendet (%d in der Warteschlange)"
L.SYNC_WAITING = "wartet auf Abgleich"
L.SYNC_LAST = "zuletzt %s"
L.SYNC_NEWER_VERSION = "Jemand in der Gilde nutzt eine neuere Addon-Version. Bitte Spätifreunde aktualisieren!"

-- /spaeti status
L.STATUS_SYNC_DIAG = "Sync-Details: Pause %s · Sperren %s/%s/%s · letztes Ergebnis %s · verworfen %d · Sperr-Antworten %d · Fehler %d · Prefix %s"
L.STATUS_SYNC_ERROR = "Sync-Fehler: %s"
L.STATUS_SYNC = "Spätipunkte: %d Einträge, Warteschlange %d, gesendet %d, empfangen %d, Drossel %d"
