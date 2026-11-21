# WoW: Forever – facts from the probe

Filled in from SpaetiProbe reports (`docs/PROBE.md`). One row per question. "Source" names the report section and which client (A/B) it came from. Leave "Answer" empty until a report confirms it.

| # | Question | Answer | Source | Consequence for the addon |
|---|---|---|---|---|
| 1 | Client version, build, TOC interface number (`GetBuildInfo` 4th return) | **1.60.1, build 70959, interface 16001** ✅ | `/spaeti status` 2026-11-21 | TOC `## Interface:` line |
| 2 | `WOW_PROJECT_ID` / `WOW_PROJECT_CAMELOT` values | | Build | Forever detection in Compat |
| 3 | AddOns folder path (`_forever_`?) and whether "load out of date" was needed | | user note | README install steps |
| 4 | `GetLocale()` on the guild's clients | deDE **and enUS** in the guild ✅ | Build | locale handling |
| 5 | `UnitName` / `UnitFullName` format (surname? realm part?) | first name + **surname in the realm slot** ✅ | Identität | display + name normalisation |
| 6 | GUID format (`UnitGUID`, roster column 17) | `Player-<serverId>-<hex>`, column 17 ✅; multiple serverIds in guild | Identität, Gilden-Roster | GUID keying |
| 7 | Roster name format (`GetGuildRosterInfo` name: hyphen, space, realm) and number of returns | "Vorname Nachname" (space), 17 returns ✅ | Gilden-Roster | Roster cache |
| 8 | `CHAT_MSG_ADDON` sender format, `Ambiguate` forms, sender → roster/GUID rule | "Vorname Nachname" = roster name, exact match ✅ | Addon-Nachrichten | `SenderToGUID` |
| 9 | `guildKey`: `C_Club.GetGuildClubId()` available and stable, or guild name | clubId 215755322 ✅ | Identität | DB keying |
| 10 | Guild rank names / indices; officer rank `Officer` present | **`Officer` = rank index 1**; officer detection works ✅ | Gilden-Roster | Perm.IsOfficer |
| 11 | Which slash aliases work (`/sfprobe`, `/spaetiprobe`, `/spätiprobe`, `/SPÄTIPROBE`) | `/späti` (lowercase ä) works ✅; uppercase still open | Slash-Befehle | `/spaeti`, `/späti` registration |
| 12 | `strlower`/`strupper` on umlauts; font renders `äöüß ÄÖÜ „“` | both work ✅ | Text / Umlaute, screenshot | UTF-8 folding helper |
| 13 | `ERR_FRIEND_ONLINE_SS` raw German string; guild online notices in `CHAT_MSG_SYSTEM`, or roster diff only | | Globale Strings, CHAT_MSG_SYSTEM | online greeting source |
| 14 | `RANDOM_ROLL_RESULT` raw German string and parsed pattern | | Globale Strings | dice games |
| 15 | Are `CHAT_MSG_SYSTEM` lines secret values? | | CHAT_MSG_SYSTEM | secret guards |
| 16 | `RegisterAddonMessagePrefix` result code | 0 Success ✅ | Addon-Nachrichten | Comm init |
| 17 | `SendAddonMessage` result codes; burst: how many of 12 succeed | 10 succeed, 11–12 → 3 Throttle ✅ | Addon-Nachrichten | throttle budget |
| 18 | Echo loss: gaps when entering/leaving a dungeon, inside vs outside | | Echo | sync retry strategy |
| 19 | Lockdown scope: `InChatMessagingLockdown()` in open world / dungeon / boss / combat | API exists; `false` in open world ✅ (instance/boss still open) | Lockdown-Zeitleiste | send gate |
| 20 | `ADDON_RESTRICTION_STATE_CHANGED` exists? payload? | | Lockdown-Zeitleiste | restriction listener |
| 21 | `C_RestrictedActions` / `C_Secrets` / `issecretvalue` available; their keys | secret-value guard API available ✅ (details open) | API-Existenz, Namespaces | Safe.lua |
| 22 | Guild chat from click / slash / `C_Timer` – sent, arrived, blocked? | | Gilden-Chat-Tests | Chat.SendGuild rules |
| 23 | Trial / veteran detection (`IsTrialAccount`, `IsVeteranTrialAccount`) and their send results | | Identität | trial notice |
| 24 | `Settings`, `AddonCompartmentFrame`, `Menu`/`MenuUtil`, `ScrollUtil` present | | API-Existenz | UI choices |
| 25 | `C_Calendar` guild events / signups exist | yes, CanAddEvent=true ✅ | API-Existenz, Spätere Features | S5 Termine: calendar or own events |
| 26 | `GetNumGuildTradeSkill` / `GetGuildTradeSkillInfo` exist and return data | yes, 10 ✅ | Spätere Features | S9 Berufe |
| 27 | `C_EncodingUtil` (CBOR, compression, base64) present | yes ✅ | API-Existenz | codec choice |
| 28 | Server time vs local time (`GetServerTime`, `date`) | equal, CET ✅ | Build | Berlin midnight reset |
| 29 | Lua errors seen in-game / probe "Abgefangene Fehler" | | Abgefangene Fehler, screenshots | – |

