---
title: "Firebase Admin Role Bootstrap"
status: "implementation-note"
created: "2026-05-25"
story: "FES-3.2"
---

# Firebase Admin Role Bootstrap

RoomForge treats `users/{uid}.role` as privileged authorization state. Normal authenticated clients must not create, update, remove, or overwrite `role`, `role_updated_at`, or `role_updated_by_uid`.

## Selected Local/Dev Bootstrap Path

For local emulator development, admin role assignment is a trusted seed operation outside the normal Flutter client profile sync path.

The intended seed writes this shape directly to `users/{target_uid}` through an operator-controlled emulator seed, Admin SDK script, Firebase console equivalent, or future privileged Cloud Function:

```json
{
  "uid": "{target_uid}",
  "email": "admin@example.test",
  "display_name": "Local Admin",
  "created_at": "server_timestamp",
  "updated_at": "server_timestamp",
  "schema_version": 1,
  "role": "admin",
  "role_updated_at": "server_timestamp",
  "role_updated_by_uid": "{bootstrap_operator_uid}"
}
```

This bootstrap path is not exposed through `AuthSession`, `FirebaseUserProfileProjection`, `FirebaseUserProfileRepository.syncProfile`, or the normal Flutter sign-in UI.

## Audit Requirements

Every privileged assignment must record:

- `role: "admin"`
- `role_updated_at`
- `role_updated_by_uid`

The bootstrap operator UID may be a local seed identity in emulator development. Production-grade assignment UI or Cloud Functions remain out of scope for FES-3.2.

## Validation

FES-3.2 validates the boundary with:

- `fs-user-role-self-create-deny`
- `fs-user-role-self-update-deny`
- `repo-user-profile-update-preserves-role`

These checks prove normal client profile writes cannot self-grant or remove privileged role state.
