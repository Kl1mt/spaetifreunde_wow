# Spätifreunde Spandau Addon – Implementation Plan

## 1. Overview and key constraints

**What we're building:** a guild addon for "Spätifreunde Spandau" on **World of Warcraft: Forever** (client 1.60.1, launched 2026-11-04).

**v1.0 scope:**
- Core: minimap button, tabbed main window, settings, guild sync layer.
- **Spätipunkte**: thanks points, ranks, "Stammkunde des Monats".
- **Login greeting** and greetings when guild members come online.
- **/spruch**: Berlin sayings.

After v1.0: Event-Planer, Pfandflaschen-Sammler, Pinnwand, Twinks, Geburtstage, Berufe, Würfelspiele, Quiz, Erfolge-Feed.

**Approach:**
- Every milestone ends in an installable zip that the guild can test.
- The unknowns only the game can answer go to the user first, through a small probe addon shipped on day 2. While the user runs it, I build the pure-Lua core.

### Hard constraints

| Area | Constraint |
|---|---|
| **API** | Forever reportedly uses the Mainline 12.1.5 API plus Midnight's addon restrictions. Every API we rely on is checked by the probe, and anything uncertain is marked **(verify in-game)**. |
| **Combat** | No combat-log use: `COMBAT_LOG_EVENT_UNFILTERED` is unavailable. No secure frames, no automation. Secret values are never compared or stored. Addon messages and chat are locked in M+ keys, PvP, encounters, and possibly whole dungeons and raids. |
| **Chat** | Nothing is posted to SAY, YELL or GUILD automatically. Guild posts happen only *synchronously* inside a click or slash handler, and only when the client is not in chat lockdown. |
| **Identity** | Forever has no realms and adds required surnames, so the name formats are unknown. All data is keyed by **player GUID**; names are for display only. |
| **Network** | One prefix `SpaetiFreunde`. Each prefix allows a burst of 10 messages, regenerating at 1 per second. Messages are at most 255 bytes. Trial and Veteran accounts cannot send. |
| **Text** | All user-facing text is German and lives in **one file, `Locale/deDE.lua`**. The only exceptions are the TOC `## Title` and `## Notes` lines. Files are UTF-8, no BOM, LF line endings. |
| **Testing** | The container has no game client. It covers lint, unit tests, a multi-client simulator and the build. **Everything in-game is done by the user and guild testers**, using checklists in `docs/TESTING_INGAME.md`. |
| **Policy** | The addon is free; there is no paid tier. |

---

## 2. Architecture summary

### 2.1 Design rules
1. **Pure logic, thin adapters.**
   - Pure Lua 5.1, testable with busted: the op log, derivation, ranks, codec, digests, UTF-8 and time helpers, and the slash parser. Clock, transport, roster and random source are passed in as arguments.
   - Only `Compat`, `Comm`, `Roster`, `Chat` and the UI files call the WoW API.
2. **Everything is a module.** A feature registers its tabs, slash subcommands, sync stores and settings through `Core/Registry.lua`. Core knows nothing about features.
3. **Assume messages get lost.** Lockdown drops, throttling and offline peers are normal. Correctness comes from an idempotent op log, set-union merge and periodic digest comparison, not from reliable delivery.
4. **Deterministic derivation.** Totals, caps and authority are computed from the op set plus the *current* server roster. Every online client sees the same roster, so all clients agree. An op is never dropped because of the roster at the moment it arrived.
5. **Libraries:**
   - Ace3 from trunk or the latest alpha: AceAddon, AceEvent, AceTimer, AceConsole, AceDB, AceComm, with ChatThrottleLib. The tagged release r1403 may not list 16001.
   - LibSerialize, LibDeflate, LibDataBroker-1.1, LibDBIcon-1.0.
   - Libraries are not committed. They are fetched into `Libs/`.
   - Licence files ship with each library: Ace3 BSD, LibDeflate zlib, LibSerialize MIT.

### 2.2 File layout (repo root = addon folder `SpaetiFreunde`)
```
SpaetiFreunde.toc            embeds.xml        CHANGELOG.md (de)   README.md (de)   LICENSE
Locale/Locale.lua            # ns.L + missing-key metatable (returns "[KEY]", logs in debug)
Locale/deDE.lua              # ALL user-facing strings, Sprüche, rank names, help texts
Core/Init.lua                # AceAddon object, constants (PREFIX, PROTO, MIN_PROTO, SCHEMA, VERSION)
Core/Compat.lua              # Forever detection, one-time API resolution, fallbacks
Core/Safe.lua                # issecret guard, Safe.text(), sanitizeUserText()
Core/Util.lua                # PatternFromFormat(), Debounce, table helpers, version compare
Core/UTF8.lua                # len/sub/truncateBytes/foldCase (ÄÖÜäöüß), isValid
Core/Time.lua                # BerlinDate(t) with EU DST rule → dayKey/monthKey/weekKey
Core/Log.lua                 # 500-entry ring buffer in SavedVariables
Core/DB.lua  Core/Migrations.lua
Core/Registry.lua  Core/Slash.lua
Core/Chat.lua                # SendGuild(): synchronous, lockdown-gated user posts
Guild/Roster.lua             # roster cache, online diff, rank lookup
Guild/Names.lua              # Normalize, Display(guid), SenderToGUID, Find(input)
Guild/Perm.lua               # IsGM / IsOfficer from current roster + cfg
Comm/Codec.lua               # LibSerialize → LibDeflate → addon-channel encoding
Comm/Comm.lua                # prefix, send gate, in-memory outbox, receive pipeline, rate limits
Comm/OpLog.lua               # pure: op store, admission, day/month digests, pruning
Comm/Sync.lua                # HELLO/OP/DAYS/OPS protocol, jitter, suppression, budget
Modules/Greeting.lua  Modules/Sprueche.lua  Modules/Points.lua  Modules/Status.lua
UI/Widgets.lua  UI/MainFrame.lua  UI/Minimap.lua  UI/Settings.lua  UI/LogWindow.lua  UI/Toast.lua
UI/Tabs/Start.lua  UI/Tabs/Punkte.lua  UI/Tabs/Online.lua  UI/Tabs/Info.lua
tools/SpaetiProbe/           # separate diagnostic addon, never in the main package
spec/  spec/mocks/wow.lua  spec/helpers/{loader,sim}.lua
scripts/dev-setup.sh  fetch-libs.sh  build.sh  check-encoding.sh  check-locale.lua  check-strings.sh
docs/FOREVER_FACTS.md  DECISIONS.md  PROTOCOL.md  SCHEMA.md  TESTING_INGAME.md  PROBE.md  RELEASE.md
.luacheckrc .busted .pkgmeta .editorconfig .gitignore Makefile .github/workflows/{ci,release}.yml
```

