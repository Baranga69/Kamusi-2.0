# Kamusi Mobile (Flutter)

## Requirements

- Flutter SDK (3.2+)
- A running Kamusi API service

## Configure the API base URL

The app reads the base URL from a Dart define named `API_BASE_URL`. It defaults
to `http://localhost:8000`, which works for the iOS simulator, desktop and web.
Android emulators need the flag, because `localhost` there is the emulator
itself:

| Target | Value |
| --- | --- |
| iOS simulator, desktop, web | `http://localhost:8000` (default) |
| Android emulator | `http://10.0.2.2:8000` |
| Physical device | `http://<your-LAN-IP>:8000` |
| Deployed API | the deployed base URL |

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Release builds must pass the deployed URL explicitly; there is no production
default baked into the app.

## Draft content

The app requests published content only. Drafts are unpublished and unreviewed,
so viewing them is an explicit local opt-in:

```bash
flutter run --dart-define=INCLUDE_DRAFTS=true
```

Never set this for a release build.

## Run the app

```bash
cd apps/mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

## Localizations

UI strings live in `lib/l10n/app_en.arb` and `lib/l10n/app_sw.arb`. The
`AppLocalizations` classes beside them are generated and committed so a fresh
clone analyzes cleanly. Regenerate after editing an `.arb` file:

```bash
flutter gen-l10n
```

(Flutter no longer exposes these through the `package:flutter_gen` synthetic
package; they are imported by relative path.)

## Checks

```bash
flutter analyze
flutter build web --dart-define=API_BASE_URL=http://localhost:8000
```

`flutter analyze` is clean of errors and warnings. It still reports Material 3
colour-role deprecations (`background`, `surfaceVariant`); resolving those means
deciding how the two distinct Kamusi neutrals map onto the current
`ColorScheme`, which is a `DESIGN_SYSTEM.md` change rather than a rename.

## Run the API

```bash
cd apps/api
poetry install
poetry run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## Example API calls

```bash
curl "http://localhost:8000/search?q=agua&lang=sw&limit=20"
curl "http://localhost:8000/lexemes/<LEXEME_ID>?lang=sw"
curl "http://localhost:8000/word-of-the-day?lang=sw"
```

## Features

- Search suggestions with debounce
- Search filters for lemma, definition, and example matches
- Word of the day card on the home screen
- Word of the day refreshes on UTC day change when the app returns to foreground
- Top app bar with side drawer for Search and Favorites
- Light/dark mode toggle on the home screen
- Recent searches (last 10) with clear action
- Swipe to remove favorites
- Lexeme and expression detail views
- Favorites with local persistence
