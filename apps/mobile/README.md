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

## Offline reading

Responses are cached on disk, so a word opened once stays readable without a
connection — which matters when data is intermittent or expensive. The exact
JSON the API returned is stored, keyed by request, with a least-recently-used
bound of 250 entries.

When a read fails for a reason a cached copy can stand in for — no connection,
a timeout, a 5xx — the saved copy is served and a calm banner says so. A 404 is
a real answer and is never masked: if an entry was removed upstream, showing
the old copy would be a lie.

This covers words already seen (so favourites and recent searches work on a
plane). Searching for something *new* offline still needs the network — true
offline search would mean shipping or syncing the corpus with a local full-text
index, which is a larger piece of work than this.

`shared_preferences` backs the cache, so there is no new dependency; a full
offline corpus would want `sqflite` with FTS instead.

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
flutter test
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

## Jifunze (Learn)

A second surface alongside the dictionary, reached from the bottom bar. The
dictionary stays calm; this is where the app is allowed motion and colour —
see `DESIGN_SYSTEM.md` §0 and §9 for what that licence does and does not
cover.

- **Today's challenge** — five questions, fixed for the day by the API, with a
  streak for turning up. Finishing the same day twice does not inflate it; a
  missed day restarts at one rather than zero.
- **Practice** — word→meaning, meaning→word, methali completion, or a mix.
  Fresh every time.
- A round cannot be failed: a wrong answer reveals the right one and moves on.
- Every question links to the entry it came from, so a round ends in the
  dictionary.
- Streak and accuracy live on the device, in UTC. No account required.

### Games

- **Tafuta Neno** — a word search. Finding a word opens its meaning under the
  grid, where it stays, and tapping it goes to the entry. The grid is the way
  in; the definition is what you leave with.
- **Unda Neno** — eight letters in a ring, dragged into words. Two modes, and
  the difference is only *when* the meanings appear: **easy** shows them from
  the start, so the game is "which word means this?", and **hard** reveals
  each one as its word is built. Unsolved answers show their length as dots
  and never their letters. The word using all eight letters is starred.
- **Neno la Siri** — a codeword. Every letter is a number, the same number
  everywhere it appears, so cracking one letter opens it in every word at
  once. Two letters are given to start. The clues are definitions, so a board
  you never finish has still taught you five words.
- The boards freeze the page scroll while a finger is on them, so a downward
  drag selects a word instead of scrolling. (It did scroll, once.)
- **Kwa muda** — one switch on the Jifunze home puts every game on a clock.
  Timed or untimed is a mood a player is in, not a property of a board, so it
  is one setting rather than a prompt on each one. Off by default: a clock
  turns a learning game into a test, and that should be opted into. When the
  time runs out the board stays on screen with every answer revealed, because
  being shown what you missed is the part worth having.

### Playing offline

`GameRoundCache` keeps a queue of **ten rounds per game** on the device.

The ordinary response cache stores the last reply per URL, which is right for
a dictionary entry and wrong for a game: every call to `/learn/wordfind`
returns a *different* puzzle, so caching by key would leave someone offline
replaying one grid forever. The queue is topped up in the background whenever
Jifunze is opened, and drawn down one round at a time — starting a game never
waits on the network.

Once the queue runs dry with no way to refill, it recycles what has already
been played, in a new order. Ten puzzles on rotation is a better answer for
someone on a long journey than a locked screen. The Jifunze home prints how
many rounds are ready, so you can check before losing signal.

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