### 2.3 TOC (first version)
```
## Interface: 16001, 120105
## Title: |cffe8a33dSpätifreunde Spandau|r
## Notes: Gildenaddon der Spätifreunde Spandau – Späti hat offen!
## Category: Guild
## Category-deDE: Gilde
## Version: @project-version@
## IconTexture: Interface\Icons\INV_Drink_05
## AddonCompartmentFunc: SpaetiFreunde_OnCompartmentClick
## AddonCompartmentFuncOnEnter: SpaetiFreunde_OnCompartmentEnter
## AddonCompartmentFuncOnLeave: SpaetiFreunde_OnCompartmentLeave
## SavedVariables: SpaetiFreundeDB
## SavedVariablesPerCharacter: SpaetiFreundeCharDB
```

- **One TOC with no suffix.** The packager handles neither `_Forever.toc` nor 16001 inside `_Mainline.toc`.
- **`120105`** lets anyone with Midnight retail smoke-test most of the API there. Whether `16001` is the right Forever number is (verify in-game).
- **Icon:** the icon path is (verify in-game). It is a built-in placeholder until real art exists.
- **Interface bumps:** every Forever patch needs a bump, or the addon shows as "veraltet". This step is in `docs/RELEASE.md`.

### 2.4 Event bus (AceEvent messages)
- `SF_DB_READY`
- `SF_ROSTER_UPDATED(changed)`
- `SF_MEMBER_ONLINE/OFFLINE(guid)`
- `SF_COMM_STATE(canSend, reason)`, where reason is `trial`, `noguild`, `lockdown` or `instance`
- `SF_STORE_CHANGED(store)`
- `SF_SYNC_STATE(store, state)`
- `SF_PEER_VERSION(guid, ver, proto)`
- `SF_SETTINGS_CHANGED(key)`

Payloads are always plain values, never secrets. UI refreshes are debounced to 0.2 s.

### 2.5 Sync protocol summary (v1 uses GUILD only)

**Op format.** Every synced fact is an immutable op:
```lua
op = { id = "<guidTail>-<t base36>-<rand4>",  -- collision-proof even after WTF loss / 2 PCs
       a = authorGUID, t = GetServerTime(), k = "thx", d = { to = guid, n = "Grund ≤60 bytes" } }
```
- Merge is set union, so merging is idempotent and the order of arrival doesn't matter.
- Deletes are tombstone ops (`k="void"`, `d.ref=id`), never physical removal.
- Ops of an unknown kind are stored and relayed, but ignored by derivation. This keeps newer clients' data intact on older clients.

**Admission (on receive; never depends on the roster):**
1. The payload is not secret, decodes inside `pcall`, stays under the size cap, and passes the per-kind `validate`: types, byte lengths, sanitised text.
2. **Direct `OP` messages:** the resolved sender GUID must equal `op.a`. The server sets the sender, so this cannot be forged.
3. **Relayed ops (`OPS` messages):** accepted on structure alone. This is what lets late clients converge.

**Derivation (pure; uses the op set plus the current roster):**
- Self-thanks are ignored.
- Per-giver daily cap (default 3) by Berlin `dayKey`, ordered by `(t, id)`.
- Ops dated more than 10 minutes in the future are ignored until that time.
- A `void` counts if its author is the target op's author, or is *currently* an officer.
- Self-authored opt-out and erase ops are applied.
- Season archive ops are applied.

**Messages:**

| m | When | Body |
|---|---|---|
| `HELLO` | On login or reload (10–40 s jitter), every 15 min ±3 min, and after lockdown ends | `{p, minp, v, dg = {store = {monthKey = hash}}}` for the current and previous month |
| `OP` | Live, when an op is created (ALERT priority) | `{st, ops}` |
| `DAYS` | When a HELLO's month hash differs from ours. 1–5 s jitter; suppressed if an identical DAYS was already seen | `{st, mk, dd = {day = hash}}` |
| `OPS` | Each client whose day hash differs sends that day's ops (BULK, paged ≤ 30 ops). Suppressed if it merged an OPS for that day during its jitter and the hashes now match | `{st, mk, day, ops, more}` |

**Rules that apply to all messages:**
- Hashes are FNV-1a over the sorted op IDs per day. The month hash is a hash over the day hashes.
- Months older than the previous one sync only on demand with `/spaeti sync alt`.
- **Budget:** a client sends at most 20 sync messages per minute. Receivers ignore more than 30 messages per minute from one sender.
- **Version rule:**
  - If `p > ours`, ignore the message and show "Neue Version verfügbar: x.y" once per session.
  - If `p < our MIN_PROTO`, ignore the message silently.
  - Versions that are unreplaced `@project-version@`, or dev and `git describe` strings, are treated as "dev" and never trigger the notice. Prerelease ordering follows semver.
- **Send gate:** a client sends only when all of these are true:
  - it is in a guild,
  - it is not a trial account (`IsTrialAccount() or IsVeteranTrialAccount()`, verify in-game),
  - `not C_ChatInfo.InChatMessagingLockdown()`,
  - it is not in a dungeon or raid. This is a conservative choice until the probe shows the real lockdown scope.

  Otherwise the message goes into an **in-memory** outbox (cap 200; a newer HELLO replaces a queued one). The outbox flushes on `PLAYER_ENTERING_WORLD`, `ZONE_CHANGED_NEW_AREA`, `ENCOUNTER_END` and `PLAYER_REGEN_ENABLED`, plus a 5 s ticker while it is not empty.
- **Healing:** ops are persisted, wire messages are not. Anything lost is healed by the next HELLO.
- **WHISPER** is not used until the probe confirms the sender/target format.

**Threat model** (stated in `docs/PROTOCOL.md`):
- The design stops accidents, desync and casual cheating.
- Caps and the self-thanks rule hold on everyone's screen, even against a modified client.
- Forged *relayed* ops are possible. Officers can void them.
- There is no cryptographic signing.

### 2.6 SavedVariables schema sketch
```lua
SpaetiFreundeDB = {                         -- AceDB, account-wide
  schema = 1,
  profiles = { Default = {
    minimap = { hide = false }, window = { point, x, y, w, h, tab = "start" },
    modules = { Greeting = { enabled = true, toast = true, inInstances = false }, Sprueche = {...}, Points = {...} },
    debug = false } },
  global = {
    guilds = { [guildKey] = {                -- "club:<C_Club.GetGuildClubId()>" else "name:<GuildName>"
      stores = { points = { ops = { [id] = op }, days = { [dayKey] = hash } },  -- days = cached digest
                 cfg    = { ops = {...} } },
      names  = { [guid] = { name, class, lastSeen } },  -- display cache only; NEVER officer notes
      peers  = { [guid] = { v, p, seen } } } },
    facts = { ... },                         -- copied from probe decisions
    log   = { ring buffer ≤500 } } }
SpaetiFreundeCharDB = { schema = 1, greetedToday = { [guid] = dayKey }, lastSpruch = {...} }
```
- **Migrations:** `Migrations[n](db)` runs in order inside `pcall`. Each migration is idempotent and has a fixture test.
- **On a failed migration:** the addon sets `readOnly = true` and shows a German error. It never deletes data.
- **Retention:** points ops older than 400 days are pruned. Pruning is deterministic, and pruned days are excluded from digests.
- **Secrets:** no secret value is ever written; every write goes through `Safe.*`.

