Goal: Build a cross-platform Flutter app (Android & iOS) for lecture attendance using QR codes & barcodes. The app must scan QR or barcode simultaneously, map the scanned value to a student (imported from Excel), mark attendance for the current lecture session, and export one Excel file per session for the lecturer to download.

Primary requirements

Import students from Excel

Excel file columns: student_id (optional numeric), student_name (string), code_value (string, the QR or barcode payload), code_type (optional: "qr"/"barcode").

Validate upload: reject duplicate code_value, show row-level errors, show preview before saving.

Local storage

Store student list and attendance locally (support offline use). Suggest either SQLite (sqflite) or Hive and explain tradeoffs.

Scanning

Use device camera to detect QR codes and barcodes at the same time (single camera preview).

When a code is detected, match code_value to imported students (exact match). Show matched student_name, student_id and mark present.

Prevent duplicate scans for the same student within the same session (debounce/lock for X seconds + visual feedback).

If the scanned value is not in DB, show “Unknown code” and allow manual lookup/registration.

Session management

Lecturer can Start Session (enter: course name, date/time auto, optional notes) and End Session.

Each session collects: session_id, course_name, timestamp_start, timestamp_end, and per-scan rows: student_id, student_name, code_value, timestamp_scan, scan_location (optional).

Export

At End Session, automatically generate an Excel file (one file per session) with attendance rows and session metadata. Allow download/share (email, cloud). Filename pattern: Attendance_<course>_<YYYYMMDD_HHMM>.xlsx.

UI/UX

Simple lecturer-facing UI: dashboard of courses/sessions, button to import Excel, Start/End session, scanner view, current session attendee list, export/download history.

Provide immediate visual confirmation on scan (green check + student name + photo placeholder) and a short sound/vibration.

Edge cases & reliability

Handle camera permission denial gracefully (show instructions).

Low-light detection hints and retry flow.

Handle duplicate codes in import with clear error messages.

Handle large classes (performance when 500+ students).

Security & privacy

Keep data local by default; if cloud sync is requested, design an opt-in API layer (not implemented unless asked).

Protect exported files if requested (optional password).



Technical preferences & suggestions (you may propose alternatives)

Flutter stable (latest recommended). Target Android & iOS.

Scanner packages: recommend and choose a package that supports scanning QR + multiple barcode formats at the same time (e.g., mobile_scanner or google_ml_kit with barcode scanning), explain pros/cons and pick one.

Excel import/export packages: e.g., excel or syncfusion_flutter_xlsio — show how to parse .xlsx and create .xlsx.

Local DB: recommend sqflite (relational queries) or hive (fast key-value). Provide schema definitions for chosen DB.

State management: use Provider, Riverpod, or Bloc — pick one and justify.

Deliverables (produce all of the following)

Project plan and folder structure.

pubspec.yaml with chosen packages.

Data model definitions (Dart classes) and DB schema/migrations.

Full, runnable Flutter code for:

Import Excel screen (with file picker and validation).

Scanner screen (camera preview + simultaneous QR & barcode detection).

Session management + attendee list screen.

Export to Excel function and Share/download integration.





A small sample Excel file content (5 rows) and expected export file structure (show columns).

Optional: Minimal wireframe images (or ASCII wireframes) for main screens.

Responses format

Start with a short summary of the chosen architecture and packages (1–2 paragraphs).

Then list the step-by-step implementation plan (numbered), with estimated complexity for each step (low/med/high).

Provide the exact code files (Dart) needed to get a minimal working prototype — include main.dart, scanner widget, import/export helpers, DB helper, and example tests.

Add inline comments in code explaining key logic (matching, de-duping, Excel creation).

End with suggestions for future improvements (cloud sync, student photos, NFC).

Extra: When implementing scanning, ensure the detector can:

Report the exact rawValue string and format (QR, Code128, EAN13, etc.).

Expose a callback onCodeScanned(String rawValue, String format) so it’s easy to test by mocking.