# Baseline Verification

Run these checks before merging project foundation changes.

```bash
./scripts/verify-foundation.sh
```

The script runs:

```bash
flutter analyze
npm run typecheck
npm test
python3 -m compileall app tests
```

Manual equivalents:

```bash
cd app
flutter analyze

cd ../editor
npm run typecheck
npm test

cd ../server
python3 -m compileall app tests
```

CI should reproduce the same app, editor, and server checks. Server pytest is available after installing `server[dev]`, but the baseline check only requires Python syntax compilation so the scaffold can be verified before dependency setup is finalized.
