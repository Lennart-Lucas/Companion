# Companion frontend

Flutter client using [Anvil Foundry](https://github.com) for auth, records, and UI shell.

## Setup

```bash
cd frontend
flutter pub get
```

Start the FastAPI backend (see `../backend`) so `http://localhost:8000/api/v1` is reachable.

## Run

```bash
flutter run -d chrome
```

In **development**, the API allows any `http://localhost:<port>` origin (Flutter web uses a random port each run). Restart the backend after pulling CORS changes. For production, set explicit `CORS_ORIGINS`.

### API base URL

Default: `http://localhost:8000/api/v1`

Override for other hosts:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://192.168.1.10:8000/api/v1
```

## Auth and data

- Login / register via `AuthBloc` with Companion token shape (`access_token`, `refresh_token`) and `GET /auth/me` session check.
- Tokens persist in `shared_preferences` across restarts.
- Productivity lists (goals, trackers, projects, tasks) load via `RecordBloc` and `CompanionRecordRepository` (`GET /{type}?limit&offset`).

## Tests

```bash
flutter analyze
flutter test
```
