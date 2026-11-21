# Addon message protocol (Spätipunkte sync)

Protocol version **1**. Code: `Core/Codec.lua` (format), `Core/Comm.lua` (transport),
`Modules/Sync.lua` (message types), `Modules/PointsData.lua` (data model and rules).

## Transport
- Prefix `SpaetiFreunde`, channel `GUILD` only. Nothing is ever sent to visible chat.
- `CHAT_MSG_ADDON` sender = `"Vorname Nachname"`, which is the roster name (confirmed). It is mapped to a GUID through the roster cache. If the sender is unknown or is ourselves (our own echo, detected by GUID), the message is ignored.
- **Send queue** with a token bucket: 8 burst, 1 token per second. The server allows 10 burst, then returns `3 AddonMessageThrottle`. Two queues: *high* for N/H/D/R and *bulk* for E chunks. A throttle result puts the message back and empties the bucket.
- **Gate:** the queue is kept and pauses instead of sending when
  - `C_ChatInfo.InChatMessagingLockdown()` returns exactly `true` (checked before sending), or
  - a send returns `11 AddOnMessageLockdown` (the real lockdown signal).

  `AreOutgoingAddonChatMessagesRestricted()` and `IsAddOnRestrictionActive(Chat)` are only shown in
  `/spaeti status` (unverified on Forever, they reported "restricted" while sending worked).
  The queue retries every 5 s and right away on `ADDON_RESTRICTION_STATE_CHANGED` (one retry timer
  at a time, however often the event fires). It stays *paused* until a send succeeds again.
- Every message is at most 255 bytes, plain printable ASCII.

## Message format
```
<proto>~<type>~<field>~<field>...
```
- `proto`: integer. A message with a **higher** number than ours is ignored, and the player sees one local "please update" notice per session. Message types we don't know, and extra fields, are ignored too. So a protocol 1 client survives additions.
- `type`: one upper-case letter.
- Lists are separated by `,`. Sub-fields are separated by `:`.
- Numbers: counts and days in decimal. Times and hashes in base36 (`0-9a-z`).
- GUIDs are sent without the `Player-` prefix: `6949-0A1B2C3D`.

### Entries
```
T:<id>:<giverGUID>:<receiverGUID>:<time36>     thank
V:<id>:<officerGUID>:<targetId>:<time36>       officer void of thank <targetId>
```
- `id` = `<last 6 hex digits of the author's GUID>.<serverTime36>.<random36>`, e.g. `a1b2c3.t5k2ab.x3f`.
- Entries are immutable. Every client stores the union of all entries it has seen, keyed by id, so merging is idempotent.
- Structural checks on receipt:
  - valid id and GUIDs;
  - no self-thanks;
  - time ≥ 2026-11-01 (Berlin);
  - time at most 1 h in the future (clock skew).

  Unknown entry kinds are dropped.

### Message types
| Type | Fields | Sent by | Meaning |
|---|---|---|---|
| `N` | `entry` | author, once | New thank or void. **Accepted only if sender GUID == entry author.** |
| `H` | `fromMonth~toMonth~mk:count:hash,...` | everyone, 10–40 s after login, then every 15 min (+0–60 s) | HELLO: summary per Berlin month `YYMM` from 2611 to the current month. A month in the range but missing from the list has 0 entries. Split into several messages if needed; each covers its own range. |
| `D` | `target~mk~fromDay~toDay~dd:count:hash,...` | peers whose month summary differs from a HELLO, after 1–5 s jitter | DAYS: our per-day summary of month `mk` for the HELLO sender `target`. **Suppression:** if an identical DAYS part from someone else for the same target was seen (60 s), ours is not sent. A new HELLO from the target clears that (e.g. after `/reload`). **Not sent while we catch up on `mk` ourselves** (see below). |
| `R` | `target~mk~dd,dd,...` | the HELLO sender, after a DAYS | REQ: "`target`, please send your entries of these days". Only days where `target` has entries and our summary differs. **Each day is requested from one DAYS sender only**, and not again while that request is outstanding (sent < 120 s ago, or new entries still arrived within 45 s). |
| `E` | `entry,entry,...` | the HELLO sender (days where it has entries and the summaries differ), and the `R` target | ENTRIES: relayed entries in chunks ≤ 255 bytes. **Accepted from any guild member.** Not queued again: days still waiting in our queue, and days for which someone other than the peer we answer sent `E` within 30 s (that dump is already on the air). |

**Catching up** on month `mk` means: an `E` brought us new entries of `mk` within 45 s, or one of
our `R` for a day of `mk` is outstanding. While catching up we don't answer HELLOs for `mk`: our
answer would only make the HELLO sender dump the days we still lack, which are on the air anyway.

Anything skipped by these rules is picked up by the next HELLO (every 15 min). They only change
*when* a client sends, not the message formats: clients without them still interoperate, they
just send more.

`count:hash` = number of ids plus the sum of `djb2(id)` mod 2³², base36. The sum doesn't depend on order, and every client computes it identically.

### Typical catch-up
1. B was offline and logs in. 10–40 s later B sends `H`.
2. A has a different November and waits 1–5 s. A sends `D` for November. C has the same data as A, sees A's `D` and stays quiet.
3. B compares the days:
   - B pushes `E` with the entries of days where it has data that differs;
   - B sends `R` for days where A has entries.
4. A answers the `R` with `E` chunks. Everyone listening ingests them, idempotently.

Measured in the mock (`tests/`): 11 peers, 627 entries. A fresh client converged in about 185 s with 157 `E` + 1 `H` + 2 `D` + 2 `R` messages and 0 throttle results.

## Rules applied at derivation time (same result on every client)
1. A void counts only if its author is an officer **in the current roster** (guild master, or rank name `Officer`).
2. Voided thanks are removed before the limits are applied, so a voided thank frees its daily slot.
3. The remaining thanks are sorted by (time, id). Per Berlin day (`Core/Time.lua`, reset at Berlin midnight):
   - at most **3** per giver;
   - at most **1** per giver→receiver pair.

   Later thanks over the limit don't count.
4. Points = accepted thanks received (all time). Ranks: Laufkundschaft 0, Gelegenheitskunde 5, Stammkunde 20, Kiezgröße 50, Spätiverkäufer 100, Spätibesitzer 250.
5. Stammkunde des Monats = most accepted thanks in the current Berlin month. Ties go to whoever reached that count first, then the lower GUID.

## Trust model: cheat-resistant, not cheat-proof
- A direct `N` must come from the author. A modified client can still relay invented entries through `E`.
- Invented entries still have to obey the derivation rules: max 3 per giver per day, and voids only from current officers.
- Officers can void any thank.
- Nothing is pruned yet. The data is small: a whole year at 20 thanks a day is about 7,000 entries, or about 400 KB of SavedVariables.
