# Activity tag deduplication, delete-with-reassign, and registry

> **Status:** Awaiting approval (not implemented)  
> **Parent:** [`SPEC_IN_PROGRESS.md`](../../../SPEC_IN_PROGRESS.md)  
> **Touches:** `specs/hourly-tracker.md`, `specs/timer.md`, `specs/notion.md`, `specs/shared.md`

**Goal:** One canonical tag per normalized name; migrate existing duplicate custom/recovered tags into built-in defaults where names collide; delete custom tags only via a reassign-required flow; keep a generated registry doc in sync with Notion.

**Decisions (approved 2026-09-03):**

| Topic | Choice |
|-------|--------|
| Name collision winner | Built-in default always wins |
| Deletable tags | Custom only (defaults stay protected) |
| Delete disposition | Reassign to another tag only (target required) |
| Same-hour collision after reassign | Merge rows: sum `durationMinutes`, reconcile notes/projects |
| Registry documentation | Notion registry + auto-generated `specs/activity-tags.md` on every tag save/delete/migration |
| Mid-session tag changes | **Blocked** while a work lap is running; pause first (snackbar explains) |

---

## 1. Problem

### 1.1 Duplicate tags in the wild

`_recoverTagsFromHourlyLogs` recreated custom tags from denormalized hourly-log names when no registry row existed. That produced **second tags with the same display name** as built-in defaults (different id/icon/color).

**Current duplicates on this device (merge into default):**

| Duplicate (delete) | Canonical (keep) |
|--------------------|------------------|
| `tag_custom_recovered_deep_work` | `tag_deep_work` |
| `tag_custom_recovered_coding___dev` | `tag_coding` |
| `tag_custom_recovered_reading___learning` | `tag_reading` |

**Custom tags to keep (unique names, no default collision):**

| ID | Name |
|----|------|
| `tag_custom_recovered_system_building` | System Building |
| `tag_custom_recovered_doom_scrolling` | Doom Scrolling |
| `tag_custom_recovered_socializing` | Socializing |
| `tag_custom_1784397860027_television` | Television |
| `tag_custom_1784067948722_planned_downtime` | Planned Downtime |
| `tag_custom_1784969723039_household_chores` | Household Chores |
| `tag_custom_1786923458817_gaming` | Gaming |

**Post-migration expected count:** 7 defaults + 7 customs = **14 tags**.

### 1.2 Weak delete UX

Deleting a custom tag today only removes it from `Prefs.trackerTags` and publishes a Notion tombstone. Hourly logs keep denormalized fields pointing at the old `tagId`. Focus timer and hourly dialog both use a simple confirm dialog with no reassignment.

### 1.3 No maintained inventory

Tag list lives only in `SharedPreferences` and Notion registry rows. No repo-visible canonical list for agents or operators.

---

## 2. Product rules (ongoing)

1. **Unique name:** `TrackerTagHelper.normalizeName(name)` must be unique across all tags in `Prefs.trackerTags`. Creation already blocks duplicates; recovery and sync must not violate this.
2. **Default precedence:** On any name collision between a default (`isDefault: true`) and a custom/recovered tag, the **default id wins**. Custom copy is removed after logs are reassigned.
3. **Custom delete only:** Built-in tags cannot be deleted from Focus timer or hourly dialog (unchanged).
4. **Delete = reassign:** Removing a custom tag always requires choosing a **target tag** from the remaining list. No "orphan historical logs" path.
5. **Hour merge:** After reassignment, at most one `HourlyLog` per `(dateStr, hour, tagId)`. If multiple rows would share that key, merge:
   - `durationMinutes` = sum of merged rows (cap not applied; timer credit may already exceed 60).
   - `notes`: join non-empty unique notes with `; ` (trimmed).
   - `projectId` / `projectTitle`: union comma-separated ids/titles, deduped, order preserved.
   - `loggedAt`: max of merged rows.
   - `notionPageId`: keep the page from the row with latest `loggedAt`; archive superseded Notion pages via existing hourly replace/archive path.
   - Regenerate `id` via `QuietHoursHelper.logId(dateStr, hour, tagId)`.
