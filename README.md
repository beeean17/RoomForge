# RoomForge

RoomForge is a web-first room reconstruction and furniture planning app.

## Term Project Plan

### Project Name

RoomForge

### Project Introduction

RoomForge is a web-based room reconstruction and furniture planning application. The project aims to help users recreate an indoor room layout digitally, place furniture in the space, and experiment with different arrangements before making real-world changes.

### Project Plan

- Build a simple web-first room editor for creating and viewing room layouts.
- Support furniture placement and basic layout planning features.
- Organize the project into separate app, editor, server, shared packages, and documentation areas.
- Continue refining the repository name, description, and feature scope as the term project progresses.

## 텀프로젝트 계획

### 프로젝트 이름

RoomForge

### 프로젝트 소개

RoomForge는 웹 기반의 방 재구성 및 가구 배치 계획 애플리케이션입니다. 사용자가 실제 공간을 디지털 환경에서 다시 구성하고, 가구를 배치해 보며, 다양한 인테리어 구성을 미리 실험할 수 있도록 돕는 것을 목표로 합니다.

### 프로젝트 계획

- 방 구조를 만들고 확인할 수 있는 간단한 웹 기반 편집기를 구현합니다.
- 가구 배치와 기본적인 공간 계획 기능을 지원합니다.
- 앱, 편집기, 서버, 공통 패키지, 문서 영역으로 프로젝트를 체계적으로 구성합니다.
- 과제 진행 과정에서 저장소 이름, 프로젝트 소개, 기능 범위를 계속 수정하고 보완합니다.

## Workspace

```text
app/       Flutter app shell
editor/    Vite + TypeScript spatial editor
server/    Legacy FastAPI API, inactive unless legacy_api mode is explicit
packages/  Shared schemas and design tokens
docs/      Project documentation
```

The default application backend is Firebase Auth, Firestore, and Storage. The
FastAPI/Oracle path is retained as legacy/reference code only.

Current Firebase refactor guidance starts at
[docs/refactor/README.md](docs/refactor/README.md). Historical FastAPI/Oracle
setup notes live under [docs/legacy/](docs/legacy/) and apply only when
`legacy_api` mode is selected intentionally.

## Verification

```bash
./scripts/verify-foundation.sh
```
