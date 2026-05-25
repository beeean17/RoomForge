import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collectionGroup,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';
import { readFileSync } from 'node:fs';

const projectId = process.env.GCLOUD_PROJECT || 'roomforge-local';
const runId = `${Date.now()}-${Math.floor(Math.random() * 100000)}`;
const adminUid = `admin-${runId}`;
const ownerUid = `owner-${runId}`;
const nonAdminUid = `non-admin-${runId}`;
const projectIdValue = `admin-project-${runId}`;
const jobId = `admin-job-${runId}`;
const retryJobId = `retry-${jobId}`;

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
    await setDoc(doc(db, 'projects', projectIdValue, 'room_dimensions', 'current'), {
      project_id: projectIdValue,
      owner_uid: ownerUid,
      width_m: 4.2,
      depth_m: 3.6,
      height_m: 2.7,
      unit: 'meters',
      source: 'user_entered',
      created_at: now,
      updated_at: now,
      schema_version: 1,
    });
    await setDoc(doc(db, 'projects', projectIdValue, 'source_images', 'source-1'), {
      source_image_id: 'source-1',
      project_id: projectIdValue,
      owner_uid: ownerUid,
      storage_path:
        `users/${ownerUid}/projects/${projectIdValue}/source-images/source-1/room.jpg`,
      stored_filename: 'room.jpg',
      content_type: 'image/jpeg',
      byte_size: 4,
      sha256_hex:
        '9f64a747e1b97f131fabb6b447296c9b6f0201e79fb3c5356e6c77e89b6a806a',
      width_px: 1280,
      height_px: 720,
      retention_status: 'active',
      uploaded_at: now,
      created_at: now,
      updated_at: now,
      schema_version: 1,
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

function adminActionPayload(
  actionId,
  targetId = jobId,
  retryId = retryJobId,
  createdByUid = adminUid,
) {
  return {
    action_id: actionId,
    project_id: projectIdValue,
    owner_uid: ownerUid,
    created_by_uid: createdByUid,
    created_by_role: 'admin',
    action_type: 'retry_reconstruction_job',
    target_type: 'reconstruction_job',
    target_id: targetId,
    reason_code: 'admin_retry',
    reason_message: 'Admin requested retry from diagnostics.',
    retry_job_id: retryId,
    metadata: {
      root_job_id: jobId,
      previous_status: 'failed',
    },
    created_at: new Date(),
    schema_version: 1,
  };
}

function adminRetryActionId(retryId) {
  return `retry_${retryId}`;
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
  {
    id: 'fs-admin-actions-create-allow',
    run: async () => {
      const adminDb = testEnv.authenticatedContext(adminUid).firestore();
      await assertSucceeds(
        setDoc(
          adminActionDoc(adminDb, 'action-create-allow'),
          adminActionPayload('action-create-allow'),
        ),
      );
    },
  },
  {
    id: 'fs-admin-actions-update-deny',
    run: async () => {
      const adminDb = testEnv.authenticatedContext(adminUid).firestore();
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(
          adminActionDoc(context.firestore(), 'action-update-deny'),
          adminActionPayload('action-update-deny'),
        );
      });
      await assertFails(
        updateDoc(adminActionDoc(adminDb, 'action-update-deny'), {
          reason_message: 'mutated',
        }),
      );
    },
  },
  {
    id: 'fs-admin-actions-delete-deny',
    run: async () => {
      const adminDb = testEnv.authenticatedContext(adminUid).firestore();
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(
          adminActionDoc(context.firestore(), 'action-delete-deny'),
          adminActionPayload('action-delete-deny'),
        );
      });
      await assertFails(deleteDoc(adminActionDoc(adminDb, 'action-delete-deny')));
    },
  },
  {
    id: 'fs-admin-non-admin-actions-read-deny',
    run: async () => {
      const nonAdminDb = testEnv
        .authenticatedContext(nonAdminUid)
        .firestore();
      await assertFails(
        getDoc(adminActionDoc(nonAdminDb, 'action-create-allow')),
      );
    },
  },
  {
    id: 'fs-admin-retry-non-admin-deny',
    run: async () => {
      const nonAdminDb = testEnv
        .authenticatedContext(nonAdminUid)
        .firestore();
      const retryId = `retry-non-admin-${jobId}`;
      const actionId = adminRetryActionId(retryId);
      const batch = writeBatch(nonAdminDb);
      queueRetryBatch({
        db: nonAdminDb,
        batch,
        actorUid: nonAdminUid,
        retryId,
        actionId,
        currentTransitionId: `transition-non-admin-retrying-${runId}`,
        retryTransitionId: `transition-non-admin-created-${runId}`,
        now: new Date(),
      });

      await assertFails(batch.commit());
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        const retryDoc = await getDoc(reconstructionJobDoc(db, retryId));
        const auditDoc = await getDoc(adminActionDoc(db, actionId));
        if (retryDoc.exists() || auditDoc.exists()) {
          throw new Error('Denied non-admin retry still created retry artifacts.');
        }
      });
    },
  },
  {
    id: 'fs-admin-retry-linked-job-allow',
    run: async () => {
      const adminDb = testEnv.authenticatedContext(adminUid).firestore();
      const batch = writeBatch(adminDb);
      queueRetryBatch({
        db: adminDb,
        batch,
        actorUid: adminUid,
        retryId: retryJobId,
        actionId: adminRetryActionId(retryJobId),
        currentTransitionId: `transition-retrying-${runId}`,
        retryTransitionId: `transition-created-${runId}`,
        now: new Date(),
      });
      await assertSucceeds(batch.commit());
    },
  },
];