---

## 3. Milestones

**Size:** S is up to half a day, M is 1–2 days, L is 3–5 days.

**Tags:** **[DEV]** means container work. **[USER]** means in game or on an account, done by the user or the guild.

**Rough calendar:**
- Week 1: Phases 0–1, with the probe out on day 2.
- Weeks 1–2: Phase 2.
- Week 2: Phase 3, which gives the testers M1.
- Weeks 3–4: Phase 4, M2.
- Week 5: Phase 5, M3.
- Weeks 6–7: Phase 6 beta and v1.0.

That is about 22–28 developer-days plus test rounds.

### Phase 0: Setup (container)

**Goal:** a reproducible toolchain, a clean repo, and CI that builds an installable zip from week 1.

**0.1 Toolchain — S [DEV]** *(day 1)*
- Install `lua5.1 liblua5.1-0-dev luarocks subversion zip`, then `busted`, `luacheck` and `luacov` via `luarocks --lua-version=5.1`.
- Put these commands in `scripts/dev-setup.sh`, and save them as the cloud environment's setup script.
- **Acceptance:** `luac5.1 -v`, `busted --version` and `luacheck --version` all run.

**0.2 Repo skeleton and hygiene — S [DEV]** *(day 1)*
- Files: `.gitignore` (`Libs/`, `.release/`, `*.zip`, `luacov.*`), `.editorconfig` (UTF-8, LF, 4 spaces), `LICENSE` (MIT proposed; see open questions), the German README stub with the install path `World of Warcraft\_forever_\Interface\AddOns\SpaetiFreunde\` (verify in-game), and `CHANGELOG.md`.
- `docs/FOREVER_FACTS.md`, holding the open in-game questions as an empty table.
- `scripts/check-encoding.sh`: fails on a BOM, invalid UTF-8 or CRLF in `*.lua`, `*.toc` and `*.xml`.
- The first commit goes on `claude/nifty-sagan-tbuth2`.
- **Acceptance:** the encoding check passes, the folder name equals the TOC name, and `git status` is clean.

**0.3 Static checks — S [DEV]**
- **`.luacheckrc`:**
  - `std = "lua51"` and `max_line_length = false`.
  - `globals`: the SavedVariables, `SLASH_*`, `SlashCmdList`, and the `SpaetiFreunde_OnCompartment*` functions.
  - `read_globals`: the WoW API we use, maintained by hand.
  - `exclude_files`: `Libs/` and `.release/`.
- **`scripts/check-locale.lua`:** fails on a key that is used but undefined, or defined but unused. It has an allowlist for list tables read by iteration, such as `SPRUECHE` and `RANKS`.
- **`scripts/check-strings.sh`:** fails on a string literal passed to `print`, `ns.Print`, `:SetText`, `:AddLine` or `:AddMessage` outside `Locale/`. It has an allowlist for format-only strings.
- **Acceptance:** `make lint check` passes, and a deliberate stray global or an English literal makes it fail.

**0.4 Test harness and mocks — M [DEV]**
- `.busted`, plus `spec/helpers/loader.lua`, which loads files in TOC order with a shared `ns`.
- `spec/mocks/wow.lua`:
  - a fake clock driving `C_Timer.After` and `C_Timer.NewTicker`, and `GetServerTime`;
  - a `CreateFrame` that records calls;
  - `issecretvalue`, switchable;
  - `C_ChatInfo` with a token-bucket throttle (10 messages, +1/s), a lockdown toggle and `Enum.SendAddonMessageResult` codes;
  - a fake guild roster;
  - `IsTrialAccount`;
  - the German globals `ERR_FRIEND_ONLINE_SS` and `RANDOM_ROLL_RESULT` as fixtures.
- `spec/helpers/sim.lua`: N clients on a shared fake GUILD channel with a seeded RNG, a loss rate, lockdown windows and an offline flag. A failing seed is printed so it can be replayed.
- **Acceptance:** a smoke spec passes, and the simulator delivers a message between 2 clients.

**0.5 Libraries and local build — M [DEV]**
- **`.pkgmeta`:**
  - `package-as: SpaetiFreunde`;
  - externals: Ace3 trunk (SVN on wowace, or the GitHub mirror if SVN is blocked; verify the URL in this step), LibDataBroker-1.1, LibDBIcon-1.0, LibSerialize, LibDeflate;
  - `ignore`: `spec`, `tools`, `scripts`, `docs`, `.github`, and the dev config files.
- `embeds.xml`.
- **`scripts/build.sh`:** runs the BigWigs packager `release.sh -d` (no upload), so `@project-version@` gets replaced. A separate step builds `SpaetiProbe.zip`.
- **If the container cannot reach wowace or GitHub,** ask for exact allowed hosts. CI builds the zip either way.
- **Acceptance:** `make build` produces `SpaetiFreunde-<ver>.zip` that unpacks to `SpaetiFreunde/SpaetiFreunde.toc`, contains `Libs/` with the licence files, has no dev files, and the packager reports no interface errors.

**0.6 CI — S [DEV]**
- **`.github/workflows/ci.yml`,** on push and PR:
  - the encoding check;
  - `luac5.1 -p` over all `.lua` files;
  - `nebularg/actions-luacheck@v1`;
  - the locale and string checks;
  - busted, with Lua 5.1 set up through `leafo/gh-actions-lua` plus luarocks;
  - `BigWigsMods/packager@v2` with `args: -d`.
- It uploads the artifacts `SpaetiFreunde-dev` and `SpaetiProbe` on every push.
- **Acceptance:** CI is green, and a downloadable zip exists for every commit.

### Phase 1: Probe (answer the in-game unknowns first)

**Goal:** turn every UNCERTAIN item in the brief into a recorded fact before any code depends on it.

**1.1 `SpaetiProbe` diagnostic addon — M [DEV]** *(ships day 2; needs only 0.1–0.2)*
- `tools/SpaetiProbe/` holds its own TOC (`## Interface: 16001, 120105`), `Probe.lua` and `SpaetiProbeDB`.
- `/sfprobe` opens a copyable edit box with all results.
- `/sfprobe anon` replaces member names with `Member1..n` and shortens GUIDs before the user pastes the results back.
- **Build:** `GetBuildInfo()` (all returns), `WOW_PROJECT_ID`, `WOW_PROJECT_CAMELOT`, `GetLocale()`.
- **API existence:** records `type()` of about 60 entries, including:
  - `C_ChatInfo.*`, `C_GuildInfo.*`, `GetGuildRosterInfo`, `Ambiguate`, `C_Club.GetGuildClubId`
  - `issecretvalue`, `canaccessvalue`, `C_Secrets`, `C_RestrictedActions`
  - `Settings.*`, `AddonCompartmentFrame`, `Menu.ModifyMenu`, `MenuUtil`, `ScrollBox`, `CreateScrollBoxListLinearView`
  - `C_Timer`, `RandomRoll`, `C_ChatInfo.SendChatMessage`, `SendChatMessage`
  - `IsTrialAccount`, `IsVeteranTrialAccount`, `GetServerTime`, `C_DateAndTime`
  - for later features: `C_Calendar.*` (guild events and signups), `GetGuildTradeSkillInfo` / `GetNumGuildTradeSkill`, `C_TradeSkillUI`, `GetProfessions`, `C_GuildInfo.GetPreferredPlaySettings`
