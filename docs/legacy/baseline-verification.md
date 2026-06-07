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
python3 -m pytest
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
python3 -m pytest
```

CI reproduces the same app, editor, and server checks. Server pytest requires installing the server development dependencies:

```bash
cd server
python3 -m venv .venv
.venv/bin/python -m pip install -e '.[dev]'
.venv/bin/python -m pytest
```