function queueRetryBatch({
  db,
  batch,
  actorUid,
  retryId,
  actionId,
  currentTransitionId,
  retryTransitionId,
  now,
}) {
  batch.update(reconstructionJobDoc(db, jobId), {
    status: 'retrying',
    status_updated_at: now,
    root_job_id: jobId,
    latest_transition_id: currentTransitionId,
    updated_at: now,
  });
  batch.set(transitionDoc(db, jobId, currentTransitionId), {
    transition_id: currentTransitionId,
    project_id: projectIdValue,
    owner_uid: ownerUid,
    job_id: jobId,
    from_status: 'failed',
    to_status: 'retrying',
    occurred_at: now,
    actor_type: 'admin',
    actor_uid: actorUid,
    reason_code: 'admin_retry',
    reason_message: 'Admin requested retry from diagnostics.',
    retry_job_id: retryId,
    schema_version: 1,
  });
  batch.set(reconstructionJobDoc(db, retryId), {
    job_id: retryId,
    project_id: projectIdValue,
    owner_uid: ownerUid,
    source_image_id: 'source-1',
    room_dimensions_id: 'current',
    status: 'created',
    status_updated_at: now,
    provider_type: 'manual_assisted_opencv',
    created_by_uid: actorUid,
    retry_of_job_id: jobId,
    root_job_id: jobId,
    retry_count: 1,
    latest_transition_id: retryTransitionId,
    artifact_refs: [],
    created_at: now,
    updated_at: now,
    schema_version: 1,
  });
  batch.set(transitionDoc(db, retryId, retryTransitionId), {
    transition_id: retryTransitionId,
    project_id: projectIdValue,
    owner_uid: ownerUid,
    job_id: retryId,
    to_status: 'created',
    occurred_at: now,
    actor_type: 'admin',
    actor_uid: actorUid,
    reason_code: 'admin_retry_created',
    reason_message: 'Admin requested retry from diagnostics.',
    schema_version: 1,
  });
  batch.set(
    adminActionDoc(db, actionId),
    adminActionPayload(actionId, jobId, retryId, actorUid),
  );
}

function adminActionDoc(db, actionId) {
  return doc(db, 'projects', projectIdValue, 'admin_actions', actionId);
}

function reconstructionJobDoc(db, id) {
  return doc(db, 'projects', projectIdValue, 'reconstruction_jobs', id);
}

function transitionDoc(db, id, transitionId) {
  return doc(
    db,
    'projects',
    projectIdValue,
    'reconstruction_jobs',
    id,
    'transitions',
    transitionId,
  );
}

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