- **Identity:**
  - `UnitName("player")`, `UnitFullName("player")`, `UnitGUID("player")`;
  - the first 5 roster rows: name, rankIndex, guid, isOnline;
  - the guild name and club ID.
- **Slash commands:** registers `/sfprobe`, `/spätiprobe` and `/SPÄTIPROBE`, and records which alias fired and the raw message. The expected result is that `strlower` does not fold `Ä`; the probe documents what actually happens.
- **System chat:** records `CHAT_MSG_SYSTEM` for 10 minutes, at most 100 lines. Each line is stored as `"<secret>"` if `issecretvalue(text)`. Also records the raw `ERR_FRIEND_ONLINE_SS` and `RANDOM_ROLL_RESULT` strings.
- **Addon messages:**
  - registers prefix `SpaetiProbe` and records the result code;
  - `/sfprobe ping` sends to GUILD and records the return code;
  - **only our prefix** is recorded on `CHAT_MSG_ADDON`, with the exact `sender`, its `Ambiguate(sender,"none")` form, and whether it matches a roster row;
  - `/sfprobe burst` sends **12** messages and records the codes. `PROBE.md` warns against running it repeatedly.
- **Echo:** `/sfprobe echo` sends a numbered message every 2 s for 2 minutes, and the receiver records the gaps. This measures loss when entering or leaving a dungeon.
- **Lockdown timeline:** records `InChatMessagingLockdown()` and `IsInInstance()` on `PLAYER_ENTERING_WORLD`, `ZONE_CHANGED_NEW_AREA`, `ENCOUNTER_START/END` and `PLAYER_REGEN_DISABLED/ENABLED`, plus every 5 s. It also registers `ADDON_RESTRICTION_STATE_CHANGED` inside `pcall` to see whether that event exists.
- **Guild chat:**
  - a button "GILDE-Test senden" sends from the click;
  - `/sfprobe gildeslash` sends from the slash handler;
  - `/sfprobe gildetimer` sends from `C_Timer.After(1)`, to find out whether that is blocked.
  - Results are recorded: success, an "addon action blocked" popup, or nothing.
  - `PROBE.md`: "Kurz in der Gilde ankündigen, dass Testnachrichten kommen."
- **Fonts:** prints `äöüß ÄÖÜ „Späti“` in chat and in a FontString, for a screenshot.
- `docs/PROBE.md`: step-by-step German instructions.
- **Acceptance:** luacheck and the syntax check pass, and the probe handles every missing API without errors (spec against the mocks with APIs removed).

**1.2 Probe run — S [USER]** *(user plus one guildmate who also installs the probe)*
1. Unzip into the `_forever_` AddOns folder and confirm the path by hand.
2. Run `/console scriptErrors 1`, then log in.
3. Run the probe in a city, in the open world, and in a dungeon, both outside and during a boss.
4. Run `ping` and `echo` with the guildmate.
5. Test the three slash aliases.
6. Test the three guild-chat variants.
7. Take the font screenshot.
8. Optional: someone with a trial or veteran account runs `ping`.
9. Send back `WTF\Account\<ACC>\SavedVariables\SpaetiProbe.lua` from both clients, after `/sfprobe anon` if wanted.

**1.3 Decision record — S [DEV]**
- Fill in `docs/FOREVER_FACTS.md` and `docs/DECISIONS.md`:
  - the interface number and AddOns path;
  - the roster, sender and GUID formats, and the sender → GUID rule;
  - `guildKey` (club ID or name);
  - which slash aliases work;
  - online notices from `CHAT_MSG_SYSTEM` or only the roster diff;
  - the German roll pattern;
  - the lockdown scope (whole instance or encounter only);
  - guild chat from a click, a slash command or a timer;
  - trial detection;
  - whether `C_Calendar` guild events and the guild tradeskill API exist.
- Update the `Compat` table and `.luacheckrc`.
- **Acceptance:** each of the 8 brief checklist items is answered or has a chosen fallback.

**1.4 Start the guild text review — S [USER]** *(in parallel)*
- The guild supplies or approves: rank names and thresholds, about 40 Berlin Sprüche, greeting lines, in-jokes, and the officer rank index (see open questions).
- Dropped already: "Wat mutt, dat mutt" is Low German, not Berlinerisch.
- **Acceptance:** an agreed list in an issue or doc, before Phase 3 strings are final.

### Phase 2: Core foundation (v0.0.x "Späti hat offen")

**Goal:** a loadable addon with tested core services. Steps 2.1–2.4 can start before the probe results arrive; 2.6 waits for 1.3.

**2.1 Init, Compat, Safe — S [DEV]**
- AceAddon object and `Const`, with `VERSION` read from `C_AddOns.GetAddOnMetadata` (verify in-game).
- `Compat` resolves each function once at load:
  - `SendAddonMessage`, `RegisterPrefix`, `GuildRoster`, `InChatLockdown` (falls back to `false`), `issecret` (falls back to `false`), `SendChat`, `OpenSettings`, `IsTrial`, `GetGuildKey`.
- `Safe.text(v)` returns nil for secrets. `sanitizeUserText(s, max)` strips control bytes, escapes `|` to `||`, checks UTF-8 and truncates.
- **Acceptance:** specs run with each API both missing and present, and a secret input never reaches a string operation.

**2.2 Util, UTF8, Time — M [DEV]**
- `UTF8`: `len`, `sub`, `truncateBytes` (never splits a character), `foldCase`.
- `Util.PatternFromFormat`: handles `%s`, `%d` and `%1$s`, and escapes magic characters.
- `Time.BerlinDate(t)`: EU DST rule, giving `dayKey`, `monthKey`, and a `weekKey` with weeks starting Monday 00:00 Berlin time.
- Semver compare, including prerelease and "dev".
- **Acceptance:**
  - DST edges (last Sunday of March and October) at local midnight;
  - `foldCase("ÄRGER")=="ärger"`;
  - truncation at every byte of `"Spätifreunde ßüö"`;
  - patterns built from the German and English `RANDOM_ROLL_RESULT`;
  - pipe-injection cases.

**2.3 Locale, DB, migrations, log — M [DEV]**
- `Locale.lua` metatable, plus `deDE.lua` with the core keys (`LOGIN_GREETING = "Späti hat offen!"`, help texts, errors).
- AceDB defaults as in 2.6. `ns.DB:Guild()` creates the guild partition lazily on `PLAYER_GUILD_UPDATE`.
- The migration runner with the read-only fallback.
- `Core/Log.lua` ring buffer, and `UI/LogWindow.lua`: a copyable box with the version, build, Compat branches and the log.
- **Acceptance:** specs cover a fresh install, the 0→1 fixture, a failing migration leaving data untouched, two separate guild keys, and the bounded ring buffer.