## Confirmed from `/spaeti status` (M1 test3, 2026-11-21)
- Client 1.60.1 (build 70959), interface 16001; addon loads (TOC is correct).
- Guild "Spätifreunde Spandau", 54 members; roster API works (online/total counts).
- Rank "Officer" has rank index 1; `Offizier: ja` correct.
- `C_ChatInfo.InChatMessagingLockdown` present, `false` in the open world.
- Secret-value guard available; Settings API registration works.

## Confirmed by the user in-game (M1 test3, 2026-11-21)
- `/späti` with umlaut works like `/spaeti`.
- Login greeting shows once, with the online count ("3 Stammkunden sind grad im Laden."); umlauts and „“ render correctly in chat.
- Minimap button: movable and clickable. Settings panel works.

## Probe report, solo (client A, 2026-11-21, SpaetiProbe 0.1.0)
Confirmed (single client, no second player yet):
- **Build:** 1.60.1 / 70959 / interface 16001. `WOW_PROJECT_ID = 18 = WOW_PROJECT_CAMELOT`. Locale `deDE`. Server time = local time (CET, UTC+1).
- **Names:** "Vorname Nachname" separated by a **space**, no hyphen. `UnitName("player")` returns `"Gernhard", "Reindaggern"`, so the surname comes back in the realm slot. `GetPlayerInfoByGUID` returns name `"Gernhard Reindaggern"` with an empty realm.
- **GUIDs:** `Player-<serverId>-<hex>`. Guild members have **different serverIds** (6937, 6939, 6945, 6949), so the guild spans several servers, which is like cross-realm. Realm names are internal (`CAMWOWEU5Realm7PvE`) and differ from the guild's realm. → Key everything by GUID; never build a "Name-Realm" ourselves.
- **Roster:** `GetGuildRosterInfo` returns 17 values; the GUID is the 17th. Rank names are **English** custom names: 1 Guild Master, 2 Officer, 3 Veteran, 4 Member, 5 Twink (1-based here; `rankIndex` 0-based → Officer = 1). A **"Twink" rank** exists, which is useful for S8.
- **Club:** `C_Club.GetGuildClubId()` = 215755322. Use it as a stable guild key.
- **Text:** `strlower`/`strupper` fold ÄÖÜ correctly. `ä` = 2 bytes. There's no `utf8` library. The font renders `äöüß ÄÖÜ „“`.
- **Global strings (deDE):** `ERR_FRIEND_ONLINE_SS = "|Hplayer:%s|h[%s]|h ist jetzt online."`, `ERR_FRIEND_OFFLINE_S = "%s ist jetzt offline."`, `RANDOM_ROLL_RESULT = "%1$s würfelt. Ergebnis: %2$d (%3$d-%4$d)"`.
- **Addon messages:** `RegisterAddonMessagePrefix` → 0 (Success). `Enum.SendAddonMessageResult` includes `AddOnMessageLockdown=11`. `C_ChatInfo.AreOutgoingAddonChatMessagesRestricted` exists → use it as the send gate together with `InChatMessagingLockdown`.
- **Restrictions:** `C_RestrictedActions.GetAddOnRestrictionState/IsAddOnRestrictionActive` exist. `Enum.AddOnRestrictionType = {Combat=0, Encounter=1, ChallengeMode=2, PvPMatch=3, Map=4, Chat=5}`. The `ADDON_RESTRICTION_STATE_CHANGED` event is valid. `issecretvalue`, `canaccessvalue`, `issecrettable` all exist.
- **Libraries not needed:** `C_EncodingUtil.SerializeCBOR/CompressString/EncodeBase64` exist, so no LibSerialize or LibDeflate.
- **Later features:** `C_Calendar` guild signup events exist and `CanAddEvent() = true` → **S5 Termine can be built on the in-game calendar**. Guild tradeskill API: `GetNumGuildTradeSkill() = 10`, plus `C_GuildInfo.QueryGuildMembersForRecipe` → **S9 Berufe can use the built-in guild profession list**.

