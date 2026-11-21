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
L.WELCOME_LINK = "[Willkommen sagen]"
-- Wird nach Klick in den Gildenchat gepostet (%s = Name)
L.WELCOME_POSTS = {
    "Willkommen im Späti, %s!",
    "Moin %s, schön dass de da bist!",
    "Na %s, allet fit? Willkommen!",
    "Tach %s! Komm rin, Kühlschrank is voll.",
}
L.WELCOME_NONE = "Grad keener zum Begrüßen da."
L.WELCOME_GONE = "%s ist nicht mehr online."

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
-- Gildenchat-Helfer
---------------------------------------------------------------------------
L.CHAT_NOT_IN_GUILD = "Du bist in keiner Gilde – nix gesendet."
L.CHAT_LOCKDOWN = "Der Chat ist grad gesperrt (z. B. Instanz oder Bosskampf) – nix gesendet."
L.CHAT_NOT_USER_ACTION = "Senden geht nur direkt per Klick oder Befehl."
L.CHAT_EMPTY = "Leere Nachricht – nix gesendet."
L.CHAT_UNAVAILABLE = "Chat-Senden ist in diesem Client nicht verfügbar."
L.CHAT_FAILED = "Senden hat nicht geklappt."

---------------------------------------------------------------------------
-- Slash-Befehle
---------------------------------------------------------------------------
L.HELP_HEADER = "Befehle:"
L.HELP_LINES = {
    "/spaeti oder /späti – Fenster öffnen/schließen",
    "/spaeti spruch – Spruch anzeigen (auch: /spruch)",
    "/spaeti willkommen – Zuletzt eingeloggtes Mitglied begrüßen",
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
L.START_TEXT = "Willkommen bei den Spätifreunden Spandau. Hier gibt's Sprüche, Grüße und bald auch Spätipunkte."
L.START_ONLINE = "Grad im Laden: %d von %d"
L.START_ONLINE_NO_GUILD = "Du bist in keiner Gilde."
L.START_BTN_SPRUCH = "Spruch zeigen"

L.POINTS_TEXT = "Spätipunkte: Bedanke dich bei Gildenmitgliedern, sammle Punkte und steig auf – von der Laufkundschaft bis zum Spätibesitzer."
L.ONLINE_TEXT = "Hier siehst du bald, wer grad im Laden ist."

L.INFO_VERSION = "Version %s"
L.INFO_TEXT = "Befehle: /spaeti, /späti, /spruch. Mehr mit /spaeti hilfe.\nNur für Mitglieder der Gilde Spätifreunde Spandau."
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
L.OPT_WELCOME = "„Willkommen sagen“-Link anzeigen"
L.OPT_WELCOME_TT = "Hängt an Online-Meldungen einen Link an. Erst dein Klick postet einen Gruß in den Gildenchat."
L.OPT_INSTANCE = "Meldungen auch in Instanzen"
L.OPT_INSTANCE_TT = "Online-Meldungen auch in Dungeons und Schlachtzügen anzeigen."
L.OPT_MINIMAP = "Minimap-Knopf anzeigen"
L.OPT_MINIMAP_TT = "Zeigt den Späti-Knopf am Rand der Minimap."
L.SETTINGS_UNAVAILABLE = "Einstellungsmenü nicht verfügbar – nutze den Info-Tab im Späti-Fenster."
