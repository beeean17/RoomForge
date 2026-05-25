import { deleteApp, initializeApp } from 'firebase/app';
import {
  connectAuthEmulator,
  createUserWithEmailAndPassword,
  getAuth,
} from 'firebase/auth';
import {
  connectFirestoreEmulator,
  doc,
  getDoc,
  getFirestore,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const projectId = process.env.GCLOUD_PROJECT || 'roomforge-local';
const app = initializeApp({
  apiKey: 'roomforge-local-api-key',
  appId: 'roomforge-local-app-id',
  authDomain: `${projectId}.firebaseapp.com`,
  messagingSenderId: '000000000000',
  projectId,
});

const auth = getAuth(app);
const db = getFirestore(app);

connectAuthEmulator(auth, 'http://127.0.0.1:9099', {
  disableWarnings: true,
});
connectFirestoreEmulator(db, '127.0.0.1', 8080);

const runId = `${Date.now()}-${Math.floor(Math.random() * 100000)}`;

async function createSignedInUser(prefix) {
  const credential = await createUserWithEmailAndPassword(
    auth,
    `${prefix}-${runId}@example.test`,
    'Password123!',
  );
  return credential.user;
}

async function createProjectSetup(owner, suffix) {
  const id = `reconstruction-project-${suffix}-${runId}`;
  await setDoc(doc(db, 'projects', id), {
    project_id: id,
    owner_uid: owner.uid,
    name: `Reconstruction Project ${suffix}`,
    schema_version: 1,
    created_at: new Date(),
    updated_at: new Date(),
  });
  await setDoc(doc(db, 'projects', id, 'room_dimensions', 'current'), {
    project_id: id,
    owner_uid: owner.uid,
    width_m: 4.2,
    depth_m: 3.6,
    height_m: 2.7,
    unit: 'meters',
    source: 'user_entered',
    created_at: new Date(),
    updated_at: new Date(),
    schema_version: 1,
  });
  await setDoc(doc(db, 'projects', id, 'source_images', 'source-1'), {
    source_image_id: 'source-1',
    project_id: id,
    owner_uid: owner.uid,
    storage_path: `users/${owner.uid}/projects/${id}/source-images/source-1/room.jpg`,
    original_filename: 'room.jpg',
    stored_filename: 'room.jpg',
    content_type: 'image/jpeg',
    byte_size: 4,
    sha256_hex:
      '9f64a747e1b97f131fabb6b447296c9b6f0201e79fb3c5356e6c77e89b6a806a',
    width_px: 1280,
    height_px: 720,
    capture_source: 'file_upload',
    retention_status: 'active',
    uploaded_at: new Date(),
    created_at: new Date(),
    updated_at: new Date(),
    schema_version: 1,
  });
  return id;
}

function jobPayload(
  owner,
  projectIdValue,
  jobId,
  status = 'created',
  transitionId = `transition-${jobId}`,
) {
  return {
    job_id: jobId,
    project_id: projectIdValue,
    owner_uid: owner.uid,
    source_image_id: 'source-1',
    room_dimensions_id: 'current',
    status,
    status_updated_at: new Date(),
    provider_type: 'manual_assisted_opencv',
    algorithm_id: 'opencv_lines_corners_v1',
    created_by_uid: owner.uid,
    root_job_id: jobId,
    retry_count: 0,
    latest_transition_id: transitionId,
    artifact_refs: [],
    created_at: new Date(),
    updated_at: new Date(),
    schema_version: 1,
  };
}

function transitionPayload(
  owner,
  projectIdValue,
  jobId,
  transitionId,
  toStatus = 'created',
  fromStatus = null,
  retryJobId = null,
) {
  return {
    transition_id: transitionId,
    project_id: projectIdValue,
    owner_uid: owner.uid,
    job_id: jobId,
    ...(fromStatus === null ? {} : { from_status: fromStatus }),
    to_status: toStatus,
    occurred_at: new Date(),
    actor_type: 'user',
    actor_uid: owner.uid,
    reason_code: 'manual_review',
    reason_message: 'Needs review after candidate extraction.',
    ...(retryJobId === null ? {} : { retry_job_id: retryJobId }),
    artifact_refs: [],
    schema_version: 1,
  };
}

async function createJobWithTransition(
  owner,
  projectIdValue,
  jobId,
  status = 'created',
) {
  const transitionId = `transition-${jobId}`;
  const batch = writeBatch(db);
  batch.set(
    doc(db, 'projects', projectIdValue, 'reconstruction_jobs', jobId),
    jobPayload(owner, projectIdValue, jobId, status, transitionId),
  );
  batch.set(
    doc(
      db,
      'projects',
      projectIdValue,
      'reconstruction_jobs',
      jobId,
      'transitions',
      transitionId,
    ),
    transitionPayload(owner, projectIdValue, jobId, transitionId, status),
  );
  await batch.commit();
  return transitionId;
}

async function retryJobWithTransitions(owner, projectIdValue, jobId) {
  const retryJobId = `retry-${jobId}`;
  const currentTransitionId = `transition-retrying-${jobId}`;
  const retryTransitionId = `transition-created-${retryJobId}`;
  const batch = writeBatch(db);
  batch.update(doc(db, 'projects', projectIdValue, 'reconstruction_jobs', jobId), {
    status: 'retrying',
    status_updated_at: new Date(),
    latest_transition_id: currentTransitionId,
    updated_at: new Date(),
  });
  batch.set(
    doc(
      db,
      'projects',
      projectIdValue,
      'reconstruction_jobs',
      jobId,
      'transitions',
      currentTransitionId,
    ),
    transitionPayload(
      owner,
      projectIdValue,
      jobId,
      currentTransitionId,
      'retrying',
      'created',
      retryJobId,
    ),
  );
  batch.set(
    doc(db, 'projects', projectIdValue, 'reconstruction_jobs', retryJobId),
    {
      ...jobPayload(
        owner,
        projectIdValue,
        retryJobId,
        'created',
        retryTransitionId,
      ),
      retry_of_job_id: jobId,
      root_job_id: jobId,
      retry_count: 1,
    },
  );
  batch.set(
    doc(
      db,
      'projects',
      projectIdValue,
      'reconstruction_jobs',
      retryJobId,
      'transitions',
      retryTransitionId,
    ),
    transitionPayload(
      owner,
      projectIdValue,
      retryJobId,
      retryTransitionId,
      'created',
    ),
  );
  batch.update(doc(db, 'projects', projectIdValue), {
    latest_job_id: retryJobId,
    current_reconstruction_status: 'created',
    updated_at: new Date(),
  });
  await batch.commit();
  return retryJobId;
}

async function updateJobWithTransition(
  owner,
  projectIdValue,
  jobId,
  fromStatus,
  toStatus,
) {
  const transitionId = `transition-update-${jobId}-${toStatus}`;
  const batch = writeBatch(db);
  batch.update(doc(db, 'projects', projectIdValue, 'reconstruction_jobs', jobId), {
    status: toStatus,
    status_updated_at: new Date(),
    latest_transition_id: transitionId,
    updated_at: new Date(),
  });
  batch.set(
    doc(
      db,
      'projects',
      projectIdValue,
      'reconstruction_jobs',
      jobId,
      'transitions',
      transitionId,
    ),
    transitionPayload(
      owner,
      projectIdValue,
      jobId,
      transitionId,
      toStatus,
      fromStatus,
    ),
  );
  await batch.commit();
  return transitionId;
}

async function expectPermissionDenied(operation) {
  try {
    await operation();
  } catch (error) {
    if (error?.code === 'permission-denied') {
      return;
    }
    throw error;
  }

  throw new Error('Expected permission-denied, but operation succeeded.');
}

const tests = [
  {
    id: 'fs-job-valid-status-review-required-allow',
    run: async () => {
      const owner = await createSignedInUser('job-review-owner');
      const projectIdValue = await createProjectSetup(owner, 'review');
      const jobId = `job-review-${runId}`;
      await createJobWithTransition(owner, projectIdValue, jobId, 'review_required');
      const snapshot = await getDoc(
        doc(db, 'projects', projectIdValue, 'reconstruction_jobs', jobId),
      );
      if (snapshot.data()?.status !== 'review_required') {
        throw new Error('review_required job status was not persisted.');
      }
    },
  },
  {
    id: 'fs-job-invalid-status-needs-review-deny',
    run: async () => {
      const owner = await createSignedInUser('job-invalid-owner');
      const projectIdValue = await createProjectSetup(owner, 'invalid-status');
      const jobId = `job-invalid-${runId}`;
      await expectPermissionDenied(() =>
        createJobWithTransition(owner, projectIdValue, jobId, 'needs_review'),
      );
    },
  },
  {
    id: 'fs-job-create-retrying-deny',
    run: async () => {
      const owner = await createSignedInUser('job-create-retrying-owner');
      const projectIdValue = await createProjectSetup(owner, 'create-retrying');
      const jobId = `job-create-retrying-${runId}`;
      await expectPermissionDenied(() =>
        createJobWithTransition(owner, projectIdValue, jobId, 'retrying'),
      );
    },
  },
  {
    id: 'fs-job-create-without-transition-deny',
    run: async () => {
      const owner = await createSignedInUser('job-no-transition-owner');
      const projectIdValue = await createProjectSetup(owner, 'no-transition');
      const jobId = `job-no-transition-${runId}`;
      await expectPermissionDenied(() =>
        setDoc(
          doc(db, 'projects', projectIdValue, 'reconstruction_jobs', jobId),
          jobPayload(owner, projectIdValue, jobId),
        ),
      );
    },
  },
  {
    id: 'fs-job-transition-missing-troubleshooting-deny',
    run: async () => {
      const owner = await createSignedInUser('job-missing-transition-fields-owner');
      const projectIdValue = await createProjectSetup(
        owner,
        'missing-transition-fields',
      );
      const jobId = `job-missing-transition-fields-${runId}`;
      const transitionId = `transition-${jobId}`;
      const transition = transitionPayload(
        owner,
        projectIdValue,
        jobId,
        transitionId,
      );
      delete transition.actor_uid;
      delete transition.reason_code;
      delete transition.reason_message;
      await expectPermissionDenied(async () => {
        const batch = writeBatch(db);
        batch.set(
          doc(db, 'projects', projectIdValue, 'reconstruction_jobs', jobId),
          jobPayload(owner, projectIdValue, jobId, 'created', transitionId),
        );
        batch.set(
          doc(
            db,
            'projects',
            projectIdValue,
            'reconstruction_jobs',
            jobId,
            'transitions',
            transitionId,
          ),
          transition,
        );
        await batch.commit();
      });
    },
  },
  {
    id: 'fs-job-transition-append-allow',
    run: async () => {
      const owner = await createSignedInUser('job-transition-owner');
      const projectIdValue = await createProjectSetup(owner, 'transition');
      const jobId = `job-transition-${runId}`;
      await createJobWithTransition(owner, projectIdValue, jobId);
    },
  },
  {
    id: 'fs-job-status-update-review-required-allow',
    run: async () => {
      const owner = await createSignedInUser('job-update-owner');
      const projectIdValue = await createProjectSetup(owner, 'status-update');
      const jobId = `job-update-${runId}`;
      const jobRef = doc(
        db,
        'projects',
        projectIdValue,
        'reconstruction_jobs',
        jobId,
      );
      await createJobWithTransition(owner, projectIdValue, jobId);
      await updateJobWithTransition(
        owner,
        projectIdValue,
        jobId,
        'created',
        'review_required',
      );
      const snapshot = await getDoc(jobRef);
      if (snapshot.data()?.status !== 'review_required') {
        throw new Error('review_required job update was not persisted.');
      }
    },
  },
  {
    id: 'fs-job-status-update-without-transition-deny',
    run: async () => {
      const owner = await createSignedInUser('job-update-no-transition-owner');
      const projectIdValue = await createProjectSetup(
        owner,
        'status-update-no-transition',
      );
      const jobId = `job-update-no-transition-${runId}`;
      const jobRef = doc(
        db,
        'projects',
        projectIdValue,
        'reconstruction_jobs',
        jobId,
      );
      await createJobWithTransition(owner, projectIdValue, jobId);
      await expectPermissionDenied(() =>
        updateDoc(jobRef, {
          status: 'review_required',
          status_updated_at: new Date(),
          latest_transition_id: `missing-transition-${runId}`,
          updated_at: new Date(),
        }),
      );
    },
  },
  {
    id: 'fs-job-status-update-existing-transition-reuse-deny',
    run: async () => {
      const owner = await createSignedInUser('job-reuse-transition-owner');
      const projectIdValue = await createProjectSetup(
        owner,
        'reuse-transition',
      );
      const jobId = `job-reuse-transition-${runId}`;
      const firstTransitionId = await createJobWithTransition(
        owner,
        projectIdValue,
        jobId,
      );
      await updateJobWithTransition(
        owner,
        projectIdValue,
        jobId,
        'created',
        'review_required',
      );
      await expectPermissionDenied(() =>
        updateDoc(
          doc(db, 'projects', projectIdValue, 'reconstruction_jobs', jobId),
          {
            status: 'created',
            status_updated_at: new Date(),
            latest_transition_id: firstTransitionId,
            updated_at: new Date(),
          },
        ),
      );
    },
  },
  {
    id: 'fs-job-retry-batch-allow',
    run: async () => {
      const owner = await createSignedInUser('job-retry-owner');
      const projectIdValue = await createProjectSetup(owner, 'retry');
      const jobId = `job-retry-${runId}`;
      await createJobWithTransition(owner, projectIdValue, jobId);
      const retryJobId = await retryJobWithTransitions(
        owner,
        projectIdValue,
        jobId,
      );
      const original = await getDoc(
        doc(db, 'projects', projectIdValue, 'reconstruction_jobs', jobId),
      );
      const retry = await getDoc(
        doc(db, 'projects', projectIdValue, 'reconstruction_jobs', retryJobId),
      );
      if (original.data()?.status !== 'retrying') {
        throw new Error('Original job was not marked retrying.');
      }
      if (retry.data()?.retry_of_job_id !== jobId) {
        throw new Error('Retry job was not linked to original job.');
      }
    },
  },
  {
    id: 'fs-job-retrying-without-retry-link-deny',
    run: async () => {
      const owner = await createSignedInUser('job-retry-missing-link-owner');
      const projectIdValue = await createProjectSetup(
        owner,
        'retry-missing-link',
      );
      const jobId = `job-retry-missing-link-${runId}`;
      await createJobWithTransition(owner, projectIdValue, jobId);
      const transitionId = `transition-retrying-missing-link-${runId}`;
      await expectPermissionDenied(async () => {
        const batch = writeBatch(db);
        batch.update(
          doc(db, 'projects', projectIdValue, 'reconstruction_jobs', jobId),
          {
            status: 'retrying',
            status_updated_at: new Date(),
            latest_transition_id: transitionId,
            updated_at: new Date(),
          },
        );
        batch.set(
          doc(
            db,
            'projects',
            projectIdValue,
            'reconstruction_jobs',
            jobId,
            'transitions',
            transitionId,
          ),
          transitionPayload(
            owner,
            projectIdValue,
            jobId,
            transitionId,
            'retrying',
            'created',
          ),
        );
        await batch.commit();
      });
    },
  },
  {
    id: 'fs-job-retrying-with-missing-retry-job-deny',
    run: async () => {
      const owner = await createSignedInUser('job-retry-missing-job-owner');
      const projectIdValue = await createProjectSetup(
        owner,
        'retry-missing-job',
      );
      const jobId = `job-retry-missing-job-${runId}`;
      const retryJobId = `missing-retry-${jobId}`;
      await createJobWithTransition(owner, projectIdValue, jobId);
      const transitionId = `transition-retrying-missing-job-${runId}`;
      await expectPermissionDenied(async () => {
        const batch = writeBatch(db);
        batch.update(
          doc(db, 'projects', projectIdValue, 'reconstruction_jobs', jobId),
          {
            status: 'retrying',
            status_updated_at: new Date(),
            latest_transition_id: transitionId,
            updated_at: new Date(),
          },
        );
        batch.set(
          doc(
            db,
            'projects',
            projectIdValue,
            'reconstruction_jobs',
            jobId,
            'transitions',
            transitionId,
          ),
          transitionPayload(
            owner,
            projectIdValue,
            jobId,
            transitionId,
            'retrying',
            'created',
            retryJobId,
          ),
        );
        await batch.commit();
      });
    },
  },
  {
    id: 'fs-job-standalone-transition-deny',
    run: async () => {
      const owner = await createSignedInUser('job-standalone-transition-owner');
      const projectIdValue = await createProjectSetup(
        owner,
        'standalone-transition',
      );
      const jobId = `job-standalone-transition-${runId}`;
      await createJobWithTransition(owner, projectIdValue, jobId);
      const transitionId = `standalone-transition-${runId}`;
      await expectPermissionDenied(() =>
        setDoc(
          doc(
            db,
            'projects',
            projectIdValue,
            'reconstruction_jobs',
            jobId,
            'transitions',
            transitionId,
          ),
          transitionPayload(
            owner,
            projectIdValue,
            jobId,
            transitionId,
            'review_required',
            'created',
          ),
        ),
      );
    },
  },
  {
    id: 'fs-job-transition-update-deny',
    run: async () => {
      const owner = await createSignedInUser('job-transition-update-owner');
      const projectIdValue = await createProjectSetup(
        owner,
        'transition-update',
      );
      const jobId = `job-transition-update-${runId}`;
      const transitionId = await createJobWithTransition(
        owner,
        projectIdValue,
        jobId,
      );
      const transitionRef = doc(
        db,
        'projects',
        projectIdValue,
        'reconstruction_jobs',
        jobId,
        'transitions',
        transitionId,
      );
      await expectPermissionDenied(() =>
        updateDoc(transitionRef, { reason_message: 'Edited transition.' }),
      );
    },
  },
];

let failed = 0;
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

await auth.signOut().catch(() => undefined);
await deleteApp(app).catch(() => undefined);
process.exit(failed > 0 ? 1 : 0);
