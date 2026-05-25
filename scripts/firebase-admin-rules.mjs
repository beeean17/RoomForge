import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collectionGroup,
  doc,
  getDocs,
  orderBy,
  query,
  setDoc,
  where,
} from 'firebase/firestore';
import { readFileSync } from 'node:fs';

const projectId = process.env.GCLOUD_PROJECT || 'roomforge-local';
const runId = `${Date.now()}-${Math.floor(Math.random() * 100000)}`;
const adminUid = `admin-${runId}`;
const ownerUid = `owner-${runId}`;
const nonAdminUid = `non-admin-${runId}`;
const projectIdValue = `admin-project-${runId}`;
const jobId = `admin-job-${runId}`;

const testEnv = await initializeTestEnvironment({
  projectId,
  firestore: {
    host: '127.0.0.1',
    port: 8080,
    rules: readFileSync('firestore.rules', 'utf8'),
  },
});

async function seedAdminDiagnosticsData() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const now = new Date();
    await setDoc(doc(db, 'users', adminUid), {
      uid: adminUid,
      email: `${adminUid}@example.test`,
      display_name: 'Rules Admin',
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
      display_name: 'Rules Non Admin',
      created_at: now,
      updated_at: now,
      schema_version: 1,
    });
    await setDoc(doc(db, 'projects', projectIdValue), {
      project_id: projectIdValue,
      owner_uid: ownerUid,
      name: 'Admin Diagnostics Project',
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
        failure_reason_code: 'opencv_failed',
        failure_reason: 'Synthetic failure for admin diagnostics.',
        artifact_refs: [],
        created_at: now,
        updated_at: now,
        schema_version: 1,
      },
    );
  });
}

const tests = [
  {
    id: 'fs-admin-job-cg-read-allow',
    run: async () => {
      const adminDb = testEnv.authenticatedContext(adminUid).firestore();
      const snapshot = await assertSucceeds(
        getDocs(
          query(
            collectionGroup(adminDb, 'reconstruction_jobs'),
            where('status', '==', 'failed'),
            orderBy('updated_at', 'desc'),
          ),
        ),
      );
      if (snapshot.docs.length !== 1 || snapshot.docs[0].data().job_id !== jobId) {
        throw new Error('Admin collection group query did not return the seeded job.');
      }
    },
  },
  {
    id: 'fs-admin-non-admin-job-cg-read-deny',
    run: async () => {
      const nonAdminDb = testEnv
        .authenticatedContext(nonAdminUid)
        .firestore();
      await assertFails(
        getDocs(
          query(
            collectionGroup(nonAdminDb, 'reconstruction_jobs'),
            where('status', '==', 'failed'),
            orderBy('updated_at', 'desc'),
          ),
        ),
      );
    },
  },
];

let failed = 0;
try {
  await testEnv.clearFirestore();
  await seedAdminDiagnosticsData();
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
