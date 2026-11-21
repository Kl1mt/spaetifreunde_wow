# Spätifreunde Spandau Addon – Lean Plan (the plan we follow)

This is the plan we work from. `docs/PLAN.md` is the detailed background: research, risks, Forever API facts. Use it as a reference, not a checklist.

**Lean means:** **all features stay.** The engineering behind them is simpler:
- Plain WoW API plus a few small libraries. No full Ace3 stack.
- Simple sync: snapshot plus last-writer-wins, with officers able to correct values. No op log with digests, and no multi-client simulator.
- CI only lints and builds a zip.
- Hardening happens later, and only where real problems show up in the guild.

## Decisions (from the user)
| Topic | Decision |
|---|---|
| Officers | The guild master plus every member whose guild rank name is `Officer` |
| Rank names | Laufkundschaft 0 → Gelegenheitskunde 5 → Stammkunde 20 → Kiezgröße 50 → Spätiverkäufer 100 → Spätibesitzer 250 |
| Sprüche | Collect common Berlin sayings and Berlinerisch phrases from the web (short, common sayings only) |
| Testers | The user recruits them |
| Distribution | GitHub releases only, as a zip attached to a release |
| Licence | Guild-only, all rights reserved |
| Language | All user-facing text is German, in `Locale/deDE.lua` |
| Chat posting | The addon **never posts to guild/say/yell chat**, not even on click. Everything is shown locally; members see each other's data only via hidden addon-message sync. Later features (Termine, Würfelspiele, Quiz, Pfand winners) must follow this too |

## Ground rules for every session
- The game client is not available in the container. Each subtask ends with a **German in-game test checklist** in `docs/TESTING_INGAME.md`, which the user works through.
- Respect Forever/Midnight restrictions:
  - no combat-log use and no combat automation;
  - posts to guild chat only directly from a click or a slash command;
  - check `C_ChatInfo.InChatMessagingLockdown()` (if it exists) before sending;
  - guard chat text against secret values.
- Mark uncertain API usage with `-- VERIFY IN-GAME` and guard it with existence checks.
- Key players by GUID where possible. Names are for display.
- Folder and addon name: `SpaetiFreunde`. TOC `## Interface: 16001, 120105` (verify in-game). SavedVariables: `SpaetiFreundeDB`.
- Slash commands: `/spaeti` (ASCII) plus `/späti` as an alias.
- Run `luacheck` before committing.

## Subtasks (one session each)

| # | Subtask | Depends on | Branch |
|---|---|---|---|
| S1 | **Probe addon** `tools/SpaetiProbe/` + `docs/PROBE.md` (German instructions): checks Forever API existence, name/GUID formats, addon message send/receive, chat lockdown, slash umlauts, system message formats; `/sfprobe` shows a copyable report | – | `claude/spaeti-s1-probe` |
| S2 | **Foundation + M1 "Erster Kunde"**: repo setup (`.luacheckrc`, `.editorconfig`, `.gitignore`, LICENSE, German README with install steps, CI lint + zip build + release on tag), TOC, locale, SavedVariables + migrations stub, guild roster cache with officer check, slash commands, minimal main window shell with tabs + minimap/compartment button + settings panel, **login greeting**, **online greeting** (local display only; the click-to-post "Willkommen" link was dropped at the user's request — the addon never posts to guild chat), **/spruch** (~40 sayings, local only; guild-chat posting was dropped at the user's request), `/spaeti status` | – | `claude/spaeti-s2-core` |
| S3 | **M2 Spätipunkte**: `/spaeti danke <Name>`, limits (3 per day per giver, no self-thanks, Berlin midnight reset), ranks, leaderboard tab, "Stammkunde des Monats", officer correction, simple guild sync (prefix `SpaetiFreunde`, versioned messages, throttled, snapshot exchange on login) | S1 results, S2 | `claude/spaeti-s3-punkte` |
| S4 | **v1.0 "Eröffnung"**: fixes from guild tests, polish, online tab, GitHub release v1.0.0 | S3 + tester feedback | `claude/spaeti-s4-release` |
| S5 | **Termine (Event-Planer)**: use the guild calendar if the probe shows it works, otherwise our own synced events with Zusage/Vielleicht/Absage + roles | S4 | `claude/spaeti-s5-termine` |
| S6 | **Pfandflaschen-Sammler**: random finds on quest turn-in or zone change (never combat), daily cap, weekly ranking | S4 | `claude/spaeti-s6-pfand` |
| S7 | **Gilden-Pinnwand**: Suche/Biete/Info posts, expiry, officer delete | S4 | `claude/spaeti-s7-pinnwand` |
| S8 | **Twinks + Geburtstage**: alt→main links (confirmed by both characters), opt-in birthdays and guild anniversaries | S4 | `claude/spaeti-s8-twinks` |
| S9 | **Berufe-Verzeichnis**: who can craft what, searchable | S4 | `claude/spaeti-s9-berufe` |
| S10 | **Würfelspiele + Gilden-Quiz** | S4 | `claude/spaeti-s10-spiele` |
| S11 | **Erfolge-Feed**: fun guild achievements derived from existing data | S6+ | `claude/spaeti-s11-erfolge` |

S1 and S2 run in parallel. They touch different folders. Each later subtask starts from the integration branch `claude/nifty-sagan-tbuth2` once its dependencies are merged there. From S5 on, features can run in parallel if they don't touch the same files.