6. **Registry doc:** `specs/activity-tags.md` is **auto-generated**. Header states "Do not edit manually." Regenerated after: tag save, tag delete (with reassign), dedup migration, successful `syncActivityTags` when tag set changes.

---

## 3. One-time migration (bootstrap)

Run once per install on app bootstrap (after `Prefs.init`, before UI), idempotent via `Prefs.activityTagDedupMigrationVersion`.

### 3.1 Algorithm `TagDedupMigration.run()`

1. Load `Prefs.trackerTags` and `Prefs.hourlyLogs`.
2. Build groups keyed by `TrackerTagHelper.normalizeName(tag.name)`.
3. For each group with more than one tag:
   - Pick **canonical**: the tag with `isDefault: true` if any; else the tag with the **earliest** `loggedAt` among its hourly logs; tie-break by lexicographic id.
   - For every non-canonical tag in the group, call `TagReassignHelper.reassignTagId(fromId, toTag: canonical)` (same helper as delete flow).
   - Remove non-canonical tags from `trackerTags`.
   - Tombstone removed tags in Notion (`deleteActivityTag` / `syncActivityTag(deleted: true)`).
4. Rewrite `lastTimerTagIds`: map removed ids to canonical ids; dedupe list.
5. Set `activityTagDedupMigrationVersion = 1`.
6. Regenerate `specs/activity-tags.md` (dev/desktop only writes to app bundle path is wrong - see 5.2).

### 3.2 Recovery fix

Change `_recoverTagsFromHourlyLogs` so it **never creates a new tag** when `normalizeName` already exists in `local`:

- If an hourly log references a name that matches an existing tag, **rewrite the log's `tagId` and denormalized fields** to the canonical tag instead of adding `tag_custom_recovered_*`.
- Only create a recovered tag when the name is genuinely unknown and not tombstoned.

This prevents regression after migration.

---

## 4. Delete-with-reassign UX

### 4.1 Shared dialog: `TagDeleteDialog`

Used from:

- `TimerTagBar` (Focus timer): long-press custom tag chip (keep); add optional trailing **delete** affordance on custom chips for discoverability (icon button or context menu).
- `HourlyLogDialog`: close/delete on custom tag chip (replace current confirm).

**Content:**

- Title: `Delete tag?`
- Body: `Reassign existing logs from "{icon} {name}" to another tag.`
- Show affected log count: `N hourly log rows` (0 allowed: still require picking a target for consistency, or auto-disable delete when N=0 and only remove from picker - **prefer allow delete with any target when N=0**).
- **Required** dropdown / searchable list of all other tags (exclude tag being deleted).
- Actions: `Cancel` | `Delete and reassign` (disabled until target selected).

### 4.2 On confirm

1. `TagReassignHelper.reassignTagId(from, to)` on all `Prefs.hourlyLogs` (+ pending hourly queue entries referencing `from`).
2. Update `lastTimerTagIds` if needed.
3. `NotionSyncService.deleteActivityTag(from)` (local remove + tombstone).
4. Refresh UI tag lists; `TimerCubit.removeActiveTag(from)` and add `to` if deleted tag was active (optional: switch selection to target - **default: replace active slot with target**).
5. Regenerate registry doc.
6. Snackbar: `Reassigned N logs to {target.icon} {target.name}`.

### 4.3 Built-in tags

No delete entry point. Long-press and delete affordance hidden/disabled for `isDefault` tags.

---

## 5. Registry documentation

### 5.1 File: `specs/activity-tags.md`

Auto-generated markdown:

```markdown
# Activity tags registry (auto-generated)

Do not edit manually. Updated by TagRegistryWriter on tag changes.

| Icon | Name | ID | Default | Color |
...
```

Sorted: defaults first (fixed order from `TrackerTag.defaults`), then customs alphabetically by name.