**2.4 Registry and slash router — S [DEV]**
- Commands:
  - `SLASH_SPAETI1="/spaeti"`;
  - `SLASH_SPAETI2="/späti"`, kept only if the probe confirmed it;
  - `SLASH_SPAETI3="/sf"`;
  - `SLASH_SPRUCH1="/spruch"`.
- Subcommands are matched with `foldCase`.
- Built-ins: `hilfe` (generated from the Registry), `optionen`, `status`, `log`, `debug`.
- **Argument rule for names:**
  - The name is the longest prefix of the arguments that matches a roster name.
  - `"Vorname Nachname"` in quotes is also accepted, as is `Name: Grund`.
  - If several names match, the addon lists them and asks again.
- **Acceptance:** specs cover `"DANKE  Hänsel"`, quoted surnames, an empty message, and German help for an unknown subcommand.

**2.5 Chat helper — S [DEV]**
- `Chat.SendGuild(text)` must be called synchronously from an OnClick or slash handler; it is never used from timers.
- If chat is locked down or the player is in a restricted instance, it prints a local German notice instead.
- Text goes through `sanitizeUserText`.
- **Acceptance:** a spec asserts that no send happens from timer callbacks: a call site check plus a guard flag set only inside click and slash handlers.

**2.6 Roster and Names — M [DEV]** *(after 1.3)*
- `GuildRoster()` runs on login and on demand, at most once every 20 s, plus a 60 s ticker.
- The cache holds GUID → name, rankIndex, level, class, zone, isOnline, status and mobile. **No officer notes.**
- There is a name index.
- The `isOnline` diff fires `SF_MEMBER_ONLINE` and `SF_MEMBER_OFFLINE`. The first snapshot is a baseline and fires nothing.
- `Names.SenderToGUID` follows the probe rule.
- **Acceptance (container):** roster fixtures in every candidate format (`Name`, `Name-Realm`, `Name Nachname`, UTF-8) pass, there is no flood on the baseline, and the throttle holds.

**Phase 2 in-game check [USER] (tag `v0.0.1`):**
- the addon loads without errors and shows its German title;
- "Späti hat offen!" appears on login;
- `/spaeti hilfe` works, along with the aliases confirmed by the probe;
- `/spaeti status` shows the expected Compat branches and member counts;
- the log window opens and its contents can be copied;
- data survives `/reload`.

### Phase 3: M1 "Erster Kunde" (v0.1: local fun, first testers)

**Goal:** 3–5 guild testers enjoy the addon on the first evening. There is no addon sync yet.

**3.1 Greetings — M [DEV]**
- On login, once per session: a random line from `L.LOGIN_GREETINGS`, plus the number of members online.
- On `SF_MEMBER_ONLINE`: a local line such as "Kalle kommt rein. Moin!".
- An optional toast (`UI/Toast.lua`) with a **[Grüßen]** button that calls `Chat.SendGuild` from the click.
  - Arrivals within 10 s are grouped into one toast, with at most one toast per 30 s.
  - The grouping only affects *display*. The send always happens inside the click.
- The `CHAT_MSG_SYSTEM` path is used only if the probe showed it works. It goes through `Safe.text` and is de-duplicated against the roster diff for 10 s.
- Muted in instances and in combat by default. `greetedToday` is kept in CharDB.
- **Acceptance:** specs cover the baseline producing no flood, de-duplication, the secret-text guard, and no `SendChatMessage` without a click.

**3.2 /spruch — S [DEV]**
- About 40 guild-approved Sprüche in `L.SPRUECHE`.
- `/spruch` prints one locally, and `/spruch gilde` posts one through `Chat.SendGuild`.
- `/spruch tag` is the Spruch des Tages: the same for everyone, seeded from the Berlin `dayKey`.
- The last 5 are not repeated.
- **Acceptance:** specs cover the same daily saying on the same date, no repeats, and the post only happening from the slash handler.

**3.3 Settings page — S [DEV]**
- `Settings.RegisterVerticalLayoutCategory(L.ADDON_NAME)` with checkboxes through `RegisterAddOnSetting` and `CreateCheckbox`: Login-Gruß, Online-Meldungen, Grüßen-Popup, In Instanzen grüßen, Debug.
- `/spaeti optionen` uses `Settings.OpenToCategory(category:GetID())` (verify in-game), with a fallback chain in Compat.
- **Acceptance:** settings persist across `/reload` and relog (in-game check).

**3.4 GitHub alpha release pipeline — S [DEV]**
- `release.yml` triggers on tag `v*`, runs `BigWigsMods/packager@v2` with `GITHUB_OAUTH: ${{ secrets.GITHUB_TOKEN }}`, and publishes a GitHub pre-release with the zip.
- Testers can install from it by hand or through WowUp. CurseForge and Wago come later.
- **Acceptance:** tag `v0.1.0-alpha1` produces a correct release zip.

**3.5 Tester rollout — S [USER]**

M1 checklist in `docs/TESTING_INGAME.md`:
- G1: no greeting flood after login.
- G2: a member coming online produces one local line and one toast.
- G3: [Grüßen] posts to guild chat.
- G4: nothing happens in a dungeon.
- S1: `/spruch`, `/spruch gilde` and `/spruch tag` work.
- O1: settings persist.
- U6: umlauts render correctly.
- I2: no Lua errors.

**Acceptance:** testers report no Lua errors, and nobody perceives the toast as spam. Tag `v0.1.0`.

### Phase 4: M2 "Stammkunde" (v0.2: Spätipunkte and sync)

**Goal:** guild-wide Spätipunkte that converge on every client, with officer void in the same milestone.

**4.1 Codec and Comm transport — M [DEV]**
- `Codec.Encode` and `Decode`: a format byte, `pcall`, and a 64 KB decoded-size cap.
- Prefix registration on every load, with the result logged.
- The send gate and in-memory outbox (2.5 rules), the flush triggers, and `SF_COMM_STATE`.
- Receive: `Safe` check → `SenderToGUID` → per-sender rate limit → dispatch. Unknown senders are parked for 30 s while the roster refreshes.
- **Acceptance:** specs cover a random-table round trip, malformed input never throwing, queueing during lockdown and flushing afterwards, a trial client never sending, and the rate limit.

**4.2 OpLog — M [DEV]**
- `new(def, deps)`, `:Create(k, d)` (collision-proof ID), `:Ingest(op, {direct, senderGUID})`, `:DayHash(day)`, `:MonthHash(mk)`, `:OpsForDay(day)`, `:Prune(now)`.
- **Acceptance:** specs show the same digest for any arrival order (shuffled property test), no ID collisions across 10,000 ops with a reset counter or clock, unknown kinds kept, and pruned days excluded from digests.

