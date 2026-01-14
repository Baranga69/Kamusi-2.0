# Kamusi Mobile (Flutter)

## Requirements

- Flutter SDK (3.2+)
- A running Kamusi API service

## Configure the API base URL

The app reads the base URL from a Dart define named `API_BASE_URL`.

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

If you omit the flag, it defaults to the Android emulator-friendly
`http://10.0.2.2:8000`.

Suggested values:

- Android emulator: `http://10.0.2.2:8000` (default)
- iOS simulator: `http://localhost:8000`
- Physical device: `http://<LAN-IP>:8000`

## Run the app

```bash
cd apps/mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

## Run the API

```bash
cd apps/api
poetry install
poetry run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## Example API calls

```bash
curl "http://localhost:8000/search?q=agua&lang=sw&limit=20"
curl "http://localhost:8000/lexemes/<LEXEME_ID>?lang=sw&include_drafts=true"
curl "http://localhost:8000/word-of-the-day?lang=sw"
```

## Features

- Search suggestions with debounce
- Word of the day card on the home screen
- Light/dark mode toggle on the home screen
- Recent searches (last 10) with clear action
- Lexeme and expression detail views
- Favorites with local persistence
