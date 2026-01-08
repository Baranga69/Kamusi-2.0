# Kamusi Mobile (Flutter)

## Requirements

- Flutter SDK (3.2+)
- A running Kamusi API service

## Configure the API base URL

The app reads the base URL from a Dart define named `API_BASE_URL`.

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

If you omit the flag, it defaults to `http://localhost:8000`.

## Run the app

```bash
cd apps/mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

## Features

- Search suggestions with debounce
- Lexeme and expression detail views
- Favorites with local persistence