**4.3 Sync engine — L [DEV]**
- HELLO, OP, DAYS and OPS as in 2.5, including:
  - the 15 min periodic HELLO;
  - HELLO after lockdown ends;
  - jitter and suppression;
  - the budget;
  - the version notice;
  - `SF_SYNC_STATE`.
- **Acceptance** (simulator with 30 clients and real throttle numbers):
  - all clients converge within 5 simulated minutes after a mass login;
  - no client gets more than 2 throttle results;
  - a client offline for a week heals;
  - random lockdown windows heal;
  - mixed `p`/`minp` versions don't crash and the notice fires once;
  - a live op lost to lockdown heals by the next HELLO.

**4.4 Spätipunkte — L [DEV]**
- **Op kinds:**
  - `thx {to, n}`;
  - `void {ref}`: by the author, or by a *current* officer;
  - `optout {on}`: self only; hides the player from leaderboards;
  - `erase {}`: self only; voids all of the player's own ops, a right-to-delete;
  - `cfg.set {key, value}`: guild master only for `officerMaxRankIndex`, officers for `pointsDailyLimit`. Last writer wins by `(t, id)`.
- **Bootstrap:** rank 0 (the guild master) is always an officer. The default threshold is rankIndex ≤ 1. A guild-master transfer is handled automatically, because authority is read from the current roster.
- **Derivation:** see 2.5. Output: totals per month and all time, given counts, and an identity-resolver hook for twinks later.
- **Ranks:** from `L.RANKS` by all-time points received. Placeholder ladder: Laufkundschaft 0 → Gelegenheitskunde 5 → Stammkunde 20 → Kiezgröße 50 → Spätiverkäufer 100 → Spätibesitzer 250, final names from the guild. Rank-ups are a **local print only**.
- **Commands:**
  - `/spaeti danke <Name> [Grund]`: shows a German reason for every rejection ("Tageslimit erreicht", "Nicht an dich selbst", "Meintest du …?");
  - `/spaeti punkte [Name]`;
  - `/spaeti liste` (Stammkunde des Monats, top 10, Berlin month) and `/spaeti liste gesamt`;
  - `/spaeti storno <Nr>` (officer);
  - `/spaeti privat an|aus`;
  - `/spaeti meinedaten löschen` (asks for confirmation).
- The recipient sees "Kalle sagt danke: <Grund> (+1 Spätipunkt)".
- **Acceptance (container):** the daily cap across Berlin midnight under DST, self-thanks ignored, voids applied (author and officer), a demoted officer's voids stopping identically on all clients, optout and erase, identical totals across simulated clients, and rank boundaries and ties (an earlier `t` wins).

**4.5 M2 rollout — M [USER]** *(2–3 players, then the whole guild)*

Checklist:
- C1: thanks arrive on all clients within 10 s.
- C2: a player who was offline catches up within about 1 minute of login.
- C3: thanks given in a dungeon are queued and delivered after leaving.
- C4: a trial account shows "Nur Empfang" and still receives.
- C5: an old and a new zip together produce the version notice and no errors.
- A1: self-thanks are rejected.
- A2: the 4th thanks of the day is rejected.
- A3: an officer storno removes the point for everyone.
- P1: data survives a relog.
- R1: forced-restriction test. With `/console addonChatRestrictionsForced 1`, the queue grows. After setting it back to 0, the queue drains and data converges.

**Acceptance:** `/spaeti status` shows the same month hash for every tester, and there are no disconnects. Tag `v0.2.0`, then announce it to the guild.

### Phase 5: M3 "Ladentheke" (v0.3: UI shell)

**Goal:** players use the window instead of remembering slash commands.

**5.1 Minimap and compartment — S [DEV]**
- LibDBIcon with `db.profile.minimap.hide` and `/spaeti minimap`.
- Left click opens the window, right click opens the settings.
- The tooltip shows the player's points this month, their rank, the number online and the Spruch des Tages.
- The TOC compartment functions.
- **Acceptance (in game):** the button can be dragged and hidden, and the position persists.

**5.2 Main window and widgets — M [DEV]**
- `UI/MainFrame.lua`: a plain frame, using `PortraitFrameTemplate` if it exists, otherwise `BackdropTemplate`.
  - Movable and resizable, position saved, ESC closes it through `UISpecialFrames`.
  - Tabs come from the Registry and are built the first time they open.
- `Widgets`: a scroll list (`ScrollBox`, falling back to `FauxScrollFrame`, per the probe), buttons, an edit box with roster autocomplete, and a dropdown (`MenuUtil` if present).
- No secure templates, and nothing writes to Blizzard frames.
- **Acceptance (in game):** opening it in combat causes no errors and no taint lines.

**5.3 Tabs — M [DEV]**
- **Start:** greeting, own rank with a progress bar, Spruch des Tages, the last 5 thanks received.
- **Punkte:** a month/all-time toggle, the leaderboard, and a "Danke sagen" form with a name picker and a reason field.
- **Online:** online members with name, level, class colour, zone (through `Safe.text`), AFK/DND, mobile flag and rank badge. Sortable, refreshed on roster events.
- **Info:**
  - version and peer versions seen;
  - send state ("Senden möglich: ja/nein (Grund)", "Nur Empfang");
  - lockdown state;
  - per-store op count and month hash (the "Prüfsumme");
  - a "Sync jetzt" button;
  - a log export button.
- **Acceptance:** the tabs match the chat commands, and they refresh live on a new op or roster change.

**5.4 Guild Sprüche (synced) — S [DEV]**
- `cfg` kinds `spruch.add` and `spruch.del`.
- Who may add is decided by the guild (open question). The default is officers.
- Text is sanitised to at most 200 bytes, with a limit of 5 per author per week, enforced in derivation.
- `/spruch neu <Text>`, `/spruch weg <Nr>`, `/spruch liste`.
- **Acceptance:** an added saying appears on a second client, and a non-officer gets a German refusal.

**5.5 M3 test — S [USER]**
- U1: the minimap button works and can be hidden.
- U2: the compartment entry works.
- U3: the window moves, resizes and closes with ESC.
- U4: tabs switch.
- U5: the settings open.
- U7: the window opens in combat without errors.
- U8: the window position survives `/reload`.
- UI scale 0.64 and 1.0 both look right, and long German names truncate properly.
- Tag `v0.3.0`.

### Phase 6: v1.0 "Eröffnung" (hardening and release)

**6.1 Guild beta 0.9.x — M [USER] + [DEV]**
- 5–10 testers for 7 or more days, using GitHub pre-releases `v0.9.0-beta.N`.
- A German issue template in `.github/ISSUE_TEMPLATE` that asks for the log window export.
- **Acceptance:** no unresolved Lua errors, identical Prüfsumme for all testers, and the full checklist green.

