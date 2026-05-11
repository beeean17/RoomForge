# RoomForge Architecture

RoomForge is a web-first room reconstruction and furniture planning app. The MVP keeps the application server lightweight: the browser/editor handles OpenCV-assisted candidate extraction, while the server verifies auth, persists data, exposes APIs, and supports admin troubleshooting.

## System Overview

```mermaid
flowchart LR
  user[User Browser]
  admin[Admin Browser]

  subgraph client[Firebase Hosting - Web Client]
    flutter[Flutter App Shell]
    editor[Three.js Editor]
    cv[OpenCV.js Web Worker]
  end

  auth[Firebase Google Auth]

  subgraph api[Oracle Cloud 1GB Server]
    fastapi[Lightweight FastAPI API]
    authz[Auth and Ownership Checks]
    services[Domain Services]
    admin_api[Admin APIs]
  end

  db[(Oracle DB)]
  future[Optional Future GPU Provider]

  user --> flutter
  admin --> flutter
  flutter --> editor
  editor --> cv

  flutter --> auth
  auth -->|Firebase ID token| flutter
  flutter -->|Bearer token + REST JSON| fastapi

  fastapi --> authz
  authz --> services
  services --> db
  admin_api --> db
  fastapi --> admin_api

  services -. provider contract .-> future
  future -. job status/results .-> fastapi
```

## Core Flow

```mermaid
sequenceDiagram
  actor User
  participant App as Flutter App
  participant Editor as Three.js + OpenCV.js
  participant Auth as Firebase Auth
  participant API as FastAPI Server
  participant DB as Oracle DB

  User->>App: Sign in with Google
  App->>Auth: Authenticate
  Auth-->>App: Firebase ID token
  App->>API: Create/open room project
  API->>Auth: Verify token
  API->>DB: Map Firebase UID and persist project

  User->>App: Upload room photo and dimensions
  App->>API: Persist source image metadata
  API->>DB: Store image, dimensions, job metadata

  App->>Editor: Load image and room inputs
  Editor->>Editor: Run OpenCV.js in Web Worker
  Editor-->>App: Candidate edges/corners/boundaries
  User->>Editor: Correct geometry

  App->>API: Save candidates, confirmed geometry, calibration
  API->>DB: Persist reconstruction artifacts and status

  User->>Editor: Edit 2D/3D furniture layout
  App->>API: Save or export layout
  API->>DB: Persist layout JSON and traceability metadata
```

## Component Responsibilities

- `app/`: Flutter web shell for auth, navigation, forms, project workflows, admin screens, and accessible non-canvas controls.
- `editor/`: TypeScript Three.js package for source-image alignment, OpenCV overlays, geometry correction, 2D/3D rendering, and furniture manipulation.
- `server/`: Lightweight FastAPI service for Firebase token verification, authorization, REST APIs, Oracle DB access, job metadata, layout persistence, and admin operations.
- `Oracle DB`: System of record for users, projects, source images, room dimensions, reconstruction jobs, status transitions, CV artifacts, corrected geometry, layouts, failures, and retry history.
- `Firebase`: Hosting for the web client and Google Auth for identity.
- `Optional provider`: Post-MVP GPU/deep-learning workers can plug into the same reconstruction job/result contract without becoming required for MVP.

## Key Constraints

- The Oracle Cloud 1GB server must not run heavy OpenCV, deep-learning, or GPU inference workloads.
- MVP OpenCV processing runs in the browser/editor layer, preferably in a Web Worker.
- Oracle DB is the primary application data store.
- Every user-facing API request must verify Firebase identity and enforce Oracle-side ownership.
- Candidate geometry and user-confirmed geometry stay separate in storage and APIs.
- Persisted reconstruction status uses `review_required`; user-facing copy may display "Needs review."
