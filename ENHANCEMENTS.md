# Suggested Enhancements

This review covers the whole codebase (`lib/`, Android/iOS config, CI). The items are grouped by priority. Each one lists the file it affects, what is wrong or missing, and a suggested fix.

---

## 1. Bugs (fix first)

### 1.1 `PermissionHelper.openAppSettings()` calls itself forever ✅
**File:** [lib/utils/permissions.dart](lib/utils/permissions.dart#L32-L34)

**Status:** ✅ implemented. The method now calls the package function through a `ph` import prefix.

The static method `openAppSettings()` calls `openAppSettings()`. Inside the class that name refers to the method itself, not to `permission_handler`'s top-level function, so calling it ends in a stack overflow.

```dart
import 'package:permission_handler/permission_handler.dart' as ph;

static Future<void> openAppSettings() async {
  await ph.openAppSettings();
}
```

### 1.2 The exported "Student ID" column holds the internal database ID
**Files:** [lib/services/excel_service.dart](lib/services/excel_service.dart#L224), [lib/screens/session_detail_screen.dart](lib/screens/session_detail_screen.dart#L336)

`AttendanceRecord.studentId` is the SQLite auto-increment key of the `students` row. It is not the university student number (`Student.studentId`). The Excel column "رقم الطالب" and the "ID:" line on the detail screen both show this internal number, so lecturers see values like `1, 2, 3…` instead of real student IDs.

**Fix:** Store the real student number on the attendance record (a new `student_number` column, which needs a DB migration; see 2.3), or JOIN `students` when exporting.

### 1.3 Foreign keys are never enabled
**File:** [lib/database/database_helper.dart](lib/database/database_helper.dart#L27-L32)

SQLite ignores `FOREIGN KEY … ON DELETE CASCADE` unless `PRAGMA foreign_keys = ON` is run on every connection. Today, deleting a student leaves orphaned attendance rows.

```dart
return await openDatabase(
  path,
  version: AppConstants.databaseVersion,
  onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
  onCreate: _createDB,
  onUpgrade: _upgradeDB,
);
```

> ⚠️ Turning this on as-is creates a new problem. `attendance_records.student_id` uses `ON DELETE CASCADE`, so **"Delete All Students" would also delete every past attendance record**. Change that FK to `ON DELETE SET NULL` (the name and code are already denormalized onto the record), or soft-delete students. See 2.3.

### 1.4 Deleting the active session leaves the app in a stale state ✅
**Files:** [lib/screens/session_detail_screen.dart](lib/screens/session_detail_screen.dart#L431), [lib/screens/home_screen.dart](lib/screens/home_screen.dart#L454)

**Status:** ✅ implemented. Swipe-deletes go through `SessionsNotifier.deleteSession` (in the shared [session_list_tile.dart](lib/widgets/session_list_tile.dart)). Every path that opens session details reloads the active session when the details screen reports a delete.

Both delete paths call `SessionService().deleteSession()` directly, so `activeSessionProvider` never learns about it. If the deleted session was the active one, the home card still shows it as active and the scan button stays enabled. Every scan then fails with "No active session".

**Fix:** Route all deletes through `SessionsNotifier.deleteSession` and reload `activeSessionProvider` afterwards. Better: have `sessionsProvider` and `activeSessionProvider` invalidate each other.

### 1.5 The cause of a failed "Start Session" is lost ✅
**File:** [lib/providers/session_provider.dart](lib/providers/session_provider.dart#L50-L67)

**Status:** ✅ implemented. `startSession` / `endSession` return `SessionOperationResult`, the home screen shows its (now Arabic) message, and the start dialog's text controllers are disposed.

`SessionService.startSession` returns a useful message ("There is already an active session…"), but `ActiveSessionNotifier.startSession` turns it into `bool`. The user only sees "فشل بدء الجلسة". Return the `SessionOperationResult` (or the error string) and show it.

### 1.6 Importing fails entirely if one code already exists
**Files:** [lib/database/database_helper.dart](lib/database/database_helper.dart#L106-L117), [lib/services/excel_service.dart](lib/services/excel_service.dart#L152)

Duplicates are checked only *inside the file*. If any `code_value` is already in the database, the batch insert (`ConflictAlgorithm.abort`) throws, and the user gets a generic failure with no row number.

**Fix:** During preview, check each code against the DB and flag those rows. Offer an import mode: **skip existing**, **update existing** (upsert on `code_value`), or **replace all**. Wrap the insert in `db.transaction` so a partial import cannot happen.

### 1.7 Holding a card in front of the camera repeats the "duplicate" alert ✅
**File:** [lib/screens/scanner_screen.dart](lib/screens/scanner_screen.dart#L192-L231)

**Status:** ✅ implemented together with 2.7 (5 s same-code lock).

`_lastScannedCode` is cleared 1.5 s after each scan. A code that stays in view is therefore processed again every ~3.5 s, and each time the error sound and red dialog appear. Keep a short-lived "recently seen" map (code → time) on the screen and ignore repeats for ~5 s. Show the red "already scanned" feedback once only.

### 1.8 Session deletion is not atomic ✅
**File:** [lib/services/session_service.dart](lib/services/session_service.dart#L142-L154)

**Status:** ✅ implemented with `DatabaseHelper.deleteSessionWithRecords` (one transaction).

Records and the session are deleted in two separate statements. Run both in one `db.transaction`. If FKs are enabled (1.3), the cascade handles the records anyway.

### 1.9 Android `MainActivity` package does not match the namespace ✅
**Files:** `android/app/src/main/kotlin/com/example/flutter_application_1/MainActivity.kt` (removed), [android/app/build.gradle.kts](android/app/build.gradle.kts#L16)

**Status:** ✅ implemented. Moved to [kotlin/com/almaarif/attendancescanner/MainActivity.kt](android/app/src/main/kotlin/com/almaarif/attendancescanner/MainActivity.kt) with the matching `package` line.

The namespace is `com.almaarif.attendancescanner`, and the manifest declares `.MainActivity`, which resolves to `com.almaarif.attendancescanner.MainActivity`. The class is declared in `package com.example.flutter_application_1`. Check this on a clean install. If it doesn't crash today, it is still fragile. Move the file to `kotlin/com/almaarif/attendancescanner/MainActivity.kt` and update its `package` line.

---

## 2. Reliability & Data

### 2.1 Run Excel parsing off the UI thread
[excel_service.dart](lib/services/excel_service.dart#L33) uses `readAsBytesSync()` and parses on the main isolate. With 500+ students (a stated goal in [Plan.md](Plan.md)), the UI freezes. Use `await File(path).readAsBytes()` and `compute()` / `Isolate.run()` for `Excel.decodeBytes` and row parsing.

### 2.2 Make the scan path faster
Each scan makes three DB round-trips: active session, student lookup, attendance check. Suggestions:
- Cache the active session ID in the scanner (it already comes from `activeSessionProvider`). Pass it into `processScan` instead of re-querying.
- Rely on the `UNIQUE(session_id, student_id)` constraint: insert with `ConflictAlgorithm.ignore` and check the returned row ID (`0` means duplicate). This removes the separate `hasStudentAttended` query and closes the race between check and insert.
- ✅ Done: the `_isWithinDebounceWindow` check in scanner_service.dart could never trigger, because the "already attended" check runs first. It has been removed (see 2.7).

### 2.3 Add a real migration path
`_upgradeDB` is empty and `databaseVersion = 1`. Before shipping schema changes (1.2, 1.3, 3.x), write versioned migrations. For example, `if (oldVersion < 2) { ALTER TABLE … }`. Add a test that upgrades a v1 database.

### 2.4 Back up and restore
All data lives in one local SQLite file. Losing the phone means losing every session. Add:
- **Export full backup** (copy the `.db` file, or dump to JSON/XLSX) through `share_plus`.
- **Restore from backup**.
- Optional: an automatic weekly backup to the documents folder.

### 2.5 Recover sessions left open
If the app is killed during a session, the session stays "active" indefinitely. On startup, if the active session started more than N hours ago (e.g. 6), ask the user whether to end it at its last scan time.

### 2.6 Don't swallow errors silently
Many `catch (e) { return false/[]/null; }` blocks (in [session_service.dart](lib/services/session_service.dart), [student_provider.dart](lib/providers/student_provider.dart), [session_provider.dart](lib/providers/session_provider.dart)) hide the real cause. At minimum, log with `debugPrint` or a logger. Better: surface typed errors to the UI. Replace the `print` calls in [sound_service.dart](lib/services/sound_service.dart) with `debugPrint` (this also fixes the `avoid_print` lint).

### 2.7 The scanner is locked too long after each scan ✅
**File:** [lib/screens/scanner_screen.dart](lib/screens/scanner_screen.dart#L208-L231)

**Status:** ✅ implemented as described below. The timings live in `AppConstants.scanGlobalGap` (0.8 s) and `AppConstants.scanSameCodeLock` (5 s). The results show in a non-modal card over the camera, and the scan error messages are now in Arabic.

After each scan, two waits run one after the other: the feedback dialog, then a fixed 1.5 s delay. The whole scanner is blocked for that time:

| Result | Dialog wait | Extra wait | Scanner blocked |
|---|---|---|---|
| Success | 1.5 s ([L305](lib/screens/scanner_screen.dart#L305)) | 1.5 s ([L225](lib/screens/scanner_screen.dart#L225)) | **~3 s** + DB time |
| Error / duplicate | 2.0 s ([L373](lib/screens/scanner_screen.dart#L373)) | 1.5 s | **~3.5 s** |

A student can show a card in about 1–1.5 s, so the scanner sits idle most of the time. For 60 students that's at least 3 minutes of lockout alone. The lock also stops *every* code, even though the only goal is to avoid counting the *same* code twice. The database already prevents that with `UNIQUE(session_id, student_id)`.

**Fix:**
1. **Per-code lock plus a short global gap.** Keep a `code → last seen time` map and ignore the same code for ~5 s. Accept a **different** code after a fixed **0.8 s** gap. That's just long enough for one student to move their card away.
   ```dart
   static const _globalGap = Duration(milliseconds: 800);
   static const _sameCodeLock = Duration(seconds: 5);
   DateTime _lastAccepted = DateTime.fromMillisecondsSinceEpoch(0);
   final Map<String, DateTime> _recentCodes = {};

   bool _shouldIgnore(String code, DateTime now) {
     if (now.difference(_lastAccepted) < _globalGap) return true;
     final seen = _recentCodes[code];
     return seen != null && now.difference(seen) < _sameCodeLock;
   }
   ```
   Record `_lastAccepted` and `_recentCodes[code]` when a scan is accepted. Remove the `_isProcessing` / `Future.delayed(1500 ms)` lock and the dead `_isWithinDebounceWindow` check in [scanner_service.dart](lib/services/scanner_service.dart#L75-L81). Keep only a simple flag that stops two DB calls overlapping.
2. **Non-modal feedback.** Replace the blocking `showDialog` with a banner or overlay that shows the name for ~1.5 s while the camera keeps scanning. A new scan replaces the banner straight away.
3. **Errors don't lock the scanner longer.** The error message can stay visible longer, but the 0.8 s gap applies to errors too, so an unknown card never holds up the next valid student.
4. Update the scanner info dialog text ("منع التكرار (3 ثواني)") to match the new timings.

Expected result: about one student per 1–1.5 s, and it also fixes 1.7 (the repeated duplicate alert).

---

## 3. Features

### 3.1 Absent students in the export *(high value)*
The export lists only students who were present. Lecturers usually need the full roster with a **Present / Absent** column, plus a summary (present count, absent count, rate). `SessionService.getSessionStats` already computes the rate but nothing uses it.

### 3.2 Subjects with their own sessions and rosters
This is the biggest structural improvement for real use.

**Problem today:**
- The course is free text typed each time a session starts, so a typo like "CS101" vs "CS 101" splits the history.
- There is one global student list, so attendance rates and absent lists are measured against *every* student imported for *any* course.

**Proposal:** the user adds a subject once with a **＋ Add subject** button. Sessions are then created *inside* that subject.

#### Navigation
```
Home
 ├─ Active session banner (if any) → Scanner
 └─ Subjects (cards) + [＋ Add subject]
      └─ Subject screen
           ├─ [Start new session]
           ├─ Sessions list (full history)
           ├─ Students tab (this subject's roster: import / add / edit)
           └─ Stats & semester export
```

#### Data model (DB v2)
```sql
CREATE TABLE subjects (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  code TEXT,                 -- e.g. "CS101" (optional)
  semester TEXT,             -- e.g. "Fall 2026" (optional)
  archived INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
);

CREATE TABLE subject_students (
  subject_id INTEGER NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  student_id INTEGER NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  PRIMARY KEY (subject_id, student_id)
);

ALTER TABLE sessions ADD COLUMN subject_id INTEGER REFERENCES subjects(id);
CREATE INDEX idx_sessions_subject_id ON sessions(subject_id);
```
Because of the `subject_students` link, one student can belong to several subjects without being imported twice. `students.code_value` stays globally unique, because one card belongs to one person.

#### Design decisions
1. **Rosters per subject.** The Excel import runs *inside* a subject. It adds new students and links existing ones (matched by `code_value`) to that subject. This is what makes absent lists and attendance rates correct.
2. **Students not enrolled.** If a student who isn't in the subject's roster scans in, show "Not enrolled in this subject". Offer **Add to subject** or **Accept as guest**. Make the default a setting.
3. **One active session at a time.** Keep the rule the code already enforces. Show the active session as a banner on the home screen so the lecturer reaches the scanner in one tap without opening the subject.
4. **Faster session start.** The subject is already known, so the dialog only asks for optional notes. The title defaults to the date (e.g. "Lecture: 1 Oct 2026").
5. **Archive, don't delete.** Deleting a subject would wipe its whole attendance history. Archive it instead (it is hidden from the home screen and shown under "Archived"). Hard delete stays available behind a strong confirmation.

#### Migration for existing users
In `_upgradeDB` (`oldVersion < 2`), inside one transaction:
1. Create the new tables and the `sessions.subject_id` column.
2. For each distinct `sessions.course_name` (trimmed), create a subject and set `subject_id` on its sessions.
3. Link every existing student to every migrated subject. That's the closest match to today's global roster, so old stats don't change.
4. Keep `course_name` for now (read-only) so nothing breaks. Drop it in a later version.

#### Code changes
- **Models:** add `Subject`. Add `subjectId` to `Session`.
- **DatabaseHelper:** subject CRUD, `getSessionsBySubject`, `getStudentsBySubject`, `enrollStudents(subjectId, ids)`, and `isEnrolled(subjectId, studentId)`.
- **Providers:** `subjectsProvider`, `subjectSessionsProvider.family(subjectId)`, and `subjectStudentsProvider.family(subjectId)`.
- **Screens:**
  - New `SubjectsHome` replaces the current home list.
  - New `SubjectScreen` with **Sessions** and **Students** tabs.
  - `ImportStudentsScreen` takes a `subjectId`.
  - The start-session dialog moves into `SubjectScreen`.
- **Scanner:** `processScan` checks enrollment against the active session's subject.
- **Export:** the per-session export lists the full subject roster with Present/Absent (3.1). A new subject-level export produces the semester matrix (3.6).

#### What it unlocks
- Correct absent lists (3.1)
- Per-student attendance percentages and "below X%" warnings (3.6)
- Semester matrix export
- A clean home screen with no limit on visible history (4.4)

**Effort:** medium to high. Do it together with the DB v2 migration in step 3 of the work order, so users go through only one schema upgrade.

### 3.3 Manual attendance & corrections
- Mark a student present by searching for their name (forgotten card, damaged code). [Plan.md](Plan.md#L23) mentions this ("allow manual lookup/registration").
- Remove an attendance record that was scanned by mistake (`deleteAttendanceRecord` exists in the DB helper but no UI uses it).
- From an "Unknown code" result, offer a quick "Register this code to a student" action.

### 3.4 Live attendee list on the scanner screen
`attendanceRecordsProvider` exists and is refreshed after each scan, but no screen reads it. Show a running counter (`42 / 60`) and the last 3–5 names scanned on the scanner screen, so the lecturer can confirm at a glance.

### 3.5 Student management screen
Students can only be bulk-imported or all deleted. Add a searchable list with add, edit and delete for single students (the provider already supports `addStudent`, `updateStudent` and `deleteStudent`).

### 3.6 Reports across sessions
Add a per-student attendance percentage across all sessions of a course, and a "students below X% attendance" list. Export a semester matrix: students × sessions, with a ✓/✗ grid.

### 3.7 Late arrivals
Add an optional "late after N minutes" threshold per session. Mark scans after the threshold as *Late* in the UI and in the export.

### 3.8 Export improvements
- Format dates with `intl` (`yyyy-MM-dd HH:mm`) instead of `DateTime.toString()`, which includes microseconds.
- Use RTL sheet direction, bold headers, and sensible column widths.
- Drop the "N/A" column for `scan_location` until location is implemented.
- Offer CSV and PDF as well as XLSX.
- Keep an export history (Plan.md: "export/download history").
- Save the sample template to a user-visible place, or share it directly. Today it goes to the app documents directory, which users can't reach on Android or iOS.

### 3.9 Optional future items (from Plan.md)
Student photos on the success dialog, an NFC card option, optional password-protected exports, and an opt-in cloud sync API layer.

---

## 4. UI / UX

### 4.1 Mixed Arabic and English
The app locale is Arabic (RTL), but large parts of the UI are in English:
- All of [import_students_screen.dart](lib/screens/import_students_screen.dart)
- Most labels in [session_detail_screen.dart](lib/screens/session_detail_screen.dart) ("Attendance List", "Present", "Date", "ACTIVE SESSION"…)
- All scan error messages from [scanner_service.dart](lib/services/scanner_service.dart) and import errors from [excel_service.dart](lib/services/excel_service.dart)

**Suggestion:** Move every string into ARB files with `flutter_localizations` + `intl` (`flutter gen-l10n`). Translate them all to Arabic, and keep English as a second locale if wanted. Services should return error *codes*, and the UI should map them to localized text.

### 4.2 Dark mode is half-supported
`darkTheme` is defined, but many widgets hard-code `Colors.white`, `Colors.green.shade50` and `Colors.grey.shade700` (scanner control bar, import action bar, active-session card). These look wrong in dark mode. Use `Theme.of(context).colorScheme` roles (`surface`, `primaryContainer`, `onSurfaceVariant`, etc.). Also replace the deprecated `withOpacity` with `withValues(alpha: …)`.

### 4.3 Scanner screen polish
- Show a clear camera permission prompt or error with an "Open Settings" button (`MobileScanner`'s `errorBuilder`), using the fixed helper from 1.1.
- Replace the blocking `showDialog` feedback with a non-modal overlay or banner. The camera keeps working underneath and fast queues of students move quicker.
- Show the torch state (on/off icon), and hide the torch button on devices without a flash.
- Set `scanWindow` on `MobileScanner` to match the drawn frame, so codes outside the frame are ignored.
- Add a setting to mute sounds or vibration.
- The info dialog says the duplicate lock is 3 s. Generate that text from `AppConstants.scanDebounceDuration` so it stays accurate.

### 4.4 Home screen
- Show today's/active session attendance count on the active-session card.
- **Older sessions can't be opened.** All sessions are saved (`getAllSessions()` has no limit), but the home screen only shows the 5 most recent ([home_screen.dart:410](lib/screens/home_screen.dart#L410), `sessionList.take(5)`), and nothing links to the rest. They still count in the "الجلسات" total, but can't be opened, exported or deleted.
  **Fix** (✅ implemented: [all_sessions_screen.dart](lib/screens/all_sessions_screen.dart), [session_list_tile.dart](lib/widgets/session_list_tile.dart)):
  - Add a **"عرض كل الجلسات"** (view all sessions) button under the recent list. Show it when there are more than 5 sessions.
  - It opens a new `AllSessionsScreen`: a scrollable list of every session from `sessionsProvider`, newest first, grouped by month.
  - Each row opens `SessionDetailScreen`. Swipe-to-delete works the same way as on the home screen.
  - Add a search box (course name) and a date-range filter.
  - Once subjects exist (3.2), each subject screen lists its own full session history, and this screen becomes a global "all sessions" view.
- Dispose the `TextEditingController`s created in `_showStartSessionDialog`, or move the dialog into its own `StatefulWidget`.
- Suggest recent course names in the start-session dialog (autocomplete).

### 4.5 Session detail screen
- Auto-refresh while the session is active: watch `attendanceRecordsProvider`, or poll or stream.
- Add search within the attendee list.
- Use one date-format style consistently (the home screen uses a manual `d/m/yyyy`, while detail uses `MMM dd, yyyy` in English).

---

## 5. Code Quality & Architecture

### 5.1 Use dependency injection consistently
Services create their dependencies directly (`DatabaseHelper.instance`, `ExcelService()`, `SessionService()`), and screens create services too (`SessionService()` in the home and detail screens, `ScannerService()` in the scanner). Providers for these already exist. Inject everything through Riverpod (`ref.read(sessionServiceProvider)`) so the logic can be tested with fakes.

### 5.2 Update the Riverpod style
`StateNotifierProvider` is legacy in Riverpod 2.x. Consider `AsyncNotifierProvider` (or `riverpod_generator`). Also:
- `attendanceRecordsProvider` re-creates its notifier whenever the active session changes. That's fine, but it should be a `FutureProvider.family` keyed by session ID so the detail screen can reuse it.
- Replace `AsyncValue<dynamic>` parameters in [home_screen.dart](lib/screens/home_screen.dart#L76) with real types (`AsyncValue<Session?>`, `AsyncValue<List<Student>>`). Today, typos in `session.courseName` are not caught at compile time.

### 5.3 Reduce duplication
- [sound_service.dart](lib/services/sound_service.dart) has three near-identical methods. Collapse them into `_play(String asset)`. Preloading with `AudioCache` / separate players avoids the stop/recreate dance and the delay before the first sound.
- The success and error dialogs in [scanner_screen.dart](lib/screens/scanner_screen.dart#L234-L377) are ~80% the same widget. Extract a `ScanFeedbackCard`.
- The info-card and stat-card widgets are repeated across screens. Move them into `lib/widgets/`.

### 5.4 Make models less error-prone
- `copyWith` cannot set nullable fields back to `null` (for example, clearing `notes` or `timestampEnd`). Use a sentinel or `freezed`.
- Consider `freezed` + `json_serializable` to generate `==`, `hashCode`, `copyWith` and maps. The hand-written `hashCode` using XOR collides easily.
- Store timestamps as UTC (`toUtc().toIso8601String()`) and convert to local time for display. This avoids problems with daylight-saving time and device time-zone changes.

### 5.5 Validators
- `validateStudentId` requires a numeric value. Many universities use alphanumeric IDs (e.g. `CS2024-017`). Allow any non-empty text, or make the rule configurable.
- Excel numeric cells can come through as `1001.0`. Normalize numeric `student_id` and `code_value` cells before validating or storing them. Otherwise a barcode stored as a number in Excel will never match the scanned string.
- Trim and normalize scanned values the same way as imported values (whitespace, invisible characters, and optionally letter case) so that matching is robust.

### 5.6 Unused or misleading code
- `ScannerService.isBarcode`, `getBarcodeFormatString`, `AppConstants.permissionStorage`, `PermissionHelper.requestStoragePermission`, and `Student.fromExcelRow` / `AttendanceRecord.toExcelRow` are unused. Remove them or put them to use.
- `INTERNET` permission in [AndroidManifest.xml](android/app/src/main/AndroidManifest.xml#L5) is not needed for an offline app (debug builds already add it).
- `pubspec.yaml` still has the template comments, and the app version is `1.0.0+1`. Clean up and adopt a versioning scheme that CI can bump.

---

## 6. Testing

[test/widget_test.dart](test/widget_test.dart) only checks `1 + 1 == 2`. Suggested coverage, in order of value:

1. **Unit tests**: `Validators`, `AppConstants.getExportFileName` (Arabic course names: the current regex `[^\w\s-]` removes **all Arabic characters**, so an Arabic course gives `Attendance__20261001_0900.xlsx`. Fix that with a Unicode-aware regex too.)
2. **Excel import tests**: parse fixture `.xlsx` files (valid, missing columns, duplicates, numeric cells, blank rows).
3. **DB tests** with `sqflite_common_ffi` (in-memory): scan flow, duplicate scan, unknown code, delete cascade, migrations.
4. **Widget tests**: home screen states (no session / active session), with providers overridden by fakes.
5. **Integration test** (`integration_test/`): start session → simulate scan → export.

---

## 7. Tooling & CI

- **CI hides test failures:** in [build-apk.yml](.github/workflows/build-apk.yml#L43-L50), `flutter test` runs with `continue-on-error: true`. Remove that, and add `flutter analyze` and `dart format --set-exit-if-changed .` steps.
- The workflow builds debug, release, *and* split release APKs on every push. Build only debug for PRs, and release/split for `main` or tags, to cut CI time.
- Release builds fall back to **debug signing** when `key.properties` is missing ([build.gradle.kts](android/app/build.gradle.kts#L53-L57)). That's convenient, but an APK signed with the debug key can't be updated with a properly signed one later. Fail release builds in CI when the secret isn't present instead.
- Enable R8/minification and resource shrinking for release (`isMinifyEnabled = true`, `isShrinkResources = true`) to shrink the APK.
- Turn on stricter lints in [analysis_options.yaml](analysis_options.yaml): `strict-casts`, `strict-raw-types`, `prefer_const_constructors`, `avoid_dynamic_calls`, `unawaited_futures`.
- Version control: the folder is not a git repository locally. Run `git init` (or clone the GitHub remote) so changes are tracked.

---

## Suggested order of work

| # | Task | Effort |
|---|------|--------|
| 1 | ✅ Bugs 1.1, 1.4, 1.5, 1.7, 1.8, 1.9 + faster scanner timing (2.7) | Low |
| 2 | Localize all strings to Arabic (4.1) | Medium |
| 3 | DB v2 migration: real student number on records, FK pragma + `SET NULL`, UTC timestamps (1.2, 1.3, 2.3) | Medium |
| 4 | Import upsert/skip modes + isolate parsing (1.6, 2.1, 5.5) | Medium |
| 5 | Export with absent students + formatting (3.1, 3.8) | Medium |
| 6 | Manual attendance, remove a record, live counter on scanner (3.3, 3.4) | Medium |
| 7 | Tests + strict CI (6, 7) | Medium |
| 8 | Subjects with sessions and rosters (3.2; ship its migration together with step 3) and cross-session reports (3.6) | High |
| 9 | Backup/restore (2.4) | Medium |