**6.2 Hardening — M [DEV]**
- Every event and comm handler runs inside `xpcall`, with errors logged.
- Audit every chat and system text path for `Safe.text`.
- No `OnUpdate` handlers. Derivation is cached and invalidated on `SF_STORE_CHANGED`. Large merges are split across frames with `C_Timer.After(0)`.
- Memory is shown in Info.
- Taint audit: with `/console taintLog 1` during a raid evening, there are no SpaetiFreunde lines [USER].
- Forced-restriction test with both CVars (`addonChatRestrictionsForced`, `addonEncounterRestrictionsForced`) [USER].
- **Acceptance:** under 2 MB memory with 1,000 ops, and no hitch during a 1,000-op sync (simulator fixture plus an in-game check).

**6.3 Privacy and data controls — S [DEV]**
- A leaderboard opt-out in the settings, through the `optout` op.
- `meinedaten löschen`.
- An officer "Saison archivieren" (`cfg.set season=<monthKey>`, guild master only). Leaderboards then start from that month, and older data stays as history.
- Members who have left the guild show as "(ehemalig)" and are excluded from "Stammkunde des Monats".
- The README explains what is stored and synced.

**6.4 Text pass — S [USER] + [DEV]**
- A native speaker from the guild reviews every string in `deDE.lua`.
- Write the German README: installation, commands, Spätipunkte rules, officer guide, and an FAQ ("Warum geht im Dungeon nichts?", "Testkonto?").
- Screenshots from the user.

**6.5 Store release — S [USER] + [DEV]**
- **[USER]:** create the CurseForge and Wago projects for the Forever game, and add the repo secrets `CF_API_TOKEN` and `WAGO_API_TOKEN`. I never handle the tokens.
- **[DEV]:** add `X-Curse-Project-ID` and `X-Wago-ID` to the TOC. `release.yml` uploads to CurseForge, Wago and GitHub, and passes `-g 1.60.1` if CurseForge rejects auto-detection.
- **[DEV]:** `docs/RELEASE.md`:
  1. Check `/dump select(4, GetBuildInfo())` and bump `## Interface` on every Forever patch.
  2. Update the CHANGELOG (German).
  3. Tag the release.
  4. Smoke-test the build installed from the store.
- **Acceptance:** tag `v1.0.0` appears in the CurseForge/Wago app for Forever, and a fresh install passes I1–I3.

**6.6 Go-live — S [USER]**
- A guild announcement in German: installation, commands, "Spätipunkte sind ein Spaß-Feature".
- Officer rank threshold set.
- A v1.0.1 hotfix slot 3 days after launch.

### Phase 7+: Post-v1 features (each is its own minor release)

Every feature gets:
- a short design note;
- an entry in `PROTOCOL.md` and a `validate` function per op kind;
- authority and retention decisions;
- pure specs, plus a simulator scenario if it syncs;
- strings in `deDE.lua` only;
- new checklist items;
- a beta tag.

| Release | Feature | Plan | Size |
|---|---|---|---|
| v1.1 | **Termine (Raid-/Event-Planer)** | **Calendar first.** If the probe shows `C_Calendar` guild events with signup work on Forever, the addon becomes a friendly view of them: list, Zusage/Vielleicht/Absage through the calendar API (verify in-game), with roles added as an `rsvp.role` op. Otherwise, store `events` with `ev.new` (any member), `ev.edit` and `ev.cancel` (author or officer, last writer wins per field) and `rsvp {ev, st, role}` (self only, last writer wins). Berlin time, a local reminder 15 min before, and a button to post the line-up to guild chat. | M (calendar) / L (op log) |
| v1.2 | **Pfandflaschen-Sammler** | Finds roll on `QUEST_TURNED_IN` and `ZONE_CHANGED_NEW_AREA`, plus an occasional out-of-combat check with `IsPlayerMoving()`, not resting, not in an instance. Never combat events. Op `pfand.find {typ}`. The daily cap is enforced in derivation. Weekly ranking from Monday 00:00 Berlin. Bottle types in `L.PFAND`: Bierflasche 8 ct, Bügelflasche 15 ct, PET 25 ct, and a rare "Goldene Mate-Flasche". A tab, and a winner line to post by click. | M |
| v1.3 | **Gilden-Pinnwand** | `post.new {cat = suche/biete/info, text ≤ 200}`, `post.del` (author or officer), expiry after 14 days, at most 3 active posts per member. Check the guild info text and guild news APIs for overlap first. | M |
| v1.3 | **Twink-Verwaltung** | `alt.claim {main}`, written by the alt, plus `alt.confirm {alt}`, written by the main character. Only the confirmed pair counts, or an officer can set it. Points can be aggregated per main, self-thanks between your own characters are blocked, and the Online tab shows "(Twink von X)". | M |
| v1.3 | **Geburtstage/Jubiläen** | Opt-in `date.set {kind, day, month}`, self only, no year. A local reminder on login, and a [Gratulieren] click that posts to guild chat. | S |
| v1.4 | **Berufe-Verzeichnis** | Probe the built-in guild tradeskill API first. If it exists, build a search UI on top of it. Otherwise, each player publishes a `prof.set` snapshot of recipe IDs, compressed to 2 KB or less, captured when they open their own profession window. Search uses `C_Item`. | M / L |
| v1.5 | **Würfelspiele** | Lotterie and Höher/Tiefer for grouped or nearby players. Rolls are parsed with `PatternFromFormat(RANDOM_ROLL_RESULT)` through `Safe.text`. The host runs the game, broadcasts results by addon message, and posts to chat on click. Marked "nur außerhalb von Instanzen". | M |
| v1.5 | **Gilden-Quiz** | The quizmaster's client is the authority. Questions come from `L.QUIZ` plus officer additions. Answers are sent by addon message, and scores are written as `quiz.score` ops by the quizmaster. If WHISPER is unverified, answers go over GUILD as hashes, which can be brute-forced; acceptable for fun. | M |
| v1.5 | **Erfolge-Feed** | Derived locally from existing stores ("10 Dankes verteilt", "Erste Goldene Mate"). A feed tab. No new sync. | S |

---

## 4. Risks and mitigations

