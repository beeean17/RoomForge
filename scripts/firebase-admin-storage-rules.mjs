import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  doc,
  setDoc,
} from 'firebase/firestore';
import {
  getBytes,
  ref,
  uploadBytes,
} from 'firebase/storage';
import { readFileSync } from 'node:fs';

const projectId = process.env.GCLOUD_PROJECT || 'roomforge-local';
const runId = `${Date.now()}-${Math.floor(Math.random() * 100000)}`;
const adminUid = `storage-admin-${runId}`;
const ownerUid = `storage-owner-${runId}`;
const nonAdminUid = `storage-non-admin-${runId}`;
const projectIdValue = `storage-project-${runId}`;
const jobId = `storage-job-${runId}`;
const artifactId = `artifact-${runId}`;
const artifactPath =
  `users/${ownerUid}/projects/${projectIdValue}/artifacts/${jobId}/${artifactId}/overlay.png`;

const testEnv = await initializeTestEnvironment({
  projectId,
  firestore: {
    host: '127.0.0.1',
    port: 8080,
    rules: readFileSync('firestore.rules', 'utf8'),
  },
  storage: {
    host: '127.0.0.1',
    port: 9199,
    rules: readFileSync('storage.rules', 'utf8'),
  },
});

async function seedFirestoreData() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const now = new Date();
    await setDoc(doc(db, 'users', adminUid), {
      uid: adminUid,
      email: `${adminUid}@example.test`,
      display_name: 'Storage Rules Admin',
      created_at: now,
      updated_at: now,
      schema_version: 1,
      role: 'admin',
      role_updated_at: now,
      role_updated_by_uid: 'rules-bootstrap',
    });
    await setDoc(doc(db, 'users', nonAdminUid), {
      uid: nonAdminUid,
      email: `${nonAdminUid}@example.test`,
      display_name: 'Storage Rules Non Admin',
      created_at: now,
      updated_at: now,
      schema_version: 1,
    });
    await setDoc(doc(db, 'projects', projectIdValue), {
      project_id: projectIdValue,
      owner_uid: ownerUid,
      name: 'Admin Storage Diagnostics Project',
      latest_job_id: jobId,
      current_reconstruction_status: 'failed',
      schema_version: 1,
      created_at: now,
      updated_at: now,
    });
    await setDoc(
      doc(db, 'projects', projectIdValue, 'reconstruction_jobs', jobId),
      {
        job_id: jobId,
        project_id: projectIdValue,
        owner_uid: ownerUid,
        source_image_id: 'source-1',
        room_dimensions_id: 'current',
        status: 'failed',
        status_updated_at: now,
        provider_type: 'manual_assisted_opencv',
        created_by_uid: ownerUid,
        root_job_id: jobId,
        retry_count: 0,
        latest_transition_id: 'transition-1',
        artifact_refs: [],
        created_at: now,
        updated_at: now,
        schema_version: 1,
      },
    );
  });
}

function artifactMetadata() {
  return {
    customMetadata: {
      owner_uid: ownerUid,
      project_id: projectIdValue,
      job_id: jobId,
      artifact_id: artifactId,
      uploaded_by_uid: ownerUid,
    },
    contentType: 'image/png',
  };
}

const tests = [
  {
    id: 'st-artifact-admin-read-allow',
    run: async () => {
      const ownerStorage = testEnv.authenticatedContext(ownerUid).storage();
      await uploadBytes(
        ref(ownerStorage, artifactPath),
        new Uint8Array([1, 2, 3, 4]),
        artifactMetadata(),
      );

      const adminStorage = testEnv.authenticatedContext(adminUid).storage();
      const bytes = await assertSucceeds(
        getBytes(ref(adminStorage, artifactPath)),
      );
      if (bytes.byteLength !== 4) {
        throw new Error('Admin artifact read returned unexpected bytes.');
      }
    },
  },
  {
    id: 'st-artifact-non-admin-cross-user-deny',
    run: async () => {
      const nonAdminStorage = testEnv
        .authenticatedContext(nonAdminUid)
        .storage();
      await assertFails(getBytes(ref(nonAdminStorage, artifactPath)));
    },
  },
];

let failed = 0;
try {
  await testEnv.clearFirestore();
  await testEnv.clearStorage();
  await seedFirestoreData();
  for (const test of tests) {
    try {
      await test.run();
      console.log(`${test.id}: pass`);
    } catch (error) {
      failed += 1;
      console.error(`${test.id}: failed`);
      console.error(error);
    }
  }
} finally {
  await testEnv.cleanup();
}

process.exit(failed > 0 ? 1 : 0);
