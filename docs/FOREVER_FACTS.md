# WoW: Forever – facts from the probe

Filled in from SpaetiProbe reports (`docs/PROBE.md`). One row per question. "Source" names the report section and which client (A/B) it came from. Leave "Answer" empty until a report confirms it.

| # | Question | Answer | Source | Consequence for the addon |
|---|---|---|---|---|
| 1 | Client version, build, TOC interface number (`GetBuildInfo` 4th return) | | Build | TOC `## Interface:` line |
| 2 | `WOW_PROJECT_ID` / `WOW_PROJECT_CAMELOT` values | | Build | Forever detection in Compat |
| 3 | AddOns folder path (`_forever_`?) and whether "load out of date" was needed | | user note | README install steps |
| 4 | `GetLocale()` on the guild's clients | | Build | locale handling |
| 5 | `UnitName` / `UnitFullName` format (surname? realm part?) | | Identität | display + name normalisation |
| 6 | GUID format (`UnitGUID`, roster column 17) | | Identität, Gilden-Roster | GUID keying |
| 7 | Roster name format (`GetGuildRosterInfo` name: hyphen, space, realm) and number of returns | | Gilden-Roster | Roster cache |
| 8 | `CHAT_MSG_ADDON` sender format, `Ambiguate` forms, sender → roster/GUID rule | | Addon-Nachrichten | `SenderToGUID` |
| 9 | `guildKey`: `C_Club.GetGuildClubId()` available and stable, or guild name | | Identität | DB keying |
| 10 | Guild rank names / indices; officer rank `Officer` present | | Gilden-Roster | Perm.IsOfficer |
| 11 | Which slash aliases work (`/sfprobe`, `/spaetiprobe`, `/spätiprobe`, `/SPÄTIPROBE`) | | Slash-Befehle | `/spaeti`, `/späti` registration |
| 12 | `strlower`/`strupper` on umlauts; font renders `äöüß ÄÖÜ „“` | | Text / Umlaute, screenshot | UTF-8 folding helper |
| 13 | `ERR_FRIEND_ONLINE_SS` raw German string; guild online notices in `CHAT_MSG_SYSTEM`, or roster diff only | | Globale Strings, CHAT_MSG_SYSTEM | online greeting source |
| 14 | `RANDOM_ROLL_RESULT` raw German string and parsed pattern | | Globale Strings | dice games |
| 15 | Are `CHAT_MSG_SYSTEM` lines secret values? | | CHAT_MSG_SYSTEM | secret guards |
| 16 | `RegisterAddonMessagePrefix` result code | | Addon-Nachrichten | Comm init |
| 17 | `SendAddonMessage` result codes; burst: how many of 12 succeed | | Addon-Nachrichten | throttle budget |
| 18 | Echo loss: gaps when entering/leaving a dungeon, inside vs outside | | Echo | sync retry strategy |
| 19 | Lockdown scope: `InChatMessagingLockdown()` in open world / dungeon / boss / combat | | Lockdown-Zeitleiste | send gate |
| 20 | `ADDON_RESTRICTION_STATE_CHANGED` exists? payload? | | Lockdown-Zeitleiste | restriction listener |
| 21 | `C_RestrictedActions` / `C_Secrets` / `issecretvalue` available; their keys | | API-Existenz, Namespaces | Safe.lua |
| 22 | Guild chat from click / slash / `C_Timer` – sent, arrived, blocked? | | Gilden-Chat-Tests | Chat.SendGuild rules |
| 23 | Trial / veteran detection (`IsTrialAccount`, `IsVeteranTrialAccount`) and their send results | | Identität | trial notice |
| 24 | `Settings`, `AddonCompartmentFrame`, `Menu`/`MenuUtil`, `ScrollUtil` present | | API-Existenz | UI choices |
| 25 | `C_Calendar` guild events / signups exist | | API-Existenz, Spätere Features | S5 Termine: calendar or own events |
| 26 | `GetNumGuildTradeSkill` / `GetGuildTradeSkillInfo` exist and return data | | Spätere Features | S9 Berufe |
| 27 | `C_EncodingUtil` (CBOR, compression, base64) present | | API-Existenz | codec choice |
| 28 | Server time vs local time (`GetServerTime`, `date`) | | Build | Berlin midnight reset |
| 29 | Lua errors seen in-game / probe "Abgefangene Fehler" | | Abgefangene Fehler, screenshots | – |