| # | Risk | Mitigation |
|---|---|---|
| R1 | No in-game testing in the container | Pure logic with mocks and a multi-client simulator; a probe addon on day 2; per-milestone German checklists; guild beta; copyable log export; CI zip on every commit; optional smoke test on Midnight retail through `120105` |
| R2 | The Forever API differs from the brief | Probe existence checks; one-time `Compat` resolution with fallbacks; Compat branches shown in `/spaeti status` |
| R3 | Name and sender format (no realms, surnames) | All data keyed by GUID; all name logic in `Guild/Names.lua`, finalised after the probe; longest-match/quoted name parsing; GUILD-only sync until WHISPER targets are verified |
| R4 | Chat and addon-message lockdown, silent drops | Gate sends before AceComm; in-memory outbox; conservative "no sends in instances" until probed; periodic HELLO heals losses; forced-restriction CVar tests |
| R5 | Throttle disconnects during login storms | One prefix; ChatThrottleLib; 10–40 s jitter; digest-first sync with day-level narrowing; response suppression; 20 messages per minute per client; tested in the simulator |
| R6 | Clients diverge (version mix, roster changes) | Set-union op log; admission never depends on the roster; derivation uses the current roster on every client; `p`/`minp` version rule; Prüfsumme comparison in beta |
| R7 | Op ID collisions after WTF loss or a second PC | IDs built from GUID, server time and a random part, with no stored counter |
| R8 | Cheating on Spätipunkte | Sender check on direct ops; caps and self-thanks enforced in derivation; officer void from v0.2; honest "cheat-resistant, not cheat-proof" statement |
| R9 | Auto-posts or a lost hardware event | `Chat.SendGuild` only synchronously from click or slash handlers; spec guard; probe tests click, slash and timer |
| R10 | Secret values crash string operations | `Safe.text` on every chat and system path; `issecretvalue` mock in specs; nothing secret in SavedVariables |
| R11 | Taint of Blizzard UI | No secure templates or Blizzard frame writes; taint-log audit before v1.0 |
| R12 | Encoding problems (BOM, split UTF-8, `Ä` folding, `\|` injection) | Encoding CI check; UTF8 helpers with tests; `sanitizeUserText` |
| R13 | English text slips in | `check-locale` and `check-strings` in CI |
| R14 | SavedVariables growth or corruption | 400-day pruning; migrations with fixture tests and a read-only fallback |
| R15 | Libraries or packager on Forever (Ace3 r1403 lacks 16001, packager quirks) | Trunk/alpha externals; unsuffixed TOC; packager dry run in CI from week 1; `-g 1.60.1` fallback; GitHub zip always produced |
| R16 | Interface number goes out of date after a patch | Bump step in `RELEASE.md`; comma-separated interface list |
| R17 | Privacy concerns | No officer notes cached; leaderboard opt-out; self-erase; opt-in birthdays; anonymised probe dumps |
| R18 | Probe side effects on the live guild | Burst capped at 12; guild warned in `PROBE.md`; only our prefix recorded |
| R19 | Trial or Veteran players think it's broken | "Nur Empfang" mode with a German status line |

---

## 5. Open questions for the guild and user

1. **Officers:** which guild rank index counts as "Offizier" (for storno, saying moderation, `cfg`)? Is the default "guild master plus rank 1" right?
2. **Ranks:** final names and thresholds. The placeholders are Laufkundschaft 0 → Gelegenheitskunde 5 → Stammkunde 20 → Kiezgröße 50 → Spätiverkäufer 100 → Spätibesitzer 250.
3. **Spätipunkte rules:** are 3 thanks per giver per day OK? Should there also be a limit of 1 per giver-receiver pair per day? Should the reset be Berlin midnight (proposed)? Is a monthly "Stammkunde des Monats" right, or should seasons be longer?
4. **Texts:** about 40 Berlinerisch Sprüche, login and online greeting lines, guild in-jokes, Kiez and Spandau references, and Pfand flavour texts. Who is the native-speaker reviewer?
5. **Guild Sprüche:** may everyone add them (with moderation), or officers only?
6. **Guild identity:** the exact guild name spelling, and whether there are twink or sister guilds that should share data.
7. **Testers:** names for 3–5 M1 testers and 5–10 beta testers. Does anyone have a trial or veteran account?
8. **Feature order after v1.0:** Termine (proposed) or Pfand first? Does the guild already use the in-game guild calendar?
9. **Distribution:** CurseForge and Wago (needs accounts and tokens from the user), or GitHub releases and WowUp only?
10. **Licence:** MIT (proposed), or "all rights reserved" for a guild-only addon?
11. **Privacy defaults:** leaderboard visible by default with opt-out (proposed), or opt-in?
12. **Art:** is there a Späti logo for the minimap and compartment icon (64×64 TGA)? Until then a built-in drink icon is used.

---

## 6. Sources

- TOC format (Interface 16001, game types, Category, compartment fields): https://warcraft.wiki.gg/wiki/TOC_format
- Patch 1.60.1 API changes (WOW_PROJECT_CAMELOT, SendChatMessage hardware event): https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes
- Getting the current interface number: https://warcraft.wiki.gg/wiki/Getting_the_current_interface_number
- C_ChatInfo.SendAddonMessage (limits, result codes, trial accounts): https://warcraft.wiki.gg/wiki/API_C_ChatInfo.SendAddonMessage
- C_ChatInfo.RegisterAddonMessagePrefix: https://warcraft.wiki.gg/wiki/API_C_ChatInfo.RegisterAddonMessagePrefix
- C_ChatInfo.InChatMessagingLockdown: https://warcraft.wiki.gg/wiki/API_C_ChatInfo.InChatMessagingLockdown
- CHAT_MSG_ADDON: https://warcraft.wiki.gg/wiki/CHAT_MSG_ADDON
- CHAT_MSG_SYSTEM: https://warcraft.wiki.gg/wiki/CHAT_MSG_SYSTEM
- Patch 12.0.0 API notes (restrictions, SavedVariables and secrets): https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes/notes
- Secret Values: https://warcraft.wiki.gg/wiki/Secret_Values
- Creating a slash command: https://warcraft.wiki.gg/wiki/Creating_a_slash_command
- Settings API: https://warcraft.wiki.gg/wiki/Settings_API
- Addon compartment: https://warcraft.wiki.gg/wiki/Addon_compartment
- C_GuildInfo.GuildRoster: https://warcraft.wiki.gg/wiki/API_C_GuildInfo.GuildRoster
- GetGuildRosterInfo: https://warcraft.wiki.gg/wiki/API_GetGuildRosterInfo
- RandomRoll: https://wowprogramming.com/docs/api/RandomRoll.html
- Wowhead, Forever addon changes: https://www.wowhead.com/news/wow-forever-will-have-addon-changes-from-midnight-382921
- Icy Veins, Forever addons: https://www.icy-veins.com/wow-forever/news/addons-in-wow-forever-blizzard-devs-just-addressed-the-big-question/
- wowforevertierlist, restrictions: https://wowforevertierlist.com/addons/restrictions
- wowforeverguides, developer guide: https://wowforeverguides.com/addons/developers
- forevermastery, installing addons: https://forevermastery.com/en/guides/install-addons
- wowhandbook, character names: https://wowhandbook.com/news/wow-forever-character-names/
- howtovideogame, rulesets and surnames: https://howtovideogame.com/wow-forever-rulesets-surnames/
- bff-wow research issue: https://github.com/Shtian/bff-wow/issues/3
- Addon Restriction Tester: https://www.curseforge.com/wow/addons/addon-restriction-tester
- Ace3: https://www.wowace.com/projects/ace3
- LibDBIcon-1.0: https://www.curseforge.com/wow/addons/libdbicon-1-0
- BigWigsMods packager: https://github.com/BigWigsMods/packager (issue #204: https://github.com/BigWigsMods/packager/issues/204)
- luacheck action: https://github.com/nebularg/actions-luacheck
- WoW API annotations for VS Code: https://github.com/Ketho/vscode-wow-api
