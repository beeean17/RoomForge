# Firebase Auth Setup

Story 1.3 wires the Flutter app shell to Firebase Google Auth without committing Firebase project secrets.

## Local Config File

Copy the example file and fill in Firebase web config values:

```bash
cp app/.env.example app/.env
```

`app/.env` is ignored by git. Do not commit real Firebase values.

Then run the web app from the repository root:

```bash
./scripts/run-app-web.sh
```

The script calls Flutter with:

```bash
flutter run -d chrome --dart-define-from-file=.env
```

For local Firebase Auth emulator mode, use two terminals so server and client logs stay separate.

Terminal 1:

```bash
./scripts/run-firebase-emulator.sh
```

Terminal 2:

```bash
./scripts/run-app-web-with-emulator.sh
```

If you explicitly want both processes in one terminal, run:

```bash
./scripts/run-app-web-emulator.sh
```

The emulator script imports existing emulator data from `app/.firebase-emulator-data` and exports data back to that directory on exit. The app-with-emulator script launches Flutter with:

```bash
--dart-define=ROOMFORGE_USE_FIREBASE_EMULATOR=true
```

## Required Values

The config file should contain:

```env
ROOMFORGE_FIREBASE_API_KEY=...
ROOMFORGE_FIREBASE_APP_ID=...
ROOMFORGE_FIREBASE_MESSAGING_SENDER_ID=...
ROOMFORGE_FIREBASE_PROJECT_ID=...
ROOMFORGE_FIREBASE_AUTH_DOMAIN=...
```

Optional:

```env
ROOMFORGE_FIREBASE_STORAGE_BUCKET=...
```

## Runtime Behavior

- If Firebase config is present, the app initializes Firebase and uses Google sign-in.
- If Firebase config is missing, the sign-in entry remains visible and the app shows a configuration message.
- The signed-in workspace is a placeholder for the project list and creation flows in later stories.

Do not commit `google-services.json`, `GoogleService-Info.plist`, service account files, or real `.env` files.