### 5.2 `TagRegistryWriter`

- Pure Dart helper + single write call from `NotionSyncService` after tag mutations.
- **Desktop/dev:** write to repo path `specs/activity-tags.md` when running from a writable project root (detect via `File('pubspec.yaml').existsSync()` relative to cwd or a compile-time flag). If not writable (installed `.app`, mobile), skip file write silently; in-memory/registry still correct via Prefs + Notion.
- **Tests:** write to temp dir via injectable path.

### 5.3 Notion remains sync source across devices

`syncActivityTags` continues to reconcile registry rows. Generated md is a **snapshot for this device/repo checkout** after local mutations, not a second source of truth.

---

## 6. Technical design

### 6.1 New helpers

| File | Responsibility |
|------|----------------|
| `lib/helpers/tag_reassign_helper.dart` | `reassignTagId`, `mergeLogsForHour`, count logs for tag |
| `lib/helpers/tag_dedup_migration.dart` | One-time migration v1 |
| `lib/helpers/tag_registry_writer.dart` | Generate `specs/activity-tags.md` content |

### 6.2 `TagReassignHelper.reassignTagId`

```
Input: fromId, toTag (TrackerTag)
1. Map every HourlyLog where tagId == fromId -> copyWith canonical denormalized fields from toTag, new id
2. Group by (dateStr, hour, tagId) and merge collisions
3. Replace logs in Prefs.hourlyLogs atomically
4. Rewrite pendingHourlyLogs JSON tagId fields
5. For each affected (dateStr, hour), call NotionSyncService.replaceHourlyLogsForHour to push merged slot
6. Return count of logs touched
```

### 6.3 Prefs

- New key: `pomo_activity_tag_dedup_migration_version` (int, default 0).

### 6.4 Bootstrap hook

`lib/bootstrap.dart`: after Notion tag sync on startup, run `TagDedupMigration.runIfNeeded()` then `TagRegistryWriter.writeIfPossible()`.

### 6.5 Spec updates (after ship)

- `specs/hourly-tracker.md`: delete flow, unique names, registry file
- `specs/timer.md`: delete-with-reassign on tag bar
- `specs/notion.md`: recovery no longer creates duplicate names
- `specs/shared.md`: migration version key, `specs/activity-tags.md`
- `SPEC.md`: link `specs/activity-tags.md` in index

---

## 7. Test plan

| Area | Cases |
|------|-------|
| `TagReassignHelper` | Reassign updates tagId + denormalized fields; merges same-hour rows; sums minutes; dedupes projects |
| `TagDedupMigration` | Default wins over recovered; idempotent second run; `lastTimerTagIds` remapped |
| `_recoverTagsFromHourlyLogs` | Does not add tag when name matches default; rewrites orphan log ids |
| `TagDeleteDialog` | Confirm disabled without target; built-in not offered for delete |
| `TagRegistryWriter` | Output format, sort order, header |
| Integration | Delete custom tag with 3 logs -> target receives merged rows; Notion tombstone called |

Run: `./scripts/verify.sh`

---

## 8. Out of scope

- Deleting or hiding built-in default tags
- Renaming tags in bulk
- Merging two **different** tag names (e.g. "TV" into "Television")
- SSE / live tag push
- Editing `specs/activity-tags.md` by hand (generator overwrites)

---

## 9. Implementation tasks (post-approval)

1. `TagReassignHelper` + tests
2. `TagDedupMigration` + bootstrap hook + tests
3. Fix `_recoverTagsFromHourlyLogs` + tests
4. `TagDeleteDialog` + wire TimerTagBar + HourlyLogDialog
5. `TagRegistryWriter` + initial generated `specs/activity-tags.md`
6. Run migration on this device's data; verify 14 tags
7. Update shipped specs; `./scripts/verify.sh`

---

## Document history

| Date | Change |
|------|--------|
| 2026-09-03 | Initial spec from operator review |
