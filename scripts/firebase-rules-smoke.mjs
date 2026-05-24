const projectId = process.env.GCLOUD_PROJECT || 'roomforge-dev';
const bucket = process.env.FIREBASE_STORAGE_BUCKET || `${projectId}.appspot.com`;

const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
const rawStorageHost =
  process.env.FIREBASE_STORAGE_EMULATOR_HOST ||
  process.env.STORAGE_EMULATOR_HOST ||
  '127.0.0.1:9199';
const storageOrigin = rawStorageHost.startsWith('http')
  ? rawStorageHost
  : `http://${rawStorageHost}`;

const firestoreBaseUrl =
  `http://${firestoreHost}/v1/projects/${projectId}` +
  '/databases/(default)/documents';
const storageBaseUrl = `${storageOrigin}/v0/b/${bucket}/o`;

const checks = [
  {
    id: 'fs-unauth-read-deny',
    request: () => fetch(`${firestoreBaseUrl}/smoke/unauthenticated`),
  },
  {
    id: 'fs-unauth-write-deny',
    request: () =>
      fetch(`${firestoreBaseUrl}/smoke?documentId=unauthenticated-write`, {
        method: 'POST',
        headers: {'content-type': 'application/json'},
        body: JSON.stringify({
          fields: {
            attempted_by: {stringValue: 'unauthenticated-smoke-test'},
          },
        }),
      }),
  },
  {
    id: 'st-unauth-read-deny',
    request: () =>
      fetch(`${storageBaseUrl}/${encodeURIComponent('smoke/denied.txt')}`),
  },
  {
    id: 'st-unauth-write-deny',
    request: () =>
      fetch(
        `${storageBaseUrl}?uploadType=media&name=${encodeURIComponent(
          'smoke/denied.txt',
        )}`,
        {
          method: 'POST',
          headers: {'content-type': 'text/plain'},
          body: 'this write must be denied by storage.rules',
        },
      ),
  },
];

function isDenied(status) {
  return status === 401 || status === 403;
}

let failures = 0;

for (const check of checks) {
  try {
    const response = await check.request();
    if (isDenied(response.status)) {
      console.log(`PASS ${check.id}: denied with HTTP ${response.status}`);
    } else {
      failures += 1;
      const body = await response.text();
      console.error(
        `FAIL ${check.id}: expected 401/403, got HTTP ${response.status}`,
      );
      if (body.length > 0) {
        console.error(body);
      }
    }
  } catch (error) {
    failures += 1;
    console.error(`FAIL ${check.id}: request failed`);
    console.error(error);
  }
}

if (failures > 0) {
  process.exitCode = 1;
} else {
  console.log('Firebase unauthenticated rules smoke checks passed.');
}