Still open (needs a second player online at the same time):
- the `CHAT_MSG_ADDON` sender format (`"Vorname Nachname"`? hyphen? server suffix?) and how to map it to a roster GUID;
- ping/burst send results and throttle;
- echo loss on entering and leaving dungeons;
- the lockdown timeline inside dungeons and boss fights;
- system messages when guild members log in or out;
- slash aliases `/spätiprobe` and `/SPÄTIPROBE` (`/späti` already confirmed in the main addon).

## Online notice confirmed (M1, 2026-11-21)
- When a guild member logs in, the game prints its own line `[Lava Lorenz] ist jetzt online.` and our addon adds `Späti: Lava Lorenz schlendert rin. Eene Mate, wie immer?`. The full "Vorname Nachname" displays correctly, and the roster-diff detection works.

## Joint probe, part 1 (A = officer, deDE client; B = guild master, **enUS client**), 2026-11-21
Build 1.60.1 / **71037** (patched 18 Nov). Interface is still 16001.

**Addon messages (GUILD) work in both directions.** ✅
- Both pings arrived on the other client in about 0.1–0.3 s, across different zones and different serverIds (6949 ↔ 6841).
- **Sender format in `CHAT_MSG_ADDON`:** `"Vorname Nachname"`, the same string as the roster name. No hyphen, no server suffix. All `Ambiguate` modes return it unchanged.
- **Sender → roster:** the name matches a roster row exactly, so **sender → GUID works via the roster name**.
- **Own messages are echoed back** on GUILD. The probe's "eigene" check compared against `UnitName("player")`, which is the first name only, and wrongly said "nein". To detect our own messages, compare the sender against the full name: `UnitName` first + " " + second return, or the name from `GetPlayerInfoByGUID(UnitGUID("player"))`.
- **Throttle:** in a burst of 12 messages, **1–10 succeed and 11–12 return `3 (AddonMessageThrottle)`**. All 10 successful ones arrived at B. Burst budget = 10 per prefix, as documented.
- No lockdown in the open world (`lockdown=false` throughout). Nothing was blocked and no errors were caught.

**Locale mix in the guild:** B plays with an **enUS** client, so `GetLocale()` and every global string are English (`"%s has come online."`, `RANDOM_ROLL_RESULT = "%s rolls %d (%d-%d)"` without positional args). The UI stays German for everyone. Never hard-code German system strings; always derive patterns from the global format strings at runtime. Also handle both positional (`%1$s`) and plain (`%s`) format specifiers.

**System messages:** `ERR_FRIEND_OFFLINE_S` lines for **guild members** do appear in `CHAT_MSG_SYSTEM`, so the guild online/offline notices are system messages. Our M1 detection uses the roster diff instead, which works independently of locale.

**Ranks:** the guild master has `rankIndex 0` ("Guild Master") and Officer has `rankIndex 1`. Our officer check = GM or rank name "Officer", and that's right.

Still open (part 2): echo loss on dungeon enter/leave, lockdown inside dungeons and boss fights.
