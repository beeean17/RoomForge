# RoomForge Server

Lightweight FastAPI service for Firebase token verification, authorization, Oracle DB access, job metadata, layout persistence, and admin operations.

The Oracle Cloud 1GB API server must not run heavy OpenCV, deep-learning, or GPU inference workloads. MVP OpenCV candidate extraction runs in the browser/editor layer.

## Local Verification

```bash
python3 -m compileall app tests
```

After installing development dependencies:

```bash
python3 -m pytest
```
